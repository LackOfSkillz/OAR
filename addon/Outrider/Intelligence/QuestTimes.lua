-- Intelligence/QuestTimes.lua  (OI03-04)
-- How long quests really take you, worked out from the quest diary QuestInfo
-- already keeps (global.questHistory[character]: took / handed in /
-- abandoned with times). No store of its own: everything here is derived on
-- demand, and the diary is never changed.
--
-- One sample per quest you took, with its kind:
--   complete   took and handed in within one play session: seconds = wall time
--              between the two (travel there and back included; inactive time
--              is not removed and is reported as possibly included)
--   multi      took and handed in in different play sessions (or, for old
--              rows with no session, more than MAX_GAP apart): no duration,
--              time logged out can't be told from time played
--   abandoned  took, then abandoned: no duration
--   open       took, not finished yet: no duration (right-censored)
--   censored   handed in or abandoned with no "took" seen (taken before the
--              diary, or on another computer): no duration (left-censored)
-- A sample is "grouped" when you were in a group at either end, and carries
-- the level, zone and game build, so summaries compare like with like.
-- Nothing is invented: only "complete" samples have seconds.

local _, ns = ...
local Q = { MAX_GAP = 4 * 3600, MIN_SAMPLES = 5 }
ns.QuestTimes = Q

function Q.Observe(history)
  local open, out = {}, {}
  for _, r in ipairs(history or {}) do
    if type(r) == "table" and tonumber(r.id) and tonumber(r.t) then
      local id = tonumber(r.id)
      if r.what == "took" then
        if open[id] then out[#out + 1] = { questID = id, kind = "open", startedAt = open[id].t, superseded = true } end
        open[id] = r
      elseif r.what == "handed in" or r.what == "abandoned" then
        local s = open[id]
        open[id] = nil
        if not s then
          out[#out + 1] = { questID = id, kind = "censored", endedAt = r.t, ended = r.what }
        elseif r.what == "abandoned" then
          out[#out + 1] = { questID = id, kind = "abandoned", startedAt = s.t, endedAt = r.t, level = s.lvl, zone = s.zone }
        else
          -- same play session? known when both rows carry one; else unknown (nil)
          local same
          if s.ps and r.ps then same = s.ps == r.ps end
          local sample = { questID = id, startedAt = s.t, endedAt = r.t, level = tonumber(s.lvl), zone = s.zone,
            build = r.gb or s.gb, grouped = (s.grp or r.grp) and true or false,
            contextKnown = (s.ps ~= nil and r.ps ~= nil) }
          if same == false or (same == nil and (r.t - s.t) > Q.MAX_GAP) then
            sample.kind = "multi"
          else
            sample.kind = "complete"
            sample.seconds = math.max(0, r.t - s.t)
            sample.mayIncludeInactive = true
          end
          out[#out + 1] = sample
        end
      end
    end
  end
  for id, s in pairs(open) do out[#out + 1] = { questID = id, kind = "open", startedAt = s.t, level = tonumber(s.lvl), zone = s.zone } end
  table.sort(out, function(a, b) return (a.startedAt or a.endedAt or 0) < (b.startedAt or b.endedAt or 0) end)
  return out
end

local function quantile(sorted, q)
  if #sorted == 0 then return nil end
  local pos = 1 + (#sorted - 1) * q
  local lo, hi = math.floor(pos), math.ceil(pos)
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo)
end

-- Summaries by stratum. opts.by: a function(sample) -> key; defaults to
-- level band (5 levels), solo or grouped, and game build.
function Q.Band(level) return level and (math.floor((level - 1) / 5) * 5 + 1) or nil end
function Q.Summary(samples, opts)
  opts = opts or {}
  local by = opts.by or function(s)
    return string.format("L%s|%s|%s", tostring(Q.Band(s.level) or "?"), s.grouped and "group" or "solo", tostring(s.build or "?"))
  end
  local groups, counts = {}, { complete = 0, multi = 0, abandoned = 0, open = 0, censored = 0 }
  for _, s in ipairs(samples or {}) do
    counts[s.kind] = (counts[s.kind] or 0) + 1
    if s.kind == "complete" then
      local k = by(s)
      groups[k] = groups[k] or {}
      table.insert(groups[k], s.seconds)
    end
  end
  local strata = {}
  for k, list in pairs(groups) do
    table.sort(list)
    local enough = #list >= Q.MIN_SAMPLES
    strata[#strata + 1] = { key = k, n = #list, median = quantile(list, 0.5), p25 = quantile(list, 0.25), p75 = quantile(list, 0.75),
      enough = enough }
  end
  table.sort(strata, function(a, b) return a.key < b.key end)
  return { strata = strata, counts = counts }
end

-- Against Journey's fixed estimate (Modules/Journey.lua QUEST_TIME, 300 s
-- "once there"). Journey's figure leaves out the trip; these samples include
-- it, so a higher median is expected and is reported, not "corrected".
function Q.Compare(summary, baseline)
  baseline = baseline or (ns.Journey and ns.Journey.QUEST_TIME) or 300
  local out = {}
  for _, s in ipairs(summary.strata) do
    out[#out + 1] = { key = s.key, n = s.n, median = s.median, baseline = baseline,
      ratio = s.enough and s.median and baseline > 0 and (s.median / baseline) or nil,
      note = s.enough and "includes travel to and from the quest" or ("only " .. s.n .. " sample" .. (s.n == 1 and "" or "s") .. ": not enough to compare") }
  end
  return out
end

-- this character's samples from the diary
function Q:Mine()
  local QI = ns.Modules:Get("QuestInfo")
  if not (QI and QI.History) then return {} end
  return Q.Observe(QI:History())
end

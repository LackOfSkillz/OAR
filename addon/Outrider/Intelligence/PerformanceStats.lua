-- Intelligence/PerformanceStats.lua  (OI03-07)
-- How your fights and your survival go, from what the game already lets
-- Outrider read. No store of its own; nothing here reads the combat log.
--   Fights: FightMeter's saved post-fight rows (char.fights), the numbers
--     Blizzard's own meter reports after combat (C_DamageMeter). A row is
--     used only if it carries its context (level, talent build, game build,
--     group) and a readable amount for you; others are counted as excluded
--     with the reason. Your damage per second is the meter's own amount for
--     you divided by the meter's own duration: no other combat figure is
--     worked out, and nothing restricted or secret is computed with.
--   Survival: the outcome recorder's death and recovery events: how many
--     deaths, how long getting back took, and deaths per hour of play (only
--     with at least MIN_PLAY seconds of non-inactive play).
-- Fights are compared only within one talent build and one game build: a
-- respec or a patch starts a new comparison, it doesn't blend into the old.

local _, ns = ...
local P = { MIN_SAMPLES = 5, MIN_PLAY = 1800 }
ns.PerformanceStats = P

local function quantile(sorted, q)
  if #sorted == 0 then return nil end
  local pos = 1 + (#sorted - 1) * q
  local lo, hi = math.floor(pos), math.ceil(pos)
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo)
end

function P.Key(ctx)
  local band = ctx.level and (math.floor((ctx.level - 1) / 5) * 5 + 1) or "?"
  return string.format("L%s|t%s|b%s|%s", tostring(band), tostring(ctx.talents or "?"), tostring(ctx.build or "?"), ctx.grouped and "group" or "solo")
end

function P.Fights(rows)
  local groups, excluded = {}, {}
  local function skip(why) excluded[why] = (excluded[why] or 0) + 1 end
  for _, r in ipairs(rows or {}) do
    local ctx = type(r) == "table" and r.context
    if type(ctx) ~= "table" then skip("no context (recorded before OI03-07)")
    elseif not ctx.talents or not ctx.build then skip("talent or game build unknown")
    elseif not (tonumber(r.player) and r.player > 0) then skip("no readable amount for you")
    elseif not (tonumber(r.duration) and r.duration > 0) then skip("no duration")
    else
      local k = P.Key(ctx)
      groups[k] = groups[k] or { key = k, talents = ctx.talents, build = ctx.build, values = {} }
      table.insert(groups[k].values, r.player / r.duration)
    end
  end
  local strata = {}
  for _, g in pairs(groups) do
    table.sort(g.values)
    strata[#strata + 1] = { key = g.key, talents = g.talents, build = g.build, n = #g.values,
      median = quantile(g.values, 0.5), p25 = quantile(g.values, 0.25), p75 = quantile(g.values, 0.75),
      enough = #g.values >= P.MIN_SAMPLES }
  end
  table.sort(strata, function(a, b) return a.key < b.key end)
  return { strata = strata, excluded = excluded }
end

-- two strata, compared only when the talent build and game build match
function P.Compare(a, b)
  if not (a and b) then return nil, "missing" end
  if a.talents ~= b.talents then return nil, "different talent builds" end
  if a.build ~= b.build then return nil, "different game builds" end
  if not (a.enough and b.enough) then return nil, "not enough fights" end
  return (b.median - a.median) / math.max(a.median, 1e-9)
end

-- events: OutcomeEvents; played: seconds of play that wasn't inactive
function P.Survival(events, played)
  local deaths, recover, openAt = 0, {}, nil
  for _, e in ipairs(events or {}) do
    if e.kind == "death" then
      deaths = deaths + 1
      openAt = e.at
    elseif e.kind == "recovery" and openAt then
      recover[#recover + 1] = e.at - openAt
      openAt = nil
    end
  end
  table.sort(recover)
  local out = { deaths = deaths, recoveries = #recover, medianRecovery = quantile(recover, 0.5), stillDead = openAt ~= nil or nil }
  if played and played >= P.MIN_PLAY then out.deathsPerHour = deaths / (played / 3600)
  else out.perHourWhy = "less than half an hour of active play" end
  return out
end

-- this character, now
function P:Mine()
  local F = ns.Modules:Get("FightMeter")
  local fights = F and F.History and P.Fights(F:History()) or { strata = {}, excluded = {} }
  local O = ns.Outcomes
  local events = O and O:Store().events or {}
  local played
  local A = ns.ActivityTimeline
  if A and A.Totals then
    local totals, sum = A:Totals()
    played = sum - (totals.inactive or 0)
  end
  return { fights = fights, survival = P.Survival(events, played), excludedThisSession = F and F.excluded or {} }
end

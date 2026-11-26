-- Intelligence/Adapters.lua  (OI02-06, OI02-07)
-- Normalize what Outrider already suggests into v4 Opportunity records
-- (Intelligence/Contracts.lua) for the Nexus planner. The existing producers
-- stay the source of truth; this only reads them:
--   progression (OI02-06): WhatNow's sources errands (Errands, Nearest),
--     quests (Journey quest XP list over QuestInfo/NPCPack data), dungeons
--     (DungeonGuide, Travel), dungeonquests (DungeonQuests); plus the current
--     LevelRoutes step.
--   resources (OI02-07): WhatNow's gear (Nearby, GearScore, DungeonGuide),
--     training (ProfTrainer, MoneyGuide), rares (Sightings), gold (MoneyGuide,
--     LootLog), gather (LootLog, Travel); DealDesk's live vendor-flip lots
--     (only lots the player's own auction search produced); Handoffs (BoE
--     upgrades another character holds, from saved inventories); Vanguard
--     (VG03-06: your own prep actions, only while Group check is on).
--   Every resource cost or gain is in copper (costCopper) or seconds
--     (costSeconds), with an evidence id; no adapter starts a scan or search.
-- Rules:
--   * ids are deterministic: "opp:" .. the producer's own key, sanitized;
--   * a candidate that can't become a valid record is excluded with a reason
--     (never guessed into shape); a failing producer is reported unavailable
--     and the rest carry on;
--   * the same quest from two producers (quest:<name>/<id>, dq:<id>) is one
--     opportunity: the better benefit wins, the other is listed as a duplicate;
--   * intent is only waypoint, panel or none; the producer's go() is kept
--     runtime-only (never serialized) and runs only on the player's click.

local _, ns = ...
local A = { PROGRESSION = { "errands", "quests", "dungeons", "dungeonquests" },
  RESOURCES = { "gear", "training", "rares", "gold", "gather" }, TTL = 180 }
ns.NexusAdapters = A

local KIND = { quest = "quest", dungeon = "dungeon", errand = "errand", gold = "gold", gather = "gather",
  profession = "profession", gear = "gear", rare = "rare", travel = "travel", explore = "explore" }
local LABEL = { observed = "observed", verified = "verified", community = "community", inferred = "inferred", guide = "community" }

local function idPart(s) return (tostring(s):gsub("[^%w_:%.@%-]", "_")) end
local function clean(s, max)
  if type(s) ~= "string" then return nil end
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", ""):gsub("%c", " ")
  return s:sub(1, max)
end
local function clamp(n) n = tonumber(n) if not n or n ~= n then return nil end return math.max(0, math.min(1, n)) end

-- The quest a candidate is about, if any (for de-duplication across producers).
function A.QuestKey(c)
  if tonumber(c.questID) then return "q" .. tonumber(c.questID) end
  local k = tostring(c.key or "")
  local id = k:match("^dq:(%d+)$") or k:match("^quest:(%d+)$")
  if id then return "q" .. id end
  local name = k:match("^quest:(.+)$")
  return name and ("n" .. name:lower()) or nil
end

-- Gold cost (OI02-R03): a known cost is a number (0 included); a cost the
-- producer doesn't know is costUnknown, never 0. Kinds that never spend gold
-- are known zero. Gear is free only from a drop or a quest reward (Nearby's
-- source kind); a vendor item or anything else has an unknown price.
A.FREE_KINDS = { quest = true, dungeon = true, rare = true, gather = true, explore = true }
A.FREE_GEAR = { drop = true, quest = true, object = true }
function A.Cost(c, kind)
  local cost = tonumber(c.costCopper)
  if cost and cost == cost and cost > -1e12 and cost < 1e12 then return math.floor(cost), false end
  if A.FREE_KINDS[kind] then return 0, false end
  if kind == "gear" and A.FREE_GEAR[c.gearSource] then return 0, false end
  return nil, true
end

-- Evidence (OI02-R04): every opportunity cites a real IntelEvidence record made
-- from its producer's candidate, with the time the fact was observed (the
-- candidate's observedAt when it has one, else now: the producer read it now).
-- The opportunity expires with its evidence, not on a fresh timer.
local CATEGORY = { quest = "quest", dungeon = "quest", gear = "gear", errand = "errand", gold = "generic",
  gather = "location", profession = "bag", rare = "historical", travel = "generic", explore = "generic" }
local EV_LABEL = { observed = "observed", community = "community", inferred = "inferred", guide = "community" }
-- Producers that read the live game state when asked: their facts are
-- observed now. The others report history (sightings, node visits, saved alt
-- inventories, auction listings) and must give the observation time, with how
-- old such a fact may be for a decision (maxAge); without a time the fact's
-- freshness is unknown (OI02-R11).
A.LIVE_SOURCES = { errands = true, quests = true, gear = true, dungeons = true, dungeonquests = true,
  training = true, gold = true, levelroute = true, tips = true }
A.MAX_AGE = { rares = 14 * 86400, gather = 15 * 60, deals = 600, handoffs = 30 * 86400 }
function A.EvidenceFor(source, c, kind, now)
  local E = ns.IntelEvidence
  local src = ("nx_" .. tostring(source)):gsub("[^%w_%-]", "_"):sub(1, 48)
  if not E.sources[src] then E:Register(src, "ready", { sourceType = "module" }) end
  local key = idPart(c.key):sub(1, 100)
  local category = (kind == "gold" and tostring(c.key):find("^deal:")) and "auction" or CATEGORY[kind] or "generic"
  local value = { kind = kind, benefit = clamp(c.benefit), seconds = tonumber(c.seconds), mapID = tonumber(c.mapID),
    questID = tonumber(c.questID), itemID = tonumber(c.itemID), costCopper = tonumber(c.costCopper) }
  local ttl = tonumber(c.evidenceTTL) or A.TTL
  local seen = tonumber(c.observedAt)
  local opts = { maxAge = tonumber(c.evidenceMaxAge) or A.MAX_AGE[source] }
  if not seen and not A.LIVE_SOURCES[source] then opts.freshness = "unknown" end
  return E:Record(src, key, category, value, EV_LABEL[c.label] or "inferred", ttl, seen, opts)
end

-- One candidate -> v4 Opportunity, or nil, reason.
function A.Adapt(source, c, revision, now)
  if type(c) ~= "table" or type(c.key) ~= "string" or c.key == "" then return nil, "no key" end
  if ns.Compat.IsSecret(c.key) or ns.Compat.IsSecret(c.title) then return nil, "secret" end
  local kind = KIND[c.kind]
  if not kind then return nil, "not an opportunity (" .. tostring(c.kind) .. ")" end
  local title = clean(c.title, 180)
  if not title or title == "" then return nil, "no title" end
  local benefit = clamp(c.benefit)
  if not benefit then return nil, "no benefit" end
  now = now or time()
  local ev = A.EvidenceFor(source, c, kind, now)
  if not ev then return nil, "no usable evidence" end
  local key = idPart(source .. ":" .. c.key):sub(1, 110)
  local rec = {
    opportunityId = "opp:" .. key, kind = kind, title = title, benefit = benefit,
    confidence = LABEL[c.label] or "unknown", evidenceIds = { ev.id },
    expiresAt = ev.expiresAt, intent = c.go and "waypoint" or (c.panel and "panel") or "none",
    revision = revision or 1, legacyCandidateId = idPart(c.key):sub(1, 120), why = clean(c.why, 300),
  }
  -- time = the trip there plus the activity itself, when the producer gives
  -- one (OI04-02: a quest's own time used to be left out)
  local secs = tonumber(c.seconds)
  local act = tonumber(c.estimatedActivitySeconds)
  if secs and secs >= 0 and secs == secs then
    rec.costSeconds = math.min(31536000, math.floor(secs + ((act and act >= 0 and act == act) and act or 0)))
  end
  local conf = clamp(c.confidence)
  if conf then rec.risk = 1 - conf end
  if ev.freshness == "unknown" then rec.freshnessUnknown = true end
  local cost, unknown = A.Cost(c, kind)
  rec.costCopper = cost
  if unknown then rec.costUnknown = true end
  local ok, field = ns.Nexus.Validate("Opportunity", rec)
  if not ok then return nil, "invalid " .. tostring(field) end
  return rec
end

-- Graph metadata from the producer's own candidate (OI02-R02). What a
-- producer doesn't say is listed in m.unknown, never guessed:
--   mapID, travelSeconds (the producer's trip estimate), faction (a quest's
--   pack faction; a quest for both factions is open to all), requires (a
--   quest's unfinished prerequisites, as opportunity ids when they are in the
--   plan's pool, else as "quest:q<id>" so the graph says what's missing),
--   overlap (the same quest from two producers), excludes (no producer
--   reports mutual exclusions yet: listed as unknown).
-- questIndex: { [questID] = opportunityId } over the pool; done(qid) checks the
-- quest log (C_QuestLog.IsQuestFlaggedCompleted).
local function questDone(qid) return ns.Compat.Call("C_QuestLog.IsQuestFlaggedCompleted", qid) == true end
function A.Meta(c, questIndex, done)
  done = done or questDone
  questIndex = questIndex or {}
  local m, unknown = {}, {}
  m.mapID = tonumber(c.mapID)
  if not m.mapID then unknown[#unknown + 1] = "map" end
  local trip = tonumber(c.estimatedTripSeconds) or tonumber(c.seconds)
  if trip and trip >= 0 then m.travelSeconds = math.floor(trip) else unknown[#unknown + 1] = "travel" end
  local q = A.QuestKey(c)
  if q then m.overlap = "quest:" .. q end
  local qid = tonumber(c.questID)
  if c.kind == "quest" or c.kind == "dungeon" then
    if c.questFaction == "Alliance" or c.questFaction == "Horde" then m.faction = c.questFaction
    elseif not qid then unknown[#unknown + 1] = "faction" end
    if qid then
      local req = {}
      local function need(pq)
        req[#req + 1] = questIndex[pq] or ("quest:q" .. tostring(pq))
      end
      for _, pq in ipairs(type(c.preAll) == "table" and c.preAll or {}) do
        if tonumber(pq) and not done(pq) then need(pq) end
      end
      local any = type(c.preAny) == "table" and c.preAny or {}
      if #any > 0 then
        local ok = false
        for _, pq in ipairs(any) do if done(pq) then ok = true break end end
        if not ok then
          -- one of several will do (OI02-R14): every alternative is listed and
          -- the graph and planner accept any one that can be done
          local alts = {}
          for _, pq in ipairs(any) do
            if tonumber(pq) then alts[#alts + 1] = questIndex[pq] or ("quest:q" .. tostring(pq)) end
          end
          if #alts > 0 then m.requiresAny = alts end
        end
      end
      if #req > 0 then m.requires = req end
    else
      unknown[#unknown + 1] = "prerequisites"
    end
  end
  unknown[#unknown + 1] = "excludes"
  m.unknown = unknown
  -- steps that need a group (OI04-01: a solo session leaves them out)
  if ns.NexusHorizon and ns.NexusHorizon.NeedsGroup(c) then m.needsGroup = true end
  return m
end

-- meta for every opportunity in a Collect result
function A.MetaAll(runtime, done)
  local index = {}
  for id, c in pairs(runtime or {}) do
    local qid = tonumber(c.questID)
    if qid and (not index[qid] or id < index[qid]) then index[qid] = id end
  end
  local meta = {}
  for id, c in pairs(runtime or {}) do meta[id] = A.Meta(c, index, done) end
  return meta
end

-- Run producers; returns opportunities (sorted by id), excluded, unavailable.
-- opts.extra: { name = function() return candidates end } producers beyond WhatNow's.
function A:Collect(names, revision, now, extra)
  local W = ns.WhatNow
  local out, excluded, unavailable, byQuest, runtime = {}, {}, {}, {}, {}
  local function take(source, list)
    for _, c in ipairs(list) do
      local rec, why = A.Adapt(source, c, revision, now)
      if not rec then
        excluded[#excluded + 1] = { source = source, key = tostring(c and c.key), reason = why }
      else
        local q = A.QuestKey(c)
        local prev = q and byQuest[q]
        if prev and prev.benefit >= rec.benefit then
          excluded[#excluded + 1] = { source = source, key = c.key, reason = "duplicate of " .. prev.opportunityId }
        else
          if prev then
            excluded[#excluded + 1] = { source = "?", key = prev.legacyCandidateId, reason = "duplicate of " .. rec.opportunityId }
            out[prev.opportunityId] = nil
          end
          if q then byQuest[q] = rec end
          out[rec.opportunityId] = rec
          runtime[rec.opportunityId] = c -- the producer's own candidate, for its go() on a click
        end
      end
    end
  end
  for _, name in ipairs(names) do
    local fn = W and W.SOURCES and W.SOURCES[name]
    local ok, list = pcall(fn or function() error("no producer") end)
    if ok and type(list) == "table" then take(name, list) else unavailable[#unavailable + 1] = name end
  end
  for name, fn in pairs(extra or {}) do
    local ok, list = pcall(fn)
    if ok and type(list) == "table" then take(name, list) else unavailable[#unavailable + 1] = name end
  end
  local list = {}
  for _, rec in pairs(out) do list[#list + 1] = rec end
  table.sort(list, function(a, b) return a.opportunityId < b.opportunityId end)
  table.sort(unavailable)
  return list, excluded, unavailable, runtime
end

-- the current LevelRoutes step as a candidate (the player's own route)
function A.LevelRouteStep()
  local L = ns.Modules:Get("LevelRoutes")
  if not (L and L.enabled and L.Current) then return {} end
  local ok, step, index, route = pcall(L.Current, L)
  if not ok or type(step) ~= "table" then return {} end
  return { { key = "route:" .. tostring(route and route.name or "route") .. ":" .. tostring(step.id or index or 1),
    kind = step.questID and "quest" or "travel", questID = step.questID,
    title = tostring(step.name or "Next step on your route"), benefit = 0.7, confidence = 0.8,
    label = "observed", why = "The next step on the route you're following." } }
end

function A:Progression(revision, now)
  return self:Collect(self.PROGRESSION, revision, now, { levelroute = A.LevelRouteStep })
end

-- DealDesk: live vendor-flip lots already found by the player's own search.
-- The gain is a measured copper profit, so benefit scales with it (capped).
function A.DealLots()
  local D = ns.Modules:Get("DealDesk")
  if not (D and D.enabled and D.Rows) then return {} end
  local out = {}
  for _, lot in ipairs(D:Rows()) do
    local profit = tonumber(lot.profitCopper)
    if profit and profit > 0 and tonumber(lot.costCopper) then
      out[#out + 1] = { key = "deal:" .. tostring(lot.id), kind = "gold",
        title = string.format("Vendor flip: item %s, +%s", tostring(lot.itemID), ns.Prices and ns.Prices.Money(profit) or tostring(profit)),
        benefit = math.min(1, profit / 100000), confidence = 0.9, label = "observed",
        costCopper = lot.costCopper, observedAt = tonumber(lot.observedAt),
        why = tostring(lot.source or "live listing and vendor value") }
    end
  end
  return out
end

-- Handoffs: BoE upgrades your other characters hold (saved inventories, read only).
function A.HandoffItems()
  local H = ns.Modules:Get("Handoffs")
  if not (H and H.enabled and H.Find) then return {} end
  local out = {}
  for _, h in ipairs(H:Find()) do
    out[#out + 1] = { key = "handoff:" .. tostring(h.holder) .. ":" .. tostring(h.itemID), kind = "gear",
      title = string.format("Mail yourself %s from %s", tostring(h.name), tostring(h.holder):match("^[^%-]+") or "an alt"),
      benefit = math.min(1, (tonumber(h.pct) or 0) / 20), confidence = 0.7, label = "observed", costCopper = 30,
      observedAt = tonumber(h.observedAt), -- when that character's bags were last saved
      why = string.format("About %d%% better than what you wear; it is in %s's %s.", math.floor(tonumber(h.pct) or 0),
        tostring(h.holder):match("^[^%-]+") or "an alt", tostring(h.where)) }
  end
  return out
end

-- Vanguard (VG03-06): your own prep actions, only while Group check (preview) is on
function A.VanguardPrep()
  local P = ns.Vanguard and ns.Vanguard.Plan
  return P and P.Candidates() or {}
end

function A:Resources(revision, now)
  return self:Collect(self.RESOURCES, revision, now, { deals = A.DealLots, handoffs = A.HandoffItems, vanguard = A.VanguardPrep })
end

-- everything, progression and resources, de-duplicated together
function A:All(revision, now)
  local names = {}
  for _, n in ipairs(self.PROGRESSION) do names[#names + 1] = n end
  for _, n in ipairs(self.RESOURCES) do names[#names + 1] = n end
  return self:Collect(names, revision, now, { levelroute = A.LevelRouteStep, deals = A.DealLots, handoffs = A.HandoffItems,
    vanguard = A.VanguardPrep })
end

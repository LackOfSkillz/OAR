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
--     upgrades another character holds, from saved inventories).
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
  local key = idPart(source .. ":" .. c.key):sub(1, 110)
  local rec = {
    opportunityId = "opp:" .. key, kind = kind, title = title, benefit = benefit,
    confidence = LABEL[c.label] or "unknown", evidenceIds = { ("ev:" .. key):sub(1, 120) },
    expiresAt = now + A.TTL, intent = c.go and "waypoint" or (c.panel and "panel") or "none",
    revision = revision or 1, legacyCandidateId = idPart(c.key):sub(1, 120), why = clean(c.why, 300),
  }
  local secs = tonumber(c.seconds)
  if secs and secs >= 0 and secs == secs then rec.costSeconds = math.min(31536000, math.floor(secs)) end
  local conf = clamp(c.confidence)
  if conf then rec.risk = 1 - conf end
  local cost = tonumber(c.costCopper)
  if cost and cost == cost then rec.costCopper = math.floor(cost) end
  local ok, field = ns.Nexus.Validate("Opportunity", rec)
  if not ok then return nil, "invalid " .. tostring(field) end
  return rec
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
        costCopper = lot.costCopper, why = tostring(lot.source or "live listing and vendor value") }
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
      why = string.format("About %d%% better than what you wear; it is in %s's %s.", math.floor(tonumber(h.pct) or 0),
        tostring(h.holder):match("^[^%-]+") or "an alt", tostring(h.where)) }
  end
  return out
end

function A:Resources(revision, now)
  return self:Collect(self.RESOURCES, revision, now, { deals = A.DealLots, handoffs = A.HandoffItems })
end

-- everything, progression and resources, de-duplicated together
function A:All(revision, now)
  local names = {}
  for _, n in ipairs(self.PROGRESSION) do names[#names + 1] = n end
  for _, n in ipairs(self.RESOURCES) do names[#names + 1] = n end
  return self:Collect(names, revision, now, { levelroute = A.LevelRouteStep, deals = A.DealLots, handoffs = A.HandoffItems })
end

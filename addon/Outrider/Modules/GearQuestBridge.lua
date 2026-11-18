-- Modules/GearQuestBridge.lua  (P6-07 GearQuest bridge)
-- GearQuest Forever (CurseForge project 1698950, by weber8210/Henrik8210,
-- installed with Gary's OK 2026-11-11) has no documented API, but exposes
-- its addon table as the global `GearQuest`. This module READS its picks
-- (read only, every call in pcall; GearQuest's frames are never touched):
--   GQ.Data:GetSlotsForClass(class) -> slot names
--   GQ.Data:GetCandidatesForSlot(slot) -> its filtered list for your level
--   GQ.Compare:RankEntries(list, slot, 1) -> its best pick for the slot
--   GQ.Data:GetItemFact(itemId) -> name, sourceType, zone, npc, questName
--   GQ.Data:NearestCoordinateSpot(itemId) + GQ.Map:ZoneMap(zone) -> waypoint
-- Picks join the Gear tab (Nearby) as source "GearQuest", scored with
-- Outrider's own weights so the list stays in one order. GearQuest's data is
-- "All Rights Reserved": nothing is copied or saved, it is read in game only.
-- If GearQuest changes and a call fails, the bridge turns itself off for
-- the session and says so in the log, never in chat.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("GearQuestBridge", {
  title = "GearQuest picks in the Gear tab",
  phase = "P6",
  order = 85,
  defaults = {},
})
ns.GearQuestBridge = M

M.SOURCE = { vendor = "sold by", quest_reward = "quest", drop = "dropped by", crafted = "crafted", world_drop = "world drop",
  boss_drop = "boss drop", profession = "crafted", reputation = "reputation reward", pvp = "PvP reward" }

function M:GQ()
  local gq = rawget(_G, "GearQuest")
  if type(gq) == "table" and type(gq.Data) == "table" and type(gq.Compare) == "table" then return gq end
end

local function call(obj, method, ...)
  local f = obj and obj[method]
  if type(f) ~= "function" then return nil end
  local ok, a, b = pcall(f, obj, ...)
  if ok then return a, b end
  M.broken = method
  M:Info("GearQuest call %s failed, bridge off this session: %s", method, tostring(a))
end

-- { {itemID, name, slot, kind = "gearquest", label, where = {mapID, x, y, who}} }
function M:Picks()
  local out = {}
  local gq = self:GQ()
  if not gq or self.broken then return out end
  local slots = call(gq.Data, "GetSlotsForClass", ns.PlayerClass()) or {}
  for _, slot in ipairs(slots) do
    if self.broken then break end
    local list = call(gq.Data, "GetCandidatesForSlot", slot)
    local ranked = type(list) == "table" and #list > 0 and call(gq.Compare, "RankEntries", list, slot, 1)
    local top = type(ranked) == "table" and ranked[1]
    local entry = type(top) == "table" and (top.entry or top)
    local id = type(entry) == "table" and tonumber(entry.itemId)
    if id then
      local fact = call(gq.Data, "GetItemFact", id) or {}
      local where = { who = fact.npc or fact.questName or fact.zone }
      local spot = call(gq.Data, "NearestCoordinateSpot", id)
      if type(spot) == "table" and spot.map and gq.Map then
        local mapID = call(gq.Map, "ZoneMap", spot.map)
        if type(mapID) == "number" and spot.x and spot.y then
          where.mapID, where.x, where.y = mapID, spot.x / 100, spot.y / 100
        end
      end
      out[#out + 1] = { itemID = id, name = fact.name or ("item " .. id), slot = slot, kind = "gearquest",
        -- never a raw token on screen ("boss_drop"): known words, else spaced out
        label = (M.SOURCE[fact.sourceType or ""] or (tostring(fact.sourceType or "GearQuest"):gsub("_", " "))), where = where,
        zone = fact.zone }
    end
  end
  return out
end

function M:Activity()
  if not self:GQ() then return "GearQuest Forever not installed" end
  if self.broken then return "GearQuest changed (" .. self.broken .. " failed); bridge off this session" end
  return "GearQuest picks show in the Gear tab"
end

-- One line at login: is GearQuest Forever loaded, and does it expose the
-- table the bridge reads? (audit 2026-11-15: it was enabled but never seen)
function M:OnEnable()
  self:On("PLAYER_ENTERING_WORLD", function(mod)
    if mod.reported then return end
    mod.reported = true
    local loaded = C.IsAddOnLoaded("GearQuestForever") or C.IsAddOnLoaded("GearQuest")
    mod:Info("GearQuest Forever loaded: %s; GearQuest table: %s; picks: %s", tostring(loaded and true or false),
      mod:GQ() and "yes" or "no", mod:GQ() and tostring(#(mod:Picks() or {})) or "-")
  end)
end

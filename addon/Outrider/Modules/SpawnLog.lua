-- Modules/SpawnLog.lua
-- What spawns at a watched rare's spot, in order (2026-11-13, to test a
-- theory: the other rare spawns, then 2 trash bears, then Mystmane; needs
-- evidence). While the player is near a spot where a watched rare has been
-- seen, every creature they see (nameplate, mouseover, target) is logged once
-- per spawn (its GUID), with the time first seen and the time it died
-- (seen dead, or its health hit 0). No combat log (hard rule 4).
-- ns.db.global.spawnLogs[rareNpcID] = { {name, npcID, guid, seen, died}, ... } (last 200)
-- At logout: the order and the gaps between a death and the next spawn.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("SpawnLog", {
  title = "Spawn log at watched rares' spots",
  phase = "P2",
  order = 35,
  defaults = { radius = 0.025 }, -- map fraction around the rare's spot (roughly 40-80 yards)
})
ns.SpawnLog = M

M.MAX = 200

function M:OnInitialize()
  local g = ns.db.global
  g.spawnLogs = type(g.spawnLogs) == "table" and g.spawnLogs or {}
  self.byGuid = {}
end

-- The watched rare whose spot Gary is standing near, or nil.
function M:SpotHere()
  local mapID, px, py = C.PlayerPosition("player")
  if not (mapID and px) then return nil end
  local scan = ns.Modules:Get("RareScan")
  local r = self:Settings().radius
  for npcID, list in pairs(ns.db.global.sightings or {}) do
    -- the rare's name from what Outrider recorded (its profile only exists once
    -- the rare itself was seen, so the spot was never recognized: 2026-11-13)
    local prof = ns.db.global.rareProfiles and ns.db.global.rareProfiles[npcID]
    local met = ns.db.global.discovered and ns.db.global.discovered.npcs and ns.db.global.discovered.npcs[npcID]
    local name = (prof and prof.name) or (met and met.name)
    if not scan or scan:IsWatched(npcID, name) then
      for _, s in ipairs(list) do
        if s.mapID == mapID and math.abs(s.x - px) < r and math.abs(s.y - py) < r then return npcID end
      end
    end
  end
  return nil
end

function M:Note(unit)
  if not C.Call("UnitExists", unit) or C.Call("UnitIsPlayer", unit) then return end
  local npcID, g = C.UnitNpcID(unit)
  if not npcID or not g or g.kind ~= "Creature" then return end
  local guid = C.Readable(C.Call("UnitGUID", unit))
  if type(guid) ~= "string" then return end
  local dead = C.Readable(C.Call("UnitIsDead", unit)) and true or false
  local e = self.byGuid[guid]
  if not e then
    local spot = self:SpotHere()
    if not spot then return end
    if C.Call("UnitIsFriend", "player", unit) then return end
    local list = ns.db.global.spawnLogs[spot] or {}
    ns.db.global.spawnLogs[spot] = list
    e = { name = C.Readable(C.Call("UnitName", unit)), npcID = npcID, guid = guid, seen = time(), spot = spot,
      deadAtFirst = dead or nil }
    list[#list + 1] = e
    while #list > M.MAX do table.remove(list, 1) end
    self.byGuid[guid] = e
    self:Debug("spawn log %s: %s first seen%s", tostring(spot), tostring(e.name), dead and " (already dead)" or "")
  end
  -- a nameplate can show before the name is known ("Unknown"): fill it in later
  if not e.name or e.name == "Unknown" then
    local nm = C.Readable(C.Call("UnitName", unit))
    if type(nm) == "string" and nm ~= "Unknown" then e.name = nm end
  end
  if dead and not e.died then e.died = time() end
end

function M:OnHealth(_, unit)
  if unit == "target" or (type(unit) == "string" and unit:find("^nameplate")) then
    local hp = C.Readable(C.Call("UnitHealth", unit))
    if hp == 0 then self:Note(unit) end
  end
end

-- "Mystmane spot: 11:11 Shadowgale Ursera (died 11:13), +10m46s, 11:25 ..."
function M:Summary(spot)
  local list = ns.db.global.spawnLogs[spot]
  if not list or #list == 0 then return nil end
  local parts, prevDeath = {}, nil
  for i = math.max(1, #list - 15), #list do
    local e = list[i]
    if prevDeath and not e.deadAtFirst then
      local gap = e.seen - prevDeath
      if gap >= 0 and gap < 7200 then parts[#parts + 1] = string.format("+%dm%02ds", math.floor(gap / 60), gap % 60) end
    end
    local name = e.name
    if not name or name == "Unknown" then
      local d = ns.db.global.discovered and ns.db.global.discovered.npcs and ns.db.global.discovered.npcs[e.npcID]
      name = d and d.name or name
    end
    parts[#parts + 1] = string.format("%s %s%s", date("%H:%M:%S", e.seen), tostring(name),
      e.died and (" (died " .. date("%H:%M:%S", e.died) .. ")") or "")
    prevDeath = e.died or prevDeath
  end
  local p = ns.db.global.rareProfiles and ns.db.global.rareProfiles[spot]
  return string.format("spawn log at %s's spot: %s", p and p.name or ("rare " .. spot), table.concat(parts, ", "))
end

function M:OnLogout()
  for spot in pairs(ns.db.global.spawnLogs) do
    local s = self:Summary(spot)
    if s then self:Info("%s", s) end
  end
end

function M:OnEnable()
  self:On("NAME_PLATE_UNIT_ADDED", function(mod, _, unit) mod:Note(unit) end)
  self:On("UPDATE_MOUSEOVER_UNIT", function(mod) mod:Note("mouseover") end)
  self:On("PLAYER_TARGET_CHANGED", function(mod) mod:Note("target") end)
  self:On("UNIT_HEALTH", self.OnHealth)
  self:On("PLAYER_LOGOUT", self.OnLogout)
end

function M:Activity()
  local n = 0
  for _, list in pairs(ns.db.global.spawnLogs) do n = n + #list end
  return string.format("%d spawns logged at watched rares' spots", n)
end

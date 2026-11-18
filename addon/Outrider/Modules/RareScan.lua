-- Modules/RareScan.lua
-- Notices rares from nameplates, target and mouseover (rares don't show as
-- vignettes on Forever, C9). A unit is a rare when its classification is
-- rare/rareelite, its npcID is in a rare pack, or it is on this character's
-- watchlist. Fires OTR_RARE_SEEN with:
--   { npcID, name, unit, how, mapID, x, y, layer, dead, level, family,
--     classification, tameable, pack }
-- Same npcID within `dedupe` seconds is not re-fired unless it went from
-- alive to dead (or back) or the layer changed. Nameplates are batched 4x/s.
-- In combat, classification may be a secret value (C6): then only pack and
-- watchlist rares are recognised.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("RareScan", {
  title = "Rare scanner",
  phase = "P2",
  order = 25,
  defaults = { dedupe = 60, watch = {} },
})

local RARE = { rare = true, rareelite = true }

function M:OnInitialize()
  self.last = {}
  self.pending = {}
end

function M:OnEnable()
  self:On("PLAYER_TARGET_CHANGED", function(mod) mod:Check("target", "target") end)
  self:On("UPDATE_MOUSEOVER_UNIT", function(mod) mod:Check("mouseover", "mouseover") end)
  self:On("NAME_PLATE_UNIT_ADDED", self.OnPlate)
  self:On("PLAYER_ENTERING_WORLD", self.CheckNameplateSetting)
  self:On("PLAYER_ENTERING_WORLD", function(mod) mod.vigSeen = {} mod:ScanVignettes() end)
  self:On("VIGNETTE_MINIMAP_UPDATED", self.ScanVignettes)
end

-- Minimap vignettes (the skull/star a rare can get): seen from much farther
-- than a nameplate (Gary, 2026-11-14: "sound an alarm when she spawns while I
-- camp"). C9 says rares may have none on Forever, so the first vignettes of a
-- session are logged to settle it. A vignette on a rare creature alerts like a
-- nameplate, with its exact position. Read-only.
function M:IsRareCreature(npcID, mapID, atlas)
  if ns.Data:Get("rare", npcID) or self:IsWatched(npcID) then return true end
  if type(atlas) == "string" and atlas:lower():find("kill") then return true end
  local mobs = ns.Finder and ns.Finder:Mobs()
  for _, r in ipairs(mobs and mapID and mobs[mapID] or {}) do
    if r[1] == npcID then return r[5] == 2 or r[5] == 4 end
  end
  return false
end

function M:ScanVignettes()
  local list = C.Call("C_VignetteInfo.GetVignettes")
  if type(list) ~= "table" then return end
  self.vigSeen = self.vigSeen or {}
  local mapID = C.PlayerPosition("player")
  for _, vg in ipairs(list) do
    if not self.vigSeen[vg] then
      local v = C.Call("C_VignetteInfo.GetVignetteInfo", vg)
      if type(v) == "table" then
        self.vigSeen[vg] = true
        local g = C.ParseGUID(C.Readable(v.objectGUID))
        self.vigLogged = (self.vigLogged or 0) + 1
        if self.vigLogged <= 20 then
          self:Info("vignette %s atlas=%s object=%s:%s", tostring(C.Readable(v.name)), tostring(v.atlasName),
            tostring(g and g.kind), tostring(g and g.id))
        end
        if g and g.kind == "Creature" and g.id and self:IsRareCreature(g.id, mapID, v.atlasName) then
          self:FromVignette(vg, v, g, mapID)
        end
      end
    end
  end
end

function M:FromVignette(vg, v, g, mapID)
  local now = GetTime and GetTime() or time()
  local inside = C.Call("IsInInstance")
  local layer = (not inside) and g.zoneUID or nil
  local prev = self.last[g.id]
  if prev and (now - prev.t) < (self:Settings().dedupe or 60) and not prev.dead and prev.layer == layer then return end
  self.last[g.id] = { t = now, dead = false, layer = layer }
  local x, y
  local pos = mapID and C.Call("C_VignetteInfo.GetVignettePosition", vg, mapID)
  if type(pos) == "table" and pos.GetXY then x, y = pos:GetXY() end
  local pack = ns.Data:Get("rare", g.id)
  local name = C.Readable(v.name)
  local info = {
    npcID = g.id, name = type(name) == "string" and name or (pack and pack.name), how = "vignette",
    mapID = mapID, x = x, y = y, exact = x ~= nil, layer = layer, dead = false,
    tameable = pack and pack.beast and pack.beast.tameable or nil, pack = pack and true or false,
    watched = self:IsWatched(g.id, name), t = time(),
  }
  self:Info("rare seen npcID=%d %s how=vignette layer=%s map=%s %s", g.id, tostring(info.name), tostring(layer),
    tostring(mapID), x and string.format("%.3f,%.3f", x, y) or "nopos")
  ns.Events:Fire("OTR_RARE_SEEN", info)
  return info
end

function M:OnDisable()
  ns.ThrottleCancel("rarescan:plates")
  self.pending = {}
end

-- Rares are usually hostile or neutral beasts; without enemy nameplates the
-- scanner only sees what Gary targets or mouses over. Tell him once.
function M:CheckNameplateSetting()
  if self.toldNameplates then return end
  local v = C.Call("C_CVar.GetCVar", "nameplateShowEnemies")
  if v == nil then v = C.Call("GetCVar", "nameplateShowEnemies") end
  if v == "0" then
    self.toldNameplates = true
    self:Warn("enemy nameplates are off: rares are only seen on target/mouseover")
    ns.Print("enemy nameplates are off, so rares are only noticed when you target or mouse over them. Press V (or Options > Nameplates) to turn them on.")
  end
end

function M:OnPlate(_, unit)
  if type(unit) ~= "string" then return end
  self.pending[unit] = true
  ns.Throttle("rarescan:plates", 0.25, function() M:FlushPlates() end)
end

function M:FlushPlates()
  local units = self.pending
  self.pending = {}
  for unit in pairs(units) do self:Check(unit, "nameplate") end
end

-- Watchlist entries are npcIDs (number keys) or lowercase names (string keys).
function M:IsWatched(npcID, name)
  local w = self:Settings().watch
  if npcID and w[npcID] then return true end
  if type(name) == "string" and w[name:lower()] then return true end
  return false
end

function M:Watch(key, on)
  local w = self:Settings().watch
  local id = tonumber(key)
  local k = id or (type(key) == "string" and key:lower()) or nil
  if k == nil then return false end
  w[k] = on and true or nil
  return true, k
end

function M:Classify(unit)
  if not C.Call("UnitExists", unit) or C.Call("UnitIsPlayer", unit) then return nil end
  local npcID, g = C.UnitNpcID(unit)
  if not npcID or not g or g.kind ~= "Creature" then return nil end
  local name = C.Readable(C.Call("UnitName", unit))
  local classification = C.Readable(C.Call("UnitClassification", unit))
  local pack = ns.Data:Get("rare", npcID)
  local watched = self:IsWatched(npcID, name or (pack and pack.name))
  if not (RARE[classification or ""] or pack or watched) then return nil end
  return npcID, g, name or (pack and pack.name), classification, pack, watched
end

function M:Check(unit, how)
  local npcID, g, name, classification, pack, watched = self:Classify(unit)
  if not npcID then return nil end
  local dead = C.Readable(C.Call("UnitIsDead", unit)) and true or false
  local inside = C.Call("IsInInstance")
  local layer = (not inside) and g.zoneUID or nil
  local now = GetTime and GetTime() or time()

  local prev = self.last[npcID]
  local dedupe = self:Settings().dedupe or 60
  if prev and (now - prev.t) < dedupe and prev.dead == dead and prev.layer == layer then
    return nil, "dedupe"
  end
  self.last[npcID] = { t = now, dead = dead, layer = layer }

  local mapID, x, y = C.PlayerPosition("player")
  local family = C.Readable(C.Call("UnitCreatureFamily", unit))
  local tameable
  if pack and pack.beast and pack.beast.tameable ~= nil then tameable = pack.beast.tameable
  else tameable = family ~= nil end
  local level = C.Readable(C.Call("UnitLevel", unit))
  local info = {
    npcID = npcID, name = name, unit = unit, how = how, mapID = mapID, x = x, y = y, layer = layer,
    dead = dead, level = type(level) == "number" and level or nil, family = family,
    classification = classification, tameable = tameable, pack = pack and true or false,
    watched = watched, t = time(),
  }
  self:Info("rare seen npcID=%d %s how=%s layer=%s dead=%s map=%s %s", npcID, tostring(name), how,
    tostring(layer), tostring(dead), tostring(mapID), x and string.format("%.3f,%.3f", x, y) or "nopos")
  ns.Events:Fire("OTR_RARE_SEEN", info)
  return info
end

-- DEEP-21: rare-route planner from the *already visible map pin set*.
-- No invented spawns; every stop comes from a rare pin in the active map.
function M:Route(mapID, watchedOnly)
  if not (mapID and ns.MapPins and ns.Waypoints) then return {}, "no current map" end
  local s = ns.Waypoints:Settings()
  local queue = s.queue or {}
  local capacity = math.max(0, (ns.Waypoints.QUEUE_MAX or 30) - #queue)
  if capacity == 0 then return {}, "waypoint queue full" end
  local list, seen = {}, {}
  for _, p in ipairs(ns.MapPins:BuildPins(mapID)) do
    local isRare = p.kind == "rare" and type(p.x) == "number" and type(p.y) == "number"
    if isRare and (not watchedOnly or self:IsWatched(p.npcID, p.name)) then
      local key = string.format("%d:%d", math.floor(p.x * 10000 + 0.5), math.floor(p.y * 10000 + 0.5))
      if not seen[key] then
        seen[key] = true
        list[#list + 1] = p
      end
    end
  end
  local _, x, y = C.PlayerPosition("player")
  x, y = x or 0.5, y or 0.5
  local result = {}
  while #list > 0 and #result < capacity do
    local best, bestD
    for i, p in ipairs(list) do
      local d = (p.x - x) ^ 2 + (p.y - y) ^ 2
      if not bestD or d < bestD then best, bestD = i, d end
    end
    local p = table.remove(list, best)
    local ok = ns.Waypoints:QueueAdd(mapID, p.x, p.y, p.name)
    if not ok then break end
    result[#result + 1] = p
    x, y = p.x, p.y
  end
  return result
end

ns.AddCommand("rareroute", "rareroute all|watched  queue nearest known rare spawns on this map", function(arg)
  local watched = tostring(arg or ""):lower() == "watched"
  local mapID = C.PlayerPosition("player")
  local list, why = M:Route(mapID, watched)
  ns.Print("rare route: %d known spawn points queued%s", #list, why and (" (" .. why .. ")") or "")
  if #list > 0 then ns.Print("use /ride way start to begin, /ride way next to skip") end
end)

ns.AddCommand("watch", "<name or npcID>  alert for this NPC on this character", function(arg)
  if not arg then ns.Print("usage: /ride watch <name or npcID>") return end
  local ok, k = M:Watch(arg, true)
  if ok then ns.Print("watching %s on %s", tostring(k), ns.db.key) M:Info("watch add %s", tostring(k)) end
end)

ns.AddCommand("unwatch", "<name or npcID>  stop watching", function(arg)
  if not arg then ns.Print("usage: /ride unwatch <name or npcID>") return end
  local ok, k = M:Watch(arg, false)
  if ok then ns.Print("stopped watching %s", tostring(k)) end
end)

-- P9-01: what the advisor needs (plain data)
function M:Snapshot()
  local watch = {}
  for k in pairs(self:Settings().watch) do watch[#watch + 1] = k end
  table.sort(watch, function(a, b) return tostring(a) < tostring(b) end)
  return { watch = watch }
end

function M:Activity()
  local n, watch = 0, {}
  for _ in pairs(self.last) do n = n + 1 end
  for k in pairs(self:Settings().watch) do watch[#watch + 1] = ns.TitleCase(k) end
  table.sort(watch)
  return string.format("%d rares seen this session%s", n, #watch > 0 and ("; watching " .. table.concat(watch, ", ")) or "")
end

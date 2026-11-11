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

function M:Activity()
  local n, watch = 0, {}
  for _ in pairs(self.last) do n = n + 1 end
  for k in pairs(self:Settings().watch) do watch[#watch + 1] = tostring(k) end
  table.sort(watch)
  return string.format("%d rares seen this session%s", n, #watch > 0 and ("; watching " .. table.concat(watch, ", ")) or "")
end

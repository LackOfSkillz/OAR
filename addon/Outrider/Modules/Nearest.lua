-- Modules/Nearest.lua  (P3-07)
-- /ride near <kind>: nearest known place of that kind on this continent
-- (world yards), same faction or neutral, sets a waypoint and says how far.
-- When dead, a corpse arrow uses the actual corpse position from
-- C_DeathInfo.GetCorpseMapPosition; the nearest spirit healer is NOT the
-- guaranteed respawn point (Forever graveyards depend on subzones).
-- No corpse coordinates: preserve the previous waypoint and report unknown.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Nearest", {
  title = "Nearest place (/ride near)",
  phase = "P3",
  order = 52,
  defaults = { spiritOnDeath = false, corpseArrow = true },
})
ns.Nearest = M

M.ALIASES = {
  spirit = "spirit_healer", healer = "spirit_healer", flight = "flight_master", fly = "flight_master",
  vendor = "vendor", repair = "repair", trainer = "trainer", mail = "mailbox", mailbox = "mailbox",
  bank = "bank", ah = "auction", auction = "auction", stable = "stable_master",
  inn = "innkeeper", innkeeper = "innkeeper", guild = "guild_master", tabard = "tabard",
  ammo = "ammo", arrows = "ammo", bullets = "ammo", -- a vendor whose goods include ammo (POICapture)
}

function M:OnEnable()
  self:On("PLAYER_DEAD", self.OnDead)
  self:On("PLAYER_ALIVE", self.OnAlive)
  self:On("PLAYER_UNGHOST", self.OnResurrected)
  self:On("OTR_WAYPOINT_CLEARED", function(mod, _, w, why)
    if w == mod.corpseWP and why == "arrived" then mod.corpseArrived = true end
  end)
end

function M:OnDisable()
  self:StopCorpsePolling()
  self.dead = nil
end

function M:StopCorpsePolling()
  if self.corpseTicker then self.corpseTicker:Cancel() self.corpseTicker = nil end
end

-- Modern Forever API. The old global GetCorpseMapPosition was removed.
-- Readable vector2 is required; never run numeric operations on secret values.
function M:CorpsePosition()
  local mapID = C.PlayerPosition("player")
  if not mapID then return nil end
  local pos = C.Call("C_DeathInfo.GetCorpseMapPosition", mapID)
  if not pos then return nil end
  local x, y
  if type(pos) == "table" and type(pos.GetXY) == "function" then
    local ok, a, b = pcall(pos.GetXY, pos)
    if ok then x, y = a, b end
  elseif type(pos) == "table" then
    x, y = pos.x, pos.y
  end
  x, y = tonumber(C.Readable(x)), tonumber(C.Readable(y))
  if not (x and y and x > 0 and x < 1 and y > 0 and y < 1) then return nil end
  return mapID, x, y
end

function M:TryCorpse()
  if not self.dead or self.corpseWP or not self:Settings().corpseArrow then return false end
  local mapID, x, y = self:CorpsePosition()
  if not mapID then return false end
  local W = ns.Waypoints
  if not W then return false end
  local ok, wp = W:Set(mapID, x, y, "Your corpse")
  if not ok then return false end
  self.corpseWP = wp
  self:StopCorpsePolling()
  self:Info("corpse arrow on map %d at %.1f, %.1f", mapID, x * 100, y * 100)
  return true
end

function M:PollCorpse()
  if self:TryCorpse() then return end
  self.corpseAttempts = (self.corpseAttempts or 0) + 1
  if self.corpseAttempts >= 15 then
    self:StopCorpsePolling()
    self:Info("corpse location unavailable; old waypoint was left unchanged")
  end
end

function M:OnAlive()
  if not self.dead and not C.Call("UnitIsGhost", "player") then return end
  self.dead = true
  if self:TryCorpse() then return end
  if not self.corpseTicker then
    self.corpseAttempts = 0
    self.corpseTicker = ns.Timer.Ticker(2, function() M:PollCorpse() end, "nearest:corpse")
  end
end

function M:OnResurrected()
  self:StopCorpsePolling()
  local W = ns.Waypoints
  -- Only touch our own corpse waypoint. If the player changed it, leave it.
  local ownCorpse = self.corpseWP and W and W.current == self.corpseWP
  local arrivedCorpse = self.corpseArrived and W and W.current == nil
  if ownCorpse or arrivedCorpse then
    if ownCorpse then W:Clear("resurrected") end
    local previous = self.savedWaypoint
    if previous then W:Set(previous.mapID, previous.x, previous.y, previous.title, previous.opts) end
  end
  self.corpseWP, self.corpseArrived, self.savedWaypoint, self.dead, self.corpseAttempts = nil, nil, nil, nil, nil
end

-- Returns poi, yards (or nil, reason).
function M:Find(kind)
  local W = ns.Waypoints
  local mapID = C.PlayerPosition("player")
  local _, px, py = W.PlayerWorldPos()
  if not (mapID and px) then return nil, "your position is unknown here" end
  local here = W.WorldPos(mapID, 0.5, 0.5)
  local faction = C.Call("UnitFactionGroup", "player")
  local best, bestD
  local candidates = {}
  for _, p in pairs(ns.db.global.pois or {}) do candidates[#candidates + 1] = p end
  -- "class_trainer": a trainer whose title names this character's class
  local want = kind == "class_trainer" and "trainer" or kind
  local cls = kind == "class_trainer" and tostring(C.Call("UnitClass", "player") or ""):lower() or nil
  if ns.NPCPack then
    for _, p in ipairs(ns.NPCPack:OfKind(want)) do candidates[#candidates + 1] = { kind = want, mapID = p.mapID,
      x = p.x, y = p.y, name = p.name, title = p.title, faction = p.faction } end
  end
  for _, p in ipairs(candidates) do
    local match = p.kind == want
    if match and cls then
      match = cls ~= "" and tostring(p.title or ""):lower():find(cls .. " trainer", 1, true) ~= nil
    end
    if kind == "ammo" then
      match = false
      for _, g in ipairs(p.goods or {}) do if g == "ammo" then match = true end end
    end
    if match and (p.faction == nil or p.faction == faction) then
      local cont, wx, wy = W.WorldPos(p.mapID, p.x, p.y)
      if wx and cont == here then
        local d = math.sqrt((wx - px) ^ 2 + (wy - py) ^ 2)
        if not bestD or d < bestD then best, bestD = p, d end
      end
    end
  end
  if not best then return nil, "no " .. (cls and (cls .. " trainer") or kind:gsub("_", " ")) .. " known on this continent yet" end
  return best, bestD
end

function M:Go(kind)
  local p, d = self:Find(kind)
  if not p then return false, d end
  ns.Waypoints:Set(p.mapID, p.x, p.y, p.name or kind)
  self:Info("nearest %s: %s %.0f yards", kind, tostring(p.name), d)
  return true, string.format("%s, %d yards. Waypoint set.", p.name or kind, math.floor(d + 0.5))
end

function M:OnDead()
  self:StopCorpsePolling()
  self.dead, self.corpseWP, self.corpseArrived, self.corpseAttempts = true, nil, nil, 0
  local W = ns.Waypoints
  local w = W and W.current
  self.savedWaypoint = w and { mapID = w.mapID, x = w.x, y = w.y, title = w.title, opts = w.opts } or nil
  -- The corpse often becomes addressable only after release. Do not replace
  -- a player waypoint with an incorrect nearest-graveyard guess.
  self:TryCorpse()
end

function M:Activity()
  return "/ride near spirit|flight|vendor|repair|trainer|mail|bank|ah|stable|inn|guild"
end

ns.AddCommand("near", "<spirit|flight|vendor|repair|trainer|mail|bank|ah|stable|inn|guild|ammo>  waypoint to the nearest one", function(arg)
  local kind = M.ALIASES[(arg or ""):lower()]
  if not kind then ns.Print("usage: /ride near spirit|flight|vendor|repair|trainer|mail|bank|ah|stable|inn|guild|ammo") return end
  local _, msg = M:Go(kind)
  ns.Print(msg)
end)

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

function M:OnInitialize()
  local global = ns.db.global
  global.graveyards = type(global.graveyards) == "table" and global.graveyards or {}
  self.graveyards = global.graveyards
end

M.ALIASES = {
  spirit = "spirit_healer", healer = "spirit_healer", flight = "flight_master", fly = "flight_master",
  vendor = "vendor", repair = "repair", trainer = "trainer", mail = "mailbox", mailbox = "mailbox",
  bank = "bank", ah = "auction", auction = "auction", stable = "stable_master",
  inn = "innkeeper", innkeeper = "innkeeper", guild = "guild_master", tabard = "tabard",
  ammo = "ammo", arrows = "ammo", bullets = "ammo", -- a vendor whose goods include ammo (POICapture)
  class = "class_trainer", -- your own class trainer (Map and places, 2026-11-20)
}

function M:OnEnable()
  self:On("PLAYER_DEAD", self.OnDead)
  self:On("PLAYER_ALIVE", self.OnAlive)
  self:On("PLAYER_ALIVE", function(mod)
    if C.Readable(C.Call("UnitIsGhost", "player")) == true then
      mod:ConfirmDeath()
      mod:RecordGhostSpawn()
    end
  end)
  self:On("PLAYER_UNGHOST", self.OnResurrected)
  self:On("PLAYER_UNGHOST", function(mod)
    if mod.deathLog and mod.deathLog.confirmed then mod:FinishDeathLog()
    else mod.deathLog = nil end
    mod.pendingDeath = nil
  end)
  self:On("OTR_WAYPOINT_CLEARED", function(mod, _, w, why)
    if w == mod.corpseWP and why == "arrived" then mod.corpseArrived = true end
  end)
end

-- DEEP-18: learn graveyard destinations from real ghost respawns.
-- Never choose a location based on nearest Euclidean spirit healer:
-- Forever's subzone bindings may choose a farther graveyard.
function M:GraveyardKey(mapID, subzone)
  if type(mapID) ~= "number" or type(subzone) ~= "string" then return nil end
  return tostring(mapID) .. ":" .. subzone:lower()
end

function M:PredictedGraveyard(mapID, subzone)
  local key = self:GraveyardKey(mapID, subzone)
  local observations = key and self.graveyards and self.graveyards[key]
  if type(observations) ~= "table" then return nil end
  local top
  for _, g in pairs(observations) do
    if not top or (g.count or 0) > (top.count or 0) then top = g end
  end
  return top and { mapID = top.mapID, x = top.x, y = top.y, count = top.count,
    confidence = "observed, not guaranteed", subzone = subzone } or nil
end

function M:RecordGhostSpawn()
  if not self.deathLog or not self.deathLog.confirmed or self.deathLog.spawn
    or C.Readable(C.Call("UnitIsGhost", "player")) ~= true then return false end
  local mapID, x, y = C.PlayerPosition("player")
  if not (mapID and type(x) == "number" and type(y) == "number") then return false end
  local log = self.deathLog
  log.spawn = { mapID = mapID, x = x, y = y }
  local key = self:GraveyardKey(log.mapID, log.subzone)
  if key then
    local locations = self.graveyards[key] or {}
    local name = tostring(mapID) .. ":" .. math.floor(x * 100 + 0.5) .. ":" .. math.floor(y * 100 + 0.5)
    local entry = locations[name] or { mapID = mapID, x = x, y = y, count = 0 }
    entry.count = entry.count + 1
    locations[name] = entry
    self.graveyards[key] = locations
  end
  local p = log.predicted
  log.correct = p and p.mapID == mapID and math.abs(p.x - x) < 0.02 and math.abs(p.y - y) < 0.02 or nil
  self:Info("graveyard observed: death %s map %s -> ghost map %d %.1f,%.1f; prior prediction %s",
    tostring(log.subzone), tostring(log.mapID), mapID, x * 100, y * 100,
    log.predicted and (log.correct and "matched" or "different") or "unavailable")
  return true
end

function M:FinishDeathLog()
  if self.deathLog then
    ns.db.global.deathHistory = ns.db.global.deathHistory or {}
    local history = ns.db.global.deathHistory
    history[#history + 1] = self.deathLog
    while #history > 100 do table.remove(history, 1) end
  end
  self.deathLog = nil
end

function M:OnDisable()
  self.pendingDeath = nil
  if self.pendingDeathTimer then self.pendingDeathTimer:Cancel() self.pendingDeathTimer = nil end
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
  if C.Readable(C.Call("UnitIsGhost", "player")) == true then
    self:ConfirmDeath()
  end
  if not self.dead and C.Readable(C.Call("UnitIsGhost", "player")) ~= true then return end
  self.dead = true
  if self:TryCorpse() then return end
  if not self.corpseTicker then
    self.corpseAttempts = 0
    self.corpseTicker = ns.Timer.Ticker(2, function() M:PollCorpse() end, "nearest:corpse")
  end
end

function M:OnResurrected()
  self.pendingDeath = nil
  if self.pendingDeathTimer then self.pendingDeathTimer:Cancel() self.pendingDeathTimer = nil end
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
  -- "class_trainer": a trainer whose title names this character's class;
  -- "trainer:<what>": a trainer whose title says it ("trainer:fishing" ->
  -- Fishing Trainer, "trainer:weapon master" -> Weapon Master; 2026-11-20)
  local want = (kind == "class_trainer" or kind:match("^trainer:")) and "trainer" or kind
  local cls = kind == "class_trainer" and tostring(C.Call("UnitClass", "player") or ""):lower() or nil
  local titled = kind:match("^trainer:(.+)$")
  if titled and not (titled:find("trainer", 1, true) or titled:find("master", 1, true)) then titled = titled .. " trainer" end
  -- trust: places you recorded, then the leveling guides, then the NPC pack
  -- (Gary, 2026-11-20: the pack had the fishing trainer in the wrong spot)
  local named = {}
  for _, p in ipairs(candidates) do if p.name then named[p.name] = true end end
  for _, g in ipairs(ns.Data:All("place")) do
    local mapID = g.kind == want and not named[g.name] and ns.Travel and ns.Travel:MapByName(g.zone)
    if mapID then
      candidates[#candidates + 1] = { kind = want, mapID = mapID, x = g.x, y = g.y, name = g.name, title = g.title, faction = g.faction, guide = true }
      named[g.name] = true
    end
  end
  if ns.NPCPack then
    for _, p in ipairs(ns.NPCPack:OfKind(want)) do
      if not named[p.name] then candidates[#candidates + 1] = { kind = want, mapID = p.mapID,
        x = p.x, y = p.y, name = p.name, title = p.title, faction = p.faction } end
    end
  end
  for _, p in ipairs(candidates) do
    local match = p.kind == want
    if match and cls then
      match = cls ~= "" and tostring(p.title or ""):lower():find(cls .. " trainer", 1, true) ~= nil
    end
    if match and titled then
      match = tostring(p.title or ""):lower():find(titled, 1, true) ~= nil
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
  if not best then return nil, "no " .. (cls and (cls .. " trainer") or titled or kind:gsub("_", " ")) .. " known on this continent yet" end
  return best, bestD
end

function M:Go(kind)
  local p, d = self:Find(kind)
  if not p then return false, d end
  ns.Waypoints:Set(p.mapID, p.x, p.y, p.name or kind)
  self:Info("nearest %s: %s %.0f yards", kind, tostring(p.name), d)
  return true, string.format("%s, %d yards. Waypoint set.", p.name or kind, math.floor(d + 0.5))
end

-- NEW-11: record a death only after a real ghost or dead state.
-- Feign Death may emit death-like events while still alive. A false event
-- must never contaminate graveyard learning, death history, or corpse routing.
function M:ActualDeath()
  -- Feign Death's spell ID is 5384. Treat positive detection as a veto,
  -- even if a client reports UnitIsDead during the feign animation.
  if C.Readable(C.Call("UnitIsFeignDeath", "player")) == true then return false end
  local feign = C.Call("C_UnitAuras.GetPlayerAuraBySpellID", 5384)
  if type(feign) == "table" then return false end -- queried specifically for Feign Death (5384)
  local ghost = C.Readable(C.Call("UnitIsGhost", "player"))
  if ghost == true then return true end
  local dead = C.Readable(C.Call("UnitIsDeadOrGhost", "player"))
  if dead == true then return true end
  dead = C.Readable(C.Call("UnitIsDead", "player"))
  return dead == true
end

function M:ConfirmDeath()
  if not self:ActualDeath() then return false end
  if self.deathLog and self.deathLog.confirmed then return true end
  local context = self.pendingDeath or {}
  self.pendingDeath = nil
  if self.pendingDeathTimer then self.pendingDeathTimer:Cancel() self.pendingDeathTimer = nil end
  self:StopCorpsePolling()
  self.dead, self.corpseWP, self.corpseArrived, self.corpseAttempts = true, nil, nil, 0
  local mapID = context.mapID or C.PlayerPosition("player")
  local subzone = context.subzone or C.Readable(C.Call("GetSubZoneText"))
  self.deathLog = { t = context.t or time(), mapID = mapID, subzone = subzone,
    predicted = self:PredictedGraveyard(mapID, subzone), confirmed = true }
  local W = ns.Waypoints
  local w = W and W.current
  self.savedWaypoint = w and { mapID = w.mapID, x = w.x, y = w.y, title = w.title, opts = w.opts } or nil
  self:TryCorpse()
  return true
end

function M:OnDead()
  if self:ConfirmDeath() then return end
  -- A death event can arrive before the client updates UnitIsDead*. Retain
  -- only its origin briefly; do not record until a later state confirms it.
  self.pendingDeath = { t = time(), mapID = C.PlayerPosition("player"),
    subzone = C.Readable(C.Call("GetSubZoneText")) }
  if self.pendingDeathTimer then self.pendingDeathTimer:Cancel() end
  self.pendingDeathTimer = ns.Timer.After(0.3, function()
    M.pendingDeathTimer = nil
    if not M.enabled or not M.pendingDeath then return end
    if not M:ConfirmDeath() then
      M.pendingDeath = nil
      M:Info("ignored death-like event: player not dead or a ghost (possible Feign Death)")
    end
  end, "nearest:confirm-death")
end

function M:Activity()
  return "/ride near spirit|flight|vendor|repair|trainer|mail|bank|ah|stable|inn|guild"
end

ns.AddCommand("near", "<spirit|flight|vendor|repair|trainer|mail|bank|ah|stable|inn|guild|ammo>  waypoint to the nearest one", function(arg)
  -- "/ride near trainer fishing": a trainer for that profession or role
  local what = (arg or ""):lower():match("^trainer%s+(.+)$")
  if what then local _, msg = M:Go("trainer:" .. what) ns.Print(msg) return end
  local kind = M.ALIASES[(arg or ""):lower()]
  if not kind then ns.Print("usage: /ride near spirit|flight|vendor|repair|trainer|mail|bank|ah|stable|inn|guild|ammo") return end
  local _, msg = M:Go(kind)
  ns.Print(msg)
end)

ns.AddCommand("grave", "grave  observed subzone-specific graveyard prediction", function()
  local mapID = C.PlayerPosition("player")
  local subzone = C.Readable(C.Call("GetSubZoneText"))
  local g = M:PredictedGraveyard(mapID, subzone)
  if not g then
    ns.Print("graveyard for %s: no verified ghost-spawn observations yet; nearest healer is not a prediction",
      tostring(subzone or "unknown subzone"))
  else
    ns.Print("observed ghost spawn for %s: map %d at %.1f %.1f (%d observations; not guaranteed)",
      subzone, g.mapID, g.x * 100, g.y * 100, g.count)
  end
end)

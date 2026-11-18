-- Modules/Layers.lua
-- Which layer (server copy of the zone) are we on? Creature GUIDs carry a
-- zone UID that is the same for every creature on one layer of a zone (the
-- LayerTracker idea, C12). We keep the last WINDOW creatures seen in the
-- current zone; the most common zone UID is the layer when it holds at least
-- SHARE of a window of at least MIN creatures.
-- Fires OTR_LAYER_CHANGED(newID, oldID, confidence). Display label "L<last 3 digits>".
-- Read-only, open world only (instances have their own copies, not layers).

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Layers", {
  title = "Layer detection",
  phase = "P2",
  order = 22,
  defaults = { history = {} },
})
ns.Layers = M

M.WINDOW, M.MIN, M.SHARE = 20, 3, 0.6
M.HISTORY_MAX = 40

function M:OnInitialize()
  self:Reset()
end

function M:Reset()
  self.seen, self.window = {}, {}
  self.current, self.confidence = nil, 0
  self.mapID = nil
end

function M:OnEnable()
  self:On("PLAYER_TARGET_CHANGED", function(mod) mod:Observe("target") end)
  self:On("UPDATE_MOUSEOVER_UNIT", function(mod) mod:Observe("mouseover") end)
  self:On("NAME_PLATE_UNIT_ADDED", function(mod, _, unit) mod:Observe(unit) end)
  self:On("ZONE_CHANGED_NEW_AREA", function(mod) mod:ZoneChanged() end)
  self:On("PLAYER_ENTERING_WORLD", function(mod) mod:ZoneChanged() end)
end

-- Different maps can reuse or remap zone UIDs. Never show the previous
-- zone's layer as current while waiting for fresh creature evidence.
function M:ZoneChanged()
  self.window, self.seen = {}, {}
  self.mapID = C.PlayerPosition("player")
  self.current, self.confidence = nil, 0
end

function M:Observe(unit)
  if type(unit) ~= "string" or C.Call("IsInInstance") then return end
  if C.Call("UnitIsPlayer", unit) then return end
  local _, g = C.UnitNpcID(unit)
  if not g or g.kind ~= "Creature" or not g.zoneUID or not g.spawnUID then return end
  -- Count each creature once per window, or one big pack would outvote the rest.
  if self.seen[g.spawnUID] then return end
  self.seen[g.spawnUID] = true
  local w = self.window
  w[#w + 1] = { uid = g.zoneUID, spawn = g.spawnUID }
  while #w > self.WINDOW do
    local old = table.remove(w, 1)
    self.seen[old.spawn] = nil
  end
  self:Evaluate()
end

-- Keep bounded, per-character visit history; identical observations refresh
-- at most once every 30 seconds so the saved file remains small.
function M:Remember(id, confidence)
  if not (self.mapID and id) then return end
  local settings = self:Settings()
  local history = settings.history
  if type(history) ~= "table" then history = {} settings.history = history end
  local now = time()
  for i = #history, 1, -1 do
    local h = history[i]
    if type(h) ~= "table" then
      table.remove(history, i)
    elseif h.mapID == self.mapID and h.id == id then
      if now - (tonumber(h.at) or 0) < 30 then return end
      table.remove(history, i)
    end
  end
  history[#history + 1] = { id = id, mapID = self.mapID, at = now, confidence = confidence }
  while #history > self.HISTORY_MAX do table.remove(history, 1) end
end

function M:History(mapID, limit)
  local history = self:Settings().history or {}
  local out = {}
  for i = #history, 1, -1 do
    local h = history[i]
    if type(h) == "table" and (not mapID or h.mapID == mapID) then
      out[#out + 1] = h
      if #out >= (limit or 8) then break end
    end
  end
  return out
end

function M:Evaluate()
  local w = self.window
  if #w < self.MIN then return end
  local counts, best, bestN = {}, nil, 0
  for _, o in ipairs(w) do
    counts[o.uid] = (counts[o.uid] or 0) + 1
    if counts[o.uid] > bestN then best, bestN = o.uid, counts[o.uid] end
  end
  local share = bestN / #w
  if share < self.SHARE then self.confidence = 0 return end
  self.confidence = share
  if best ~= self.current then
    local old = self.current
    self.current = best
    if old then
      self:Info("layer changed %s -> %s (%.0f%% of %d creatures, map %s)", self.Label(old), self.Label(best),
        share * 100, #w, tostring(self.mapID))
      ns.Events:Fire("OTR_LAYER_CHANGED", best, old, share)
    else
      self:Info("layer %s (%.0f%% of %d creatures, map %s)", self.Label(best), share * 100, #w, tostring(self.mapID))
    end
  end
  self:Remember(best, share)
end

function M.Label(id)
  if not id then return "?" end
  return string.format("Layer %d", id % 1000) -- "Layer 21", not "L021" (premium plan S5)
end

-- Current layer id, confidence 0..1, display label.
function M:Current()
  if C.Call("IsInInstance") then return nil, 0, "?" end
  local mapID = C.PlayerPosition("player")
  if mapID and self.mapID and mapID ~= self.mapID then return nil, 0, "?" end
  if not self.current or self.confidence < self.SHARE then return nil, self.confidence, "?" end
  return self.current, self.confidence, self.Label(self.current)
end

function M:Snapshot()
  local id, confidence, label = self:Current()
  return { layer = id, label = label, confidence = confidence }
end

function M:Activity()
  local id, conf, label = self:Current()
  if not id then return string.format("learning (%d of %d mobs seen)", #self.window, self.MIN) end
  return string.format("you are on %s (%.0f%% sure)", label, conf * 100)
end

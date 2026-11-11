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
  defaults = {},
})
ns.Layers = M

M.WINDOW, M.MIN, M.SHARE = 20, 3, 0.6

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

-- A new zone has its own zone UIDs: start the window over, but keep the
-- last known layer id so a change can still be reported against it.
function M:ZoneChanged()
  self.window, self.seen = {}, {}
  self.mapID = C.PlayerPosition("player")
  self.confidence = 0
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

function M:Evaluate()
  local w = self.window
  if #w < self.MIN then return end
  local counts, best, bestN = {}, nil, 0
  for _, o in ipairs(w) do
    counts[o.uid] = (counts[o.uid] or 0) + 1
    if counts[o.uid] > bestN then best, bestN = o.uid, counts[o.uid] end
  end
  local share = bestN / #w
  if share < self.SHARE then return end
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
end

function M.Label(id)
  if not id then return "?" end
  return string.format("L%03d", id % 1000)
end

-- Current layer id, confidence 0..1, display label.
function M:Current()
  return self.current, self.confidence, self.Label(self.current)
end

function M:Snapshot()
  return { layer = self.current, label = self.Label(self.current), confidence = self.confidence }
end

-- Core/Combat.lua
-- Protected frames (secure buttons, action bars, unit frames) cannot be
-- created, moved, shown or hidden in combat. Anything that touches them goes
-- through ns.Combat:Run(fn): runs now if safe, otherwise after combat ends.

local _, ns = ...
local Combat = { name = "combat", queue = {}, keyed = {}, MAX = 100 }
ns.Combat = Combat

function Combat:InLockdown()
  return ns.Compat.InCombat()
end

-- key (optional) collapses repeated requests: only the latest fn per key runs.
function Combat:Run(label, fn, key)
  if not self:InLockdown() then
    return ns.Safe(label, fn)
  end
  if key then
    if self.keyed[key] then self.keyed[key].fn = fn return false end
    local item = { label = label, fn = fn, key = key }
    self.keyed[key] = item
    self.queue[#self.queue + 1] = item
  else
    self.queue[#self.queue + 1] = { label = label, fn = fn }
  end
  -- A runaway producer must not grow the queue forever: drop the oldest.
  while #self.queue > self.MAX do
    local dropped = table.remove(self.queue, 1)
    if dropped.key then self.keyed[dropped.key] = nil end
    if ns.Log then ns.Log:Warn("combat", "queue full, dropped %s", dropped.label) end
  end
  if ns.Log then ns.Log:Debug("combat", "queued %s until combat ends", label) end
  return false
end

-- Withdraw a queued job (e.g. a module was switched off before combat ended).
function Combat:Cancel(key)
  local item = self.keyed[key]
  if not item then return false end
  self.keyed[key] = nil
  for i = #self.queue, 1, -1 do
    if self.queue[i] == item then table.remove(self.queue, i) end
  end
  return true
end

function Combat:Flush()
  if self:InLockdown() then return end
  local q = self.queue
  self.queue, self.keyed = {}, {}
  for _, item in ipairs(q) do ns.Safe(item.label, item.fn) end
end

function Combat:Pending() return #self.queue end

ns.Events:On("PLAYER_REGEN_ENABLED", Combat, function() Combat:Flush() end)

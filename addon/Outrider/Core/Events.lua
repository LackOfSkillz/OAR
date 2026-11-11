-- Core/Events.lua
-- One hidden frame dispatches every game event to registered handlers.
-- Handlers are grouped by owner (a module table) so a module can be switched
-- off with a single OffAll(owner). Every handler runs inside ns.Safe.
-- Internal messages (ns:Fire) use the same table with names starting "OTR_".

local _, ns = ...
local Events = { handlers = {}, unitFrames = {}, stats = {}, slow = {} }
ns.Events = Events

local frame = CreateFrame("Frame")
Events.frame = frame

local function isInternal(event) return event:sub(1, 4) == "OTR_" end

local function dispatch(event, ...)
  local list = Events.handlers[event]
  if not list then return end
  -- copy so handlers can unregister themselves while we iterate
  local snapshot = {}
  for i = 1, #list do snapshot[i] = list[i] end
  Events.stats[event] = (Events.stats[event] or 0) + 1
  -- Per-handler timing only in debug mode (debugprofilestop has a cost).
  local timed = ns.db and ns.db.global.debug and debugprofilestop
  for i = 1, #snapshot do
    local h = snapshot[i]
    if not h.removed then
      local where = (h.ownerName or "?") .. ":" .. event
      if timed then
        local t0 = debugprofilestop()
        ns.Safe(where, h.fn, event, ...)
        Events:NoteTiming(where, debugprofilestop() - t0)
      else
        ns.Safe(where, h.fn, event, ...)
      end
    end
  end
end

frame:SetScript("OnEvent", function(_, event, ...) dispatch(event, ...) end)

-- Register fn(event, ...) for event. owner is any table (usually a module).
function Events:On(event, owner, fn)
  assert(type(event) == "string" and type(fn) == "function", "Events:On(event, owner, fn)")
  local list = self.handlers[event]
  if not list then
    list = {}
    self.handlers[event] = list
    if not isInternal(event) then
      local ok = pcall(frame.RegisterEvent, frame, event)
      if not ok and ns.Log then ns.Log:Warn("events", "cannot register %s on this client", event) end
    end
  end
  local h = { owner = owner, ownerName = type(owner) == "table" and owner.name or tostring(owner), fn = fn }
  list[#list + 1] = h
  return h
end

function Events:Off(event, owner)
  local list = self.handlers[event]
  if not list then return end
  for i = #list, 1, -1 do
    if list[i].owner == owner then list[i].removed = true table.remove(list, i) end
  end
  if #list == 0 then
    self.handlers[event] = nil
    if not isInternal(event) then pcall(frame.UnregisterEvent, frame, event) end
  end
end

function Events:OffAll(owner)
  local events = {}
  for event in pairs(self.handlers) do events[#events + 1] = event end
  for _, event in ipairs(events) do self:Off(event, owner) end
end

-- Internal message bus: ns.Events:Fire("OTR_PROFILE_CHANGED", key)
function Events:Fire(message, ...)
  assert(isInternal(message), "internal messages must start with OTR_")
  dispatch(message, ...)
end

-- Keep the slowest 10 handlers seen (max ms per handler).
function Events:NoteTiming(where, ms)
  local slow = self.slow
  for _, s in ipairs(slow) do
    if s.where == where then
      s.calls = s.calls + 1
      if ms > s.ms then s.ms = ms end
      table.sort(slow, function(a, b) return a.ms > b.ms end)
      return
    end
  end
  slow[#slow + 1] = { where = where, ms = ms, calls = 1 }
  table.sort(slow, function(a, b) return a.ms > b.ms end)
  while #slow > 10 do table.remove(slow) end
end

function Events:Count(event)
  local list = self.handlers[event]
  return list and #list or 0
end

-- Exposed for tests only.
Events._dispatch = dispatch

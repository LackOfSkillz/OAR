-- Core/Timer.lua
-- Timers and throttling shared by every scanner.
--   ns.Timer.After(sec, fn, label)   one-shot, returns a handle with :Cancel()
--   ns.Timer.Ticker(sec, fn, label)  repeating, returns a handle with :Cancel()
--   ns.Throttle(key, interval, fn, ...)  at most once per interval per key, and
--     the last call in a burst always runs (trailing), with its own arguments.
-- Uses C_Timer when the client has it; otherwise one hidden OnUpdate frame
-- that is only shown while something is pending (no idle OnUpdate cost).
-- Every callback runs through ns.Safe.

local _, ns = ...
local Timer = { active = {}, count = 0 }
ns.Timer = Timer

local function now()
  return (GetTime and GetTime()) or 0
end

-- ---------------------------------------------------------------- fallback
-- Only used when C_Timer is missing. Keeps a flat list; fine for the handful
-- of timers an addon has.
local driver, queue = nil, {}

local function driverStep(_, elapsed)
  local t = now()
  local due = {}
  for i = #queue, 1, -1 do
    local job = queue[i]
    if job.cancelled then
      table.remove(queue, i)
    elseif job.at <= t then
      due[#due + 1] = job
      table.remove(queue, i)
    end
  end
  for i = #due, 1, -1 do due[i].fire() end
  if #queue == 0 and driver then driver:Hide() end
end

local function fallbackSchedule(delay, fire)
  if not driver then
    driver = CreateFrame("Frame")
    driver:Hide()
    driver:SetScript("OnUpdate", driverStep)
  end
  local job = { at = now() + delay, fire = fire }
  queue[#queue + 1] = job
  driver:Show()
  return job
end

function Timer.UsingFallback()
  return not (C_Timer and C_Timer.After)
end

function Timer.DriverRunning()
  return driver ~= nil and driver:IsShown() and true or false
end

-- A timer or ticker run, timed while a lag check or the always-on watch
-- runs (ns.timing; Modules/LagCheck.lua, Modules/PerfWatch.lua).
local function run(label, fn, ...)
  local lag = ns.timing and rawget(_G, "debugprofilestop")
  if not lag then return ns.Safe(label, fn, ...) end
  local t0 = lag()
  ns.Safe(label, fn, ...)
  ns.NoteTiming("timer " .. tostring(label), lag() - t0)
end

-- ---------------------------------------------------------------- handles
local Handle = {}
Handle.__index = Handle

function Handle:Cancel()
  if self.cancelled then return end
  self.cancelled = true
  if self.job then
    self.job.cancelled = true
    -- Fallback mode: drop it now so the OnUpdate driver stops when idle.
    for i = #queue, 1, -1 do if queue[i] == self.job then table.remove(queue, i) end end
    if #queue == 0 and driver then driver:Hide() end
  end
  if self.native and self.native.Cancel then pcall(self.native.Cancel, self.native) end
  Timer.Untrack(self)
end

function Handle:IsCancelled() return self.cancelled == true end

function Timer.Track(h)
  if Timer.active[h] then return end
  Timer.active[h] = true
  Timer.count = Timer.count + 1
end

function Timer.Untrack(h)
  if not Timer.active[h] then return end
  Timer.active[h] = nil
  Timer.count = Timer.count - 1
end

function Timer.Pending() return Timer.count end

local function schedule(delay, fire)
  if C_Timer and C_Timer.After then
    C_Timer.After(delay, fire)
    return nil
  end
  return fallbackSchedule(delay, fire)
end

function Timer.After(delay, fn, label)
  delay = tonumber(delay) or 0
  if delay < 0 then delay = 0 end
  local h = setmetatable({ label = label or "timer" }, Handle)
  Timer.Track(h)
  h.job = schedule(delay, function()
    if h.cancelled then return end
    h.cancelled = true
    Timer.Untrack(h)
    run(h.label, fn)
  end)
  return h
end

-- A ticker re-arms itself after each run, so a slow or failing callback can
-- never stack up runs. Native NewTicker is not needed for that.
function Timer.Ticker(interval, fn, label)
  interval = tonumber(interval) or 1
  if interval < 0.01 then interval = 0.01 end
  local h = setmetatable({ label = label or "ticker", runs = 0 }, Handle)
  Timer.Track(h)
  local function arm()
    h.job = schedule(interval, function()
      if h.cancelled then return end
      h.runs = h.runs + 1
      run(h.label, fn, h)
      if not h.cancelled then arm() end
    end)
  end
  arm()
  return h
end

-- ---------------------------------------------------------------- throttle
local throttles = {}
Timer.throttles = throttles

function ns.Throttle(key, interval, fn, ...)
  local st = throttles[key]
  if not st then
    st = { last = -math.huge }
    throttles[key] = st
  end
  st.fn, st.n, st.args = fn, select("#", ...), { ... }
  if st.pending then return false end
  local t = now()
  local wait = st.last + interval - t
  if wait <= 0 then
    st.last = t
    ns.Safe("throttle:" .. tostring(key), fn, ...)
    return true
  end
  st.pending = Timer.After(wait, function()
    st.pending = nil
    st.last = now()
    st.fn(unpack(st.args, 1, st.n))
  end, "throttle:" .. tostring(key))
  return false
end

-- Drop a key's pending trailing run (module switched off).
function ns.ThrottleCancel(key)
  local st = throttles[key]
  if st and st.pending then st.pending:Cancel() st.pending = nil end
end

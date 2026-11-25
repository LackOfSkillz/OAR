-- Core/Perf.lua
-- /ride perf: memory, event traffic, handlers, timers, pools, modules.
-- Budget (docs/ARCHITECTURE.md): core idle under 1.5 MB; no OnUpdate while
-- idle; stay far below the client's per-addon caps (C19: Timer 500, Frame
-- 10000). Results go to the log and ns.db.global.perf for Claude to read.

local ADDON, ns = ...
-- Memory budget for Outrider itself (data packs are their own addons). Raised
-- from 1.5 MB on 2026-11-11: core measured 1.3 MB with 45 modules, plus map
-- places built on demand (~130 KB per visited map).
local Perf = { name = "perf", BUDGET_KB = 3072, TIMER_CAP = 500 }
ns.Perf = Perf

-- Timing sinks (Modules/LagCheck.lua, Modules/PerfWatch.lua): while any
-- sink is on, Core/Events.lua and Core/Timer.lua time every handler and timer
-- run (ns.timing) and hand each timing to every sink that is on.
Perf.sinks = {}
function Perf:AddSink(sink) self.sinks[#self.sinks + 1] = sink self:UpdateTiming() end
function Perf:UpdateTiming()
  local on = nil
  for _, s in ipairs(self.sinks) do if s.on then on = true end end
  ns.timing = on
end
function ns.NoteTiming(where, ms)
  for _, s in ipairs(Perf.sinks) do if s.on then s:Note(where, ms) end end
end
-- the part of Outrider a timing belongs to: "MinimapPins:PLAYER_STARTED_MOVING" -> MinimapPins
function Perf.Part(where)
  return tostring(where):match("^([^:]+)") or tostring(where)
end

-- The game's add-on profiler, when the client has it and it is on.
-- Returns nil, why when it can't be read.
local function metricEnum(name)
  local E = rawget(_G, "Enum")
  local t = type(E) == "table" and E.AddOnProfilerMetric
  return type(t) == "table" and t[name] or nil
end
function Perf.Profiler()
  local P = rawget(_G, "C_AddOnProfiler")
  if type(P) ~= "table" or type(P.GetAddOnMetric) ~= "function" then return nil, "this client has no add-on profiler" end
  if type(P.IsEnabled) == "function" then
    local ok, on = pcall(P.IsEnabled)
    if ok and on == false then return nil, "the game's add-on profiler is off" end
  end
  local function get(fn, name)
    local m = metricEnum(name)
    if m == nil or type(P[fn]) ~= "function" then return nil end
    local ok, v
    if fn == "GetAddOnMetric" then ok, v = pcall(P[fn], ADDON, m) else ok, v = pcall(P[fn], m) end
    v = ok and ns.Compat.Readable(v) or nil
    return type(v) == "number" and v or nil
  end
  local out = {
    recentMs = get("GetAddOnMetric", "RecentAverageTime"),
    sessionMs = get("GetAddOnMetric", "SessionAverageTime"),
    peakMs = get("GetAddOnMetric", "PeakTime"),
    over5 = get("GetAddOnMetric", "CountTimeOver5Ms"),
    over50 = get("GetAddOnMetric", "CountTimeOver50Ms"),
    allAddonsMs = get("GetOverallMetric", "RecentAverageTime"),
    gameMs = get("GetApplicationMetric", "RecentAverageTime"),
  }
  if not out.recentMs and not out.sessionMs then return nil, "the profiler gave no numbers for Outrider" end
  if out.recentMs and out.allAddonsMs and out.allAddonsMs > 0 then out.shareAddons = out.recentMs / out.allAddonsMs * 100 end
  if out.recentMs and out.gameMs and out.gameMs > 0 then out.shareGame = out.recentMs / out.gameMs * 100 end
  return out
end


function Perf:MemoryKB()
  local update = (C_AddOns and C_AddOns.UpdateAddOnMemoryUsage) or rawget(_G, "UpdateAddOnMemoryUsage")
  local get = (C_AddOns and C_AddOns.GetAddOnMemoryUsage) or rawget(_G, "GetAddOnMemoryUsage")
  if not get then return nil end
  if update then pcall(update) end
  local ok, kb = pcall(get, ADDON)
  if ok and type(kb) == "number" then return kb end
end

-- OI01-04 runtime baseline extras, all read-only and fail-soft:
--   client      version and build (GetBuildInfo)
--   boot        ms spent in our own load and login steps (debugprofilestop)
--   frames      named Outrider_ frames (unnamed ones can't be counted cheaply)
--   cpuMs       only when the player already has scriptProfile on; Outrider
--               never switches it on (it slows every addon)
--   errors      errors and taint reports recorded this session
function Perf:Runtime()
  local out = {}
  local ok, version, build = pcall(rawget(_G, "GetBuildInfo") or function() end)
  if ok then out.client = { version = version, build = build } end
  if ns.bootTimes then out.boot = ns.CopyTable(ns.bootTimes) end
  local frames = 0
  for k, v in pairs(_G) do
    if type(k) == "string" and k:sub(1, 9) == "Outrider_" and type(v) == "table" and type(v.GetObjectType) == "function" then frames = frames + 1 end
  end
  out.frames = frames
  local cvar = ns.Compat.Call("C_CVar.GetCVar", "scriptProfile")
  if cvar == nil then cvar = ns.Compat.Call("GetCVar", "scriptProfile") end
  if tostring(cvar) == "1" then
    local update = (C_AddOns and C_AddOns.UpdateAddOnCPUUsage) or rawget(_G, "UpdateAddOnCPUUsage")
    local get = (C_AddOns and C_AddOns.GetAddOnCPUUsage) or rawget(_G, "GetAddOnCPUUsage")
    if update then pcall(update) end
    local okc, ms = pcall(get or function() end, ADDON)
    out.cpuMs = okc and type(ms) == "number" and ms or nil
  else
    out.cpu = "unavailable: scriptProfile is off"
  end
  local errs, taint = 0, 0
  for _, e in ipairs(ns.Errors.list or {}) do
    if e.session == ns.session then
      if e.where == "taint" then taint = taint + 1 else errs = errs + 1 end
    end
  end
  out.errors, out.taint = errs, taint
  -- the game's add-on profiler, when present (Modules/PerfPage.lua)
  do
    local okp, pr = pcall(Perf.Profiler)
    if okp and pr then out.profiler = { recentMs = pr.recentMs, sessionMs = pr.sessionMs, peakMs = pr.peakMs, over5 = pr.over5,
      shareAddons = pr.shareAddons } end
  end
  -- collected rows moved to the archive so far (owner retention decision 2026-11-24)
  out.archiveRows = ns.Archive and ns.Archive:Count() or 0
  return out
end

-- one row per session, last RUNS kept (ns.db.global.perfRuns), for the live baseline
Perf.RUNS = 10
function Perf:Remember(r)
  local g = ns.db.global
  g.perfRuns = ns.KeepTable(g.perfRuns, "Perf:g.perfRuns") or {}
  local list = g.perfRuns
  if list[#list] and list[#list].session == ns.session then table.remove(list) end
  list[#list + 1] = { session = ns.session, build = ns.build, at = r.at, uptime = r.uptime, memoryKB = r.memoryKB,
    memoryRawKB = r.memoryRawKB, handlers = r.handlers, timers = r.timers, modulesOn = r.modulesOn,
    secureButtons = r.secureButtons, runtime = r.runtime }
  while #list > self.RUNS do table.remove(list, 1) end
end

function Perf:Collect()
  local handlers, events = 0, 0
  for _, list in pairs(ns.Events.handlers) do events = events + 1 handlers = handlers + #list end
  local top = {}
  for event, n in pairs(ns.Events.stats) do top[#top + 1] = { event = event, n = n } end
  table.sort(top, function(a, b) return a.n > b.n end)
  while #top > 8 do table.remove(top) end
  local on = 0
  for _, m in ipairs(ns.Modules.list) do if m.enabled then on = on + 1 end end
  local secureAll, secureFree = 0, 0
  if ns.SecureButtons then secureAll, secureFree = ns.SecureButtons:Counts() end
  local r = {
    at = time(),
    uptime = (GetTime and ns.bootClock) and math.floor(GetTime() - ns.bootClock) or nil,
    memoryKB = self:MemoryKB(),
    events = events, handlers = handlers, topEvents = top,
    timers = ns.Timer.Pending(), timerDriver = ns.Timer.DriverRunning(),
    combatQueue = ns.Combat:Pending(),
    modulesOn = on, modules = #ns.Modules.list,
    secureButtons = secureAll, secureFree = secureFree,
    toasts = ns.Toast and ns.Toast:Count() or 0,
    slow = ns.CopyTable(ns.Events.slow),
    runtime = self:Runtime(),
  }
  r.overBudget = {}
  if r.memoryKB and r.memoryKB > self.BUDGET_KB then r.overBudget[#r.overBudget + 1] = "memory" end
  if r.timers > self.TIMER_CAP / 10 then r.overBudget[#r.overBudget + 1] = "timers" end
  if r.timerDriver and r.timers == 0 then r.overBudget[#r.overBudget + 1] = "idle OnUpdate" end
  return r
end

-- quiet = the logout report. It first reads memory as is (live data plus
-- garbage not yet collected), then runs one full garbage collection and reads
-- again: the second number is what the budget checks. Before this the logout
-- figure swung between 2.8 and 6.3 MB with chat traffic (2026-11-11).
function Perf:Report(quiet)
  local raw
  if quiet then
    raw = self:MemoryKB()
    pcall(collectgarbage, "collect")
  end
  local r = self:Collect()
  r.memoryRawKB = raw
  ns.db.global.perf = r
  self:Remember(r)
  local rt = r.runtime or {}
  ns.Log:Info("perf", "runtime: client %s build %s, load %s ms, login %s ms, %d named frames, cpu %s, %d errors, %d taint",
    tostring(rt.client and rt.client.version), tostring(rt.client and rt.client.build),
    rt.boot and rt.boot.initMs and string.format("%.1f", rt.boot.initMs) or "?",
    rt.boot and rt.boot.loginMs and string.format("%.1f", rt.boot.loginMs) or "?",
    rt.frames or 0, rt.cpuMs and string.format("%.1f ms", rt.cpuMs) or tostring(rt.cpu), rt.errors or 0, rt.taint or 0)
  local mem = r.memoryKB and string.format("%.0f KB", r.memoryKB) or "unknown"
  if r.memoryRawKB then mem = mem .. string.format(" live (%.0f KB before garbage collection)", r.memoryRawKB) end
  ns.Log:Info("perf", "mem %s, %d events/%d handlers, timers %d (driver %s), combat queue %d, modules %d/%d, secure %d (%d free), uptime %ss",
    mem, r.events, r.handlers, r.timers, tostring(r.timerDriver), r.combatQueue, r.modulesOn, r.modules,
    r.secureButtons, r.secureFree, tostring(r.uptime or "?"))
  local busy = {}
  for _, t in ipairs(r.topEvents) do busy[#busy + 1] = t.event .. "=" .. t.n end
  ns.Log:Info("perf", "busiest events: %s", #busy > 0 and table.concat(busy, ", ") or "none")
  for _, s in ipairs(r.slow) do ns.Log:Info("perf", "slow handler %s max %.2f ms (%d calls)", s.where, s.ms, s.calls) end
  if #r.overBudget > 0 then ns.Log:Warn("perf", "over budget: %s", table.concat(r.overBudget, ", ")) end
  if quiet then return r end
  ns.Print("memory %s | timers %d | handlers %d | modules %d/%d%s. /reload to save for Claude.", mem, r.timers,
    r.handlers, r.modulesOn, r.modules, #r.overBudget > 0 and (" | over budget: " .. table.concat(r.overBudget, ", ")) or "")
  return r
end

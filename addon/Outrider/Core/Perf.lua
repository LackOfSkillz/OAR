-- Core/Perf.lua
-- /ride perf: memory, event traffic, handlers, timers, pools, modules.
-- Budget (docs/ARCHITECTURE.md): core idle under 1.5 MB; no OnUpdate while
-- idle; stay far below the client's per-addon caps (C19: Timer 500, Frame
-- 10000). Results go to the log and ns.db.global.perf for Claude to read.

local ADDON, ns = ...
local Perf = { name = "perf", BUDGET_KB = 1536, TIMER_CAP = 500 }
ns.Perf = Perf

function Perf:MemoryKB()
  local update = (C_AddOns and C_AddOns.UpdateAddOnMemoryUsage) or rawget(_G, "UpdateAddOnMemoryUsage")
  local get = (C_AddOns and C_AddOns.GetAddOnMemoryUsage) or rawget(_G, "GetAddOnMemoryUsage")
  if not get then return nil end
  if update then pcall(update) end
  local ok, kb = pcall(get, ADDON)
  if ok and type(kb) == "number" then return kb end
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
  }
  r.overBudget = {}
  if r.memoryKB and r.memoryKB > self.BUDGET_KB then r.overBudget[#r.overBudget + 1] = "memory" end
  if r.timers > self.TIMER_CAP / 10 then r.overBudget[#r.overBudget + 1] = "timers" end
  if r.timerDriver and r.timers == 0 then r.overBudget[#r.overBudget + 1] = "idle OnUpdate" end
  return r
end

function Perf:Report()
  local r = self:Collect()
  ns.db.global.perf = r
  local mem = r.memoryKB and string.format("%.0f KB", r.memoryKB) or "unknown"
  ns.Log:Info("perf", "mem %s, %d events/%d handlers, timers %d (driver %s), combat queue %d, modules %d/%d, secure %d (%d free), uptime %ss",
    mem, r.events, r.handlers, r.timers, tostring(r.timerDriver), r.combatQueue, r.modulesOn, r.modules,
    r.secureButtons, r.secureFree, tostring(r.uptime or "?"))
  local busy = {}
  for _, t in ipairs(r.topEvents) do busy[#busy + 1] = t.event .. "=" .. t.n end
  ns.Log:Info("perf", "busiest events: %s", #busy > 0 and table.concat(busy, ", ") or "none")
  for _, s in ipairs(r.slow) do ns.Log:Info("perf", "slow handler %s max %.2f ms (%d calls)", s.where, s.ms, s.calls) end
  if #r.overBudget > 0 then ns.Log:Warn("perf", "over budget: %s", table.concat(r.overBudget, ", ")) end
  ns.Print("memory %s | timers %d | handlers %d | modules %d/%d%s. /reload to save for Claude.", mem, r.timers,
    r.handlers, r.modulesOn, r.modules, #r.overBudget > 0 and (" | over budget: " .. table.concat(r.overBudget, ", ")) or "")
  return r
end

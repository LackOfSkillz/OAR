-- Modules/PerfPage.lua  (Gary, 2026-11-25: players on the subreddit watch
-- latency and CPU; one screen that shows what Outrider costs, so it can prove
-- it takes performance seriously)
--
-- The Performance page (Outrider group) shows, all read-only and fail-soft:
--   * the game's own numbers: FPS now, low and average while the page is
--     open; home and world latency (GetNetStats);
--   * Outrider's CPU from the game's add-on profiler (C_AddOnProfiler, on
--     modern clients; probed, unverified on Forever until seen in game):
--     recent and session average ms per frame, the peak, how many frames it
--     took over 5 ms, and its share of all add-ons' and of the game's time;
--     without the profiler, the one-minute lag check (LagCheck) times
--     Outrider itself;
--   * memory: Outrider's, its budget (Perf.BUDGET_KB) and its share of all
--     loaded add-ons;
--   * Outrider's own load: event handlers, timers pending, the timer driver
--     idle or not (no OnUpdate while idle), modules on, login time;
--   * Monitor: one press starts measuring until Stop (page open or closed),
--     with one row per minute (LagCheck:Start(0));
--   * budgets with a pass or fail, past sessions (Perf.perfRuns) and past
--     lag checks, and a "Copy for a post" text with no name, realm or gold.
-- Sampling runs only while this page is open (a 1 s ticker, cancelled when
-- the Hub closes or another page opens); memory of every add-on is updated
-- at most every 10 s, because that call walks all of them.

local ADDON, ns = ...
local C = ns.Compat
local M = ns:NewModule("PerfPage", {
  title = "Performance page",
  phase = "P8",
  order = 92,
  defaults = {},
})
ns.PerfPage = M

M.KEEP = 60              -- live samples kept while the page is open (1 a second)
M.MEMORY_EVERY = 10      -- seconds between "every add-on" memory updates
M.CHECKS = 20            -- past lag checks kept in view; older ones go to the archive
M.BUDGETS = { loginMs = 100, lagPct = 0.5, frameMs = 1 }

function M:OnInitialize() self.samples = {} end
function M:OnEnable()
  self:On("OTR_HUB_HIDDEN", function(mod) mod:StopLive() end)
  self:On("OTR_LAGCHECK", function(mod, _, what) if what == "done" then mod:KeepCheck() end end)
end
function M:OnDisable() self:StopLive() end

-- ------------------------------------------------------------ the game's numbers
function M.Net()
  local _, _, home, world = C.Call("GetNetStats")
  return tonumber(C.Readable(home)), tonumber(C.Readable(world))
end
function M.FPS() return tonumber(C.Readable(C.Call("GetFramerate"))) end

-- The game's add-on profiler, when the client has it and it is on.
-- Returns nil, why when it can't be read.
local function metricEnum(name)
  local E = rawget(_G, "Enum")
  local t = type(E) == "table" and E.AddOnProfilerMetric
  return type(t) == "table" and t[name] or nil
end
function M.Profiler()
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
    v = ok and C.Readable(v) or nil
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

-- Outrider's memory and all loaded add-ons' (updated at most every 10 s).
function M:Memory(force)
  local now = C.Call("GetTime") or 0
  local A = rawget(_G, "C_AddOns") or {}
  local get = A.GetAddOnMemoryUsage or rawget(_G, "GetAddOnMemoryUsage")
  if not get then return nil end
  if force or not self.memAt or now - self.memAt >= M.MEMORY_EVERY then
    self.memAt = now
    local update = A.UpdateAddOnMemoryUsage or rawget(_G, "UpdateAddOnMemoryUsage")
    if update then pcall(update) end
    local mine = select(2, pcall(get, ADDON))
    local all, n = 0, 0
    local count = A.GetNumAddOns or rawget(_G, "GetNumAddOns")
    local info = A.GetAddOnInfo or rawget(_G, "GetAddOnInfo")
    local loaded = A.IsAddOnLoaded or rawget(_G, "IsAddOnLoaded")
    local okc, total = pcall(count or function() return 0 end)
    for i = 1, (okc and tonumber(total) or 0) do
      local ok, name = pcall(info, i)
      if ok and name and (not loaded or select(2, pcall(loaded, name)) == true) then
        local okm, kb = pcall(get, name)
        if okm and type(kb) == "number" then all, n = all + kb, n + 1 end
      end
    end
    self.mem = { mine = type(mine) == "number" and mine or nil, all = n > 0 and all or nil, addons = n }
  end
  return self.mem
end

-- Outrider's own load right now.
function M.Load()
  local handlers, events = 0, 0
  for _, list in pairs(ns.Events.handlers) do events = events + 1 handlers = handlers + #list end
  local on = 0
  for _, m in ipairs(ns.Modules.list) do if m.enabled then on = on + 1 end end
  local handled = 0
  for _, n in pairs(ns.Events.stats) do handled = handled + n end
  return { handlers = handlers, events = events, timers = ns.Timer.Pending(), driver = ns.Timer.DriverRunning(),
    modulesOn = on, modules = #ns.Modules.list, handled = handled,
    loginMs = ns.bootTimes and ns.bootTimes.loginMs, initMs = ns.bootTimes and ns.bootTimes.initMs }
end

-- ------------------------------------------------------------ live sampling
function M:Sample()
  local l = M.Load()
  local s = { at = C.Call("GetTime") or 0, fps = M.FPS(), handled = l.handled }
  s.home, s.world = M.Net()
  local list = self.samples
  list[#list + 1] = s
  -- the live window only (never saved): the oldest second leaves it
  while #list > M.KEEP do table.remove(list, 1) end
  return s
end

-- FPS low / average / now and events handled per second over the window.
function M:Live()
  local list = self.samples
  local sum, n, low = 0, 0, nil
  for _, s in ipairs(list) do
    if s.fps then sum, n = sum + s.fps, n + 1 if not low or s.fps < low then low = s.fps end end
  end
  local last, first = list[#list], list[1]
  local rate
  if last and first and last.at > first.at then rate = (last.handled - first.handled) / (last.at - first.at) end
  return { fps = last and last.fps, fpsAvg = n > 0 and sum / n or nil, fpsLow = low, home = last and last.home,
    world = last and last.world, eventsPerSec = rate, seconds = #list }
end

function M:StartLive(refresh)
  self.refresh = refresh
  if self.ticker then return end
  self:Sample()
  self.ticker = ns.Timer.Ticker(1, function()
    local hub = ns.Hub
    if not (hub and hub.frame and hub.frame:IsShown() and hub.current == "performance") then M:StopLive() return end
    M:Sample()
    if M.refresh then M.refresh() end
  end, "perfpage")
end
function M:StopLive()
  if self.ticker then self.ticker:Cancel() self.ticker = nil end
  self.refresh = nil
end

-- ------------------------------------------------------------ history
-- Every finished lag check is kept (the single global.lagCheck is replaced
-- by the next one); past M.CHECKS the oldest go to the archive, never away.
function M:KeepCheck()
  local r = ns.db.global.lagCheck
  if type(r) ~= "table" then return end
  local g = ns.db.global
  g.lagChecks = ns.KeepTable(g.lagChecks, "PerfPage:g.lagChecks") or {}
  local list = g.lagChecks
  if list[#list] and list[#list].at == r.at then return end
  list[#list + 1] = ns.CopyTable(r)
  while #list > M.CHECKS and ns.Archive:Shift("lagChecks", list, { path = "global.lagChecks", scope = "account" }) do end
end

-- ------------------------------------------------------------ budgets
-- true / false when measured, nil when not ("x and false or nil" would be nil)
local function judge(measured, pass)
  if measured == nil or measured == false then return nil end
  return pass and true or false
end

-- { label, ok (true/false/nil = not measured), value text, why }
function M:Budgets()
  local out = {}
  local mem = self:Memory()
  local kb = mem and mem.mine
  out[#out + 1] = { "Memory under " .. math.floor(ns.Perf.BUDGET_KB / 1024) .. " MB", judge(kb, kb and kb <= ns.Perf.BUDGET_KB),
    kb and string.format("%.1f MB", kb / 1024) or "not readable", "data packs load as their own add-ons, only when needed" }
  local l = M.Load()
  out[#out + 1] = { "Nothing runs every frame while idle", not (l.driver and l.timers == 0),
    l.driver and string.format("%d timers waiting", l.timers) or "timer driver asleep", "no OnUpdate unless a timer is due" }
  out[#out + 1] = { "Login work under " .. M.BUDGETS.loginMs .. " ms", judge(l.loginMs, l.loginMs and l.loginMs <= M.BUDGETS.loginMs),
    l.loginMs and string.format("%.0f ms", l.loginMs) or "not measured", "time Outrider spends when you log in" }
  local p = M.Profiler()
  out[#out + 1] = { "Under " .. M.BUDGETS.frameMs .. " ms per frame", judge(p and p.recentMs, p and p.recentMs and p.recentMs <= M.BUDGETS.frameMs),
    p and p.recentMs and string.format("%.3f ms", p.recentMs) or "needs the game's profiler", "recent average, from the game itself" }
  local lc = ns.db.global.lagCheck
  out[#out + 1] = { "Lag check under " .. M.BUDGETS.lagPct .. "% of the game's time", judge(lc and lc.pct, lc and lc.pct and lc.pct < M.BUDGETS.lagPct),
    lc and lc.pct and string.format("%.2f%%", lc.pct) or "run a check below", "Outrider times itself for one minute" }
  local errs, taint = 0, 0
  for _, e in ipairs(ns.Errors.list or {}) do
    if e.session == ns.session then if e.where == "taint" then taint = taint + 1 else errs = errs + 1 end end
  end
  out[#out + 1] = { "No blocked actions (taint) this session", taint == 0, tostring(taint), "protected actions only from your own key presses" }
  return out
end

-- ------------------------------------------------------------ share text
-- Plain numbers only: no character, realm, guild or gold.
function M:ShareText()
  local t = {}
  local function add(fmt, ...) t[#t + 1] = string.format(fmt, ...) end
  local _, build = pcall(rawget(_G, "GetBuildInfo") or function() end)
  add("Outrider %s performance (client %s)", tostring(ns.version), tostring(build or "?"))
  local live = self:Live()
  if live.fpsAvg then add("FPS: %.0f average, %.0f lowest over %d s", live.fpsAvg, live.fpsLow or live.fpsAvg, live.seconds) end
  if live.home then add("Latency: home %d ms, world %d ms", live.home, live.world or 0) end
  local p = M.Profiler()
  if p then
    add("CPU (game profiler): %.3f ms per frame recently, %.3f ms session average, peak %.1f ms",
      p.recentMs or 0, p.sessionMs or 0, p.peakMs or 0)
    if p.shareAddons then add("Share of all add-ons' time: %.1f%%", p.shareAddons) end
    if p.over5 then add("Frames over 5 ms: %d", p.over5) end
  end
  local mem = self:Memory()
  if mem and mem.mine then
    add("Memory: %.1f MB%s", mem.mine / 1024, mem.all and string.format(" of %.1f MB for %d add-ons", mem.all / 1024, mem.addons) or "")
  end
  local lc = ns.db.global.lagCheck
  if lc and lc.pct then add("Lag check: %.2f%% of the game's time over %d s, slowest moment %.1f ms", lc.pct, lc.seconds or 60, lc.worst and lc.worst.ms or 0) end
  for _, b in ipairs(self:Budgets()) do
    add("[%s] %s: %s", b[2] == true and "pass" or b[2] == false and "FAIL" or "n/a", b[1], b[3])
  end
  return table.concat(t, "\n")
end

-- ------------------------------------------------------------ page
local function ms(v, d) return v and string.format("%." .. (d or 2) .. "f ms", v) or "—" end

function M:Stats()
  local live, p, mem, l = self:Live(), M.Profiler(), self:Memory(), M.Load()
  local out = {
    { cap = "FPS", value = live.fps and string.format("%.0f", live.fps) or "—",
      note = live.fpsLow and string.format("low %.0f, avg %.0f (%d s)", live.fpsLow, live.fpsAvg, live.seconds) or "sampling" },
    { cap = "Latency", value = live.world and (live.world .. " ms") or "—", note = live.home and ("home " .. live.home .. " ms") or "" },
    { cap = "Outrider CPU", value = p and ms(p.recentMs, 3) or "—",
      color = p and p.recentMs and (p.recentMs <= M.BUDGETS.frameMs and "good" or "warn") or nil,
      note = p and (p.shareAddons and string.format("%.1f%% of all add-ons", p.shareAddons) or "per frame, recent") or "see below" },
    { cap = "Outrider memory", value = mem and mem.mine and string.format("%.1f MB", mem.mine / 1024) or "—",
      fill = mem and mem.mine and math.min(1, mem.mine / ns.Perf.BUDGET_KB),
      color = mem and mem.mine and mem.mine > ns.Perf.BUDGET_KB and "bad" or "good",
      note = mem and mem.all and string.format("%.0f%% of %d add-ons", mem.mine / mem.all * 100, mem.addons) or "" },
  }
  local L = ns.LagCheck
  if L and L.on and L.data then
    local sm = L:Summary()
    out[#out + 1] = { cap = L.data.open and "Monitoring" or "Lag check", color = "gold",
      value = string.format("%d:%02d", math.floor(sm.seconds / 60), sm.seconds % 60),
      note = string.format("Outrider %.2f%% of the game's time", sm.pct) }
  end
  out[#out + 1] = { cap = "Events / second", value = live.eventsPerSec and string.format("%.1f", live.eventsPerSec) or "—",
    note = l.handlers .. " handlers on " .. l.events .. " events" }
  return out
end

function M:CpuLines()
  local p, why = M.Profiler()
  if not p then
    return { { title = "CPU from the game: not available", line = why .. ". The lag check below times Outrider itself instead." } }
  end
  return {
    { title = "Recent average", line = ms(p.recentMs, 3) .. " per frame" .. (p.shareGame and string.format(" (%.2f%% of the game's frame time)", p.shareGame) or "") },
    { title = "This session", line = ms(p.sessionMs, 3) .. " per frame on average; peak " .. ms(p.peakMs, 1) },
    { title = "Slow frames", line = string.format("%s frames over 5 ms, %s over 50 ms this session",
      p.over5 and string.format("%.0f", p.over5) or "?", p.over50 and string.format("%.0f", p.over50) or "?") },
  }
end

function M:BudgetBars()
  local out = {}
  for _, b in ipairs(self:Budgets()) do
    out[#out + 1] = { label = b[1], fill = b[2] == nil and 0 or 1, text = (b[2] == true and "pass  " or b[2] == false and "FAIL  " or "")
      .. b[3], color = b[2] == true and "good" or b[2] == false and "bad" or nil }
  end
  return out
end

-- Past sessions: memory and login time per session (Perf keeps the rows).
function M.History()
  local out = {}
  local runs = ns.db.global.perfRuns or {}
  local max = 1
  for _, r in ipairs(runs) do if type(r.memoryKB) == "number" and r.memoryKB > max then max = r.memoryKB end end
  for i = #runs, 1, -1 do
    local r = runs[i]
    local rt = r.runtime or {}
    local login = rt.boot and rt.boot.loginMs
    out[#out + 1] = { label = r.at and date("%b %d %H:%M", r.at) or ("session " .. i),
      fill = type(r.memoryKB) == "number" and r.memoryKB / max or 0,
      text = string.format("%s, login %s%s", type(r.memoryKB) == "number" and string.format("%.1f MB", r.memoryKB / 1024) or "?",
        login and string.format("%.0f ms", login) or "?", rt.profiler and rt.profiler.sessionMs and string.format(", %.3f ms/frame", rt.profiler.sessionMs) or "") }
  end
  return out
end

-- One row per minute: the run going on now, else the last monitoring run.
function M.Minutes()
  local L = ns.LagCheck
  local rows, live = nil, false
  if L and L.on and L.data and L.data.open then rows, live = L.data.minutes, true
  else
    local list = ns.db.global.lagChecks or {}
    for i = #list, 1, -1 do if list[i].monitor then rows = list[i].minutes break end end
  end
  local out = {}
  rows = rows or {}
  for i = #rows, math.max(1, #rows - 29), -1 do
    local r = rows[i]
    local pct = r.secs and r.secs > 0 and r.ms / (r.secs * 1000) * 100 or 0
    out[#out + 1] = { label = (live and "minute " or "min ") .. i, fill = math.min(1, pct / 2),
      text = string.format("FPS %.0f (low %.0f), Outrider %.2f%%%s%s", r.fps or 0, r.low or r.fps or 0, pct,
        r.world and (", world " .. r.world .. " ms") or "", r.cpu and string.format(", %.3f ms/frame", r.cpu) or ""),
      color = pct < 0.5 and "good" or pct < 2 and "warn" or "bad" }
  end
  return out
end

function M.Checks()
  local out = {}
  local list = ns.db.global.lagChecks or {}
  for i = #list, math.max(1, #list - 9), -1 do
    local r = list[i]
    out[#out + 1] = { label = r.at and date("%b %d %H:%M", r.at) or "?", fill = math.min(1, (r.pct or 0) / 2),
      text = string.format("%.2f%%, slowest %.1f ms%s", r.pct or 0, r.worst and r.worst.ms or 0,
        r.fpsAvg and string.format(", FPS %.0f", r.fpsAvg) or ""),
      color = r.level == "fine" and "good" or r.level == "small" and "warn" or "bad" }
  end
  return out
end

ns.Hub:AddTab("performance", "Performance", function(p)
  ns.UI:FormPage(p, {
    { "header", "What Outrider costs your game", icon = "Spell_Nature_TimeStop" },
    { "note", "Live numbers from the game itself, while this page is open. 1. Play as usual. 2. Watch the numbers. 3. Run a lag check for the full picture, then copy the result for a post." },
    { "stats", function() return M:Stats() end },
    { "header", "CPU time", icon = "Trade_Engineering" },
    { "cards", function() return M:CpuLines() end },
    { "header", "Promises we keep", icon = "Ability_Warrior_DefensiveStance" },
    { "bars", function() return M:BudgetBars() end },
    { "buttons", {
      { "Monitor until I stop", function() if ns.LagCheck then ns.LagCheck:Start(0) p:Refresh() end end },
      { "Stop and save", function() if ns.LagCheck then ns.LagCheck:Stop("stopped") p:Refresh() end end },
      { "Run a lag check (1 min)", function() if ns.LagCheck then ns.LagCheck:Start() end end },
      { "Copy for a post", function() ns.UI:TextDialog("Outrider performance", M:ShareText(), "copy") end },
    } },
    { "header", "Minute by minute", icon = "INV_Misc_PocketWatch_02" },
    { "note", function()
      local L = ns.LagCheck
      if L and L.on and L.data and L.data.open then return "Monitoring now, with this page open or closed. Stop and save ends it (logging out does too)." end
      return #M.Minutes() > 0 and "Your last monitoring run, newest minute first." or "Press Monitor until I stop: Outrider measures itself until you press Stop, one row a minute."
    end },
    { "bars", function() return M.Minutes() end },
    { "header", "Past lag checks", icon = "Spell_Holy_BorrowedTime" },
    { "bars", function() return M.Checks() end },
    { "note", function() return #M.Checks() == 0 and "No lag check yet: press Run a lag check above." or "" end },
    { "header", "Past sessions", icon = "INV_Misc_PocketWatch_01" },
    { "bars", function() return M.History() end },
    { "note", "Memory and login time per session, saved when you log out." },
  })
  -- live while shown: Hub:ShowTab refreshes the page each time it opens
  local base = p.Refresh
  function p:Refresh()
    M:StartLive(function() if p:IsShown() then base(p) end end)
    base(self)
  end
end, 63, { group = "Outrider", icon = "Interface\\Icons\\Spell_Nature_TimeStop" })

ns.AddCommand("perfpage", "open the Performance page: FPS, latency, Outrider's CPU and memory", function()
  ns.Hub:Build():Show()
  ns.Hub:ShowTab("performance")
end)

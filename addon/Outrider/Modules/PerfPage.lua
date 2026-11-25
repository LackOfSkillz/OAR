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
--   * the always-on watch (Modules/PerfWatch.lua): this session minute by
--     minute, its slow moments (spikes and freezes, with what ran and where),
--     Outrider's heaviest parts, and past sessions; a switch turns it off;
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
function M:Activity()
  return self.ticker and "showing live numbers (Settings, Performance)" or "Settings, Performance: FPS, latency, Outrider's CPU and memory"
end

-- ------------------------------------------------------------ the game's numbers
function M.Net()
  local _, _, home, world = C.Call("GetNetStats")
  return tonumber(C.Readable(home)), tonumber(C.Readable(world))
end
function M.FPS() return tonumber(C.Readable(C.Call("GetFramerate"))) end

-- The game's add-on profiler lives in Core/Perf.lua (Perf.Profiler).
M.Profiler = function() return ns.Perf.Profiler() end

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
  local W = ns.PerfWatch
  local s = { at = C.Call("GetTime") or 0, fps = M.FPS(), handled = l.handled,
    ours = W and W.on and W.cur and W.cur.total or nil }
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
  local W = ns.PerfWatch
  local w = W and W.on and W:Summary()
  if w then add("Always-on watch this session: %.3f%% of the game's time over %d min, %d spikes, %d game freezes (%d mostly Outrider's)",
    w.pct, math.floor(w.seconds / 60), w.spikes, w.hitches, w.ours) end
  local lc = ns.db.global.lagCheck
  if lc and lc.pct then add("Lag check: %.2f%% of the game's time over %d s, slowest moment %.1f ms", lc.pct, lc.seconds or 60, lc.worst and lc.worst.ms or 0) end
  for _, b in ipairs(self:Budgets()) do
    add("[%s] %s: %s", b[2] == true and "pass" or b[2] == false and "FAIL" or "n/a", b[1], b[3])
  end
  return table.concat(t, "\n")
end

-- ------------------------------------------------------------ page
-- bars take an {r, g, b} colour; stat tiles take the theme name
local function rgb(name) if name then return { ns.Theme:Color(name) } end end
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
  local W = ns.PerfWatch
  local w = W and W.on and W:Summary()
  if w then
    out[#out + 1] = { cap = "Watching this session", color = w.pct < M.BUDGETS.lagPct and "good" or "warn",
      value = string.format("%.2f%%", w.pct),
      note = string.format("of the game's time over %d min; %d spikes, %d freezes", math.floor(w.seconds / 60), w.spikes, w.hitches) }
  end
  out[#out + 1] = { cap = "Events / second", value = live.eventsPerSec and string.format("%.1f", live.eventsPerSec) or "—",
    note = l.handlers .. " handlers on " .. l.events .. " events" }
  return out
end

function M:CpuLines()
  local p, why = M.Profiler()
  if not p then
    return { { pic = "Interface\Icons\INV_Misc_QuestionMark", title = "CPU from the game: not available", line = why .. ". The always-on watch below times Outrider itself instead." } }
  end
  return {
    { pic = "Interface\Icons\Spell_Nature_TimeStop", title = "Recent average", line = ms(p.recentMs, 3) .. " per frame" .. (p.shareGame and string.format(" (%.2f%% of the game's frame time)", p.shareGame) or "") },
    { pic = "Interface\Icons\INV_Misc_PocketWatch_01", title = "This session", line = ms(p.sessionMs, 3) .. " per frame on average; peak " .. ms(p.peakMs, 1) },
    { pic = "Interface\Icons\Spell_Nature_Slow", title = "Slow frames", line = string.format("%s frames over 5 ms, %s over 50 ms this session",
      p.over5 and string.format("%.0f", p.over5) or "?", p.over50 and string.format("%.0f", p.over50) or "?") },
  }
end

function M:BudgetBars()
  local out = {}
  for _, b in ipairs(self:Budgets()) do
    out[#out + 1] = { label = b[1], fill = b[2] == nil and 0 or 1, text = (b[2] == true and "pass  " or b[2] == false and "FAIL  " or "")
      .. b[3], color = rgb(b[2] == true and "good" or b[2] == false and "bad" or nil) }
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

-- One row per minute: this session (the always-on watch), else the last saved one.
function M.Minutes()
  local W = ns.PerfWatch
  local rows, live = nil, false
  if W and W.on and W.cur then rows, live = W.cur.minutes, true
  else
    local list = ns.db.global.perfWatch or {}
    rows = list[#list] and list[#list].minutes
  end
  local out = {}
  rows = rows or {}
  for i = #rows, math.max(1, #rows - 29), -1 do
    local r = rows[i]
    local pct = r.secs and r.secs > 0 and r.ms / (r.secs * 1000) * 100 or 0
    out[#out + 1] = { label = (live and "minute " or "min ") .. i, fill = math.min(1, pct / 2),
      text = string.format("FPS %.0f (low %.0f), Outrider %.2f%%%s%s", r.fps or 0, r.low or r.fps or 0, pct,
        r.world and (", world " .. r.world .. " ms") or "", r.cpu and string.format(", %.3f ms/frame", r.cpu) or ""),
      color = rgb(pct < 0.5 and "good" or pct < 2 and "warn" or "bad") }
  end
  return out
end

-- Slow moments, newest first: Outrider's spikes and the game's freezes.
function M.SlowRows()
  local out = {}
  local list = ns.db.global.perfSlow or {}
  local W = ns.PerfWatch
  for i = #list, math.max(1, #list - 24), -1 do
    local r = list[i]
    local what
    if r.kind == "hitch" then
      local ours = r.ours or 0
      what = string.format("Game froze %.1f s: Outrider %.0f ms of it (%s)", r.ms / 1000, ours,
        ours >= r.ms / 2 and "ours" or "not Outrider")
    else
      what = string.format("Outrider %s: %.0f ms", tostring(r.where), r.ms)
    end
    if (r.n or 1) > 1 then what = what .. string.format(", %d times", r.n) end
    out[#out + 1] = { label = r.at and date("%b %d %H:%M", r.at) or "?",
      fill = math.min(1, r.ms / 1000), color = rgb((r.kind == "spike" or (r.ours or 0) >= r.ms / 2) and "bad" or "warn"),
      text = what .. " - " .. (W and W.Describe(r) or "") }
  end
  return out
end

-- Outrider's heaviest parts this session (the always-on watch)
function M.Parts()
  local W = ns.PerfWatch
  local w = W and W.on and W:Summary()
  if not w then return {} end
  local out, top = {}, w.parts[1] and w.parts[1].ms or 1
  for i = 1, math.min(8, #w.parts) do
    local p = w.parts[i]
    out[#out + 1] = { label = p.name, fill = top > 0 and p.ms / top or 0,
      text = string.format("%.0f ms in %d runs, slowest %.1f ms", p.ms, p.n, p.max),
      color = rgb(p.max >= W.SPIKE_MS and "warn" or "good") }
  end
  return out
end

-- past sessions from the always-on watch
function M.Sessions()
  local out = {}
  local list = ns.db.global.perfWatch or {}
  for i = #list, math.max(1, #list - 9), -1 do
    local r = list[i]
    out[#out + 1] = { label = r.startedAt and date("%b %d %H:%M", r.startedAt) or "?", fill = math.min(1, (r.pct or 0) / 2),
      text = string.format("%.2f%% over %d min, %d spikes, %d freezes (%d ours)%s", r.pct or 0, math.floor((r.seconds or 0) / 60),
        r.spikes or 0, r.hitches or 0, r.ours or 0, r.fpsAvg and string.format(", FPS %.0f", r.fpsAvg) or ""),
      color = rgb((r.ours or 0) > 0 and "bad" or (r.pct or 0) < 0.5 and "good" or "warn") }
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
      color = rgb(r.level == "fine" and "good" or r.level == "small" and "warn" or "bad") }
  end
  return out
end


-- ------------------------------------------------------------ charts
-- A column chart drawn with plain textures (Gary, 2026-11-25: "a graph or
-- some visualization"). get() returns { values = {...}, max, budget,
-- colorOf(v) -> theme name, marks = { [i] = true }, now = "text", empty = "text" }.
M.CHART_H = 64
function M.Chart(host, title, get)
  local Theme = ns.Theme
  local f = CreateFrame("Frame", nil, host)
  f:SetSize(600, M.CHART_H + 34)
  f.title = ns.UI.Text(f, "small", "gold")
  f.title:SetPoint("TOPLEFT", 0, 0)
  f.title:SetText(title)
  f.now = ns.UI.Text(f, "small", "body")
  f.now:SetPoint("TOPRIGHT", 0, 0)
  f.plot = f:CreateTexture(nil, "BACKGROUND")
  f.plot:SetPoint("TOPLEFT", 0, -16)
  f.plot:SetPoint("RIGHT", f, "RIGHT", 0, 0)
  f.plot:SetHeight(M.CHART_H)
  f.plot:SetColorTexture(Theme:Color("bg"))
  f.budget = f:CreateTexture(nil, "OVERLAY")
  f.budget:SetHeight(1)
  f.budget:SetColorTexture(Theme:Color("gold"))
  f.budgetText = ns.UI.Text(f, "small", "muted")
  f.top = ns.UI.Text(f, "small", "muted")
  f.top:SetPoint("TOPLEFT", f.plot, "TOPLEFT", 4, -2)
  f.empty = ns.UI.Text(f, "small", "muted")
  f.empty:SetPoint("CENTER", f.plot, "CENTER", 0, 0)
  f.cols, f.marks = {}, {}
  function f:LayoutHeight() return M.CHART_H + 34 end
  function f:Refresh()
    local ok, d = ns.Safe("perfpage:chart", get)
    d = ok and type(d) == "table" and d or { values = {} }
    local vals = d.values or {}
    local n = #vals
    local w = math.max(100, (self:GetWidth() or 600))
    local max = d.max or 0
    for _, v in ipairs(vals) do if v > max then max = v end end
    if d.budget and d.budget > max then max = d.budget * 1.25 end
    if max <= 0 then max = 1 end
    self.now:SetText(d.now or "")
    self.empty:SetText(n == 0 and (d.empty or "no data yet") or "")
    self.top:SetText(n > 0 and (d.topText and d.topText(max) or "") or "")
    local slots = math.max(n, d.slots or n)
    local cw = slots > 0 and w / slots or w
    for i = 1, math.max(n, #self.cols) do
      local c = self.cols[i]
      if i <= n then
        if not c then c = self:CreateTexture(nil, "ARTWORK") self.cols[i] = c end
        local h = math.max(1, math.min(M.CHART_H, vals[i] / max * M.CHART_H))
        c:ClearAllPoints()
        c:SetPoint("BOTTOMLEFT", self.plot, "BOTTOMLEFT", (slots - n + i - 1) * cw + 1, 0)
        c:SetSize(math.max(1, cw - 2), h)
        local r, g, b = Theme:Color(d.colorOf and d.colorOf(vals[i]) or "gold")
        c:SetColorTexture(r, g, b, 0.85)
        c:Show()
      elseif c then c:Hide() end
      local m = self.marks[i]
      if i <= n and d.marks and d.marks[i] then
        if not m then m = self:CreateTexture(nil, "OVERLAY") self.marks[i] = m end
        m:ClearAllPoints()
        m:SetPoint("TOPLEFT", self.plot, "TOPLEFT", (slots - n + i - 1) * cw + 1, 0)
        m:SetSize(math.max(2, cw - 2), 4)
        local r, g, b = Theme:Color("bad")
        m:SetColorTexture(r, g, b, 1)
        m:Show()
      elseif m then m:Hide() end
    end
    if d.budget and n > 0 then
      local y = d.budget / max * M.CHART_H
      self.budget:ClearAllPoints()
      self.budget:SetPoint("BOTTOMLEFT", self.plot, "BOTTOMLEFT", 0, y)
      self.budget:SetPoint("RIGHT", self.plot, "RIGHT", 0, 0)
      self.budget:Show()
      self.budgetText:ClearAllPoints()
      self.budgetText:SetPoint("BOTTOMRIGHT", self.plot, "BOTTOMRIGHT", -4, y + 2)
      self.budgetText:SetText(d.budgetText or "budget")
    else
      self.budget:Hide()
      self.budgetText:SetText("")
    end
    self.last = d
  end
  f:SetScript("OnSizeChanged", function(self) self:Refresh() end)
  f:Refresh()
  return f
end

-- Live: Outrider's ms in each second, last 60 s (budget: 0.5% = 5 ms a second)
function M:LiveCpu()
  local list, vals = self.samples, {}
  for i = 2, #list do
    local a, b = list[i - 1], list[i]
    if a.ours and b.ours and b.at > a.at then vals[#vals + 1] = math.max(0, (b.ours - a.ours) / (b.at - a.at)) end
  end
  local budget = M.BUDGETS.lagPct * 10
  return { values = vals, slots = M.KEEP - 1, budget = budget, budgetText = "budget 0.5%",
    colorOf = function(v) return v <= budget and "good" or v <= budget * 4 and "warn" or "bad" end,
    now = #vals > 0 and string.format("%.1f ms in the last second (%.2f%%)", vals[#vals], vals[#vals] / 10) or "",
    topText = function(max) return string.format("%.0f ms", max) end,
    empty = ns.PerfWatch and ns.PerfWatch.on and "starting..." or "switch on Watch performance all the time" }
end

-- Live: FPS each second, last 60 s
function M:LiveFps()
  local vals = {}
  for _, s in ipairs(self.samples) do if s.fps then vals[#vals + 1] = s.fps end end
  return { values = vals, slots = M.KEEP,
    colorOf = function(v) return v >= 50 and "good" or v >= 25 and "warn" or "bad" end,
    now = #vals > 0 and string.format("%.0f FPS now", vals[#vals]) or "",
    topText = function(max) return string.format("%.0f", max) end, empty = "starting..." }
end

-- This session, minute by minute: Outrider's share; red marks = a slow moment in that minute
function M.SessionChart()
  local W = ns.PerfWatch
  local rows = W and W.on and W.cur and W.cur.minutes or {}
  local vals, marks = {}, {}
  local slow = ns.db.global.perfSlow or {}
  for i, r in ipairs(rows) do
    vals[i] = r.secs and r.secs > 0 and r.ms / (r.secs * 1000) * 100 or 0
    local from, to = rows[i - 1] and rows[i - 1].at or (r.at and r.at - 60) or 0, r.at or 0
    for j = #slow, 1, -1 do
      local s = slow[j]
      if s.session ~= ns.session then break end
      if s.at and s.at > from and s.at <= to then marks[i] = true break end
    end
  end
  -- the newest 90 minutes fit the chart
  local start = math.max(1, #vals - 89)
  local v2, m2 = {}, {}
  for i = start, #vals do v2[#v2 + 1] = vals[i] if marks[i] then m2[#v2] = true end end
  return { values = v2, marks = m2, budget = M.BUDGETS.lagPct, budgetText = "budget 0.5%",
    colorOf = function(v) return v <= M.BUDGETS.lagPct and "good" or v <= 2 and "warn" or "bad" end,
    now = #v2 > 0 and string.format("%d minutes, red = a slow moment", #vals) or "",
    topText = function(max) return string.format("%.2f%%", max) end,
    empty = "the first minute shows after one minute of play" }
end

ns.Hub:AddTab("performance", "Performance", function(p)
  ns.UI:FormPage(p, {
    { "header", "What Outrider costs your game", icon = "Spell_Nature_TimeStop" },
    { "note", "Live numbers from the game itself, updated every second while this page is open. Outrider also watches itself the whole time you play: see Slow moments below." },
    { "stats", function() return M:Stats() end },
    { "custom", function(host) return M.Chart(host, "Outrider's time, each second (last minute)", function() return M:LiveCpu() end) end, M.CHART_H + 34, stretch = true },
    { "custom", function(host) return M.Chart(host, "Your FPS, each second (last minute)", function() return M:LiveFps() end) end, M.CHART_H + 34, stretch = true },
    { "custom", function(host) return M.Chart(host, "This session: Outrider's share of the game's time, each minute", M.SessionChart) end, M.CHART_H + 34, stretch = true },
    { "header", "CPU time", icon = "Trade_Engineering" },
    { "cards", function() return M:CpuLines() end },
    { "header", "Promises we keep", icon = "Ability_Warrior_DefensiveStance" },
    { "bars", function() return M:BudgetBars() end },
    { "check", "Watch performance all the time", function() return ns.PerfWatch and ns.PerfWatch.enabled end,
      function(on) ns.Modules:SetEnabled("PerfWatch", on) p:Refresh() end,
      "times everything Outrider does while you play and keeps every slow moment" },
    { "buttons", {
      { "Run a lag check (1 min)", function() if ns.LagCheck then ns.LagCheck:Start() end end },
      { "Copy for a post", function() ns.UI:TextDialog("Outrider performance", M:ShareText(), "copy") end },
    } },
    { "header", "Slow moments", icon = "Spell_Nature_Slow" },
    { "note", function()
      return #M.SlowRows() > 0 and "Every time Outrider took 20 ms or more at once, or the game froze for a quarter second or more (loading screens left out), with what you were doing. Newest first."
        or "No slow moments yet. Outrider keeps every one it sees while you play."
    end },
    { "bars", function() return M.SlowRows() end },
    { "header", "Heaviest parts of Outrider this session", icon = "Trade_Engineering" },
    { "bars", function() return M.Parts() end },
    { "header", "Minute by minute", icon = "INV_Misc_PocketWatch_02" },
    { "note", function()
      local W = ns.PerfWatch
      if W and W.on then return "This session, newest minute first, page open or closed." end
      return "The watch is off: switch on Watch performance all the time above."
    end },
    { "bars", function() return M.Minutes() end },
    { "header", "Past sessions", icon = "INV_Misc_PocketWatch_01" },
    { "bars", function() return M.Sessions() end },
    { "header", "Past lag checks", icon = "Spell_Holy_BorrowedTime" },
    { "bars", function() return M.Checks() end },
    { "note", function() return #M.Checks() == 0 and "No lag check yet: press Run a lag check above." or "" end },
    { "header", "Memory per session", icon = "INV_Misc_Gem_Pearl_04" },
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

ns.AddCommand("perfpage", "open the Performance page (Settings): FPS, latency, Outrider's CPU, memory and slow moments", function()
  ns.Hub:Build():Show()
  ns.Hub:ShowTab("performance")
end)

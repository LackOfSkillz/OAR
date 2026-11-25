-- Modules/PerfWatch.lua  (Gary, 2026-11-25: "the only way to do it is to
-- collect our data constantly during gameplay". A player found a one-second
-- lag that only happened while travelling with minimap dots showing; a check
-- someone has to start never sees a case nobody thought to test.)
--
-- Always on from login (switch: Performance page, or /ride module PerfWatch off):
--   * every Outrider event handler and timer is timed (Core/Events.lua and
--     Core/Timer.lua through ns.NoteTiming), summed per part of Outrider;
--   * a SPIKE: one Outrider handler or timer run of SPIKE_MS or more, kept
--     with what ran, the map, moving or not, in combat or not, and FPS;
--   * a FREEZE: the game itself stalled HITCH_S or more (a 0.5 s engine
--     timer fired late; no per-frame script), kept with how much of it was
--     Outrider's own time, so a freeze is either ours or clearly not ours;
--   * one row a minute: FPS average and low, world latency, Outrider's share.
-- Logout (or /reload) saves the session (global.perfWatch) and spikes and
-- freezes are saved as they happen (global.perfSlow); past their caps the
-- oldest go to the archive. A slow moment of LOG_MS or more also goes into
-- the log once per place per session, so Claude finds it with read-logs.
-- Cost: two clock reads per handler run and a 0.5 s timer.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("PerfWatch", {
  title = "Performance watch (always on)",
  phase = "P8",
  order = 93,
  defaults = {},
})
ns.PerfWatch = M

M.SPIKE_MS = 20       -- one run this long drops a frame or more at 60 FPS
M.HITCH_S = 0.25      -- the game stalled this long (a timer late by it)
M.TICK = 0.5
M.MERGE_S = 5         -- the same place again within this long counts up one row
M.LOG_MS = 100
M.SLOW_KEEP = 300     -- slow moments in view; older ones go to the archive
M.SESSIONS = 30       -- saved sessions in view; older ones go to the archive
M.LOADING_S = 8       -- loading screens freeze the game: not counted

function M:OnInitialize() self.on = false ns.Perf:AddSink(M) end

function M:OnEnable()
  self:On("PLAYER_LOGOUT", function(mod) mod:Save("logout") end)
  self:On("PLAYER_ENTERING_WORLD", function(mod) mod:Loading(false) end)
  self:On("LOADING_SCREEN_ENABLED", function(mod) mod:Loading(true) end)
  self:On("LOADING_SCREEN_DISABLED", function(mod) mod:Loading(false) end)
  self:Begin()
end

function M:OnDisable()
  self:Save("off")
  if self.ticker then self.ticker:Cancel() self.ticker = nil end
  self.on = false
  ns.Perf:UpdateTiming()
end

local function now() return C.Call("GetTime") or 0 end
-- a loading screen (and a few seconds after it) freezes the game on purpose
function M:Loading(on)
  self.loading = on or nil
  self.loadingUntil = now() + M.LOADING_S
end

function M:Begin()
  local t = now()
  self.cur = { started = t, startedAt = time(), total = 0, by = {}, fpsSum = 0, fpsN = 0, minutes = {},
    spikes = 0, hitches = 0, ours = 0, worst = { ms = 0, where = "-" } }
  self.last, self.window, self.logged, self.saved = t, 0, {}, false
  self.on = true
  ns.Perf:UpdateTiming()
  -- the game's own engine timer, not Outrider's queue: it is not a pending
  -- job and never keeps a per-frame script alive; without C_Timer there is
  -- no freeze detection and no minute rows (handler timing still works)
  if not self.ticker then
    local CT = rawget(_G, "C_Timer")
    if CT and type(CT.NewTicker) == "function" then
      local ok, h = pcall(CT.NewTicker, M.TICK, function()
        -- its own cost counts like any other part of Outrider
        local clock = rawget(_G, "debugprofilestop")
        local a = clock and clock()
        ns.Safe("PerfWatch:tick", M.Tick, M)
        if a and M.on then M:Note("timer perfwatch", clock() - a) end
      end)
      if ok then self.ticker = h end
    end
  end
end

-- every timed Outrider handler or timer run
function M:Note(where, ms)
  local s = self.cur
  if not s or type(ms) ~= "number" then return end
  s.total = s.total + ms
  self.window = self.window + ms
  local name = ns.Perf.Part(where)
  local p = s.by[name]
  if not p then p = { name = name, ms = 0, max = 0, n = 0 } s.by[name] = p end
  p.ms, p.n = p.ms + ms, p.n + 1
  if ms > p.max then p.max, p.worstAt = ms, where end
  if ms > s.worst.ms then s.worst = { ms = ms, where = where } end
  if ms >= M.SPIKE_MS then self:Slow("spike", where, ms) end
end

function M:Activity()
  local w = self.on and self:Summary()
  if not w then return "off" end
  return string.format("watching: Outrider %.2f%% of the game's time, %d slow moments, %d freezes this session", w.pct, w.spikes, w.hitches)
end

-- what the player was doing (all read-only, fail-soft)
function M.Context()
  local map = C.Call("C_Map.GetBestMapForUnit", "player")
  local moving = C.Call("IsPlayerMoving")
  local combat = C.Call("InCombatLockdown")
  return { map = tonumber(C.Readable(map)), moving = C.Readable(moving) == true or nil,
    combat = C.Readable(combat) == true or nil, fps = tonumber(C.Readable(C.Call("GetFramerate"))) }
end

function M.List()
  local g = ns.db.global
  g.perfSlow = ns.KeepTable(g.perfSlow, "PerfWatch:g.perfSlow") or {}
  return g.perfSlow
end

-- one slow moment: a spike (Outrider's) or a freeze (the game's)
function M:Slow(kind, where, ms, ours)
  local s = self.cur
  if kind == "spike" then s.spikes = s.spikes + 1 else s.hitches = s.hitches + 1 end
  if kind == "hitch" and ours and ours >= ms / 2 then s.ours = s.ours + 1 end
  local list = M.List()
  local at = time()
  local last = list[#list]
  if last and last.kind == kind and last.where == where and at - (last.last or last.at) <= M.MERGE_S then
    last.n, last.last = (last.n or 1) + 1, at
    if ms > last.ms then last.ms, last.ours = ms, ours end
  else
    local row = M.Context()
    row.at, row.kind, row.where, row.ms, row.ours, row.n = at, kind, where, ms, ours, 1
    row.build, row.char, row.session = ns.build, ns.db.key, ns.session
    list[#list + 1] = row
    while #list > M.SLOW_KEEP and ns.Archive:Shift("perfSlow", list, { path = "global.perfSlow", scope = "account" }) do end
  end
  if ms >= M.LOG_MS and not self.logged[kind .. where] then
    self.logged[kind .. where] = true
    if kind == "spike" then
      self:Warn("slow moment: %s took %.0f ms (%s)", tostring(where), ms, M.Describe(list[#list]))
    else
      self:Warn("game froze %.0f ms, Outrider's part %.0f ms (%s)", ms, ours or 0, M.Describe(list[#list]))
    end
  end
end

function M.Describe(r)
  local t = {}
  if r.moving then t[#t + 1] = "moving" end
  if r.combat then t[#t + 1] = "in combat" end
  if r.map then t[#t + 1] = "map " .. r.map end
  if r.fps then t[#t + 1] = string.format("FPS %.0f", r.fps) end
  return #t > 0 and table.concat(t, ", ") or "no context"
end

-- every 0.5 s: freezes, FPS and the minute rows
function M:Tick()
  local s = self.cur
  if not s then return end
  local t = now()
  local late = t - self.last - M.TICK
  self.last = t
  local ours = self.window
  self.window = 0
  if late >= M.HITCH_S and not self.loading and not (self.loadingUntil and t < self.loadingUntil) then
    self:Slow("hitch", "game", late * 1000, ours)
  end
  local f = tonumber(C.Readable(C.Call("GetFramerate")))
  local b = s.minute
  if not b or t - b.at >= 60 then
    self:CloseMinute()
    b = { at = t, fpsSum = 0, n = 0, total0 = s.total }
    s.minute = b
  end
  if f then
    s.fpsSum, s.fpsN = s.fpsSum + f, s.fpsN + 1
    if not s.fpsLow or f < s.fpsLow then s.fpsLow = f end
    b.fpsSum, b.n = b.fpsSum + f, b.n + 1
    if not b.low or f < b.low then b.low = f end
  end
  local _, _, _, world = C.Call("GetNetStats")
  world = tonumber(C.Readable(world))
  if world and (not b.world or world > b.world) then b.world = world end
end

function M:CloseMinute()
  local s = self.cur
  local b = s and s.minute
  if not b or b.n == 0 then return end
  local okp, P = pcall(ns.Perf.Profiler)
  s.minutes[#s.minutes + 1] = { at = time(), fps = b.fpsSum / b.n, low = b.low, world = b.world, ms = s.total - b.total0,
    secs = b.n * M.TICK, cpu = okp and P and P.recentMs or nil }
  s.minute = nil
end

-- the session so far
function M:Summary()
  local s = self.cur
  if not s then return nil end
  local secs = math.max(1, now() - s.started)
  local parts = {}
  for _, p in pairs(s.by) do parts[#parts + 1] = p end
  table.sort(parts, function(a, b) return a.ms > b.ms end)
  return { seconds = math.floor(secs + 0.5), totalMs = s.total, pct = s.total / (secs * 1000) * 100,
    fpsAvg = s.fpsN > 0 and s.fpsSum / s.fpsN or nil, fpsLow = s.fpsLow, spikes = s.spikes, hitches = s.hitches,
    ours = s.ours, worst = s.worst, parts = parts, minutes = s.minutes, startedAt = s.startedAt }
end

-- logout, /reload or switched off: the session is saved once
function M:Save(why)
  if self.saved or not self.cur then return nil end
  self:CloseMinute()
  local r = self:Summary()
  self.saved = true
  local keep = {}
  for i = 1, math.min(10, #r.parts) do
    local p = r.parts[i]
    keep[i] = { name = p.name, ms = math.floor(p.ms * 10 + 0.5) / 10, max = math.floor(p.max * 10 + 0.5) / 10, n = p.n, worstAt = p.worstAt }
  end
  local row = { session = ns.session, build = ns.build, char = ns.db.key, startedAt = r.startedAt, seconds = r.seconds,
    pct = r.pct, totalMs = r.totalMs, fpsAvg = r.fpsAvg, fpsLow = r.fpsLow, spikes = r.spikes, hitches = r.hitches,
    ours = r.ours, worst = r.worst, parts = keep, minutes = r.minutes, why = why }
  local g = ns.db.global
  g.perfWatch = ns.KeepTable(g.perfWatch, "PerfWatch:g.perfWatch") or {}
  local list = g.perfWatch
  list[#list + 1] = row
  while #list > M.SESSIONS and ns.Archive:Shift("perfWatch", list, { path = "global.perfWatch", scope = "account" }) do end
  self:Info("session (%s): Outrider %.3f%% of the game's time (%.0f ms in %d s), %d spikes, %d freezes (%d mostly Outrider's), slowest %.1f ms in %s, FPS avg %s low %s",
    tostring(why), r.pct, r.totalMs, r.seconds, r.spikes, r.hitches, r.ours, r.worst.ms, tostring(r.worst.where),
    r.fpsAvg and string.format("%.0f", r.fpsAvg) or "?", r.fpsLow and string.format("%.0f", r.fpsLow) or "?")
  return row
end

-- Modules/LagCheck.lua  (requirement 2026-11-21: a user reported FPS drops;
-- give users a way to debug lag)
-- A one-minute measurement any player can start (Help, Report or idea, "Check
-- for lag"; /ride lag): while it runs, every Outrider event handler and timer
-- is timed (Core/Events.lua and Core/Timer.lua ask M.on) and the game's FPS is
-- sampled twice a second. Then, in plain words: how much of the game's time
-- Outrider used, its slowest single moment (one long moment is a stutter),
-- FPS average and low, and the heaviest parts of Outrider with a Turn off
-- button each. The result is kept (ns.db.global.lagCheck) and goes into the
-- next report, so it reaches us on GitHub.
-- Timing only while a check runs: debugprofilestop costs a little itself.
-- Monitoring (Gary, 2026-11-25: "when I press a button, I wanna be able to
-- continually monitor performance"): Start(0) runs until Stop, with the page
-- open or closed, and keeps one row per minute (FPS, latency, Outrider's
-- share, the game profiler's number). Running totals plus one small row a
-- minute. Logging out or /reload ends the run and saves it, like Stop.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("LagCheck", {
  title = "Lag check",
  phase = "P8",
  order = 91,
  defaults = {},
})
ns.LagCheck = M

M.SECONDS = 60
M.SAMPLE = 0.5            -- seconds between FPS samples
M.STUTTER_MS = 16         -- one handler this long drops a frame at 60 FPS
M.LEVELS = { { 0.5, "fine" }, { 2, "small" } } -- % of the game's time; above: heavy

function M:OnInitialize() self.on = false end

-- a timing sink (Core/Perf.lua): timed while a check runs
ns.Perf:AddSink(M)
-- a running check stops with the module (OI01-11: no sampler left behind)
function M:OnDisable() if self.on then self:Stop("module off") end end
function M:OnEnable()
  -- logging out or reloading mid-run: save what was measured
  self:On("PLAYER_LOGOUT", function(mod) if mod.on then mod:Stop("logout") end end)
end

-- one finished minute of a run
local function closeMinute(d)
  local b = d.minute
  if not b or b.n == 0 then return end
  local okp, P = pcall(ns.Perf.Profiler)
  if not okp then P = nil end
  d.minutes[#d.minutes + 1] = { fps = b.fpsSum / b.n, low = b.low, world = b.world, ms = d.total - b.total0,
    secs = b.n * M.SAMPLE, cpu = P and P.recentMs or nil }
end

-- Called by the event and timer dispatch while a check runs.
function M:Note(where, ms, _kb)
  local d = self.data
  if not d or type(ms) ~= "number" then return end
  local e = d.by[where]
  if not e then e = { where = where, ms = 0, max = 0, n = 0 } d.by[where] = e end
  e.ms, e.n = e.ms + ms, e.n + 1
  if ms > e.max then e.max = ms end
  d.total = d.total + ms
  if ms > d.worst.ms then d.worst = { where = where, ms = ms } end
end

function M:Start(seconds)
  if self.on then return false, "already checking" end
  seconds = seconds or M.SECONDS
  local open = seconds == 0
  self.data = { by = {}, total = 0, worst = { where = "-", ms = 0 }, fpsSum = 0, fpsN = 0, seconds = seconds,
    open = open, minutes = {}, started = C.Call("GetTime") or 0 }
  self.on = true
  ns.Perf:UpdateTiming()
  self.sampler = ns.Timer.Ticker(M.SAMPLE, function()
    local d = self.data
    if not d then return end
    local f = tonumber(C.Readable(C.Call("GetFramerate")))
    local now = C.Call("GetTime") or 0
    local b = d.minute
    if not b or now - b.at >= 60 then
      closeMinute(d)
      b = { at = now, fpsSum = 0, n = 0, total0 = d.total }
      d.minute = b
    end
    if f then
      d.fpsSum, d.fpsN = d.fpsSum + f, d.fpsN + 1
      if not d.fpsLow or f < d.fpsLow then d.fpsLow = f end
      b.fpsSum, b.n = b.fpsSum + f, b.n + 1
      if not b.low or f < b.low then b.low = f end
    end
    local _, _, _, world = C.Call("GetNetStats")
    world = tonumber(C.Readable(world))
    if world and (not b.world or world > b.world) then b.world = world end
  end, "lagcheck:fps")
  if not open then self.timer = ns.Timer.After(seconds, function() M:Stop("done") end, "lagcheck:end") end
  self:Info(open and "monitoring started (until stopped)" or "lag check started for %d seconds", seconds)
  ns.Events:Fire("OTR_LAGCHECK", "started")
  return true
end

-- Part of Outrider a timing belongs to: "MinimapPins:PLAYER_STARTED_MOVING" -> MinimapPins.
M.Part = function(where) return ns.Perf.Part(where) end

-- The finished result (also used while running, for a progress line).
function M:Summary()
  local d = self.data
  if not d then return nil end
  local now = C.Call("GetTime") or d.started
  local secs = math.max(1, d.open and (now - d.started) or math.min(d.seconds, now - d.started))
  local parts = {}
  for where, e in pairs(d.by) do
    local name = M.Part(where)
    local p = parts[name]
    if not p then p = { name = name, ms = 0, max = 0, n = 0 } parts[name] = p end
    p.ms, p.n = p.ms + e.ms, p.n + e.n
    if e.max > p.max then p.max, p.worstAt = e.max, where end
  end
  local list = {}
  for _, p in pairs(parts) do list[#list + 1] = p end
  table.sort(list, function(a, b) return a.ms > b.ms end)
  local pct = d.total / (secs * 1000) * 100
  local level = "heavy"
  for _, l in ipairs(M.LEVELS) do if pct < l[1] then level = l[2] break end end
  return { seconds = math.floor(secs + 0.5), totalMs = d.total, pct = pct, level = level,
    worst = d.worst, fpsAvg = d.fpsN > 0 and d.fpsSum / d.fpsN or nil, fpsLow = d.fpsLow, parts = list, open = d.open,
    stutter = d.worst.ms >= M.STUTTER_MS, at = time(), build = ns.build }
end

function M:Stop(why)
  if not self.on then return nil end
  self.on = false
  ns.Perf:UpdateTiming()
  if self.sampler then self.sampler:Cancel() self.sampler = nil end
  if self.timer then self.timer:Cancel() self.timer = nil end
  closeMinute(self.data)
  local s = self:Summary()
  local keep = {}
  for i = 1, math.min(5, #s.parts) do
    local p = s.parts[i]
    keep[i] = { name = p.name, ms = math.floor(p.ms * 10 + 0.5) / 10, max = math.floor(p.max * 10 + 0.5) / 10, n = p.n }
  end
  ns.db.global.lagCheck = { at = s.at, build = s.build, seconds = s.seconds, pct = s.pct, level = s.level,
    totalMs = s.totalMs, worst = s.worst, fpsAvg = s.fpsAvg, fpsLow = s.fpsLow, parts = keep, stutter = s.stutter,
    monitor = s.open or nil, minutes = #self.data.minutes > 0 and self.data.minutes or nil }
  self:Info("lag check (%s): Outrider %.2f%% of the time (%.0f ms in %d s), slowest %.1f ms in %s, FPS avg %s low %s; heaviest: %s",
    tostring(why), s.pct, s.totalMs, s.seconds, s.worst.ms, tostring(s.worst.where),
    s.fpsAvg and string.format("%.0f", s.fpsAvg) or "?", s.fpsLow and string.format("%.0f", s.fpsLow) or "?",
    #keep > 0 and (keep[1].name .. " " .. keep[1].ms .. " ms") or "nothing")
  ns.Print(M.Verdict(ns.db.global.lagCheck))
  ns.Events:Fire("OTR_LAGCHECK", "done")
  self.data = nil
  return ns.db.global.lagCheck
end

-- One plain sentence for a result.
function M.Verdict(r)
  if not r then return "No lag check yet." end
  local fps = r.fpsAvg and string.format(" Your FPS: about %.0f (lowest %.0f).", r.fpsAvg, r.fpsLow or r.fpsAvg) or ""
  local base
  if r.level == "fine" then
    base = string.format("Outrider used %.1f%% of the game's time: it isn't what's slowing your game.", r.pct)
  elseif r.level == "small" then
    base = string.format("Outrider used %.1f%% of the game's time: a small part.", r.pct)
  else
    base = string.format("Outrider used %.1f%% of the game's time: that's a lot. Turn off its heaviest part below and check again.", r.pct)
  end
  if r.stutter then
    base = base .. string.format(" Its slowest moment was %.0f ms (%s): that can cause a short stutter.", r.worst.ms, M.Part(r.worst.where))
  end
  return base .. fps
end

-- Lines for a report (Feedback): only when a check ran in the last day.
function M.ReportLines()
  local r = ns.db.global.lagCheck
  if not r or not r.at or time() - r.at > 86400 then return nil end
  local parts = {}
  for _, p in ipairs(r.parts or {}) do parts[#parts + 1] = string.format("%s %.1f ms (max %.1f, %d calls)", p.name, p.ms, p.max, p.n) end
  return {
    { "Lag check", string.format("Outrider %.2f%% of %d s (%s); slowest %.1f ms in %s; FPS avg %s, low %s", r.pct, r.seconds, r.level,
      r.worst and r.worst.ms or 0, tostring(r.worst and r.worst.where), r.fpsAvg and string.format("%.0f", r.fpsAvg) or "?",
      r.fpsLow and string.format("%.0f", r.fpsLow) or "?") },
    { "Heaviest parts", #parts > 0 and table.concat(parts, "; ") or "none" },
  }
end

function M:Activity()
  if self.on then
    local s = self:Summary()
    if self.data and self.data.open then
      return string.format("monitoring: %d min so far, Outrider %.2f%% of the game's time", math.floor((s and s.seconds or 0) / 60), s and s.pct or 0)
    end
    return string.format("checking: %d of %d seconds", s and s.seconds or 0, self.data and self.data.seconds or M.SECONDS)
  end
  return M.Verdict(ns.db.global.lagCheck)
end

ns.AddCommand("lag", "[stop]  one-minute lag check: how much of the game's time Outrider uses", function(arg)
  arg = (arg or ""):lower()
  if arg == "stop" then M:Stop("stopped") return end
  local ok, why = M:Start()
  ns.Print(ok and "Lag check running for 1 minute: play as usual (move, fight, open the map). The result shows here." or why)
end)

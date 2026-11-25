-- The Performance page (Modules/PerfPage.lua; Gary, 2026-11-25: players
-- watch latency and CPU, so show what Outrider costs). Numbers are test data.
local T, mock = ...

local function session(opts)
  opts = opts or {}
  local game = mock.new({ class = "SHAMAN", level = 2, memoryKB = opts.memoryKB or 1500 })
  game.fps, game.latency = 60, 45
  game.addonList = { "Questie", "Details" }
  game.addonMemory = { Questie = 30000, Details = 8500 }
  game.loadedAddons.Questie, game.loadedAddons.Details = true, true
  if opts.profiler then
    local env = game.env
    local E = rawget(env, "Enum")
    E.AddOnProfilerMetric = { SessionAverageTime = 0, RecentAverageTime = 1, EncounterAverageTime = 2, LastTime = 3,
      PeakTime = 4, CountTimeOver1Ms = 5, CountTimeOver5Ms = 6, CountTimeOver10Ms = 7, CountTimeOver50Ms = 8 }
    local addon = { [0] = 0.08, [1] = 0.05, [4] = 3.2, [6] = 4, [8] = 0 }
    rawset(env, "C_AddOnProfiler", {
      IsEnabled = function() return opts.profiler ~= "off" end,
      GetAddOnMetric = function(name, m) if name == "Outrider" then return addon[m] end return 0 end,
      GetOverallMetric = function(m) if m == 1 then return 1.25 end return 0 end,
      GetApplicationMetric = function(m) if m == 1 then return 16.6 end return 0 end,
    })
  end
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game:advance(2)
  return game, ns, ns.PerfPage
end

T.describe("performance page", function()
  T.it("reads the game's add-on profiler: Outrider's ms per frame and its share", function()
    local _, ns, M = session({ profiler = true })
    local p = M.Profiler()
    T.ok(p, "profiler numbers")
    T.eq(p.recentMs, 0.05)
    T.eq(p.over5, 4)
    T.ok(math.abs(p.shareAddons - 4) < 0.001, "0.05 of 1.25 ms is 4% of all add-ons")
    T.ok(p.shareGame < 1)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("without the profiler (or with it off) it says so and points to the lag check", function()
    local _, _, M = session()
    local p, why = M.Profiler()
    T.eq(p, nil)
    T.contains(why, "no add-on profiler")
    T.contains(M:CpuLines()[1].line, "lag check")
    local _, _, M2 = session({ profiler = "off" })
    local _, why2 = M2.Profiler()
    T.contains(why2, "off")
  end)

  T.it("memory: Outrider's own and its share of every loaded add-on", function()
    local _, _, M = session({ memoryKB = 2000 })
    local m = M:Memory(true)
    T.eq(m.mine, 2000)
    T.eq(m.all, 40500)
    T.eq(m.addons, 3)
  end)

  T.it("samples only while the page is open; FPS low and average, latency", function()
    local game, ns, M = session()
    T.eq(M.ticker, nil, "nothing runs before the page opens")
    ns.Hub:Build():Show()
    ns.Hub:ShowTab("performance")
    T.ok(M.ticker, "live while open")
    game.fps = 30
    game:advance(1.1)
    game.fps = 60
    game:advance(1.1)
    local live = M:Live()
    T.eq(live.fpsLow, 30)
    T.eq(live.world, 45)
    T.ok(live.fpsAvg > 30 and live.fpsAvg < 60)
    ns.Hub.frame:Hide()
    T.eq(M.ticker, nil, "stops when the Hub closes")
    T.ok(#M.samples <= M.KEEP)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("budgets pass or fail from real readings, and unmeasured ones say so", function()
    local _, _, M = session({ profiler = true, memoryKB = 99999 })
    local by = {}
    for _, b in ipairs(M:Budgets()) do by[b[1]:match("^(%a+)")] = b end
    T.eq(by.Memory[2], false, "over the memory budget fails")
    T.eq(by.Under[2], true, "0.05 ms per frame passes")
    T.eq(by.Lag[2], nil, "no lag check yet: not measured, not a pass")
  end)

  T.it("the share text has numbers but no character, realm or gold", function()
    local _, ns, M = session({ profiler = true })
    M:Sample()
    local t = M:ShareText()
    T.contains(t, "CPU (game profiler)")
    T.contains(t, "Memory:")
    T.ok(not t:find(ns.db.key, 1, true), "no character key")
    T.ok(not t:find("gold", 1, true))
  end)

  T.it("every finished lag check is kept; past the cap the oldest go to the archive", function()
    local game, ns, M = session()
    for i = 1, M.CHECKS + 2 do
      ns.db.global.lagCheck = { at = 1000 + i, pct = 0.1, level = "fine", seconds = 60, worst = { ms = 1, where = "x" } }
      ns.Events:Fire("OTR_LAGCHECK", "done")
    end
    T.eq(#ns.db.global.lagChecks, M.CHECKS)
    T.eq(#ns.Archive:Rows("lagChecks"), 2, "older checks archived, not dropped")
    T.eq(#M.Checks(), 10, "the page shows the newest 10")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("the session row saved at logout carries the profiler numbers", function()
    local _, ns = session({ profiler = true })
    local r = ns.Perf:Report(true)
    T.eq(r.runtime.profiler.recentMs, 0.05)
    T.eq(ns.db.global.perfRuns[#ns.db.global.perfRuns].runtime.profiler.sessionMs, 0.08)
  end)

  T.it("Monitor runs until stopped, page open or closed, one row a minute (not one minute)", function()
    local game, ns, M = session()
    local L = ns.LagCheck
    T.ok(L:Start(0), "monitoring started")
    game.fps = 50
    game:advance(61)
    game.fps = 40
    game:advance(61)
    game:advance(200)
    T.ok(L.on, "still running after five minutes")
    T.eq(M.ticker, nil, "the page isn't open: only the monitor runs")
    T.ok(#L.data.minutes >= 4, "a row per finished minute")
    T.ok(math.abs(L.data.minutes[1].fps - 50) < 1)
    T.contains(L:Activity(), "monitoring: 5 min")
    T.ok(#M.Minutes() >= 4, "the page lists the minutes while it runs")
    local r = L:Stop("stopped")
    T.ok(r.monitor, "saved as a monitoring run")
    T.ok(r.seconds >= 320, "covers the whole run, not 60 s: " .. r.seconds)
    T.eq(r.fpsLow, 40)
    T.ok(#ns.db.global.lagChecks >= 1, "kept with past checks")
    T.ok(#M.Minutes() >= 4, "the last run's minutes stay on the page")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("logging out mid-run saves it; the one-minute check still stops by itself", function()
    local game, ns = session()
    local L = ns.LagCheck
    L:Start(0)
    game:advance(90)
    game:fire("PLAYER_LOGOUT")
    T.ok(not L.on, "stopped at logout")
    T.ok(ns.db.global.lagCheck.monitor, "the run was saved")
    L:Start()
    game:advance(61)
    T.ok(not L.on, "the one-minute check ends by itself")
    T.ok(not ns.db.global.lagCheck.monitor)
  end)
end)

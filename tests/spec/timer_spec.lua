-- Timers, tickers and throttling (P1-04).
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("timer", function()
  T.it("After runs once, after the delay", function()
    local game, ns = session()
    local n = 0
    ns.Timer.After(1, function() n = n + 1 end)
    game:advance(0.5)
    T.eq(n, 0)
    game:advance(0.6)
    T.eq(n, 1)
    game:advance(5)
    T.eq(n, 1)
    T.eq(ns.Timer.Pending(), 0)
  end)

  T.it("a cancelled After never runs", function()
    local game, ns = session()
    local n = 0
    local h = ns.Timer.After(1, function() n = n + 1 end)
    h:Cancel()
    game:advance(2)
    T.eq(n, 0)
    T.eq(ns.Timer.Pending(), 0)
  end)

  T.it("a ticker repeats until cancelled", function()
    local game, ns = session()
    local n = 0
    local h = ns.Timer.Ticker(1, function() n = n + 1 end)
    game:advance(3.5)
    T.eq(n, 3)
    h:Cancel()
    game:advance(5)
    T.eq(n, 3)
    T.eq(ns.Timer.Pending(), 0)
  end)

  T.it("a failing ticker is recorded and keeps ticking", function()
    local game, ns = session()
    local n = 0
    local h = ns.Timer.Ticker(1, function() n = n + 1 error("tick broke") end, "bad ticker")
    game:advance(3.5)
    T.eq(n, 3)
    T.eq(#ns.Errors.list, 1)
    T.eq(ns.Errors.list[1].count, 3)
    h:Cancel()
  end)

  T.it("falls back to an OnUpdate frame that only runs while timers are pending", function()
    local game, ns = session({ noCTimer = true })
    T.ok(ns.Timer.UsingFallback())
    T.no(ns.Timer.DriverRunning(), "idle: no OnUpdate")
    local n = 0
    ns.Timer.After(0.3, function() n = n + 1 end)
    T.ok(ns.Timer.DriverRunning())
    for _ = 1, 10 do game:advance(0.05) end
    T.eq(n, 1)
    T.no(ns.Timer.DriverRunning(), "driver hides again when nothing is pending")
    local h = ns.Timer.Ticker(0.1, function() n = n + 1 end)
    for _ = 1, 10 do game:advance(0.05) end
    T.ok(n >= 4)
    h:Cancel()
    game:advance(0.05)
    T.no(ns.Timer.DriverRunning())
  end)
end)

T.describe("throttle", function()
  T.it("a burst of 20 calls in 0.1 s runs once now and once trailing, with the last arguments", function()
    local game, ns = session()
    local runs = {}
    for i = 1, 20 do
      ns.Throttle("scan", 0.25, function(v) runs[#runs + 1] = v end, i)
      game:advance(0.005)
    end
    T.eq(#runs, 1)
    T.eq(runs[1], 1)
    game:advance(0.5)
    T.eq(#runs, 2)
    T.eq(runs[2], 20)
    game:advance(1)
    T.eq(#runs, 2, "no extra runs after the burst")
  end)

  T.it("keys are independent and calls spaced out all run", function()
    local game, ns = session()
    local a, b = 0, 0
    for _ = 1, 4 do
      ns.Throttle("a", 0.25, function() a = a + 1 end)
      ns.Throttle("b", 0.25, function() b = b + 1 end)
      game:advance(0.3)
    end
    T.eq(a, 4)
    T.eq(b, 4)
  end)

  T.it("ThrottleCancel drops the trailing run", function()
    local game, ns = session()
    local n = 0
    ns.Throttle("x", 1, function() n = n + 1 end)
    ns.Throttle("x", 1, function() n = n + 1 end)
    ns.ThrottleCancel("x")
    game:advance(2)
    T.eq(n, 1)
  end)
end)

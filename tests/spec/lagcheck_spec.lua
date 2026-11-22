-- Lag check (Gary, 2026-11-21: "my daughter is saying it's causing some fps
-- drops"). The mock clock drives debugprofilestop; FPS is game.fps.
local T, mock = ...

local function start()
  local game = mock.new({ class = "PRIEST", level = 20 })
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  return game, ns, ns.LagCheck
end

T.describe("lag check", function()
  T.it("times handlers and timers only while it runs, and names the heaviest part", function()
    local game, ns, L = start()
    local slow = { name = "SpecSlow" }
    ns.Events:On("SPEC_LAG_EVENT", slow, function() game.clock = game.clock + 0.03 end) -- 30 ms each
    game:fire("SPEC_LAG_EVENT")
    T.eq(L.data, nil, "nothing recorded before a check")
    T.ok(L:Start(60))
    game.fps = 42
    for _ = 1, 5 do game:fire("SPEC_LAG_EVENT") end
    ns.Timer.After(1, function() game.clock = game.clock + 0.002 end, "SpecTimer:tick")
    game:advance(61)
    T.eq(L.on, false, "stops by itself after a minute")
    local r = ns.db.global.lagCheck
    T.ok(r, "result kept")
    T.eq(r.parts[1].name, "SpecSlow")
    T.ok(r.parts[1].ms >= 149, "five handlers of 30 ms: " .. tostring(r.parts[1].ms))
    T.ok(r.stutter, "a 30 ms moment is a stutter")
    T.ok(math.abs((r.fpsAvg or 0) - 42) < 1, "FPS sampled")
    local timerSeen = false
    for _, p in ipairs(r.parts) do if p.name:find("SpecTimer", 1, true) then timerSeen = true end end
    T.ok(timerSeen, "timers are timed too")
    T.contains(L.Verdict(r), "stutter")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("says plainly when Outrider isn't the cause, and the report carries the result", function()
    local game, ns, L = start()
    L:Start(60)
    game:advance(61)
    local r = ns.db.global.lagCheck
    T.eq(r.level, "fine")
    T.contains(L.Verdict(r), "isn't what's slowing your game")
    local lines = ns.Feedback.Details(false)
    local found = false
    for _, d in ipairs(lines) do if d[1] == "Lag check" then found = true end end
    T.ok(found, "the next report includes the lag check")
  end)

  T.it("runs from the report page and from /ride lag", function()
    local game, ns, L = start()
    game:slash("report")
    local p = ns.Hub.byId.feedback.panel
    p.lagBtn:Click()
    T.ok(L.on, "started from the button")
    T.contains(p.lagText:GetText(), "Checking")
    p.lagBtn:Click()
    T.eq(L.on, false, "the same button stops it")
    game:slash("lag")
    T.ok(L.on)
    game:slash("lag stop")
    T.eq(L.on, false)
    T.eq(#ns.Errors.list, 0)
  end)
end)

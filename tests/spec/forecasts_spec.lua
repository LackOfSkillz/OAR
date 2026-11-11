-- Forecasts (P8-08). Gaps and sessions are test data.
local T, mock = ...

T.describe("forecasts", function()
  T.it("respawn ranges need 3 observations and show the count", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    local F = ns.Forecasts
    T.eq(F.Respawn({ 600, 700 }).lo, nil)
    local r = F.Respawn({ 600, 900, 700 })
    T.eq(r.lo, 600) T.eq(r.hi, 900) T.eq(r.median, 700) T.eq(r.n, 3)
    local wide = F.Respawn({ 100, 600, 610, 620, 630, 640, 650, 660, 670, 5000 })
    T.ok(wide.lo >= 600 and wide.hi <= 670, "outliers trimmed")
    ns.db.global.respawnObs[5807] = { 600, 900, 700 }
    local lines = F:RespawnLines()
    T.contains(lines[1].text, "10 to 15 min, usually 12 (3 observations)")
    game:slash("forecast")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("gold per hour over sessions of 10+ minutes, with a trend", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    local F = ns.Forecasts
    T.eq(F.Gold({ { start = 0, stop = 60, net = 500 } }), nil, "too short")
    local s = {}
    for i = 1, 8 do s[i] = { start = 0, stop = 3600, net = i <= 3 and 10000 or 30000 } end
    local g = F.Gold(s)
    T.eq(g.sessions, 8)
    T.eq(g.trend, "up")
    ns.db.char.ledger = s
    T.contains(F:GoldLine(), "per hour over 8 sessions, trend up (estimate)")
  end)
end)

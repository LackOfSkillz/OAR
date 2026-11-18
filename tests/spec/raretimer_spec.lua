-- Rare timer: next window every N hours from a start, restarted by a kill.
local T, mock = ...

T.describe("rare timer", function()
  T.it("counts windows every 3 h from the restart; a seen kill restarts it; warns 5 min before", function()
    local game = mock.new({ now = 1794600000 + 3600 })
    local ns = game:loadAddon()
    game:login()
    local R = ns.RareTimer
    local t = ns.db.global.rareTimers[259388]
    T.ok(t and t.off, "Mystmane timer seeded from Gary's report, then switched off after two missed windows")
    T.eq(R:Line(259388, 1794600000 + 3600), nil)
    t.off = nil -- the timer logic itself, on the same data
    T.eq(R.Next(t, 1794600000 + 3600), 1794600000 + 3 * 3600)
    T.contains(R:Line(259388, 1794600000 + 3600), "in 2h 00m")
    game.now = 1794600000 + 3 * 3600 - 200
    R:Tick()
    local warned
    for _, l in ipairs(ns.Log:Tail(10)) do if ns.Log:FormatLine(l):find("Mystmane window soon", 1, true) then warned = true end end
    T.ok(warned)
    game.now = 1794600000 + 4 * 3600
    R:OnRareSeen(nil, { npcID = 259388, dead = true })
    T.eq(R.Next(t, game.now + 1), game.now + 3 * 3600)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a switched-off timer shows nothing and never warns", function()
    local game = mock.new({ now = 1794600000 + 3 * 3600 - 200 })
    local ns = game:loadAddon()
    game:login()
    ns.RareTimer:Tick()
    for _, l in ipairs(ns.Log:Tail(20)) do T.ok(not ns.Log:FormatLine(l):find("window soon", 1, true)) end
    T.contains(ns.RareTimer:Activity(), "no fixed timer") T.contains(ns.RareTimer:Activity(), "Nov 13")
  end)
end)

-- /ride perf (P1-11).
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false) -- its timers/combat hooks would skew these counts
  return game, ns
end

T.describe("perf", function()
  T.it("reports memory, handlers, timers and saves the result", function()
    local game, ns = session()
    for _ = 1, 5 do game:fire("BAG_UPDATE_DELAYED") end
    game:advance(3) -- let throttled handlers settle before measuring
    game:slash("perf")
    local r = ns.db.global.perf
    T.ok(game.memoryUpdated)
    T.eq(r.memoryKB, 420)
    T.ok(r.handlers > 0)
    T.eq(r.timers, 0)
    T.no(r.timerDriver)
    T.eq(#r.overBudget, 0)
    T.contains(game:chatText(), "memory 420 KB")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("flags memory over the 1.5 MB budget", function()
    local game, ns = session({ memoryKB = 4000 })
    game:slash("perf")
    T.same(ns.db.global.perf.overBudget, { "memory" })
  end)

  T.it("counts events always and times handlers only in debug mode", function()
    local game, ns = session()
    ns.Events:On("BAG_UPDATE_DELAYED", { name = "probe" }, function() end)
    game:fire("BAG_UPDATE_DELAYED")
    T.eq(ns.Events.stats.BAG_UPDATE_DELAYED, 1)
    T.eq(#ns.Events.slow, 0)
    ns.db.global.debug = true
    game:fire("BAG_UPDATE_DELAYED")
    T.ok(#ns.Events.slow >= 1)
    T.eq(ns.Events.stats.BAG_UPDATE_DELAYED, 2)
  end)
end)

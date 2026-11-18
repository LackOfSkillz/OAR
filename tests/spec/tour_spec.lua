-- /ride tour (D19, development only): one screenshot per page, each on a click of Next.
local T, mock = ...

T.describe("page tour", function()
  T.it("opens every page in turn and takes one screenshot per click of Next, never by itself", function()
    local game = mock.new({ class = "HUNTER", level = 20 })
    local shots = 0
    game.base.Screenshot = function() shots = shots + 1 end
    rawset(game.env, "Screenshot", game.base.Screenshot)
    local ns = game:loadAddon()
    game:login()
    local Tour = ns.Hub.Tour
    game:slash("tour")
    T.ok(Tour.steps and #Tour.steps > 5, "a step per page plus the map")
    T.ok(ns.Hub.frame:IsShown(), "first page open")
    game:advance(5)
    T.eq(shots, 0, "nothing is captured without a click")
    local first = ns.Hub.current
    Tour:Capture()
    game:advance(2)
    T.eq(shots, 1)
    T.ok(ns.Hub.current ~= first, "moved to the next page")
    while Tour.steps do Tour:Capture() game:advance(2) end
    T.ok(shots >= 5)
    T.ok(not Tour.bar:IsShown(), "bar gone at the end")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("refuses to start in combat", function()
    local game = mock.new({ class = "HUNTER", level = 20 })
    local ns = game:loadAddon()
    game:login()
    game:setCombat(true)
    game:slash("tour")
    T.ok(not ns.Hub.Tour.steps)
  end)
end)

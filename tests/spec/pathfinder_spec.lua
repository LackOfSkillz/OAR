-- OI04-13: Pathfinder measured routes.
local T, mock = ...

local function session()
  local game = mock.new({ mapID = 1412, x = 0.5, y = 0.5 })
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.Pathfinder
end
local function trip(from, to, est, secs, build) return { walking = true, fromMap = from, toMap = to, estimate = est, seconds = secs, build = build or "B" } end

T.describe("Pathfinder measured routes (OI04-13)", function()
  T.it("the route's own trips first, then your walking in general, else Travel's estimate", function()
    local _, _, PF = session()
    local trips = { trip(1, 2, 100, 150), trip(1, 2, 100, 140), trip(1, 2, 100, 160), trip(3, 4, 100, 110), trip(5, 6, 100, 120) }
    local f, src, n = PF.Factor(1, 2, trips, "B")
    T.eq(f, 1.5) T.eq(src, "your trips on this route") T.eq(n, 3)
    f, src = PF.Factor(7, 8, trips, "B")
    T.eq(src, "your walking in general") T.eq(f, 1.4)
    f, src = PF.Factor(7, 8, { trip(1, 2, 100, 150) }, "B")
    T.eq(f, 1) T.eq(src, "Travel's estimate", "no history: the plain estimate")
  end)

  T.it("another game build's trips don't count", function()
    local _, _, PF = session()
    local trips = { trip(1, 2, 100, 300, "OLD"), trip(1, 2, 100, 300, "OLD"), trip(1, 2, 100, 300, "OLD") }
    local f, src = PF.Factor(1, 2, trips, "NEW")
    T.eq(f, 1) T.eq(src, "Travel's estimate")
  end)

  T.it("a long unwalked last leg is a straight line, not a road; slow mode takes longer", function()
    local _, _, PF = session()
    local e = PF.Estimate(600, { fromMap = 1, toMap = 9, trips = {}, lastLeg = 400 })
    T.ok(e.straightLine) T.ok(e.note:find("no known road"))
    local walked = { trip(1, 9, 600, 600), trip(1, 9, 600, 600), trip(1, 9, 600, 600) }
    T.eq(PF.Estimate(600, { fromMap = 1, toMap = 9, trips = walked, lastLeg = 400, build = "B" }).straightLine, nil, "walked: a real road")
    T.eq(PF.Estimate(600, { slow = true }).seconds, math.floor(600 * PF.SLOW + 0.5))
  end)

  T.it("no known way stays unknown (never a straight line)", function()
    local _, ns, PF = session()
    T.eq(PF.Estimate(nil, {}), nil)
    T.ok(ns.Travel.TimeToRaw, "the original is kept")
    local real = ns.Travel.TimeToRaw
    ns.Travel.TimeToRaw = function() return nil end
    -- the wrapper calls the raw function it captured at login, so test through a fresh install
    ns.Travel.TimeToRaw = nil
    ns.Travel.TimeTo = function() return nil end
    PF.Install()
    T.eq(ns.Travel:TimeTo({}, { mapID = 9 }), nil)
    ns.Travel.TimeToRaw = real
  end)

  T.it("Travel:TimeTo is corrected live, and says where the figure came from; trips keep the raw estimate", function()
    local game, ns, PF = session()
    local prep = { best = { [2] = 100 } }
    local target = { mapID = 9 }
    ns.Travel.TimeToRaw = nil
    ns.Travel.TimeTo = function() return 400, 2 end
    PF.Install()
    local secs, via, est = ns.Travel:TimeTo(prep, target)
    T.eq(via, 2) T.eq(est.raw, 400) T.eq(est.source, "Travel's estimate")
    T.ok(est.straightLine, "300 s straight last leg")
    T.eq(ns.Travel:TimeToRaw(prep, target), 400)
  end)

  T.it("deviation: how far real trips were from the plan", function()
    local _, _, PF = session()
    local d = PF.Deviation({ trip(1, 2, 100, 120), trip(1, 2, 100, 150), { mode = "flight", estimate = 100, seconds = 50 } }, "B")
    T.eq(d.trips, 2) T.eq(d.medianRatio, 1.35)
  end)

  T.it("route choice stays yours: no waypoint or movement", function()
    local fh = assert(io.open("addon/Outrider/Intelligence/Pathfinder.lua"))
    local code = fh:read("*a"):gsub("%-%-[^\n]*", "")
    fh:close()
    T.ok(not code:find("Waypoints:Set") and not code:find("MoveForward") and not code:find("Interact"))
  end)
end)

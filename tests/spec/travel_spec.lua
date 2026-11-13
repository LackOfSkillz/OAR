-- Travel router and Journey guide. Maps, positions and rides are test data.
local T, mock = ...

-- Two continents: 100 and 200 on continent 1 (side by side), 300 on continent 2.
local function session(opts)
  opts = opts or {}
  opts.mapID, opts.x, opts.y = opts.mapID or 100, opts.x or 0.1, opts.y or 0.5
  local game = mock.new(opts)
  game.maps = { [1] = { name = "World" }, [10] = { name = "East", parent = 1 }, [20] = { name = "Isle", parent = 1 },
    [100] = { name = "Westfield", parent = 10 }, [200] = { name = "Eastvale", parent = 10 }, [300] = { name = "Far Isle", parent = 20 },
    [12] = { name = "Top" } }
  game.maps[10].parent, game.maps[20].parent = 1, 1
  game.mapWorld = { [100] = { 1, 0, 0 }, [200] = { 1, 1000, 0 }, [300] = { 2, 0, 0 } }
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game:advance(2)
  return game, ns, opts
end

T.describe("travel", function()
  T.it("finds zones by name from the client's map tree", function()
    local _, ns = session()
    T.eq(ns.Travel:MapByName("eastvale"), 200)
    T.eq(ns.Travel:MapByName("Far Isle"), 300)
  end)

  T.it("walks on one continent; uses a known flight when quicker", function()
    local _, ns = session()
    local target = ns.Travel.Point(200, 0.9, 0.5, "Camp")
    local r = ns.Travel:Route(target)
    T.eq(#r.steps, 1)
    T.eq(r.steps[1].kind, "walk")
    T.ok(math.abs(r.seconds - 1800 / 7) < 1, "1800 yards on foot")
    -- two flight points this character knows, near start and near target
    ns.db.global.taxiNodes = { [1] = { name = "West FP", mapID = 100, x = 0.12, y = 0.5, cont = 1, wx = 120, wy = 500 },
      [2] = { name = "East FP", mapID = 200, x = 0.88, y = 0.5, cont = 1, wx = 1880, wy = 500 } }
    ns.db.char.taxiKnown = { [1] = true, [2] = true }
    r = ns.Travel:Route(target)
    T.eq(r.steps[2].kind, "fly")
    T.eq(r.steps[2].text, "Fly to East FP")
    T.ok(r.seconds < 1800 / 7)
  end)

  T.it("another continent: no way until a ride is known, then walk, ride, walk", function()
    local _, ns = session()
    local target = ns.Travel.Point(300, 0.5, 0.5, "Hermit")
    local r, why = ns.Travel:Route(target)
    T.eq(r, nil)
    T.contains(why, "no known way to Far Isle")
    ns.db.global.travelLinks = { { kind = "learned", from = { mapID = 200, x = 0.5, y = 0.9 }, to = { mapID = 300, x = 0.1, y = 0.1 }, oneWay = true } }
    r = ns.Travel:Route(target)
    T.eq(#r.steps, 3)
    T.eq(r.steps[1].kind, "walk")
    T.eq(r.steps[2].kind, "learned")
    T.contains(r.steps[2].text, "Eastvale to Far Isle")
    T.contains(r.steps[3].text, "Hermit, Far Isle")
  end)

  T.it("learns a ride from a loading screen that wasn't a flight or teleport", function()
    local game, ns, opts = session()
    game:fire("LOADING_SCREEN_ENABLED")
    opts.mapID, opts.x, opts.y = 300, 0.2, 0.3
    game:fire("PLAYER_ENTERING_WORLD", false, false)
    local l = ns.db.global.travelLinks[1]
    T.ok(l, "ride learned")
    T.eq(l.from.mapID, 100)
    T.eq(l.to.mapID, 300)
    -- a hearthstone is not a ride
    game.spells = { { name = "Hearthstone", id = 8690 } }
    game:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 8690)
    game:fire("LOADING_SCREEN_ENABLED")
    opts.mapID = 100
    game:fire("PLAYER_ENTERING_WORLD", false, false)
    T.eq(#ns.db.global.travelLinks, 1)
  end)

  T.it("guide sets the arrow for the first leg and moves on after arriving", function()
    local game, ns, opts = session()
    ns.db.global.travelLinks = { { kind = "learned", from = { mapID = 200, x = 0.5, y = 0.9 }, to = { mapID = 300, x = 0.1, y = 0.1 }, oneWay = true } }
    ns.Journey:Go({ name = "Bow", target = ns.Travel.Point(300, 0.5, 0.5, "Hermit"), seconds = 600 })
    local w = ns.Waypoints.current
    T.eq(w.mapID, 200)
    T.ok(math.abs(w.y - 0.9) < 0.001, "arrow at the dock")
    local told
    for _, l in ipairs(game.chat) do if l:find("then: Take the ride you took before", 1, true) then told = true end end
    T.ok(told, "next step said once")
    -- the ride happens: now on the far isle
    opts.mapID, opts.x, opts.y = 300, 0.1, 0.1
    game:fire("PLAYER_ENTERING_WORLD", false, false)
    game:advance(3)
    T.eq(ns.Waypoints.current.mapID, 300, "arrow moved to the target")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("XP estimate grows with level and is cut for low quests", function()
    local _, ns = session()
    T.ok(ns.Journey.XP(13, 13) > ns.Journey.XP(10, 13))
    T.eq(ns.Journey.XP(3, 13), math.floor(ns.Journey.XP(3, 3) * 0.1 / 10 + 0.5) * 10)
  end)
end)

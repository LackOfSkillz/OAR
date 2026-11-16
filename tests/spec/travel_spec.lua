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

  T.it("a guide boat without dock coordinates leaves from the town's flight master", function()
    local _, ns = session()
    ns.db.global.pois = {
      ["taxi-1"] = { id = "taxi-1", kind = "flight_master", source = "client", name = "Harborton, Eastvale", mapID = 200, x = 0.8, y = 0.2 },
      ["taxi-2"] = { id = "taxi-2", kind = "flight_master", source = "client", name = "Isleport, Far Isle", mapID = 300, x = 0.3, y = 0.7 },
    }
    ns.Data:Register("link", "spec", { { id = "boat-spec", kind = "boat", source = "spec", verified = false,
      from = { zone = "Eastvale", place = "Harborton" }, to = { zone = "Far Isle", place = "Isleport" } } })
    local r = ns.Travel:Route(ns.Travel.Point(300, 0.5, 0.5, "Hermit"))
    T.ok(r, "a route")
    T.eq(r.steps[1].kind, "walk")
    T.eq(r.steps[1].to.mapID, 200)
    T.ok(math.abs(r.steps[1].to.x - 0.8) < 1e-9 and math.abs(r.steps[1].to.y - 0.2) < 1e-9, "walk to the flight master, not the zone middle")
    T.contains(r.steps[1].text, "the dock is by the flight master")
    T.eq(r.steps[2].kind, "boat")
    T.contains(r.steps[3].text, "Hermit, Far Isle")
    -- no flight master known: the zone middle, marked approximate
    ns.db.global.pois = {}
    r = ns.Travel:Route(ns.Travel.Point(300, 0.5, 0.5, "Hermit"))
    T.contains(r.steps[1].text, "dock spot not known yet")
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

  T.it("at the dock the guide says the ride once and stops re-setting the arrow", function()
    local game, ns, opts = session()
    ns.db.global.travelLinks = { { kind = "learned", from = { mapID = 200, x = 0.5, y = 0.9 }, to = { mapID = 300, x = 0.1, y = 0.1 }, oneWay = true } }
    ns.Journey:Go({ name = "Bow", target = ns.Travel.Point(300, 0.5, 0.5, "Hermit"), seconds = 600 })
    -- Gary walks to the dock: the arrow arrives
    opts.mapID, opts.x, opts.y = 200, 0.5, 0.9
    local sets = 0
    ns.Events:On("OTR_WAYPOINT_SET", "spec", function() sets = sets + 1 end)
    game:advance(10)
    T.ok(sets <= 1, "no set/arrive loop (" .. sets .. " sets)")
    T.eq(ns.Waypoints.current, nil)
    local told = 0
    for _, l in ipairs(game.chat) do if l:find("Now: Take the ride you took before", 1, true) then told = told + 1 end end
    T.eq(told, 1)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a journey carries on after a reload", function()
    local game, ns = session()
    ns.db.global.travelLinks = { { kind = "learned", from = { mapID = 200, x = 0.5, y = 0.9 }, to = { mapID = 300, x = 0.1, y = 0.1 }, oneWay = true } }
    ns.Journey:Go({ name = "Bow", target = ns.Travel.Point(300, 0.5, 0.5, "Hermit"), seconds = 600 })
    -- the reload: the module starts over with only what was saved
    ns.Journey.goal = nil
    ns.Waypoints:Clear("reload", true)
    ns.Modules:SetEnabled("Journey", false)
    ns.Modules:SetEnabled("Journey", true)
    game:advance(3)
    T.ok(ns.Journey.goal, "goal back")
    T.eq(ns.Journey.goal.name, "Bow")
    T.eq(ns.Waypoints.current.mapID, 200, "arrow at the dock again")
    ns.Journey:Stop("done")
    T.eq(ns.Journey:Settings().goal, nil)
  end)

  T.it("a journey to a rare ends when it is tamed", function()
    local _, ns = session()
    ns.Journey:Go({ name = "Spec Cat", npcID = 83002, target = ns.Travel.Point(200, 0.9, 0.5, "Spec Cat"), seconds = 300 })
    T.ok(ns.Journey.goal)
    ns.Events:Fire("OTR_SIGHTING_ADDED", 99999, { state = "tamed" })
    T.ok(ns.Journey.goal, "another creature changes nothing")
    ns.Events:Fire("OTR_SIGHTING_ADDED", 83002, { state = "tamed" })
    T.eq(ns.Journey.goal, nil)
    T.eq(ns.Journey:Settings().goal, nil, "not resumed after a reload")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("an old saved journey to a rare already tamed is dropped at login", function()
    local game, ns = session()
    ns.Data:Register("rare", "spec", { { npcID = 83003, name = "Old Cat", mapID = 200, verified = false } })
    ns.Journey:Settings().goal = { name = "Old Cat", target = { mapID = 200, x = 0.9, y = 0.5 } }   -- no npcID, no t
    ns.Sightings:Record(83003, { state = "tamed", t = game.env.time(), mapID = 200 })
    ns.Modules:SetEnabled("Journey", false)
    ns.Modules:SetEnabled("Journey", true)
    game:advance(3)
    T.eq(ns.Journey.goal, nil)
    T.eq(ns.Journey:Settings().goal, nil)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("XP estimate grows with level and is cut for low quests", function()
    local _, ns = session()
    T.ok(ns.Journey.XP(13, 13) > ns.Journey.XP(10, 13))
    T.eq(ns.Journey.XP(3, 13), math.floor(ns.Journey.XP(3, 3) * 0.1 / 10 + 0.5) * 10)
  end)

  T.it("the map marker's tooltip says what it leads to, the step, distance and what's next", function()
    local game, ns = session()
    ns.db.global.travelLinks = { { kind = "learned", from = { mapID = 200, x = 0.5, y = 0.9 }, to = { mapID = 300, x = 0.1, y = 0.1 }, oneWay = true } }
    ns.Journey:Go({ name = "The Strange Hermit", sub = "quest from Strange Hermit", target = ns.Travel.Point(300, 0.5, 0.5, "Hermit"), seconds = 600 })
    local text = {}
    for _, l in ipairs(ns.Journey:PinLines()) do text[#text + 1] = l[1] end
    local all = table.concat(text, " | ")
    T.contains(all, "Outrider: The Strange Hermit")
    T.contains(all, "quest from Strange Hermit")
    T.contains(all, "yards away")
    T.contains(all, "Now: Go to")
    T.contains(all, "Then: Take the ride you took before")
  end)
end)

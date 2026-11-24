-- The way there (Gary, 2026-11-21): dots from you to the destination that
-- follow ground walked before. Only verified ground is drawn (2026-11-23):
-- no straight guesses, and no dots unless walked ground reaches the
-- destination. Test maps: 1 map unit = 1000 yards (wowmock).
local T, mock = ...

local function session()
  local game = mock.new({ mapID = 100, x = 0.1, y = 0.5 })
  game.maps = { [1] = { name = "World" }, [10] = { name = "East", parent = 1 },
    [100] = { name = "Westfield", parent = 10 }, [200] = { name = "Eastvale", parent = 10 } }
  game.mapWorld = { [100] = { 1, 0, 0 }, [200] = { 1, 1000, 0 } }
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game:advance(2)
  return game, ns, ns.Path
end

-- a walked path from (0.1, 0.5) up to (0.1, 0.44), across to (0.3, 0.44), down to (0.3, 0.5): around a wall
-- (320 yards walked against 200 straight: a detour under OFF times the straight line wins)
-- a straight walked line along y = 0.5 on one map
local function road(ns, mapID, x1, x2)
  local dots = {}
  for i = 0, math.floor((x2 - x1) / 0.01 + 0.5) do dots[#dots + 1] = { x = x1 + i * 0.01, y = 0.5, t = 1 } end
  ns.db.global.trails[mapID] = dots
end

local function walkAround(ns)
  local dots = {}
  for i = 0, 6 do dots[#dots + 1] = { x = 0.1, y = 0.5 - i * 0.01, t = 1 } end
  for i = 1, 20 do dots[#dots + 1] = { x = 0.1 + i * 0.01, y = 0.44, t = 1 } end
  for i = 1, 6 do dots[#dots + 1] = { x = 0.3, y = 0.44 + i * 0.01, t = 1 } end
  ns.db.global.trails[100] = dots
end

T.describe("the way there", function()
  T.it("no destination, no dots; nobody walked there: no dots either, and it says so", function()
    local game, ns, P = session()
    T.eq(#P:Pins(100), 0)
    ns.Waypoints:Set(100, 0.3, 0.5, "Tower")
    T.eq(#P:Pins(100), 0, "a straight guess is never drawn")
    T.contains(P:Activity(), "nobody has walked there yet")
    road(ns, 100, 0.1, 0.3)
    P:Replan("walked")
    local pins = P:Pins(100)
    T.ok(#pins > 5, "a line of dots on the walked road")
    for _, p in ipairs(pins) do T.eq(p.walked, true) end
    ns.Waypoints:Clear("done")
    T.eq(#P:Pins(100), 0, "cleared with the waypoint")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("follows the path you walked around a wall instead of the straight line", function()
    local game, ns, P = session()
    walkAround(ns)
    ns.Waypoints:Set(100, 0.3, 0.5, "Tower")
    local walked, highest = 0, 1
    for _, p in ipairs(P:Pins(100)) do
      if p.walked then walked = walked + 1 end
      if p.y < highest then highest = p.y end
    end
    T.ok(walked > 12, "most dots on the walked path")
    T.ok(highest < 0.45, "it goes up and around")
    T.ok(P.walked > 250, "about 320 yards walked")
  end)

  T.it("walked ground that stops far from the destination draws nothing (it may lead to the wrong side of a cliff)", function()
    local game, ns, P = session()
    road(ns, 100, 0.1, 0.3)
    ns.Waypoints:Set(100, 0.3, 0.6, "Up the hill")
    T.eq(#P:Pins(100), 0, "100 yards unwalked at the end")
    T.ok(not P.verified)
  end)

  T.it("a short straight hop beats a long detour", function()
    local game, ns, P = session()
    walkAround(ns)
    ns.Waypoints:Set(100, 0.12, 0.5, "Next door")
    for _, p in ipairs(P:Pins(100)) do T.ok(p.y > 0.47, "no trip around the loop for 20 yards") end
  end)

  T.it("dots show on the neighbouring map too, and on the minimap", function()
    local game, ns, P = session()
    game.opts.x = 0.9
    road(ns, 100, 0.9, 1.0)
    local d2 = {}
    for i = 0, 10 do d2[#d2 + 1] = { x = i * 0.01, y = 0.5, t = 1 } end
    ns.db.global.trails[200] = d2
    ns.Waypoints:Set(200, 0.1, 0.5, "Over the border")
    local here, there = P:Pins(100), P:Pins(200)
    T.ok(#here > 0 and #there > 0, "split over both maps")
    ns.MinimapPins:Update()
    local path = 0
    for _, d in ipairs(ns.MinimapPins.used) do if d.pin and d.pin.kind == "path" then path = path + 1 end end
    T.ok(path > 0, "on the minimap")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("re-plans as you walk, and can be switched off", function()
    local game, ns, P = session()
    road(ns, 100, 0.1, 0.5)
    ns.Waypoints:Set(100, 0.5, 0.5, "Far")
    local before = #P:Pins(100)
    game.opts.x = 0.3
    P:Tick()
    T.ok(#P:Pins(100) < before, "the part behind you is gone")
    P:Settings().on = false
    P:Replan("off")
    T.eq(#P:Pins(100), 0)
  end)

  T.it("follows a creature's patrol route (walked routes pack) where you never walked", function()
    local game, ns, P = session()
    -- a route that goes up and around, like a trail round a ridge
    local line = {}
    for i = 0, 6 do line[#line + 1] = 0.1 line[#line + 1] = 0.5 - i * 0.01 end
    for i = 1, 20 do line[#line + 1] = 0.1 + i * 0.01 line[#line + 1] = 0.44 end
    for i = 1, 6 do line[#line + 1] = 0.3 line[#line + 1] = 0.44 + i * 0.01 end
    rawset(game.env, "Outrider_DataPaths", { source = "spec", maps = { [100] = { line } } })
    P.routes = nil
    ns.Waypoints:Set(100, 0.3, 0.5, "Cave")
    local walked = 0
    for _, p in ipairs(P:Pins(100)) do if p.walked then walked = walked + 1 end end
    T.ok(walked > 10, "dots along the patrol route")
  end)

  T.it("uses the walked paths shipped with Outrider, without drawing them as yours", function()
    local game, ns, P = session()
    local flat = {}
    for i = 0, 6 do flat[#flat + 1] = 0.1 flat[#flat + 1] = 0.5 - i * 0.01 end
    for i = 1, 20 do flat[#flat + 1] = 0.1 + i * 0.01 flat[#flat + 1] = 0.44 end
    for i = 1, 6 do flat[#flat + 1] = 0.3 flat[#flat + 1] = 0.44 + i * 0.01 end
    rawset(game.env, "Outrider_DataTrails", { source = "spec", maps = { [100] = flat } })
    P.shipped = nil
    ns.Waypoints:Set(100, 0.3, 0.5, "Cave")
    local walked = 0
    for _, p in ipairs(P:Pins(100)) do if p.walked then walked = walked + 1 end end
    T.ok(walked > 10, "dots along the shipped path")
    for _, pin in ipairs(ns.Trail:Pins(100, {})) do T.ok(pin.kind ~= "trail", "not shown as your own trail") end
  end)

  T.it("any quest the game tracks gets dots: its own next waypoint first, else the quest data", function()
    local game, ns, P = session()
    road(ns, 100, 0.1, 0.25)
    game.trackedQuest = 77
    game.env.C_QuestLog.GetNextWaypoint = function(id) if id == 77 then return 100, 0.25, 0.5 end end
    game.env.C_QuestLog.GetNextWaypointText = function() return "Enter the cave" end
    P:Replan("quest arrow")
    local pins = P:Pins(100)
    T.ok(#pins > 0)
    T.contains(pins[1].name, "Enter the cave")
    game.env.C_QuestLog.GetNextWaypoint = nil
    ns.QuestObjectives.Nearest = function() return { mapID = 100, x = 0.2, y = 0.5, label = "Wolf Den" } end
    P:Replan("quest arrow")
    T.contains(P:Pins(100)[1].name, "Wolf Den")
  end)

  T.it("a quest the game's arrow guides gets the dots too", function()
    local game, ns, P = session()
    road(ns, 100, 0.1, 0.2)
    local Q = ns.QuestObjectives
    Q.guideQuest = 42
    Q.Nearest = function() return { mapID = 100, x = 0.2, y = 0.5, label = "Necklace" } end
    P:Replan("quest arrow")
    T.ok(#P:Pins(100) > 0)
    T.contains(P:Pins(100)[1].name, "Necklace")
  end)

  T.it("walking re-uses the search: no new graph per step, the same dots", function()
    local game, ns, P = session()
    road(ns, 100, 0.1, 0.3)
    ns.Waypoints:Set(100, 0.3, 0.5, "Tower")
    local g = P.graph
    T.ok(g and g.done, "searched once for the destination")
    local n0 = #P:Pins(100)
    game.opts.x = 0.15
    P:Replan("moving")
    T.ok(P.graph == g, "same search while moving")
    T.ok(#P:Pins(100) > 0 and #P:Pins(100) <= n0, "dots from the new spot")
    P:Replan("map pin")
    T.ok(P.graph ~= g or P.graph.sig == g.sig, "a non-moving reason with unchanged trails may keep it")
  end)

  T.it("a big network is searched in slices across frames, with the same answer", function()
    local _, ns, P = session()
    local nodes = {}
    for i = 1, 3000 do nodes[i] = { wx = (i % 60) * 20, wy = math.floor(i / 60) * 20, mapID = 100 } end
    local a, b = { wx = 0, wy = 0 }, { wx = 1180, wy = 980 }
    local whole = ns.Path.RouteFrom((function() local g = ns.Path.Graph(b, nodes) ns.Path.Step(g) return g end)(), a)
    local t = 0
    local g = ns.Path.Graph(b, nodes, 4)
    local env = getfenv and getfenv(ns.Path.Step) or _G
    local old = env.debugprofilestop
    env.debugprofilestop = function() t = t + 1 return t end -- every call costs 1 ms
    local slices = 0
    while not ns.Path.Step(g) do slices = slices + 1 end
    env.debugprofilestop = old
    T.ok(slices > 1, "it paused and resumed (" .. slices .. " slices)")
    local sliced = ns.Path.RouteFrom(g, a)
    T.eq(#sliced, #whole)
    for k = 1, #whole do T.eq(sliced[k].wx, whole[k].wx) T.eq(sliced[k].wy, whole[k].wy) end
  end)
end)


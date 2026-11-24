-- The map inside Outrider, routes you draw, the world map panel (2026-11-24).
local T, mock = ...

local function session(opts)
  local game = mock.new(opts or { mapID = 1413, x = 0.5, y = 0.5 })
  game.maps = {
    [1414] = { name = "Kalimdor", mapType = 2, parent = 947 },
    [1413] = { name = "The Barrens", mapType = 3, parent = 1414, rect = { 0.5, 0.6, 0.4, 0.6 } },
    [279] = { name = "Wailing Caverns", mapType = 4, parent = 1413 },
  }
  game.base.Outrider_DataDungeons = { source = "test", dungeons = {
    [43] = { name = "Wailing Caverns", map = 1413, x = .46, y = .36, bosses = {}, items = {} } } }
  rawset(game.env, "Outrider_DataDungeons", game.base.Outrider_DataDungeons)
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("map panel view math", function()
  T.it("fits the map, zooms around the cursor and keeps the map in view", function()
    local game, ns = session()
    local MV = ns.UI.MapViewLib
    local st = MV.Clamp({ vw = 500, vh = 300, lw = 1000, lh = 600, zoom = 1 })
    local W, H = MV.Size(st)
    T.eq(W, 500) T.eq(H, 300)
    local x, y = MV.FromView(st, 250, 150)
    T.ok(math.abs(x - 0.5) < 1e-9 and math.abs(y - 0.5) < 1e-9)
    -- zoom at a point: that map point stays under the cursor
    local mx, my = MV.FromView(st, 100, 60)
    MV.ZoomAt(st, 2, 100, 60)
    local nx, ny = MV.FromView(st, 100, 60)
    T.ok(math.abs(nx - mx) < 1e-9 and math.abs(ny - my) < 1e-9, "point stays put")
    -- can't pan past the edge
    MV.Pan(st, 5000, 5000)
    local ox, oy = MV.Origin(st)
    T.eq(ox, 0) T.eq(oy, 0)
    st.zoom = 99 MV.Clamp(st)
    T.eq(st.zoom, MV.MAX_ZOOM)
    -- the map art: 12 base tiles, then the zone's explorable areas on top
    local art = MV.Art(1413)
    T.eq(art.lw, 1002)
    T.ok(#art.tiles > 12)
    T.ok(not art.tiles[12].overlay and art.tiles[13].overlay)
    game.mapArt = { [5] = false }
    T.eq(MV.Art(5), nil)
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("routes", function()
  T.it("draws lines and markers, undoes, erases, and keeps limits", function()
    local _, ns = session()
    local R = ns.Routes
    local r = R:New(279)
    T.eq(r.name, "Wailing Caverns by Torrant")
    -- close points are dropped, the last point is kept
    local line = R:AddLine(r.id, 3, { 0.1, 0.1, 0.1005, 0.1, 0.2, 0.2, 0.2001, 0.2 })
    T.eq(#line.p, 4, "the near-duplicates and the repeated end point dropped")
    T.eq(line.p[1], 100) T.eq(line.p[3], 200)
    T.eq(select(2, R:AddLine(r.id, 1, { 0.1, 0.1 })), "too short")
    local mark = R:AddMark(r.id, 0.5, 0.5, 8, nil, 2)
    T.eq(mark.k, 8)
    T.eq(select(2, R:AddMark(r.id, 0.5, 0.5, 0, "  ")), "empty label")
    R:AddMark(r.id, 0.7, 0.7, 0, "Pull here|cff", 1)
    T.eq(r.marks[2].t, "Pull herecff", "no escape codes in labels")
    T.ok(R:Undo(r.id))
    T.eq(#r.marks, 1, "undo takes the newest")
    T.ok(R:EraseNear(r.id, 0.15, 0.152, 0.01), "erases the line near the click")
    T.eq(#r.lines, 0)
    T.ok(not R:EraseNear(r.id, 0.9, 0.9, 0.01))
    T.eq(#R:For(279), 1)
    R:SetShown(r.id, false)
    T.eq(#R:For(279), 0)
    T.ok(R:Delete(r.id))
    T.eq(R:Get(r.id), nil)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("copies to text and back, and refuses bad text", function()
    local _, ns = session()
    local R = ns.Routes
    local r = R:New(1413, "Crossroads loop")
    R:AddLine(r.id, 2, { 0.1, 0.1, 0.3, 0.3, 0.5, 0.1 })
    R:AddMark(r.id, 0.3, 0.3, 1, "Inn", 5)
    local text = R:Export(r.id)
    T.ok(text:find("^OTRROUTE:"))
    local copy = R:Import("  " .. text .. "\n")
    T.ok(copy and copy.id ~= r.id)
    T.eq(copy.name, "Crossroads loop")
    T.eq(#copy.lines[1].p, 6)
    T.eq(copy.marks[1].t, "Inn")
    T.ok(copy.shown, "your own paste shows")
    T.eq(select(2, R:Import("hello")), "not an Outrider route")
    T.eq(select(2, R:Import("OTRROUTE:@@@")), "damaged text")
    -- hostile data is cleaned
    local bad = R.Unpack({ m = 1413, n = string.rep("x", 500), l = { { 99, { -5, 2000, 10, 10, 50, 50 } } }, k = { { 5, 5, 3, "|Hlink|h" } } })
    T.eq(#bad.name, R.MAX_NAME)
    T.eq(bad.lines[1].c, #R.COLORS)
    T.eq(#bad.lines[1].p, 4, "off-map points dropped")
    T.eq(R.Unpack({ m = "x" }), nil)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("shares on a button press and takes routes from friends switched off", function()
    local game, ns = session({ mapID = 1413, x = 0.5, y = 0.5, inGuild = true })
    local R = ns.Routes
    local r = R:New(1413, "Guild run")
    R:AddLine(r.id, 2, { 0.1, 0.1, 0.3, 0.3 })
    game.sent = {}
    T.ok(R:Share(r.id, "GUILD"))
    T.ok(#game.sent >= 1 and game.sent[1].channel == "GUILD")
    T.ok(not R:Share(r.id, "SAY"), "only allowed channels")
    -- a friend's route arrives
    ns.Events:Fire("OTR_COMM", "ROUTE", R.Pack(r), "Friend-Forever", "GUILD")
    local got
    for _, x in ipairs(R:List(1413)) do if x.from == "Friend-Forever" then got = x end end
    T.ok(got, "kept")
    T.ok(not got.shown, "switched off until you turn it on")
    ns.Events:Fire("OTR_COMM", "ROUTE", R.Pack(r), "Friend-Forever", "GUILD")
    local n = 0
    for _, x in ipairs(R:List(1413)) do if x.from then n = n + 1 end end
    T.eq(n, 1, "the same route again replaces the copy")
    R:Settings().receive = false
    ns.Events:Fire("OTR_COMM", "ROUTE", R.Pack(r), "Other-Forever", "GUILD")
    n = 0
    for _, x in ipairs(R:List(1413)) do if x.from then n = n + 1 end end
    T.eq(n, 1, "receiving can be turned off")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("puts dots along shown routes on the minimap and lines on the world map", function()
    local game, ns = session()
    local R = ns.Routes
    local r = R:New(1413, "Road")
    R:AddLine(r.id, 4, { 0.40, 0.50, 0.60, 0.50 })
    R:AddMark(r.id, 0.6, 0.5, 1, nil, 4)
    local pins = R:Pins(1413)
    local dots, marks = 0, 0
    for _, p in ipairs(pins) do if p.kind == "route" then dots = dots + 1 else marks = marks + 1 end end
    T.eq(dots, 9, "one every 2.5% along 20%")
    T.eq(marks, 1)
    ns.Modules:Get("MinimapPins"):Update()
    local shown = 0
    for _, d in ipairs(ns.Modules:Get("MinimapPins").used) do if d.pin and d.pin.kind == "route" then shown = shown + 1 end end
    T.ok(shown > 0, "dots on the minimap")
    game.mapShownID = 1413
    game.env.WorldMapFrame:Show()
    ns.Routes:RefreshWorld()
    T.ok(R.layer and R.layer:IsShown(), "drawn on the world map")
    T.eq(#R.layer.rUsedL, 1)
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("map pages", function()
  T.it("the routes page shows your map and draws a line with the mouse", function()
    local game, ns = session()
    ns.Hub:Build():Show()
    ns.Hub:ShowTab("worldmap")
    local p = ns.Hub.byId.worldmap.panel
    local v = p.view
    T.eq(v.mapID, 1413, "the map you're on")
    T.ok(#v.tileUsed > 0, "map art drawn")
    -- new route, draw mode, drag
    local r = ns.Routes:New(1413)
    v:SetRoute(r.id)
    v:SetMode("line")
    local host = v.host
    game.cursorX, game.cursorY = 110, 690
    host:GetScript("OnMouseDown")(host, "LeftButton")
    game.cursorX, game.cursorY = 150, 650
    host:GetScript("OnUpdate")(host, 0.05)
    game.cursorX, game.cursorY = 200, 620
    host:GetScript("OnUpdate")(host, 0.05)
    host:GetScript("OnMouseUp")(host, "LeftButton")
    T.eq(#r.lines, 1, "the stroke became a line")
    T.ok(#r.lines[1].p >= 4)
    -- a marker click
    v:SetMode("mark")
    game.cursorX, game.cursorY = 140, 660
    host:GetScript("OnMouseDown")(host, "LeftButton")
    host:GetScript("OnMouseUp")(host, "LeftButton")
    T.eq(#r.marks, 1)
    -- move mode: a click on a zone opens it; right-click goes up
    v:SetMap(1414)
    v:SetMode("move")
    v.route = nil
    local W, H = ns.UI.MapViewLib.Size(v.st)
    local ox, oy = ns.UI.MapViewLib.Origin(v.st)
    game.cursorX, game.cursorY = 100 + ox + 0.55 * W, 700 - (oy + 0.5 * H)
    host:GetScript("OnMouseDown")(host, "LeftButton")
    host:GetScript("OnMouseUp")(host, "LeftButton")
    T.eq(v.mapID, 1413, "clicked into the zone")
    host:GetScript("OnMouseDown")(host, "RightButton")
    host:GetScript("OnMouseUp")(host, "RightButton")
    T.eq(v.mapID, 1414, "right-click: up one map")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("dungeon maps find the dungeon's own map and floors", function()
    local game, ns = session()
    T.eq(ns.MapPages.DungeonMap("Wailing Caverns", 1413), 279)
    T.eq(ns.MapPages.DungeonMap("Nowhere Keep", 1413), nil)
    ns.Hub:Build():Show()
    ns.Hub:ShowTab("dungeonmap")
    local p = ns.Hub.byId.dungeonmap.panel
    T.eq(p.view.mapID, 279)
    game.maps[279].group, game.maps[279].floor = 7, 0
    game.maps[280] = { name = "Lower caves", mapType = 4, parent = 1413, group = 7, floor = 1 }
    p.view.mapID = nil
    p.view:SetMap(279)
    T.ok(p.floorBtn:IsShown())
    p.floorBtn:Click()
    T.eq(p.view.mapID, 280, "next floor")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("the panel beside the world map follows the map and toggles routes", function()
    local game, ns = session()
    local r = ns.Routes:New(1413, "Barrens loop")
    ns.Routes:SetShown(r.id, false)
    local D = ns.MapDock
    local rows = D:Rows(1413)
    local text = {}
    for _, row in ipairs(rows) do text[#text + 1] = row.text end
    local all = table.concat(text, "\n")
    T.contains(all, "The Barrens")
    T.contains(all, "Wailing Caverns")
    T.contains(all, "Barrens loop")
    for _, row in ipairs(rows) do if row.kind == "route" then row.go() end end
    T.ok(ns.Routes:Get(r.id).shown, "clicked on")
    game.mapShownID = 1413
    game.env.WorldMapFrame:Show()
    D:Refresh()
    T.ok(D.frame and D.frame:IsShown(), "shows with the world map")
    game.env.WorldMapFrame:Hide()
    T.ok(not D.frame:IsShown(), "hides with it")
    T.eq(#ns.Errors.list, 0)
  end)
end)

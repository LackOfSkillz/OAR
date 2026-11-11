-- World map pins and pin cards (P3-03, P3-05). Positions are test data.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game.units = {}
  return game, ns
end

local function addPlaces(ns)
  ns.db.global.pois["npc-1-vendor"] = { id = "npc-1-vendor", kind = "vendor", mapID = 1412, x = 0.4, y = 0.5, name = "Smith", n = 2, faction = "Horde", verified = false }
  ns.db.global.pois["npc-2-flight_master"] = { id = "npc-2-flight_master", kind = "flight_master", mapID = 1412, x = 0.6, y = 0.2, name = "Flyer", faction = "Alliance", verified = false }
  ns.db.global.pois["npc-3-bank"] = { id = "npc-3-bank", kind = "bank", mapID = 9999, x = 0.1, y = 0.1, name = "Banker", verified = false }
end

T.describe("map pins", function()
  T.it("pins for the shown map only, same faction, plus rares from sightings", function()
    local game, ns = session()
    addPlaces(ns)
    ns.Events:Fire("OTR_RARE_SEEN", { npcID = 7301, name = "Map Rare", how = "target", mapID = 1412, x = 0.3, y = 0.3, layer = 1 })
    local pins = ns.MapPins:PinsFor(1412)
    T.eq(#pins, 2)
    T.eq(pins[1].name, "Smith")
    T.eq(pins[2].kind, "rare")
  end)

  T.it("opening the map draws them on the canvas at x*width, y*height", function()
    local game, ns = session()
    addPlaces(ns)
    game.mapShownID = 1412
    game.env.WorldMapFrame:Show()
    T.eq(ns.MapPins.shown, 1)
    local pin = ns.MapPins.used[1]
    local _, _, _, x, y = pin:GetPoint(1)
    T.eq(x, 400)
    T.eq(y, -350)
  end)

  T.it("hiding a kind removes its pins", function()
    local game, ns = session()
    addPlaces(ns)
    ns.MapPins:Settings().hidden.vendor = true
    T.eq(#ns.MapPins:PinsFor(1412), 0)
  end)

  T.it("clicking a pin opens a card; its Waypoint button sets a waypoint", function()
    local game, ns = session()
    addPlaces(ns)
    game.mapShownID = 1412
    game.env.WorldMapFrame:Show()
    local pin = ns.MapPins.used[1]
    pin.__scripts.OnClick(pin)
    local card = ns.MapPins.card
    T.ok(card:IsShown())
    T.eq(card.title:GetText(), "Smith")
    T.contains(card.body:GetText(), "Visited 2 times")
    card.way.__scripts.OnClick(card.way)
    T.eq(ns.Waypoints.current.title, "Smith")
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("marker symbols and colours", function()
  T.it("picks a symbol by role and a colour by group", function()
    local game = mock.new()
    local ns = game:loadAddon()
    local MP = ns.MapPins
    local function icon(kind, title, goods) return MP.IconFor({ kind = kind, poi = { title = title, goods = goods } }) end
    T.contains(icon("trainer", "Hunter Trainer"), "Class")
    T.contains(icon("trainer", "Leatherworking Trainer"), "Profession")
    T.contains(icon("vendor", "Bowyer"), "Ammunition")
    T.contains(icon("vendor", "Trade Supplies", { "food & potions" }), "Food")
    T.contains(icon("innkeeper"), "Innkeeper")
    T.contains(icon("rare"), "Skull")
    T.eq(MP.Group("vendor"), "merchant")
    T.eq(MP.Group("trainer"), "trainer")
    T.eq(MP.Group("bank"), "service")
    T.eq(MP.Group("rare"), "rare")
  end)
end)

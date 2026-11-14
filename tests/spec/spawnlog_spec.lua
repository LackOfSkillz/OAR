-- Spawn log at a watched rare's spot: order, deaths, gaps. Test data.
local T, mock = ...

T.describe("spawn log", function()
  T.it("logs each spawn at the spot once, its death, and the gap to the next spawn", function()
    local game = mock.new({ mapID = 2521, x = 0.598, y = 0.341 })
    local ns = game:loadAddon()
    game:login()
    ns.Modules:Get("RareScan"):Watch("mystmane", true)
    ns.db.global.sightings = { [259388] = { { mapID = 2521, x = 0.598, y = 0.341, state = "alive", t = 1 } } }
    ns.db.global.discovered = { npcs = { [259388] = { name = "Mystmane", mapID = 2521 } }, recent = {} } -- no profile yet
    game.units = { nameplate1 = { name = "Shadowgale Ursera", guid = "Creature-0-1-2521-0-250927-00000000AA", level = 11 } }
    game:fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    game:fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local list = ns.db.global.spawnLogs[259388]
    T.eq(#list, 1, "one spawn, seen twice")
    game.units.nameplate1.dead = true
    game:fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    T.ok(list[1].died)
    game.now = game.now + 646
    game.units.nameplate1 = { name = "Shadowgale Ursera", guid = "Creature-0-1-2521-0-250927-00000000BB", level = 11 }
    game:fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    T.eq(#list, 2)
    T.contains(ns.SpawnLog:Summary(259388), "Shadowgale Ursera")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("nothing is logged away from a watched rare's spot", function()
    local game = mock.new({ mapID = 2521, x = 0.10, y = 0.10 })
    local ns = game:loadAddon()
    game:login()
    ns.Modules:Get("RareScan"):Watch("mystmane", true)
    ns.db.global.sightings = { [259388] = { { mapID = 2521, x = 0.598, y = 0.341, state = "alive", t = 1 } } }
    game.units = { nameplate1 = { name = "Wolf", guid = "Creature-0-1-2521-0-1-00000000CC", level = 5 } }
    game:fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    T.eq(ns.db.global.spawnLogs[259388], nil)
  end)
end)

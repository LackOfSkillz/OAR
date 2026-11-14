-- Catch log (P5-12) and gathering nodes (P5-13). Items are test data.
local T, mock = ...

local function session()
  local game = mock.new()
  game.spells[#game.spells + 1] = { name = "Herb Gathering", id = 2366 }
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  return game, ns
end

T.describe("loot log", function()
  T.it("logs fishing catches by zone and this session", function()
    local game, ns = session()
    game.fishingLoot = true
    game.loot = { { id = 6291, name = "Raw Brilliant Smallfish", count = 1 } }
    game:fire("LOOT_OPENED")
    game:fire("LOOT_OPENED")
    T.eq(ns.db.global.fishing[1412][6291], 2)
    T.contains(ns.Modules:Get("LootLog"):Activity(), "2 fish this session")
  end)

  T.it("a herb gathered becomes a node pin; the same spot again just counts up", function()
    local game, ns = session()
    game.loot = { { id = 2447, name = "Peacebloom", count = 2 } }
    game:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 2366)
    game:fire("LOOT_OPENED")
    game:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 2366)
    game:fire("LOOT_OPENED")
    T.eq(#ns.db.global.nodes, 1)
    T.eq(ns.db.global.nodes[1].count, 2)
    local found
    for _, p in ipairs(ns.MapPins:PinsFor(1412)) do if p.kind == "herb" then found = p end end
    T.ok(found)
    T.eq(found.name, "Peacebloom (x2)")
    T.eq(ns.MapPins.Group("herb"), "gather")
  end)

  T.it("ordinary loot is ignored", function()
    local game, ns = session()
    game.loot = { { id = 1, name = "Wolf Fang", count = 1 } }
    game:fire("LOOT_OPENED")
    T.eq(#ns.db.global.nodes, 0)
    T.eq(#ns.Errors.list, 0)
  end)
end)

-- Rare profiles: stats when seen, spells and their timing when cast. Test data.
local T, mock = ...

T.describe("rare profile", function()
  T.it("records stats when a rare is seen and its casts with the gap between them", function()
    local game = mock.new({ mapID = 2521 })
    game.spells = { { name = "Ravage", id = 5001 } }
    local ns = game:loadAddon()
    game:login()
    local guid = "Creature-0-1-2521-0-259388-0000000001"
    game.units = { target = { name = "Mystmane", guid = guid, level = 13, family = "Bear", hpMax = 812,
      classification = "rare", attackSpeed = 1.8 } }
    ns.Events:Fire("OTR_RARE_SEEN", { npcID = 259388, name = "Mystmane", unit = "target", level = 13, family = "Bear",
      classification = "rare" })
    local p = ns.db.global.rareProfiles[259388]
    T.eq(p.hpMax, 812)
    game:fire("UNIT_SPELLCAST_START", "target", "c1", 5001)
    game:fire("UNIT_SPELLCAST_SUCCEEDED", "target", "c1", 5001)
    game:advance(14)
    game:fire("UNIT_SPELLCAST_SUCCEEDED", "target", "c2", 5001)
    T.eq(p.spells.Ravage.n, 2, "a start and its success count once")
    T.contains(ns.RareProfile:Summary(259388), "Ravage x2 (about every 14s)")
    T.contains(ns.RareProfile:Summary(259388), "health 812")
    T.eq(#ns.Errors.list, 0)
  end)
end)

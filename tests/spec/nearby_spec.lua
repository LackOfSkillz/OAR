-- Nearby upgrades (P6-05/06). A tiny pack stands in for Outrider_Data_Gear.
local T, mock = ...

local function session()
  local game = mock.new({ mapID = 1412, x = 0.5, y = 0.5 })
  game.env.Outrider_DataGear = { source = "test", items = {
    [501] = { "Quest Cloak", 20, 22, { { "quest", 1412, 0.4, 0.4, "Help the Grimtotem", 22, "Horde" } } },
    [502] = { "Vendor Cloak", 22, 22, { { "vendor", 1412, 0.6, 0.6, "Varia Hardhide", nil, "Horde" } } },
    [503] = { "Alliance Cloak", 20, 22, { { "vendor", 1412, 0.6, 0.6, "Someone", nil, "Alliance" } } },
    [504] = { "Far Cloak", 20, 22, { { "vendor", 1411, 0.6, 0.6, "Elsewhere", nil, "Horde" } } },
    [505] = { "Level 40 Cloak", 40, 45, { { "drop", 1412, 0.2, 0.2, "Big Rare", nil, nil } } },
  } }
  game.items = {
    [400] = { name = "Old Cloak", equipLoc = "INVTYPE_CLOAK" },
    [501] = { name = "Quest Cloak", equipLoc = "INVTYPE_CLOAK" },
    [502] = { name = "Vendor Cloak", equipLoc = "INVTYPE_CLOAK" },
    [503] = { name = "Alliance Cloak", equipLoc = "INVTYPE_CLOAK" },
    [504] = { name = "Far Cloak", equipLoc = "INVTYPE_CLOAK" },
    [505] = { name = "Level 40 Cloak", equipLoc = "INVTYPE_CLOAK" },
  }
  game.itemStats = { [400] = { ITEM_MOD_AGILITY_SHORT = 2 }, [501] = { ITEM_MOD_AGILITY_SHORT = 6 },
    [502] = { ITEM_MOD_AGILITY_SHORT = 6 }, [503] = { ITEM_MOD_AGILITY_SHORT = 9 }, [504] = { ITEM_MOD_AGILITY_SHORT = 9 },
    [505] = { ITEM_MOD_AGILITY_SHORT = 20 } }
  game.worn = { [15] = 400 }
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.Nearby
end

T.describe("nearby", function()
  T.it("lists zone, faction and level appropriate upgrades; vendor before quest at equal gain", function()
    local _, _, N = session()
    local list = N:Candidates()
    T.eq(#list, 2)
    T.eq(list[1].name, "Vendor Cloak")
    T.eq(list[2].name, "Quest Cloak")
    T.contains(N.Describe(list[2]), "quest Help the Grimtotem (level 22)")
  end)

  T.it("one toast per item, never repeated; click sets a waypoint", function()
    local game, ns, N = session()
    N:Scan("test")
    T.eq(ns.Toast:Count(), 1)
    T.contains(ns.Toast.visible[1].title:GetText(), "Upgrade nearby")
    N:Scan("test")
    N:Scan("test")
    T.eq(ns.Toast:Count(), 2, "second item toasts once, then nothing new")
    N:Scan("test")
    T.eq(ns.Toast:Count(), 2)
    game:slash("nearby")
    T.contains(game:chatText(), "Vendor Cloak")
    T.eq(#ns.Errors.list, 0)
  end)
end)

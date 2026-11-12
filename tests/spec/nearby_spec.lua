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

T.describe("nearby quest availability", function()
  T.it("done or far-too-high quests drop out; not-yet quests come last with a note", function()
    local game = mock.new({ mapID = 1412, x = 0.5, y = 0.5, level = 4 })
    game.env.Outrider_DataGear = { source = "test", items = {
      [901] = { "Open Cloak", 3, 5, { { "quest", 1412, 0.4, 0.4, "Easy One", 4, nil, 901, 2, {}, {} } } },
      [902] = { "Later Cloak", 5, 13, { { "quest", 1412, 0.6, 0.6, "Catching Wind", 6, nil, 902, 5, { 99260 }, {} } } },
      [903] = { "Done Cloak", 3, 5, { { "quest", 1412, 0.3, 0.3, "Old Quest", 4, nil, 903, 1, {}, {} } } },
      [904] = { "Far Cloak", 3, 5, { { "quest", 1412, 0.2, 0.2, "Way Too Hard", 11, nil, 904, 5, {}, {} } } },
    } }
    game.items = { [400] = { name = "Old Cloak", equipLoc = "INVTYPE_CLOAK" } }
    game.itemStats = { [400] = { ITEM_MOD_AGILITY_SHORT = 2 } }
    for id = 901, 904 do
      game.items[id] = { name = "c" .. id, equipLoc = "INVTYPE_CLOAK" }
      game.itemStats[id] = { ITEM_MOD_AGILITY_SHORT = id == 902 and 9 or 4 }
    end
    game.worn = { [15] = 400 }
    game.questsDone = { [903] = true }
    local ns = game:loadAddon()
    game:login()
    local list = ns.Nearby:Candidates()
    local ids = {}
    for _, c in ipairs(list) do ids[#ids + 1] = c.itemID end
    T.same(ids, { 901, 902 }, "903 done, 904 too high; 902 after 901 though it scores higher")
    T.contains(ns.Nearby.Describe(list[2]), "from level 5, after 1 earlier quest")
  end)
end)

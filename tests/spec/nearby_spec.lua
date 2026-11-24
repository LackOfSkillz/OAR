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
    T.eq(#list, 3)
    T.eq(list[1].name, "Vendor Cloak")
    T.eq(list[2].name, "Quest Cloak")
    T.contains(N.Describe(list[2]), "quest Help the Grimtotem (level 22)")
    T.eq(list[3].name, "Far Cloak", "few here: another zone's best cloak comes after this zone's, though it scores higher")
    T.ok(list[3].away)
  end)

  T.it("with plenty here, other zones stay out", function()
    local _, _, N = session()
    N.FEW = 2
    local list = N:Candidates()
    T.eq(#list, 2)
    N.FEW = 6
  end)

  T.it("other zones: one per slot, your continent first, never a toast", function()
    local game = mock.new({ mapID = 1450, x = 0.5, y = 0.5, level = 12 })
    game.env.Outrider_DataGear = { source = "test", items = {
      [601] = { "Kalimdor Cloak", 10, 14, { { "vendor", 1438, 0.5, 0.5, "Near Vendor", nil, nil } } },
      [602] = { "Better Kalimdor Cloak", 10, 14, { { "drop", 1438, 0.5, 0.5, "Wolf", nil, nil } } },
      [603] = { "Azeroth Cloak", 10, 14, { { "vendor", 1429, 0.5, 0.5, "Far Vendor", nil, nil } } },
      [604] = { "Azeroth Boots", 10, 14, { { "vendor", 1429, 0.5, 0.5, "Far Vendor", nil, nil } } },
    } }
    game.items = { [400] = { name = "Old Cloak", equipLoc = "INVTYPE_CLOAK" }, [401] = { name = "Old Boots", equipLoc = "INVTYPE_FEET" },
      [601] = { name = "Kalimdor Cloak", equipLoc = "INVTYPE_CLOAK" }, [602] = { name = "Better Kalimdor Cloak", equipLoc = "INVTYPE_CLOAK" },
      [603] = { name = "Azeroth Cloak", equipLoc = "INVTYPE_CLOAK" }, [604] = { name = "Azeroth Boots", equipLoc = "INVTYPE_FEET" } }
    game.itemStats = { [400] = { ITEM_MOD_AGILITY_SHORT = 2 }, [401] = { ITEM_MOD_AGILITY_SHORT = 2 },
      [601] = { ITEM_MOD_AGILITY_SHORT = 5 }, [602] = { ITEM_MOD_AGILITY_SHORT = 7 },
      [603] = { ITEM_MOD_AGILITY_SHORT = 12 }, [604] = { ITEM_MOD_AGILITY_SHORT = 6 } }
    game.worn = { [15] = 400, [8] = 401 }
    game.maps = { [1450] = { mapID = 1450, name = "Moonglade", mapType = 3, parent = 1414 },
      [1438] = { mapID = 1438, name = "Teldrassil", mapType = 3, parent = 1414 },
      [1429] = { mapID = 1429, name = "Elwynn Forest", mapType = 3, parent = 1415 },
      [1414] = { mapID = 1414, name = "Kalimdor", mapType = 2, parent = 947 },
      [1415] = { mapID = 1415, name = "Eastern Kingdoms", mapType = 2, parent = 947 } }
    local ns = game:loadAddon()
    game:login()
    local N = ns.Nearby
    local list = N:Candidates()
    local names = {}
    for _, c in ipairs(list) do names[#names + 1] = c.name end
    T.same(names, { "Better Kalimdor Cloak", "Azeroth Boots" }, "best cloak on Kalimdor beats the bigger one across the sea")
    T.contains(N.Describe(list[1]), "Teldrassil")
    N:Scan("test")
    T.eq(ns.Toast:Count(), 0, "no 'upgrade nearby' toast for other zones")
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

T.describe("nearby new sources", function()
  T.it("dungeon, rare and chest sources read plainly; gear you can craft is listed first", function()
    local game = mock.new({ mapID = 1412, x = 0.5, y = 0.5, level = 20 })
    game.env.Outrider_DataGear = { source = "test", items = {
      [701] = { "Boss Cloak", 20, 25, { { "dungeon", 1412, 0.4, 0.4, "Mutanus the Devourer (Wailing Caverns)", nil, nil } } },
      [702] = { "Rare Cloak", 20, 25, { { "rare", 1412, 0.4, 0.4, "Snort the Heckler", nil, nil } } },
      [703] = { "Chest Cloak", 20, 25, { { "chest", 1412, 0.4, 0.4, "Solid Chest", nil, nil } } },
      [705] = { "World Cloak", 20, 25, { { "world", 0, 0, 0, "creatures level 18 and up", nil, nil } } },
    } }
    game.items = { [400] = { name = "Old Cloak", equipLoc = "INVTYPE_CLOAK" } }
    game.itemStats = { [400] = { ITEM_MOD_AGILITY_SHORT = 2 } }
    for id = 701, 705 do
      game.items[id] = { name = "c" .. id, equipLoc = "INVTYPE_CLOAK" }
      game.itemStats[id] = { ITEM_MOD_AGILITY_SHORT = 6 }
    end
    game.worn = { [15] = 400 }
    local ns = game:loadAddon()
    game:login()
    ns.db.char.professions = { Tailoring = { recipes = { [9001] = { name = "Made Cloak", learned = true, product = 704 } } } }
    local list = ns.Nearby:Candidates()
    local by = {}
    for _, c in ipairs(list) do by[c.itemID] = ns.Nearby.Describe(c) end
    T.eq(list[1].itemID, 704, "crafting is the least effort at equal gain")
    T.contains(by[704], "you can make it with Tailoring")
    T.contains(by[701], "dropped by Mutanus the Devourer (Wailing Caverns)")
    T.contains(by[702], "dropped by the rare Snort the Heckler")
    T.contains(by[703], "found in a Solid Chest")
    T.contains(by[705], "world drop from creatures level 18 and up")
    local cards = ns.Nearby:CardItems()
    for _, c in ipairs(cards) do
      if c.itemID == 705 then T.eq(#c.actions, 0, "a world drop has no waypoint") end
    end
    T.eq(#ns.Errors.list, 0)
  end)
end)

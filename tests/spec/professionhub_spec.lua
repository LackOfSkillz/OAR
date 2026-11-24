-- Professions, "Your professions" (Gary, 2026-11-21: craft what's in your
-- bags, or get pointed to the auction house or the nearest place for the
-- ingredients). Recipes, sources and prices are test data.
local T, mock = ...

local function start()
  local game = mock.new({ class = "ROGUE", level = 14, mapID = 1412, x = 0.5, y = 0.5 })
  game.mapWorld = { [1412] = { 1, 0, 0 }, [1456] = { 2, 0, 0 } }
  game.prof = { name = "Leatherworking", skill = 57, max = 150, recipes = {
    [1] = { name = "Light Armor Kit", diff = 0, reagents = { [2318] = 1 } },
    [2] = { name = "Embossed Leather Gloves", diff = 1, reagents = { [2318] = 3, [2320] = 2 } },
    [3] = { name = "Handstitched Belt", diff = 2, reagents = { [2318] = 6, [2672] = 1 } },
  } }
  game.items = { [2318] = { name = "Light Leather" }, [2320] = { name = "Coarse Thread" }, [2672] = { name = "Stringy Wolf Meat" } }
  local pack = { source = "test",
    items = {
      [2318] = { "Light Leather", 10, 6, {}, {}, {} },
      [2320] = { "Coarse Thread", 5, 0, {}, {}, { 900 } },
      [2672] = { "Stringy Wolf Meat", 5, 0, { 901, 902 }, {}, {} },
    },
    npcs = {
      [900] = { "Thread Seller", 10, 10, nil, { [1412] = { 0.52, 0.5 } } },
      [901] = { "Young Wolf", 12, 13, nil, { [1412] = { 0.6, 0.5 } } },
      [902] = { "Ancient Wolf", 50, 52, nil, { [1412] = { 0.51, 0.5 } } },
    },
    objects = {},
  }
  game.base.Outrider_DataReagents = pack
  rawset(game.env, "Outrider_DataReagents", pack)
  local ns = game:loadAddon()
  game:login()
  game:fire("TRADE_SKILL_SHOW")
  game:advance(1)
  ns.db.global.inventory[ns.db.key] = { bags = { [2318] = 4 }, bank = {} }
  return game, ns, ns.ProfessionHub
end

T.describe("your professions", function()
  T.it("sorts what you can make now from what you still need", function()
    local _, ns, M = start()
    local r = M:Recipes("Leatherworking")
    T.eq(r.now[1].name, "Light Armor Kit", "best for skill first")
    T.eq(r.now[1].n, 4, "four from four leather")
    T.eq(r.next[1].name, "Embossed Leather Gloves")
    T.eq(r.next[1].missing[1].name, "Coarse Thread")
    T.eq(r.next[1].missing[1].need, 2)
  end)

  T.it("finds the best source: a vendor, a creature around your level, the auction house", function()
    local _, ns, M = start()
    local thread = M:Sources(2320, 2)
    T.eq(thread[1].kind, "vendor")
    T.contains(thread[1].text, "Thread Seller")
    local meat = M:Sources(2672, 1)
    T.eq(meat[1].kind, "drop")
    T.contains(meat[1].text, "Young Wolf", "the level 50 wolf is too high for you")
    ns.Prices:Record(2318, 40)
    local leather = M:Sources(2318, 2)
    T.eq(leather[1].kind, "ah", "no source on the map: the auction house with its price")
    T.ok(leather[1].price == 40)
    local hint = false
    for _, s in ipairs(leather) do if s.kind == "hint" then hint = true end end
    T.ok(hint, "leather: skin beasts")
  end)

  T.it("a click on a source plans the way there", function()
    local _, ns, M = start()
    local planned
    ns.Journey.Go = function(_, e) planned = e return true end
    M:Go(M:Sources(2320, 2)[1])
    T.ok(planned and planned.target, "a trip to the vendor")
  end)

  T.it("is the first tab of Professions and fills without errors", function()
    local game, ns = start()
    ns.Hub:Build():Show()
    ns.Hub:ShowTab(ns.Hub.LastSub("professions"))
    T.eq(ns.Hub.current, "professions")
    local p = ns.Hub.byId.professions.panel
    T.contains(p.detail.title:GetText(), "Leatherworking")
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("gathering professions", function()
  T.it("Herbalism lists the herbs for your skill with their nearest spot, newest herb first", function()
    local _, ns, M = start()
    M:Pack()
    M.pack.items[2447] = { "Peacebloom", 5, 9, {}, { 1617 }, {} }
    M.pack.items[765] = { "Silverleaf", 5, 9, {}, { 1618 }, {} }
    M.pack.objects = { [1617] = { "Peacebloom", { [1412] = { 0.55, 0.5 } } }, [1618] = { "Silverleaf", { [1412] = { 0.45, 0.5 } } } }
    ns.db.char.professions.Herbalism = { skill = 7, max = 75, recipes = {} }
    local pick
    for _, p in ipairs(M:Profs()) do if p.name == "Herbalism" then pick = p end end
    local rows = M:GatherRows(pick)
    T.ok(#rows >= 2, "starter herbs listed")
    T.eq(rows[1].item.name, "Silverleaf", "the later herb in the guide first")
    T.contains(rows[1].source.text, "Pick Silverleaf")
    T.ok(rows[1].source.target ~= nil, "Go has somewhere to go")
    for _, r in ipairs(rows) do T.ok(r.item.name ~= "Earthroot", "Earthroot needs 15") end
    ns.Hub:Build():Show()
    ns.Hub:ShowTab("professions")
    local panel = ns.Hub.byId.professions.panel
    M.lastPick = "Herbalism"
    for _, c in ipairs(panel.cards or {}) do if c.prof == "Herbalism" and c:GetScript("OnClick") then c:GetScript("OnClick")(c) end end
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("recipes to learn", function()
  T.it("lists recipes you don't know yet that still give skill, learnable now first, with where to learn them", function()
    local game, ns, M = start()
    local pack = { source = "spec",
      recipes = {
        [9001] = { "Leatherworking", 50, 70, 90, 5001, 1, {}, "trainer", nil, "Trainer Boots" },
        [9002] = { "Leatherworking", 55, 75, 95, 5002, 1, {}, "item", 7001, "Pattern Gloves" },
        [9003] = { "Leatherworking", 75, 95, 115, 5003, 1, {}, "item", 7002, "Later Belt" },
        [9004] = { "Leatherworking", 1, 20, 40, 5004, 1, {}, "trainer", nil, "Grey Belt" },
        [9005] = { "Tailoring", 50, 70, 90, 5005, 1, {}, "trainer", nil, "Cloth Thing" },
        [1] = { "Leatherworking", 1, 30, 60, 5006, 1, {}, "trainer", nil, "Light Armor Kit" },
      },
      recipeItems = { [7001] = { "Pattern: Gloves", { { "vendor", 1412, 0.52, 0.5, "Pattern Seller", nil } } } },
    }
    rawset(game.env, "Outrider_DataCrafting", pack)
    M.crafting = nil
    local list = M:ToLearn("Leatherworking", 57, ns.db.char.professions.Leatherworking.recipes)
    local names = {}
    for _, e in ipairs(list) do names[#names + 1] = e.name end
    T.same(names, { "Trainer Boots", "Pattern Gloves", "Later Belt" }, "grey, known and other professions left out; later one last")
    T.contains(list[1].source.text, "trainer")
    T.contains(list[2].source.text, "Pattern Seller")
    T.ok(list[2].source.target ~= nil, "Go has a spot")
    ns.Hub:Build():Show()
    ns.Hub:ShowTab("professions")
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("profession slots", function()
  T.it("Fishing and Cooking show although Forever's archaeology slot is empty", function()
    local game, ns, M = start()
    local slots = { [1] = { "Herbalism", 7, 75 }, [4] = { "Fishing", 1, 75 }, [5] = { "Cooking", 1, 75 } }
    game.env.GetProfessions = function() return 1, nil, nil, 4, 5 end
    game.env.GetProfessionInfo = function(i) local s = slots[i] if s then return s[1], nil, s[2], s[3], 0, 0, nil end end
    local owned = ns.Crafter:Owned()
    T.ok(owned.Fishing ~= nil, "Fishing")
    T.ok(owned.Cooking ~= nil, "Cooking")
    ns.Professions:ScanSkills()
    T.eq(ns.db.char.professions.Fishing.skill, 1)
    local names = {}
    for _, p in ipairs(M:Profs()) do names[p.name] = true end
    T.ok(names.Fishing, "on the Professions page")
  end)
end)

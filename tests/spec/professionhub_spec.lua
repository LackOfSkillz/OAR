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

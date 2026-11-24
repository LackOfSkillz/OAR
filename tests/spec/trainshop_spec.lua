-- Training shopping: what the skill-up recipes need, priced at the auction
-- house, cheapest per skill point first, plus unknown recipes for sale.
local T, mock = ...

local function session()
  local game = mock.new({ now = 1794700000 })
  game.items = {
    [765] = { name = "Silverleaf" }, [2447] = { name = "Peacebloom" }, [3371] = { name = "Empty Vial" },
    [2318] = { name = "Light Leather" }, [2995] = { name = "Recipe: Swiftness Potion" },
  }
  local ns = game:loadAddon()
  game:login()
  ns.db.char.professions = {
    Alchemy = { skill = 30, max = 75, recipes = {
      [1] = { name = "Minor Healing Potion", diff = 1, reagents = { [2447] = 1, [765] = 1, [3371] = 1 } },
      [2] = { name = "Elixir of Minor Defense", diff = 0, reagents = { [765] = 2, [3371] = 1 } },
      [3] = { name = "Old Grey Potion", diff = 3, reagents = { [2447] = 1 } } } },
  }
  game.ahListings = {
    [765] = { name = "Silverleaf", minPrice = 10, qty = 100 },
    [2447] = { name = "Peacebloom", minPrice = 15, qty = 50 },
    [2995] = { name = "Recipe: Swiftness Potion", minPrice = 5000, recipe = 6 },
  }
  game.itemTips = { [2995] = { "Recipe: Swiftness Potion", "Requires Alchemy (60)" } }
  ns.Crafter.Have = function(id) return ({ [3371] = 20 })[id] or 0 end
  return game, ns
end

local function run(game, ns)
  game:fire("AUCTION_HOUSE_SHOW")
  ns.TrainShop:Start()
  local guard = 0
  while ns.TrainShop.queue and guard < 20 do
    guard = guard + 1
    game:fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
  end
end

T.describe("training shopping", function()
  T.it("needs come only from recipes that still give skill", function()
    local _, ns = session()
    local needs = ns.TrainShop:Needs()
    T.ok(needs[765] and needs[2447], "Silverleaf and Peacebloom")
    T.eq(needs[3371], nil, "20 vials in the bags are enough")
  end)

  T.it("searches each ingredient and the recipe category, ranks by cost per point, lists unknown recipes", function()
    local game, ns = session()
    run(game, ns)
    T.eq(#game.queries, 3, "Peacebloom, Silverleaf, Alchemy recipes")
    local text = table.concat(ns.TrainShop:Lines(), "\n")
    -- Defense: 10 crafts x 2 Silverleaf x 10c = 200c for 10 points = 20c/point
    -- Healing: 8 crafts x (10 + 15)c = 200c for 6 points = 33c/point
    T.ok(text:find("Elixir of Minor Defense", 1, true) < text:find("Minor Healing Potion", 1, true), "cheaper per point first")
    T.contains(text, "20c per point")
    T.ok(not text:find("Swiftness", 1, true), "needs 60, you 30: more than 25 above, left out")
    T.ok(not text:find("Old Grey Potion", 1, true), "grey recipes never")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a search that goes unanswered switches to one search per click", function()
    local game, ns = session()
    game:fire("AUCTION_HOUSE_SHOW")
    ns.TrainShop:Start()
    ns.TrainShop:Timeout(ns.TrainShop.queue[1])
    T.ok(ns.TrainShop.manual)
    T.contains(ns.TrainShop.frame.button.label:GetText(), "Search next")
  end)
end)

T.describe("training shopping by profession", function()
  local function both()
    local game, ns = session()
    ns.db.char.professions.Cooking = { skill = 63, max = 75, line = 185, recipes = {} }
    for k = 1, 10 do
      ns.db.char.professions.Cooking.recipes[100 + k] = { name = "Snack " .. k, diff = 0, reagents = { [2318] = 1 } }
    end
    ns.db.char.professions.Alchemy.line = 171
    local have = ns.Crafter.Have
    ns.Crafter.Have = function(id) if id == 2318 then return 99 end return have(id) end
    return game, ns
  end

  T.it("All gives each profession a share: ten free Cooking recipes don't hide Alchemy", function()
    local game, ns = both()
    run(game, ns)
    local text = table.concat(ns.TrainShop:Lines(), "|")
    T.contains(text, "Alchemy: Elixir of Minor Defense")
    T.contains(text, "Cooking: Snack")
  end)

  T.it("choosing Alchemy searches only Alchemy and lists only Alchemy; chips are this character's professions", function()
    local game, ns = both()
    game:fire("AUCTION_HOUSE_SHOW")
    ns.TrainShop:Choose("Alchemy")
    local guard = 0
    while ns.TrainShop.queue and guard < 20 do guard = guard + 1 game:fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED") end
    local text = table.concat(ns.TrainShop:Lines(), "|")
    T.contains(text, "Alchemy:")
    T.ok(not text:find("Cooking", 1, true))
    local labels = {}
    for _, c in ipairs(ns.TrainShop.frame.chips) do if c:IsShown() then labels[#labels + 1] = c.label:GetText() .. (c.on and "*" or "") end end
    T.eq(table.concat(labels, ","), "All,Alchemy*,Cooking")
    ns.TrainShop:Choose(nil)
    T.eq(ns.TrainShop:Chosen(), nil)
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("shopping window (2026-11-20 redesign)", function()
  T.it("Training has three sub-items: skill-up cards, recipes and a shopping list with Buy all", function()
    local game, ns = session()
    run(game, ns)
    local G = ns.GearShop
    G.open = true
    G:Pick("training")
    local f = G.frame
    T.ok(f:IsShown(), "window shown")
    T.ok(f.rows[1]:IsShown(), "a skill-up card")
    T.contains(f.rows[1].text:GetText(), "Elixir of Minor Defense")
    T.contains(f.rows[1].pill:GetText(), "+10 skill")
    T.ok(f.rows[1].reagents[1]:IsShown(), "reagent icons")
    G:Pick("recipes")
    T.eq(G.mode, "recipes")
    T.ok(not f.rows[1]:IsShown(), "Swiftness needs 60: nothing usable soon")
    G:Pick("list")
    local names = {}
    for _, r in ipairs(f.rows) do if r:IsShown() then names[#names + 1] = r.text:GetText() end end
    T.contains(table.concat(names, ","), "Silverleaf")
    T.contains(table.concat(names, ","), "Peacebloom")
    T.ok(f.buyAll:IsShown(), "Buy all")
    T.eq(#game.queries, 3, "one search serves all three views")
    G:BuyAll()
    T.ok((ns.AHBuy.current and 1 or 0) + #ns.AHBuy.queue >= 2, "every line queued, each still confirmed by a click")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("gear views search from the menu and page through results", function()
    local game, ns = session()
    game:fire("AUCTION_HOUSE_SHOW")
    local G = ns.GearShop
    G:Pick("bags")
    T.eq(G.mode, "bags")
    T.ok(G.queue ~= nil or G.found ~= nil, "a bag search started")
    G.found, G.queue = {}, nil
    G:Refresh()
    T.ok(G.frame.empty ~= nil)
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("recipes you already know", function()
  T.it("leaves out only recipes this character knows; another character knowing one doesn't hide it", function()
    local game, ns = session()
    game.items[2996] = { name = "Recipe: Elixir of Minor Defense" }
    game.items[2997] = { name = "Recipe: Holy Brew" }
    game.items[2998] = { name = "Recipe: Fresh Brew" }
    game.ahListings[2996] = { name = "Recipe: Elixir of Minor Defense", minPrice = 100, recipe = 6 }
    game.ahListings[2997] = { name = "Recipe: Holy Brew", minPrice = 200, recipe = 6 }
    game.ahListings[2998] = { name = "Recipe: Fresh Brew", minPrice = 300, recipe = 6 }
    game.itemTips[2996] = { "Recipe: Elixir of Minor Defense", "Requires Alchemy (1)" }
    game.itemTips[2997] = { "Recipe: Holy Brew", "Requires Alchemy (10)" }
    game.itemTips[2998] = { "Recipe: Fresh Brew", "Requires Alchemy (20)" }
    ns.db.raw.chars["Khreos-Airwolf"] = { professions = { Alchemy = { skill = 200, recipes = { [9] = { name = "Holy Brew" } } } } }
    run(game, ns)
    local names = {}
    for _, r in ipairs(ns.TrainShop:UsefulRecipes()) do names[#names + 1] = r.name end
    T.eq(table.concat(names, ","), "Recipe: Holy Brew,Recipe: Fresh Brew", "Defense: you know it; Holy Brew stays though Khreos knows it")
    local _, status = ns.TrainShop:View("recipes")
    T.contains(status, "Hidden: 1 you already know")
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("recipes you already know, every profession", function()
  -- the prefix each profession's recipe items carry, and its auction subclass
  local PROFS = {
    { "Alchemy", "Recipe", 6 }, { "Blacksmithing", "Plans", 4 }, { "Cooking", "Recipe", 5 },
    { "Enchanting", "Formula", 8 }, { "Engineering", "Schematic", 3 }, { "First Aid", "Manual", 7 },
    { "Leatherworking", "Pattern", 1 }, { "Tailoring", "Pattern", 2 },
  }
  for _, p in ipairs(PROFS) do
    local prof, prefix, sub = p[1], p[2], p[3]
    T.it(prof .. ": hides what this character knows (by name or 'Already known'), keeps what only another character knows", function()
      local game = mock.new({ now = 1794700000 })
      game.items = {
        [1] = { name = "Linen Cloth" },
        [11] = { name = prefix .. ": Known Thing" }, [12] = { name = prefix .. ": Alt Thing" },
        [13] = { name = prefix .. ": New Thing" }, [14] = { name = prefix .. ": Tooltip Thing" },
      }
      local ns = game:loadAddon()
      game:login()
      ns.db.char.professions = { [prof] = { skill = 50, max = 75, recipes = {
        [1] = { name = "Known Thing", diff = 3, reagents = { [1] = 1 } } } } }
      ns.db.raw.chars["Alty-Realm"] = { professions = { [prof] = { skill = 300, recipes = { [9] = { name = "Alt Thing" } } } } }
      game.ahListings = {
        [11] = { name = prefix .. ": Known Thing", minPrice = 100, recipe = sub },
        [12] = { name = prefix .. ": Alt Thing", minPrice = 200, recipe = sub },
        [13] = { name = prefix .. ": New Thing", minPrice = 300, recipe = sub },
        [14] = { name = prefix .. ": Tooltip Thing", minPrice = 400, recipe = sub },
      }
      game.itemTips = {
        [11] = { prefix .. ": Known Thing", "Requires " .. prof .. " (40)" },
        [12] = { prefix .. ": Alt Thing", "Requires " .. prof .. " (45)" },
        [13] = { prefix .. ": New Thing", "Requires " .. prof .. " (50)" },
        [14] = { prefix .. ": Tooltip Thing", "Requires " .. prof .. " (30)", "Already known" },
      }
      ns.Crafter.Have = function() return 99 end
      game:fire("AUCTION_HOUSE_SHOW")
      ns.TrainShop:Start()
      local guard = 0
      while ns.TrainShop.queue and guard < 20 do guard = guard + 1 game:fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED") end
      local searched
      for _, q in ipairs(game.queries or {}) do
        local f = q.itemClassFilters and q.itemClassFilters[1]
        if f and f.classID == 9 and f.subClassID == sub then searched = true end
      end
      T.ok(searched, prof .. " recipes searched in subclass " .. sub)
      local names = {}
      for _, r in ipairs(ns.TrainShop:UsefulRecipes()) do names[#names + 1] = r.name end
      table.sort(names)
      T.eq(table.concat(names, ","), prefix .. ": Alt Thing," .. prefix .. ": New Thing")
      local _, status = ns.TrainShop:View("recipes")
      T.contains(status, "Hidden: 2 you already know")
      T.eq(#ns.Errors.list, 0)
    end)
  end
end)

T.describe("recipe items that load late (2026-11-20: 57 of 58 without skill)", function()
  T.it("a recipe whose tooltip isn't loaded yet is read again later, and dropped if you know it", function()
    local game, ns = session()
    game.items[2996] = { name = "Recipe: Elixir of Minor Defense" }
    game.items[2997] = { name = "Recipe: Late Brew" }
    game.ahListings[2996] = { name = "Recipe: Elixir of Minor Defense", minPrice = 100, recipe = 6 }
    game.ahListings[2997] = { name = "Recipe: Late Brew", minPrice = 200, recipe = 6 }
    game.itemTips[2995] = { "Recipe: Swiftness Potion" } -- not loaded: only the title
    game.itemTips[2996] = { "Recipe: Elixir of Minor Defense" }
    game.itemTips[2997] = { "Recipe: Late Brew" }
    run(game, ns)
    local T2 = ns.TrainShop
    T.eq(#T2:UsefulRecipes(), 0, "nothing readable yet")
    -- the item data arrives
    game.itemTips[2995] = { "Recipe: Swiftness Potion", "Requires Alchemy (60)" }
    game.itemTips[2996] = { "Recipe: Elixir of Minor Defense", "Requires Alchemy (1)" }
    game.itemTips[2997] = { "Recipe: Late Brew", "Requires Alchemy (35)" }
    local list = T2:UsefulRecipes()
    T.eq(#list, 1)
    T.eq(list[1].name, "Recipe: Late Brew")
    T.eq(list[1].need, 35)
    T.ok(T2.knownHidden >= 1, "Minor Defense is known: dropped once readable")
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("add then buy on the same button (2026-11-20)", function()
  T.it("first click adds to the cart, the same button then says Buy and buys; the cart bar does the same", function()
    local game, ns = session()
    run(game, ns)
    local G = ns.GearShop
    G.open = true
    G:Pick("list")
    local f = G.frame
    local card = f.rows[1]
    T.eq(card.buy.label:GetText(), "Buy", "one thing to buy: the button says Buy")
    T.contains(f.cart.text:GetText(), "Cart empty")
    card.buy.__scripts.OnClick(card.buy)
    T.eq(card.buy.label:GetText(), "...", "finding the price")
    game:fire("COMMODITY_PRICE_UPDATED", 10, 200)
    T.eq(card.buy.label:GetText(), "Buy", "same spot, now Buy")
    T.contains(f.cart.text:GetText(), "Cart 1")
    card.buy.__scripts.OnClick(card.buy)
    T.eq(#game.bought, 1, "bought with the second click on the same button")
    T.eq(card.buy.label:GetText(), "Buying")
    game:fire("COMMODITY_PURCHASE_SUCCEEDED")
    T.eq(card.buy.label:GetText(), "Bought")
    -- Add all, then Buy in the cart bar without moving
    f.buyAll.__scripts.OnClick(f.buyAll)
    game:fire("COMMODITY_PRICE_UPDATED", 10, 200)
    f.cart.buy.__scripts.OnClick(f.cart.buy)
    T.eq(#game.bought, 2)
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("every profession, gathering too (2026-11-24: only Cooking and First Aid had chips)", function()
  local function gatherer()
    local game, ns = session()
    -- the five-slot shape: Herbalism in slot 1, Fishing in the fishing slot, no archaeology
    game.profs = { [1] = { name = "Herbalism", skill = 10, max = 75, line = 182 },
      [4] = { name = "Fishing", skill = 75, max = 150, line = 356 } }
    ns.db.char.professions = {
      Cooking = { skill = 40, max = 75, line = 185, recipes = { [1] = { name = "Snack", diff = 0, reagents = { [2318] = 1 } } } },
      ["First Aid"] = { skill = 30, max = 75, line = 129, recipes = {} },
    }
    game.items[90001] = { name = "Shiny Bauble" }
    game.items[90002] = { name = "Fishing Pole" }
    game.items[90003] = { name = "Strong Fishing Pole" }
    game.items[90004] = { name = "Pole Rack" } -- answers the search but isn't a pole
    game.items[90005] = { name = "Book: Fishing Basics" }
    game.ahListings[90001] = { name = "Shiny Bauble", minPrice = 300, qty = 20 }
    game.ahListings[90002] = { name = "Fishing Pole", minPrice = 50 }
    game.ahListings[90003] = { name = "Strong Fishing Pole", minPrice = 5000 }
    game.ahListings[90004] = { name = "Fishing Pole", minPrice = 1 }
    game.ahListings[90005] = { name = "Book: Fishing Basics", minPrice = 900, recipe = 9 }
    return game, ns
  end
  local function choose(game, ns, prof)
    game:fire("AUCTION_HOUSE_SHOW")
    ns.TrainShop:Choose(prof)
    local guard = 0
    while ns.TrainShop.queue and guard < 40 do guard = guard + 1 game:fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED") end
  end
  local function labels(ns)
    local out = {}
    for _, c in ipairs(ns.TrainShop.frame.chips) do if c:IsShown() then out[#out + 1] = c.label:GetText() .. (c.on and "*" or "") end end
    return table.concat(out, ",")
  end

  T.it("chips: All and every profession this character has, crafting and gathering", function()
    local game, ns = gatherer()
    game:fire("AUCTION_HOUSE_SHOW")
    T.eq(labels(ns), "All*,Cooking,First Aid,Fishing,Herbalism")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("Fishing searches each lure, a pole and the Fishing books; results become supply cards with a Buy", function()
    local game, ns = gatherer()
    choose(game, ns, "Fishing")
    T.eq(labels(ns), "All,Cooking,First Aid,Fishing*,Herbalism")
    local texts, books = {}, false
    for _, q in ipairs(game.queries or {}) do
      if q.searchString ~= "" then texts[q.searchString] = true end
      local f = q.itemClassFilters and q.itemClassFilters[1]
      if f and f.classID == 9 and f.subClassID == 9 then books = true end
    end
    for _, lure in ipairs(ns.Fishing.LURES) do T.ok(texts[lure], "searched " .. lure) end
    T.ok(texts["Fishing Pole"], "searched a pole")
    T.ok(books, "Fishing books still searched")
    T.ok(not texts["Light Leather"], "no Cooking ingredients")
    local cards, status = ns.TrainShop:View("training")
    local byName = {}
    for _, c in ipairs(cards) do byName[c.title] = c end
    local b = byName["Shiny Bauble"]
    T.ok(b, "a lure card")
    T.eq(b.sub, "Helps Fishing")
    T.eq(b.price, 300)
    T.eq(b.action[1].name, "Shiny Bauble")
    T.eq(b.action[1].itemKey.itemID, 90001)
    T.ok(byName["Fishing Pole"] and byName["Strong Fishing Pole"], "poles whose name holds the search")
    T.eq(byName["Pole Rack"], nil, "a result without the searched name is left out")
    T.contains(status, "help Fishing")
    T.eq(#(game.bought or {}), 0, "nothing bought without a click")
    -- drawn in the shopping window with a Buy button
    local G = ns.GearShop
    G.open = true
    G:Pick("training")
    local shown = {}
    for _, r in ipairs(G.frame.rows) do if r:IsShown() then shown[#shown + 1] = r.text:GetText() .. (r.buy:IsShown() and "+buy" or "") end end
    T.contains(table.concat(shown, ","), "Shiny Bauble+buy")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("Herbalism: one plain card, no search", function()
    local game, ns = gatherer()
    choose(game, ns, "Herbalism")
    T.eq(#(game.queries or {}), 0, "nothing to search")
    local cards, status = ns.TrainShop:View("training")
    T.eq(#cards, 1)
    T.eq(cards[1].title, "Herbalism")
    T.contains(cards[1].sub, "picking herbs")
    T.eq(cards[1].action, nil)
    T.contains(status, "nothing to buy")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("All adds supplies after the crafting skill-ups; a crafting chip is unchanged", function()
    local game, ns = gatherer()
    ns.db.char.professions.Alchemy = { skill = 30, max = 75, line = 171, recipes = {
      [2] = { name = "Elixir of Minor Defense", diff = 0, reagents = { [765] = 2, [3371] = 1 } } } }
    choose(game, ns, nil)
    local cards = ns.TrainShop:View("training")
    local titles = {}
    for _, c in ipairs(cards) do titles[#titles + 1] = c.title end
    local all = table.concat(titles, "|")
    T.ok(all:find("Elixir of Minor Defense", 1, true) < all:find("Shiny Bauble", 1, true), "recipes first, then supplies")
    T.contains(all, "Herbalism")
    game.queries = nil
    choose(game, ns, "Alchemy")
    T.eq(#game.queries, 2, "Silverleaf and Alchemy recipes only")
    cards = ns.TrainShop:View("training")
    T.eq(#cards, 1)
    T.contains(cards[1].title, "Elixir of Minor Defense")
    T.eq(#ns.Errors.list, 0)
  end)
end)

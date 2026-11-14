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

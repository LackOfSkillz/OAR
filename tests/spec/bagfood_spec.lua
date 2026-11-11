-- Food and drink placeholders (P4-05). Items are test data.
local T, mock = ...

local function session()
  local game = mock.new({ level = 20 })
  game.items = {
    [1] = { name = "Old Bread", reqLevel = 5, spell = "Food" },
    [2] = { name = "Tough Jerky", reqLevel = 15, spell = "Food" },
    [3] = { name = "Too Good Steak", reqLevel = 35, spell = "Food" },
    [4] = { name = "Spring Water", reqLevel = 5, spell = "Drink" },
    [5] = { name = "Conjured Water", reqLevel = 1, spell = "Drink" },
    [6] = { name = "Linen Cloth", reqLevel = 0 },
  }
  game.bags = { [0] = { 1, 2, 3, 4, 5, 6 } }
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  return game, ns
end

local function eatDrink(ns)
  for _, e in ipairs(ns.Data:All("macro")) do if e.id == "all-eat-drink" then return e end end
end

T.describe("bag food", function()
  T.it("picks the best usable food and drink, conjured first", function()
    local game, ns = session()
    T.eq(ns.BagFood.food, "Tough Jerky")
    T.eq(ns.BagFood.drink, "Conjured Water")
  end)

  T.it("the EatDrink macro fills in and updates itself when a food runs out", function()
    local game, ns = session()
    local e = eatDrink(ns)
    T.ok(ns.MacroLibrary:Install(e))
    T.eq(game.macros[1].body, "/use Conjured Water\n/use Tough Jerky")
    game.bags[0][2] = nil -- ate the last Tough Jerky
    game:fire("BAG_UPDATE_DELAYED")
    game:advance(11)
    T.eq(game.macros[1].body, "/use Conjured Water\n/use Old Bread")
  end)

  T.it("never updates in combat; catches up after", function()
    local game, ns = session()
    ns.MacroLibrary:Install(eatDrink(ns))
    game.combat = true
    game.bags[0][2] = nil
    game:fire("BAG_UPDATE_DELAYED")
    game:advance(11)
    T.contains(game.macros[1].body, "Tough Jerky")
    game:setCombat(false)
    game:advance(11)
    T.contains(game.macros[1].body, "Old Bread")
    T.eq(#ns.Errors.list, 0)
  end)
end)

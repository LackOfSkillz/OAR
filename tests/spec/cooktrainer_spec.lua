-- Cooking training button: estimate from recipe colours and bags, shows at +10,
-- builds a fire first when it can, then cooks; grey recipes never count.
local T, mock = ...

local function session(bagCounts)
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  ns.db.char.professions = ns.db.char.professions or {}
  ns.db.char.professions.Cooking = { skill = 40, max = 75, recipes = {
    [1] = { name = "Charred Wolf Meat", learned = true, diff = 0, reagents = { [2672] = 1 } },
    [2] = { name = "Roasted Boar Meat", learned = true, diff = 1, reagents = { [769] = 1 } },
    [3] = { name = "Herb Baked Egg", learned = true, diff = 3, reagents = { [6889] = 1 } },
    [4] = { name = "Basic Campfire", learned = true, diff = 0, reagents = { [4470] = 1 } },
  } }
  ns.Crafter.Have = function(id) return bagCounts[id] or 0 end
  return game, ns
end

T.describe("cooking trainer", function()
  T.it("counts orange as 1 and yellow as 0.75 per craft, grey and the campfire as nothing", function()
    local _, ns = session({ [2672] = 6, [769] = 8, [6889] = 20, [4470] = 3 })
    local total, list = ns.CookTrainer:Estimate()
    T.eq(total, 12) -- 6 + floor(8 * 0.75)
    T.eq(#list, 2)
  end)

  T.it("shows at +10 with Build fire first, then Cook after the fire goes up; hidden below 10", function()
    local game, ns = session({ [2672] = 6, [769] = 8, [4470] = 1 })
    local CT = ns.CookTrainer
    CT:Evaluate()
    T.ok(CT.btn, "button made at +12")
    T.eq(CT:Body(), "/cast Basic Campfire")
    CT.state = "cook"
    T.eq(CT:Body(), "/ride make Cooking train")
    local _, ns2 = session({ [2672] = 4 })
    ns2.CookTrainer:Evaluate()
    T.eq(ns2.CookTrainer.btn, nil, "+4 is under the threshold")
    T.eq(#ns.Errors.list + #ns2.Errors.list, 0)
  end)

  T.it("without wood it goes straight to Cook", function()
    local _, ns = session({ [2672] = 12 })
    ns.CookTrainer:Evaluate()
    T.eq(ns.CookTrainer.state, "cook")
  end)

  T.it("a snooze hides it for 30 minutes", function()
    local game, ns = session({ [2672] = 12 })
    local CT = ns.CookTrainer
    CT:Evaluate()
    CT:Snooze()
    CT.btn = nil
    CT:Evaluate()
    T.eq(CT.btn, nil)
    game.now = (game.now or time()) + 31 * 60
  end)
end)

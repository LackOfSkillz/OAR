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
    T.eq(CT:Body(), "/ride make Cooking fire")
    CT.state = "make"
    T.eq(CT:Body(), "/ride make Cooking train")
    local _, ns2 = session({ [2672] = 4 })
    ns2.CookTrainer:Evaluate()
    T.eq(ns2.CookTrainer.btn, nil, "+4 is under the threshold")
    T.eq(#ns.Errors.list + #ns2.Errors.list, 0)
  end)

  T.it("without wood it goes straight to Cook", function()
    local _, ns = session({ [2672] = 12 })
    ns.CookTrainer:Evaluate()
    T.eq(ns.CookTrainer.state, "make")
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

T.describe("profession trainer", function()
  T.it("offers the crafting profession with most to gain, never a gathering one, and respects per-profession off", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    ns.db.char.professions = {
      Leatherworking = { skill = 20, max = 75, recipes = {
        [10] = { name = "Light Armor Kit", learned = true, diff = 0, reagents = { [2318] = 1 } } } },
      Alchemy = { skill = 20, max = 75, recipes = {
        [11] = { name = "Minor Healing Potion", learned = true, diff = 1, reagents = { [2447] = 1, [765] = 1 } } } },
      Skinning = { skill = 40, max = 75, recipes = {} },
    }
    ns.Crafter.Have = function(id) return ({ [2318] = 15, [2447] = 20, [765] = 20 })[id] or 0 end
    local T2 = ns.ProfTrainer
    local profs = T2:Professions()
    T.eq(#profs, 2, "Skinning gathers only")
    local prof, total = T2:Best()
    T.eq(prof, "Alchemy") -- 20 x 0.75 = 15 ties 15 x 1; ties keep the first in name order
    T.eq(total, 15)
    ns.ProfTrainer:Settings().off = { Alchemy = true }
    prof = T2:Best()
    T.eq(prof, "Leatherworking")
    T2:Evaluate()
    T.eq(T2:Body(), "/ride make Leatherworking train")
    T2:SetKey("BUTTON4")
    T.eq(T2:Settings().key, "BUTTON4")
    T.contains(T2:Activity(), "Leatherworking about +15")
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("profession trainer blank names", function()
  T.it("a blank-named profession record is dropped and never offered", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    ns.db.char.professions = { [""] = { skill = 0, max = 0, recipes = {
      [1] = { name = "Elixir of Minor Defense", learned = true, diff = 0, reagents = { [765] = 1 } } } } }
    T.eq(#ns.ProfTrainer:Professions(), 0, "never offered")
    ns.Modules:Get("Professions"):Store()
    T.eq(ns.db.char.professions[""], nil, "dropped on the next scan")
  end)
end)

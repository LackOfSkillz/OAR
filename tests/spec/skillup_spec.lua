-- Skill-up planner (P5-04). Recipes, colors and prices are test data.
local T, mock = ...

local function session()
  local game = mock.new()
  game.prof = { name = "Leatherworking", skill = 75, max = 150, recipes = {
    [1] = { name = "Orange Boots", diff = 0, reagents = { [2318] = 4 } },   -- 4 leather per point
    [2] = { name = "Yellow Belt", diff = 1, reagents = { [2318] = 2 } },    -- 2/0.6 = 3.33 leather per point
    [3] = { name = "Green Cuffs", diff = 2, reagents = { [2318] = 1 } },    -- 4 per point
    [4] = { name = "Grey Cloak", diff = 3, reagents = { [2318] = 1 } },     -- no skill
    [5] = { name = "Odd Hat", diff = 0, reagents = { [9999] = 1 } },        -- unpriced
  } }
  game.items = { [2318] = { name = "Light Leather" }, [9999] = { name = "Mystery" } }
  local ns = game:loadAddon()
  game:login()
  game:fire("TRADE_SKILL_SHOW")
  game:advance(1)
  ns.Prices:Record(2318, 100)
  return game, ns, ns.SkillUp
end

T.describe("skillup", function()
  T.it("ranks by cost per expected point; grey skipped, unpriced last", function()
    local _, _, S = session()
    local r = S:Rank("Leatherworking", {})
    T.eq(r[1].name, "Yellow Belt")
    T.eq(math.floor(r[1].perPoint + 0.5), 333)
    T.eq(r[#r].name, "Odd Hat")
    T.eq(r[#r].perPoint, nil)
    for _, x in ipairs(r) do T.no(x.name == "Grey Cloak") end
  end)

  T.it("owned materials are free and used first in the route", function()
    local _, ns, S = session()
    ns.db.global.inventory[ns.db.key] = { bags = { [2318] = 4 }, bank = {} }
    T.eq(S:Rank("Leatherworking")[1].cost, 0)
    local route = S:Route("Leatherworking", 3)
    T.ok(route.points >= 3)
    T.ok(route.cost > 0 and route.cost < 1100)
    T.contains(table.concat(S:Lines("Leatherworking", 78), "\n"), "Route to 78")
    T.eq(#ns.Errors.list, 0)
  end)
end)

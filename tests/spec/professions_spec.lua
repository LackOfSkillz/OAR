-- Profession scanner (P5-02). Recipe data is test data.
local T, mock = ...

T.describe("professions", function()
  T.it("records skill and recipes with reagents when the window opens, per character", function()
    local game = mock.new()
    game.prof = { name = "Leatherworking", skill = 75, max = 150, recipes = {
      [2149] = { name = "Handstitched Leather Boots", reagents = { [2318] = 2, [2320] = 1 } },
      [2152] = { name = "Light Armor Kit", reagents = { [2318] = 1 } },
    } }
    local ns = game:loadAddon()
    game:login()
    game:fire("TRADE_SKILL_SHOW")
    game:advance(1)
    local p = ns.db.char.professions["Leatherworking"]
    T.eq(p.skill, 75)
    T.eq(p.recipes[2149].reagents[2318], 2)
    T.contains(ns.Modules:Get("Professions"):Activity(), "Leatherworking 75/150 (2 recipes)")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a list update with nothing changed is skipped; a skill-up or a learned recipe scans again", function()
    local game = mock.new()
    game.prof = { name = "Leatherworking", skill = 75, max = 150, recipes = {
      [2149] = { name = "Handstitched Leather Boots", reagents = { [2318] = 2, [2320] = 1 } },
    } }
    local ns = game:loadAddon()
    game:login()
    game:fire("TRADE_SKILL_SHOW")
    game:advance(1)
    local T2 = game.env.C_TradeSkillUI
    local orig, info, schem = T2.GetRecipeInfo, 0, 0
    local origS = T2.GetRecipeSchematic
    T2.GetRecipeInfo = function(...) info = info + 1 return orig(...) end
    T2.GetRecipeSchematic = function(...) schem = schem + 1 return origS(...) end
    game:fire("TRADE_SKILL_LIST_UPDATE")
    game:advance(3)
    T.eq(info, 0, "nothing changed: no recipe asked")
    game.prof.skill = 76
    game:fire("TRADE_SKILL_LIST_UPDATE")
    game:advance(3)
    T.eq(info, 1, "a skill-up rescans")
    T.eq(schem, 0, "what a recipe needs and makes is not asked again")
    T.eq(ns.db.char.professions["Leatherworking"].skill, 76)
    game:fire("NEW_RECIPE_LEARNED", 2152)
    game:fire("TRADE_SKILL_LIST_UPDATE")
    game:advance(3)
    T.eq(info, 2, "a learned recipe rescans")
    T2.GetRecipeInfo, T2.GetRecipeSchematic = orig, origS
    T.eq(#ns.Errors.list, 0)
  end)
end)

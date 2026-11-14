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
end)

-- Craft queue and shopping list (P5-03). Recipes and items are test data.
local T, mock = ...

T.describe("craft queue", function()
  T.it("shopping list subtracts own bags and bank, lists alts apart", function()
    local game = mock.new()
    game.prof = { name = "Leatherworking", skill = 75, max = 150, recipes = {
      [2149] = { name = "Boots", reagents = { [2318] = 2, [2320] = 1 } } } }
    game.items = { [2318] = { name = "Light Leather" }, [2320] = { name = "Coarse Thread" } }
    game.bags = { [0] = { 2318 } }
    game.counts = { [0] = { 3 } }
    local ns = game:loadAddon()
    game:login()
    game:fire("TRADE_SKILL_SHOW")
    game:advance(1)
    ns.db.global.inventory["Lumen-Forever"] = { bags = { [2318] = 4 }, bank = {}, mail = {} }
    local Q = ns.CraftQueue
    Q:Add("Leatherworking:2149", 5)
    local rows = Q:Shopping()
    local leather
    for _, r in ipairs(rows) do if r.itemID == 2318 then leather = r end end
    T.eq(leather.need, 10)
    T.eq(leather.have, 3)
    T.eq(leather.missing, 7)
    T.eq(leather.alts, 4)
    T.contains(Q:ShoppingText(), "Light Leather: need 10, have 3, BUY 7 (alts: Lumen 4)")
    T.eq(#ns.Errors.list, 0)
  end)
end)

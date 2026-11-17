-- Bag marks and item search (gap analysis 2026-11-17). Items are test data.
local T, mock = ...

local function start()
  local game = mock.new({ class = "HUNTER", level = 20 })
  game.items = {
    [101] = { name = "Old Bow", equipLoc = "INVTYPE_RANGED", class = 2, subclass = 2, sell = 5 },
    [102] = { name = "New Bow", equipLoc = "INVTYPE_RANGED", class = 2, subclass = 2, sell = 50 },
    [117] = { name = "Tough Jerky", quality = 1, sell = 1 },
    [999] = { name = "Broken Fang", quality = 0, sell = 3 },
  }
  game.itemStats = { [101] = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 5 }, [102] = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 9 } }
  game.worn = { [18] = 101 }
  game.bags = { [0] = { [1] = 102, [2] = 999, [3] = 117 } }
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.BagExtras
end

T.describe("bag extras", function()
  T.it("marks upgrades, junk and item level on a bag slot", function()
    local game, ns, M = start()
    local b = game.base.CreateFrame("Button", nil, game.base.UIParent)
    local marks = M:Decorate(b, 0, 1)
    T.ok(marks.upgrade)
    T.ok(b.otrMarks.arrow:IsShown())
    marks = M:Decorate(b, 0, 2)
    T.eq(marks.junk, true)
    T.ok(b.otrMarks.coin:IsShown())
    T.ok(not b.otrMarks.arrow:IsShown())
    marks = M:Decorate(b, 0, 3)
    T.eq(marks.upgrade, nil)
    T.eq(marks.junk, nil)
    M:Settings().junk = false
    T.eq(M:Decorate(b, 0, 2).junk, nil)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("finds an item by name on every character", function()
    local game, ns, M = start()
    ns.Inventory.db["Lumen-Test"] = { bags = { [117] = 4 }, bank = { [117] = 20 }, mail = {}, worn = {} }
    ns.Inventory:ScanBags()
    local list = M:Search("jerky")
    T.eq(#list, 1)
    T.ok(list[1].total >= 24)
    T.contains(M.WhereText(list[1].per), "Lumen: bags 4, bank 20")
    game:slash("where jerky")
    T.contains(game:chatText(), "Tough Jerky")
    ns.Hub:Toggle()
    M.query = "jerky"
    ns.Hub:ShowTab("alts")
    T.eq(#ns.Errors.list, 0)
  end)
end)

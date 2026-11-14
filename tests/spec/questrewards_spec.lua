-- Quest reward pick and bag upgrades (P6-04). Items are test data.
local T, mock = ...

local function session()
  local game = mock.new()
  game.items = {
    [101] = { name = "Old Bow", equipLoc = "INVTYPE_RANGED", class = 2, subclass = 2, sell = 5 },
    [102] = { name = "New Bow", equipLoc = "INVTYPE_RANGED", class = 2, subclass = 2, sell = 50 },
    [401] = { name = "Cloth Robe", equipLoc = "INVTYPE_CHEST", class = 4, subclass = 1, sell = 300 },
    [403] = { name = "Worn Vest", equipLoc = "INVTYPE_CHEST", class = 4, subclass = 2, sell = 1 },
    [402] = { name = "Plate Helm", equipLoc = "INVTYPE_HEAD", class = 4, subclass = 4, sell = 900 },
  }
  game.itemStats = { [101] = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 5 }, [102] = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 7 },
    [401] = { ITEM_MOD_INTELLECT_SHORT = 3 }, [402] = { ITEM_MOD_STRENGTH_SHORT = 5 }, [403] = { ITEM_MOD_AGILITY_SHORT = 6 } }
  game.worn = { [18] = 101, [5] = 403 }
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  return game, ns
end

T.describe("quest rewards", function()
  T.it("picks the usable upgrade over a pricier item", function()
    local game, ns = session()
    game.choices = { 401, 102, 402 }
    local i, why = ns.QuestRewards:Best()
    T.eq(i, 2)
    T.contains(why, "upgrade")
    game:fire("QUEST_COMPLETE")
    T.contains(ns.Toast.visible[1].title:GetText(), "Best reward: New Bow")
  end)

  T.it("with no upgrade it picks the best vendor value", function()
    local game, ns = session()
    game.choices = { 401, 402 }
    local i, why = ns.QuestRewards:Best()
    T.eq(i, 2)
    T.contains(why, "sells for")
  end)

  T.it("an upgrade in the bags toasts once", function()
    local game, ns = session()
    game.bags = { [0] = { 102 } }
    game:fire("BAG_UPDATE_DELAYED") game:advance(3)
    game:fire("BAG_UPDATE_DELAYED") game:advance(3)
    local n = 0
    for _, f in ipairs(ns.Toast.visible) do if f.title:GetText() == "Upgrade in your bags" then n = n + 1 end end
    T.eq(n, 1)
    T.eq(#ns.Errors.list, 0)
  end)
end)

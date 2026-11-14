-- Auction helper (P5-07). Prices are test data.
local T, mock = ...

local function session()
  local game = mock.new()
  game.items = { [2589] = { name = "Linen Cloth", sell = 13 }, [2996] = { name = "Bolt of Linen Cloth", sell = 25 } }
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.AuctionHelper
end

T.describe("auction helper", function()
  T.it("undercuts the market by the rule, never below the floor", function()
    local _, ns, A = session()
    ns.Prices:Record(2589, 100)
    local r = A:Suggest(2589)
    T.eq(r.price, 98)                -- 2% under 100c
    T.eq(r.floor, math.ceil(13 / 0.95))
    T.eq(#r.warnings, 0)
    ns.Prices:Record(2589, 10)       -- market crashes below vendor
    r = A:Suggest(2589)
    T.eq(r.price, r.floor)
    T.contains(table.concat(r.warnings, ";"), "below your floor")
  end)

  T.it("floor includes craft cost and the deposit; warns when deposit eats profit", function()
    local game, ns, A = session()
    ns.db.char.professions = { Tailoring = { recipes = { [1] = { name = "Bolt of Linen Cloth", reagents = { [2589] = 2 } } } } }
    ns.Prices:Record(2589, 100)
    ns.Prices:Record(2996, 205)
    game.deposit = 50
    local r = A:Suggest(2996)
    T.eq(r.floor, math.ceil((200 + 50) / 0.95))
    T.contains(table.concat(r.warnings, ";"), "deposit")
  end)

  T.it("lists own auctions priced above today's lowest; undercut setting", function()
    local game, ns, A = session()
    ns.Prices:Record(2589, 90)
    game.owned = { { itemKey = { itemID = 2589 }, buyoutAmount = 120, status = 0 } }
    local u = A:Undercut()
    T.eq(#u, 1)
    T.eq(u[1].name, "Linen Cloth")
    game:fire("AUCTION_HOUSE_SHOW")
    game:fire("OWNED_AUCTIONS_UPDATED")
    T.contains(ns.AuctionHelper.frame.text:GetText(), "Undercut")
    game:slash("undercut 5c")
    ns.Prices:Record(2589, 90)
    T.eq(A:Suggest(2589).price, 85)
    T.eq(#ns.Errors.list, 0)
  end)
end)

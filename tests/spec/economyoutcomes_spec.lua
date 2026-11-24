-- OI03-06: economy outcomes: realized flow, confirmed sales, transfers, estimates apart.
local T, mock = ...

local function session(prep)
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  game.money = 10000
  game.env.SendMail = function() end
  game.env.C_AuctionHouse = game.env.C_AuctionHouse or {}
  game.env.C_AuctionHouse.PostItem = function() end
  game.inbox = {}
  game.env.GetInboxInvoiceInfo = function(i)
    local m = game.inbox[i]
    if m and m.invoice then local v = m.invoice return "seller", v.item, "Buyer", v.bid, v.buyout, v.deposit, v.cut end
  end
  if prep then prep(game, ns) end
  ns.Modules:SetEnabled("Outcomes", true)
  ns.Outcomes.money = game.money
  return game, ns, ns.EconomyOutcomes
end
local function last(ns) local ev = ns.Outcomes:Store().events return ev[#ev] end
local function spend(game, n) game.money = game.money - n game:fire("PLAYER_MONEY") end
local function gain(game, n) game.money = game.money + n game:fire("PLAYER_MONEY") end

T.describe("economy outcomes (OI03-06)", function()
  T.it("mail from a sale invoice is a confirmed sale; from your own alt it is a transfer, not profit", function()
    local game, ns = session(function(_, ns) ns.db.raw.chars["Lumen-Forever"] = {} end)
    game.inbox = { { money = 900, sender = "Auction House", invoice = { item = "Linen Cloth", bid = 800, buyout = 1000, deposit = 50, cut = 50 } },
      { money = 5000, sender = "Lumen" } }
    game:fire("MAIL_SHOW")
    game:fire("MAIL_INBOX_UPDATE")
    game.env.TakeInboxMoney(1)
    game:fire("PLAYER_MONEY")
    T.eq(last(ns).context, "auction sale (confirmed)")
    game:advance(5)
    game.env.TakeInboxMoney(2)
    game:fire("PLAYER_MONEY")
    T.eq(last(ns).context, "transfer in")
    local E = ns.EconomyOutcomes
    local sum = E.Summary(ns.Outcomes:Store().events, E:Sales(ns.Outcomes:Store()))
    T.eq(sum.transfers, 5000)
    T.eq(sum.realizedNet, 900, "the transfer is not counted as profit")
    T.eq(sum.confirmedSales, 1) T.eq(sum.knownFees, 50)
  end)

  T.it("the same invoice seen on every mailbox update counts once; a missing cut is unknown, not zero", function()
    local game, ns, E = session()
    game.inbox = { { money = 900, invoice = { item = "Copper Ore", bid = 900, buyout = 900, deposit = 30 } } }
    for _ = 1, 3 do game:fire("MAIL_INBOX_UPDATE") end
    local sales = E:Sales(ns.Outcomes:Store())
    T.eq(#sales, 1)
    T.eq(sales[1].fee, nil) T.eq(sales[1].feeUnknown, true)
    T.eq(E.Summary({}, sales).salesWithUnknownFee, 1)
  end)

  T.it("auction house: money out right after posting is a deposit, otherwise a purchase", function()
    local game, ns = session()
    game:fire("AUCTION_HOUSE_SHOW")
    game.env.C_AuctionHouse.PostItem()
    spend(game, 40)
    T.eq(last(ns).context, "auction deposit")
    game:advance(10)
    spend(game, 700)
    T.eq(last(ns).context, "auction purchase")
  end)

  T.it("gold sent to your own alt is a transfer out; to someone else it is mail spend", function()
    local game, ns = session(function(_, ns) ns.db.raw.chars["Lumen-Forever"] = {} end)
    game:fire("MAIL_SHOW")
    game.env.SendMail("Lumen", "gold", "")
    spend(game, 1030)
    T.eq(last(ns).context, "transfer out")
    game:advance(10)
    game.env.SendMail("Stranger", "hi", "")
    spend(game, 30)
    T.eq(last(ns).context, "mail sent (gold or postage)")
  end)

  T.it("vendor, training and loot are told apart", function()
    local game, ns = session()
    game:fire("MERCHANT_SHOW") gain(game, 120)
    T.eq(last(ns).context, "vendor sale")
    spend(game, 60)
    T.eq(last(ns).context, "vendor spend")
    game:fire("MERCHANT_CLOSED") game:fire("TRAINER_SHOW") spend(game, 100)
    T.eq(last(ns).context, "training")
    game:fire("TRAINER_CLOSED") gain(game, 25)
    T.eq(last(ns).context, "loot and quests")
  end)

  T.it("disappeared auctions and loot estimates never count as sales or profit", function()
    local _, _, E = session()
    local sum = E.Summary({ { kind = "money_in", amount = 100, context = "vendor sale" } }, {}, { unverified = 3, estimatedLoot = 99999 })
    T.eq(sum.realizedNet, 100)
    T.eq(sum.confirmedSales, 0)
    T.eq(sum.unverifiedAuctions, 3)
    T.eq(sum.estimatedLoot, 99999) T.eq(sum.estimatedLootIsEstimate, true)
  end)

  T.it("the 201st sale archives the oldest", function()
    local game, ns, E = session()
    for i = 1, E.MAX_SALES + 1 do
      game.inbox = { { money = 1, invoice = { item = "Item " .. i, bid = i, buyout = i, deposit = 1, cut = 1 } } }
      game:fire("MAIL_INBOX_UPDATE")
    end
    T.eq(#E:Sales(ns.Outcomes:Store()), E.MAX_SALES)
    T.ok(#ns.Archive:Rows("confirmedSales") >= 1)
  end)
end)

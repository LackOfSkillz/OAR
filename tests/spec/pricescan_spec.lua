-- Full auction house scan: cheapest buyout per unit for every item, once per 15 minutes.
local T, mock = ...

T.describe("full price scan", function()
  T.it("records the cheapest per-unit buyout of every item and waits 15 minutes before the next", function()
    local game = mock.new({ now = 1794700000 })
    game.replicate = { { 765, 20, 400 }, { 765, 5, 50 }, { 2447, 1, 30 }, { 999, 1, 0 } }
    local ns = game:loadAddon()
    game:login()
    game:fire("AUCTION_HOUSE_SHOW")
    T.ok(ns.Prices:FullScan())
    game:fire("REPLICATE_ITEM_LIST_UPDATE")
    T.eq(ns.Prices:History(765), 10, "50c for 5 beats 400c for 20")
    T.eq(ns.Prices:History(2447), 30)
    T.eq(ns.Prices:History(999), nil, "no buyout, no price")
    T.contains(game:chatText(), "price scan done: 2 items priced")
    T.ok(not ns.Prices:FullScan(), "too soon")
    T.contains(game:chatText(), "15 minutes")
    game.now = game.now + 16 * 60
    T.ok(ns.Prices:FullScan())
    T.eq(#ns.Errors.list, 0)
  end)
end)

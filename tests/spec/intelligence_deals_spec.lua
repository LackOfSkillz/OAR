-- Deal Desk may read only user-initiated current AH results; never buys.
local T, mock = ...
local function session()
  local game = mock.new({ money = 100000, items = {
    [2504] = { name = "Test Sword", sell = 1000 },
  }})
  local ns = game:loadAddon()
  game:login()
  return game, ns
end
T.describe("intelligence 2.0 Deal Desk", function()
  T.it("is opt-in and rejects a closed auction house", function()
    local game, ns = session()
    local D = ns.DealDesk
    T.no(D.enabled)
    T.eq(D:ConsiderLot({itemID=2504},{now=game.now}), nil)
    ns.Modules:SetEnabled("DealDesk", true)
    T.eq(D:ConsiderLot({},{}), nil)
    T.eq(#D:Rows(), 0)
  end)
  T.it("keeps capped read-only reviewed lots and clears on AH close", function()
    local game, ns = session()
    local D = ns.DealDesk
    ns.Modules:SetEnabled("DealDesk", true)
    game:fire("AUCTION_HOUSE_SHOW")
    T.ok(D:Reserve(1))
    local now = game.now
    local lot = {itemID=2504, auctionID=55, quantity=2,
      buyoutCopper=300, observedAt=now, live=true, sellable=true, bound=false}
    local c = {vendorUnitCopper=1000,goldCopper=100000,reserveCopper=10000,now=now}
    local v = D:ConsiderLot(lot,c)
    T.ok(v)
    T.eq(v.profitCopper, 1700)
    T.no(v.executesAction)
    T.eq(#D:Rows(),1)
    D:ConsiderLot(lot,c)
    T.eq(#D:Rows(),1)
    D:Open()
    T.ok(D.window)
    T.eq(#ns.Errors.list,0)
    game:fire("AUCTION_HOUSE_CLOSED")
    T.eq(#D:Rows(),0)
    T.no(game.bought)
  end)
  T.it("stale and unaffordable lots are never actionable", function()
    local game, ns = session()
    local D = ns.DealDesk
    ns.Modules:SetEnabled("DealDesk", true)
    game:fire("AUCTION_HOUSE_SHOW")
    local now = game.now
    local lot = {itemID=2504, auctionID=56, quantity=1,
      buyoutCopper=300, observedAt=now-500, live=true, sellable=true,bound=false}
    local c={vendorUnitCopper=1000,goldCopper=100000,reserveCopper=0,now=now}
    T.eq(D:ConsiderLot(lot,c),nil)
    lot.observedAt=now
    c.goldCopper=200
    T.eq(D:ConsiderLot(lot,c),nil)
    T.eq(#D:Rows(),0)
  end)
end)

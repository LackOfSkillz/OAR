local T, mock = ...
local function economy()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  return ns.IntelEconomy
end
T.describe("intelligence 2.0 vendor arbitrage", function()
  T.it("uses stack buyout vs NPC unit price, no AH resale fee", function()
    local E = economy()
    local lot = {itemID=101, quantity=5, buyoutCopper=250, observedAt=1000,
      live=true, sellable=true, bound=false}
    local context = {vendorUnitCopper=100, goldCopper=2000, reserveCopper=500, now=1010}
    local d = E.VendorFloor(lot, context)
    T.eq(d.npcTotalCopper, 500)
    T.eq(d.profitCopper, 250)
    T.ok(d.purchaseManual)
    T.no(d.executesAction)
  end)
  T.it("suppresses cached, bound, stale, zero-value and unaffordable lots", function()
    local E = economy()
    local lot = {itemID=101, quantity=5, buyoutCopper=250, observedAt=1000,
      live=true, sellable=true, bound=false}
    local ctx = {vendorUnitCopper=100, goldCopper=2000, reserveCopper=500, now=1010}
    local function reject(k, value)
      local copy = {}
      for a,b in pairs(lot) do copy[a] = b end
      copy[k] = value
      T.eq(E.VendorFloor(copy, ctx), nil)
    end
    reject("live", false)
    reject("sellable", false)
    reject("bound", true)
    reject("quantity", 0)
    reject("quantity", -1)
    reject("buyoutCopper", 1000)
    reject("observedAt", 800)
    ctx.vendorUnitCopper = 0
    T.eq(E.VendorFloor(lot, ctx), nil)
    ctx.vendorUnitCopper, ctx.goldCopper = 100, 600
    T.eq(E.VendorFloor(lot, ctx), nil)
    T.no(E.HistoricalHint(101, 100, 2).actionable)
  end)

T.describe("intelligence 2.0 speculative economics", function()
  T.it("labels AH resale estimates as hypotheses and declines unknown fees", function()
    local E = economy()
    local sample = {itemID=51, quantity=3, totalCostCopper=300,
                    expectedUnitCopper=200}
    local h = E.ResaleHypothesis(sample)
    T.no(h.actionable)
    T.eq(h.possibleNetCopper, nil)
    T.eq(h.liquidity, "unknown")
    sample.feeCopper, sample.depositCopper = 25, 10
    h = E.ResaleHypothesis(sample)
    T.eq(h.expectedGrossCopper, 600)
    T.eq(h.possibleNetCopper, 265)
    T.no(h.actionable)
  end)
  T.it("only stores bounded explicitly confirmed outcomes and observed rates", function()
    local E = economy()
    local c = {}
    T.no(E.RecordOutcome(c, {kind="vendor",itemID=1,netCopper=100}))
    T.ok(E.RecordOutcome(c, {kind="vendor",itemID=1,netCopper=100,confirmed=true}))
    T.eq(#c.intelEconomyOutcomes, 1)
    T.eq(c.intelEconomyOutcomes[1].netCopper, 100)
    T.eq(E.GoldPerHour(100, 100, "estimated"), nil)
    T.eq(E.GoldPerHour(100, 100, "observed"), 3600)
    T.eq(E.GoldPerHour(100, 0, "observed"), nil)
  end)
end)

end)

-- Price history, graphs and the best time to list (Gary, 2026-11-24).
-- Items and prices are test data.
local T, mock = ...

local function session()
  local game = mock.new()
  game.items = { [2318] = { name = "Light Leather", sell = 15 }, [2589] = { name = "Linen Cloth", sell = 13 },
    [2592] = { name = "Wool Cloth", sell = 33 } }
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

-- local midnight on 2026-11-01 (a Sunday), so weekdays and hours follow the test machine's clock like WoW's date()
local T0 = os.time({ year = 2026, month = 11, day = 1, hour = 0, min = 0, sec = 0 })

-- 4 weeks, six checks a day; Tuesdays 20% dearer, 16-20 o'clock 10% dearer
local function fill(ns, id, weeks)
  local PH = ns.PriceHistory
  PH:Watch(id, "manual")
  for d = 0, weeks * 7 - 1 do
    for _, h in ipairs({ 2, 6, 10, 14, 18, 22 }) do
      local t = T0 + d * 86400 + h * 3600
      local tm = os.date("*t", t)
      local price = 1000
      if tm.wday == 3 then price = price * 1.2 end
      if tm.hour >= 16 and tm.hour < 20 then price = price * 1.1 end
      PH:Seen(id, math.floor(price), 40, t)
    end
  end
end

T.describe("price history", function()
  T.it("keeps hourly samples only for tracked items, the lowest of each hour", function()
    local game, ns = session()
    local PH = ns.PriceHistory
    game.now = T0 + 3600 * 5
    T.eq(PH:Seen(2318, 300, 10), false, "not tracked: no detail")
    PH:Watch(2318, "manual")
    T.ok(PH:Seen(2318, 300, 10))
    PH:Seen(2318, 250, 8)
    PH:Seen(2318, 280, 9)
    T.eq(#PH.store.items[2318], 1, "same hour: one row")
    T.eq(PH.store.items[2318][1][2], 250, "the lowest")
    T.eq(PH.store.items[2318][1][3], 8, "with the count at that price")
    game.now = game.now + 3600
    PH:Seen(2318, 260)
    T.eq(#PH.store.items[2318], 2)
    -- 121 days later the old rows are gone
    game.now = game.now + 121 * 86400
    PH:Seen(2318, 270)
    T.eq(#PH.store.items[2318], 1)
  end)

  T.it("tracks what you search and sell by itself, with the count for sale", function()
    local game, ns = session()
    game.now = T0
    game.commodityList = { [2592] = { { 120, 15 }, { 130, 25 } } }
    game:fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2592)
    T.ok(ns.PriceHistory:IsTracked(2592), "searched: tracked")
    local row = ns.PriceHistory.store.items[2592][1]
    T.eq(row[2], 120)
    T.eq(row[3], 40, "every one for sale")
    -- a browse still gives every item its 14-day daily low, but no hourly detail
    game.browse = { { itemKey = { itemID = 2589 }, minPrice = 9, totalQuantity = 200 } }
    game:fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
    T.ok(ns.Prices.db[2589], "daily low kept")
    T.eq(ns.PriceHistory.store.items[2589], nil, "no hourly detail for an untracked item")
    -- the graph uses the daily lows for untracked items too
    T.eq(#ns.PriceHistory:Daily(2589, 30), 1)
  end)

  T.it("never pushes out items you tracked by hand when the list is full", function()
    local _, ns = session()
    local PH = ns.PriceHistory
    PH.MAX_WATCH = 3
    PH:Watch(1, "manual") PH:Watch(2, "search") PH:Watch(3, "manual")
    T.ok(PH:Watch(4, "sell"))
    T.eq(PH.store.watch[2], nil, "the automatic one made room")
    T.ok(PH.store.watch[1] and PH.store.watch[3])
    PH.MAX_WATCH = 2
    PH:Unwatch(4)
    T.eq(PH:Watch(5, "sell"), false, "only hand-tracked items left: nothing pushed out")
    PH.MAX_WATCH = 300
  end)

  T.it("finds the best weekday and time of day to list", function()
    local game, ns = session()
    local PH = ns.PriceHistory
    fill(ns, 2318, 4)
    game.now = T0 + 28 * 86400
    local b = PH:BestTimes(2318)
    T.eq(b.samples, 168)
    T.ok(b.week.ready and b.hour.ready)
    T.eq(b.week.best.name, "Tuesday")
    T.eq(b.hour.best.name, "Evening")
    T.ok(b.week.best.rel > 1.1, "Tuesday about 15-20% over the usual")
    T.eq(b.week.best.qty, 40)
    local line = PH:Advice(2318)
    T.ok(line and line:find("Tuesday") and line:find("Evening"), line)
    T.eq(PH:Short(2318), "Tue evening")
    local rows = ns.TooltipLines:Lines("item", game.env.GameTooltip, { id = 2318 })
    local found
    for _, r in ipairs(rows) do if r[1] == "Best time to list" then found = r.right end end
    T.eq(found, "Tue evening")
  end)

  T.it("says it is still learning with few samples, and when nothing stands out", function()
    local game, ns = session()
    local PH = ns.PriceHistory
    PH:Watch(2589, "manual")
    for i = 0, 4 do PH:Seen(2589, 100, nil, T0 + i * 7200) end
    local line, why = PH:Advice(2589)
    T.eq(line, nil)
    T.ok(why:find("Still learning: 5 of 12"), why)
    -- a flat price for four weeks
    for d = 1, 28 do for _, h in ipairs({ 3, 9, 15, 21 }) do PH:Seen(2589, 100, nil, T0 + d * 86400 + h * 3600) end end
    line, why = PH:Advice(2589)
    T.eq(line, nil)
    T.ok(why:find("No time stands out"), why)
    game.now = T0
  end)

  T.it("summary: now, usual, range and a trend over two weeks", function()
    local game, ns = session()
    local PH = ns.PriceHistory
    PH:Watch(2318, "manual")
    for d = 0, 20 do PH:Seen(2318, d >= 14 and 1300 or 1000, 5, T0 + d * 86400 + 12 * 3600) end
    game.now = T0 + 20 * 86400 + 13 * 3600
    local s = PH:Summary(2318, 30)
    T.eq(s.now, 1300)
    T.eq(s.qty, 5)
    T.eq(s.low, 1000)
    T.eq(s.high, 1300)
    T.eq(s.trend, "up")
    T.eq(#PH:Daily(2318, 7), 7)
    local items, opts = PH:GraphItems(2318, 30)
    T.eq(#items, 21)
    T.eq(items[21].color, "good", "today stands out")
    T.ok(opts.floor < 1000 and opts.ceil == 1300)
  end)

  T.it("the Price history page lists, graphs and tracks an item", function()
    local game, ns = session()
    fill(ns, 2318, 4)
    game.now = T0 + 28 * 86400
    ns.Prices:Record(2589, 9) -- priced but untracked
    ns.Hub:Build():Show()
    ns.Hub:ShowTab("pricehistory")
    local p = ns.Hub.byId.pricehistory.panel
    T.ok(p, "page built")
    p:Refresh()
    T.eq(p.sel, 2318, "the tracked item is picked first")
    T.ok(p.graph.count >= 7, "a column per day")
    T.ok(p.advice:GetText():find("Tuesday"), p.advice:GetText())
    T.eq(p.slots[2].count, 7, "seven weekday bars")
    T.eq(p.track:GetText(), "Stop tracking")
    -- typing finds untracked priced items
    p.filter = "linen"
    p:Refresh()
    T.eq(p.list.items[1].id, 2589)
    T.eq(p.list.items[1].tracked, false)
    p.sel = 2589
    p:Refresh()
    T.eq(p.track:GetText(), "Track")
    T.ok(p.advice:GetText():find("press Track"))
    p.track:Click()
    T.ok(ns.PriceHistory.store.watch[2589], "tracked by hand")
    T.eq(ns.PriceHistory.store.watch[2589].why, "manual")
  end)
end)

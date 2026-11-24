-- OI01-14 + owner retention decision 2026-11-24: collected data that leaves a
-- capped working store goes to ns.Archive, never away. Items are test data.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  game.items = { [2318] = { name = "Light Leather", sell = 15 } }
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("archive instead of delete", function()
  T.it("Put, Shift and Rows keep rows unchanged under key@character, oldest first", function()
    local _, ns = session()
    local list = { { a = 1 }, { a = 2 }, { a = 3 } }
    ns.Archive:Shift("demo", list)
    ns.Archive:Put("demo", { a = 9 })
    local rows = ns.Archive:Rows("demo")
    T.eq(#rows, 2)
    T.eq(rows[1].a, 1)
    T.eq(rows[2].a, 9)
    T.eq(#list, 2)
    T.ok(ns.db.global.archive["demo@" .. ns.db.key])
    T.eq(ns.Archive:Count(), 2)
  end)

  T.it("survives a damaged saved archive (bad type) without losing new rows", function()
    local _, ns = session()
    ns.db.global.archive = "junk"
    ns.Archive:Put("demo", { a = 1 })
    T.eq(#ns.Archive:Rows("demo"), 1)
    ns.db.global.archive["demo@" .. ns.db.key] = 7
    ns.Archive:Put("demo", { a = 2 })
    T.eq(#ns.Archive:Rows("demo"), 1, "a damaged list is replaced, the new row kept")
  end)

  T.it("auction daily lows older than 14 days move to the archive", function()
    local game, ns = session()
    game.now = 86400 * 20000
    ns.Prices:Record(2318, 500)
    game.now = game.now + 86400 * 20
    ns.Prices:Record(2318, 450)
    T.eq(#ns.Prices.db[2318], 1, "the working store keeps 14 days")
    local rows = ns.Archive:Rows("prices")
    T.eq(#rows, 1)
    T.eq(rows[1].id, 2318)
    T.eq(rows[1].row[2], 500, "the old low is kept as it was")
  end)

  T.it("price history rows past the cap or age, and untracked items, go to the archive", function()
    local game, ns = session()
    local PH = ns.PriceHistory
    PH:Watch(2318, "manual")
    local t0 = 86400 * 20000
    PH:Seen(2318, 100, 5, t0)
    PH:Seen(2318, 110, 5, t0 + 121 * 86400)
    T.eq(#PH.store.items[2318], 1)
    T.eq(#ns.Archive:Rows("priceHistory"), 1)
    T.eq(ns.Archive:Rows("priceHistory")[1].row[2], 100)
    PH:Unwatch(2318)
    game.now = t0 + 200 * 86400
    PH:Prune(game.now)
    T.eq(PH.store.items[2318], nil, "out of the working store")
    local items = ns.Archive:Rows("priceHistoryItems")
    T.eq(#items, 1)
    T.eq(items[1].id, 2318)
    T.eq(items[1].rows[1][2], 110, "the whole history is kept")
  end)

  T.it("rare sightings beyond the working cap are archived, not dropped", function()
    local _, ns = session()
    local S = ns.Sightings
    local cap = S.CAP
    S.CAP = 2
    for i = 1, 4 do S:Record(9001, { t = i, mapID = 1412, x = 0.1, y = 0.2 }) end
    S.CAP = cap
    T.ok(#ns.Archive:Rows("sightings") >= 1, "older sightings archived")
  end)

  T.it("logs keep their caps (they are not collected data)", function()
    local _, ns = session()
    for i = 1, 30 do ns.session = "s" .. i ns.DB:StartSession(ns.session) end
    T.eq(#ns.db.global.sessions, ns.DB.MAX_SESSIONS)
    T.eq(#ns.Archive:Rows("sessions"), 0)
  end)
end)

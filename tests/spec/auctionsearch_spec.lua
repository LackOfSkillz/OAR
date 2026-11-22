-- Free auction searches and shopping lists (Gary, 2026-11-22: match
-- Auctionator): plain extras in the search, recent searches, lists you can
-- search in one go, import and export.
local T, mock = ...

local function session()
  local game = mock.new({ level = 20 })
  game.items = {
    [2589] = { name = "Linen Cloth", quality = 1, reqLevel = 0 },
    [2592] = { name = "Wool Cloth", quality = 1, reqLevel = 0 },
    [7001] = { name = "Bloody Bracers", quality = 2, reqLevel = 15 },
  }
  game.commodities = { [2589] = true, [2592] = true }
  game.ahListings = {
    [2589] = { name = "Linen Cloth", minPrice = 90, qty = 300 },
    [2592] = { name = "Wool Cloth", minPrice = 400, qty = 80 },
    [7001] = { name = "Bloody Bracers", minPrice = 25000, qty = 1 },
  }
  local ns = game:loadAddon()
  game:login()
  game:fire("AUCTION_HOUSE_SHOW")
  return game, ns
end

local function finish(game, ns)
  local guard = 0
  while ns.AuctionSearch.queue and guard < 30 do guard = guard + 1 game:fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED") end
end

T.describe("auction search", function()
  T.it("understands exact names, level, price, quality, usable and how many", function()
    local _, ns = session()
    local P = ns.AuctionSearch.Parse
    local q = P('"Linen Cloth" x20 under 1s')
    T.eq(q.text, "Linen Cloth")
    T.ok(q.exact)
    T.eq(q.qty, 20)
    T.eq(q.maxPrice, 100)
    q = P("bracers lvl 10-20 green+ usable")
    T.eq(q.text, "bracers")
    T.eq(q.minLevel, 10)
    T.eq(q.maxLevel, 20)
    T.eq(q.quality, 2)
    T.ok(q.orBetter)
    T.ok(q.usable)
    q = P("Green Dye")
    T.eq(q.text, "Green Dye", "a plain colour word stays part of the name")
    T.eq(q.quality, nil)
    q = P('"Wool Cloth";0;0;0;0;0;0;0;0;0;;;;')
    T.eq(q.text, "Wool Cloth", "an Auctionator term: the item name")
  end)

  T.it("finds items, drops what costs more than 'under', and Buy never pays more", function()
    local game, ns = session()
    local S = ns.AuctionSearch
    S:Run({ '"Linen Cloth" x20 under 1s' }, "search")
    finish(game, ns)
    local r = S:Results()
    T.eq(#r, 1)
    T.eq(r[1].itemID, 2589)
    T.ok(r[1].commodity)
    T.eq(r[1].action[1].qty, 20)
    T.eq(r[1].action[1].maxUnit, 100)
    T.eq(ns.db.global.ahSearchHistory[1], '"Linen Cloth" x20 under 1s', "kept as a recent search")
    S:Run({ '"Wool Cloth" under 1s' }, "search")
    finish(game, ns)
    T.eq(#S:Results(), 0, "wool costs 4s: left out")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a shopping list searches every term in one go", function()
    local game, ns = session()
    local S = ns.AuctionSearch
    local l = S:NewList("Tailoring")
    S:AddTerm(l, '"Linen Cloth"')
    S:AddTerm(l, '"Wool Cloth"')
    T.ok(not S:AddTerm(l, '"wool cloth"'), "no doubles")
    S:Run(l.terms, "lists")
    finish(game, ns)
    local ids = {}
    for _, r in ipairs(S:Results()) do ids[r.itemID] = true end
    T.ok(ids[2589] and ids[2592])
    T.eq(#game.queries, 2, "one search per term")
  end)

  T.it("imports Auctionator and TSM lists and exports a list as text", function()
    local _, ns = session()
    local S = ns.AuctionSearch
    local lists, terms = S:Import('Cloth^"Linen Cloth";0;0;0;0;0;0;0;0;0;;;;^Wool Cloth\ni:2589,i:7001,i:99999')
    T.eq(lists, 2)
    T.eq(terms, 5)
    local cloth = S:List("Cloth")
    T.eq(cloth.terms[1], '"Linen Cloth"')
    T.eq(cloth.terms[2], "Wool Cloth")
    local imp = S:List("Imported")
    T.eq(imp.terms[1], '"Linen Cloth"')
    T.eq(imp.terms[3], "#99999", "an item not loaded yet keeps its id")
    T.eq(S.Export(cloth), 'Cloth^"Linen Cloth"^Wool Cloth')
    local again = S:Import(S.Export(cloth))
    T.eq(again, 1, "an export imports back")
  end)

  T.it("the shopping window shows Search and Shopping lists with their rows", function()
    local game, ns = session()
    local G = ns.GearShop
    G:Pick("search")
    T.ok(ns.AuctionSearch.bars.search:IsShown(), "the search box row")
    ns.AuctionSearch:Run({ "Linen Cloth" }, "search")
    finish(game, ns)
    G:Refresh()
    T.ok(G.frame.rows[1]:IsShown())
    T.eq(G.frame.rows[1].buy.label:GetText(), "Buy")
    local l = ns.AuctionSearch:NewList("Mats")
    ns.AuctionSearch:AddTerm(l, "Wool Cloth")
    G:Pick("lists")
    T.ok(not ns.AuctionSearch.bars.search:IsShown(), "the search row hides on another view")
    T.eq(G.frame.rows[1].buy.label:GetText(), "Search")
    T.eq(#ns.Errors.list, 0)
  end)
end)

-- Gear upgrades at the auction house: best upgrade per slot, ticked items
-- bought one click at a time with the price on the button.
local T, mock = ...

local function session()
  local game = mock.new({ level = 15 })
  game.items = {
    [101] = { name = "Old Bow", equipLoc = "INVTYPE_RANGED", class = 2, subclass = 2 },
    [301] = { name = "Worn Vest", equipLoc = "INVTYPE_CHEST", class = 4, subclass = 2 },
    [401] = { name = "Fine Vest", equipLoc = "INVTYPE_CHEST", class = 4, subclass = 2 },
    [402] = { name = "Okay Vest", equipLoc = "INVTYPE_CHEST", class = 4, subclass = 2 },
    [403] = { name = "Plate Vest", equipLoc = "INVTYPE_CHEST", class = 4, subclass = 4 },
    [501] = { name = "Leather Cap", equipLoc = "INVTYPE_HEAD", class = 4, subclass = 2 },
  }
  game.itemStats = {
    [101] = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 5 },
    [301] = { ITEM_MOD_AGILITY_SHORT = 2 },
    [401] = { ITEM_MOD_AGILITY_SHORT = 6 },
    [402] = { ITEM_MOD_AGILITY_SHORT = 4 },
    [403] = { ITEM_MOD_STRENGTH_SHORT = 20 },
    [501] = { ITEM_MOD_AGILITY_SHORT = 3 },
  }
  game.worn = { [18] = 101, [5] = 301 }
  game.ahListings = {
    [401] = { name = "Fine Vest", minPrice = 5000, class = 4, invType = 5 },
    [402] = { name = "Okay Vest", minPrice = 1000, class = 4, invType = 5 },
    [403] = { name = "Plate Vest", minPrice = 500, class = 4, invType = 5 },
    [501] = { name = "Leather Cap", minPrice = 800, class = 4, invType = 1 },
  }
  game.ahAuctions = { [401] = { { 9001, 5200 }, { 9002, 5000 } }, [501] = { { 9003, 800 } } }
  local ns = game:loadAddon()
  game:login()
  game:fire("AUCTION_HOUSE_SHOW")
  ns.GearShop:Start()
  local guard = 0
  while ns.GearShop.queue and guard < 30 do guard = guard + 1 game:fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED") end
  return game, ns
end

T.describe("gear shop", function()
  T.it("searches every slot and keeps the best usable upgrade per slot", function()
    local game, ns = session()
    T.ok(#game.queries >= 16, "one search per armor slot plus weapons")
    local best = ns.GearShop:Best()
    local by = {}
    for _, b in ipairs(best) do by[b.slotName] = b end
    T.eq(by.chest and by.chest.itemID, 401, "the bigger upgrade, not the cheaper one")
    T.eq(by.head and by.head.itemID, 501, "fills the empty head slot")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("buys ticked items one click at a time: look up, then confirm with the price", function()
    local game, ns = session()
    local G = ns.GearShop
    G.picked = { [401] = true, [501] = true }
    -- slot order: head first, then chest
    G:BuyClick() -- look up the cap
    game:fire("ITEM_SEARCH_RESULTS_UPDATED")
    T.contains(G.frame.buy.label:GetText(), "Confirm: buy Leather Cap for 8s")
    G:BuyClick()
    T.eq(game.bought[1].id, 9003)
    G:BuyClick() -- look up the vest
    game:fire("ITEM_SEARCH_RESULTS_UPDATED")
    T.contains(G.frame.buy.label:GetText(), "Confirm: buy Fine Vest for 50s")
    G:BuyClick() -- the cheapest of its two listings
    T.eq(game.bought[2].id, 9002)
    T.eq(game.bought[2].price, 5000)
    T.eq(G.buying, nil, "done")
    T.eq(#ns.Errors.list, 0)
  end)
end)

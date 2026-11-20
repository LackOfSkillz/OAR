-- Gear upgrades at the auction house: weapons (top 10) and armor (best per
-- slot), only what this class wears and what the gold covers; Buy goes
-- through the confirm bar (AHBuy), one confirmed click per purchase.
local T, mock = ...

local function session(money)
  local game = mock.new({ level = 15 })
  game.money = money or 100000
  game.items = {
    [101] = { name = "Old Bow", equipLoc = "INVTYPE_RANGED", class = 2, subclass = 2 },
    [301] = { name = "Worn Vest", equipLoc = "INVTYPE_CHEST", class = 4, subclass = 2 },
    [401] = { name = "Fine Vest", equipLoc = "INVTYPE_CHEST", class = 4, subclass = 2 },
    [402] = { name = "Okay Vest", equipLoc = "INVTYPE_CHEST", class = 4, subclass = 2 },
    [403] = { name = "Silk Robe", equipLoc = "INVTYPE_CHEST", class = 4, subclass = 1 },
    [404] = { name = "Golden Vest", equipLoc = "INVTYPE_CHEST", class = 4, subclass = 2 },
    [501] = { name = "Leather Cap", equipLoc = "INVTYPE_HEAD", class = 4, subclass = 2 },
    [601] = { name = "Great Bow", equipLoc = "INVTYPE_RANGED", class = 2, subclass = 2 },
    [602] = { name = "Holy Wand", equipLoc = "INVTYPE_RANGEDRIGHT", class = 2, subclass = 19 },
  }
  game.itemStats = {
    [101] = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 5 },
    [301] = { ITEM_MOD_AGILITY_SHORT = 2 },
    [401] = { ITEM_MOD_AGILITY_SHORT = 6 },
    [402] = { ITEM_MOD_AGILITY_SHORT = 4 },
    [403] = { ITEM_MOD_AGILITY_SHORT = 30 },
    [404] = { ITEM_MOD_AGILITY_SHORT = 40 },
    [501] = { ITEM_MOD_AGILITY_SHORT = 3 },
    [601] = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 9 },
    [602] = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 20 },
  }
  game.worn = { [18] = 101, [5] = 301 }
  game.ahListings = {
    [401] = { name = "Fine Vest", minPrice = 5000, class = 4, invType = 5 },
    [402] = { name = "Okay Vest", minPrice = 1000, class = 4, invType = 5 },
    [403] = { name = "Silk Robe", minPrice = 500, class = 4, invType = 5 },
    [404] = { name = "Golden Vest", minPrice = 250000, class = 4, invType = 5 },
    [501] = { name = "Leather Cap", minPrice = 800, class = 4, invType = 1 },
    [601] = { name = "Great Bow", minPrice = 3000, class = 2 },
    [602] = { name = "Holy Wand", minPrice = 200, class = 2 },
  }
  game.ahAuctions = { [401] = { { 9001, 5200 }, { 9002, 5000 } }, [501] = { { 9003, 800 } }, [601] = { { 9004, 3000 } } }
  local ns = game:loadAddon()
  game:login()
  game:fire("AUCTION_HOUSE_SHOW")
  return game, ns
end

local function search(game, ns, mode)
  ns.GearShop:Start(mode)
  local guard = 0
  while ns.GearShop.queue and guard < 30 do guard = guard + 1 game:fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED") end
  local by = {}
  for _, b in ipairs((ns.GearShop:Results())) do by[b.slotName] = by[b.slotName] or b by[b.itemID] = b end
  return by
end

T.describe("gear shop", function()
  T.it("armor: the best affordable piece of the class's own armor type per slot", function()
    local game, ns = session(100000) -- 10 gold
    local by = search(game, ns, "armor")
    T.eq(by.chest and by.chest.itemID, 401, "Fine Vest: best leather the gold covers")
    T.eq(by[403], nil, "no cloth for a hunter")
    T.eq(by[404], nil, "25 gold is more than 10 gold")
    T.eq(by.head and by.head.itemID, 501, "fills the empty head slot")
    local _, skipped = ns.GearShop:Results()
    T.eq(skipped, 1)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("weapons: only weapon types the class uses", function()
    local game, ns = session()
    local by = search(game, ns, "weapons")
    T.ok(by[601], "a bow for a hunter")
    T.eq(by[602], nil, "no wand for a hunter")
  end)

  T.it("Buy looks up the cheapest listing; the confirm click buys it", function()
    local game, ns = session()
    search(game, ns, "armor")
    local row
    for _, r in ipairs(ns.GearShop.frame.rows) do if r.item and r.item.itemID == 401 then row = r end end
    T.ok(row, "Fine Vest row")
    ns.AHBuy:Add({ name = row.item.name, itemKey = row.item.itemKey })
    game:fire("ITEM_SEARCH_RESULTS_UPDATED")
    T.contains(ns.AHBuy.frame.text:GetText(), "Fine Vest: 50s")
    ns.AHBuy:Confirm()
    T.eq(game.bought[1].id, 9002)
    T.eq(game.bought[1].price, 5000)
    T.eq(ns.AHBuy.current, nil)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("never buys past the gold carried", function()
    local game, ns = session(2000)
    ns.AHBuy:Add({ name = "Fine Vest", itemKey = { itemID = 401 } })
    game:fire("ITEM_SEARCH_RESULTS_UPDATED")
    ns.AHBuy:Confirm()
    T.eq(game.bought, nil)
    T.contains(game:chatText(), "more than you carry")
  end)

  T.it("stackable training goods: price quote for the amount, then confirm", function()
    local game, ns = session()
    ns.AHBuy:Add({ name = "Silverleaf", itemID = 765, qty = 20, commodity = true })
    T.eq(game.commodityStart.qty, 20)
    game:fire("COMMODITY_PRICE_UPDATED", 10, 200)
    T.contains(ns.AHBuy.frame.text:GetText(), "Silverleaf x20: 2s")
    ns.AHBuy:Confirm()
    T.eq(game.bought[1].commodity, 765)
    T.eq(game.bought[1].qty, 20)
  end)
end)

T.describe("gear shop weapon skills", function()
  T.it("a weapon type the class can use but this character hasn't learned is marked, after usable ones", function()
    local game = mock.new({ level = 15 })
    game.money = 100000
    game.knownSpells = { [264] = true } -- Bows only
    game.items = {
      [101] = { name = "Old Bow", equipLoc = "INVTYPE_RANGED", class = 2, subclass = 2 },
      [601] = { name = "Great Bow", equipLoc = "INVTYPE_RANGED", class = 2, subclass = 2 },
      [701] = { name = "Prospector Axe", equipLoc = "INVTYPE_WEAPON", class = 2, subclass = 0 },
      [702] = { name = "Iron Knuckles", equipLoc = "INVTYPE_WEAPON", class = 2, subclass = 13 },
    }
    game.itemStats = { [101] = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 5 }, [601] = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 9 },
      [701] = { ITEM_MOD_AGILITY_SHORT = 20 }, [702] = { ITEM_MOD_AGILITY_SHORT = 20 } }
    game.worn = { [18] = 101 }
    game.ahListings = { [601] = { name = "Great Bow", minPrice = 3000, class = 2 },
      [701] = { name = "Prospector Axe", minPrice = 5000, class = 2 }, [702] = { name = "Iron Knuckles", minPrice = 100, class = 2 } }
    local ns = game:loadAddon()
    game:login()
    game:fire("AUCTION_HOUSE_SHOW")
    ns.GearShop:Start("weapons")
    game:fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
    local list = ns.GearShop:Results()
    T.eq(list[1].itemID, 601, "the bow you can use comes first")
    T.eq(list[2].itemID, 701)
    T.eq(list[2].learn, "learn Axes")
    for _, b in ipairs(list) do T.ok(b.itemID ~= 702, "hunters can't use fist weapons") end
    T.contains(ns.GearShop.Gain(list[2]), "learn Axes first")
  end)
end)

T.describe("class weapon rules", function()
  T.it("each class's usable weapon types match Classic plus Forever's changes", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    local W = ns.GearScore.WEAPON_TYPES
    -- Forever: rogues learn one-handed axes, druids polearms
    T.ok(W.ROGUE[0] and W.DRUID[6])
    -- hunters: no fist weapons or wands; bows, guns, crossbows, thrown, axes yes
    T.ok(not W.HUNTER[13] and not W.HUNTER[19])
    T.ok(W.HUNTER[0] and W.HUNTER[2] and W.HUNTER[3] and W.HUNTER[16] and W.HUNTER[18])
    -- casters
    for _, cls in ipairs({ "PRIEST", "MAGE", "WARLOCK" }) do T.ok(W[cls][19] and W[cls][15] and W[cls][10], cls .. " wand, dagger, staff") end
    T.ok(not W.PRIEST[7] and W.MAGE[7] and W.WARLOCK[7], "priests no swords; mages and warlocks one-handed swords")
    T.ok(not W.PALADIN[15] and not W.PALADIN[2], "paladins no daggers or bows")
    T.ok(not W.SHAMAN[7] and W.SHAMAN[0] and W.SHAMAN[13], "shamans axes and fists, no swords")
    T.ok(not W.WARRIOR[19], "warriors no wands")
    -- armor types: heaviest each class wears, mail/plate from 40
    local A = ns.GearScore.ArmorType
    T.eq(A("PRIEST", 60), 1) T.eq(A("ROGUE", 60), 2) T.eq(A("DRUID", 60), 2)
    T.eq(A("HUNTER", 39), 2) T.eq(A("HUNTER", 40), 3) T.eq(A("SHAMAN", 40), 3)
    T.eq(A("WARRIOR", 39), 3) T.eq(A("PALADIN", 40), 4)
  end)
end)

T.describe("gear shop bags", function()
  local function bagSession(opts)
    local game = mock.new({ level = 15 })
    game.money = opts.money or 100000
    game.items = {
      [801] = { name = "Small Pouch", class = 1, subclass = 0 },
      [802] = { name = "Linen Bag", class = 1, subclass = 0 },
      [803] = { name = "Big Sack", class = 1, subclass = 0 },
      [804] = { name = "Dear Pack", class = 1, subclass = 0 },
      [805] = { name = "Herb Pouch", class = 1, subclass = 2 },
      [806] = { name = "Soul Pouch", class = 1, subclass = 1 },
      [807] = { name = "Light Quiver", class = 11, subclass = 2 },
      [808] = { name = "Big Quiver", class = 11, subclass = 2, reqLevel = 40 },
    }
    game.itemTips = { [801] = { "Small Pouch", "6 Slot Bag" }, [802] = { "Linen Bag", "10 Slot Bag" },
      [803] = { "Big Sack", "14 Slot Bag" }, [804] = { "Dear Pack", "16 Slot Bag" }, [805] = { "Herb Pouch", "12 Slot Herb Bag" },
      [806] = { "Soul Pouch", "20 Slot Soul Bag" }, [807] = { "Light Quiver", "12 Slot Quiver" }, [808] = { "Big Quiver", "18 Slot Quiver" } }
    game.ahListings = {}
    for id, it in pairs(game.items) do game.ahListings[id] = { name = it.name, minPrice = opts.prices and opts.prices[id] or 1000, class = it.class } end
    -- carried: 10, 8, 8 and a 6-slot quiver (hunter)
    game.bagSize = { [1] = 10, [2] = 8, [3] = 8, [4] = 6 }
    game.bagFamily = { [4] = 1 }
    local ns = game:loadAddon()
    game:login()
    if opts.herbalist then ns.db.char.professions = { Herbalism = { skill = 30, max = 75 } } end
    game:fire("AUCTION_HOUSE_SHOW")
    ns.GearShop:Start("bags")
    local guard = 0
    while ns.GearShop.queue and guard < 5 do guard = guard + 1 game:fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED") end
    return game, ns
  end

  T.it("bags bigger than your smallest, most slots first; hunters get a quiver; no soul bags", function()
    local game, ns = bagSession({ prices = { [804] = 500000 } })
    T.eq(#game.queries, 2, "bags and quivers")
    local list, skipped = ns.GearShop:Results()
    T.eq(list[1].itemID, 803, "14 slots: +6 over the 8-slot bag")
    T.eq(list[1].gain, 6)
    T.eq(list[2].itemID, 802)
    T.eq(skipped, 1, "the 16-slot pack is past the gold")
    local ids = {}
    for _, b in ipairs(list) do ids[b.itemID] = b end
    T.eq(ids[801], nil, "6 slots is smaller than what you carry")
    T.eq(ids[806], nil, "soul bags are for warlocks")
    T.eq(ids[805], nil, "herb bags only for herbalists")
    T.eq(ids[808], nil, "level 40 quiver is too high")
    T.eq(ids[807].gain, 6, "12-slot quiver over the 6-slot one")
    T.contains(ns.GearShop.BagLine(list[1]), "replaces your 8-slot bag")
    T.contains(ns.GearShop.Gain(list[1]), "+6 slots")
    ns.GearShop:Refresh()
    T.contains(ns.GearShop.frame.rows[1].text:GetText(), "Bag: Big Sack")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a herbalist also sees herb bags, after the general ones", function()
    local _, ns = bagSession({ herbalist = true })
    local list = ns.GearShop:Results()
    T.eq(list[#list].itemID, 805)
    T.contains(ns.GearShop.BagLine(list[#list]), "herb only")
  end)
end)

T.describe("buying waits for the game's answer (2026-11-20)", function()
  T.it("the next lookup waits until the purchase is answered; refusals and the game's red text are logged", function()
    local game, ns = session()
    game:fire("AUCTION_HOUSE_SHOW")
    local A = ns.AHBuy
    A:Add({ name = "Silverleaf", itemID = 765, qty = 20, commodity = true })
    A:Add({ name = "Peacebloom", itemID = 2447, qty = 5, commodity = true })
    game:fire("COMMODITY_PRICE_UPDATED", 10, 200)
    A:Confirm()
    T.ok(A.pending, "waiting for the answer")
    T.eq(game.commodityStart.id, 765, "Peacebloom not started yet")
    T.eq(game.commodityStart.qty, 20)
    T.contains(A.frame.sub:GetText(), "waiting for the auction house")
    A:Confirm()
    T.eq(#game.bought, 1, "a second click while waiting buys nothing")
    game:fire("UI_ERROR_MESSAGE", 1, "Item not found")
    game:fire("COMMODITY_PURCHASE_SUCCEEDED")
    T.eq(A.pending, nil)
    T.eq(game.commodityStart.qty, 5, "now Peacebloom is looked up")
    game:fire("COMMODITY_PRICE_UPDATED", 20, 100)
    A:Confirm()
    game:fire("AUCTION_HOUSE_SHOW_ERROR", 3)
    T.ok(A.pending, "an error alone doesn't settle it")
    game:advance(6)
    T.eq(A.results.bought, 1)
    T.eq(A.results.failed, 1)
    local log = {}
    for _, l in ipairs(ns.Log:Tail(30)) do log[#log + 1] = ns.Log:FormatLine(l) end
    log = table.concat(log, "\n")
    T.contains(log, "bought Silverleaf x20")
    T.contains(log, "game said while buying: Item not found")
    T.contains(log, "purchase Peacebloom x5: auction house error 3")
    T.contains(game:chatText(), "Peacebloom x5 wasn't bought")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("no answer at all: after a few seconds it moves on and says so in the log", function()
    local game, ns = session()
    game:fire("AUCTION_HOUSE_SHOW")
    local A = ns.AHBuy
    A:Add({ name = "Silverleaf", itemID = 765, qty = 20, commodity = true })
    game:fire("COMMODITY_PRICE_UPDATED", 10, 200)
    A:Confirm()
    game:advance(6)
    T.eq(A.pending, nil)
    T.eq(A.results.failed, 1)
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("an auction error but the gold was taken (2026-11-20, Heavy Shortbow)", function()
  T.it("counts as bought, and the log says the game showed an error", function()
    local game, ns = session()
    game:fire("AUCTION_HOUSE_SHOW")
    local A = ns.AHBuy
    A:Add({ name = "Silverleaf", itemID = 765, qty = 20, commodity = true })
    game:fire("COMMODITY_PRICE_UPDATED", 10, 200)
    A:Confirm()
    game:fire("AUCTION_HOUSE_SHOW_ERROR", 10)
    game.money = game.money - 200
    game:fire("PLAYER_MONEY")
    T.eq(A.pending, nil)
    T.eq(A.results.bought, 1)
    T.eq(A.results.failed, 0)
    local log = {}
    for _, l in ipairs(ns.Log:Tail(20)) do log[#log + 1] = ns.Log:FormatLine(l) end
    T.contains(table.concat(log, " | "), "the gold was taken, so it went through")
    T.ok(not game:chatText():find("wasn't bought", 1, true), "no wrong chat line")
  end)
end)

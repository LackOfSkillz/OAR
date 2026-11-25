-- OI05-12..16: supply graph, reservations, Treasurer budget, realized economics, profession costs.
local T, mock = ...

local function session()
  local game = mock.new({ level = 20, class = "HUNTER" })
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

-- 1 Bolt of Cloth (100) = 2 Thread (200) ; Thread = 1 Fibre (300); Shirt (400) = 2 Bolts + 1 Dye (500)
local MAKES = {
  [100] = { key = "Tailoring:1", name = "Bolt", makes = 1, makesKnown = true, reagents = { [200] = 2 } },
  [200] = { key = "Tailoring:2", name = "Thread", makes = 4, makesKnown = true, reagents = { [300] = 1 } },
  [400] = { key = "Tailoring:3", name = "Shirt", makes = 1, makesKnown = true, reagents = { [100] = 2, [500] = 1 } },
}

T.describe("supply graph (OI05-12)", function()
  T.it("expands intermediates, rounds crafts up, keeps the extra for later needs, buys the rest", function()
    local _, ns = session()
    local r = ns.Supply.Expand({ { goal = "shirt", itemID = 400, count = 1 } }, MAKES, {}, {})
    -- 2 bolts need 4 thread = one Thread craft (makes 4) = 1 fibre; plus 1 dye
    T.eq(r.shopping[300], 1) T.eq(r.shopping[500], 1)
    local seq = {}
    for i, s in ipairs(r.sequence) do seq[s.name] = i end
    T.ok(seq.Thread < seq.Bolt and seq.Bolt < seq.Shirt, "intermediates first")
    T.eq(r.sequence[seq.Thread].crafts, 1)
    -- a second goal uses no more thread crafts: none left over, since all 4 were used
    local two = ns.Supply.Expand({ { goal = "a", itemID = 200, count = 1 }, { goal = "b", itemID = 200, count = 2 } }, MAKES, {}, {})
    local crafts = 0
    for _, s in ipairs(two.sequence) do crafts = crafts + s.crafts end
    T.eq(crafts, 1, "the extra 3 thread from one craft cover the second goal")
  end)

  T.it("detects a recipe cycle and doesn't loop", function()
    local _, ns = session()
    local loop = { [1] = { key = "a", name = "A", makes = 1, makesKnown = true, reagents = { [2] = 1 } },
      [2] = { key = "b", name = "B", makes = 1, makesKnown = true, reagents = { [1] = 1 } } }
    local r = ns.Supply.Expand({ { goal = "x", itemID = 1, count = 1 } }, loop, {}, {})
    T.eq(#r.cycles, 1) T.eq(r.cycles[1].itemID, 1)
  end)

  T.it("never double allocates; other realm or faction excluded; stale alts flagged; soulbound named", function()
    local _, ns = session()
    local now = 10 * 86400
    local stock = { [500] = { mine = 1, alts = {
      { char = "Alt-Here", count = 2, at = 0, realm = "Here", faction = "Horde" },
      { char = "Far-There", count = 9, realm = "There", faction = "Horde" },
      { char = "Ally-Here", count = 9, realm = "Here", faction = "Alliance" } } } }
    local r = ns.Supply.Expand({ { goal = "a", itemID = 500, count = 2 }, { goal = "b", itemID = 500, count = 3 } }, {}, stock,
      { realm = "Here", faction = "Horde" }, now)
    T.eq(r.goals[1].fromMine, 1) T.eq(r.goals[1].fromAlts, 1)
    T.eq(r.goals[2].fromAlts, 1) T.eq(r.goals[2].buy, 2, "the 3 units in reach are used once")
    T.eq(#r.excluded, 2)
    T.eq(r.transfers[1].count, 2) T.ok(r.transfers[1].stale) T.ok(r.transfers[1].check:find("soulbound"))
  end)
end)

T.describe("reservations and transfers (OI05-13)", function()
  T.it("an override and then priority decide competing goals; releasing keeps the record", function()
    local _, ns = session()
    local S = ns.Supply
    local low = S.Reserve("later", 500, 2, 90)
    S.Reserve("soon", 500, 2, 10)
    S.Reserve("must", 500, 1, 99, true)
    local r = S.Expand(S.Active(), {}, { [500] = { mine = 3, alts = {} } }, {})
    T.eq(r.goals[1].goal, "must") T.eq(r.goals[2].goal, "soon") T.eq(r.goals[3].goal, "later")
    T.eq(r.goals[3].buy, 2)
    T.ok(S.Release(low.id))
    T.eq(#S.Active(), 2)
    T.eq(#S.Store().reservations, 3, "released, not deleted")
    T.eq(select(2, S.Reserve("", 1, 1)), "goal, item and a count above 0")
  end)

  T.it("the plan follows stock changes and only advises (no mail, craft or buy calls)", function()
    local _, ns = session()
    local S = ns.Supply
    S.Reserve("dye", 500, 3, 10)
    ns.db.global.inventory = { [ns.db.key] = { bags = { [500] = 1 } } }
    T.eq(S.Plan().shoppingList[1].count, 2)
    ns.db.global.inventory[ns.db.key].bags[500] = 3
    T.eq(#S.Plan().shoppingList, 0, "stock changed: nothing left to buy")
    local src = io.open("addon/Outrider/Intelligence/Supply.lua"):read("*a"):gsub("%-%-[^\n]*", "")
    for _, call in ipairs({ "SendMail", "PlaceAuctionBid", "C_TradeSkillUI.CraftRecipe", "BuyMerchantItem", "PostItem" }) do
      T.ok(not src:find(call, 1, true), call)
    end
  end)
end)

T.describe("Treasurer budget (OI05-14)", function()
  T.it("whole copper; unknown categories listed; your own amount wins; short when gold doesn't cover", function()
    local _, ns = session()
    local Tr = ns.Treasurer
    local b = Tr.Budget(5000)
    T.eq(b.have, 5000)
    local unk = table.concat(b.unknown, ",")
    T.ok(unk:find("repair"), unk)
    T.ok(Tr.Set("repair", 1500.7))
    b = Tr.Budget(5000)
    local repair
    for _, r in ipairs(b.rows) do if r.cat == "repair" then repair = r end end
    T.eq(repair.copper, 1500) T.eq(repair.source, "set by you")
    T.ok(Tr.Set("training", 6000))
    local f = Tr.Fits(100, 5000)
    T.eq(f.fits, false) T.ok(f.short >= 2600, tostring(f.short))
    T.no(Tr.Set("pets", 1)) T.no(Tr.Set("repair", -5))
    T.ok(Tr.Set("repair", nil))
  end)

  T.it("every character's wallet is listed apart, yours first", function()
    local game, ns = session()
    ns.Alts.alts["Zed-Realm"] = { money = 777, t = 1 }
    game.money = 4200
    local w = ns.Treasurer.Wallets()
    T.ok(w[1].me) T.eq(w[1].copper, 4200)
    local found
    for _, x in ipairs(w) do if x.char == "Zed-Realm" then found = x end end
    T.eq(found.copper, 777)
  end)
end)

T.describe("realized economics (OI05-15) and profession costs (OI05-16)", function()
  T.it("confirmed sales only; unknown cuts have no net; unverified auctions apart; thin data and depth said", function()
    local game, ns = session()
    local r = ns.Market.Realized({ { item = "Linen", price = 1000, fee = 50, deposit = 10 }, { item = "Linen", price = 800 } }, 4)
    T.eq(r.sales, 2) T.eq(r.net, 950) T.eq(r.feeUnknown, 1) T.eq(r.unverified, 4)
    T.eq(r.cutShare, nil, "a cut isn't measured while one is unknown")
    T.eq(ns.Market.SaleChance(3, 4), nil)
    T.eq(ns.Market.SaleChance(3, 6), 0.5)
    game.items = game.items or {}
    game.items[700] = { name = "Linen", sell = 13 }
    ns.Prices.Statistics = function() return { count = 2, median = 120, days = 2, source = "seen" } end
    local c = ns.Market.Compare(700, { cutShare = 0.05 })
    T.eq(c.vendor, 13) T.ok(c.ah.thin) T.eq(c.ah.afterCut, 114) T.ok(c.ah.depositUnknown)
    T.ok(c.notes[1]:find("depth"))
  end)

  T.it("orange first with a cost per sure point; yellow and green chance unknown; observed apart", function()
    local _, ns = session()
    ns.db.char.professions = { Tailoring = { recipes = {
      a = { name = "Cheap", diff = 0, reagents = { [1] = 2 }, skillUps = 1 },
      b = { name = "Dear", diff = 0, reagents = { [2] = 1 } },
      c = { name = "Maybe", diff = 1, reagents = { [1] = 1 } },
      d = { name = "Dull", diff = 3, reagents = { [1] = 1 } },
      e = { name = "Unpriced", diff = 0, reagents = { [9] = 1 } } } } }
    ns.Prices.Get = function(_, id) return ({ [1] = 10, [2] = 500 })[id] end
    local p = ns.Market.Paths("Tailoring", { [1] = 1 })
    T.eq(p.rows[1].name, "Cheap") T.eq(p.rows[1].costPerPoint, 20) T.eq(p.rows[1].ownedUnits, 1)
    T.eq(p.rows[2].name, "Dear") T.eq(p.rows[3].name, "Unpriced") T.ok(p.rows[3].unpriced)
    T.ok(p.rows[4].chance:find("unknown")) T.eq(p.rows[5].name, "Dull")
    T.eq(p.observedSkillUps, 0)
    T.eq(select(2, ns.Market.Paths("Mining")), "no recipes recorded for Mining")
    T.eq(#ns.Errors.list, 0)
  end)
end)

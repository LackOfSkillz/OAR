-- P5-06 Merchant's Favor planner: capture first, plan from what was captured.
-- All names and numbers here are made-up fixtures, not game data.
local T, mock = ...

local function session(setup)
  local game = mock.new({ ammo = 1000 })
  if setup then setup(game) end
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("favor", function()
  T.it("reads bundle lines in the usual wordings", function()
    local _, ns = session()
    local P = ns.Favor.ParseBundle
    T.same(P("20 Linen Cloth"), { name = "Linen Cloth", count = 20 })
    T.same(P("Linen Cloth x20"), { name = "Linen Cloth", count = 20 })
    T.same(P("Linen Cloth (0/20)"), { name = "Linen Cloth", count = 20 })
    T.same(P("Linen Cloth: 3/20"), { name = "Linen Cloth", count = 20 })
    T.same(P("|cffffffff- 10 Copper Ore|r"), { name = "Copper Ore", count = 10 })
    T.eq(P("Use: Open the crate"), nil)
    T.eq(P("Requires Level 10"), nil)
    T.eq(P(nil), nil)
  end)

  T.it("captures balance, standing, a crate and plans from bags and alts", function()
    local game, ns = session(function(game)
      game.items = game.items or {}
      game.items[9001] = { name = "Waylaid Supplies: Cloth" }
      game.items[2589] = { name = "Linen Cloth" }
      game.items[2770] = { name = "Copper Ore" }
      game.bags = { [0] = { [1] = 9001, [2] = 2589 } }
      game.counts = { [0] = { [1] = 1, [2] = 12 } }
    end)
    local env = game.env
    env.C_CurrencyInfo = {
      GetCurrencyListSize = function() return 2 end,
      GetCurrencyListInfo = function(i)
        if i == 1 then return { name = "Miscellaneous", isHeader = true } end
        return { name = "Merchant's Favor", quantity = 45 }
      end,
      GetCurrencyListLink = function(i) return "|Hcurrency:9999:0|h" end,
    }
    env.C_Reputation = {
      GetNumFactions = function() return 1 end,
      GetFactionDataByIndex = function() return { name = "Durotar Supply and Logistics", reaction = 5, currentStanding = 300 } end,
    }
    env.C_TooltipInfo.GetBagItem = function(bag, slot)
      return { lines = { { leftText = "Waylaid Supplies: Cloth" }, { leftText = "Fill with one bundle:" },
        { leftText = "20 Linen Cloth" }, { leftText = "10 Copper Ore" } } }
    end
    local F = ns.Favor
    ns.Inventory:ScanBags()
    F:ScanCurrency() F:ScanStanding() F:ScanCrates()
    local key = ns.db.key
    T.eq(F.db.balance[key].amount, 45)
    T.eq(F.db.balance[key].currencyID, 9999)
    T.eq(F.db.standing[key].reaction, 5)
    local crate = F.db.crates[9001]
    T.ok(crate, "crate learned")
    T.eq(crate.verified, false)
    T.eq(#crate.bundles, 2)
    -- an alt holds 10 more cloth
    ns.Inventory.db["Alt-Realm"] = { bags = { [2589] = 10 }, bank = {}, mail = {}, worn = {} }
    local plan = F:Plan(9001)
    T.eq(plan[1].name, "Linen Cloth")
    T.ok(plan[1].ready)
    T.eq(plan[1].have, 22)
    local text = table.concat(F:Lines(), "\n")
    T.contains(text, "Merchant's Favor:|r 45")
    T.contains(text, "ready: you have 22 Linen Cloth")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("records a quartermaster only when it sells for Favor", function()
    local game, ns = session()
    local env = game.env
    env.UnitName = function() return "Depot Clerk" end
    env.GetMerchantNumItems = function() return 2 end
    env.GetMerchantItemID = function(i) return 100 + i end
    env.GetMerchantItemCostInfo = function(i) return i == 1 and 1 or 0 end
    env.GetMerchantItemCostItem = function() return nil, 30, nil, "Merchant's Favor" end
    T.eq(#ns.Favor:ScanVendor(), 2)
    T.eq(ns.Favor.db.vendor["Depot Clerk"].items[1].costs[1].value, 30)
    env.GetMerchantItemCostInfo = function() return 0 end
    env.UnitName = function() return "Plain Vendor" end
    T.eq(ns.Favor:ScanVendor(), nil)
    T.eq(ns.Favor.db.vendor["Plain Vendor"], nil)
  end)

  T.it("fails soft with no currency or reputation API", function()
    local game, ns = session()
    game.env.C_CurrencyInfo = nil
    game.env.C_Reputation = nil
    game.env.GetNumFactions = nil
    T.eq(ns.Favor:ScanCurrency(), nil)
    T.eq(ns.Favor:ScanStanding(), nil)
    T.contains(table.concat(ns.Favor:Lines(), "\n"), "not seen yet")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("Journey finds The Rake at its Forever spawn, not Classic data", function()
    local game = mock.new({ seedRares = true })
    local ns = game:loadAddon()
    game:login()
    local found
    for _, e in ipairs(ns.Finder:Find({ kind = "rare", text = "rake" })) do if e.name == "The Rake" then found = e end end
    T.ok(found, "The Rake listed")
    T.eq(found.mapID, 1412)
    T.ok(math.abs(found.x - 0.515) < 1e-6 and math.abs(found.y - 0.275) < 1e-6)
    T.contains(found.sub, "2 spots")
  end)
end)

T.describe("rare seed pack (P2-02)", function()
  T.it("loads without validation errors, every entry cited, verified only where Gary saw it", function()
    local game = mock.new({ seedRares = true })
    local ns = game:loadAddon()
    game:login()
    local all = ns.Data:All("rare")
    T.ok(#all >= 5, "seed entries")
    for _, e in ipairs(all) do
      T.ok(type(e.source) == "string" and e.source ~= "", "source for " .. e.name)
      if e.verified then T.ok(e.verifiedOn ~= nil, e.name .. " says when it was verified") end
      if e.mapID == 1412 then T.ok(e.source:find("Forever", 1, true), "Mulgore spawns only from a Forever source") end
    end
    T.eq(ns.Data:Get("rare", 259388).name, "Mystmane")
    T.eq(ns.Data:Get("rare", 5807).verified, true)   -- Torrant tamed it (stable creatureID 5807)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("Journey finds The Rake at its Forever spawn, not Classic data", function()
    local game = mock.new({ seedRares = true })
    local ns = game:loadAddon()
    game:login()
    local found
    for _, e in ipairs(ns.Finder:Find({ kind = "rare", text = "rake" })) do if e.name == "The Rake" then found = e end end
    T.ok(found, "The Rake listed")
    T.eq(found.mapID, 1412)
    T.ok(math.abs(found.x - 0.515) < 1e-6 and math.abs(found.y - 0.275) < 1e-6)
    T.contains(found.sub, "2 spots")
  end)
end)

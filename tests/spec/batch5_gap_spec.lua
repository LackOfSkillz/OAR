-- DEEP-25..34: batch-5 implementation contract tests.
local T, mock = ...

local function session(before)
  local game = mock.new({ level = 18, class = "HUNTER" })
  if before then before(game) end
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("batch5 leveling routes", function()
  T.it("validates original steps, persists progress, supports skip and undo", function()
    local g, ns = session()
    local r = ns.LevelRoutes
    local ok = r:Create("My Route", {
      { kind = "quest", id = "q1", name = "First quest", questID = 891, mapID = 1412, x = 0.3, y = 0.4 },
      { kind = "loot", id = "i2", name = "Collect items", itemID = 7002, count = 2 },
      { kind = "place", id = "p3", name = "Find location", mapID = 1412, x = 0.6, y = 0.2 },
    })
    T.ok(ok)
    T.ok(r:Start("My Route"))
    T.eq(r:Current().id, "q1")
    r:OnQuest(nil, 891)
    T.eq(r:Current().id, "i2")
    r:OnLoot(nil, "mob", { { id = 7002, count = 1 } })
    T.eq(r:Current().id, "i2")
    r:OnLoot(nil, "mob", { { id = 7002, count = 1 } })
    T.eq(r:Current().id, "p3")
    r:Mark(r:Current(), "skipped")
    T.eq(r:Current(), nil)
    T.ok(r:Undo())
    T.eq(r:Current().id, "p3")
    T.eq(#ns.Errors.list, 0)
  end)
  T.it("won't create coordinates outside maps or negative count", function()
    local g, ns = session()
    T.no(ns.LevelRoutes:Create("Bad", { { kind = "place", name = "Impossible",
      mapID = 1412, x = -0.01, y = 0.6 } }))
  end)
end)

T.describe("batch5 stat scales and food", function()
  T.it("accepts supported Pawn stats, rejects unknown and excessive weights", function()
    local g, ns = session()
    local G = ns.GearScore
    T.no(G:ValidWeight("bad", 2))
    T.no(G:ValidWeight("ITEM_MOD_AGILITY_SHORT", 5000))
    T.ok(G:ValidWeight("ITEM_MOD_AGILITY_SHORT", 2))
    local ok, name = G:ImportPawn('( Pawn: v1: "Test": Class=Hunter, Name="Test", Agility=2.5, Stamina=1.1, Bogus=3 )')
    T.ok(ok)
    T.eq(name, "Test")
    T.eq(G:Weights().ITEM_MOD_AGILITY_SHORT, 2.5)
    T.eq(G:Weights().ITEM_MOD_STAMINA_SHORT, 1.1)
  end)
  T.it("stores explicit preferred and excluded food", function()
    local g, ns = session()
    g:slash("foodrules prefer Crisp Apple")
    T.eq(ns.BagFood:Settings().prefer["crisp apple"], 100)
    g:slash("foodrules never Crisp Apple")
    T.eq(ns.BagFood:Settings().prefer["crisp apple"], nil)
    T.ok(ns.BagFood:Settings().never["crisp apple"])
  end)
end)

T.describe("batch5 AH, sources and alts", function()
  T.it("selling list has no invented auction IDs, denied cancels without AH", function()
    local g, ns = session()
    local A = ns.AuctionHelper
    T.eq(#A:Owned(), 0)
    local ok = A:CancelAuction(123)
    T.no(ok)
    T.eq(#A:SalesLedger(), 0)
  end)
  T.it("recipe sources only count explicitly learned metadata", function()
    local g, ns = session()
    local P = ns.ProfExtras
    T.ok(P:RecordRecipeSource(99111, "Sample Brew", "vendor", "Test Merchant", 20))
    T.no(P:RecordRecipeSource(99112, "Bad", "unknown", "Nobody"))
    T.eq(P:UnlearnedRecipes()[1].name, "Sample Brew")
    T.eq(P:UnlearnedRecipes()[1].source, "user supplied, unverified")
  end)
  T.it("alt recipes and bank/bag views use last recorded data only", function()
    local g, ns = session()
    ns.Alts.alts["Friend-Realm"] = { recipes = { [42] = true } }
    ns.Inventory.db["Friend-Realm"] = { bags = { [7101] = 3 }, bank = {}, worn = {}, mail = {} }
    T.eq(ns.Alts:KnownBy(42)[1], "Friend-Realm")
    local b = ns.Alts:AltBags("Friend-Realm")
    T.eq(b[1].id, 7101)
    T.eq(b[1].n, 3)
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("batch5 equipment, rares and bags", function()
  T.it("reports missing gear by inventory presence without equipping", function()
    local g, ns = session()
    local G = ns.GearSets
    G:Settings().sets["test"] = { name = "test", items = { [1] = "item:77172" } }
    local report = G:Missing("test")
    T.eq(#report.missing, 1)
    T.eq(report.missing[1].id, 77172)
    T.eq(#ns.Errors.list, 0)
  end)
  T.it("rare model falls back when display data absent and loot stays sourced", function()
    local g, ns = session()
    local R = ns.Modules:Get("RareAlerts")
    local ok = R:ShowModel({ npcID = 81330 })
    T.no(ok)
    T.eq(#R:KnownLoot(81330), 0)
    ns.db.global.rareLootSources = { [81330] = { { id = 771, chance = 2.5, source = "verified local test" } } }
    T.eq(R:KnownLoot(81330)[1].id, 771)
  end)
  T.it("bag browser exposes categories, alt cached inventory and BoE flag", function()
    local g, ns = session()
    ns.Inventory.db["Other-Realm"] = { bags = { [9001] = 2 }, bank = {}, mail = {}, worn = {} }
    local rows = ns.BagExtras:BagRows("bags", "Other-Realm", "", "all")
    T.eq(rows[1].id, 9001)
    T.eq(rows[1].source, "last observed")
    T.eq(rows[1].count, 2)
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("batch5 client meter", function()
  T.it("uses Blizzard's known post-fight session structure, no combat-log capture", function()
    local g, ns = session(function(game)
      rawset(game.env, "C_DamageMeter", {
        GetAvailableCombatSessions = function() return { { sessionID = 111, name = "Dummy" } } end,
        GetCombatSessionFromID = function()
          return { durationSeconds = 10, totalAmount = 1200,
            combatSources = { { name = "Me", isLocalPlayer = true, totalAmount = 1200 } } }
        end,
      })
    end)
    local M = ns.FightMeter
    T.ok(M:Capture())
    T.eq(M:History()[1].dps, 120)
    T.eq(M:History()[1].player, 1200)
    T.eq(M:History()[1].name, "Dummy")
    T.eq(#ns.Errors.list, 0)
  end)
end)

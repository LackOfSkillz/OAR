-- POI capture (P3-06) and Nearest (P3-07). Positions are test data.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game.units = {}
  return game, ns
end

local function talk(game, id, name, event, x, y)
  game.opts.x, game.opts.y = x, y
  game.units.npc = { guid = "Creature-0-5250-0-777-" .. id .. "-00000001", name = name }
  game:fire(event)
end

T.describe("poi capture and nearest", function()
  T.it("records vendors (with repair), flight masters, spirit healers and mailboxes", function()
    local game, ns = session()
    game.canRepair = true
    talk(game, 6001, "Smith", "MERCHANT_SHOW", 0.40, 0.40)
    talk(game, 6002, "Flyer", "TAXIMAP_OPENED", 0.60, 0.60)
    talk(game, 6003, "Spirit Healer", "CONFIRM_XP_LOSS", 0.20, 0.20)
    game.units.npc = nil
    game.opts.x, game.opts.y = 0.5, 0.5
    game:fire("MAIL_SHOW")
    T.eq(ns.POI:Count("vendor"), 1)
    T.eq(ns.POI:Count("repair"), 1)
    T.eq(ns.POI:Count("flight_master"), 1)
    T.eq(ns.POI:Count("spirit_healer"), 1)
    T.eq(ns.POI:Count("mailbox"), 1)
    local v = ns.db.global.pois["npc-6001-vendor"]
    T.eq(v.faction, "Horde")
    T.eq(v.verified, false)
  end)

  T.it("repeat visits average the position", function()
    local game, ns = session()
    talk(game, 6001, "Smith", "MERCHANT_SHOW", 0.40, 0.40)
    talk(game, 6001, "Smith", "MERCHANT_SHOW", 0.42, 0.40)
    T.ok(math.abs(ns.db.global.pois["npc-6001-vendor"].x - 0.41) < 1e-9)
  end)

  T.it("/ride near picks the closest one and sets a waypoint", function()
    local game, ns = session()
    talk(game, 6011, "Far Healer", "CONFIRM_XP_LOSS", 0.90, 0.90)
    talk(game, 6012, "Near Healer", "CONFIRM_XP_LOSS", 0.30, 0.30)
    game.opts.x, game.opts.y = 0.35, 0.35
    game:slash("near spirit")
    T.eq(ns.Waypoints.current.title, "Near Healer")
    T.contains(game:chatText(), "Near Healer, 71 yards")
  end)

  T.it("other-faction places are skipped; unknown kinds say so", function()
    local game, ns = session()
    talk(game, 6021, "Ally Flyer", "TAXIMAP_OPENED", 0.5, 0.5)
    ns.db.global.pois["npc-6021-flight_master"].faction = "Alliance"
    game:slash("near flight")
    T.contains(game:chatText(), "no flight master known")
    T.eq(ns.Waypoints.current, nil)
  end)

  T.it("dying sets a waypoint to the nearest spirit healer", function()
    local game, ns = session()
    talk(game, 6012, "Near Healer", "CONFIRM_XP_LOSS", 0.30, 0.30)
    game:fire("PLAYER_DEAD")
    T.eq(ns.Waypoints.current.title, "Near Healer")
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("poi backfill", function()
  T.it("NPC visits recorded by Discovery become places at login", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    ns.db.global.discovered.npcs[6101] = { name = "Old Banker", quality = "interact", mapID = 1412, x = 0.5, y = 0.5, roles = { "gossip", "banker" } }
    ns.db.global.discovered.npcs[6102] = { name = "Seen Only", quality = "mouseover", mapID = 1412, x = 0.5, y = 0.5, roles = { "vendor" } }
    local sv = game:logout()
    local g2 = mock.new({ savedVariables = sv })
    local ns2 = g2:loadAddon()
    g2:login()
    T.ok(ns2.db.global.pois["npc-6101-bank"])
    T.eq(ns2.db.global.pois["npc-6102-vendor"], nil, "a mouseover position is not good enough for a place")
  end)
end)

T.describe("place details", function()
  T.it("vendors record their title and what they sell; tooltips show both", function()
    local game, ns = session()
    game.merchant = { 9001, 9002, 9003 }
    game.itemClass = { [9001] = 6, [9002] = 6, [9003] = 0 }
    game.opts.x, game.opts.y = 0.47, 0.37
    game.units.npc = { guid = "Creature-0-5250-0-777-6201-00000001", name = "Bow Seller", title = "Bowyer" }
    game:fire("MERCHANT_SHOW")
    game:advance(1)
    local p = ns.db.global.pois["npc-6201-vendor"]
    T.eq(p.title, "Bowyer")
    T.same(p.goods, { "ammo", "food & potions" })
    local first, second = ns.POI.Describe(p, "Vendor")
    T.eq(first, "Vendor (Bowyer)")
    T.eq(second, "Sells: ammo, food & potions")
    local M = ns.Modules:Get("MinimapPins")
    M:Update()
    local d = M.used[1]
    d.__scripts.OnEnter(d)
    T.contains(game.env.GameTooltip.__lines[2], "Vendor (Bowyer)")
    T.eq(game.env.GameTooltip.__lines[3], "Sells: ammo, food & potions")
  end)

  T.it("trainers keep what they train", function()
    local game, ns = session()
    game.units.npc = { guid = "Creature-0-5250-0-777-6202-00000001", name = "Teacher", title = "Hunter Trainer" }
    game:fire("TRAINER_SHOW")
    T.eq(ns.POI.Describe(ns.db.global.pois["npc-6202-trainer"], "Trainer"), "Trainer (Hunter Trainer)")
  end)

  T.it("NPCs without a title just show the kind", function()
    local game, ns = session()
    game.units.npc = { guid = "Creature-0-5250-0-777-6203-00000001", name = "Plain" }
    game:fire("BANKFRAME_OPENED")
    T.eq(ns.db.global.pois["npc-6203-bank"].title, nil)
  end)
end)

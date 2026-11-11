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

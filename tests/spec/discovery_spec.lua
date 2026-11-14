-- Discovery (P2-01). Unit data below is test data only, not game facts.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  game.units = {}
  return game, ns
end

local function npc(id, name, extra)
  local u = { guid = "Creature-0-5250-0-777-" .. id .. "-00001ABC", name = name, level = 12,
              classification = "normal", creatureType = "Humanoid" }
  for k, v in pairs(extra or {}) do u[k] = v end
  return u
end

T.describe("discovery", function()
  T.it("captures a targeted NPC with position, layer and quality", function()
    local game, ns = session()
    game.units.target = npc(90001, "Test Vendor")
    game:fire("PLAYER_TARGET_CHANGED")
    local e = ns.db.global.discovered.npcs[90001]
    T.ok(e)
    T.eq(e.name, "Test Vendor")
    T.eq(e.mapID, 1412)
    T.eq(e.quality, "target")
    T.eq(e.layer, 777)
    T.eq(e.seen, 1)
  end)

  T.it("talking to a vendor upgrades quality to interact and tags the role", function()
    local game, ns = session()
    game.units.target = npc(90001, "Test Vendor")
    game:fire("PLAYER_TARGET_CHANGED")
    game.opts.x, game.opts.y = 0.50, 0.40
    game.units.npc = game.units.target
    game:fire("MERCHANT_SHOW")
    local e = ns.db.global.discovered.npcs[90001]
    T.eq(e.quality, "interact")
    T.same(e.roles, { "vendor" })
    T.eq(e.x, 0.50)
    -- a second visit from a slightly different spot is averaged
    game.opts.x = 0.52
    game:fire("MERCHANT_SHOW")
    T.ok(math.abs(e.x - 0.51) < 1e-9)
    T.same(e.roles, { "vendor" }, "role not duplicated")
  end)

  T.it("a nameplate never overwrites a better position", function()
    local game, ns = session()
    game.units.target = npc(90002, "Guard")
    game:fire("PLAYER_TARGET_CHANGED")
    game.units.nameplate1 = game.units.target
    game.opts.x = 0.9
    game:fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    game:advance(0.5)
    local e = ns.db.global.discovered.npcs[90002]
    T.eq(e.quality, "target")
    T.eq(e.x, 0.46)
    T.eq(e.seen, 2)
  end)

  T.it("skips players, pets, critters and secret names", function()
    local game, ns = session()
    local D = ns.Modules:Get("Discovery")
    game.units.target = { guid = "Player-1-0000ABCD", name = "Someone", player = true }
    T.eq(select(2, D:Capture("target", "target")), "player")
    game.units.target = { guid = "Pet-0-1-0-777-12345-0001", name = "Wolf" }
    T.eq(select(2, D:Capture("target", "target")), "not a creature")
    game.units.target = npc(90003, "Hare", { creatureType = "Critter" })
    T.eq(select(2, D:Capture("target", "target")), "critter")
    game.units.target = npc(90004, { __secret = true })
    T.eq(select(2, D:Capture("target", "target")), "secret or no name")
    T.eq(D:Count(), 0)
  end)

  T.it("a burst of nameplates is processed in throttled batches", function()
    local game, ns = session()
    local D = ns.Modules:Get("Discovery")
    for i = 1, 20 do
      game.units["nameplate" .. i] = npc(91000 + i, "Mob " .. i)
      game:fire("NAME_PLATE_UNIT_ADDED", "nameplate" .. i)
    end
    local afterBurst = D:Count()
    T.ok(afterBurst <= 1, "at most the leading flush runs inside the burst")
    game:advance(0.5)
    T.eq(D:Count(), 20)
  end)

  T.it("no layer is recorded inside instances", function()
    local game, ns = session({ inInstance = true })
    game.units.target = npc(90005, "Dungeon Mob")
    game:fire("PLAYER_TARGET_CHANGED")
    T.eq(ns.db.global.discovered.npcs[90005].layer, nil)
  end)

  T.it("discoveries survive a reload and /ride discovered lists them", function()
    local game, ns = session()
    game.units.target = npc(90001, "Test Vendor")
    game:fire("PLAYER_TARGET_CHANGED")
    local sv = game:logout()
    local g2 = mock.new({ savedVariables = sv })
    local ns2 = g2:loadAddon()
    g2:login()
    T.eq(ns2.db.global.discovered.npcs[90001].name, "Test Vendor")
    g2:slash("discovered 5")
    T.contains(g2:chatText(), "Test Vendor (90001) target")
    T.eq(#ns2.Errors.list, 0)
  end)
end)

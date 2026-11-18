-- RareScan (P2-03). Unit data is test data only.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  game.units = {}
  local seen = {}
  ns.Events:On("OTR_RARE_SEEN", { name = "spec" }, function(_, info) seen[#seen + 1] = info end)
  return game, ns, seen
end

local function mob(id, name, extra)
  local u = { guid = "Creature-0-5250-0-777-" .. id .. "-00001ABC", name = name, level = 20,
              classification = "normal", creatureType = "Beast", family = "Cat" }
  for k, v in pairs(extra or {}) do u[k] = v end
  return u
end

T.describe("rarescan", function()
  T.it("a rare-classified mob fires OTR_RARE_SEEN with position and layer", function()
    local game, ns, seen = session()
    game.units.mouseover = mob(80001, "Spec Rare", { classification = "rare" })
    game:fire("UPDATE_MOUSEOVER_UNIT")
    T.eq(#seen, 1)
    local i = seen[1]
    T.eq(i.npcID, 80001)
    T.eq(i.how, "mouseover")
    T.eq(i.layer, 777)
    T.eq(i.mapID, 1412)
    T.eq(i.dead, false)
    T.eq(i.tameable, true)
  end)

  T.it("normal mobs are ignored unless in a pack or on the watchlist", function()
    local game, ns, seen = session()
    game.units.target = mob(80002, "Plain Cat")
    game:fire("PLAYER_TARGET_CHANGED")
    T.eq(#seen, 0)
    game:slash("watch plain cat")
    game:fire("PLAYER_TARGET_CHANGED")
    T.eq(#seen, 1)
    T.ok(seen[1].watched)
    ns.Data:Register("rare", "spec", { { npcID = 80003, name = "Pack Rare", mapID = 1412, verified = false } })
    game.units.target = mob(80003, "Pack Rare")
    game:fire("PLAYER_TARGET_CHANGED")
    T.eq(#seen, 2)
    T.ok(seen[2].pack)
  end)

  T.it("dedupes within 60 s, re-fires on death or after the window", function()
    local game, ns, seen = session()
    game.units.target = mob(80001, "Spec Rare", { classification = "rare" })
    game:fire("PLAYER_TARGET_CHANGED")
    game:fire("PLAYER_TARGET_CHANGED")
    T.eq(#seen, 1)
    game.units.target.dead = true
    game:fire("PLAYER_TARGET_CHANGED")
    T.eq(#seen, 2)
    T.eq(seen[2].dead, true)
    game:advance(61)
    game:fire("PLAYER_TARGET_CHANGED")
    T.eq(#seen, 3)
  end)

  T.it("a layer change re-fires", function()
    local game, ns, seen = session()
    game.units.target = mob(80001, "Spec Rare", { classification = "rare" })
    game:fire("PLAYER_TARGET_CHANGED")
    game.units.target.guid = "Creature-0-5250-0-888-80001-00001ABC"
    game:fire("PLAYER_TARGET_CHANGED")
    T.eq(#seen, 2)
    T.eq(seen[2].layer, 888)
  end)

  T.it("nameplates are batched, never on OnUpdate", function()
    local game, ns, seen = session()
    for i = 1, 10 do
      game.units["nameplate" .. i] = mob(81000 + i, "R" .. i, { classification = "rareelite" })
      game:fire("NAME_PLATE_UNIT_ADDED", "nameplate" .. i)
    end
    T.ok(#seen <= 1)
    game:advance(0.5)
    T.eq(#seen, 10)
    T.no(ns.Timer.DriverRunning())
  end)

  T.it("secret classification in combat: only pack or watchlist rares count", function()
    local game, ns, seen = session()
    game.units.target = mob(80001, "Spec Rare", { classification = { __secret = true } })
    game:fire("PLAYER_TARGET_CHANGED")
    T.eq(#seen, 0)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("notes once in the Feed (not chat) when enemy nameplates are off", function()
    local game, ns = session({ cvars = { nameplateShowEnemies = "0" } })
    game:fire("PLAYER_ENTERING_WORLD", false, true)
    local _, n = game:chatText():gsub("nameplates are off", "")
    T.eq(n, 0, "login chat stays quiet")
    T.eq(ns.Feed.list[1].title, "Enemy nameplates are off")
  end)

  T.it("the watchlist is per character", function()
    local game, ns = session()
    game:slash("watch The Rake")
    local sv = game:logout()
    local g2 = mock.new({ savedVariables = sv, name = "Zeil", class = "PRIEST" })
    local ns2 = g2:loadAddon()
    g2:login()
    T.no(ns2.Modules:Get("RareScan"):IsWatched(nil, "The Rake"))
    local g3 = mock.new({ savedVariables = g2:logout() })
    local ns3 = g3:loadAddon()
    g3:login()
    T.ok(ns3.Modules:Get("RareScan"):IsWatched(nil, "The Rake"))
  end)
end)

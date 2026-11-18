-- Layer detection (P2-06). GUIDs are test data.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game.units = {}
  local changes = {}
  ns.Events:On("OTR_LAYER_CHANGED", { name = "spec" }, function(_, new, old) changes[#changes + 1] = { new, old } end)
  return game, ns, changes
end

local n = 0
local function see(game, zoneUID, unit)
  n = n + 1
  unit = unit or "target"
  game.units[unit] = { guid = string.format("Creature-0-5250-0-%d-3000-%08X", zoneUID, n), name = "Mob" }
  game:fire(unit == "target" and "PLAYER_TARGET_CHANGED" or "UPDATE_MOUSEOVER_UNIT")
end

T.describe("layers", function()
  T.it("needs 3 creatures before naming a layer", function()
    local game, ns = session()
    see(game, 4321) see(game, 4321)
    T.eq(ns.Layers:Current(), nil)
    see(game, 4321)
    local id, conf, label = ns.Layers:Current()
    T.eq(id, 4321)
    T.eq(conf, 1)
    T.eq(label, "Layer 321")
  end)

  T.it("stays stable with a few stragglers, changes once after a real switch", function()
    local game, ns, changes = session()
    for _ = 1, 8 do see(game, 1111) end
    see(game, 2222)
    T.eq(ns.Layers:Current(), 1111)
    T.eq(#changes, 0)
    for _ = 1, 20 do see(game, 2222) end
    T.eq(ns.Layers:Current(), 2222)
    T.eq(#changes, 1)
    T.same(changes[1], { 2222, 1111 })
  end)

  T.it("the same creature seen again does not count twice", function()
    local game, ns = session()
    game.units.target = { guid = "Creature-0-5250-0-5555-3000-0000AAAA", name = "Mob" }
    for _ = 1, 5 do game:fire("PLAYER_TARGET_CHANGED") end
    T.eq(ns.Layers:Current(), nil)
  end)

  T.it("ignores instances and players", function()
    local game, ns = session({ inInstance = true })
    for _ = 1, 5 do see(game, 9999) end
    T.eq(ns.Layers:Current(), nil)
  end)

  T.it("the hub Overview shows the layer", function()
    local game, ns = session()
    for _ = 1, 3 do see(game, 4321) end
    game:slash("")
    ns.Hub.frame.tabBar:Select("overview")
    T.contains(ns.Hub.byId.overview.panel.layer:GetText(), "Layer 321")
  end)

  T.it("shows the layer on the info bar and records visit history", function()
    local game, ns = session()
    T.contains(ns.InfoBar:Text("layer"), "Layer —")
    for _ = 1, 3 do see(game, 4321) end
    T.contains(ns.InfoBar:Text("layer"), "Layer 321")
    local history = ns.Layers:History(1412)
    T.eq(#history, 1)
    T.eq(history[1].id, 4321)
    T.eq(history[1].mapID, 1412)
  end)

  T.it("never displays a stale layer after entering a new zone", function()
    local game, ns = session()
    for _ = 1, 3 do see(game, 4321) end
    T.eq(ns.Layers:Current(), 4321)
    ns.Layers:ZoneChanged()
    T.eq(ns.Layers:Current(), nil)
    T.contains(ns.InfoBar:Text("layer"), "Layer —")
    T.eq(#ns.Layers:History(1412), 1)
  end)

  T.it("shows unknown when the sampled creatures disagree", function()
    local game, ns = session()
    for _ = 1, 3 do see(game, 1111) end
    T.eq(ns.Layers:Current(), 1111)
    for _ = 1, 3 do see(game, 2222) end
    T.eq(ns.Layers:Current(), nil)
    T.contains(ns.InfoBar:Text("layer"), "Layer —")
  end)
end)

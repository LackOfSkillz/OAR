-- Herb and ore node pack: profession and skill aware. Points are test data.
local T, mock = ...

local function session(prof, skill)
  local game = mock.new({ mapID = 1412, x = 0.5, y = 0.5 })
  game.prof = prof and { name = prof, skill = skill or 1, max = 75, line = 1, recipes = {} }
  game.base.Outrider_DataNodes = { source = "test", maps = { [1412] = {
    { "Peacebloom", "herb", { 0.52, 0.52, 0.80, 0.80 } },
    { "Earthroot", "herb", { 0.60, 0.60 } },
    { "Copper Vein", "ore", { 0.55, 0.55 } },
  } } }
  rawset(game.env, "Outrider_DataNodes", game.base.Outrider_DataNodes)
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game:advance(2)
  if prof == "Herbalism" then ns.db.char.professions.Herbalism = { skill = skill, max = 75, recipes = {} } end
  return game, ns
end

local function names(list) local out = {} for _, n in ipairs(list) do out[n.name] = n end return out end

T.describe("node pack", function()
  T.it("a herbalist sees herbs up to their skill, no ore", function()
    local _, ns = session("Herbalism", 5)
    local n = names(ns.NodePack:For(1412))
    T.ok(n.Peacebloom)
    T.eq(n.Earthroot, nil, "needs 15 per the herb guide")
    T.eq(n["Copper Vein"], nil)
    ns.db.char.professions.Herbalism.skill = 20
    T.ok(names(ns.NodePack:For(1412)).Earthroot, "shows once your skill is high enough")
  end)

  T.it("a miner sees ore; someone with neither sees nothing", function()
    local _, ns = session("Mining", 1)
    T.ok(names(ns.NodePack:For(1412))["Copper Vein"])
    local _, ns2 = session(nil)
    T.eq(#ns2.NodePack:For(1412), 0)
  end)

  T.it("map pins skip spots you gathered yourself; the finder lists the nearest spawn", function()
    local _, ns = session("Herbalism", 5)
    ns.db.global.nodes = { { kind = "herb", mapID = 1412, x = 0.521, y = 0.519, name = "Peacebloom", count = 2 } }
    local pins = ns.NodePack:Pins(1412)
    T.eq(#pins, 1, "the 0.52 spot is yours, the 0.80 one comes from the pack")
    T.eq(pins[1].x, 0.80)
    local f = ns.Finder:Find({ kind = "node" })
    T.eq(f[1].name, "Peacebloom")
    T.eq(f[1].x, 0.52, "nearest spawn to you")
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("node pack switch", function()
  T.it("off: only nodes you gathered on the map and in the finder", function()
    local game = mock.new({ mapID = 1412, x = 0.5, y = 0.5 })
    game.prof = { name = "Herbalism", skill = 5, max = 75, line = 1, recipes = {} }
    game.base.Outrider_DataNodes = { source = "test", maps = { [1412] = { { "Peacebloom", "herb", { 0.80, 0.80 } } } } }
    rawset(game.env, "Outrider_DataNodes", game.base.Outrider_DataNodes)
    local ns = game:loadAddon()
    game:login()
    ns.db.char.professions.Herbalism = { skill = 5, max = 75, recipes = {} }
    T.eq(#ns.NodePack:Pins(1412), 1)
    ns.NodePack:SetShown(false)
    T.eq(#ns.NodePack:Pins(1412), 0)
    T.eq(#ns.Finder:Find({ kind = "node" }), 0)
    ns.NodePack:SetShown(true)
    T.eq(#ns.NodePack:Pins(1412), 1)
  end)
end)

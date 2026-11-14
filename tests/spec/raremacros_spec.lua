-- Rare-aware macros (P4-07). Names are test data.
local T, mock = ...

local function session()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game.units = {}
  return game, ns
end

local function entry(ns, id) for _, e in ipairs(ns.Data:All("macro")) do if e.id == id then return e end end end

T.describe("rare macros", function()
  T.it("the tame macro follows the newest watched tameable rare, out of combat", function()
    local game, ns = session()
    game:slash("watch Alpha Cat")
    game:slash("watch Beta Wolf")
    local e = entry(ns, "hunter-tame-rare")
    T.ok(ns.MacroLibrary:Install(e))
    T.contains(game.macros[1].body, "/targetexact Alpha Cat")
    game.units.target = { guid = "Creature-0-5250-0-777-8801-00000001", name = "Beta Wolf", classification = "rare", family = "Wolf", level = 10 }
    game:setCombat(true)
    game:fire("PLAYER_TARGET_CHANGED")
    T.contains(game.macros[1].body, "Alpha Cat", "not in combat")
    game:setCombat(false)
    T.contains(game.macros[1].body, "/targetexact Beta Wolf")
  end)

  T.it("the scan macro lists this zone's rares, watched first, within 255 characters", function()
    local game, ns = session()
    game:slash("watch Mystmane")
    local rares = {}
    for i = 1, 30 do rares[i] = { npcID = 8900 + i, name = "Zone Rare Number " .. i, mapID = 1412, verified = false } end
    ns.Data:Register("rare", "spec", rares)
    local e = entry(ns, "hunter-rare-scan")
    T.ok(ns.MacroLibrary:Install(e))
    local body = game.macros[1].body
    T.ok(#body <= 255)
    T.eq(body:match("^/cleartarget\n/targetexact (%S+)"), "Mystmane")
    T.eq(ns.MacroEngine.Errors(body), 0)
  end)
end)

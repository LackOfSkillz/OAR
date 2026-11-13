-- Finder: search and sort everything. Names, levels and positions are test data.
local T, mock = ...

local function session()
  local opts = { mapID = 1412, x = 0.5, y = 0.5, level = 13 }
  local game = mock.new(opts)
  game.base.Outrider_DataMobs = { source = "test", maps = { [1412] = {
    { 501, "Mystmane", 13, 13, 4, { 0.60, 0.34 } },
    { 502, "Prowler", 12, 14, 0, { 0.51, 0.50, 0.70, 0.70 } },
    { 503, "Ancient Drake", 50, 52, 1, { 0.52, 0.52 } },
    { 504, "Snapbeak", 9, 9, 2, { 0.90, 0.90 } },
  } } }
  game.base.Outrider_DataNPC = { source = "test", maps = { [1412] = {
    { 601, "vendor", 0.40, 0.40, "Ama Breadbaker", "Food & Drink", nil, nil },
    { 602, "quest_giver", 0.45, 0.45, "Fillion Flamebreeze", nil, nil, {
      { 701, "The Missing Scholar", 1, 13, nil, 0, {}, {} },
      { 702, "Old Errand", 1, 4, nil, 0, {}, {} } } },
  } } }
  rawset(game.env, "Outrider_DataMobs", game.base.Outrider_DataMobs)
  rawset(game.env, "Outrider_DataNPC", game.base.Outrider_DataNPC)
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game:advance(2)
  return game, ns
end

local function names(list) local out = {} for i, e in ipairs(list) do out[i] = e.name end return out end
local function has(list, name) for _, e in ipairs(list) do if e.name == name then return e end end end

T.describe("finder", function()
  T.it("search finds a rare from the creature pack by name", function()
    local _, ns = session()
    local list = ns.Finder:Find({ text = "mystmane" })
    T.eq(list[1].name, "Mystmane")
    T.eq(list[1].kind, "rare")
    T.eq(list[1].level, 13)
    T.ok(list[1].seconds, "has a travel time")
  end)

  T.it("Rares lists rares and rare elites only; Creatures without search stays near your level", function()
    local _, ns = session()
    local rares = ns.Finder:Find({ kind = "rare" })
    T.ok(has(rares, "Mystmane") and has(rares, "Snapbeak"))
    T.eq(has(rares, "Prowler"), nil)
    local mobs = ns.Finder:Find({ kind = "mob" })
    T.ok(has(mobs, "Prowler"))
    T.eq(has(mobs, "Ancient Drake"), nil, "level 50 left out without a search")
    T.ok(has(ns.Finder:Find({ kind = "mob", text = "drake" }), "Ancient Drake"), "found when searched")
  end)

  T.it("sorts: nearest, name, closest to your level, XP", function()
    local _, ns = session()
    local near = ns.Finder:Find({ kind = "rare", sort = "nearest" })
    T.eq(near[1].name, "Mystmane", "0.10,0.16 away beats 0.40,0.40")
    T.eq(names(ns.Finder:Find({ kind = "rare", sort = "name" }))[1], "Mystmane")
    T.eq(ns.Finder:Find({ kind = "rare", sort = "level" })[1].name, "Mystmane", "level 13 = yours")
    local q = ns.Finder:Find({ kind = "quest", sort = "xp" })
    T.eq(q[1].name, "The Missing Scholar")
    T.ok(q[1].xp > q[2].xp)
  end)

  T.it("NPCs from the pack when searching; Places from what you used; every line renders", function()
    local _, ns = session()
    T.ok(has(ns.Finder:Find({ kind = "npc", text = "bread" }), "Ama Breadbaker"))
    ns.db.global.pois = { ["npc-9-vendor"] = { kind = "vendor", mapID = 1412, x = 0.49, y = 0.49, name = "Zerril", title = "Zerril" } }
    local places = ns.Finder:Find({ kind = "place" })
    T.ok(has(places, "Zerril"))
    for _, e in ipairs(ns.Finder:Find({ text = "e" })) do T.ok(type(ns.Finder.Line(e)) == "string") end
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("/ride journey rare lists, then a number starts the guide", function()
    local game, ns = session()
    game:slash("journey rare")
    game:slash("journey 1")
    T.ok(ns.Journey.goal, "guiding")
    T.ok(ns.Waypoints.current, "arrow set")
    T.eq(#ns.Errors.list, 0)
  end)
end)

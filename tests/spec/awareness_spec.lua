-- Suggestions suit the character: faction, race, class and level (Gary, 2026-11-13).
-- Two zones: 1412 has Horde quests and a Horde NPC, 1429 has Alliance ones. Test data.
local T, mock = ...

local function session(faction, raceID, level)
  local opts = { faction = faction, raceID = raceID, level = level or 12, mapID = 1412, x = 0.5, y = 0.5 }
  local game = mock.new(opts)
  game.base.Outrider_DataNPC = { source = "test", maps = {
    [1412] = {
      { 801, "quest_giver", 0.40, 0.40, "Horde Giver", nil, "Horde", {
        { 901, "Horde Errand", 1, 12, "Horde", 0, {}, {}, 0 },
        { 902, "Horde Hunt", 1, 13, "Horde", 0, {}, {}, 0 } } },
      { 802, "vendor", 0.42, 0.42, "Horde Vendor", nil, "Horde", nil },
    },
    [1429] = {
      { 811, "quest_giver", 0.50, 0.50, "Alliance Giver", nil, "Alliance", {
        { 911, "Alliance Errand", 1, 12, "Alliance", 0, {}, {}, 0 },
        { 912, "Alliance Hunt", 1, 13, "Alliance", 0, {}, {}, 0 },
        { 913, "Dwarves Only", 1, 12, "Alliance", 0, {}, {}, 4 } } },
    },
  } }
  rawset(game.env, "Outrider_DataNPC", game.base.Outrider_DataNPC)
  game.mapWorld = { [1412] = { 1, 0, 0 }, [1429] = { 1, 2000, 0 } }
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game:advance(2)
  return game, ns
end

local function names(list) local out = {} for _, e in ipairs(list) do out[e.name] = e end return out end

T.describe("awareness", function()
  T.it("an Alliance character gets Alliance quests and zones only", function()
    local _, ns = session("Alliance", 1) -- human
    local q = names(ns.Finder:Find({ kind = "quest" }))
    T.ok(q["Alliance Errand"] and q["Alliance Hunt"])
    T.eq(q["Horde Errand"], nil)
    T.eq(q["Dwarves Only"], nil, "race-only quest for dwarves hidden from a human")
    local z = ns.Finder:Find({ kind = "zone" })
    T.eq(#z, 1)
    T.eq(z[1].mapID, 1429)
  end)

  T.it("a Horde character gets the Horde side", function()
    local _, ns = session("Horde", 2) -- orc
    local q = names(ns.Finder:Find({ kind = "quest" }))
    T.ok(q["Horde Errand"])
    T.eq(q["Alliance Errand"], nil)
    T.eq(ns.Finder:Find({ kind = "zone" })[1].mapID, 1412)
  end)

  T.it("the race-only quest shows for its race", function()
    local _, ns = session("Alliance", 3) -- dwarf
    T.ok(names(ns.Finder:Find({ kind = "quest" }))["Dwarves Only"])
  end)

  T.it("NPCs and places another character met on the other faction stay hidden", function()
    local _, ns = session("Alliance", 1)
    ns.db.global.discovered = { npcs = {
      [802] = { name = "Horde Vendor", mapID = 1412, x = 0.42, y = 0.42, title = "Goods", roles = { "vendor" } },
      [803] = { name = "Neutral Smith", mapID = 1412, x = 0.43, y = 0.43, title = "Smith", faction = "Neutral", roles = { "vendor" } },
      [804] = { name = "Horde Guard", mapID = 1412, x = 0.44, y = 0.44, faction = "Horde", creatureType = "Humanoid", level = 12 },
    }, recent = {} }
    ns.db.global.pois = {
      ["npc-802-vendor"] = { kind = "vendor", npcID = 802, mapID = 1412, x = 0.42, y = 0.42, title = "Horde Vendor", faction = "Horde" },
      ["npc-803-vendor"] = { kind = "vendor", npcID = 803, mapID = 1412, x = 0.43, y = 0.43, title = "Neutral Smith", faction = "Horde" },
    }
    local npcs = names(ns.Finder:Find({ kind = "npc" }))
    T.eq(npcs["Horde Vendor"], nil, "pack says Horde")
    T.ok(npcs["Neutral Smith"])
    T.eq(names(ns.Finder:Find({ kind = "mob" }))["Horde Guard"], nil)
    local places = names(ns.Finder:Find({ kind = "place" }))
    T.eq(places["Horde Vendor"], nil)
    T.ok(places["Neutral Smith"], "a neutral NPC found by a Horde character still shows")
  end)

  T.it("a new race (Skyborne) still gets quests open to its whole faction", function()
    local game = mock.new({ faction = "Alliance", raceID = 85, level = 12, mapID = 1429, x = 0.5, y = 0.5 })
    game.base.Outrider_DataNPC = { source = "test", maps = { [1429] = {
      { 811, "quest_giver", 0.5, 0.5, "Giver", nil, "Alliance", {
        { 921, "For All Alliance", 1, 12, "Alliance", 0, {}, {}, 77 },
        { 922, "Humans Only", 1, 12, "Alliance", 0, {}, {}, 1 } } } } } }
    rawset(game.env, "Outrider_DataNPC", game.base.Outrider_DataNPC)
    local ns = game:loadAddon()
    game:login()
    local q = names(ns.Finder:Find({ kind = "quest" }))
    T.ok(q["For All Alliance"], "faction-wide mask counts for a new race")
    T.eq(q["Humans Only"], nil)
  end)
end)

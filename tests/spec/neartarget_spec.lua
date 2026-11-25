-- Every "take me there" button goes to the right kind of NPC (Gary, 2026-11-21:
-- the rogue trainer arrow went to the cooking trainer). Places are test data.
local T, mock = ...

local function session(cls, level)
  local game = mock.new({ class = cls or "ROGUE", level = level or 14 })
  local ns = game:loadAddon()
  game:login()
  ns.db.global.pois = {}
  local function put(id, name, title, x, y, note)
    ns.db.global.pois[id] = { id = id, kind = "trainer", mapID = 1412, x = x, y = y, name = name, title = title, note = note }
    if ns.MapPins then ns.MapPins:Invalidate() end -- placed directly, as the addon's own writers then do
  end
  return game, ns, put
end

T.describe("take me there", function()
  T.it("class trainer: the rogue trainer, never the nearer cooking trainer", function()
    local _, ns, put = session("ROGUE")
    put("a", "Aska Mistrunner", "Cooking Trainer", 0.47, 0.38)     -- right next to you
    put("b", "Boarton Shadetotem", "Rogue Trainer", 0.70, 0.70)
    T.eq(ns.Nearest:Find("class_trainer").name, "Boarton Shadetotem")
    T.eq(ns.Nearest:Find("trainer:cooking").name, "Aska Mistrunner")
  end)

  T.it("a starter trainer who teaches only to level 6 is skipped later on", function()
    local _, ns, put = session("ROGUE", 14)
    put("a", "Akeri Duskblade", "Rogue Trainer", 0.47, 0.38, "teaches up to level 6")
    put("b", "Eltheen Nightbreeze", "Rogue Trainer", 0.70, 0.70)
    T.eq(ns.Nearest:Find("class_trainer").name, "Eltheen Nightbreeze")
  end)

  T.it("profession trainers by the game's titles, and only ones that teach the rank you need", function()
    local _, ns, put = session("ROGUE")
    put("a", "Mak", "Journeyman Leatherworker", 0.47, 0.38)
    put("b", "Tarn", "Expert Leatherworker", 0.60, 0.60)
    put("c", "Una", "Artisan Leatherworker", 0.80, 0.80)
    T.eq(ns.Nearest:Find("trainer:leatherworking").name, "Mak", "any leatherworking trainer")
    T.eq(ns.Nearest:Find("trainer:leatherworking:3").name, "Tarn", "Expert needed: the Journeyman can't teach it")
    T.eq(ns.Nearest:Find("trainer:leatherworking:4").name, "Una")
    T.eq(ns.Nearest.NextRank(75), 2)
    T.eq(ns.Nearest.NextRank(150), 3)
    T.eq(ns.Nearest.NextRank(300), nil)
  end)

  T.it("nothing that fits: no arrow, a plain message", function()
    local _, ns, put = session("ROGUE")
    put("a", "Aska Mistrunner", "Cooking Trainer", 0.47, 0.38)
    local p, why = ns.Nearest:Find("class_trainer")
    T.eq(p, nil)
    T.contains(why, "rogue trainer")
  end)

  T.it("Forever titles: a <Fisher> is a fishing trainer", function()
    local _, ns, put = session("ROGUE")
    put("a", "Baelann Swiftcurrent", "Fisher", 0.50, 0.40)
    T.eq(ns.Nearest:Find("trainer:fishing").name, "Baelann Swiftcurrent")
  end)

  T.it("what an NPC was seen teaching beats its title", function()
    local _, ns, put = session("ROGUE")
    put("a", "Odd Title", "Keeper of Secrets", 0.47, 0.38)
    ns.db.global.pois.a.npcID = 5001
    put("b", "Plain", "Rogue Trainer", 0.80, 0.80)
    ns.db.global.pois.b.npcID = 5002
    ns.db.global.teaches = { [5001] = "rogue", [5002] = "cooking" }
    T.eq(ns.Nearest:Find("class_trainer").name, "Odd Title")
    T.eq(ns.Nearest:Find("trainer:cooking").name, "Plain")
  end)
end)


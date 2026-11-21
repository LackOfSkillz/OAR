-- The leveling knowledge base (Data/Leveling.lua, Wowhead's Forever guides,
-- Gary 2026-11-21). Entries come from the guides; the maps below are test maps.
local T, mock = ...

local function session(cls, faction)
  local game = mock.new({ class = cls or "ROGUE", level = 20, faction = faction })
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("leveling knowledge", function()
  T.it("has the guide's zones, places and builds, all unverified", function()
    local _, ns = session()
    T.eq(ns.Data:Get("zoneguide", "Riverglades").lo, 36)
    T.eq(ns.Data:Get("zoneguide", "Riverglades").hi, 44)
    T.eq(ns.Data:Get("zoneguide", "Zephras Isle").hi, 12)
    local fisher = ns.Data:Get("place", "zeph-fennfairweather")
    T.eq(fisher.title, "Fishing Trainer")
    T.ok(math.abs(fisher.x - 0.45) < 1e-9 and math.abs(fisher.y - 0.484) < 1e-9)
    for _, p in ipairs(ns.Data:All("place")) do T.eq(p.verified, false, p.id) end
    local ids = {}
    for _, b in ipairs(ns.Data:All("talentbuild")) do ids[b.id] = b end
    T.ok(ids["warrior-fury"] and ids["shaman-elemental"] and ids["shaman-enhancement"])
    -- one point per level from 10 to 60: 51 points
    for _, id in ipairs({ "warrior-fury", "shaman-elemental", "shaman-enhancement", "shaman-elemental-group" }) do
      local n = 0
      for _, o in ipairs(ids[id].order) do n = n + o[2] end
      T.eq(n, 51, id)
    end
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("the guide's range wins over Classic data, and what you met wins over the guide", function()
    local game, ns = session()
    ns.Travel.ZoneName = function(mapID) return mapID == 1412 and "Riverglades" or "x" end
    ns.ZoneLevels.cache = {}
    local lo, hi, src = ns.ZoneLevels:Range(1412)
    T.eq(src, "guide")
    T.eq(lo, 36) T.eq(hi, 44)
    local npcs = ns.db.global.discovered.npcs
    for i = 1, 10 do npcs[70000 + i] = { mapID = 1412, level = 40, creatureType = "Humanoid", classification = "normal", x = 0.5, y = 0.5, faction = "Neutral" } end
    ns.ZoneLevels.cache = {}
    local _, _, src2 = ns.ZoneLevels:Range(1412)
    T.eq(src2, "seen")
  end)

  T.it("nearest fishing trainer: the guide's spot, unless you recorded him yourself", function()
    local _, ns = session()
    ns.Travel.MapByName = function(_, name) return name == "Zephras Isle" and 1412 or nil end
    local p = ns.Nearest:Find("trainer:fishing")
    T.ok(p and p.guide, "found from the guide")
    ns.db.global.pois = { ["npc-1-trainer"] = { id = "npc-1-trainer", kind = "trainer", mapID = 1412, x = 0.30, y = 0.30,
      name = "Fenn Fairweather", title = "Fishing Trainer" } }
    local mine = ns.Nearest:Find("trainer:fishing")
    T.eq(mine.x, 0.30, "your own sighting wins")
  end)

  T.it("/ride cozy queues the chain in your faction's order", function()
    local _, ns = session("ROGUE", "Horde")
    local steps = ns.LevelRoutes.ChainSteps("cozy", "Horde")
    T.eq(steps[1].zone, "The Barrens")
    T.eq(steps[2].zone, "Westfall")
    local a = ns.LevelRoutes.ChainSteps("cozy", "Alliance")
    T.eq(a[1].zone, "Westfall")
    T.eq(#a, 7)
    T.eq(a[7].zone, "Hillsbrad Foothills")
  end)
end)

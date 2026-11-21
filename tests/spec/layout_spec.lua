-- The 2026-11-20 layout (Gary: "a more logical grouping ... best practice").
-- POIs below are test data.
local T, mock = ...

local function session(cls)
  local game = mock.new({ class = cls or "ROGUE", level = 12 })
  local ns = game:loadAddon()
  game:login()
  ns.Hub:Build()
  return game, ns
end

T.describe("layout", function()
  T.it("Map and places lists your trainers: class, weapon master, secondary professions and the ones you learned", function()
    local _, ns = session("ROGUE")
    ns.db.char.professions = { Skinning = { skill = 40, max = 75 } }
    ns.Hub.frame.tabBar:Select("waypoints")
    local labels = {}
    for _, it in ipairs(ns.ClassPage.PlaceTiles()) do labels[it[1]] = true end
    for _, it in ipairs(ns.ClassPage.TrainerTiles()) do labels[it[1]] = true end
    T.ok(labels["Skinning"], "a profession you learned")
    T.ok(labels["Weapon master"], "weapon master")
    T.ok(labels["Cooking"] and labels["First Aid"] and labels["Fishing"], "secondary professions")
    T.no(labels["Stable"], "no stable for a rogue")
    T.no(labels["Pet trainer"], "no pet trainer for a rogue")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a hunter gets stable, ammo and pet trainer", function()
    local _, ns = session("HUNTER")
    ns.Hub.frame.tabBar:Select("waypoints")
    local labels = {}
    for _, it in ipairs(ns.ClassPage.PlaceTiles()) do labels[it[1]] = true end
    for _, it in ipairs(ns.ClassPage.TrainerTiles()) do labels[it[1]] = true end
    T.ok(labels["Stable"] and labels["Ammo"] and labels["Pet trainer"])
  end)

  T.it("nearest trainer by what it teaches: trainer:fishing finds the Fishing Trainer, not another trainer", function()
    local _, ns = session()
    ns.db.global.pois = {
      ["npc-1-trainer"] = { id = "npc-1-trainer", kind = "trainer", mapID = 1412, x = 0.41, y = 0.41, name = "Near Smith", title = "Blacksmithing Trainer" },
      ["npc-2-trainer"] = { id = "npc-2-trainer", kind = "trainer", mapID = 1412, x = 0.60, y = 0.60, name = "Far Fisher", title = "Fishing Trainer" },
    }
    local p = ns.Nearest:Find("trainer:fishing")
    T.eq(p and p.name, "Far Fisher")
    local none, why = ns.Nearest:Find("trainer:weapon master")
    T.eq(none, nil)
    T.contains(why, "weapon master")
  end)

  T.it("the macro switches live on the Macros page, behind Options", function()
    local _, ns = session("ROGUE")
    ns.Hub.frame.tabBar:Select("macros")
    local p = ns.Hub.byId.macros.panel
    T.no(p.opts:IsShown())
    p.optBtn.__scripts.OnClick(p.optBtn)
    T.ok(p.opts:IsShown())
    T.eq(#p.opts.checks, 3)
    T.eq(#ns.Errors.list, 0)
  end)
end)

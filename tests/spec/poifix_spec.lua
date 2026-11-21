-- Places fix themselves from what you see up close (Gary, 2026-11-20: "the poi
-- for the fishing trainer is wrong ... I'm standing right next to him").
-- NPCs and pack rows below are test data, not game facts.
local T, mock = ...

local function session(withPack)
  local game = mock.new()
  if withPack then
    game.base.Outrider_DataNPC = { source = "test", maps = { [1412] = {
      { 9201, "trainer", 0.20, 0.80, "Test Fisher", "Fishing Trainer", nil },
    } } }
    rawset(game.env, "Outrider_DataNPC", game.base.Outrider_DataNPC)
  end
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game.units = {}
  return game, ns
end

local function fisher(extra)
  local u = { guid = "Creature-0-5250-0-777-9201-00001ABC", name = "Test Fisher", level = 30,
    classification = "normal", creatureType = "Humanoid", title = "Fishing Trainer", faction = "Horde" }
  for k, v in pairs(extra or {}) do u[k] = v end
  return u
end

local function pinOf(ns, name)
  for _, p in ipairs(ns.MapPins:BuildPins(1412)) do if p.name == name then return p end end
end

T.describe("places fix themselves", function()
  T.it("standing next to an NPC is a sure spot; far away it is not", function()
    local game, ns = session()
    game.opts.x, game.opts.y = 0.50, 0.40
    game.units.mouseover = fisher({ near = false })
    game:fire("UPDATE_MOUSEOVER_UNIT")
    local e = ns.db.global.discovered.npcs[9201]
    T.eq(e.quality, "mouseover")
    game.units.mouseover = fisher({ near = true })
    game:fire("UPDATE_MOUSEOVER_UNIT")
    T.eq(e.quality, "near")
    T.eq(e.qualityRank, 3)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("the map pin and the arrow move to where you saw the trainer, over the data pack", function()
    local game, ns = session(true)
    T.eq(pinOf(ns, "Test Fisher").x, 0.20, "the pack's spot before you see him")
    game.opts.x, game.opts.y = 0.55, 0.45
    game.units.target = fisher({ near = true })
    game:fire("PLAYER_TARGET_CHANGED")
    local pin = pinOf(ns, "Test Fisher")
    T.ok(math.abs(pin.x - 0.55) < 1e-9 and math.abs(pin.y - 0.45) < 1e-9, "pin moved to where you stood")
    -- a place of its own (its title says trainer), so it wins everywhere
    local p = ns.db.global.pois["npc-9201-trainer"]
    T.ok(p, "trainer place created from the title")
    T.eq(p.x, 0.55)
    -- the Fishing page's Show the way and the pack's list use it too
    local mapID, x = ns.FishingGuide.Place("Test Fisher")
    T.eq(mapID, 1412)
    T.eq(x, 0.55)
    for _, q in ipairs(ns.NPCPack:OfKind("trainer")) do
      if q.npcID == 9201 then T.eq(q.x, 0.55) end
    end
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("an NPC seen up close far from its old spot moves there; close by it is averaged", function()
    local game, ns = session()
    game.opts.x, game.opts.y = 0.30, 0.30
    game.units.npc = fisher()
    game:fire("TRAINER_SHOW")
    local p = ns.db.global.pois["npc-9201-trainer"]
    T.eq(p.x, 0.30)
    -- a few yards over: averaged
    game.opts.x = 0.31
    game:fire("TRAINER_SHOW")
    T.ok(p.x > 0.30 and p.x < 0.31, "averaged, not moved")
    -- seen right next to him across town: the place moves
    game.opts.x, game.opts.y = 0.70, 0.60
    game.units.mouseover = fisher({ near = true })
    game:fire("UPDATE_MOUSEOVER_UNIT")
    local e = ns.db.global.discovered.npcs[9201]
    T.eq(e.x, 0.70)
    T.eq(p.x, 0.70)
    T.eq(p.y, 0.60)
    -- and talking to him there again doesn't drag him back
    game:fire("TRAINER_SHOW")
    T.ok(math.abs(p.x - 0.70) < 1e-9)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("in combat nothing is range-checked", function()
    local game, ns = session()
    game.combat = true
    game.units.target = fisher({ near = true })
    game:fire("PLAYER_TARGET_CHANGED")
    T.eq(ns.db.global.discovered.npcs[9201].quality, "target")
    T.eq(ns.db.global.pois["npc-9201-trainer"], nil)
  end)
end)

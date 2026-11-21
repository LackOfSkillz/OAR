-- Competitive gap batch #16-24: safety, real data boundaries and persistence.
local T, mock = ...

local function session(before)
  local game = mock.new({ class = "HUNTER", level = 20 })
  if before then before(game) end
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("batch4 read-only combat", function()
  T.it("Auto Shot gives hints only with a readable ranged API", function()
    local g, ns = session(function(game)
      game.base.UnitRangedDamage = function() return 2.8 end
      game.base.GetUnitSpeed = function() return 7 end
      rawset(game.env, "UnitRangedDamage", game.base.UnitRangedDamage)
      rawset(game.env, "GetUnitSpeed", game.base.GetUnitSpeed)
    end)
    local state = ns.HunterFight:ShotReadiness()
    T.eq(state.known, true)
    T.eq(state.speed, 2.8)
    T.eq(state.moving, true)
    T.eq(state.inRange, nil, "no guessed target range without readable API")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("Auto Shot hint stays quiet out of combat and without an enemy target", function()
    local canAttack = false
    local g, ns = session(function(game)
      game.base.UnitRangedDamage = function() return 2.8 end
      game.base.GetUnitSpeed = function() return 7 end
      game.base.UnitCanAttack = function() return canAttack end
      for _, k in ipairs({ "UnitRangedDamage", "GetUnitSpeed", "UnitCanAttack" }) do rawset(game.env, k, game.base[k]) end
    end)
    rawset(g.env, "SwingTimerRanged", g.env.CreateFrame("Frame"))
    local M = ns.HunterFight
    local frame = M:ShotOverlay()
    T.ok(frame, "overlay built on the ranged swing timer")
    M:UpdateShotOverlay()
    T.eq(frame.label:GetText(), "", "moving out of combat: no hint")
    g:setCombat(true)
    M:UpdateShotOverlay()
    T.eq(frame.label:GetText(), "", "in combat, no enemy target: no hint")
    canAttack = true
    M:UpdateShotOverlay()
    T.contains(frame.label:GetText(), "Stop moving")
    g:setCombat(false)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("threat status distinguishes player and pet and leaves nameplates unchanged", function()
    local g, ns = session(function(game)
      game.base.UnitDetailedThreatSituation = function(who)
        if who == "player" then return false, 1, 45 end
        if who == "pet" then return true, 3, 100 end
      end
      rawset(game.env, "UnitDetailedThreatSituation", game.base.UnitDetailedThreatSituation)
    end)
    local M = ns.RarePlates
    local x = M:ThreatStatus("nameplate1")
    T.eq(x.owner, "pet")
    T.eq(x.pet.pct, 100)
    g.units = { nameplate1 = { guid = "Creature-0-1-0-1-777-001", name = "Wolf", classification = "normal" } }
    g:fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    T.ok(M.threatMarkers.nameplate1)
    g:fire("UNIT_THREAT_SITUATION_UPDATE", "nameplate1")
    g:fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    T.eq(M.threatMarkers.nameplate1, nil)
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("batch4 graveyard evidence", function()
  T.it("learns the subzone's actual ghost arrival instead of guessing nearest healer", function()
    local g, ns = session(function(game)
      game.base.GetSubZoneText = function() return "The Crossroads" end
      game.base.UnitIsGhost = function() return game.ghost or false end
      rawset(game.env, "GetSubZoneText", game.base.GetSubZoneText)
      rawset(game.env, "UnitIsGhost", game.base.UnitIsGhost)
    end)
    local M = ns.Nearest
    T.eq(M:PredictedGraveyard(1412, "The Crossroads"), nil)
    g.opts.x, g.opts.y = 0.3, 0.4
    g:fire("PLAYER_DEAD")
    g.ghost = true
    g.opts.x, g.opts.y = 0.52, 0.66
    g:fire("PLAYER_ALIVE")
    local p = M:PredictedGraveyard(1412, "The Crossroads")
    T.ok(p)
    T.eq(p.x, 0.52)
    T.eq(p.y, 0.66)
    T.eq(p.count, 1)
    g.ghost = false
    g:fire("PLAYER_UNGHOST")
    T.eq(#ns.db.global.deathHistory, 1)
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("batch4 training and dungeon data", function()
  T.it("never invents trainer services; observed services become future level cards", function()
    local g, ns = session(function(game)
      game.base.GetNumTrainerServices = function() return 1 end
      game.base.GetTrainerServiceInfo = function()
        return "Cited Test Spell", "Rank 1", "available", false
      end
      game.base.GetTrainerServiceLevelReq = function() return 22 end
      rawset(game.env, "GetTrainerServiceLevelReq", game.base.GetTrainerServiceLevelReq)
      game.base.GetTrainerServiceCost = function() return 550 end
      rawset(game.env, "GetNumTrainerServices", game.base.GetNumTrainerServices)
      rawset(game.env, "GetTrainerServiceInfo", game.base.GetTrainerServiceInfo)
      rawset(game.env, "GetTrainerServiceCost", game.base.GetTrainerServiceCost)
    end)
    T.eq(ns.Spellbook:TrainingAt(22)[1], nil)
    g:fire("TRAINER_SHOW")
    g:advance(0.5)
    local rows = ns.Spellbook:TrainingAt(22)
    T.eq(rows[1].name, "Cited Test Spell")
    T.eq(rows[1].cost, 550)
    T.eq(rows[1].source, "your class trainer")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("links boss kill quests and returns boss loot from the installed data", function()
    local g, ns = session(function(game)
      game.base.Outrider_DataDungeons = { source = "test", dungeons = {
        [100] = { name = "Test Dungeon", map = 1412, x = 0.4, y = 0.5,
          bosses = { { 999, "Boss Nine", 20, 1, { 9001 } } },
          items = { [9001] = { "Hunter Bow", 18 } } },
      } }
      game.base.Outrider_DataQuests = { source = "test", quests = {
        [801] = { "Defeat Boss Nine", 20, { { "npc", 999, "Kill Boss Nine" } } },
      }, info = {}, npcs = {}, objects = {}, items = {} }
      rawset(game.env, "Outrider_DataDungeons", game.base.Outrider_DataDungeons)
      rawset(game.env, "Outrider_DataQuests", game.base.Outrider_DataQuests)
    end)
    local q = ns.DungeonGuide:QuestList("Test Dungeon")
    T.eq(#q, 1)
    T.eq(q[1].id, 801)
    T.eq(q[1].source, "boss objective")
    local loot = ns.DungeonGuide:BossLoot("Boss Nine")
    T.eq(loot[1].id, 9001)
    T.eq(loot[1].name, "Hunter Bow")
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("batch4 route, gear and map notes", function()
  T.it("queues only known rare spawn coordinates and reuses waypoint queue", function()
    local g, ns = session()
    ns.MapPins.BuildPins = function() return {
      { kind = "rare", id = "rare-77119", npcID = 77119, name = "Route Rare",
        mapID = 1412, x = 0.55, y = 0.46 },
    } end
    local points = ns.Modules:Get("RareScan"):Route(1412, false)
    T.ok(#points >= 1)
    T.ok(#ns.Waypoints:Settings().queue >= 1)
    T.eq(ns.Waypoints.current, nil, "route doesn't auto-run without player request")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("groups available quest XP by zone with explicit estimate caveat", function()
    local g, ns = session()
    ns.NPCPack.AvailableEverywhere = function() return {
      { mapID = 1412, level = 20, diff = "yellow" },
      { mapID = 1412, level = 18, diff = "green" },
      { mapID = 1413, level = 3, diff = "grey" },
    } end
    local rows = ns.Journey:ZoneOutlook()
    T.eq(rows[1].mapID, 1412)
    T.eq(rows[1].count, 2)
    T.ok(rows[1].estimatedXP > 0)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("saves wish list; authored notes can be edited and removed", function()
    local g, ns = session()
    local B, M = ns.BagExtras, ns.MapTab
    T.ok(B:Wish(9001, true))
    T.ok(B:Wishlist()[9001])
    T.eq(B:Wishes()[1].id, 9001)
    local id = M:AddNote(1412, 0.4, 0.5, "Visit the cave")
    T.ok(id)
    T.eq(M:NotesFor(1412)[1].name, "Visit the cave")
    T.ok(M:EditNote(id, "Cave entrance"))
    T.eq(M:NotesFor(1412)[1].name, "Cave entrance")
    local found = false
    for _, p in ipairs(ns.MapPins:BuildPins(1412)) do
      if p.kind == "note" and p.name == "Cave entrance" then found = true end
    end
    T.ok(found)
    T.ok(M:RemoveNote(id))
    T.eq(#M:NotesFor(1412), 0)
    T.eq(#ns.Errors.list, 0)
  end)
end)

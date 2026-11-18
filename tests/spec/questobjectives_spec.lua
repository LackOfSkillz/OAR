-- Quest objectives on the map from the private quest pack (2026-11-17).
-- The pack below is test data shaped like tools/import_questie_quests.py output.
local T, mock = ...

local function start()
  local game = mock.new({ class = "HUNTER", level = 20 })
  local pack = { source = "test",
    quests = {
      [3741] = { "Hilary's Necklace", 15, { { "item", 10958 } }, fin = { 8962 } },
      [102] = { "Done Already", 10, {}, fin = { 8962 } },
      [100] = { "Wolf Trouble", 8, { { "npc", 2958, "Prairie Wolf slain" } } },
      [101] = { "Look Around", 8, {}, explore = { "Scout the lake", 1433, 0.2, 0.5 } },
    },
    npcs = { [2958] = { "Prairie Wolf", { [1412] = { 0.4, 0.5, 0.42, 0.52 } } },
      [8962] = { "Hilary", { [1433] = { 0.28, 0.48 } } } },
    starters = { [31] = { { 248, "Wanted: Poster", 15, 21, nil, 0, {}, {}, 0 } } },
    objects = { [154357] = { "Glinting Mud", { [1433] = { 0.168, 0.532, 0.229, 0.56 } } },
      [31] = { "Wanted Board", { [1433] = { 0.3, 0.45 } } } },
    items = { [10958] = { "Hilary's Necklace", {}, { 154357 } } },
  }
  game.base.Outrider_DataQuests = pack
  rawset(game.env, "Outrider_DataQuests", pack)
  game.questLog = {
    { title = "Hilary's Necklace", questID = 3741 },
    { title = "Wolf Trouble", questID = 100 },
    { title = "Look Around", questID = 101 },
    { title = "Done Already", questID = 102, isComplete = true },
  }
  game.questObjectives = {
    [3741] = { { text = "Hilary's Necklace: 0/1", finished = false } },
    [100] = { { text = "Prairie Wolf slain: 8/8", finished = true } },
    [101] = { { text = "Scout the lake", finished = false } },
  }
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.QuestObjectives
end

T.describe("quest objectives", function()
  T.it("pins the unfinished objectives of your quests on their maps", function()
    local game, ns, M = start()
    local lake = M:Pins(1433)
    local mud, explore = 0, 0
    for _, p in ipairs(lake) do
      if p.name == "Hilary's Necklace" then mud = mud + 1 T.contains(p.title, "in Glinting Mud") end
      if p.name == "Scout the lake" then explore = explore + 1 end
    end
    T.eq(mud, 2)
    T.eq(explore, 1)
    T.eq(#M:Pins(1412), 0, "the wolves are done")
    -- MapPins shows them too
    local seen = false
    for _, p in ipairs(ns.MapPins:PinsFor(1433)) do if p.kind == "objective" then seen = true end end
    T.ok(seen)
    M:Settings().show = false
    T.eq(#M:Pins(1433), 0)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("mousing over a quest object alerts once and saves the spot", function()
    local game, ns, M = start()
    local line = game.base.CreateFrame("Frame")
    line.GetText = function() return "Glinting Mud" end
    rawset(game.env, "GameTooltipTextLeft1", line)
    local tt = { GetUnit = function() return nil end }
    M:OnTooltip(tt)
    T.ok(M.seen["Glinting Mud"] and #M.seen["Glinting Mud"] == 1)
    T.contains(ns.Toast.visible[1].title:GetText(), "Glinting Mud is here")
    local n = #ns.Toast.visible
    M:OnTooltip(tt)
    T.eq(#ns.Toast.visible, n, "no second alert within a minute")
    line.GetText = function() return "Some Rock" end
    game.now = game.now + 120
    M:OnTooltip(tt)
    T.eq(#ns.Toast.visible, n)
  end)
end)

T.describe("quest objectives: Questie parity", function()
  T.it("finished quests get a turn-in pin; objects that give quests get a quest giver pin", function()
    local game, ns, M = start()
    local turnin, giver = 0, 0
    for _, p in ipairs(M:Pins(1433)) do
      if p.kind == "turnin" then turnin = turnin + 1 T.contains(p.title, "Done Already") T.contains(p.title, "Hilary") end
      if p.kind == "quest_giver" then giver = giver + 1 T.eq(p.quests[1].name, "Wanted: Poster") end
    end
    T.eq(turnin, 1)
    T.eq(giver, 1)
  end)

  T.it("tooltips say which quest needs a mob, an object or an item", function()
    local game, ns, M = start()
    T.eq(#M:LinesFor("npc", 2958), 0, "wolves done")
    local obj = M:LinesFor("object", "Glinting Mud")
    T.eq(#obj, 1)
    T.contains(obj[1][1], "Hilary's Necklace: 0/1")
    T.eq(#M:LinesFor("item", 10958), 1)
  end)

  T.it("Go puts the arrow on the nearest objective, or the turn-in when done", function()
    local game, ns, M = start()
    local spot = M:Nearest(3741)
    T.eq(spot.mapID, 1433)
    T.eq(spot.label, "Hilary's Necklace")
    local hand = M:Nearest(102)
    T.contains(hand.label, "Hand in")
    T.ok(M:Guide(3741))
    ns.Hub:Toggle()
    ns.Hub:ShowTab("quests")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a quest whose objectives are all done counts as ready even when the client leaves isComplete empty", function()
    local game, ns, M = start()
    game.questObjectives[3741] = { { text = "Hilary's Necklace: 1/1", finished = true } }
    local spot = M:Nearest(3741)
    T.contains(spot.label, "Hand in", "the turn-in, not a vanished marker")
    T.eq(ns.QuestTracker.Read()[1].quests[1].complete, true, "tracker agrees")
  end)

  T.it("1 of 5 collected is never done, whatever the flags or other signals say (every quest)", function()
    local game, ns, M = start()
    local CQ = game.env.C_QuestLog
    -- the client's flag says finished but the count says 1/5
    game.questObjectives[3741] = { { text = "Crisp Spider Meat: 1/5", finished = true } }
    T.eq(M.Objectives(3741)[1].finished, false)
    T.eq(M:Nearest(3741).label, "Hilary's Necklace", "still points at the objective")
    -- counts from numFulfilled/numRequired win over the text and the flag
    game.questObjectives[3741] = { { text = "Crisp Spider Meat", finished = true, numFulfilled = 1, numRequired = 5 } }
    T.eq(M.Objectives(3741)[1].finished, false)
    -- old Classic-style values from the other signals (-1 failed, 0) never mark it done
    game.questObjectives[3741] = { { text = "Crisp Spider Meat: 1/5", finished = false } }
    CQ.IsComplete = function() return -1 end
    CQ.ReadyForTurnIn = function() return 0 end
    game.questLog[1].isComplete = 1
    T.eq(M.Log()[1].complete, false, "an unfinished objective vetoes every other signal")
    T.eq(ns.QuestTracker.Read()[1].quests[1].complete, false, "tracker agrees")
    -- 5/5 with no flag at all is done
    game.questObjectives[3741] = { { text = "Crisp Spider Meat: 5/5" } }
    T.eq(M.Log()[1].complete, true)
  end)

  T.it("a quest without objectives counts as done only on a real true or 1", function()
    local game, ns, M = start()
    local CQ = game.env.C_QuestLog
    game.questObjectives[3741] = {}
    CQ.IsComplete = function() return -1 end
    T.eq(M.Log()[1].complete, false, "-1 is failed, not done")
    CQ.IsComplete = function() return 1 end
    T.eq(M.Log()[1].complete, true)
  end)

  T.it("clicking a quest tracks it with the game's own arrow and area, like the world map", function()
    local game, ns, M = start()
    T.ok(M:Guide(3741))
    T.eq(game.trackedQuest, 3741, "the game tracks the quest")
    T.eq(ns.Waypoints.current, nil, "no second arrow from Outrider")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("when a quest becomes ready the arrow moves to its turn-in, but never over your own waypoint", function()
    local game, ns, M = start()
    -- without the game's quest tracking, Outrider's own arrow does the job
    game.env.C_SuperTrack.SetSuperTrackedQuestID = nil
    game:fire("QUEST_LOG_UPDATE") game:advance(1)
    T.ok(M:Guide(3741), "arrow on the necklace")
    T.eq(ns.Waypoints.current.title, "Hilary's Necklace")
    game.questObjectives[3741] = { { text = "Hilary's Necklace: 1/1", finished = true } }
    game:fire("QUEST_LOG_UPDATE") game:advance(1)
    T.contains(ns.Waypoints.current.title, "Hand in", "arrow moved to the turn-in by itself")
    -- your own waypoint stays put
    local game2, ns2, M2 = start()
    game2.env.C_SuperTrack.SetSuperTrackedQuestID = nil
    game2:fire("QUEST_LOG_UPDATE") game2:advance(1)
    ns2.Waypoints:Set(1433, 0.5, 0.5, "My spot")
    game2.questObjectives[3741] = { { text = "Hilary's Necklace: 1/1", finished = true } }
    game2:fire("QUEST_LOG_UPDATE") game2:advance(1)
    T.eq(ns2.Waypoints.current.title, "My spot")
    T.eq(#ns.Errors.list + #ns2.Errors.list, 0)
  end)
end)

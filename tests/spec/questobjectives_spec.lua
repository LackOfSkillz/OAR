-- Quest objectives on the map from the private quest pack (2026-11-17).
-- The pack below is test data shaped like tools/import_questie_quests.py output.
local T, mock = ...

local function start()
  local game = mock.new({ class = "HUNTER", level = 20 })
  local pack = { source = "test",
    quests = {
      [3741] = { "Hilary's Necklace", 15, { { "item", 10958 } } },
      [100] = { "Wolf Trouble", 8, { { "npc", 2958, "Prairie Wolf slain" } } },
      [101] = { "Look Around", 8, {}, explore = { "Scout the lake", 1433, 0.2, 0.5 } },
    },
    npcs = { [2958] = { "Prairie Wolf", { [1412] = { 0.4, 0.5, 0.42, 0.52 } } } },
    objects = { [154357] = { "Glinting Mud", { [1433] = { 0.168, 0.532, 0.229, 0.56 } } } },
    items = { [10958] = { "Hilary's Necklace", {}, { 154357 } } },
  }
  game.base.Outrider_DataQuests = pack
  rawset(game.env, "Outrider_DataQuests", pack)
  game.questLog = {
    { title = "Hilary's Necklace", questID = 3741 },
    { title = "Wolf Trouble", questID = 100 },
    { title = "Look Around", questID = 101 },
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

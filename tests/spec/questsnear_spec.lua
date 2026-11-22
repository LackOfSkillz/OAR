-- Quests, Near me (Gary, 2026-11-21: by Undercity, the quest page sent him
-- back to Orgrimmar). Test pack shaped like tools/import_questie_quests.py output.
-- Maps: 1412 (where you stand) and 1433 side by side on continent 1, 1456 on continent 2.
local T, mock = ...

local function start()
  local game = mock.new({ class = "HUNTER", level = 12, mapID = 1412, x = 0.5, y = 0.5 })
  game.mapWorld = { [1412] = { 1, 0, 0 }, [1433] = { 1, 1000, 0 }, [1456] = { 2, 0, 0 } }
  local pack = { source = "test",
    quests = {
      [500] = { "Near Wolves", 12, { { "npc", 2958, "Wolf slain" } } },
      [501] = { "Far Errand", 12, { { "npc", 2959, "Kodo slain" } } },
      [502] = { "Done Deal", 11, {}, fin = { 8962 } },
    },
    npcs = { [2958] = { "Wolf", { [1412] = { 0.52, 0.5 }, [1456] = { 0.5, 0.5 } } },
      [2959] = { "Kodo", { [1456] = { 0.4, 0.4 } } },
      [8962] = { "Hilary", { [1433] = { 0.1, 0.5 } } } },
    starters = {}, objects = {}, items = {},
  }
  game.base.Outrider_DataQuests = pack
  rawset(game.env, "Outrider_DataQuests", pack)
  game.questLog = {
    { title = "Near Wolves", questID = 500 },
    { title = "Far Errand", questID = 501 },
    { title = "Done Deal", questID = 502, isComplete = true },
  }
  game.questObjectives = {
    [500] = { { text = "Wolf slain: 0/5", finished = false } },
    [501] = { { text = "Kodo slain: 0/5", finished = false } },
  }
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.QuestsNear
end

T.describe("quests near me", function()
  T.it("Go to nearest picks the closest spot, on another map too, not the first one found", function()
    local game, ns = start()
    local spot = ns.QuestObjectives:Nearest(500)
    T.eq(spot.mapID, 1412, "the wolves here, not on the other continent")
    -- standing on the neighbouring map: the turn-in there wins over nothing
    game.opts.mapID, game.opts.x = 1433, 0.2
    local hand = ns.QuestObjectives:Nearest(502)
    T.eq(hand.mapID, 1433)
    T.ok(hand.yards and hand.yards < 200, "a real distance in yards")
  end)

  T.it("ranks what's close and fits your level first, and says why", function()
    local _, ns, M = start()
    local list = M:List()
    T.ok(#list >= 2, "quests listed")
    local pos = {}
    for i, e in ipairs(list) do pos[e.questID] = i end
    T.ok(pos[500] and pos[502], "near quests are there")
    if pos[501] then T.ok(pos[500] < pos[501], "the one across the sea comes after the one next to you") end
    T.ok(list[1].xp > 0, "an XP estimate when the game gives none")
    local title, sub = M.Line(list[1])
    T.ok(title ~= "" and sub:find("XP a minute", 1, true), "XP per minute shown")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("is the first tab of Quests, and a click guides the quest", function()
    local game, ns, M = start()
    ns.Hub:Build():Show()
    ns.Hub:ShowTab(ns.Hub.LastSub("quests"))
    T.eq(ns.Hub.current, "questsnear", "Quests opens on Near me")
    local guided
    ns.QuestObjectives.Guide = function(_, id) guided = id return true end
    local e = M:List()[1]
    M:Go(e)
    if e.kind == "log" then T.eq(guided, e.questID) end
    T.eq(#ns.Errors.list, 0)
  end)
end)

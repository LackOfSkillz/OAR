-- Quest givers colored by level (Gary, 2026-11-11). Rows are test data.
local T, mock = ...

local function session(level)
  local game = mock.new({ level = level })
  game.base.Outrider_DataNPC = { source = "test", maps = { [1412] = {
    { 9201, "quest_giver", 0.40, 0.40, "On Level", nil, "Horde", {
      { 1, "Yellow Quest", 10, 12, "Horde", 0, {}, {} },
      { 2, "Red Quest", 10, 18, "Horde", 0, {}, {} } } },
    { 9202, "quest_giver", 0.41, 0.41, "All Done", nil, "Horde", { { 3, "Finished", 1, 5, nil, 0, {}, {} } } },
    { 9203, "quest_giver", 0.42, 0.42, "Too High", nil, "Horde", { { 4, "Later", 20, 22, nil, 0, {}, {} } } },
    { 9204, "quest_giver", 0.43, 0.43, "Chain", nil, nil, {
      { 5, "Part Two", 1, 11, nil, 0, { 3 }, {} },
      { 6, "Part Three", 1, 11, nil, 0, { 99 }, {} } } },
    { 9205, "quest_giver", 0.44, 0.44, "Mage Only", nil, nil, { { 7, "Arcane Stuff", 1, 12, nil, 128, {}, {} } } },
    { 9206, "quest_giver", 0.45, 0.45, "Old Stuff", nil, nil, { { 8, "Rats", 1, 2, nil, 0, {}, {} } } },
  } } }
  rawset(game.env, "Outrider_DataNPC", game.base.Outrider_DataNPC)
  game.questsDone = { [3] = true }
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

local function byName(ns)
  local out = {}
  for _, p in ipairs(ns.MapPins:PinsFor(1412)) do out[p.name] = p end
  return out
end

T.describe("quest pins", function()
  T.it("colors by the best quest for your level and hides givers with nothing to offer", function()
    local _, ns = session(12)
    local pins = byName(ns)
    T.eq(pins["On Level"].quests[1].name, "Yellow Quest")
    T.eq(pins["On Level"].quests[2].diff, "red")
    T.same(pins["On Level"].questColor, ns.NPCPack.DIFF_COLOR.yellow)
    T.eq(pins["All Done"], nil, "completed")
    T.eq(pins["Too High"], nil, "required level 20")
    T.eq(#pins["Chain"].quests, 1, "Part Three needs quest 99 first")
    T.eq(pins["Mage Only"], nil, "class quest for mages")
    T.eq(pins["Old Stuff"], nil, "grey hidden by default")
    T.contains(ns.MapPins.QuestLines(pins["On Level"])[1], "[12] Yellow Quest")
  end)

  T.it("game color rules and the grey switch", function()
    local game, ns = session(12)
    local D = ns.NPCPack.Difficulty
    T.eq(D(17, 12), "red") T.eq(D(15, 12), "orange") T.eq(D(10, 12), "yellow") T.eq(D(8, 12), "green") T.eq(D(5, 12), "grey")
    game:slash("questpins grey on")
    T.ok(byName(ns)["Old Stuff"])
    game.questsActive = { [1] = true }
    game:fire("QUEST_ACCEPTED", 1)
    T.eq(byName(ns)["On Level"].quests[1].name, "Red Quest", "quest in your log no longer offered")
    T.eq(#ns.Errors.list, 0)
  end)
end)

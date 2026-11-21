-- Quest chains step by step (Gary, 2026-11-21). Test data shaped like the
-- quest pack, modelled on Gary's stuck quests: A Grand Adventure (needs 92700
-- first) and The Earthen Ring (needs 93090 first, handed in in Mulgore).
local T, mock = ...

local function start(done)
  local game = mock.new({ class = "ROGUE", level = 14 })
  local pack = { source = "test",
    quests = {
      [92700] = { "Before the Adventure", 10, {}, fin = { 251968 } },
      [92708] = { "A Grand Adventure", 12, {}, fin = { 251968 } },
      [93090] = { "Earth Calls", 12, {}, fin = { 251968 } },
      [95349] = { "The Earthen Ring", 13, {}, fin = { 259119 } },
      [95350] = { "Welcome to Azeroth", 13, {}, fin = { 259119 } },
    },
    info = { [92708] = { pa = { 92700 } }, [95349] = { pa = { 93090 }, n = 95350 }, [93090] = { pl = { 92708 } } },
    npcs = { [251968] = { "Ayessa Dawnsinger", { [2521] = { 0.5915, 0.7978 } } },
      [259119] = { "Alaana Stormwalker", { [1412] = { 0.3339, 0.2251 } } } },
    starters = {}, objects = {}, items = {},
  }
  game.base.Outrider_DataQuests = pack
  rawset(game.env, "Outrider_DataQuests", pack)
  local npc = { source = "test", maps = { [2521] = {
    { 251968, "quest_giver", 0.5915, 0.7978, "Ayessa Dawnsinger", "Grand Skyseer", "Horde", { { 92708, "A Grand Adventure", 7, 12, "Horde", 0, { 92700 }, {}, 0 }, { 95349, "The Earthen Ring", 7, 13, "Horde", 0, { 93090 }, {}, 0 }, { 93090, "Earth Calls", 7, 12, "Horde", 0, {}, {}, 0 } } },
  }, [1412] = {
    { 259119, "quest_giver", 0.3339, 0.2251, "Alaana Stormwalker", "Windshapers", "Horde", { { 95350, "Welcome to Azeroth", 7, 13, nil, 0, {}, {}, 0 } } },
  } } }
  game.base.Outrider_DataNPC = npc
  rawset(game.env, "Outrider_DataNPC", npc)
  game.questLog = { { title = "The Earthen Ring", questID = 95349, isComplete = true } }
  game.questsDone = done or { [92700] = true, [92708] = true, [93090] = true }
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.QuestChains
end

T.describe("quest chains", function()
  T.it("the whole chain, oldest first, with each step's status", function()
    local _, ns, Q = start()
    local steps = Q:Steps(95349)
    local names, status = {}, {}
    for i, s in ipairs(steps) do names[i] = s.name status[i] = s.status end
    T.same(names, { "Before the Adventure", "A Grand Adventure", "Earth Calls", "The Earthen Ring", "Welcome to Azeroth" })
    T.same(status, { "done", "done", "done", "ready", "locked" })
    T.eq(steps[4].where.name, "Alaana Stormwalker", "hand it in in Mulgore, not to Ayessa")
    T.eq(steps[5].where.name, "Alaana Stormwalker", "the next quest's giver")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a missed step shows: A Grand Adventure not done locks the rest", function()
    local _, _, Q = start({ [92700] = true })
    local st = {}
    for _, s in ipairs(Q:Steps(95349)) do st[s.name] = s.status end
    T.eq(st["A Grand Adventure"], "available")
    T.eq(st["Earth Calls"], "locked")
  end)

  T.it("the Chains tab lists log quests that are part of a chain; clicking a step sets the arrow", function()
    local game, ns = start({ [92700] = true })
    ns.Hub:Build()
    ns.Hub.frame.tabBar:Select("questchains")
    local p = ns.Hub.byId.questchains.panel
    T.eq(#p.list.items, 1)
    T.contains(p.card.sub:GetText(), "steps done")
    -- step 2, A Grand Adventure, is to pick up from Ayessa
    p.card.steps.rowFrames[2].__scripts.OnClick(p.card.steps.rowFrames[2])
    T.ok(ns.Waypoints.current and ns.Waypoints.current.title:find("Ayessa"), "arrow to Ayessa")
    T.eq(#ns.Errors.list, 0)
  end)
end)

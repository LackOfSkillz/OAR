-- Dungeon quests and keys (Attune-level page, Gary 2026-11-21). Uses the real
-- guide data (mock.new({ guides = true })); quest log and history are test data.
local T, mock = ...

local function session(level, faction)
  local game = mock.new({ class = "ROGUE", level = level or 14, faction = faction, guides = true })
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("dungeon quests", function()
  T.it("each dungeon has its quests for your side, sorted by level, from the guides", function()
    local _, ns = session(14, "Horde")
    local rfc
    for _, d in ipairs(ns.DungeonQuests:Chains("Horde")) do if d.name == "Ragefire Chasm" then rfc = d end end
    T.ok(rfc, "Ragefire Chasm")
    T.eq(rfc.lo, 13)
    T.ok(#rfc.steps >= 3)
    for _, s in ipairs(rfc.steps) do T.ok(s.faction == nil or s.faction == "Horde") end
    local hot
    for _, d in ipairs(ns.DungeonQuests:Chains("Horde")) do if d.name == "The Hall of Thanes" then hot = d end end
    for _, s in ipairs(hot and hot.steps or {}) do T.ok(s.faction ~= "Alliance", "no Alliance quests for Horde") end
  end)

  T.it("status: handed in = done, in the log = in your log, far above you = later", function()
    local _, ns = session(14, "Horde")
    local D = ns.DungeonQuests
    ns.db.global.questHistory[ns.db.key] = { { name = "Slaying the Beast", what = "handed in", t = 1 } }
    local ctx = D:Context()
    ctx.log["Hidden Enemies"] = true
    T.eq(D:Status({ quest = "Slaying the Beast", level = 9 }, ctx), "done")
    T.eq(D:Status({ quest = "Hidden Enemies", level = 9 }, ctx), "active")
    T.eq(D:Status({ quest = "Something", level = 30 }, ctx), "later")
    T.eq(D:Status({ quest = "Something", level = 15 }, ctx), "todo")
  end)

  T.it("the page: list, detail with Go buttons, won't do hides a dungeon, Next names one", function()
    local game, ns = session(14, "Horde")
    ns.Hub:Build()
    ns.Hub.frame.tabBar.buttons.dungeons.__scripts.OnClick(ns.Hub.frame.tabBar.buttons.dungeons)
    T.eq(ns.Hub.current, "dungeonquests", "the sidebar opens Quests and keys first")
    local p = ns.Hub.byId.dungeonquests.panel
    T.ok(#p.list.items > 0)
    T.ok(p.d and #p.d.steps > 0)
    T.contains(p.next:GetText(), "Next:")
    local first = p.d.name
    p.card.wont.__scripts.OnClick(p.card.wont)
    for _, d in ipairs(p.list.items) do T.ok(d.name ~= first, "hidden after Won't do") end
    -- clicking a quest sets the arrow when its zone is on the map list
    ns.Travel.MapByName = function() return 1411 end
    p:Show1(p.list.items[1])
    p.card.steps.rowFrames[1].__scripts.OnClick(p.card.steps.rowFrames[1])
    T.ok(ns.Waypoints.current, "arrow set")
    T.eq(#ns.Errors.list, 0)
  end)
end)

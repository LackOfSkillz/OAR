-- Player-requested improvements: tooltip gating, Feign Death guard,
-- and quest references for items outside the active log.
local T, mock = ...

local function session(opts)
  local g = mock.new(opts or { class = "HUNTER", level = 20 })
  local ns = g:loadAddon()
  g:login()
  return g, ns
end

T.describe("Shift-gated tooltip extras", function()
  T.it("preserves defaults, limits each source, can suppress an individual provider", function()
    local g, ns = session()
    local TL = ns.TooltipLines
    local tip = g.env.GameTooltip
    local fake = { enabled = true }
    TL:Add("item", "beast", fake, function()
      return { { "first drop", "good" }, { "second drop", "good" }, { "third drop", "good" } }
    end)
    TL.providers.item = { TL.providers.item[#TL.providers.item] }
    T.eq(#TL:Lines("item", tip, { id = 90 }), 3)
    TL:Settings().limit = 2
    T.eq(#TL:Lines("item", tip, { id = 90 }), 2)
    TL:Settings().shiftOnly = true
    T.eq(#TL:Lines("item", tip, { id = 90 }), 0)
    g.shift = true
    T.eq(#TL:Lines("item", tip, { id = 90 }), 2)
    T.ok(TL:SetEnabled("beast", false))
    T.eq(#TL:Lines("item", tip, { id = 90 }), 0)
    T.ok(TL:SetEnabled("beast", true))
    T.eq(#TL:Lines("item", tip, { id = 90 }), 2)
    T.no(TL:SetEnabled("not-a-real-key", false))
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("slash controls and per-character settings do not change combat-hide behavior", function()
    local g, ns = session()
    g:slash("toolextras shift")
    T.eq(ns.TooltipLines:Settings().shiftOnly, true)
    g:slash("toolextras limit 2")
    T.eq(ns.TooltipLines:Settings().limit, 2)
    g:slash("toolextras hide questuses")
    T.no(ns.TooltipLines:Enabled("questuses"))
    g:slash("toolextras show questuses")
    T.ok(ns.TooltipLines:Enabled("questuses"))
    g:slash("toolextras always")
    T.eq(ns.TooltipLines:Settings().shiftOnly, false)
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("Feign Death never trains graveyard map", function()
  T.it("ignores false death event when alive and drops delayed context", function()
    local g, ns = session()
    local N = ns.Nearest
    rawset(g.env, "UnitIsDeadOrGhost", function() return false end)
    rawset(g.env, "UnitIsGhost", function() return false end)
    g:fire("PLAYER_DEAD")
    T.eq(N.deathLog, nil)
    g:advance(0.4)
    T.eq(N.pendingDeath, nil)
    T.eq(N.deathLog, nil)
    T.eq(ns.db.global.deathHistory, nil)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("Feign Death vetoes even a client that reports dead", function()
    local g, ns = session()
    local N = ns.Nearest
    rawset(g.env, "UnitIsDeadOrGhost", function() return true end)
    rawset(g.env, "UnitIsFeignDeath", function() return true end)
    g:fire("PLAYER_DEAD")
    g:advance(0.4)
    T.eq(N.deathLog, nil)
    T.eq(N.pendingDeath, nil)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("real ghost arrival is recorded only after a confirmed death", function()
    local g, ns = session()
    local N = ns.Nearest
    rawset(g.env, "GetSubZoneText", function() return "West Field" end)
    g.ghost = false
    rawset(g.env, "UnitIsGhost", function() return g.ghost end)
    rawset(g.env, "UnitIsDeadOrGhost", function() return g.ghost end)
    g.opts.x, g.opts.y = .35, .42
    g:fire("PLAYER_DEAD")
    g.ghost = true
    g:fire("PLAYER_ALIVE")
    g.opts.x, g.opts.y = .50, .60
    T.ok(N:RecordGhostSpawn())
    local mapID = ns.Compat.PlayerPosition("player")
    local obs = N:PredictedGraveyard(mapID, "West Field")
    T.ok(obs)
    T.eq(obs.count, 1)
    g.ghost = false
    g:fire("PLAYER_UNGHOST")
    T.eq(#ns.db.global.deathHistory, 1)
    T.eq(ns.db.global.deathHistory[1].confirmed, true)
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("quest item tooltips beyond the active log", function()
  T.it("shows quest starter and objective use from indexed private pack", function()
    local g = mock.new({ class = "HUNTER", level = 20 })
    local pack = {
      source = "test", quests = {
        [10] = { "The Hidden Letter", 18, {} },
        [20] = { "Gather Crystals", 20, { { "item", 900, "Crystal" } } },
        [30] = { "More Crystals", 19, { { "item", 900, "Crystal" } } },
        [40] = { "Yet More Crystals", 20, { { "item", 900, "Crystal" } } },
      }, items = {}, npcs = {}, objects = {},
      itemStarts = { [900] = { 10 } },
      itemUses = { [900] = { 20, 30, 40 } },
    }
    rawset(g.env, "Outrider_DataQuests", pack)
    g.questsDone = { [10] = true }
    local ns = g:loadAddon()
    g:login()
    local rows = ns.QuestObjectives:ItemQuestLines(900)
    T.eq(#rows, 4)
    T.contains(rows[1][1], "Starts quest: The Hidden Letter (done)")
    T.contains(rows[2][1], "Used by quest: Gather Crystals")
    T.contains(rows[#rows][1], "+1 more")
    T.eq(#ns.QuestObjectives:ItemQuestLines(901), 0)
    ns.TooltipLines:Settings().questUsesLimit = 1
    T.eq(#ns.QuestObjectives:ItemQuestLines(900), 3)
    T.eq(#ns.Errors.list, 0)
  end)
end)

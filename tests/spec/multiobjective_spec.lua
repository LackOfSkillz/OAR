-- OI04-02: multi-objective planning: shared travel and rewards once, prerequisites, time with a margin.
local T, mock = ...

local function session(cands)
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  local N = ns.NexusCore
  N:Settings().on = true
  local S = ns.WhatNow.SOURCES
  for k in pairs(S) do S[k] = function() return {} end end
  for name, list in pairs(cands or {}) do S[name] = function() return list end end
  local A = ns.NexusAdapters
  A.LevelRouteStep, A.DealLots, A.HandoffItems = function() return {} end, function() return {} end, function() return {} end
  return game, ns, N
end
local function c(key, kind, extra)
  local t = { key = key, kind = kind, title = key, benefit = 0.7, confidence = 0.8, label = "observed", mapID = 2, seconds = 600 }
  for k, v in pairs(extra or {}) do t[k] = v end
  return t
end

T.describe("multi-objective planning (OI04-02)", function()
  T.it("quests, gear, gathering and errands are planned together", function()
    local _, _, N = session({
      quests = { c("quest:A", "quest", { questID = 1, estimatedActivitySeconds = 300 }) },
      gear = { c("gear:Helm", "gear", { gearSource = "drop" }) },
      gather = { c("gather:herb", "gather") },
      errands = { c("errand:vendor", "errand", { costCopper = 0 }) },
    })
    local cur = N:Replan("x")
    local kinds = {}
    for _, id in ipairs(cur.result.plan.steps) do kinds[cur.graph.nodes[id].opp.kind] = true end
    local n = 0 for _ in pairs(kinds) do n = n + 1 end
    T.ok(n >= 3, "several kinds in one plan")
  end)

  T.it("a quest's own time counts, not just the trip", function()
    local _, ns = session()
    local rec = ns.NexusAdapters.Adapt("quests", c("quest:A", "quest", { seconds = 200, estimatedActivitySeconds = 300 }), 1)
    T.eq(rec.costSeconds, 500)
  end)

  T.it("travel shared by steps on one map is counted once", function()
    local _, ns = session()
    local P = ns.NexusPlanner
    local function opp(id) return { opportunityId = id, kind = "quest", title = id, benefit = 0.8, confidence = "observed",
      evidenceIds = { "e" }, expiresAt = 1, intent = "none", revision = 1, costSeconds = 900, risk = 0.1, costCopper = 0 } end
    local meta = { a = { mapID = 2, travelSeconds = 600 }, b = { mapID = 2, travelSeconds = 600 } }
    local g = ns.NexusGraph.Build({ opp("a"), opp("b") }, meta, { copper = 1000, mapID = 1 })
    local res = P.Plan(g, ns.NexusScore.Rank(g, { { objective = "level", priority = 1 } }, { copper = 1000 }), { copper = 1000, mapID = 1 })
    -- first step: 600 trip + 300 activity; second: 120 local move + 300 activity
    T.eq(res.estimateSeconds, 900 + 300 + P.LOCAL_MOVE)
    T.eq(res.bufferedSeconds, math.floor((900 + 300 + P.LOCAL_MOVE) * P.BUFFER + 0.5))
  end)

  T.it("the same reward from two producers counts once; prerequisites are respected", function()
    local _, _, N = session({
      quests = { c("quest:Rake", "quest", { questID = 745 }), c("quest:Next", "quest", { questID = 746, preAll = { 745 }, benefit = 0.9 }) },
      dungeonquests = { c("dq:745", "dungeon", { benefit = 0.65 }) },
    })
    local cur = N:Replan("x")
    local rake, nxt, n745 = nil, nil, 0
    for i, id in ipairs(cur.result.plan.steps) do
      if id:find("745") or id:find("Rake") then n745 = n745 + 1 rake = rake or i end
      if id:find("Next") then nxt = i end
    end
    T.eq(n745, 1, "one entry for quest 745")
    T.ok(rake and nxt and rake < nxt, "the prerequisite comes first")
  end)

  T.it("a time budget is checked against the margin, and the page shows the estimate as one", function()
    local _, ns, N = session({ quests = { c("quest:A", "quest", { seconds = 400, estimatedActivitySeconds = 300, mapID = 3 }),
      c("quest:B", "quest", { seconds = 400, estimatedActivitySeconds = 300, mapID = 4 }) } })
    ns.NexusHorizon.Set(N, { minutes = 25, group = "either" })
    local cur = N:Replan("x")
    T.ok(cur.result.bufferedSeconds <= 25 * 60, "margined estimate fits the budget")
    T.eq(#cur.result.plan.steps, 1, "two 700 s steps with the margin don't fit 25 minutes")
    local _, note = ns.NexusPage.Cards()
    T.ok(note:find("an estimate; allow up to"), note)
  end)
end)

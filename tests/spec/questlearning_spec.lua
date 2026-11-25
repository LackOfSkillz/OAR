-- Review OI-FR04: your own quest times reach the planner. With enough timed
-- quests, the quest step's time is yours, the planner's cost changes and a
-- time-limited plan holds fewer quests; with too few, nothing changes.
local T, mock = ...

local function session(diary)
  local game = mock.new({ level = 20 })
  local ns = game:loadAddon()
  game:login()
  local N = ns.NexusCore
  N:Settings().on = true
  local S = ns.WhatNow.SOURCES
  local quests = S.quests
  for k in pairs(S) do S[k] = function() return {} end end
  S.quests = quests
  ns.NPCPack = ns.NPCPack or {}
  ns.Journey.XPList = function()
    local out = {}
    for i = 1, 6 do
      out[i] = { name = "Quest " .. i, level = 20, xp = 900, rate = 100 - i, giver = "Giver", mapID = 1, seconds = 60, questID = 9000 + i }
    end
    return out
  end
  local A = ns.NexusAdapters
  A.LevelRouteStep, A.DealLots, A.HandoffItems = function() return {} end, function() return {} end, function() return {} end
  local h = ns.Modules:Get("QuestInfo"):History()
  for _, r in ipairs(diary or {}) do h[#h + 1] = r end
  return game, ns, N
end

-- n quests that took you `secs` each, at level 20, solo, one play session
local function diary(n, secs)
  local rows, t = {}, 1000
  for i = 1, n do
    rows[#rows + 1] = { t = t, id = 500 + i, what = "took", lvl = 20, ps = "s1" }
    rows[#rows + 1] = { t = t + secs, id = 500 + i, what = "handed in", lvl = 20, ps = "s1" }
    t = t + secs + 10
  end
  return rows
end

local function questCost(N)
  local cur = N:Replan("x")
  local costs = {}
  for id, node in pairs(cur.graph.nodes) do if tostring(node.opp.title):find("Quest 1 [", 1, true) then costs[#costs + 1] = node.opp.costSeconds end end
  return costs[1], cur
end

T.describe("personal quest times in planning (review OI-FR04)", function()
  T.it("too few timed quests: the usual estimate stays", function()
    local _, ns, N = session(diary(3, 1500))
    T.eq(ns.QuestTimes:Personal(20, false), nil)
    local c = questCost(N)
    T.eq(c, 60 + ns.Journey.QUEST_TIME)
  end)

  T.it("enough slow quests: the step costs more, the plan holds fewer, the diary is unchanged", function()
    local _, ns0, N0 = session()
    ns0.NexusHorizon.Set(N0, { minutes = 60 })
    local base, cur0 = questCost(N0)
    local _, ns, N = session(diary(12, 1500))
    local before = #ns.Modules:Get("QuestInfo"):History()
    local m = ns.QuestTimes:Personal(20, false)
    T.ok(m and m.value > 900, "learned: " .. tostring(m and m.value))
    ns.NexusHorizon.Set(N, { minutes = 60 })
    local mine, cur = questCost(N)
    T.ok(mine > base, string.format("cost %s > %s", tostring(mine), tostring(base)))
    T.ok(#cur.result.plan.steps < #cur0.result.plan.steps,
      string.format("fewer quests fit an hour: %d < %d", #cur.result.plan.steps, #cur0.result.plan.steps))
    T.eq(#ns.Modules:Get("QuestInfo"):History(), before, "observations untouched")
  end)
end)

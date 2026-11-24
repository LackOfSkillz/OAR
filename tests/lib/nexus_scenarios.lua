-- tests/lib/nexus_scenarios.lua
-- Curated scenarios for the Nexus benchmark (OI02-15): the same candidate list
-- for WhatNow and the Nexus, a context, and the property a good answer has.
-- Candidates are test data in WhatNow's own shape.
local B = {}

local function q(key, kind, title, benefit, extra)
  local c = { key = key, kind = kind, title = title, benefit = benefit, confidence = 0.8, seconds = 600, label = "observed" }
  for k, v in pairs(extra or {}) do c[k] = v end
  return c
end

B.SCENARIOS = {
  { name = "gold goal", goal = "gold", copper = 500000, expect = "a gold step first",
    cands = { q("quest:Q1", "quest", "Quest 1", 0.9), q("gold:farm", "gold", "Farm boars", 0.7), q("gather:herb", "gather", "Peacebloom", 0.4) },
    ok = function(top) return top == "gold:farm" end },
  { name = "gear goal, low funds", goal = "gear", copper = 2000, expect = "nothing unaffordable first",
    cands = { q("gear:Axe", "gear", "Buy Big Axe", 0.95, { costCopper = 90000 }), q("gear:Boots", "gear", "Buy Boots", 0.6, { costCopper = 1500 }),
      q("quest:Q2", "quest", "Quest 2", 0.5) },
    ok = function(top) return top ~= "gear:Axe" end,
    why = "WhatNow has no gold budget, so it can put an item you can't pay for first; the Nexus treats the spendable gold as a hard limit." },
  { name = "level goal, duplicate quest", goal = "level", copper = 50000, expect = "one entry per quest",
    cands = { q("quest:Red Silk", "quest", "Pick up Red Silk Bandanas", 0.7, { questID = 214 }), q("dq:214", "dungeon", "Red Silk Bandanas for Deadmines", 0.8),
      q("errand:repair", "errand", "Repair", 0.4) },
    ok = function(top, steps)
      local n = 0
      for _, s in ipairs(steps or {}) do
        local low = s:lower():gsub("_", " ")
        if low:find("214", 1, true) or low:find("red silk", 1, true) then n = n + 1 end
      end
      return n <= 1
    end,
    why = "The same quest from two producers is counted once by the Nexus." },
  { name = "professions goal", goal = "professions", copper = 100000, expect = "a profession step first",
    cands = { q("profession:Cooking", "profession", "Train Cooking", 0.6, { costCopper = 500 }), q("quest:Q3", "quest", "Quest 3", 0.9), q("rare:61", "rare", "Thuros", 0.5) },
    ok = function(top) return top == "profession:Cooking" end },
  { name = "explore goal", goal = "explore", copper = 100000, expect = "the rare first",
    cands = { q("rare:61", "rare", "Thuros may be up", 0.7), q("gold:x", "gold", "Farm", 0.8), q("quest:Q4", "quest", "Quest 4", 0.5) },
    ok = function(top) return top == "rare:61" end },
  { name = "mix goal, doubtful source", goal = "mix", copper = 100000, expect = "a well-evidenced step first",
    cands = { q("quest:Rumour", "quest", "A rumoured quest", 0.75, { label = "inferred", confidence = 0.2, seconds = nil }),
      q("quest:Solid", "quest", "A known quest", 0.7, { label = "observed", confidence = 0.9 }) },
    ok = function(top) return top == "quest:Solid" end,
    why = "The Nexus charges for low confidence and unknown time; WhatNow multiplies by confidence only." },
}

-- the producer key a v4 record came from
local function legacy(ns, id, runtime) local c = runtime and runtime[id] return c and c.key end

function B.Nexus(ns, game, sc)
  local S = ns.WhatNow.SOURCES
  local saved = {}
  for k, v in pairs(S) do saved[k] = v S[k] = function() return {} end end
  S.quests = function() return sc.cands end
  local A = ns.NexusAdapters
  local keep = { A.LevelRouteStep, A.DealLots, A.HandoffItems }
  A.LevelRouteStep, A.DealLots, A.HandoffItems = function() return {} end, function() return {} end, function() return {} end
  local opps, _, _, runtime = A:All(1, game.now)
  for k, v in pairs(saved) do S[k] = v end
  A.LevelRouteStep, A.DealLots, A.HandoffItems = keep[1], keep[2], keep[3]
  local meta = {}
  for id, c in pairs(runtime) do local qk = A.QuestKey(c) meta[id] = { overlap = qk and ("quest:" .. qk) or nil } end
  local ctx = { copper = sc.copper, now = game.now, revision = 1 }
  local graph = ns.NexusGraph.Build(opps, meta, ctx)
  local ranked = ns.NexusScore.Rank(graph, { { objective = sc.goal, priority = 1 } }, ctx)
  local res = ns.NexusPlanner.Plan(graph, ranked, ctx)
  local steps = {}
  for _, id in ipairs(res.plan and res.plan.steps or {}) do steps[#steps + 1] = legacy(ns, id, runtime) or id end
  return steps, res
end

function B.Run(ns, game, sc)
  local picks = ns.WhatNow.Pick(sc.cands, sc.goal, {}, game.now)
  local wTop = picks and picks[1] and picks[1].key
  local steps, res = B.Nexus(ns, game, sc)
  return { whatnowTop = wTop, nexusTop = steps[1], steps = steps, work = res.work,
    whatnowOk = sc.ok(wTop, picks and (function() local t = {} for i, p in ipairs(picks) do t[i] = p.key end return t end)()),
    nexusOk = sc.ok(steps[1], steps) }
end

return B

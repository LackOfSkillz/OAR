-- tests/lib/nexus_scenarios.lua
-- Curated scenarios for the Nexus benchmark (OI02-15, widened for the Phase 2
-- review): the same candidates for WhatNow and the Nexus, a context, and the
-- property a good answer has. Candidates are test data in WhatNow's own
-- shape; sc.sources splits them over several producers (so cross-producer
-- duplicates and failures are real), sc.fail names producers that throw.
-- B.RealProducers runs the addon's own producers on the mock client.
local B = {}

local function q(key, kind, title, benefit, extra)
  local c = { key = key, kind = kind, title = title, benefit = benefit, confidence = 0.8, seconds = 600, label = "observed", mapID = 1 }
  for k, v in pairs(extra or {}) do c[k] = v end
  return c
end

local function count(steps, pat)
  local n = 0
  for _, s in ipairs(steps or {}) do if tostring(s):lower():gsub("_", " "):find(pat, 1, true) then n = n + 1 end end
  return n
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
    ok = function(top, steps) return count(steps, "214") + count(steps, "red silk") <= 1 end,
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

  -- widened for the Phase 2 review
  { name = "conflicting goals", goal = "gold", goals = { { objective = "gold", priority = 1 }, { objective = "gear", priority = 2 } },
    copper = 100000, expect = "the top goal leads, the second still gets a step",
    cands = { q("gold:farm", "gold", "Farm boars", 0.7), q("gear:Drop", "gear", "Helm from Hogger", 0.7, { gearSource = "drop" }),
      q("quest:Q5", "quest", "Quest 5", 0.3) },
    ok = function(top, steps) return top == "gold:farm" and count(steps, "helm") + count(steps, "drop") >= 1 end,
    why = "WhatNow takes one goal; the Nexus weighs every active goal by priority." },
  { name = "insufficient resources", goal = "gear", copper = 1500, reserve = 1000, expect = "no purchase above the reserve, unknown prices left out",
    cands = { q("gear:Axe", "gear", "Buy Axe", 0.95, { costCopper = 900 }), q("gear:Shop", "gear", "Vendor bracers", 0.9, { gearSource = "vendor" }),
      q("quest:Q6", "quest", "Quest 6", 0.4) },
    ok = function(top, steps) return count(steps, "axe") == 0 and count(steps, "bracers") == 0 and count(steps, "shop") == 0 end,
    why = "With 5s spendable over the reserve, the 9s axe and the vendor item of unknown price can't be planned; WhatNow ranks them first." },
  { name = "stale observations", goal = "mix", copper = 100000, expect = "a fresh node over one seen long ago",
    cands = { q("gather:old", "gather", "Old node", 0.9, { observedAt = "stale" }), q("gather:new", "gather", "Fresh node", 0.5) },
    ok = function(top, steps) return top == "gather:new" and count(steps, "old") == 0 end,
    why = "The Nexus drops a fact past its expiry; WhatNow has no observation time." },
  { name = "unavailable metadata", goal = "level", copper = 100000, expect = "the step with known map and time first",
    cands = { q("quest:Vague", "quest", "A vague quest", 0.72, { mapID = false, seconds = false }), q("quest:Clear", "quest", "A clear quest", 0.7) },
    ok = function(top) return top == "quest:Clear" end,
    why = "Unknown map and time are uncertainty to the Nexus, not free." },
  { name = "overlapping objectives", goal = "level", copper = 100000, expect = "one entry for one quest offered twice",
    sources = { quests = { q("quest:The Rake", "quest", "Kill The Rake", 0.7, { questID = 745 }) },
      dungeonquests = { q("dq:745", "dungeon", "The Rake (group)", 0.65) }, errands = { q("errand:vendor", "errand", "Sell junk", 0.3, { costCopper = 0 }) } },
    ok = function(top, steps) return count(steps, "745") + count(steps, "rake") == 1 end,
    why = "Two producers offering the same quest are one opportunity in the Nexus." },
  { name = "adverse conditions", goal = "level", copper = 100000, expect = "a plan from what still works",
    sources = { quests = { q("quest:Q7", "quest", "Quest 7", 0.6) } }, fail = { "gear", "dungeons" },
    ok = function(top) return top == "quest:Q7" end,
    why = "Failing producers are reported as unavailable; the rest still plan." },
}

-- the producer key a v4 record came from
local function legacy(id, runtime) local c = runtime and runtime[id] return c and c.key end

-- candidate copies with test markers resolved (false = field absent, "stale" = old observation)
local function resolve(list, now)
  local out = {}
  for i, c in ipairs(list or {}) do
    local copy = {}
    for k, v in pairs(c) do if v ~= false then copy[k] = v end end
    if copy.observedAt == "stale" then copy.observedAt = now - 3600 end
    out[i] = copy
  end
  return out
end

function B.Sources(sc, now)
  if sc.sources then
    local out = {}
    for name, list in pairs(sc.sources) do out[name] = resolve(list, now) end
    return out
  end
  return { quests = resolve(sc.cands, now) }
end

function B.AllCands(sc, now)
  local all = {}
  local src = B.Sources(sc, now)
  local names = {}
  for name in pairs(src) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do for _, c in ipairs(src[name]) do all[#all + 1] = c end end
  return all
end

function B.Nexus(ns, game, sc)
  local S = ns.WhatNow.SOURCES
  local saved = {}
  for k, v in pairs(S) do saved[k] = v S[k] = function() return {} end end
  for name, list in pairs(B.Sources(sc, game.now)) do S[name] = function() return list end end
  for _, name in ipairs(sc.fail or {}) do S[name] = function() error("producer down") end end
  local A = ns.NexusAdapters
  local keep = { A.LevelRouteStep, A.DealLots, A.HandoffItems }
  A.LevelRouteStep, A.DealLots, A.HandoffItems = function() return {} end, function() return {} end, function() return {} end
  local opps, excluded, unavailable, runtime = A:All(1, game.now)
  for k, v in pairs(saved) do S[k] = v end
  A.LevelRouteStep, A.DealLots, A.HandoffItems = keep[1], keep[2], keep[3]
  local ctx = { copper = sc.copper, reserveCopper = sc.reserve, now = game.now, revision = 1, mapID = 1 }
  local graph = ns.NexusGraph.Build(opps, A.MetaAll(runtime), ctx)
  local ranked = ns.NexusScore.Rank(graph, sc.goals or { { objective = sc.goal, priority = 1 } }, ctx)
  local res = ns.NexusPlanner.Plan(graph, ranked, ctx)
  local steps = {}
  for _, id in ipairs(res.plan and res.plan.steps or {}) do steps[#steps + 1] = legacy(id, runtime) or id end
  res.unavailable, res.excluded = unavailable, excluded
  return steps, res
end

function B.Run(ns, game, sc)
  local cands = B.AllCands(sc, game.now)
  local picks = ns.WhatNow.Pick(cands, sc.goal, {}, game.now)
  local wTop = picks and picks[1] and picks[1].key
  local keys = {}
  for i, p in ipairs(picks or {}) do keys[i] = p.key end
  local steps, res = B.Nexus(ns, game, sc)
  return { whatnowTop = wTop, nexusTop = steps[1], steps = steps, work = res.work, unavailable = res.unavailable,
    whatnowOk = sc.ok(wTop, keys), nexusOk = sc.ok(steps[1], steps) }
end

-- The addon's own producers on the mock client, planner on: whatever they
-- find, the result is either a valid plan whose every step cites resolvable
-- evidence and appears once, or no plan with a reason code.
function B.RealProducers(ns, game)
  local N = ns.NexusCore
  N:Settings().on = true
  local cur = N:Replan("bench")
  N:Settings().on = false
  local out = { ok = false, steps = 0, opportunities = 0, unavailable = cur and #cur.unavailable or 0 }
  if not cur then out.why = "no result" return out end
  for _ in pairs(cur.graph.nodes) do out.opportunities = out.opportunities + 1 end
  local res = cur.result
  if not res.plan then out.ok, out.why = res.code ~= nil, res.code return out end
  local seen = {}
  for _, id in ipairs(res.plan.steps) do
    if seen[id] then out.why = "duplicate " .. id return out end
    seen[id] = true
    for _, ev in ipairs(cur.graph.nodes[id].opp.evidenceIds) do
      if not ns.IntelEvidence:Get(ev) then out.why = "evidence missing for " .. id return out end
    end
  end
  out.ok, out.steps = true, #res.plan.steps
  return out
end

return B

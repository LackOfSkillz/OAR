-- OI02-10: bounded sequence planner.
local T, mock = ...

local function session()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

local function opp(id, t)
  local o = { opportunityId = id, kind = "quest", title = id, benefit = 0.5, confidence = "observed",
    evidenceIds = { "ev:" .. id }, expiresAt = 1, intent = "none", revision = 1, costSeconds = 300, risk = 0.1 }
  for k, v in pairs(t or {}) do o[k] = v end
  return o
end
local GOALS = { { objective = "level", priority = 1 } }

-- best value over all subsets that respect prerequisites, exclusions and gold
local function oracle(ns, graph, ranked, ctx, horizon)
  local ids, score = {}, {}
  for _, r in ipairs(ranked) do if r.score > 0 then ids[#ids + 1] = r.id score[r.id] = r.score end end
  local best = 0
  local spend = ctx.copper and (ctx.copper - (ctx.reserveCopper or 0))
  for mask = 1, 2 ^ #ids - 1 do
    local set, n, value, copper, ok = {}, 0, 0, 0, true
    for i, id in ipairs(ids) do
      if math.floor(mask / 2 ^ (i - 1)) % 2 == 1 then set[id] = true n = n + 1 value = value + score[id] copper = copper + (graph.nodes[id].opp.costCopper or 0) end
    end
    if n > horizon then ok = false end
    if spend and copper > spend then ok = false end
    for id in pairs(set) do
      for _, req in ipairs(graph.nodes[id].meta.requires or {}) do if not set[req] then ok = false end end
      for _, x in ipairs(graph.nodes[id].meta.excludes or {}) do if set[x] then ok = false end end
    end
    if ok and value > best then best = value end
  end
  return best
end

T.describe("nexus bounded planner", function()
  T.it("on small graphs the plan's value matches the exhaustive oracle", function()
    local _, ns = session()
    local cases = {
      { opps = { opp("a"), opp("b", { benefit = 0.9 }), opp("c", { benefit = 0.7, costCopper = 4000 }), opp("d", { benefit = 0.8, costCopper = 5000 }) },
        meta = { b = { requires = { "a" } }, c = { excludes = { "d" } } }, ctx = { copper = 10000 }, horizon = 3 },
      { opps = { opp("a", { benefit = 0.3 }), opp("b", { benefit = 0.95 }), opp("c", { benefit = 0.6 }), opp("e", { benefit = 0.9, costCopper = 9000 }) },
        meta = { e = { requires = { "c" } } }, ctx = { copper = 9500, reserveCopper = 1000 }, horizon = 2 },
    }
    for i, cs in ipairs(cases) do
      local g = ns.NexusGraph.Build(cs.opps, cs.meta, cs.ctx)
      local ranked = ns.NexusScore.Rank(g, GOALS, cs.ctx)
      local res = ns.NexusPlanner.Plan(g, ranked, cs.ctx, { horizon = cs.horizon })
      T.ok(res.plan, "case " .. i .. " has a plan")
      T.ok(math.abs(res.value - oracle(ns, g, ranked, cs.ctx, cs.horizon)) < 1e-9, "case " .. i .. " optimal")
      T.ok(ns.Nexus.Validate("Plan", res.plan))
      -- prerequisites come before what needs them
      local pos = {}
      for k, id in ipairs(res.plan.steps) do pos[id] = k end
      for id, m in pairs(cs.meta) do
        for _, req in ipairs(m.requires or {}) do if pos[id] then T.ok(pos[req] and pos[req] < pos[id], id .. " after " .. req) end end
      end
    end
  end)

  T.it("an adversarial large graph terminates under the work cap with a safe partial plan", function()
    local _, ns = session()
    local opps, meta = {}, {}
    for i = 1, 300 do
      local id = string.format("n%03d", i)
      opps[#opps + 1] = opp(id, { benefit = 0.3 + (i % 7) / 10 })
      if i > 1 then meta[id] = { requires = { string.format("n%03d", i - 1) } } end
    end
    local g = ns.NexusGraph.Build(opps, meta, {})
    local ranked = ns.NexusScore.Rank(g, GOALS, {})
    local res = ns.NexusPlanner.Plan(g, ranked, {}, { maxWork = 50 })
    T.ok(res.work <= 50, "work capped (" .. res.work .. ")")
    T.ok(res.plan == nil or res.plan.truncated or #res.plan.steps <= 8)
    local full = ns.NexusPlanner.Plan(g, ranked, {})
    T.ok(full.plan and #full.plan.steps <= 8, "horizon respected")
  end)

  T.it("an infeasible budget gives no plan with a reason, never a made-up sequence", function()
    local _, ns = session()
    local g = ns.NexusGraph.Build({ opp("a", { costCopper = 5000 }), opp("b", { costCopper = 6000 }) }, {}, {})
    local ranked = ns.NexusScore.Rank(g, GOALS, { copper = 100000 })
    local res = ns.NexusPlanner.Plan(g, ranked, { copper = 3000 })
    T.eq(res.plan, nil)
    T.eq(res.why, "nothing fits the gold you have")
    local timeRes = ns.NexusPlanner.Plan(g, ranked, { copper = 100000, budgetSeconds = 100 })
    T.eq(timeRes.plan, nil)
    T.eq(timeRes.why, "nothing fits the time and gold you have")
    T.eq(ns.NexusPlanner.Plan(g, {}, {}).why, "nothing worth doing right now fits your goals")
  end)

  T.it("alternatives name other good first steps; same input, same plan", function()
    local _, ns = session()
    local opps = { opp("a", { benefit = 0.9 }), opp("b", { benefit = 0.8 }), opp("c", { benefit = 0.7 }) }
    local g = ns.NexusGraph.Build(opps, { a = { excludes = { "b" } } }, {})
    local ranked = ns.NexusScore.Rank(g, GOALS, {})
    local r1 = ns.NexusPlanner.Plan(g, ranked, { revision = 3, now = 100 })
    local r2 = ns.NexusPlanner.Plan(g, ranked, { revision = 3, now = 100 })
    T.eq(table.concat(r1.plan.steps, ","), table.concat(r2.plan.steps, ","))
    T.ok(#r1.alternatives >= 1)
    T.ok(r1.alternatives[1].firstStep ~= r1.plan.steps[1])
  end)
end)

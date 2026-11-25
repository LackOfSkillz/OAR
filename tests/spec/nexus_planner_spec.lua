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

-- review OI-FR06: an exhaustive solver over ORDERED sequences, with the
-- planner's own step times (shared same-map travel), map changes and budgets
local function orderedOracle(ns, graph, ranked, ctx, horizon)
  local P = ns.NexusPlanner
  local ids, score = {}, {}
  for _, r in ipairs(ranked) do if r.score > 0 then ids[#ids + 1] = r.id score[r.id] = r.score end end
  local spend = ctx.copper and (ctx.copper - (ctx.reserveCopper or 0))
  local best = 0
  local function walk(st)
    if st.value > best then best = st.value end
    if #st.seq >= horizon then return end
    for _, id in ipairs(ids) do
      local n = graph.nodes[id]
      local ok = not st.set[id]
      for _, req in ipairs(ok and n.meta.requires or {}) do if not st.set[req] then ok = false end end
      for _, x in ipairs(ok and n.meta.excludes or {}) do if st.set[x] then ok = false end end
      if ok then for o in pairs(st.set) do for _, x in ipairs(graph.nodes[o].meta.excludes or {}) do if x == id then ok = false end end end end
      local c = n.opp.costCopper or 0
      if ok and c > 0 and (not spend or st.copper + c > spend) then ok = false end
      local secs = ok and P.StepSeconds(st, n)
      if ok and ctx.budgetSeconds and (st.seconds + secs) * P.BUFFER > ctx.budgetSeconds then ok = false end
      if ok then
        local seq, set = {}, {}
        for i, s in ipairs(st.seq) do seq[i] = s end
        seq[#seq + 1] = id
        for s in pairs(st.set) do set[s] = true end
        set[id] = true
        local value = st.value + score[id]
        if n.meta.mapID and st.map and n.meta.mapID ~= st.map then value = value - P.MAP_CHANGE end
        walk({ seq = seq, set = set, value = value, map = n.meta.mapID or st.map, here = n.meta.mapID and true or false, copper = st.copper + math.max(0, c), seconds = st.seconds + secs })
      end
    end
  end
  walk({ seq = {}, set = {}, value = 0, copper = 0, seconds = 0, map = ctx.mapID })
  return best
end

T.describe("resource-aware state dominance (review OI-FR06)", function()
  T.it("with order-dependent times and a time budget the plan matches an exhaustive ordered solver", function()
    local _, ns = session()
    local seed = 12345
    local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648 return seed % n end
    local worse = 0
    for case = 1, 40 do
      local opps, meta = {}, {}
      for i = 1, 5 do
        local id = "s" .. i
        opps[#opps + 1] = opp(id, { benefit = 0.2 + rnd(80) / 100, costSeconds = 200 + rnd(900) })
        meta[id] = { mapID = 1 + rnd(3), travelSeconds = 100 + rnd(600) }
      end
      local ctx = { mapID = 1, budgetSeconds = 900 + rnd(1800) }
      local g = ns.NexusGraph.Build(opps, meta, ctx)
      local ranked = ns.NexusScore.Rank(g, GOALS, ctx)
      local res = ns.NexusPlanner.Plan(g, ranked, ctx, { horizon = 4 })
      local want = orderedOracle(ns, g, ranked, ctx, 4)
      local got = res.plan and res.value or 0
      T.ok(got <= want + 1e-9, "case " .. case .. ": never above the true best")
      if got < want - 1e-9 then worse = worse + 1 end
      if res.plan then T.ok(res.bufferedSeconds <= ctx.budgetSeconds, "case " .. case .. " fits its time") end
    end
    T.eq(worse, 0, "every case reaches the exhaustive best")
  end)

  T.it("keeps the quicker order of the same steps when it leaves room for one more", function()
    local _, ns = session()
    -- one order of a and b costs 1200 s, the other 820 s (the long trip is
    -- shared): same steps, same map, same value; only the quick one leaves
    -- room for c in 1500 s (with the 20% margin). Every arrangement, so the slow order is met first
    -- in at least one of them.
    for _, v in ipairs({ { 0.9, 0.6, 500, 100 }, { 0.9, 0.6, 100, 500 }, { 0.6, 0.9, 500, 100 }, { 0.6, 0.9, 100, 500 } }) do
      local opps = { opp("a", { benefit = v[1], costSeconds = 600 }), opp("b", { benefit = v[2], costSeconds = 600 }),
        opp("c", { benefit = 0.5, costSeconds = 300 }) }
      local meta = { a = { mapID = 2, travelSeconds = v[3] }, b = { mapID = 2, travelSeconds = v[4] }, c = { mapID = 3, travelSeconds = 100 } }
      local ctx = { mapID = 2, budgetSeconds = 1500 }
      local g = ns.NexusGraph.Build(opps, meta, ctx)
      local ranked = ns.NexusScore.Rank(g, GOALS, ctx)
      local res = ns.NexusPlanner.Plan(g, ranked, ctx, { horizon = 3 })
      local label = table.concat(v, "/")
      T.ok(res.plan and #res.plan.steps == 3, label .. ": all three fit: " .. table.concat(res.plan and res.plan.steps or {}, ","))
      T.ok(res.plan and math.abs(res.value - orderedOracle(ns, g, ranked, ctx, 3)) < 1e-9, label .. ": the exhaustive best")
    end
  end)
end)

-- Phase 2 review, resubmission 1 corrections (OI02-R10..R14).
local T, mock = ...

-- a session with the planner on; every producer stubbed except those in keep
-- (the real producer functions are returned in `real`)
local function session(cands, extra, keep)
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  local N = ns.NexusCore
  N:Settings().on = true
  local S = ns.WhatNow.SOURCES
  local real = {}
  for k, v in pairs(S) do real[k] = v end
  for k in pairs(S) do if not (keep and keep[k]) then S[k] = function() return {} end end end
  if cands then S.quests = function() return cands end end
  for k, fn in pairs(extra or {}) do S[k] = fn end
  local A = ns.NexusAdapters
  real.deals, real.handoffs = A.DealLots, A.HandoffItems
  A.LevelRouteStep = function() return {} end
  if not (keep and keep.deals) then A.DealLots = function() return {} end end
  if not (keep and keep.handoffs) then A.HandoffItems = function() return {} end end
  return game, ns, N, real
end

local function q(key, kind, extra)
  local c = { key = key, kind = kind, title = key, benefit = 0.6, confidence = 0.8, seconds = 300, label = "observed", mapID = 1 }
  for k, v in pairs(extra or {}) do c[k] = v end
  return c
end

local function opp(id, t)
  local o = { opportunityId = id, kind = "quest", title = id, benefit = 0.5, confidence = "observed",
    evidenceIds = { "ev:" .. id }, expiresAt = 1, intent = "none", revision = 1, costSeconds = 300, risk = 0.1, costCopper = 0 }
  for k, v in pairs(t or {}) do o[k] = v end
  return o
end
local GOALS = { { objective = "level", priority = 1 } }
local function plan(ns, opps, meta, ctx)
  local g = ns.NexusGraph.Build(opps, meta, ctx)
  local ranked = ns.NexusScore.Rank(g, GOALS, ctx)
  return ns.NexusPlanner.Plan(g, ranked, ctx), g
end
local function indexOf(list, x) for i, v in ipairs(list or {}) do if v == x then return i end end end

-- a planner session with two quests whose producer go() counts its calls
local function planned()
  local calls = { go = 0, b = 0 }
  local function go() calls.go = calls.go + 1 return true end
  local game, ns, N = session({
    q("quest:A", "quest", { questID = 1, benefit = 0.9, go = go, alt = { text = "alt", go = go } }),
    q("quest:B", "quest", { questID = 2, benefit = 0.7, go = function() calls.b = calls.b + 1 return true end }),
  })
  N:Replan("x")
  return game, ns, N, calls
end

T.describe("nexus review R10: every Go on a plan step goes through Act", function()
  T.it("plan picks carry no producer callback or alternative; a valid Go runs once through Act", function()
    local _, ns, N, calls = planned()
    local picks = N:Picks()
    T.ok(#picks > 0)
    for _, p in ipairs(picks) do
      T.ok(p.alt == nil, "no producer alternative")
      T.ok(N.current.runtime[p.nexusId].go ~= p.go, "go is not the producer's")
    end
    T.eq(calls.go, 0)
    T.ok(ns.WhatNow:Go(picks[1]))
    T.eq(calls.go, 1)
  end)

  local CASES = {
    { "combat", function(game) game.combat = true end },
    { "skipped", function(_, _, N, id) N:Settings().skipped[id] = true end },
    { "expired", function(game, ns) game:advance(ns.NexusAdapters.TTL + 5) end },
    { "disabled", function(_, _, N) N:Settings().on = false end },
    { "rejected", function(_, _, N, id) N.current.rejected[id] = "test" end },
    { "stale", function(_, ns) ns.NexusState:Invalidate("gold") end },
  }
  for _, case in ipairs(CASES) do
    T.it("a " .. case[1] .. " step can't run from What now?, Home or Radar", function()
      local game, ns, N, calls = planned()
      local R = ns.OpportunityRadar
      ns.Modules:SetEnabled("OpportunityRadar", true)
      local pick = N:Picks()[1]
      R.dirty = true
      local card = R:Cards()[1]
      T.ok(card, "Radar shows the plan step")
      N:Settings().paused = true -- no re-plan may rescue the step before the click
      case[2](game, ns, N, pick.nexusId)
      ns.WhatNow:Go(pick)         -- What now? page and Home's Go button
      R:GoCard(card)              -- Radar
      T.eq(calls.go, 0, case[1] .. ": the producer's go() never ran")
      T.eq(select(1, N:Act(pick.nexusId)), false, case[1] .. ": Act refuses")
      game.combat = false
    end)
  end
end)

T.describe("nexus review R10: the next-step key", function()
  T.it("presses Go on the plan's own pick, which runs Act", function()
    local _, ns, N, calls = planned()
    local acts, act = 0, N.Act
    N.Act = function(self, id) acts = acts + 1 return act(self, id) end
    ns.HandyKeys:Next()
    N.Act = act
    T.eq(acts, 1, "through Act")
    T.eq(calls.go, 1)
    N:Settings().skipped[N.current.result.plan.steps[1]] = true
    N:Settings().paused = true
    ns.HandyKeys:Next()
    T.eq(calls.go, 1, "a skipped first step is not run by the key")
  end)
end)

T.describe("nexus review R11: observation times from the real producers", function()
  T.it("rares: the sighting's own time, not now", function()
    local game, ns, N, real = session(nil, nil, { rares = true })
    local seen = game.now - 3600
    local scan = ns.Modules:Get("RareScan")
    scan:Settings().watch[61] = true
    local W, L = ns.Sightings.Window, ns.Sightings.Last
    ns.Sightings.Window = function() return { state = "open" } end
    ns.Sightings.Last = function() return { t = seen, mapID = 1, x = 0.5, y = 0.5 } end
    local cur = N:Replan("x")
    ns.Sightings.Window, ns.Sightings.Last = W, L
    local found
    for id, node in pairs(cur.graph.nodes) do
      if id:find("rare") then found = ns.IntelEvidence:Get(node.opp.evidenceIds[1]) end
    end
    T.ok(found, "the rare is planned with its evidence")
    T.eq(found.observedAt, seen)
    T.eq(found.calculatedAt, game.now)
    T.eq(found.freshness, "known")
  end)
  T.it("gather: the time you saw the node up", function()
    local game, ns, N = session(nil, nil, { gather = true })
    local L = ns.LootLog
    local here, nodes, st = ns.Travel.Here, L.NodesFor, L.NodeState
    ns.Travel.Here = function() return { mapID = 1, x = 0.5, y = 0.5 } end
    L.NodesFor = function() return { { mapID = 1, x = 0.4, y = 0.4, kind = "herb", name = "Peacebloom" } } end
    L.NodeState = function() return "up", 120 end
    local cur = N:Replan("x")
    ns.Travel.Here, L.NodesFor, L.NodeState = here, nodes, st
    local row
    for id, node in pairs(cur.graph.nodes) do if id:find("gather") then row = ns.IntelEvidence:Get(node.opp.evidenceIds[1]) end end
    T.ok(row) T.eq(row.observedAt, game.now - 120)
  end)
  T.it("alt inventory and auction lots carry their saved times", function()
    local game, ns, N, real = session(nil, nil, { handoffs = true, deals = true })
    local H, D = ns.Modules:Get("Handoffs"), ns.Modules:Get("DealDesk")
    local hf, dr = H.Find, D.Rows
    local he, de = H.enabled, D.enabled
    H.enabled, D.enabled = true, true
    H.Find = function() return { { holder = "Alt-Realm", itemID = 5, name = "Ring", pct = 10, where = "bags", observedAt = game.now - 86400 } } end
    D.Rows = function() return { { id = 1, itemID = 7, profitCopper = 500, costCopper = 100, observedAt = game.now - 60 } } end
    local recs = ns.NexusAdapters:Collect({}, 1, game.now, { deals = ns.NexusAdapters.DealLots, handoffs = ns.NexusAdapters.HandoffItems })
    H.Find, D.Rows, H.enabled, D.enabled = hf, dr, he, de
    local seen = {}
    for _, o in ipairs(recs) do seen[o.legacyCandidateId:match("^(%a+)")] = ns.IntelEvidence:Get(o.evidenceIds[1]) end
    T.eq(seen.handoff.observedAt, game.now - 86400)
    T.eq(seen.deal.observedAt, game.now - 60)
  end)
  T.it("history with no time is marked unknown freshness, never a fresh observation, and costs uncertainty", function()
    local game, ns = session()
    local A = ns.NexusAdapters
    local rec = A.Adapt("rares", q("rare:9", "rare"), 1)
    local row = ns.IntelEvidence:Get(rec.evidenceIds[1])
    T.eq(row.freshness, "unknown")
    T.eq(rec.freshnessUnknown, true)
    local live = A.Adapt("quests", q("quest:L", "quest"), 1)
    T.ok(not live.freshnessUnknown, "live producers observe now")
    local g = ns.NexusGraph.Build({ opp("a"), opp("b", { freshnessUnknown = true }) }, {}, { copper = 1000 })
    local s = {}
    for _, r in ipairs(ns.NexusScore.Rank(g, GOALS, { copper = 1000 })) do s[r.id] = r.score end
    T.ok(s.b < s.a)
  end)
end)

T.describe("nexus review R12: a change of goals or settings makes the plan stale at once", function()
  local function fresh()
    local game, ns, N = planned()
    T.eq(select(1, N:IsStale()), false)
    N:Settings().paused = true -- before any re-plan could run
    return game, ns, N
  end
  T.it("goal added, reserve raised, priority changed", function()
    local _, ns, N = fresh()
    local g = ns.NexusGoals:Create("gold", { priority = 2 })
    T.eq(select(1, N:IsStale()), true, "new goal")
    N:Replan("x") N:Settings().paused = false N:Replan("x") N:Settings().paused = true
    T.eq(select(1, N:IsStale()), false)
    ns.NexusGoals:Edit(g.goalId, { reserveCopper = 10000 })
    T.eq(select(1, N:IsStale()), true, "reserve")
  end)
  T.it("skip, pin and the switch", function()
    local _, ns, N = fresh()
    local id = N.current.result.plan.steps[1]
    N:Settings().skipped[id] = true
    T.eq(select(1, N:IsStale()), true, "skip")
    N:Settings().skipped[id] = nil
    T.eq(select(1, N:IsStale()), false, "undone")
    N:Settings().pinned = id
    T.eq(select(1, N:IsStale()), true, "pin")
    N:Settings().pinned = nil
    N:SetOn(false)
    T.eq(N.current, nil, "switching off drops the plan")
  end)
  T.it("What now? and Radar never serve the other provider's cached list", function()
    local _, ns, N = planned()
    local R = ns.OpportunityRadar
    ns.Modules:SetEnabled("OpportunityRadar", true)
    ns.WhatNow:List()
    T.eq(ns.WhatNow.provider, "nexus")
    R.dirty = false
    R:Cards()
    N:Settings().on = false -- even without SetOn, within the cache time
    ns.WhatNow:List()
    T.eq(ns.WhatNow.provider, "whatnow")
    local before = R.recomputeCount
    R:Cards()
    T.ok(R.recomputeCount > before, "Radar rebuilt for the new provider")
  end)
  T.it("an expired step disappears from the picks before any re-plan", function()
    local game, ns, N = planned()
    N:Settings().paused = true
    T.ok(#N:Picks() > 0)
    game:advance(ns.NexusAdapters.TTL + 5)
    T.eq(#N:Picks(), 0)
  end)
end)

T.describe("nexus review R13: an unknown price is checked, not counted as spent", function()
  T.it("without a reserve it is planned as unconfirmed and labelled; with one it is left out", function()
    local _, ns = session()
    local opps = { opp("buy", { kind = "gear", costCopper = nil, costUnknown = true, benefit = 0.9 }), opp("q") }
    local res = plan(ns, opps, {}, { copper = 5000 })
    T.ok(indexOf(res.plan.steps, "buy"))
    T.eq(res.financial, "unconfirmed")
    T.eq(res.unconfirmed[1], "buy")
    T.ok(indexOf(res.plan.reasonCodes, "cost_unconfirmed"))
    res = plan(ns, opps, {}, { copper = 5000, reserveCopper = 1000 })
    T.ok(not indexOf(res.plan.steps, "buy"))
    T.eq(res.financial, "confirmed")
  end)
  T.it("the pick and the Plan card say to check the price first", function()
    local _, ns, N = session(nil, { gear = function() return { q("gear:Shop", "gear", { gearSource = "vendor", benefit = 0.95, go = function() end }) } end })
    N:Replan("x")
    local p
    for _, x in ipairs(N:Picks()) do if x.key == "gear:Shop" then p = x end end
    T.ok(p and p.priceUnknown and p.caveat:find("Price unknown"), "pick caveat")
    local cards = ns.NexusPage.Cards()
    local tagged = false
    for _, c in ipairs(cards) do for _, t in ipairs(c.tags) do if t[1] == "price unknown" then tagged = true end end end
    T.ok(tagged, "card tag")
  end)
end)

T.describe("nexus review R14: one of several prerequisites", function()
  T.it("an infeasible first alternative doesn't block the quest when another can be done", function()
    local _, ns = session()
    local opps = { opp("altA", { costCopper = 99999 }), opp("altB"), opp("goal", { benefit = 1 }) }
    local meta = { goal = { requiresAny = { "altA", "altB" } } }
    local res, g = plan(ns, opps, meta, { copper = 1000 })
    T.ok(g.invalid.altA, "the first alternative can't be afforded")
    T.ok(not g.invalid.goal)
    T.ok(indexOf(res.plan.steps, "altB") < indexOf(res.plan.steps, "goal"))
  end)
  T.it("with no alternative possible the quest says so", function()
    local _, ns = session()
    local g = ns.NexusGraph.Build({ opp("goal") }, { goal = { requiresAny = { "quest:q1", "quest:q2" } } }, { copper = 1000 })
    T.ok(tostring(g.invalid.goal):find("one of"), tostring(g.invalid.goal))
  end)
  T.it("from the quest pack: preAny becomes requiresAny in a real Replan", function()
    local _, _, N = session({
      q("quest:Pre1", "quest", { questID = 1 }), q("quest:Pre2", "quest", { questID = 2, costCopper = 0 }),
      q("quest:Post", "quest", { questID = 3, benefit = 0.95, preAny = { 1, 2 } }),
    })
    local cur = N:Replan("x")
    local post
    for id, node in pairs(cur.graph.nodes) do if id:find("Post$") then post = node end end
    T.eq(#post.meta.requiresAny, 2)
    T.ok(not cur.rejected[post.id])
  end)
end)

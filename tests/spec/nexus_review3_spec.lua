-- Phase 2 review, resubmission 2 corrections (OI02-R15..R17).
local T, mock = ...

local function session(cands)
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  local N = ns.NexusCore
  N:Settings().on = true
  local S = ns.WhatNow.SOURCES
  for k in pairs(S) do S[k] = function() return {} end end
  if cands then S.quests = function() return cands end end
  local A = ns.NexusAdapters
  A.LevelRouteStep, A.DealLots, A.HandoffItems = function() return {} end, function() return {} end, function() return {} end
  return game, ns, N
end

local function q(key, extra)
  local c = { key = key, kind = "quest", title = key, benefit = 0.6, confidence = 0.8, seconds = 300, label = "observed", mapID = 1 }
  for k, v in pairs(extra or {}) do c[k] = v end
  return c
end
local function opp(id, t)
  local o = { opportunityId = id, kind = "quest", title = id, benefit = 0.8, confidence = "observed",
    evidenceIds = { "ev:" .. id }, expiresAt = 1, intent = "none", revision = 1, costSeconds = 60, risk = 0.1, costCopper = 0 }
  for k, v in pairs(t or {}) do o[k] = v end
  return o
end
local GOALS = { { objective = "level", priority = 1 } }
local function plan(ns, opps, meta, opts)
  local ctx = { copper = 1000 }
  local g = ns.NexusGraph.Build(opps, meta, ctx)
  local ranked = ns.NexusScore.Rank(g, GOALS, ctx)
  if opts and opts.reverse then
    local r = {}
    for i = #ranked, 1, -1 do r[#r + 1] = ranked[i] end
    ranked = r
  end
  return ns.NexusPlanner.Plan(g, ranked, ctx), g
end
local function pos(res, id) for i, v in ipairs(res.plan and res.plan.steps or {}) do if v == id then return i end end end
local function sorted(res)
  local t = {}
  for i, v in ipairs(res.plan and res.plan.steps or {}) do t[i] = v end
  table.sort(t)
  return table.concat(t, ",")
end

T.describe("nexus review R15: prerequisite loops terminate safely", function()
  T.it("circular AND: both are left out, nothing crashes", function()
    local _, ns = session()
    local res, g = plan(ns, { opp("A"), opp("B"), opp("C") }, { A = { requires = { "B" } }, B = { requires = { "A" } } })
    T.ok(g.invalid.A and g.invalid.B, "the loop is invalid")
    T.eq(sorted(res), "C")
  end)
  T.it("circular OR with a valid exit: A needs B or C, B needs A, C needs nothing", function()
    local _, ns = session()
    local opps = { opp("A", { benefit = 1 }), opp("B"), opp("C") }
    local meta = { A = { requiresAny = { "B", "C" } }, B = { requires = { "A" } } }
    local res = plan(ns, opps, meta)
    T.ok(pos(res, "C") and pos(res, "A") and pos(res, "C") < pos(res, "A"), "C then A")
    if pos(res, "B") then T.ok(pos(res, "A") < pos(res, "B"), "B only after A") end
    local rev = plan(ns, opps, meta, { reverse = true })
    T.eq(sorted(rev), sorted(res), "ranking order doesn't change the plan")
  end)
  T.it("circular OR with no exit: terminates, nothing from the loop is planned, the reason is given", function()
    local _, ns = session()
    local res = plan(ns, { opp("A"), opp("B"), opp("X") }, { A = { requiresAny = { "B" } }, B = { requiresAny = { "A" } } })
    T.eq(sorted(res), "X")
    T.ok(res.unplannable.A and res.unplannable.B)
  end)
  T.it("mixed AND/OR: A needs D and (B or C), B needs A, C needs D", function()
    local _, ns = session()
    local opps = { opp("A", { benefit = 1 }), opp("B"), opp("C"), opp("D") }
    local meta = { A = { requires = { "D" }, requiresAny = { "B", "C" } }, B = { requires = { "A" } }, C = { requires = { "D" } } }
    for _, rev in ipairs({ false, true }) do
      local res = plan(ns, opps, meta, { reverse = rev })
      T.ok(pos(res, "D") < pos(res, "C") and pos(res, "C") < pos(res, "A"), "D, C, A (reverse=" .. tostring(rev) .. ")")
    end
  end)
  T.it("deep and adversarial graphs finish fast and plan nothing impossible", function()
    local _, ns = session()
    -- a chain 300 long: the top is too deep to plan, and says so
    local opps, meta = {}, {}
    for i = 1, 300 do
      opps[#opps + 1] = opp("c" .. i)
      if i > 1 then meta["c" .. i] = { requires = { "c" .. (i - 1) } } end
    end
    local t0 = os.clock()
    local res = plan(ns, opps, meta)
    T.ok(res.unplannable["c300"], "too deep")
    -- 60 nodes that each need any of the others, no way in
    local o2, m2 = {}, {}
    for i = 1, 60 do
      o2[#o2 + 1] = opp("n" .. i)
      local alts = {}
      for k = 1, 60 do if k ~= i then alts[#alts + 1] = "n" .. k end end
      m2["n" .. i] = { requiresAny = alts }
    end
    local res2 = plan(ns, o2, m2)
    T.eq(res2.plan, nil, "nothing plannable")
    T.ok(os.clock() - t0 < 5, string.format("took %.2f s", os.clock() - t0))
  end)
end)

T.describe("nexus review R16: pages never show an expired plan step as current", function()
  local function setup()
    local game, ns, N = session({ q("quest:A", { questID = 1, benefit = 0.9, go = function() end }),
      q("quest:B", { questID = 2, benefit = 0.7, go = function() end }) })
    N:Replan("x")
    N:Settings().paused = true
    local first = N.current.result.plan.steps[1]
    -- the step expires 5 s from now: well inside every cache window
    N.current.graph.nodes[first].opp.expiresAt = game.now + 5
    return game, ns, N, first
  end
  T.it("What now? drops the step from its cached list once it expires", function()
    local game, ns, N, first = setup()
    local list = ns.WhatNow:List()
    T.eq(list[1].nexusId, first)
    game:advance(10)
    for _, c in ipairs(ns.WhatNow:List()) do T.ok(c.nexusId ~= first, "expired step gone") end
  end)
  T.it("Radar's card can't outlive the step, and leaves on expiry", function()
    local game, ns, N, first = setup()
    local R = ns.OpportunityRadar
    ns.Modules:SetEnabled("OpportunityRadar", true)
    R.dirty = true
    local cards = R:Cards()
    local card
    for _, c in ipairs(cards) do if c.nexusId == first then card = c end end
    T.ok(card, "shown while current")
    T.ok(card.expiresAt <= N.current.graph.nodes[first].opp.expiresAt, "Radar's evidence doesn't extend it")
    game:advance(10)
    for _, c in ipairs(R:Cards()) do T.ok(c.nexusId ~= first, "gone from Radar") end
  end)
  T.it("the Plan page shows it as out of date, not as the next step", function()
    local game, ns, N, first = setup()
    game:advance(10)
    local cards, note = ns.NexusPage.Cards()
    for _, c in ipairs(cards) do T.ok(c.title ~= "quest:A", "not shown as current") end
    T.ok(note:find("out of date"), note)
  end)
end)

T.describe("nexus review R17: more events make the plan stale at once", function()
  local EVENTS = { "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED",
    "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "ITEM_SEARCH_RESULTS_UPDATED" }
  for _, ev in ipairs(EVENTS) do
    T.it(ev .. " makes the plan stale before the debounced re-plan", function()
      local game, ns, N = session({ q("quest:A", { questID = 1 }) })
      ns.Modules:SetEnabled("Nexus", true)
      N:Replan("x")
      local before = N.replans
      T.eq(select(1, N:IsStale()), false)
      game:fire(ev)
      T.eq(select(1, N:IsStale()), true, ev)
      T.eq(N.replans, before, "no re-plan yet (debounced)")
    end)
  end
  T.it("with every saved goal paused or archived, the implicit What now? goal is in the key", function()
    local _, ns, N = session({ q("quest:A", { questID = 1 }) })
    local g = ns.NexusGoals:Create("gold", { priority = 1 })
    ns.NexusGoals:Pause(g.goalId)
    N:Replan("x")
    N:Settings().paused = true
    T.eq(select(1, N:IsStale()), false)
    ns.WhatNow:SetGoal(ns.WhatNow:Goal() == "gear" and "level" or "gear")
    T.eq(select(1, N:IsStale()), true, "the implicit goal changed")
    N:Settings().paused = false N:Replan("x") N:Settings().paused = true
    ns.NexusGoals:Delete(g.goalId) -- archived: still implicit
    T.eq(select(1, N:IsStale()), true, "archiving changes the saved goal's status")
  end)
end)

-- Phase 2 review corrections (OI02-R01..R09): one regression test per finding.
local T, mock = ...

local function session(cands, extra)
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  local N = ns.NexusCore
  N:Settings().on = true
  local S = ns.WhatNow.SOURCES
  for k in pairs(S) do S[k] = function() return {} end end
  S.quests = function() return cands or {} end
  for k, fn in pairs(extra or {}) do S[k] = fn end
  local A = ns.NexusAdapters
  A.LevelRouteStep, A.DealLots, A.HandoffItems = function() return {} end, function() return {} end, function() return {} end
  return game, ns, N
end

local function q(key, kind, extra)
  local c = { key = key, kind = kind, title = key, benefit = 0.6, confidence = 0.8, seconds = 300, label = "observed" }
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
local function plan(ns, opps, meta, ctx, opts)
  local g = ns.NexusGraph.Build(opps, meta, ctx)
  local ranked = ns.NexusScore.Rank(g, GOALS, ctx)
  return ns.NexusPlanner.Plan(g, ranked, ctx, opts), g, ranked
end
local function stepIds(res) return res.plan and res.plan.steps or {} end
local function indexOf(list, x) for i, v in ipairs(list) do if v == x then return i end end end

T.describe("nexus review R01: a pin is a planner input", function()
  T.it("a feasible pin goes first even when it scores low", function()
    local _, ns = session()
    local res = plan(ns, { opp("a", { benefit = 0.9 }), opp("b", { benefit = 0.1 }) }, {}, { copper = 1000 }, { pin = "b" })
    T.eq(stepIds(res)[1], "b")
    T.ok(res.pin.ok)
  end)
  T.it("a pin over budget can't go first: no bypass, the plan says why", function()
    local _, ns = session()
    local res = plan(ns, { opp("a"), opp("pricey", { benefit = 0.9, costCopper = 5000 }) }, {}, { copper = 1000 }, { pin = "opp:none" })
    T.eq(res.pin.code, "pin_gone")
    res = plan(ns, { opp("a"), opp("pricey", { benefit = 0.9, costCopper = 5000 }) }, {}, { copper = 1000 }, { pin = "pricey" })
    T.ok(indexOf(stepIds(res), "pricey") == nil, "the unaffordable pin is not planned")
    T.eq(res.pin.ok, false)
    T.eq(res.pin.code, "pin_infeasible")
  end)
  T.it("a pin whose prerequisite isn't done can't go first", function()
    local _, ns = session()
    local res = plan(ns, { opp("first"), opp("second", { benefit = 0.9 }) }, { second = { requires = { "first" } } }, { copper = 1000 }, { pin = "second" })
    T.eq(res.pin.ok, false)
    T.ok(res.pin.why:find("first"), res.pin.why)
    T.ok(indexOf(stepIds(res), "first") < indexOf(stepIds(res), "second"), "the order still respects the prerequisite")
  end)
  T.it("NexusCore passes the pin to the planner and Diagnose explains an infeasible one", function()
    local _, _, N = session({ q("quest:A", "quest", { questID = 1 }) },
      { gear = function() return { q("gear:Axe", "gear", { gearSource = "vendor", costCopper = 999999, itemID = 5 }) } end })
    N:Replan("x")
    local axe
    for id in pairs(N.current.graph.nodes) do if id:find("Axe") then axe = id end end
    N:Settings().pinned = axe
    local cur = N:Replan("pin")
    T.ok(cur.result.plan.steps[1] ~= axe, "not first: it costs more than you carry")
    local found = false
    for _, d in ipairs(N:Diagnose()) do if d.code == "pin_infeasible" then found = true end end
    T.ok(found, "pin_infeasible listed")
  end)
end)

T.describe("nexus review R02: graph metadata comes from production candidates", function()
  T.it("faction, unfinished prerequisites, travel and unknowns come from the quest pack fields", function()
    local _, ns = session()
    local A = ns.NexusAdapters
    local done = { [10] = true }
    local m = A.Meta({ key = "quest:X", kind = "quest", questID = 12, mapID = 1, estimatedTripSeconds = 240,
      questFaction = "Horde", preAll = { 10, 11 } }, { [11] = "opp:quests:quest:Y" }, function(id) return done[id] end)
    T.eq(m.faction, "Horde")
    T.eq(m.travelSeconds, 240)
    T.eq(#m.requires, 1)
    T.eq(m.requires[1], "opp:quests:quest:Y")
    local m2 = A.Meta({ key = "quest:Z", kind = "quest", questID = 13, preAny = { 20, 21 } }, {}, function() return false end)
    T.eq(m2.requires[1], "quest:q20", "a missing prerequisite outside the pool is named")
    local u = table.concat(m2.unknown, ",")
    T.ok(u:find("map") and u:find("excludes"), u)
    local m3 = A.Meta({ key = "gear:G", kind = "gear" })
    T.ok(table.concat(m3.unknown, ","):find("travel"))
  end)
  T.it("a quest for the other faction or with an unmet prerequisite is left out of a real Replan", function()
    local game, ns, N = session({
      q("quest:Ours", "quest", { questID = 1, mapID = 1 }),
      q("quest:Theirs", "quest", { questID = 2, questFaction = "Alliance", mapID = 1 }),
      q("quest:Later", "quest", { questID = 3, preAll = { 99 }, mapID = 1 }),
    })
    local cur = N:Replan("x")
    local why = {}
    for id, r in pairs(cur.rejected) do why[id:match("quest:(%w+)$") or id] = r end
    T.ok(tostring(why.Theirs):find("faction"), tostring(why.Theirs))
    T.ok(tostring(why.Later):find("prerequisite"), tostring(why.Later))
    T.ok(why.Ours == nil)
  end)
end)

T.describe("nexus review R03: unknown gold cost is not zero", function()
  T.it("free kinds are known zero; a vendor item or a repair has an unknown cost", function()
    local _, ns = session()
    local A = ns.NexusAdapters
    local r1 = A.Adapt("quests", q("quest:A", "quest"), 1)
    T.eq(r1.costCopper, 0) T.ok(not r1.costUnknown)
    local r2 = A.Adapt("gear", q("gear:Drop", "gear", { gearSource = "drop" }), 1)
    T.eq(r2.costCopper, 0)
    local r3 = A.Adapt("gear", q("gear:Shop", "gear", { gearSource = "vendor" }), 1)
    T.eq(r3.costCopper, nil) T.eq(r3.costUnknown, true)
    local r4 = A.Adapt("errands", q("errand:repair", "errand"), 1)
    T.eq(r4.costUnknown, true)
    local r5 = A.Adapt("errands", q("errand:vendor", "errand", { costCopper = 0 }), 1)
    T.eq(r5.costCopper, 0) T.ok(not r5.costUnknown)
  end)
  T.it("with a gold reserve an unknown cost is left out; without one it scores as uncertain, never as free", function()
    local _, ns = session()
    local known, unknown = opp("known", { kind = "gear" }), opp("unknown", { kind = "gear", costCopper = nil, costUnknown = true })
    local g = ns.NexusGraph.Build({ known, unknown }, {}, { copper = 5000, reserveCopper = 1000 })
    T.eq(g.invalid.unknown, "cost unknown")
    g = ns.NexusGraph.Build({ known, unknown }, {}, { copper = 5000 })
    T.ok(not g.invalid.unknown)
    local ranked = ns.NexusScore.Rank(g, GOALS, { copper = 5000 })
    local s = {}
    for _, r in ipairs(ranked) do s[r.id] = r.score end
    T.ok(s.unknown < s.known, "unknown cost costs uncertainty")
  end)
end)

T.describe("nexus review R04: real evidence with the original observation time", function()
  T.it("every opportunity cites an IntelEvidence record that resolves and sets its expiry", function()
    local game, ns = session()
    local recs = ns.NexusAdapters:Collect({}, 1, game.now, { quests = function() return { q("quest:A", "quest") } end })
    local o = recs[1]
    local row = ns.IntelEvidence:Get(o.evidenceIds[1])
    T.ok(row, "resolves")
    T.eq(o.expiresAt, row.expiresAt)
    local v4 = ns.IntelEvidence:AsV4(o.evidenceIds[1])
    T.ok(v4, "a valid v4 Evidence record")
  end)
  T.it("an older observation keeps its time and expires from it; a stale one is excluded", function()
    local game, ns = session()
    local A = ns.NexusAdapters
    local seen = game.now - 100
    local rec = A.Adapt("gather", q("gather:n", "gather", { observedAt = seen }), 1)
    local row = ns.IntelEvidence:Get(rec.evidenceIds[1])
    T.eq(row.observedAt, seen)
    T.eq(rec.expiresAt, seen + A.TTL)
    local gone, why = A.Adapt("gather", q("gather:old", "gather", { observedAt = game.now - A.TTL - 10 }), 1)
    T.eq(gone, nil) T.eq(why, "no usable evidence")
  end)
  T.it("Radar rebuilding its facts does not clear the planner's", function()
    local game, ns = session()
    local recs = ns.NexusAdapters:Collect({}, 1, game.now, { quests = function() return { q("quest:A", "quest") } end })
    ns.IntelEvidence:Clear("WhatNow")
    T.ok(ns.IntelEvidence:Get(recs[1].evidenceIds[1]))
  end)
end)

T.describe("nexus review R05: Act checks every boundary", function()
  local function ready()
    local calls = { go = 0 }
    local game, ns, N = session({
      q("quest:A", "quest", { questID = 1, benefit = 0.9, go = function() calls.go = calls.go + 1 end }),
      q("quest:B", "quest", { questID = 2, benefit = 0.7, go = function() calls.go = calls.go + 1 end }),
    })
    local cur = N:Replan("x")
    return game, ns, N, cur, calls
  end
  T.it("refuses in combat, for a skipped step, and for a step not in the plan", function()
    local game, ns, N, cur, calls = ready()
    local first = cur.result.plan.steps[1]
    game.combat = true
    T.eq(select(1, N:Act(first)), false)
    game.combat = false
    N:Settings().skipped[first] = true
    local ok, why = N:Act(first)
    T.eq(ok, false) T.ok(why:find("skipped"), why)
    N:Settings().skipped[first] = nil
    ok = N:Act("opp:quests:quest:Nope")
    T.eq(ok, false)
    T.eq(calls.go, 0)
  end)
  T.it("refuses when its evidence went stale even though the plan is young", function()
    local game, ns, N, cur, calls = ready()
    game:advance(ns.NexusAdapters.TTL + 5)
    local ok, why = N:Act(cur.result.plan.steps[1])
    T.eq(ok, false)
    T.ok(why:find("out of date") or why:find("evidence"), why)
    T.eq(calls.go, 0)
  end)
  T.it("runs only the declared intent: none does nothing", function()
    local _, _, N, cur = ready()
    local id = cur.result.plan.steps[1]
    cur.graph.nodes[id].opp.intent = "none"
    local ok = N:Act(id)
    T.eq(ok, false)
  end)
  T.it("when every check passes, the producer's go() runs once", function()
    local _, _, N, cur, calls = ready()
    local ok, kind = N:Act(cur.result.plan.steps[1])
    T.ok(ok) T.eq(kind, "waypoint") T.eq(calls.go, 1)
  end)
end)

T.describe("nexus review R06: the order matters", function()
  T.it("steps on the same map are grouped rather than interleaved", function()
    local _, ns = session()
    -- ids alternate maps (s1 map 1, s2 map 2, ...), so id order alone would interleave
    local opps = { opp("s1"), opp("s2"), opp("s3"), opp("s4") }
    local meta = { s1 = { mapID = 1 }, s3 = { mapID = 1 }, s2 = { mapID = 2 }, s4 = { mapID = 2 } }
    local res = plan(ns, opps, meta, { copper = 1000, mapID = 1 })
    local maps, changes = {}, 0
    for i, id in ipairs(stepIds(res)) do maps[i] = meta[id].mapID if i > 1 and maps[i] ~= maps[i - 1] then changes = changes + 1 end end
    T.eq(#maps, 4)
    T.eq(changes, 1, "one map change: " .. table.concat(stepIds(res), ","))
    T.eq(maps[1], 1, "starts where you are")
  end)
end)

T.describe("nexus review R07: the goal editor", function()
  T.it("add, reprioritise, pause, reserve and archive goals from the page (kept, never deleted)", function()
    local _, ns = session()
    local P, G = ns.NexusPage, ns.NexusGoals
    local g1 = P.AddGoal("level")
    local g2 = P.AddGoal("gold")
    T.eq(g1.priority, 1) T.eq(g2.priority, 2)
    local cards = P.GoalCards()
    T.eq(#cards, 2)
    local function act(card, label) for _, a in ipairs(card.actions) do if a[1] == label then a[2]() return end end error("no " .. label) end
    act(P.GoalCards()[2], "Higher")
    T.eq(G:Find(g2.goalId).priority, 1)
    act(P.GoalCards()[1], "Keep 1g more")
    local top = P.GoalCards()[1]
    T.ok(top.tags[3] and top.tags[3][1]:find("keep"), "reserve shown")
    act(P.GoalCards()[1], "Pause goal")
    act(P.GoalCards()[1], "Archive")
    local archived = 0
    for _, g in ipairs(G:All()) do if g.status == "archived" then archived = archived + 1 end end
    T.eq(archived, 1, "archived, still saved")
    T.eq(#G:All(), 2, "nothing deleted")
    for _, c in ipairs(P.GoalCards()) do for _, a in ipairs(c.actions) do T.ok(a[3], a[1] .. " has a tooltip") end end
  end)
end)

T.describe("nexus review R08: one source of recommendations", function()
  T.it("with the planner on What now? and Radar show the plan's steps; off, their own", function()
    local _, ns, N = session({ q("quest:A", "quest", { questID = 1, benefit = 0.9 }), q("quest:B", "quest", { questID = 2, benefit = 0.5 }) })
    local list = ns.WhatNow:List(true)
    T.eq(ns.WhatNow.provider, "nexus")
    T.ok(list[1] and list[1].nexusId, "a plan step")
    T.eq(list[1].nexusId, N.current.result.plan.steps[1])
    N:Settings().on = false
    ns.WhatNow:List(true)
    T.eq(ns.WhatNow.provider, "whatnow")
  end)
end)

T.describe("nexus review R09: prerequisites that only pay off later", function()
  T.it("a low-value prerequisite is planned before the valuable step it unlocks", function()
    local _, ns = session()
    local opps = { opp("chore", { benefit = 0.02, costSeconds = 3000, risk = 0.6, confidence = "community" }),
      opp("prize", { benefit = 1, costSeconds = 60 }) }
    local meta = { prize = { requires = { "chore" } } }
    local res, _, ranked = plan(ns, opps, meta, { copper = 1000 })
    local s = {}
    for _, r in ipairs(ranked) do s[r.id] = r.score end
    T.ok(s.chore <= 0, "the prerequisite alone is not worth it: " .. s.chore)
    T.ok(indexOf(stepIds(res), "chore") and indexOf(stepIds(res), "chore") < indexOf(stepIds(res), "prize"))
    T.ok(res.value > 0)
  end)
  T.it("skipping a prerequisite does not count as doing it", function()
    local _, _, N = session({
      q("quest:Pre", "quest", { questID = 1, benefit = 0.4 }),
      q("quest:Post", "quest", { questID = 2, benefit = 0.9, preAll = { 1 } }),
    })
    local cur = N:Replan("x")
    local pre
    for id in pairs(cur.graph.nodes) do if id:find("Pre$") then pre = id end end
    N:Settings().skipped[pre] = true
    cur = N:Replan("skip")
    local postWhy
    for id, why in pairs(cur.rejected) do if id:find("Post$") then postWhy = why end end
    T.ok(tostring(postWhy):find("prerequisite"), tostring(postWhy))
  end)
end)

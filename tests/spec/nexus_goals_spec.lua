-- OI02-05: the goal model. Several goals, per character or account, prioritised,
-- with deadlines and reserves; delete archives; problems explained, not fixed.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.NexusGoals
end

T.describe("nexus goal model", function()
  T.it("create, edit, pause, resume, complete and delete (archive) persist per scope", function()
    local game, ns, G = session()
    local a = G:Create("gold", { priority = 2, target = 100000, reserveCopper = 5000 })
    local b = G:Create("level", { scope = "account", priority = 1, target = 40 })
    T.ok(a and b)
    T.ok(ns.Nexus.Validate("Goal", a))
    T.ok(G:Edit(a.goalId, { priority = 1 }))
    T.ok(G:Pause(b.goalId))
    T.eq(G:Find(b.goalId).status, "paused")
    T.ok(G:Resume(b.goalId))
    T.ok(G:Complete(a.goalId))
    local c = G:Create("explore")
    T.ok(G:Delete(c.goalId))
    T.eq(G:Find(c.goalId).status, "archived", "delete keeps it, archived")
    local saved = game:logout()
    local _, _, G2 = session({ savedVariables = saved })
    T.eq(G2:Find(a.goalId).status, "done")
    T.eq(G2:Find(b.goalId).status, "active")
    T.eq(G2:Find(b.goalId).scope, "account")
    T.eq(G2:Find(c.goalId).status, "archived")
    -- account goals follow to another character; character goals don't
    local _, _, G3 = session({ savedVariables = saved, name = "Lumen", class = "PRIEST" })
    T.ok(G3:Find(b.goalId), "account goal seen by another character")
    T.eq(G3:Find(a.goalId), nil, "character goal stays with its character")
  end)

  T.it("invalid goals and edits are refused with the failing field, nothing half-changed", function()
    local _, _, G = session()
    local g, why = G:Create("fame")
    T.eq(g, nil) T.eq(why, "objective")
    g, why = G:Create("gold", { priority = 9 })
    T.eq(why, "priority")
    local ok = G:Create("gold")
    local good, field = G:Edit(ok.goalId, { priority = 0, target = 5 })
    T.eq(good, false) T.eq(field, "priority")
    T.eq(G:Find(ok.goalId).target, nil, "the failed edit changed nothing")
    T.eq(select(2, G:Edit(ok.goalId, { goalId = "x" })), "goalId")
  end)

  T.it("active goals sort by priority, then age; WhatNow's goal stands in when there are none", function()
    local game, ns, G = session()
    ns.WhatNow.Goal = function() return "gear" end
    local act = G:Active()
    T.eq(#act, 1) T.eq(act[1].objective, "gear") T.ok(act[1].implicit)
    local a = G:Create("gold", { priority = 3 })
    game.now = game.now + 10
    local b = G:Create("level", { priority = 1 })
    game.now = game.now + 10
    local c = G:Create("explore", { priority = 3 })
    act = G:Active()
    T.eq(act[1].goalId, b.goalId)
    T.eq(act[2].goalId, a.goalId)
    T.eq(act[3].goalId, c.goalId)
  end)

  T.it("conflicts and infeasible goals are explained, never silently overridden", function()
    local game, _, G = session()
    G:Create("level", { target = 70, priority = 1 })
    G:Create("level", { target = 10, priority = 2 })
    G:Create("gold", { target = 500, reserveCopper = 900000, priority = 1, deadline = game.now - 60 })
    local codes = {}
    for _, p in ipairs(G:Check(game.now, { level = 20, copper = 1000 })) do codes[p.code] = (codes[p.code] or 0) + 1 end
    T.eq(codes.target_unreachable, 1)
    T.eq(codes.already_reached, 2, "level 10 and the gold target")
    T.eq(codes.reserve_above_gold, 1)
    T.eq(codes.deadline_passed, 1)
    T.eq(codes.duplicate, 1)
    T.eq(codes.priority_tie, 1)
    for _, g in ipairs(G:All()) do T.eq(g.status, "active", "nothing was changed by the check") end
  end)
end)

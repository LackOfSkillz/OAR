-- OI03-10: preference and feedback model.
local T, mock = ...

local function session()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.NexusPreferences
end

T.describe("preference and feedback model (OI03-10)", function()
  T.it("useful, wrong, completed and not-now are told apart; ignored counts for nothing", function()
    local _, _, P = session()
    local src = {
      radar = { ["quest:A"] = { verdict = "useful", t = 10 }, ["quest:B"] = { verdict = "done", t = 10 },
        ["gear:C"] = { verdict = "wrong", t = 10 }, ["gold:D"] = { verdict = "snooze", t = 10 } },
      shown = { ["quest:E"] = 12, ["gold:F"] = 40 },
    }
    local adj, counts = P.Adjustments(src)
    T.eq(counts.quest.useful, 1) T.eq(counts.quest.completed, 1) T.eq(counts.quest.ignored, 1)
    T.ok(adj.quest > 0) T.ok(adj.gear < 0)
    T.eq(adj.gold, nil, "only not-now and ignored: no nudge at all")
    T.eq(counts.gold.ignored, 1) T.eq(counts.gold.neutral, 1)
  end)

  T.it("one suggestion is one vote: repeats don't amplify, the latest verdict wins", function()
    local _, _, P = session()
    local once = P.Adjustments({ radar = { ["quest:A"] = { verdict = "useful", t = 10 } } })
    local again = P.Adjustments({ radar = { ["quest:A"] = { verdict = "useful", t = 20 } },
      outcomes = { { kind = "quest_completed", attribution = "likely", stepId = "opp:quests:quest:A", at = 30 },
        { kind = "quest_completed", attribution = "likely", stepId = "opp:quests:quest:A", at = 31 } } })
    T.ok(again.quest <= once.quest + 1e-9, "the same suggestion counted once")
    local flipped = P.Adjustments({ radar = { ["quest:A"] = { verdict = "useful", t = 10 } }, skip = { ["quest:A"] = 50 } })
    T.ok(flipped.quest < 0, "a later Not useful replaces the earlier useful")
  end)

  T.it("bounded: a hundred votes still nudge by at most MAX_ADJ", function()
    local _, _, P = session()
    local radar = {}
    for i = 1, 100 do radar["quest:Q" .. i] = { verdict = "useful", t = i } end
    local adj = P.Adjustments({ radar = radar })
    T.ok(adj.quest <= P.MAX_ADJ + 1e-12)
  end)

  T.it("explicit goals dominate: the nudge never flips a goal-driven order", function()
    local _, ns, P = session()
    local function opp(id, kind) return { opportunityId = id, kind = kind, title = id, benefit = 0.7, confidence = "observed",
      evidenceIds = { "e" }, expiresAt = 1, intent = "none", revision = 1, costSeconds = 300, risk = 0.1, costCopper = 0 } end
    local g = ns.NexusGraph.Build({ opp("g1", "gold"), opp("q1", "quest") }, {}, { copper = 1000 })
    local ctx = { copper = 1000, preferences = { quest = P.MAX_ADJ, gold = -P.MAX_ADJ } }
    local ranked = ns.NexusScore.Rank(g, { { objective = "gold", priority = 1 } }, ctx)
    T.eq(ranked[1].id, "g1", "the gold goal still leads despite the strongest opposite feedback")
    local seen = false
    for _, t in ipairs(ranked[1].trace) do if t[1] == "your feedback" then seen = true end end
    T.ok(seen, "the nudge is in the score trace")
  end)

  T.it("opt-out removes the nudge; reset starts from now; undo brings it back; nothing is deleted", function()
    local game, ns, P = session()
    local N = ns.NexusCore
    ns.db.char.radarFeedback = { ["quest:A"] = { verdict = "useful", t = game.now - 100 } }
    local ctx = N:Context()
    T.ok(ctx.preferences.quest > 0)
    P.Settings(N).on = false
    T.eq(N:Context().preferences, nil, "switched off")
    P.Settings(N).on = true
    P.Reset(N)
    T.eq(N:Context().preferences.quest, nil, "votes before the reset are ignored")
    T.ok(ns.db.char.radarFeedback["quest:A"], "the feedback itself is kept")
    T.ok(P.Undo(N))
    T.ok(N:Context().preferences.quest > 0, "undo restores it")
  end)

  T.it("a reset or opt-out makes the current plan stale at once", function()
    local game, ns, P = session()
    local N = ns.NexusCore
    N:Settings().on = true
    local S = ns.WhatNow.SOURCES
    for k in pairs(S) do S[k] = function() return {} end end
    N:Replan("x")
    N:Settings().paused = true
    T.eq(select(1, N:IsStale()), false)
    P.Reset(N)
    T.eq(select(1, N:IsStale()), true)
  end)

  T.it("Explain says where a nudge came from", function()
    local _, _, P = session()
    local _, counts = P.Adjustments({ radar = { ["quest:A"] = { verdict = "useful", t = 1 } }, shown = { ["quest:B"] = 3 } })
    local text = P.Explain("quest", counts)
    T.ok(text:find("1 useful") and text:find("1 shown and passed over"), text)
    T.eq(P.Explain("gear", counts), "no feedback on these yet")
  end)
end)

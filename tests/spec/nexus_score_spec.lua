-- OI02-09: scoring and trade-offs.
local T, mock = ...

local function session()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.NexusScore, ns.NexusGraph
end

local function opp(id, t)
  local o = { opportunityId = id, kind = "quest", title = id, benefit = 0.5, confidence = "community",
    evidenceIds = { "ev:" .. id }, expiresAt = 1, intent = "none", revision = 1, costSeconds = 600, risk = 0.2 }
  for k, v in pairs(t or {}) do o[k] = v end
  return o
end
local GOLD = { { objective = "gold", priority = 1 } }

T.describe("nexus scoring", function()
  T.it("same input, same rank; ties break by id; trace adds up to the score", function()
    local _, _, S, G = session()
    local opps = { opp("b"), opp("a"), opp("c", { benefit = 0.9 }) }
    local r1 = S.Rank(G.Build(opps, {}, {}), GOLD, {})
    local r2 = S.Rank(G.Build(opps, {}, {}), GOLD, {})
    T.eq(r1[1].id, "c")
    T.eq(r1[2].id, "a", "a and b tie: id order")
    T.eq(r1[3].id, "b")
    for i = 1, 3 do
      T.eq(r1[i].id, r2[i].id)
      local sum = 0
      for _, t in ipairs(r1[i].trace) do sum = sum + t[2] end
      T.ok(math.abs(sum - r1[i].score) < 1e-9, "trace reconstructs the score")
      T.eq(r1[i].version, "nexus-score-1")
    end
  end)

  T.it("monotonic: more benefit never lowers the score, more time or gold never raises it", function()
    local _, _, S, G = session()
    local function score(t) return S.One(G.Build({ opp("x", t) }, {}, {}).nodes.x, GOLD, { copper = 100000 }) end
    T.ok(score({ benefit = 0.8 }) >= score({ benefit = 0.4 }))
    T.ok(score({ costSeconds = 3600 }) <= score({ costSeconds = 60 }))
    T.ok(score({ costCopper = 50000 }) <= score({ costCopper = 100 }))
    T.ok(score({ confidence = "inferred" }) < score({ confidence = "verified" }), "low confidence costs")
  end)

  T.it("bounds: the score stays within [-1, 1] for any valid record", function()
    local _, _, S, G = session()
    for _, t in ipairs({ { benefit = 0, costSeconds = 31536000, risk = 1, confidence = "unknown" }, { benefit = 1, costSeconds = 0, risk = 0, confidence = "verified" } }) do
      local s = S.One(G.Build({ opp("x", t) }, {}, {}).nodes.x, GOLD, {})
      T.ok(s >= -1 and s <= 1, tostring(s))
    end
  end)

  T.it("hard constraints dominate: the reserve and missing gold readings exclude, invalid nodes stay out", function()
    local _, _, S, G = session()
    local g = G.Build({ opp("cheap", { costCopper = 1000, benefit = 0.1 }), opp("dear", { costCopper = 60000, benefit = 1 }),
      opp("ally") }, { ally = { faction = "Alliance" } }, { faction = "Horde" })
    local ranked, rejected = S.Rank(g, GOLD, { copper = 80000, reserveCopper = 30000 })
    T.eq(#ranked, 1)
    T.eq(ranked[1].id, "cheap", "a great but unaffordable option never outranks the budget")
    T.eq(rejected.dear, "over budget")
    T.eq(rejected.ally, "faction: for Alliance")
    local _, rej2 = S.Rank(G.Build({ opp("dear", { costCopper = 10 }) }, {}, {}), GOLD, {})
    T.eq(rej2.dear, "cost with no gold reading")
  end)

  T.it("cross-unit: gold and time are normalised; unknown time adds uncertainty instead of counting zero", function()
    local _, _, S, G = session()
    local known = S.One(G.Build({ opp("x", { costSeconds = 0 }) }, {}, {}).nodes.x, GOLD, {})
    local unknown = S.One(G.Build({ opp("x", { costSeconds = nil }) }, {}, {}).nodes.x, GOLD, {})
    T.ok(unknown < known, "unknown time is not free")
    local fitGold = S.GoalFit("gold", GOLD)
    local fitQuest = S.GoalFit("quest", GOLD)
    T.ok(fitGold > fitQuest, "the goal shapes the weight")
    local mixed = S.GoalFit("quest", { { objective = "gold", priority = 1 }, { objective = "level", priority = 3 } })
    T.ok(mixed > fitQuest and mixed < 1, "several goals blend by priority")
  end)
end)

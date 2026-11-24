-- OI02-08: the Nexus dependency graph.
local T, mock = ...

local function session()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.NexusGraph
end

local function opp(id, benefit, cost)
  return { opportunityId = id, kind = "quest", title = id, benefit = benefit or 0.5, confidence = "community",
    evidenceIds = { "ev:" .. id }, expiresAt = 1, intent = "none", revision = 1, costCopper = cost }
end

T.describe("nexus dependency graph", function()
  T.it("prerequisites come first; an unmet one makes the node invalid with the reason", function()
    local _, _, G = session()
    local g = G.Build({ opp("b"), opp("a"), opp("c") },
      { b = { requires = { "a" } }, c = { requires = { "zzz" } } }, {})
    T.eq(table.concat(g.order, ","), "a,b")
    T.eq(g.invalid.c, "unmet prerequisite: zzz")
    local g2 = G.Build({ opp("c") }, { c = { requires = { "zzz" } } }, { done = { zzz = true } })
    T.eq(g2.invalid.c, nil, "a prerequisite already done counts")
  end)

  T.it("cycles are found and every node in the loop (and what needs it) is invalid", function()
    local _, _, G = session()
    local g = G.Build({ opp("a"), opp("b"), opp("c"), opp("d") },
      { a = { requires = { "b" } }, b = { requires = { "c" } }, c = { requires = { "a" } }, d = { requires = { "a" } } }, {})
    T.eq(g.invalid.a, "cycle") T.eq(g.invalid.b, "cycle") T.eq(g.invalid.c, "cycle")
    T.ok(g.invalid.d:find("needs a", 1, true))
    T.eq(#g.order, 0)
  end)

  T.it("faction mismatch, over budget and unknown travel are reported, not silently fixed", function()
    local _, _, G = session()
    local g = G.Build({ opp("ally"), opp("pricey", 0.5, 90000), opp("far"), opp("near") },
      { ally = { faction = "Alliance" }, far = { mapID = 1440 }, near = { mapID = 1440, travelSeconds = 240 } },
      { faction = "Horde", mapID = 1412, copper = 100000, reserveCopper = 20000 })
    T.eq(g.invalid.ally, "faction: for Alliance")
    T.eq(g.invalid.pricey, "over budget", "80g spendable, 90g cost")
    T.ok(g.nodes.far.travelUnknown, "unknown travel is unknown, not zero")
    T.eq(g.nodes.near.travelUnknown, nil)
    local travel
    for _, e in ipairs(g.edges) do if e.type == "travel" then travel = e end end
    T.eq(travel.seconds, 240)
  end)

  T.it("overlapping rewards count once; resource conflicts and exclusions are edges", function()
    local _, _, G = session()
    local g = G.Build({ opp("q1", 0.8, 30000), opp("q2", 0.6, 30000), opp("x") },
      { q1 = { overlap = "quest:214" }, q2 = { overlap = "quest:214", excludes = { "x" } } },
      { copper = 50000 })
    T.eq(g.nodes.q1.countedBenefit, 0.8)
    T.eq(g.nodes.q2.countedBenefit, 0, "the same reward isn't counted twice")
    T.eq(g.nodes.q2.notes[1], "overlap with q1")
    local types = {}
    for _, e in ipairs(g.edges) do types[e.type] = (types[e.type] or 0) + 1 end
    T.eq(types.excludes, 1)
    local conflicts = G.ResourceConflicts(g, { copper = 50000 })
    T.eq(#conflicts, 1, "q1 + q2 cost 60g of 50g")
  end)

  T.it("the same input gives the same graph", function()
    local _, _, G = session()
    local opps = { opp("c"), opp("a"), opp("b") }
    local meta = { c = { requires = { "a" } } }
    local a, b = G.Build(opps, meta, {}), G.Build(opps, meta, {})
    T.eq(table.concat(a.order, ","), table.concat(b.order, ","))
    T.eq(table.concat(a.order, ","), "a,b,c")
  end)
end)

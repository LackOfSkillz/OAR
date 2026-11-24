-- Intelligence/Score.lua  (OI02-09)
-- Versioned, explainable scoring of graph nodes for the Nexus planner.
--   utility = goalFit * countedBenefit
--             - time * timeCost - gold * goldCost - risk * riskCost - uncertainty * uncertaintyCost
-- goalFit: each active goal's weight for the opportunity's kind (WhatNow's
--   table, so both agree), averaged by goal priority (priority 1 counts most).
-- timeCost = seconds / (seconds + 900), in [0, 1); unknown time is not zero:
--   it adds to uncertainty instead.
-- goldCost = copper / spendable gold, capped at 1.
-- riskCost = the record's risk (1 - producer confidence), unknown counts 0.5.
-- uncertaintyCost: by confidence label, plus unknown time or travel.
-- Hard constraints dominate: invalid graph nodes and anything costing more than
-- the spendable gold are never scored. Ties break by id. Every result carries a
-- trace whose terms add up to its score exactly (to 1e-9).

local _, ns = ...
local S = { VERSION = "nexus-score-1" }
ns.NexusScore = S

S.WEIGHTS = { time = 0.3, gold = 0.3, risk = 0.2, uncertainty = 0.2 }
S.LABEL_UNCERTAINTY = { verified = 0, observed = 0.05, community = 0.15, inferred = 0.3, unknown = 0.5 }
S.PRIORITY_WEIGHT = { 1, 0.8, 0.6, 0.4, 0.2 }

local function kindWeights(objective)
  local W = ns.WhatNow and ns.WhatNow.WEIGHTS or {}
  return W[objective] or W.mix or {}
end

-- goal fit for a kind over the active goals (each { objective, priority })
function S.GoalFit(kind, goals)
  local sum, wsum = 0, 0
  for _, g in ipairs(goals or {}) do
    local pw = S.PRIORITY_WEIGHT[g.priority or 3] or 0.6
    sum = sum + pw * (kindWeights(g.objective)[kind] or 0.5)
    wsum = wsum + pw
  end
  if wsum == 0 then return kindWeights("mix")[kind] or 0.5 end
  return sum / wsum
end

-- Score one graph node: score, trace, or nil, reason (hard constraint)
function S.One(node, goals, ctx)
  ctx = ctx or {}
  local o = node.opp
  local spendable = ctx.copper and (ctx.copper - (ctx.reserveCopper or 0)) or nil
  if o.costCopper and o.costCopper > 0 then
    if not spendable then return nil, "cost with no gold reading" end
    if o.costCopper > spendable then return nil, "over budget" end
  end
  local W = S.WEIGHTS
  local fit = S.GoalFit(o.kind, goals)
  local benefit = node.countedBenefit ~= nil and node.countedBenefit or o.benefit
  local timeCost = o.costSeconds and (o.costSeconds / (o.costSeconds + 900)) or 0
  local goldCost = (o.costCopper and o.costCopper > 0) and math.min(1, o.costCopper / math.max(1, spendable)) or 0
  local riskCost = o.risk or 0.5
  local unc = S.LABEL_UNCERTAINTY[o.confidence] or 0.5
  if not o.costSeconds then unc = unc + 0.1 end
  if node.travelUnknown then unc = unc + 0.1 end
  unc = math.min(1, unc)
  local trace = {
    { "goal benefit", fit * benefit },
    { "time", -W.time * timeCost },
    { "gold", -W.gold * goldCost },
    { "risk", -W.risk * riskCost },
    { "uncertainty", -W.uncertainty * unc },
  }
  local score = 0
  for _, t in ipairs(trace) do score = score + t[2] end
  return score, trace
end

-- Rank a graph's valid nodes: { {id, score, trace} } best first, and rejected { [id] = reason }.
function S.Rank(graph, goals, ctx)
  local out, rejected = {}, {}
  for _, id in ipairs(graph.order) do
    local score, trace = S.One(graph.nodes[id], goals, ctx)
    if score then out[#out + 1] = { id = id, score = score, trace = trace, version = S.VERSION }
    else rejected[id] = trace end
  end
  for id, why in pairs(graph.invalid) do rejected[id] = why end
  table.sort(out, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.id < b.id
  end)
  return out, rejected
end

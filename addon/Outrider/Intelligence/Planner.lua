-- Intelligence/Planner.lua  (OI02-10; OI02-R01, R06, R09)
-- Bounded sequence planning over scored graph nodes (Graph.lua, Score.lua).
--   ns.NexusPlanner.Plan(graph, ranked, ctx, opts) -> result
-- A plan is an ordered sequence of up to HORIZON steps that respects
-- prerequisites (a step's requirements are earlier in the plan or already
-- done), mutual exclusions, the spendable gold (gold minus reserve) and an
-- optional time budget. Its value is the sum of the steps' scores minus a
-- MAP_CHANGE penalty each time the plan moves to another map (the first step
-- counts from where you are), so the order matters: steps on one map are
-- grouped. A plan's value must be above zero.
-- Candidates: the best-ranked steps that score above zero (at most
-- MAX_CANDIDATES), plus the prerequisites they need, whatever those score: a
-- step that is only worth it for what it unlocks is planned with what it
-- unlocks (R09). A good step whose prerequisite can't be planned is left out.
-- opts.pin: the step the player pinned. It is a planner input, not a reorder
-- afterwards (R01): it must pass every constraint as the first step (valid,
-- prerequisites done, affordable, within the time budget). If it can't, the
-- plan is made without it and result.pin says why (code pin_infeasible).
-- Search: beam search, BEAM states per depth, and a work cap (state
-- expansions): when the cap is hit the best plan found so far is returned with
-- truncated = true, never a made-up sequence. States are the same when they
-- hold the same steps and end on the same map; the better one is kept. Unknown
-- step time counts as UNKNOWN_SECONDS against a time budget (unknown is not free).
-- requiresAny (one of several prerequisites) is satisfied by any alternative
-- earlier in the plan or done; each plannable alternative is a candidate.
-- A step with an unknown gold cost is planned as "check the price first": it
-- adds nothing to the gold spent, so the plan is marked financial =
-- "unconfirmed" with those steps in result.unconfirmed (OI02-R13).
-- result: { plan = v4 Plan or nil, why, code, value, alternatives =
--   { {firstStep, value} }, truncated, work, pin = { id, ok, why, code },
--   financial = "confirmed"|"unconfirmed", unconfirmed = { ids } }

local _, ns = ...
local P = { MAX_CANDIDATES = 60, HORIZON = 8, BEAM = 16, MAX_WORK = 20000, UNKNOWN_SECONDS = 900, MAP_CHANGE = 0.05 }
ns.NexusPlanner = P

local function key(seq) return table.concat(seq, ">") end

-- The candidate steps: the pin (if it can be scored), the best-ranked steps
-- above zero whose prerequisites can all be planned, and those prerequisites
-- (any score). Returns cands (ids), score ({ [id] = score }), pinInfo.
function P.Candidates(graph, ranked, done, pinId)
  local function node(id) return graph.nodes[id] end
  local cands, score, pos, blocked = {}, {}, {}, {}
  for _, r in ipairs(ranked) do pos[r.id] = r end
  -- can id and its unfinished prerequisites all be planned? (memoized)
  local function plannable(id, depth, visiting)
    if done[id] then return true end
    if blocked[id] ~= nil then return not blocked[id] end
    if not pos[id] or depth > P.HORIZON or visiting[id] then return false end
    visiting[id] = true
    for _, req in ipairs(node(id).meta.requires or {}) do
      if not plannable(req, depth + 1, visiting) then visiting[id] = nil blocked[id] = true return false end
    end
    local alts = node(id).meta.requiresAny
    if alts then
      local any = false
      for _, alt in ipairs(alts) do if plannable(alt, depth + 1, visiting) then any = true break end end
      if not any then visiting[id] = nil blocked[id] = true return false end
    end
    visiting[id] = nil
    blocked[id] = false
    return true
  end
  local function add(id)
    if done[id] or score[id] or #cands >= P.MAX_CANDIDATES then return end
    for _, req in ipairs(node(id).meta.requires or {}) do add(req) end
    -- one of several: every plannable alternative is a candidate, the search picks
    for _, alt in ipairs(node(id).meta.requiresAny or {}) do
      if node(alt) and plannable(alt, 1, {}) then add(alt) end
    end
    if #cands < P.MAX_CANDIDATES and not score[id] then cands[#cands + 1] = id score[id] = pos[id].score end
  end
  local pinInfo
  if pinId then
    pinInfo = { id = pinId, ok = false }
    if not node(pinId) then pinInfo.why, pinInfo.code = "the pinned step is no longer suggested", "pin_gone"
    elseif graph.invalid[pinId] then pinInfo.why, pinInfo.code = tostring(graph.invalid[pinId]), "pin_infeasible"
    elseif not pos[pinId] then pinInfo.why, pinInfo.code = "it can't be scored (over budget or no gold reading)", "pin_infeasible"
    else score[pinId] = pos[pinId].score cands[#cands + 1] = pinId end
  end
  for _, r in ipairs(ranked) do
    if r.score > 0 and plannable(r.id, 1, {}) then add(r.id) end
  end
  return cands, score, pinInfo
end

function P.Plan(graph, ranked, ctx, opts)
  ctx, opts = ctx or {}, opts or {}
  local horizon = math.min(opts.horizon or P.HORIZON, P.HORIZON)
  local beam = opts.beam or P.BEAM
  local maxWork = opts.maxWork or P.MAX_WORK
  local spendable = ctx.copper and (ctx.copper - (ctx.reserveCopper or 0)) or nil
  local budgetSeconds = ctx.budgetSeconds
  local done = ctx.done or {}
  local function node(id) return graph.nodes[id] end
  local pinId = opts.pin
  local cands, score, pinInfo = P.Candidates(graph, ranked, done, pinId)
  if #cands == 0 then return { why = "nothing worth doing right now fits your goals", code = "no_candidates", work = 0, pin = pinInfo } end

  local function canAdd(state, id)
    if state.set[id] then return false end
    local n = node(id)
    for _, req in ipairs(n.meta.requires or {}) do
      if not state.set[req] and not done[req] then return false, "needs " .. tostring(req) .. " first" end
    end
    if n.meta.requiresAny then
      local any = false
      for _, alt in ipairs(n.meta.requiresAny) do if state.set[alt] or done[alt] then any = true break end end
      if not any then return false, "needs one of " .. table.concat(n.meta.requiresAny, ", ") .. " first" end
    end
    for _, x in ipairs(n.meta.excludes or {}) do if state.set[x] then return false, "can't be done with " .. x end end
    for other in pairs(state.set) do
      for _, x in ipairs(node(other).meta.excludes or {}) do if x == id then return false, "can't be done with " .. other end end
    end
    local c = n.opp.costCopper or 0 -- an unknown cost never reaches here as 0 under a reserve (Graph.lua)
    if c > 0 and (not spendable or state.copper + c > spendable) then return false, "over budget" end
    if budgetSeconds then
      local s = n.opp.costSeconds or P.UNKNOWN_SECONDS
      if state.seconds + s > budgetSeconds then return false, "over the time budget" end
    end
    return true
  end
  local function extend(st, id)
    local n = node(id)
    local seq = {}
    for i, s in ipairs(st.seq) do seq[i] = s end
    seq[#seq + 1] = id
    local set = {}
    for s in pairs(st.set) do set[s] = true end
    set[id] = true
    local map = n.meta.mapID or st.map
    local value = st.value + score[id]
    if n.meta.mapID and st.map and n.meta.mapID ~= st.map then value = value - P.MAP_CHANGE end
    return { seq = seq, set = set, value = value, map = map,
      copper = st.copper + math.max(0, n.opp.costCopper or 0), seconds = st.seconds + (n.opp.costSeconds or P.UNKNOWN_SECONDS) }
  end

  local start = { seq = {}, set = {}, value = 0, copper = 0, seconds = 0, map = ctx.mapID }
  local frontier = { start }
  local best, pinned = start, false
  if pinInfo and score[pinId] then
    local ok, why = canAdd(start, pinId)
    if ok then
      start = extend(start, pinId)
      frontier, best, pinned = { start }, start, true
      pinInfo.ok = true
    else
      pinInfo.why, pinInfo.code = why, "pin_infeasible"
    end
  end
  local firsts = {} -- best value seen per first step (for alternatives)
  local work, truncated = 0, false
  for _ = #start.seq + 1, horizon do
    local nextStates, seen = {}, {}
    for _, st in ipairs(frontier) do
      for _, id in ipairs(cands) do
        if work >= maxWork then truncated = true break end
        if canAdd(st, id) then
          work = work + 1
          local nx = extend(st, id)
          local sorted = {}
          for i, s in ipairs(nx.seq) do sorted[i] = s end
          table.sort(sorted)
          local k = key(sorted) .. "@" .. tostring(nx.map)
          local at = seen[k]
          if not at then
            nextStates[#nextStates + 1] = nx
            seen[k] = #nextStates
          elseif nx.value > nextStates[at].value then
            nextStates[at] = nx
          end
          local f = nx.seq[1]
          if not firsts[f] or nx.value > firsts[f] then firsts[f] = nx.value end
        end
      end
      if truncated then break end
    end
    if #nextStates == 0 then break end
    table.sort(nextStates, function(a, b)
      if a.value ~= b.value then return a.value > b.value end
      return key(a.seq) < key(b.seq)
    end)
    for i = #nextStates, beam + 1, -1 do nextStates[i] = nil end
    if nextStates[1].value > best.value then best = nextStates[1] end
    frontier = nextStates
    if truncated then break end
  end

  if #best.seq == 0 or (best.value <= 0 and not pinned) then
    return { why = budgetSeconds and "nothing fits the time and gold you have" or "nothing fits the gold you have",
      code = budgetSeconds and "over_time_or_gold" or "over_gold", work = work, truncated = truncated, pin = pinInfo }
  end
  local alternatives = {}
  for f, v in pairs(firsts) do if f ~= best.seq[1] then alternatives[#alternatives + 1] = { firstStep = f, value = v } end end
  table.sort(alternatives, function(a, b) if a.value ~= b.value then return a.value > b.value end return a.firstStep < b.firstStep end)
  for i = #alternatives, 4, -1 do alternatives[i] = nil end
  local reasons = { "goal_fit" }
  if spendable then reasons[#reasons + 1] = "gold_budget" end
  if budgetSeconds then reasons[#reasons + 1] = "time_budget" end
  if truncated then reasons[#reasons + 1] = "search_capped" end
  if pinned then reasons[#reasons + 1] = "pinned" elseif pinInfo then reasons[#reasons + 1] = "pin_infeasible" end
  -- unknown prices (OI02-R13): such a step is "check the price", not a
  -- confirmed purchase; the plan's gold is then not guaranteed
  local unconfirmed = {}
  for _, id in ipairs(best.seq) do if node(id).opp.costUnknown then unconfirmed[#unconfirmed + 1] = id end end
  if #unconfirmed > 0 then reasons[#reasons + 1] = "cost_unconfirmed" end
  local plan = { planId = "plan:" .. tostring(ctx.revision or 0) .. ":" .. tostring(work), snapshotRevision = ctx.revision or 0,
    steps = best.seq, reasonCodes = reasons, createdAt = ctx.now or time(), version = 1, truncated = truncated,
    budgetSeconds = budgetSeconds }
  local ok, field = ns.Nexus.Validate("Plan", plan)
  if not ok then return { why = "plan failed validation: " .. tostring(field), code = "invalid_plan", work = work, pin = pinInfo } end
  return { plan = plan, value = best.value, alternatives = alternatives, truncated = truncated, work = work, pin = pinInfo,
    unconfirmed = unconfirmed, financial = #unconfirmed > 0 and "unconfirmed" or "confirmed" }
end

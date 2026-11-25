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
local P = { MAX_CANDIDATES = 60, HORIZON = 8, BEAM = 16, MAX_WORK = 20000, UNKNOWN_SECONDS = 900, MAP_CHANGE = 0.05,
  LOCAL_MOVE = 120, BUFFER = 1.2, PARETO = 4, FAST_SHARE = 0.25 }
-- Review OI-FR06 (2026-11-25): step times depend on the order, so two states
-- with the same steps ending on the same map are no longer equivalent. Each
-- (steps, map) keeps up to PARETO states that no other beats on value, time
-- and gold together; under a time budget FAST_SHARE of the beam goes to the
-- quickest states the value cut would drop, so a cheaper path that leaves room
-- for one more step can still win.
-- OI04-02: a step's time is its trip plus its activity. When the step before
-- already brought you to the same map, the trip is shared: this step counts
-- LOCAL_MOVE instead of its trip from where you started. Plans report their
-- time as an estimate with a BUFFER margin, and a time budget is checked
-- against the margined figure (conservative).
function P.StepSeconds(st, n)
  local s = n.opp.costSeconds or P.UNKNOWN_SECONDS
  local trip = n.meta.travelSeconds
  -- shared travel only after a step whose map is known (st.here): a step with
  -- no map doesn't put you anywhere (OI-FR06)
  if #st.seq > 0 and st.here ~= false and n.opp.costSeconds and trip and n.meta.mapID and st.map == n.meta.mapID then
    s = math.max(0, s - trip) + math.min(trip, P.LOCAL_MOVE)
  end
  return s
end
ns.NexusPlanner = P

local function key(seq) return table.concat(seq, ">") end

-- The candidate steps: the pin (if it can be scored), the best-ranked steps
-- above zero whose prerequisites can all be planned, and those prerequisites
-- (any score). Returns cands (ids), score ({ [id] = score }), pinInfo,
-- unplannable ({ [id] = reason } for good steps left out for their prerequisites).
-- Cycle-safe and bounded (OI02-R15): the prerequisite walk carries the path it
-- is on and refuses to re-enter it; a "no" found only because of that cycle
-- guard depends on the path, so it is never remembered (only path-independent
-- answers are memoized, which makes the result independent of ranking order);
-- the walk is capped at DEP_DEPTH levels and DEP_WORK visits per call, and
-- running out counts as "can't plan it" (safe), never as an error. Expansion
-- keeps an in-progress set, so a cycle can't recurse.
P.DEP_DEPTH, P.DEP_WORK = 8, 4000
function P.Candidates(graph, ranked, done, pinId)
  local function node(id) return graph.nodes[id] end
  local cands, score, pos, memo, unplannable = {}, {}, {}, {}, {}
  for _, r in ipairs(ranked) do pos[r.id] = r end
  local work
  -- returns ok, cyclic (cyclic: the answer relied on the path guard)
  local function walk(id, depth, onPath)
    if done[id] then return true, false end
    if memo[id] ~= nil then return memo[id], false end
    if onPath[id] then return false, true end
    if not pos[id] or not node(id) then memo[id] = false return false, false end
    work = work + 1
    if depth > P.DEP_DEPTH or work > P.DEP_WORK then return false, true end -- bounded: not remembered
    onPath[id] = true
    local ok, cyclic = true, false
    for _, req in ipairs(node(id).meta.requires or {}) do
      local r, c = walk(req, depth + 1, onPath)
      cyclic = cyclic or c
      if not r then ok = false break end
    end
    local alts = ok and node(id).meta.requiresAny
    if alts then
      local any = false
      for _, alt in ipairs(alts) do
        local r, c = walk(alt, depth + 1, onPath)
        if r then any = true break end
        cyclic = cyclic or c
      end
      ok = any
    end
    onPath[id] = nil
    if ok or not cyclic then memo[id] = ok end
    return ok, cyclic
  end
  local function plannable(id)
    work = 0
    return (walk(id, 1, {}))
  end
  local adding = {}
  local function add(id)
    if done[id] or score[id] or adding[id] or #cands >= P.MAX_CANDIDATES then return end
    adding[id] = true
    for _, req in ipairs(node(id).meta.requires or {}) do add(req) end
    -- one of several: every plannable alternative is a candidate, the search picks
    for _, alt in ipairs(node(id).meta.requiresAny or {}) do
      if node(alt) and plannable(alt) then add(alt) end
    end
    adding[id] = nil
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
    if r.score > 0 then
      if plannable(r.id) then add(r.id) else unplannable[r.id] = "its prerequisites can't be planned (missing, a loop, or too deep)" end
    end
  end
  return cands, score, pinInfo, unplannable
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
  local cands, score, pinInfo, unplannable = P.Candidates(graph, ranked, done, pinId)
  if #cands == 0 then return { why = "nothing worth doing right now fits your goals", code = "no_candidates", work = 0, pin = pinInfo, unplannable = unplannable } end

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
      local s = P.StepSeconds(state, n)
      if (state.seconds + s) * P.BUFFER > budgetSeconds then return false, "over the time budget" end
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
    return { seq = seq, set = set, value = value, map = map, here = n.meta.mapID and true or false,
      copper = st.copper + math.max(0, n.opp.costCopper or 0), seconds = st.seconds + P.StepSeconds(st, n) }
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
          local bucket = seen[k]
          if not bucket then
            nextStates[#nextStates + 1] = nx
            seen[k] = { #nextStates }
          else
            local function beats(a, b) return a.value >= b.value and a.seconds <= b.seconds and a.copper <= b.copper end
            local dominated = false
            for _, j in ipairs(bucket) do
              local o = nextStates[j]
              if o and beats(o, nx) then dominated = true break end
            end
            if not dominated then
              local placed = false
              for _, j in ipairs(bucket) do
                local o = nextStates[j]
                if o and beats(nx, o) then
                  if placed then nextStates[j] = false else nextStates[j] = nx placed = true end
                end
              end
              if not placed then
                if #bucket < P.PARETO then
                  nextStates[#nextStates + 1] = nx
                  bucket[#bucket + 1] = #nextStates
                else
                  -- full: replace the lowest value if this one is higher
                  local wj
                  for _, j in ipairs(bucket) do
                    local o = nextStates[j]
                    if o and (not wj or o.value < nextStates[wj].value) then wj = j end
                  end
                  if wj and nx.value > nextStates[wj].value then nextStates[wj] = nx end
                end
              end
            end
          end
          local f = nx.seq[1]
          if not firsts[f] or nx.value > firsts[f] then firsts[f] = nx.value end
        end
      end
      if truncated then break end
    end
    local live = {}
    for _, st in ipairs(nextStates) do if st then live[#live + 1] = st end end
    nextStates = live
    if #nextStates == 0 then break end
    table.sort(nextStates, function(a, b)
      if a.value ~= b.value then return a.value > b.value end
      if a.seconds ~= b.seconds then return a.seconds < b.seconds end
      return key(a.seq) < key(b.seq)
    end)
    if #nextStates > beam then
      local fast = budgetSeconds and math.floor(beam * P.FAST_SHARE) or 0
      local keep = {}
      for i = 1, beam - fast do keep[i] = nextStates[i] end
      if fast > 0 then
        local rest = {}
        for i = beam - fast + 1, #nextStates do rest[#rest + 1] = nextStates[i] end
        table.sort(rest, function(a, b)
          if a.seconds ~= b.seconds then return a.seconds < b.seconds end
          if a.value ~= b.value then return a.value > b.value end
          return key(a.seq) < key(b.seq)
        end)
        for i = 1, math.min(fast, #rest) do keep[#keep + 1] = rest[i] end
        table.sort(keep, function(a, b)
          if a.value ~= b.value then return a.value > b.value end
          if a.seconds ~= b.seconds then return a.seconds < b.seconds end
          return key(a.seq) < key(b.seq)
        end)
      end
      nextStates = keep
    end
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
    unconfirmed = unconfirmed, financial = #unconfirmed > 0 and "unconfirmed" or "confirmed", unplannable = unplannable,
    estimateSeconds = best.seconds, bufferedSeconds = math.floor(best.seconds * P.BUFFER + 0.5) }
end

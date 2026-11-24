-- Intelligence/Planner.lua  (OI02-10)
-- Bounded sequence planning over scored graph nodes (Graph.lua, Score.lua).
--   ns.NexusPlanner.Plan(graph, ranked, ctx, opts) -> result
-- A plan is an ordered set of up to HORIZON steps that respects prerequisites
-- (a step's requirements are earlier in the plan or already done), mutual
-- exclusions, the spendable gold (gold minus reserve) and an optional time
-- budget. Its value is the sum of the steps' scores; only steps that score
-- above zero are worth adding. Search: beam search, BEAM states per depth,
-- at most MAX_CANDIDATES best-ranked nodes, and a work cap (state expansions):
-- when the cap is hit the best plan found so far is returned with
-- truncated = true, never a made-up sequence. Unknown step time counts as
-- UNKNOWN_SECONDS against a time budget (unknown is not free).
-- result: { plan = v4 Plan or nil, why = reason when nil, value, alternatives =
--   { {firstStep, value} }, truncated, work }

local _, ns = ...
local P = { MAX_CANDIDATES = 60, HORIZON = 8, BEAM = 16, MAX_WORK = 20000, UNKNOWN_SECONDS = 900 }
ns.NexusPlanner = P

local function key(seq) return table.concat(seq, ">") end

function P.Plan(graph, ranked, ctx, opts)
  ctx, opts = ctx or {}, opts or {}
  local horizon = math.min(opts.horizon or P.HORIZON, P.HORIZON)
  local beam = opts.beam or P.BEAM
  local maxWork = opts.maxWork or P.MAX_WORK
  local spendable = ctx.copper and (ctx.copper - (ctx.reserveCopper or 0)) or nil
  local budgetSeconds = ctx.budgetSeconds
  local done = ctx.done or {}

  -- candidates: positive scores, best first, at most MAX_CANDIDATES
  -- a good step's prerequisites come along with it (else it could never be planned)
  local cands, score, pos = {}, {}, {}
  for _, r in ipairs(ranked) do pos[r.id] = r end
  local function addWithReqs(id, depth)
    if score[id] or #cands >= P.MAX_CANDIDATES or depth > P.HORIZON then return end
    local r = pos[id]
    if not r or r.score <= 0 then return end
    for _, req in ipairs(graph.nodes[id].meta.requires or {}) do
      if not done[req] then addWithReqs(req, depth + 1) end
    end
    if #cands < P.MAX_CANDIDATES then cands[#cands + 1] = id score[id] = r.score end
  end
  for _, r in ipairs(ranked) do addWithReqs(r.id, 1) end
  if #cands == 0 then return { why = "nothing worth doing right now fits your goals", work = 0 } end

  local function node(id) return graph.nodes[id] end
  local function canAdd(state, id)
    if state.set[id] then return false end
    local n = node(id)
    for _, req in ipairs(n.meta.requires or {}) do
      if not state.set[req] and not done[req] then return false end
    end
    for _, x in ipairs(n.meta.excludes or {}) do if state.set[x] then return false end end
    for other in pairs(state.set) do
      for _, x in ipairs(node(other).meta.excludes or {}) do if x == id then return false end end
    end
    local c = n.opp.costCopper or 0
    if c > 0 and (not spendable or state.copper + c > spendable) then return false end
    if budgetSeconds then
      local s = n.opp.costSeconds or P.UNKNOWN_SECONDS
      if state.seconds + s > budgetSeconds then return false end
    end
    return true
  end

  local frontier = { { seq = {}, set = {}, value = 0, copper = 0, seconds = 0 } }
  local best = frontier[1]
  local firsts = {} -- best value seen per first step (for alternatives)
  local work, truncated = 0, false
  for _ = 1, horizon do
    local nextStates, seen = {}, {}
    for _, st in ipairs(frontier) do
      for _, id in ipairs(cands) do
        if work >= maxWork then truncated = true break end
        if canAdd(st, id) then
          work = work + 1
          local seq = {}
          for i, s in ipairs(st.seq) do seq[i] = s end
          seq[#seq + 1] = id
          -- the same set in a different order is one state (keep the first, deterministic)
          local sorted = {}
          for i, s in ipairs(seq) do sorted[i] = s end
          table.sort(sorted)
          local k = key(sorted)
          if not seen[k] then
            seen[k] = true
            local set = {}
            for s in pairs(st.set) do set[s] = true end
            set[id] = true
            local n = node(id)
            local ns_ = { seq = seq, set = set, value = st.value + score[id],
              copper = st.copper + (n.opp.costCopper or 0), seconds = st.seconds + (n.opp.costSeconds or P.UNKNOWN_SECONDS) }
            nextStates[#nextStates + 1] = ns_
            local f = seq[1]
            if not firsts[f] or ns_.value > firsts[f] then firsts[f] = ns_.value end
          end
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

  if #best.seq == 0 then
    return { why = budgetSeconds and "nothing fits the time and gold you have" or "nothing fits the gold you have",
      work = work, truncated = truncated }
  end
  local alternatives = {}
  for f, v in pairs(firsts) do if f ~= best.seq[1] then alternatives[#alternatives + 1] = { firstStep = f, value = v } end end
  table.sort(alternatives, function(a, b) if a.value ~= b.value then return a.value > b.value end return a.firstStep < b.firstStep end)
  for i = #alternatives, 4, -1 do alternatives[i] = nil end
  local reasons = { "goal_fit" }
  if spendable then reasons[#reasons + 1] = "gold_budget" end
  if budgetSeconds then reasons[#reasons + 1] = "time_budget" end
  if truncated then reasons[#reasons + 1] = "search_capped" end
  local plan = { planId = "plan:" .. tostring(ctx.revision or 0) .. ":" .. tostring(work), snapshotRevision = ctx.revision or 0,
    steps = best.seq, reasonCodes = reasons, createdAt = ctx.now or time(), version = 1, truncated = truncated,
    budgetSeconds = budgetSeconds }
  local ok, field = ns.Nexus.Validate("Plan", plan)
  if not ok then return { why = "plan failed validation: " .. tostring(field), work = work } end
  return { plan = plan, value = best.value, alternatives = alternatives, truncated = truncated, work = work }
end

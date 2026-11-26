-- Vanguard/WhatIf.lua
-- VG04-01/02/03: try other group makeups without touching the real group.
--   WI.From(snap, roleOf)        a hypothetical roster copied from the live one
--   WI.Edit(roster, op, ...)     a NEW roster with one change (role, move, lock,
--                                bench, unbench, add a candidate, drop a candidate)
--   WI.Optimize(roster, opts)    better subgroups (raid), bounded and deterministic
--   WI.Alternatives(roster, entry) single changes ranked by readiness gain
-- Nothing here invites, moves, marks or messages anyone: it's a model.
-- The subgroup objective counts verified-or-potential party-wide effects
-- (Battle Shout, auras, Trueshot Aura: Vanguard/Utility.lua, scope "party")
-- reaching each member, plus one healer per group where possible. A rule we
-- don't know isn't counted. Results are suggestions with their reasons, never
-- a promised improvement.

local _, ns = ...
ns.Vanguard = ns.Vanguard or {}
local V = ns.Vanguard
local WI = { VERSION = 1, GROUP = 5, MAX_ITER = 200, MAX_EVAL = 20000 }
V.WhatIf = WI

local function copy(t)
  local o = {}
  for k, v in pairs(t) do o[k] = type(v) == "table" and copy(v) or v end
  return o
end

function WI.From(snap, roleOf)
  local r = { version = WI.VERSION, members = {}, next = 1 }
  for i, m in ipairs(snap and snap.members or {}) do
    local role = roleOf and roleOf(m)
    r.members[#r.members + 1] = { id = "m" .. i, self = m.self or nil, name = m.name, class = V.Obs.Value(m.class),
      level = V.Obs.Num(m.level), role = role and role.value, group = V.Obs.Num(m.subgroup) or math.floor((i - 1) / WI.GROUP) + 1 }
  end
  return r
end

local function find(r, id) for i, m in ipairs(r.members) do if m.id == id then return m, i end end end

-- ops: role(id, role) move(id, group) lock(id, on) bench(id, on) add({class, role, level}) drop(id)
function WI.Edit(roster, op, id, value)
  local r = copy(roster)
  local m = id and find(r, id)
  if op == "role" and m then
    if value ~= nil and not V.Roster.ROLES[value] then return nil, "bad role" end
    m.role = value
  elseif op == "move" and m then
    if m.locked then return nil, "locked" end
    local g = tonumber(value)
    if not g or g < 1 or g > 8 or g ~= math.floor(g) then return nil, "bad group" end
    local n = 0
    for _, x in ipairs(r.members) do if x.group == g and not x.bench and x ~= m then n = n + 1 end end
    if n >= WI.GROUP then return nil, "group full" end
    m.group = g
  elseif op == "lock" and m then m.locked = value and true or nil
  elseif op == "bench" and m then
    if m.locked and value then return nil, "locked" end
    m.bench = value and true or nil
  elseif op == "add" then
    local c = type(id) == "table" and id or {}
    if not V.Roles.BY_CLASS[c.class] then return nil, "unknown class" end
    if c.role and not (V.Roles.BY_CLASS[c.class][c.role]) then return nil, "that class has no such role" end
    r.next = (r.next or 1) + 1
    local slot = 1
    local count = {}
    for _, x in ipairs(r.members) do if not x.bench then count[x.group] = (count[x.group] or 0) + 1 end end
    while (count[slot] or 0) >= WI.GROUP do slot = slot + 1 end
    r.members[#r.members + 1] = { id = "c" .. r.next, candidate = true, class = c.class, role = c.role,
      level = tonumber(c.level), group = slot }
  elseif op == "drop" and m then
    if not m.candidate then return nil, "only candidates you added can be dropped" end
    local _, i = find(r, id)
    table.remove(r.members, i)
  else
    return nil, "nothing to change"
  end
  return r
end

-- pseudo roster members for Utility/Assess
function WI.Members(roster)
  local O = V.Obs
  local out = {}
  for _, m in ipairs(roster.members) do
    if not m.bench then
      out[#out + 1] = { key = m.id, self = m.self, class = m.class and O.New("class", m.class, "manual") or O.Unknown("class"),
        level = m.level and O.New("level", m.level, "manual") or O.Unknown("level"), subgroup = O.New("subgroup", m.group, "manual"),
        role = m.role and O.New("role", m.role, "manual") or O.Unknown("role"), hypo = m }
    end
  end
  return out
end

-- party-scope capabilities a member could provide (potential or verified)
local function partyCaps(m, pseudo)
  local out = {}
  for _, cap in ipairs(V.Utility.ORDER) do
    local c = V.Utility.CAPS[cap]
    if c.scope == "party" then
      local s = V.Utility.Member(pseudo, cap).state
      if s == "verified" or s == "potential" then out[#out + 1] = cap end
    end
  end
  return out
end

-- objective for an assignment: { [index] = group }
local function score(members, caps, healer, assign)
  local groups = {}
  for i, g in pairs(assign) do
    local t = groups[g]
    if not t then t = { n = 0, caps = {}, heal = false } groups[g] = t end
    t.n = t.n + 1
    for _, cap in ipairs(caps[i]) do t.caps[cap] = true end
    if healer[i] then t.heal = true end
  end
  local s = 0
  for _, t in pairs(groups) do
    local k = 0
    for _ in pairs(t.caps) do k = k + 1 end
    s = s + k * t.n + (t.heal and 3 or 0)
  end
  return s
end

-- roster -> new roster with better subgroups, explanation
function WI.Optimize(roster, opts)
  opts = opts or {}
  local maxIter = opts.maxIter or WI.MAX_ITER
  local r = copy(roster)
  local active = {}
  for _, m in ipairs(r.members) do if not m.bench then active[#active + 1] = m end end
  local pseudo = WI.Members(r)
  local caps, healer, assign, size = {}, {}, {}, {}
  for i, m in ipairs(active) do
    caps[i] = partyCaps(m, pseudo[i])
    healer[i] = m.role == "HEALER"
    assign[i] = m.group
    size[m.group] = (size[m.group] or 0) + 1
  end
  local ngroups = math.max(1, math.ceil(#active / WI.GROUP))
  for g in pairs(size) do if g > ngroups then ngroups = g end end
  local best = score(active, caps, healer, assign)
  local start = best
  local evals, iter, moves = 0, 0, {}
  while iter < maxIter do
    iter = iter + 1
    local bestMove, bestScore = nil, best
    for i = 1, #active do
      if not active[i].locked then
        -- swap with someone in another group
        for j = i + 1, #active do
          if not active[j].locked and assign[i] ~= assign[j] then
            assign[i], assign[j] = assign[j], assign[i]
            evals = evals + 1
            local s = score(active, caps, healer, assign)
            assign[i], assign[j] = assign[j], assign[i]
            if s > bestScore then bestScore, bestMove = s, { "swap", i, j } end
          end
        end
        -- move to a group with room
        for g = 1, ngroups do
          if g ~= assign[i] and (size[g] or 0) < WI.GROUP then
            local old = assign[i]
            assign[i] = g
            evals = evals + 1
            local s = score(active, caps, healer, assign)
            assign[i] = old
            if s > bestScore then bestScore, bestMove = s, { "move", i, g } end
          end
        end
      end
      if evals > WI.MAX_EVAL then break end
    end
    if not bestMove or evals > WI.MAX_EVAL then break end
    if bestMove[1] == "swap" then
      local i, j = bestMove[2], bestMove[3]
      assign[i], assign[j] = assign[j], assign[i]
      moves[#moves + 1] = string.format("swap %s and %s", active[i].id, active[j].id)
    else
      local i, g = bestMove[2], bestMove[3]
      size[assign[i]] = size[assign[i]] - 1
      size[g] = (size[g] or 0) + 1
      assign[i] = g
      moves[#moves + 1] = string.format("move %s to group %d", active[i].id, g)
    end
    best = bestScore
  end
  for i, m in ipairs(active) do m.group = assign[i] end
  return r, { before = start, after = best, moves = moves, iterations = iter, evaluations = evals,
    note = best > start and "more party-wide effects reach more members" or "no better arrangement found" }
end

-- exhaustive reference for small rosters (tests): best objective value
function WI.Exhaustive(roster)
  local active = {}
  for _, m in ipairs(roster.members) do if not m.bench then active[#active + 1] = m end end
  local pseudo = WI.Members(roster)
  local caps, healer = {}, {}
  for i, m in ipairs(active) do caps[i] = partyCaps(m, pseudo[i]) healer[i] = m.role == "HEALER" end
  local ngroups = math.max(1, math.ceil(#active / WI.GROUP))
  local assign, size, best = {}, {}, -1
  local function rec(i)
    if i > #active then
      local s = score(active, caps, healer, assign)
      if s > best then best = s end
      return
    end
    if active[i].locked then
      assign[i] = active[i].group
      size[assign[i]] = (size[assign[i]] or 0) + 1
      rec(i + 1)
      size[assign[i]] = size[assign[i]] - 1
      return
    end
    for g = 1, ngroups do
      if (size[g] or 0) < WI.GROUP then
        assign[i] = g
        size[g] = (size[g] or 0) + 1
        rec(i + 1)
        size[g] = size[g] - 1
      end
    end
  end
  rec(1)
  return best
end

-- readiness of a hypothetical roster for a catalog entry
function WI.Readiness(roster, entry)
  local members = WI.Members(roster)
  local snap = { members = members, generation = "hypo" }
  return V.Assess.Build({ snap = snap, entry = entry, roleOf = function(m) return { value = V.Obs.Value(m.role), source = "manual" } end,
    profiles = {}, cachedAt = {}, st = {} })
end

-- single changes ranked by how much the readiness range moves (VG04-03)
function WI.Alternatives(roster, entry)
  local base = WI.Readiness(roster, entry)
  local out = {}
  local function try(label, r)
    if not r then return end
    local a = WI.Readiness(r, entry)
    local dl, dh = (a.score.low or 0) - (base.score.low or 0), (a.score.high or 0) - (base.score.high or 0)
    out[#out + 1] = { label = label, low = a.score.low, high = a.score.high, dLow = dl, dHigh = dh, gate = a.score.gate,
      why = (dl > 0 and "raises the low end" or dh > 0 and "raises the high end" or "no change in readiness") }
  end
  for _, m in ipairs(roster.members) do
    if not m.bench and m.class then
      for _, role in ipairs(V.Roles.Roles(m.class) or {}) do
        if role ~= m.role then
          try(string.format("%s as %s", m.self and "you" or m.id, role:lower()), (WI.Edit(roster, "role", m.id, role)))
        end
      end
    end
  end
  local n = 0
  for _, m in ipairs(roster.members) do if not m.bench then n = n + 1 end end
  if entry and entry.size and n < entry.size then
    for _, c in ipairs({ { "PRIEST", "HEALER" }, { "WARRIOR", "TANK" }, { "MAGE", "DAMAGER" } }) do
      try(string.format("add a %s %s", c[1]:lower(), c[2]:lower()), (WI.Edit(roster, "add", { class = c[1], role = c[2], level = entry.min })))
    end
  end
  table.sort(out, function(a, b)
    if a.dLow ~= b.dLow then return a.dLow > b.dLow end
    if a.dHigh ~= b.dHigh then return a.dHigh > b.dHigh end
    return a.label < b.label
  end)
  local reason
  if #out == 0 then reason = entry and entry.size and n >= entry.size and "the group is full and nobody can change role" or "nothing to try" end
  return out, base, reason
end

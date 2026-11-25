-- Intelligence/Graph.lua  (OI02-08)
-- The dependency graph over v4 opportunities for the Nexus planner.
--   ns.NexusGraph.Build(opps, meta, ctx) -> graph
-- opps: v4 Opportunity records. meta[opportunityId] (all optional):
--   requires = { ids }      must be done first (prerequisite edges)
--   requiresAny = { ids }   one of these must be done first (OI02-R14)
--   faction = "Alliance"|"Horde"
--   excludes = { ids }      can't both be done (mutually exclusive edges)
--   overlap = "key"         same reward or objective as others with this key
--   mapID = n, travelSeconds = n
-- ctx: { faction, mapID, copper, reserveCopper, done = { [id] = true } }
-- graph: { nodes = { [id] = node }, edges = { {from, to, type} },
--          invalid = { [id] = reason }, order = { ids, prerequisites first } }
-- Rules: a faction mismatch, an unmet or invalid prerequisite, a cycle or a
-- cost above the spendable gold makes a node invalid with its reason (it is
-- never quietly dropped). Overlapping rewards count once: the best node of an
-- overlap group keeps its benefit, the others get countedBenefit = 0 and an
-- "overlap" note. A different map with no travel estimate is marked
-- travelUnknown (its cost is unknown, not zero). A step whose gold cost is
-- unknown (costUnknown) is invalid ("cost unknown") when a gold reserve is set. Deterministic: ties by id.

local _, ns = ...
local G = {}
ns.NexusGraph = G

function G.Build(opps, meta, ctx)
  meta, ctx = meta or {}, ctx or {}
  local done = ctx.done or {}
  local g = { nodes = {}, edges = {}, invalid = {}, order = {} }
  local ids = {}
  for _, o in ipairs(opps or {}) do
    if type(o) == "table" and o.opportunityId and not g.nodes[o.opportunityId] then
      g.nodes[o.opportunityId] = { id = o.opportunityId, opp = o, meta = meta[o.opportunityId] or {},
        countedBenefit = o.benefit, notes = {} }
      ids[#ids + 1] = o.opportunityId
    end
  end
  table.sort(ids)
  local function bad(id, why) if not g.invalid[id] then g.invalid[id] = why end end
  local spendable = ctx.copper and (ctx.copper - (ctx.reserveCopper or 0)) or nil

  for _, id in ipairs(ids) do
    local n = g.nodes[id]
    local m = n.meta
    if m.faction and ctx.faction and m.faction ~= ctx.faction then bad(id, "faction: for " .. m.faction) end
    -- a solo session leaves out steps that need a group (and, through the
    -- prerequisite spread below, anything that needs them first)
    if ctx.solo and m.needsGroup then bad(id, "needs a group (you chose solo)") end
    for _, req in ipairs(m.requires or {}) do
      g.edges[#g.edges + 1] = { from = req, to = id, type = "requires" }
      if not done[req] and not g.nodes[req] then bad(id, "unmet prerequisite: " .. req) end
    end
    if m.requiresAny then
      local any = false
      for _, alt in ipairs(m.requiresAny) do
        g.edges[#g.edges + 1] = { from = alt, to = id, type = "requires_any" }
        if done[alt] or g.nodes[alt] then any = true end
      end
      if not any then bad(id, "unmet prerequisite: one of " .. table.concat(m.requiresAny, ", ")) end
    end
    for _, x in ipairs(m.excludes or {}) do
      if g.nodes[x] then g.edges[#g.edges + 1] = { from = id, to = x, type = "excludes" } end
    end
    local cost = n.opp.costCopper
    if spendable and cost and cost > 0 and cost > spendable then bad(id, "over budget") end
    -- an unknown price is not free (OI02-R03): with a gold reserve to protect
    -- it can't be planned; otherwise it is planned as uncertain, with a note
    if n.opp.costUnknown then
      if (ctx.reserveCopper or 0) > 0 then bad(id, "cost unknown")
      else n.notes[#n.notes + 1] = "gold cost unknown" end
    end
    if m.mapID and ctx.mapID and m.mapID ~= ctx.mapID then
      if m.travelSeconds then
        g.edges[#g.edges + 1] = { from = "here", to = id, type = "travel", seconds = m.travelSeconds }
      else
        n.travelUnknown = true
        n.notes[#n.notes + 1] = "travel time unknown"
      end
    end
  end

  -- cycles among prerequisites (iterative DFS colouring)
  local colour = {}
  local function visit(start)
    local stack = { { start, 1 } }
    local path = { start }
    colour[start] = 1
    while #stack > 0 do
      local top = stack[#stack]
      local reqs = g.nodes[top[1]] and g.nodes[top[1]].meta.requires or {}
      local nxt = reqs[top[2]]
      top[2] = top[2] + 1
      if nxt == nil then
        colour[top[1]] = 2
        stack[#stack] = nil
        path[#path] = nil
      elseif g.nodes[nxt] then
        if colour[nxt] == 1 then
          local inCycle = false
          for _, p in ipairs(path) do if p == nxt then inCycle = true end if inCycle then bad(p, "cycle") end end
        elseif not colour[nxt] then
          colour[nxt] = 1
          stack[#stack + 1] = { nxt, 1 }
          path[#path + 1] = nxt
        end
      end
    end
  end
  for _, id in ipairs(ids) do if not colour[id] then visit(id) end end

  -- invalid prerequisites spread to what needs them
  local changed = true
  while changed do
    changed = false
    for _, id in ipairs(ids) do
      if not g.invalid[id] then
        for _, req in ipairs(g.nodes[id].meta.requires or {}) do
          if g.invalid[req] then bad(id, "needs " .. req .. " (" .. g.invalid[req] .. ")") changed = true break end
        end
        local alts = g.nodes[id].meta.requiresAny
        if alts and not g.invalid[id] then
          local live = false
          for _, alt in ipairs(alts) do if done[alt] or (g.nodes[alt] and not g.invalid[alt]) then live = true break end end
          if not live then bad(id, "needs one of " .. table.concat(alts, ", ") .. " (none can be done)") changed = true end
        end
      end
    end
  end

  -- overlapping rewards count once
  local groups = {}
  for _, id in ipairs(ids) do
    local key = g.nodes[id].meta.overlap
    if key and not g.invalid[id] then groups[key] = groups[key] or {} table.insert(groups[key], id) end
  end
  for _, list in pairs(groups) do
    table.sort(list, function(a, b)
      local ba, bb = g.nodes[a].opp.benefit, g.nodes[b].opp.benefit
      if ba ~= bb then return ba > bb end
      return a < b
    end)
    for k = 2, #list do
      local n = g.nodes[list[k]]
      n.countedBenefit = 0
      n.notes[#n.notes + 1] = "overlap with " .. list[1]
      g.edges[#g.edges + 1] = { from = list[k], to = list[1], type = "overlap" }
    end
  end

  -- valid nodes, prerequisites first (Kahn, ties by id)
  local indeg, after = {}, {}
  for _, id in ipairs(ids) do if not g.invalid[id] then indeg[id] = 0 after[id] = {} end end
  for _, id in ipairs(ids) do
    if indeg[id] then
      for _, req in ipairs(g.nodes[id].meta.requires or {}) do
        if indeg[req] then indeg[id] = indeg[id] + 1 table.insert(after[req], id) end
      end
    end
  end
  local ready = {}
  for _, id in ipairs(ids) do if indeg[id] == 0 then ready[#ready + 1] = id end end
  while #ready > 0 do
    table.sort(ready)
    local id = table.remove(ready, 1)
    g.order[#g.order + 1] = id
    for _, nx in ipairs(after[id]) do
      indeg[nx] = indeg[nx] - 1
      if indeg[nx] == 0 then ready[#ready + 1] = nx end
    end
  end
  return g
end

-- pairs of valid nodes that together cost more than the spendable gold
function G.ResourceConflicts(g, ctx)
  local spendable = ctx and ctx.copper and (ctx.copper - (ctx.reserveCopper or 0))
  local out = {}
  if not spendable then return out end
  for i, a in ipairs(g.order) do
    for k = i + 1, #g.order do
      local b = g.order[k]
      local ca, cb = g.nodes[a].opp.costCopper or 0, g.nodes[b].opp.costCopper or 0
      if ca > 0 and cb > 0 and ca + cb > spendable then out[#out + 1] = { a, b } end
    end
  end
  return out
end

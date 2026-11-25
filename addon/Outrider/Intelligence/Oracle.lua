-- Intelligence/Oracle.lua  (OI05-02: deterministic comparisons)
-- Compares two scenarios (Intelligence/Scenario.lua) dimension by dimension,
-- with what Outrider can actually work out, and nothing more:
--   gold        exact copper difference
--   gear        GearScore's role score for each changed slot against what you
--               wear (a role score, not DPS); an item it can't score is unknown
--   level, role, professions   plain differences
--   talents     the point change; its effect is unknown here (the Forge models
--               what it can, OI05-03+)
--   zone risk   Guardian's label for the scenario's zone and level
--   plan        the planner's best plan value for each scenario's gold and
--               place over the current opportunities (a relative score, not a
--               promise), when there is a current plan
-- A dimension that can't be worked out is listed as unknown, never filled in.
-- A comparison whose base no longer matches the live character says
-- "refresh": the character changed since the scenarios were made. No numbers
-- are made more precise than their source (percentages to whole numbers).
-- Works offline: no companion, nothing sent.

local _, ns = ...
local O = { VERSION = "oracle-1" }
ns.Oracle = O
local S = function() return ns.Scenario end

local function gearScore(slotItem)
  local G = ns.GearScore
  if not (G and G.Compare) then return nil end
  local ok, r = pcall(G.Compare, G, "item:" .. slotItem)
  if ok and type(r) == "table" and tonumber(r.pct) then return r.pct end
end

function O.PlanValue(state)
  local N = ns.NexusCore
  local cur = N and N.current
  if not (cur and cur.graph) then return nil end
  local opps = {}
  for _, node in pairs(cur.graph.nodes) do opps[#opps + 1] = node.opp end
  table.sort(opps, function(a, b) return a.opportunityId < b.opportunityId end)
  local meta = {}
  for id, node in pairs(cur.graph.nodes) do meta[id] = node.meta end
  local ctx = { copper = state.copper, mapID = state.zone, now = time(), revision = 0 }
  local g = ns.NexusGraph.Build(opps, meta, ctx)
  local ranked = ns.NexusScore.Rank(g, ns.NexusGoals:Active(), ctx)
  local res = ns.NexusPlanner.Plan(g, ranked, ctx)
  return res.plan and res.value or 0
end

-- compare scenario a with scenario b; opts.liveHash (for staleness)
function O.Compare(a, b, opts)
  opts = opts or {}
  local ra, rb = S().Raw(a), S().Raw(b)
  local out = { version = O.VERSION, dims = {}, unknown = {}, notes = {} }
  if ra.baseHash ~= rb.baseHash then out.stale = "the two scenarios come from different snapshots: make them again" return out end
  if opts.liveHash and opts.liveHash ~= ra.baseHash then out.stale = "your character changed since these scenarios: refresh" return out end
  local sa, sb = ra.state, rb.state
  local function dim(name, va, vb, unit)
    out.dims[#out.dims + 1] = { name = name, a = va, b = vb, delta = (type(va) == "number" and type(vb) == "number") and (vb - va) or nil, unit = unit }
  end
  dim("gold", sa.copper, sb.copper, "copper")
  if sa.level ~= sb.level then dim("level", sa.level, sb.level, "levels") end
  if sa.role ~= sb.role then out.dims[#out.dims + 1] = { name = "role", a = sa.role, b = sb.role } end
  -- gear: each slot that differs
  local slots = {}
  for slot in pairs(sa.gear or {}) do slots[slot] = true end
  for slot in pairs(sb.gear or {}) do slots[slot] = true end
  for slot in pairs(slots) do
    local ia, ib = sa.gear[slot], sb.gear[slot]
    if ia ~= ib then
      -- an empty slot scores 0 (nothing worn); an item the scorer can't read is unknown
      local pa = ia == nil and 0 or (ia == (opts.worn or {})[slot] and 0 or gearScore(ia))
      local pb = ib == nil and 0 or (ib == (opts.worn or {})[slot] and 0 or gearScore(ib))
      if pa and pb then
        dim("gear slot " .. slot, math.floor(pa + 0.5), math.floor(pb + 0.5), "% role score vs what you wear")
      else
        out.unknown[#out.unknown + 1] = "gear slot " .. slot .. ": an item couldn't be scored"
      end
    end
  end
  -- talents: the change is known, its effect isn't
  local ta, tb = table.concat(sa.talents or {}, "/"), table.concat(sb.talents or {}, "/")
  if ta ~= tb then
    out.dims[#out.dims + 1] = { name = "talents", a = ta, b = tb }
    out.unknown[#out.unknown + 1] = "the effect of the talent change (not modelled here)"
  end
  for name, skill in pairs(sb.professions or {}) do
    local was = (sa.professions or {})[name]
    if was ~= skill then dim(name, was, skill, "skill") end
  end
  if sa.zone ~= sb.zone or sa.level ~= sb.level then
    local G = ns.Guardian
    if G then
      local x, y = G.ForMap(sa.zone, sa.level), G.ForMap(sb.zone, sb.level)
      if x.level == "unknown" or y.level == "unknown" then out.unknown[#out.unknown + 1] = "zone risk (no level data)"
      else out.dims[#out.dims + 1] = { name = "zone risk", a = x.level, b = y.level } end
    end
  end
  local va, vb = O.PlanValue(sa), O.PlanValue(sb)
  if va and vb then
    dim("plan value", math.floor(va * 100 + 0.5) / 100, math.floor(vb * 100 + 0.5) / 100, "relative planner score, not a promise")
  else
    out.unknown[#out.unknown + 1] = "the plan for each (no current plan: switch the planner on)"
  end
  -- trade-offs in words
  for _, d in ipairs(out.dims) do
    if d.name == "gold" and d.delta and d.delta < 0 then out.notes[#out.notes + 1] = "costs " .. (ns.Prices and ns.Prices.Money(-d.delta) or tostring(-d.delta)) end
    if d.name:find("^gear") and d.delta and d.delta > 0 then out.notes[#out.notes + 1] = string.format("%s about +%d%%", d.name, d.delta) end
  end
  return out
end

-- Intelligence/Guardian.lua  (OI04-12)
-- How risky a place is for you, from facts Outrider already has: the zone's
-- creature level range (ZoneLevels: creatures you saw there, a guide, or the
-- Classic creature pack, with the source named) and your own recorded deaths
-- there (Nearest's death history). No hidden-enemy detection, nothing from
-- secret values, no combat log. With no level data the risk says "unknown".
-- The advice is a label and, for a risky step, a safer step from the plan's
-- own alternatives; which way you go stays your choice.
--   safe       your level is at or above the zone's top
--   fair       inside the range
--   risky      1-2 levels under the bottom of the range
--   dangerous  3 or more under
-- Your deaths there raise it one step (at DEATHS or more).

local _, ns = ...
local C = ns.Compat
local G = { DEATHS = 2, ORDER = { "safe", "fair", "risky", "dangerous" } }
ns.Guardian = G
local RANK = { safe = 1, fair = 2, risky = 3, dangerous = 4 }

-- pure: level, lo, hi, deaths -> { level = label, why }
function G.Label(level, lo, hi, deaths, source)
  if not (level and lo and hi) then return { level = "unknown", why = "no level data for this zone" } end
  local l
  if level >= hi then l = "safe" elseif level >= lo then l = "fair" elseif lo - level <= 2 then l = "risky" else l = "dangerous" end
  local why = string.format("creatures %d-%d%s, you are %d", lo, hi, source and (" (" .. source .. ")") or "", level)
  if (deaths or 0) >= G.DEATHS then
    l = G.ORDER[math.min(4, RANK[l] + 1)]
    why = why .. string.format("; you died here %d times", deaths)
  end
  return { level = l, why = why }
end

function G.Deaths(mapID)
  local n = 0
  for _, d in ipairs(type(ns.db.global.deathHistory) == "table" and ns.db.global.deathHistory or {}) do
    if type(d) == "table" and d.mapID == mapID then n = n + 1 end
  end
  return n
end

function G.ForMap(mapID, level)
  local Z = ns.Modules:Get("ZoneLevels")
  local lo, hi, source
  if Z and Z.Range and mapID then
    local ok, a, b, c = pcall(Z.Range, Z, mapID)
    if ok then lo, hi, source = a, b, c end
  end
  return G.Label(level, lo, hi, G.Deaths(mapID), source)
end

-- a plan's steps with their risk, and a safer step for a risky one (from the
-- plan's alternatives); nothing is changed in the plan
function G.ForPlan(cur, level)
  local out = {}
  if not (cur and cur.result and cur.result.plan) then return out end
  local safe
  for _, alt in ipairs(cur.result.alternatives or {}) do
    local n = cur.graph.nodes[alt.firstStep]
    if n and n.meta.mapID and RANK[G.ForMap(n.meta.mapID, level).level] and RANK[G.ForMap(n.meta.mapID, level).level] <= 2 then
      safe = safe or { id = alt.firstStep, title = n.opp.title }
    end
  end
  for _, id in ipairs(cur.result.plan.steps) do
    local n = cur.graph.nodes[id]
    local r = n and n.meta.mapID and G.ForMap(n.meta.mapID, level) or { level = "unknown", why = "no map for this step" }
    if (r.level == "risky" or r.level == "dangerous") and safe and safe.id ~= id then r.safer = safe end
    out[id] = r
  end
  return out
end

function G.Level() return tonumber(C.Readable(C.Call("UnitLevel", "player"))) or 1 end

-- Vanguard/Readiness.lua
-- VG03-03: the readiness math (spec section 8). Pure: no game calls.
-- Each applicable requirement j has a weight w_j > 0 and a fulfilment range
-- [l_j, u_j] in [0, 1]: a known result has l = u; an unknown one is [0, 1].
--   score range  = 100 * sum(w l) / sum(w)  ..  100 * sum(w u) / sum(w)
--   known-only   = 100 * sum(w f) / sum(known w), labeled partial
--   coverage     = known weight / total weight
-- A point index is shown only when coverage >= POINT_COVERAGE and at least
-- one requirement has a target; otherwise the range (or nothing).
-- Critical checks stand apart from the score: a confirmed miss blocks, an
-- unknown one is "not established", all known and met is "prerequisites
-- observed" (not a promise of success). This is a readiness index, never a
-- chance of winning.

local _, ns = ...
ns.Vanguard = ns.Vanguard or {}
local Rd = { VERSION = 1, POINT_COVERAGE = 0.8 }
ns.Vanguard.Readiness = Rd

local function clamp01(x) if x ~= x then return 0 end if x < 0 then return 0 elseif x > 1 then return 1 end return x end

-- results: { { id, weight, critical, l, u, known } } (known = l == u)
function Rd.Score(results)
  local W, lo, hi, KW, kf = 0, 0, 0, 0, 0
  local gate, blocking, open = "none", {}, {}
  local criticalSeen = false
  for _, r in ipairs(results or {}) do
    local w = tonumber(r.weight) or 0
    if w > 0 and w == w and w < math.huge then
      local l, u = clamp01(tonumber(r.l) or 0), clamp01(tonumber(r.u) or 1)
      if u < l then l, u = u, l end
      W, lo, hi = W + w, lo + w * l, hi + w * u
      if l == u then KW, kf = KW + w, kf + w * l end
      if r.critical then
        criticalSeen = true
        if u == 0 then blocking[#blocking + 1] = r.id
        elseif l < 1 then open[#open + 1] = r.id end
      end
    end
  end
  local out = { version = Rd.VERSION, totalWeight = W, knownWeight = KW, blocking = blocking, notEstablished = open }
  if W == 0 then
    out.coverage, out.state = 0, "no requirements"
    return out
  end
  out.coverage = KW / W
  out.low, out.high = 100 * lo / W, 100 * hi / W
  if KW > 0 then out.knownOnly = 100 * kf / KW end
  if out.coverage >= Rd.POINT_COVERAGE and out.knownOnly then out.point = out.knownOnly end
  if #blocking > 0 then gate = "blocked"
  elseif #open > 0 then gate = "not established"
  elseif criticalSeen then gate = "prerequisites observed" end
  out.gate = gate
  out.state = out.point and "point" or (KW > 0 and "range" or "unknown")
  return out
end

function Rd.Text(s)
  if not s or s.state == "no requirements" then return "nothing to check" end
  local function p(n) return string.format("%d", math.floor(n + 0.5)) end
  local cov = string.format("%d%% known", math.floor(s.coverage * 100 + 0.5))
  if s.state == "point" then return p(s.point) .. " of 100 (" .. cov .. ")" end
  if s.state == "range" then return p(s.low) .. " to " .. p(s.high) .. " (" .. cov .. ")" end
  return "unknown (" .. cov .. ")"
end

-- Vanguard/Observation.lua
-- VG01-03: one observed fact with where it came from and how sure it is
-- (spec section 7, Observation). Pure; no game calls except the secret check.
--
--   local o = Obs.New("level", 29, "native", { unit = "level" })
--   Obs.Num(o)   -> 29, or nil when the fact is not known (never 0)
--
-- Rules: a secret value is refused before anything compares, formats or
-- stores it (status unknown, reason "secret"); nil is unknown, not zero;
-- numbers must be finite; strings are capped; tables are not values.

local _, ns = ...
local C = ns.Compat
ns.Vanguard = ns.Vanguard or {}
local O = {}
ns.Vanguard.Obs = O

O.STATUS = { known = true, unknown = true, stale = true, conflicting = true, unsupported = true }
O.SOURCE = { native = true, self = true, peer = true, manual = true, catalog = true, model = true }
O.MAX_STRING = 80
O.MAX_KIND = 40

local function finite(v) return v == v and v ~= math.huge and v ~= -math.huge end
O.Finite = finite

local function stamp() return (GetTime and GetTime()) or 0 end

-- opts: unit, status, reason, at, expiresAt, scope, rev, evidence
function O.New(kind, value, source, opts)
  opts = opts or {}
  local o = { kind = tostring(kind or "?"):sub(1, O.MAX_KIND), source = O.SOURCE[source] and source or "native",
    unit = opts.unit, scope = opts.scope, rev = opts.rev, evidence = opts.evidence,
    observedAt = opts.at or stamp(), expiresAt = opts.expiresAt }
  -- the secret check comes first: nothing below may touch a secret
  if C.IsSecret(value) then
    o.status, o.reason = "unknown", "secret"
    return o
  end
  local t = type(value)
  if value == nil then
    o.status, o.reason = opts.status == "unsupported" and "unsupported" or "unknown", opts.reason or "not readable"
  elseif t == "number" then
    if finite(value) then o.value, o.status = value, "known"
    else o.status, o.reason = "unknown", "not a finite number" end
  elseif t == "string" then
    o.value, o.status = value:sub(1, O.MAX_STRING), "known"
  elseif t == "boolean" then
    o.value, o.status = value, "known"
  else
    o.status, o.reason = "unsupported", "not a simple value"
  end
  if o.status == "known" and opts.status and O.STATUS[opts.status] then
    o.status, o.reason = opts.status, opts.reason
  end
  return o
end

function O.Unknown(kind, reason, source) return O.New(kind, nil, source, { reason = reason }) end
function O.Unsupported(kind, reason) return O.New(kind, nil, "native", { status = "unsupported", reason = reason }) end

function O.Known(o) return type(o) == "table" and o.status == "known" and o.value ~= nil end

-- the number, only when it is known; unknown never turns into 0
function O.Num(o)
  if O.Known(o) and type(o.value) == "number" then return o.value end
  return nil
end

function O.Value(o) if O.Known(o) then return o.value end end

-- an expired fact is kept but marked stale (D27: stale data is shown as stale)
function O.Age(o, t)
  if type(o) ~= "table" then return o end
  if o.status == "known" and o.expiresAt and (t or stamp()) >= o.expiresAt then
    local s = {}
    for k, v in pairs(o) do s[k] = v end
    s.status, s.reason = "stale", "expired"
    return s
  end
  return o
end

-- validation for anything built elsewhere or read back
function O.Valid(o)
  if type(o) ~= "table" then return false, "not a table" end
  if not O.STATUS[o.status] then return false, "bad status" end
  if not O.SOURCE[o.source] then return false, "bad source" end
  if type(o.kind) ~= "string" or #o.kind > O.MAX_KIND then return false, "bad kind" end
  local v = o.value
  if C.IsSecret(v) then return false, "secret value" end
  if o.status == "known" and v == nil then return false, "known without a value" end
  if type(v) == "number" and not finite(v) then return false, "not finite" end
  if type(v) == "string" and #v > O.MAX_STRING then return false, "string too long" end
  if v ~= nil and type(v) ~= "number" and type(v) ~= "string" and type(v) ~= "boolean" then return false, "bad value type" end
  for _, k in ipairs({ "observedAt", "expiresAt" }) do
    if o[k] ~= nil and (type(o[k]) ~= "number" or not finite(o[k])) then return false, "bad " .. k end
  end
  return true
end

-- several facts about the same thing: agree -> known, disagree -> conflicting
function O.Merge(kind, list)
  local seen, first
  for _, o in ipairs(list or {}) do
    if O.Known(o) then
      if first == nil then first = o
      elseif o.value ~= first.value then seen = true end
    end
  end
  if not first then return O.Unknown(kind, "no readable source") end
  if seen then
    local c = O.New(kind, nil, first.source, { reason = "sources disagree" })
    c.status = "conflicting"
    return c
  end
  return first
end

-- Intelligence/Contracts.lua  (OI02-01)
-- Nexus v4 records, additive to the v1-v3 snapshot/advice/opportunity
-- contracts (which stay unchanged): Evidence, CharacterState, Goal,
-- Opportunity, Plan, Outcome. The spec below is a copy of
-- docs/contracts/nexus_v4.lua, the single source both Lua and the Python
-- companion read; tests/spec/nexus_contracts_spec.lua fails if they differ,
-- and both validators must agree on docs/contracts/nexus_v4_fixtures.lua.
-- Validation is strict: unknown fields, wrong types, out-of-range numbers,
-- unknown enum values and over-long lists are rejected (nothing executable
-- can ride along in a record).

local _, ns = ...
local N = {}
ns.Nexus = N

N.SPEC = {
  version = 4,
  types = {
    id = { kind = "id", max = 120 }, -- letters, digits and _ - : . @ only
    text = { kind = "string", max = 300 },
    title = { kind = "string", max = 180 },
    time = { kind = "integer", min = 0, max = 4102444800 },
    count = { kind = "integer", min = 0, max = 1000000000 },
    copper = { kind = "integer", min = -1000000000000, max = 1000000000000 },
    seconds = { kind = "integer", min = 0, max = 31536000 },
    unit = { kind = "number", min = 0, max = 1 },
    level = { kind = "integer", min = 1, max = 60 },
    priority = { kind = "integer", min = 1, max = 5 },
    flag = { kind = "boolean" },
  },
  enums = {
    evidenceKind = { "quest", "gear", "bag", "location", "talent", "auction", "historical", "errand", "generic" },
    confidence = { "observed", "verified", "community", "inferred", "unknown" },
    privacy = { "local", "exportable" },
    sourceType = { "module", "pack", "player", "client" },
    class = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID", "UNKNOWN" },
    role = { "tank", "healer", "melee", "ranged", "caster", "pet", "unknown" },
    roleSource = { "explicit", "observed", "unknown" },
    faction = { "Alliance", "Horde", "Neutral", "unknown" },
    goalScope = { "char", "account" },
    objective = { "level", "gold", "gear", "professions", "explore", "mix" },
    goalStatus = { "active", "paused", "done", "archived" },
    opportunityKind = { "quest", "dungeon", "errand", "gold", "gather", "profession", "gear", "rare", "travel", "explore" },
    intent = { "waypoint", "panel", "none" },
    result = { "done", "skipped", "failed", "unknown" },
    attribution = { "direct", "likely", "unknown" },
    feedback = { "useful", "wrong", "dismiss", "none" },
  },
  records = {
    Evidence = {
      { "evidenceId", "id", true }, { "kind", "enum:evidenceKind", true }, { "sourceId", "id", true },
      { "sourceType", "enum:sourceType", true }, { "observedAt", "time", true }, { "expiresAt", "time", true },
      { "confidence", "enum:confidence", true }, { "privacy", "enum:privacy", true },
      { "clientBuild", "text", false }, { "packRevision", "text", false }, { "sampleCount", "count", false },
    },
    CharacterState = {
      { "characterKey", "id", true }, { "classToken", "enum:class", true }, { "role", "enum:role", true },
      { "roleSource", "enum:roleSource", true }, { "level", "level", true }, { "faction", "enum:faction", true },
      { "takenAt", "time", true }, { "revision", "count", true }, { "copper", "copper", false },
    },
    Goal = {
      { "goalId", "id", true }, { "scope", "enum:goalScope", true }, { "objective", "enum:objective", true },
      { "priority", "priority", true }, { "status", "enum:goalStatus", true }, { "createdAt", "time", true },
      { "target", "count", false }, { "deadline", "time", false }, { "reserveCopper", "copper", false },
    },
    Opportunity = {
      { "opportunityId", "id", true }, { "kind", "enum:opportunityKind", true }, { "title", "title", true },
      { "benefit", "unit", true }, { "confidence", "enum:confidence", true }, { "evidenceIds", "list:id:16", true },
      { "expiresAt", "time", true }, { "intent", "enum:intent", true }, { "revision", "count", true },
      { "costSeconds", "seconds", false }, { "costCopper", "copper", false }, { "risk", "unit", false },
      { "legacyCandidateId", "id", false }, { "why", "text", false }, { "costUnknown", "flag", false }, { "freshnessUnknown", "flag", false },
    },
    Plan = {
      { "planId", "id", true }, { "snapshotRevision", "count", true }, { "steps", "list:id:8", true },
      { "reasonCodes", "list:id:16", true }, { "createdAt", "time", true }, { "version", "count", true },
      { "truncated", "flag", true }, { "budgetSeconds", "seconds", false },
    },
    Outcome = {
      { "eventId", "id", true }, { "sessionId", "id", true }, { "startAt", "time", true },
      { "result", "enum:result", true }, { "attribution", "enum:attribution", true },
      { "planId", "id", false }, { "stepId", "id", false }, { "endAt", "time", false }, { "feedback", "enum:feedback", false },
    },
  },
}

local function enumSet(name)
  N.sets = N.sets or {}
  local set = N.sets[name]
  if not set then
    set = {}
    for _, v in ipairs(N.SPEC.enums[name] or {}) do set[v] = true end
    N.sets[name] = set
  end
  return set
end

local function finite(n) return type(n) == "number" and n == n and n > -math.huge and n < math.huge end

local function checkType(tname, v)
  if tname:sub(1, 5) == "enum:" then
    return type(v) == "string" and enumSet(tname:sub(6))[v] == true
  end
  if tname:sub(1, 5) == "list:" then
    local inner, max = tname:match("^list:([%w]+):(%d+)$")
    if type(v) ~= "table" then return false end
    local n = 0
    for k in pairs(v) do
      if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then return false end
      n = n + 1
    end
    if n > tonumber(max) then return false end
    for i = 1, n do if v[i] == nil or not checkType(inner, v[i]) then return false end end
    return true
  end
  local t = N.SPEC.types[tname]
  if not t then return false end
  if ns.Compat and ns.Compat.IsSecret and ns.Compat.IsSecret(v) then return false end
  if t.kind == "id" then
    return type(v) == "string" and #v >= 1 and #v <= t.max and v:find("^[%w_:%.@%-]+$") ~= nil
  elseif t.kind == "string" then
    return type(v) == "string" and #v <= t.max and not v:find("[%c|]")
  elseif t.kind == "integer" then
    return finite(v) and v == math.floor(v) and v >= t.min and v <= t.max
  elseif t.kind == "number" then
    return finite(v) and v >= t.min and v <= t.max
  elseif t.kind == "boolean" then
    return type(v) == "boolean"
  end
  return false
end
N.CheckType = checkType

-- ok, field: the first failing field name ("unknownField" for extras)
function N.Validate(record, t)
  local fields = N.SPEC.records[record]
  if not fields then return false, "record" end
  if type(t) ~= "table" then return false, "table" end
  local known = {}
  for _, f in ipairs(fields) do
    known[f[1]] = true
    local v = t[f[1]]
    if v == nil then
      if f[3] then return false, f[1] end
    elseif not checkType(f[2], v) then
      return false, f[1]
    end
  end
  for k in pairs(t) do if not known[k] then return false, "unknownField" end end
  -- cross-field rules
  if record == "Evidence" and t.expiresAt < t.observedAt then return false, "expiresAt" end
  if record == "Outcome" and t.endAt and t.endAt < t.startAt then return false, "endAt" end
  return true
end

-- v3 opportunity card (Intelligence/Opportunity.lua) -> v4 Opportunity.
-- The v3 card itself is not changed; this is a read-only view.
local KIND = { quest = "quest", dungeon = "dungeon", errand = "errand", gold = "gold", gather = "gather",
  profession = "profession", gear = "gear", rare = "rare", travel = "travel", explore = "explore" }
function N.FromV3Opportunity(card, revision)
  if type(card) ~= "table" or type(card.candidateId) ~= "string" then return nil, "card" end
  local id = "opp:" .. card.candidateId:gsub("[^%w_:%.@%-]", "_")
  local rec = { opportunityId = id:sub(1, 120), kind = KIND[card.kind] or "errand", title = card.title,
    benefit = math.max(0, math.min(1, tonumber(card.score) or 0)), confidence = card.label or "unknown",
    evidenceIds = { card.evidenceId }, expiresAt = card.expiresAt, intent = "none", revision = revision or 1,
    legacyCandidateId = card.candidateId:gsub("[^%w_:%.@%-]", "_"):sub(1, 120), why = card.why }
  local ok, field = N.Validate("Opportunity", rec)
  if not ok then return nil, field end
  return rec
end

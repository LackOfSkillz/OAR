-- Safe adapter over WhatNow candidate data; no inferred action is executable.
local _, ns = ...
local O = { SCHEMA = 3 }
ns.IntelOpportunity = O
local function finite(n) return type(n) == "number" and n == n and n >= 0 and n < math.huge end
local function plain(s, max)
  if ns.Compat.IsSecret(s) or type(s) ~= "string" then return nil end
  s = s:gsub("|", ""):gsub("[%z\1-\31]", " ")
  return s:sub(1, max)
end
function O:FromWhatNow(candidate, profile, evidence)
  if type(candidate) ~= "table" or ns.Compat.IsSecret(candidate.key) or
    type(candidate.key) ~= "string" or
    #candidate.key > 120 or candidate.key:find("[%c|]") or not candidate.key:find("%S") or
    type(candidate.kind) ~= "string" or not plain(candidate.title, 180) or #candidate.title > 180 or
    not finite(candidate.benefit) or candidate.benefit > 1 or
    not finite(candidate.confidence or 1) or (candidate.confidence or 1) > 1 then return nil end
  if not ns.ClassProfiles.Allows(profile.class, profile.role, candidate.roleHint) then return nil end
  local label = candidate.label or "inferred"
  if label ~= "observed" and label ~= "verified" and label ~= "community" and label ~= "inferred" then return nil end
  if not evidence then return nil end
  return { schema = O.SCHEMA, candidateId = candidate.key, kind = candidate.kind,
    title = plain(candidate.title, 180),
    why = plain(candidate.why, 300) or "Suggested from available evidence",
    where = plain(candidate.where, 120) or "Unknown",
    score = ns.WhatNow.Score(candidate, ns.WhatNow:Goal()),
    evidenceId = evidence.id, label = label, observedAt = evidence.observedAt,
    expiresAt = evidence.expiresAt, role = profile.role, source = "WhatNow",
    -- Runtime-only pointer to existing permitted user-click handling; never serialized.
    _candidate = candidate }
end
function O:Valid(card, now)
  if not card or not ns.IntelEvidence:Get(card.evidenceId, now) then return false end
  return (now or time()) <= card.expiresAt
end
function O:Top(candidates, max)
  local out, seen = {}, {}
  for _, c in ipairs(candidates or {}) do
    if self:Valid(c) and not seen[c.candidateId] then
      out[#out + 1], seen[c.candidateId] = c, true
    end
  end
  table.sort(out, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.candidateId < b.candidateId
  end)
  for i = #out, (max or 3) + 1, -1 do out[i] = nil end
  return out
end

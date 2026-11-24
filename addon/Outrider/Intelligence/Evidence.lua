-- Typed, bounded evidence lifecycle. No automatic export/network or secret computations.
local _, ns = ...
local E = { sources = {}, observations = {}, serial = 0, MAX = 500, TTL = {
  quest = 180, gear = 180, bag = 30, location = 30, talent = 180,
  auction = 120, historical = 86400, errand = 60, generic = 120,
}}
ns.IntelEvidence = E
local function finite(n)
  return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end
local function plain(v, depth)
  if ns.Compat.IsSecret(v) then return nil end
  if type(v) == "string" then return #v <= 300 and v or v:sub(1, 300) end
  if type(v) == "number" then return finite(v) and v or nil end
  if type(v) == "boolean" then return v end
  if type(v) ~= "table" or depth >= 3 then return nil end
  local out, n = {}, 0
  for k, x in pairs(v) do
    if n >= 24 then break end
    if type(k) == "string" and k:match("^[%w_]+$") and #k <= 40 then
      -- Never serialize identity, chat or raw protected state.
      if k ~= "name" and k ~= "realm" and k ~= "guild" and k ~= "chat" and k ~= "token" then
        local safe = plain(x, depth + 1)
        if safe ~= nil then out[k], n = safe, n + 1 end
      end
    end
  end
  return out
end
-- OI02-02: a source says what it is (sourceType: module, pack, player or client)
-- and whether it may mark facts "verified" (canVerify). Verified status is never
-- inferred from a source's name: a source registered without canVerify that
-- passes "verified" is rejected.
local SOURCE_TYPES = { module = true, pack = true, player = true, client = true }
function E:Register(id, capability, opts)
  if ns.Compat.IsSecret(id) or type(id) ~= "string" or not id:match("^[%w_%-]+$") or #id > 48 then return false end
  opts = type(opts) == "table" and opts or {}
  local st = opts.sourceType or "module"
  if not SOURCE_TYPES[st] then return false end
  self.sources[id] = { status = capability or "ready", updated = time(), sourceType = st, canVerify = opts.canVerify == true }
  return true
end
local function scope()
  return tostring(ns.db and ns.db.key or "?"), tostring(ns.build or "unknown")
end
-- observedAt (optional): when the underlying fact was observed; it is kept,
-- not refreshed, and the expiry counts from it (OI02-R04).
function E:Record(source, key, category, value, label, ttl, observedAt)
  if type(source) ~= "string" or not self.sources[source] then return nil end
  if ns.Compat.IsSecret(key) or type(key) ~= "string" or #key < 1 or #key > 120 or key:find("[%c|]") or not key:find("%S") then return nil end
  if not self.TTL[category] then return nil end
  if label ~= "observed" and label ~= "verified" and label ~= "community" and label ~= "inferred" then return nil end
  if label == "verified" and not self.sources[source].canVerify then return nil end
  local safe = plain(value, 0)
  if type(safe) ~= "table" then return nil end
  local seconds = ttl or self.TTL[category]
  if not finite(seconds) or seconds < 0 or seconds > 86400 then return nil end
  local now = time()
  local seen = tonumber(observedAt)
  if seen and (seen ~= seen or seen > now + 5) then return nil end
  seen = seen and math.floor(seen) or now
  if seen + seconds < now then return nil end -- already stale: not recorded as fresh
  self.serial = self.serial + 1
  local char, build = scope()
  local record = { id = source .. ":" .. key, source = source, category = category,
    observedAt = seen, expiresAt = seen + seconds, label = label,
    build = build, char = char, sourceType = self.sources[source].sourceType, privacy = "local",
    value = safe, revision = self.serial }
  -- Evict oldest by revision without unbounded retention.
  self.observations[record.id] = record
  local count, oldestId, oldestRev = 0, nil, math.huge
  for id, row in pairs(self.observations) do
    count = count + 1
    if row.revision < oldestRev then oldestId, oldestRev = id, row.revision end
  end
  if count > self.MAX then self.observations[oldestId] = nil end
  return record
end
-- A fact is usable only for the character and addon build that observed it,
-- not from the future, and not after it expires (OI02-02). The second return
-- says why, so the planner can explain an unknown.
function E:Get(id, now)
  local row = self.observations[id]
  if not row then return nil, "missing" end
  now = now or time()
  if now > row.expiresAt then self.observations[id] = nil return nil, "stale" end
  if row.observedAt > now + 5 then return nil, "future" end
  local char, build = scope()
  if row.char ~= char then return nil, "other character" end
  if row.build ~= build then return nil, "other build" end
  return row
end

-- the v4 Evidence record for a stored fact (Intelligence/Contracts.lua), or nil, why
function E:AsV4(id, now)
  local row, why = self:Get(id, now)
  if not row then return nil, why end
  local rec = { evidenceId = row.id:gsub("[^%w_:%.@%-]", "_"):sub(1, 120), kind = row.category,
    sourceId = row.source, sourceType = row.sourceType or "module", observedAt = row.observedAt,
    expiresAt = row.expiresAt, confidence = row.label, privacy = row.privacy or "local", clientBuild = row.build }
  local ok, field = ns.Nexus.Validate("Evidence", rec)
  if not ok then return nil, "invalid " .. tostring(field) end
  return rec
end
function E:Invalidate(category)
  for id, row in pairs(self.observations) do
    if row.category == category then self.observations[id] = nil end
  end
end
-- Only sanitized explicit facts may enter an exported explanation.
function E:Exportable(ids)
  local out, seen = {}, {}
  for _, id in ipairs(ids or {}) do
    if #out >= 16 then break end
    if type(id) == "string" and not seen[id] then
      seen[id] = true
      local row = self:Get(id)
      if row then
        out[#out + 1] = { evidenceId = row.id, kind = row.category,
          observedAt = row.observedAt, gameBuild = row.build,
          confidence = row.label, source = row.source }
      end
    end
  end
  return out
end
-- Clear(source): drop one source's runtime facts (Radar rebuilds its own;
-- the planner's stay). Clear() drops all. These are in-memory caches, never
-- saved data (docs/intelligence/DATA_LIFETIME.md).
function E:Clear(source)
  if source == nil then self.observations = {} return end
  for id, row in pairs(self.observations) do
    if row.source == source then self.observations[id] = nil end
  end
end

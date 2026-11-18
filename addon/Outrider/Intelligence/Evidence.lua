-- Typed, bounded evidence lifecycle. No automatic export/network or secret computations.
local _, ns = ...
local E = { sources = {}, observations = {}, serial = 0, MAX = 100, TTL = {
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
function E:Register(id, capability)
  if type(id) ~= "string" or not id:match("^[%w_%-]+$") or #id > 48 then return false end
  self.sources[id] = { status = capability or "ready", updated = time() }
  return true
end
function E:Record(source, key, category, value, label, ttl)
  if type(source) ~= "string" or not self.sources[source] then return nil end
  if type(key) ~= "string" or #key < 1 or #key > 120 or key:find("[%c|]") or not key:find("%S") then return nil end
  if not self.TTL[category] then return nil end
  if label ~= "observed" and label ~= "verified" and label ~= "community" and label ~= "inferred" then return nil end
  local safe = plain(value, 0)
  if type(safe) ~= "table" then return nil end
  local seconds = ttl or self.TTL[category]
  if not finite(seconds) or seconds < 0 or seconds > 86400 then return nil end
  self.serial = self.serial + 1
  local record = { id = source .. ":" .. key, source = source, category = category,
    observedAt = time(), expiresAt = time() + seconds, label = label,
    build = tostring(ns.build or "unknown"), value = safe, revision = self.serial }
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
function E:Get(id, now)
  local row = self.observations[id]
  if not row then return nil end
  if (now or time()) > row.expiresAt then self.observations[id] = nil return nil end
  return row
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
function E:Clear()
  self.observations = {}
end

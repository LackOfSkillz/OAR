-- Intelligence/World.lua  (OI06-01 .. OI06-05: what Outrider knows about the world)
-- OI06-01 Observation(raw): one shape for Discovery, POICapture, Trail and
--   Sightings records: { kind, subject, mapID, x, y, at, build, realm, ruleset,
--   layer, method, precision (yards), positionOf = "player", consent,
--   provenance = { source = "self" | "guild" | "pack:<name>" | "import:<id>", by } }.
--   Validated: positive whole ids, fractional 0..1 coordinates, a time not in
--   the future, a build string, a map the client knows (when it can tell). A
--   position is always the player's at the time, with how far off that can be
--   (interact 5 yd, near 10, target or mouseover 30, nameplate 40, a window 5):
--   never an NPC's exact spot.
-- OI06-02 Sources: a manifest per pack (license, revision, flavor classic or
--   forever, build, evidence observed | cited | inferred). A pack with no
--   license or no evidence class is quarantined (kept, not used); Classic data
--   is labelled "may be wrong on Forever"; a build older than a rule's
--   minimum is outdated. Built-in packs are first-party (the project's own,
--   each entry with its own source line).
-- OI06-03 Resolve(observations): nothing is overwritten. Observations are
--   grouped by layer and map, then by distance (within the larger of their
--   precisions); each group is weighed by evidence (method, source, how
--   recent, how many). A group from a source that isn't allowed (an import
--   not approved, a sender not in your group or guild) weighs 0 and is
--   flagged. A newer group with 2+ observations beats an older one ("moved?"),
--   the old one kept. Every observation has an audit line.
-- OI06-04 RareForecast(sightings, layer): respawn gaps only from a death and
--   a later sighting alive on the SAME layer and build; alive then alive is a
--   sighting, not a respawn; a death with no later sighting is censored (a
--   lower bound, counted apart). No forecast under MIN_GAPS; a chance by time
--   only from CALIBRATED gaps or more (the share of gaps that were shorter).
--   Unknown layer: no gaps. A build change starts the count again.
-- OI06-05 Unseen(mapID): pack places on a map you haven't seen yet, kept apart
--   from ones you can't use (the other faction) and ones removed on Forever;
--   a route through the verified ones nearest first (straight lines, marked).

local _, ns = ...
local C = ns.Compat
local W = { VERSION = "world-1", MIN_GAPS = 3, CALIBRATED = 8, FUTURE = 60 }
ns.World = W
W.PRECISION = { interact = 5, near = 10, window = 5, target = 30, mouseover = 30, nameplate = 40, walk = 5, unknown = 50 }
W.METHOD_WEIGHT = { interact = 1, window = 1, near = 0.9, target = 0.6, mouseover = 0.6, nameplate = 0.4, walk = 0.8, unknown = 0.2 }
W.SOURCE_WEIGHT = { self = 1, guild = 0.6, forever = 0.5, classic = 0.15, import = 0.4 }

local function int(v) return type(v) == "number" and v == math.floor(v) and v > 0 end
local function frac(v) return type(v) == "number" and v > 0 and v < 1 end

function W.Build()
  local v, b = C.Call("GetBuildInfo")
  v, b = C.Readable(v), C.Readable(b)
  return v and (tostring(v) .. (b and ("." .. tostring(b)) or "")) or nil
end

local function knownMap(mapID)
  local info = C.Call("C_Map.GetMapInfo", mapID)
  if info == nil and C.Resolve("C_Map.GetMapInfo") then return false end
  return true
end

-- OI06-01
function W.Observation(raw, now)
  now = now or time()
  if type(raw) ~= "table" then return nil, "not a table" end
  local o = { kind = raw.kind, subject = raw.subject, mapID = raw.mapID, x = raw.x, y = raw.y, at = raw.at, build = raw.build,
    realm = raw.realm, ruleset = raw.ruleset, layer = raw.layer, method = raw.method or "unknown", consent = raw.consent,
    positionOf = "player", provenance = raw.provenance or { source = "self" } }
  if type(o.kind) ~= "string" or o.kind == "" then return nil, "kind missing" end
  if not (int(o.subject) or (type(o.subject) == "string" and #o.subject > 0 and #o.subject <= 64)) then return nil, "subject must be an id" end
  if not int(o.mapID) then return nil, "map must be a whole id" end
  if not (frac(o.x) and frac(o.y)) then return nil, "x and y must be map fractions between 0 and 1" end
  if not (type(o.at) == "number" and o.at > 0 and o.at <= now + W.FUTURE) then return nil, "time missing or in the future" end
  if type(o.build) ~= "string" or o.build == "" then return nil, "build missing" end
  if not W.PRECISION[o.method] then return nil, "unknown method " .. tostring(o.method) end
  if not knownMap(o.mapID) then return nil, "the client doesn't know map " .. tostring(o.mapID) end
  if o.layer ~= nil and not int(o.layer) then o.layer = nil end
  o.precision = W.PRECISION[o.method]
  return o
end

-- adapters from what's already saved
function W.FromDiscovery(npcID, rec, build, now)
  local p = type(rec) == "table" and rec or {}
  local how = p.quality or p.how
  local method = (how == "interact" and "interact") or (how == "near" and "near") or (how == "nameplate" and "nameplate")
    or ((how == "target" or how == "mouseover") and how) or "unknown"
  return W.Observation({ kind = "npc", subject = tonumber(npcID), mapID = tonumber(p.mapID), x = p.x, y = p.y,
    at = tonumber(p.lastSeen or p.t), build = p.build or build, layer = p.layer, method = method,
    provenance = { source = "self" } }, now)
end
function W.FromSighting(npcID, s, build, now)
  return W.Observation({ kind = "rare", subject = tonumber(npcID), mapID = s.mapID, x = s.x, y = s.y, at = s.t, build = s.build or build,
    layer = s.layer, method = (s.how == "target" or s.how == "mouseover" or s.how == "nameplate") and s.how or "unknown",
    provenance = { source = s.by and s.by ~= ns.db.key and "guild" or "self", by = s.by } }, now)
end

-- OI06-02 source registry
W.manifests = {}
function W.Manifest(name, m)
  if type(m) ~= "table" then return nil, "manifest must be a table" end
  local why
  if type(m.license) ~= "string" or m.license == "" then why = "no license" end
  if not why and not ({ observed = true, cited = true, inferred = true })[m.evidence] then why = "no evidence class" end
  local rec = { name = name, license = m.license, revision = m.revision, flavor = m.flavor or "forever", build = m.build,
    evidence = m.evidence, quarantined = why }
  if rec.flavor == "classic" then rec.label = "Classic data: may be wrong on Forever" end
  W.manifests[name] = rec
  return rec
end
-- a rule: { minBuild = "1.60.0" } makes older packs outdated
local function older(a, b)
  local pa, pb = {}, {}
  for n in tostring(a):gmatch("%d+") do pa[#pa + 1] = tonumber(n) end
  for n in tostring(b):gmatch("%d+") do pb[#pb + 1] = tonumber(n) end
  for i = 1, math.max(#pa, #pb) do
    if (pa[i] or 0) ~= (pb[i] or 0) then return (pa[i] or 0) < (pb[i] or 0) end
  end
  return false
end
W.older = older
function W.Classify(name, rules)
  local m = W.manifests[name]
  if not m then return { name = name, firstParty = true, label = "Outrider's own pack: each entry names its source" } end
  local out = { name = name, flavor = m.flavor, evidence = m.evidence, license = m.license, label = m.label }
  if m.quarantined then out.quarantined, out.label = m.quarantined, "quarantined: " .. m.quarantined end
  if rules and rules.minBuild and m.build and older(m.build, rules.minBuild) then out.outdated = true out.label = "outdated: built for " .. m.build end
  out.usable = not out.quarantined and not out.outdated
  return out
end

-- register an outside pack: quarantined or outdated packs are kept apart
-- (W.quarantine[name], entries untouched), never indexed for use
W.quarantine = {}
-- the packs set aside, for other parts of Outrider: { name = why }
function W.Quarantined()
  local out = {}
  for name, q in pairs(W.quarantine) do out[name] = q.why end
  return out
end
function W.RegisterPack(kind, name, manifest, entries, rules)
  W.Manifest(name, manifest)
  local cls = W.Classify(name, rules)
  if not cls.usable then
    W.quarantine[name] = { kind = kind, why = cls.quarantined or cls.label, entries = entries }
    return 0, cls
  end
  for _, e in ipairs(entries or {}) do
    e.flavor = e.flavor or cls.flavor
    if cls.flavor == "classic" then e.verified = false e.confidence = e.confidence == "verified" and "community" or e.confidence end
  end
  return ns.Data:Register(kind, name, entries), cls
end

-- OI06-03 conflict resolution
local function dist(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end
local YARDS_PER_UNIT = 1000 -- an estimate for a zone map; only used to compare precisions
function W.Resolve(obs, opts)
  opts = opts or {}
  local now = opts.now or time()
  -- allowed: your own, your guild's (the sender checked on receipt), a pack,
  -- or an import you approved; any other claimed source is treated as spoofed
  local allowed = opts.allowed or function(o)
    local p = o.provenance or {}
    local s = type(p.source) == "string" and p.source or ""
    if s == "self" or s == "guild" or s:find("^pack:") then return true end
    return s:find("^import:") ~= nil and p.approved == true
  end
  local groups, audit = {}, {}
  for i, o in ipairs(obs or {}) do
    local key = tostring(o.layer or "?") .. "|" .. tostring(o.mapID)
    local placed
    for _, g in ipairs(groups) do
      if g.key == key and dist(g.center, o) * YARDS_PER_UNIT <= math.max(g.precision, o.precision or 50) then placed = g break end
    end
    if not placed then
      placed = { key = key, layer = o.layer, mapID = o.mapID, center = { x = o.x, y = o.y }, members = {}, precision = o.precision or 50, weight = 0, newest = 0 }
      groups[#groups + 1] = placed
    end
    local ok = allowed(o)
    local src = o.provenance and o.provenance.source or "self"
    local sw = W.SOURCE_WEIGHT[src:match("^(%a+)")] or (src:find("^pack") and W.SOURCE_WEIGHT.forever) or 0.3
    if o.flavor == "classic" then sw = W.SOURCE_WEIGHT.classic end
    local age = math.max(0, now - (o.at or now)) / 86400
    local w = ok and (W.METHOD_WEIGHT[o.method] or 0.2) * sw / (1 + age / 30) or 0
    placed.members[#placed.members + 1] = o
    placed.weight = placed.weight + w
    if ok then placed.newest = math.max(placed.newest, o.at or 0) end
    if not ok then placed.flagged = true end
    audit[#audit + 1] = { index = i, group = #groups, weight = w, why = not ok and "source not allowed" or nil }
  end
  table.sort(groups, function(a, b) return a.weight > b.weight end)
  local best = groups[1]
  -- relocation: within one layer and map, a group with 2+ allowed observations
  -- all newer than anything another group there has seen: it moved (the old
  -- spot is kept)
  if best then
    local newest
    for _, g in ipairs(groups) do
      if g.key == best.key and g.weight > 0 then
        local others = 0
        for _, h in ipairs(groups) do if h ~= g and h.key == g.key and h.weight > 0 and h.newest > others then others = h.newest end end
        local n = 0
        for _, o in ipairs(g.members) do if allowed(o) and (o.at or 0) > others then n = n + 1 end end
        if n >= 2 and others > 0 and (not newest or g.newest > newest.newest) then newest = g end
      end
    end
    if newest then newest.moved = true best = newest end
  end
  return { best = best, groups = groups, audit = audit, kept = #(obs or {}) }
end

-- OI06-04 rare forecasting
function W.RareForecast(sightings, layer, now)
  now = now or time()
  if layer == nil then return { unknown = "layer unknown: no respawn gaps without it" } end
  local gaps, censored, sightingsN = {}, 0, 0
  local lastDead, build, started
  for _, s in ipairs(sightings or {}) do
    if s.layer == layer then
      -- a record from another build (an older record has none) starts again
      if started and s.build ~= build then gaps, censored, lastDead, sightingsN = {}, 0, nil, 0 end
      started, build = true, s.build
      if s.state == "dead" or s.state == "tamed" then
        if lastDead then censored = censored + 1 end
        lastDead = s
      elseif lastDead then
        gaps[#gaps + 1] = s.t - lastDead.t
        lastDead = nil
      else
        sightingsN = sightingsN + 1
      end
    end
  end
  if lastDead then censored = censored + 1 end
  table.sort(gaps)
  local out = { layer = layer, gaps = #gaps, censored = censored, sightingsOnly = sightingsN, build = build }
  if #gaps < W.MIN_GAPS then out.why = string.format("%d respawn gap%s on this layer: not enough to forecast", #gaps, #gaps == 1 and "" or "s") return out end
  out.min, out.max, out.median = gaps[1], gaps[#gaps], gaps[math.floor((#gaps + 1) / 2)]
  if lastDead and #gaps >= W.CALIBRATED then
    local since = now - lastDead.t
    local shorter = 0
    for _, g in ipairs(gaps) do if g <= since then shorter = shorter + 1 end end
    out.chanceUp = shorter / #gaps
    out.chanceNote = string.format("%d of %d past gaps were shorter than the time since it died", shorter, #gaps)
  elseif lastDead then
    out.since = now - lastDead.t
    out.chanceNote = "no chance figure under " .. W.CALIBRATED .. " gaps"
  end
  return out
end

-- OI06-05 explorer
function W.Unseen(mapID, opts)
  opts = opts or {}
  local seen = opts.seen or {}
  local faction = opts.faction or C.Readable(C.Call("UnitFactionGroup", "player"))
  local out = { unseen = {}, unavailable = {}, removed = {}, seen = 0 }
  for _, p in ipairs(ns.Data:All("poi")) do
    if p.mapID == mapID then
      if p.removed then out.removed[#out.removed + 1] = p
      elseif p.faction and faction and p.faction ~= faction and p.faction ~= "both" then out.unavailable[#out.unavailable + 1] = p
      elseif seen[p.id] then out.seen = out.seen + 1
      else out.unseen[#out.unseen + 1] = p end
    end
  end
  table.sort(out.unseen, function(a, b) return a.id < b.id end)
  return out
end

-- nearest first through verified unseen places, straight lines
function W.Route(places, from)
  local left, route = {}, {}
  for _, p in ipairs(places or {}) do if p.verified then left[#left + 1] = p end end
  local at = from
  while #left > 0 and at do
    local bi, bd
    for i, p in ipairs(left) do
      local d = dist(at, p)
      if not bd or d < bd then bi, bd = i, d end
    end
    local p = table.remove(left, bi)
    route[#route + 1] = { id = p.id, name = p.name, x = p.x, y = p.y, straight = true }
    at = p
  end
  return route, "straight lines between places, not a walking path"
end

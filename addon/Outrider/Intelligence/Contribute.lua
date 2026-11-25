-- Intelligence/Contribute.lua  (OI06-06 contribution export, OI06-07 import and pack build)
-- OI06-06: a manual, reviewed export of world observations only. Off by
--   default (global.contribute.on); it needs the player's consent each time
--   (Preview, then Export with the preview's token). What goes out: kind,
--   subject id, map, coordinates rounded to 0.001, layer, build, method,
--   precision. What never goes out: character names, account, realm (unless
--   the player ticks it), chat, gold, bags, or the walking trail. Size and
--   schema are checked before the text is made.
-- OI06-07: offline import into a moderation queue, never straight into use:
--   the text is decoded by Serialize (which never runs code), checked for size,
--   shape and each observation's schema; duplicates are dropped by key;
--   each record waits as "pending" until the player approves or rejects it.
--   Build(queue, rev) makes a pack deterministically (sorted, the same input
--   gives the same manifest hash); a build isn't publishable until rights are
--   reviewed. Earlier builds are kept, so a rollback is picking one.

local _, ns = ...
local K = { VERSION = 1, TAG = "OTRW1", MAX_ROWS = 2000, MAX_TEXT = 200000, ROUND = 1000 }
ns.Contribute = K
K.FIELDS = { "kind", "subject", "mapID", "x", "y", "layer", "build", "method", "precision" }

function K.Store()
  local g = ns.db.global
  g.contribute = ns.KeepTable(g.contribute, "Contribute:global.contribute") or {}
  local s = g.contribute
  s.queue = ns.KeepTable(s.queue, "Contribute:queue") or {}
  s.builds = ns.KeepTable(s.builds, "Contribute:builds") or {}
  s.seen = ns.KeepTable(s.seen, "Contribute:seen") or {}
  return s
end

local function round(v) return math.floor(v * K.ROUND + 0.5) / K.ROUND end

-- one observation reduced to what may leave the PC
function K.Strip(o, withRealm)
  local r = {}
  for _, f in ipairs(K.FIELDS) do r[f] = o[f] end
  r.x, r.y = round(o.x), round(o.y)
  if withRealm then r.realm = o.realm end
  return r
end

-- what this account has observed, as World observations
function K.Collect()
  local W, out = ns.World, {}
  local build = W.Build()
  for npcID, rec in pairs(ns.db.global.discovered and ns.db.global.discovered.npcs or {}) do
    local o = W.FromDiscovery(npcID, rec, build)
    if o then out[#out + 1] = o end
  end
  for npcID, list in pairs(ns.db.global.sightings or {}) do
    for _, s in ipairs(type(list) == "table" and list or {}) do
      local o = W.FromSighting(npcID, s, build)
      if o then out[#out + 1] = o end
    end
  end
  return out
end

function K.Preview(obs, opts)
  opts = opts or {}
  local st = K.Store()
  if not st.on then return nil, "sharing world observations is off (it's off by default)" end
  local rows = {}
  for _, o in ipairs(obs or K.Collect()) do rows[#rows + 1] = K.Strip(o, opts.realm) end
  table.sort(rows, function(a, b)
    if a.kind ~= b.kind then return a.kind < b.kind end
    if tostring(a.subject) ~= tostring(b.subject) then return tostring(a.subject) < tostring(b.subject) end
    return (a.x + a.y) < (b.x + b.y)
  end)
  if #rows > K.MAX_ROWS then return nil, "more than " .. K.MAX_ROWS .. " observations: export fewer" end
  local text = ns.Serialize.Export({ tag = K.TAG, v = K.VERSION, rows = rows })
  if #text > K.MAX_TEXT then return nil, "the export is too big" end
  return { rows = rows, count = #rows, text = text, token = ns.Serialize.Adler32(text),
    excluded = "no names, account, chat, gold, bags or walking trail" .. (opts.realm and "" or "; realm left out") }
end

function K.Export(obs, token, opts)
  local pv, why = K.Preview(obs, opts)
  if not pv then return nil, why end
  if token ~= pv.token then return nil, "consent needed: preview, then export that preview" end
  return pv.text
end

-- OI06-07 import into the moderation queue
local function key(r) return table.concat({ tostring(r.kind), tostring(r.subject), tostring(r.mapID), tostring(r.x), tostring(r.y), tostring(r.layer), tostring(r.build) }, "|") end

function K.Import(text, label, now)
  now = now or time()
  if type(text) ~= "string" or #text > K.MAX_TEXT then return nil, "missing or too big" end
  local data, err = ns.Serialize.Import(text)
  if type(data) ~= "table" then return nil, err or "not readable" end
  if data.tag ~= K.TAG or data.v ~= K.VERSION or type(data.rows) ~= "table" then return nil, "not a world observation export" end
  if #data.rows > K.MAX_ROWS then return nil, "too many rows" end
  local st = K.Store()
  st.next = (st.next or 0) + 1
  local src = "import:" .. st.next
  local added, rejected, dupes = 0, {}, 0
  for i, r in ipairs(data.rows) do
    if type(r) ~= "table" then rejected[#rejected + 1] = i .. ": not a record"
    else
      local o, why = ns.World.Observation({ kind = r.kind, subject = r.subject, mapID = r.mapID, x = r.x, y = r.y, at = now,
        build = r.build, layer = r.layer, method = r.method, provenance = { source = src } }, now)
      if not o then rejected[#rejected + 1] = i .. ": " .. why
      elseif st.seen[key(r)] then dupes = dupes + 1
      else
        st.seen[key(r)] = now
        st.queue[#st.queue + 1] = { status = "pending", from = tostring(label or src):sub(1, 40), source = src, at = now, row = K.Strip(o) }
        added = added + 1
      end
    end
  end
  return { added = added, rejected = rejected, duplicates = dupes, source = src }
end

function K.Decide(index, approve)
  local q = K.Store().queue[index]
  if not q or q.status ~= "pending" then return false end
  q.status, q.decided = approve and "approved" or "rejected", time()
  return true
end

-- a deterministic pack from the approved rows; rights reviewed separately
function K.Build(rev, rightsReviewed)
  local rows = {}
  for _, q in ipairs(K.Store().queue) do if q.status == "approved" then rows[#rows + 1] = q.row end end
  table.sort(rows, function(a, b) return key(a) < key(b) end)
  local enc = ns.Serialize.Encode(rows)
  local manifest = { revision = tostring(rev or "0"), rows = #rows, hash = ns.Serialize.Adler32(enc), evidence = "observed",
    license = rightsReviewed and "reviewed" or nil, publishable = rightsReviewed == true, built = time() }
  local st = K.Store()
  st.builds[#st.builds + 1] = { manifest = manifest, rows = rows }
  return manifest, rows
end

-- rollback: an earlier build, kept
function K.BuildAt(i) local b = K.Store().builds[i] return b and b.manifest, b and b.rows end

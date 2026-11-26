-- Vanguard/Share.lua
-- VG04-05/06/07: optional prep sharing between Outrider users in your group,
-- and putting what you know about a member together without hiding conflicts.
--
-- Protocol "VPREP", version 1 (addon message over PARTY or RAID only, through
-- Comm's size and rate limits). Off by default; you see the exact fields
-- before anything is sent (Share.Preview). Fields, all optional:
--   v, seq (counts up per sender), exp (seconds it stays valid, at most 900),
--   role (what you say you'll play), level, ready (your own press),
--   prep = { ok, todo, unknown } counts from your Prep checklist
-- No names of others, no gear links, no bag contents.
-- Receiving: group channel only, sender must be in your group, version must
-- match (a newer one is ignored and noted once), sizes and types checked,
-- seq must go up (a replayed or late packet is dropped), at most one update
-- per RATE seconds per sender. A revoke {v, seq, revoke = true} from a member
-- is honoured at once, even right after an update, and remembers its seq so a
-- late update can't bring the data back. Leaving the group forgets them.
-- Members who don't share (or don't run Outrider) keep the native-only view.
-- Memory only.

local _, ns = ...
local C = ns.Compat
ns.Vanguard = ns.Vanguard or {}
local V = ns.Vanguard
local S = { VERSION = 1, TYPE = "VPREP", RATE = 10, MAX_EXP = 900, MAX_COUNT = 99 }
V.Share = S
S.peers, S.revoked, S.lastIn, S.seen, S.notes = {}, {}, {}, {}, {}

local function int(v, lo, hi)
  if type(v) ~= "number" or v ~= v or v ~= math.floor(v) or v < lo or v > hi then return nil end
  return v
end

-- a received payload -> clean table, or nil and why
function S.Check(d)
  if type(d) ~= "table" then return nil, "not a table" end
  if d.v ~= S.VERSION then return nil, (type(d.v) == "number" and d.v > S.VERSION) and "newer version" or "bad version" end
  local seq = int(d.seq, 1, 2 ^ 31)
  if not seq then return nil, "bad seq" end
  if d.revoke == true then return { revoke = true, seq = seq } end
  local out = { seq = seq }
  local exp = int(d.exp, 1, S.MAX_EXP)
  if not exp then return nil, "bad expiry" end
  out.exp = exp
  if d.role ~= nil then
    if not V.Roster.ROLES[d.role] then return nil, "bad role" end
    out.role = d.role
  end
  if d.level ~= nil then
    out.level = int(d.level, 1, 60)
    if not out.level then return nil, "bad level" end
  end
  if d.ready ~= nil and type(d.ready) ~= "boolean" then return nil, "bad ready" end
  out.ready = d.ready
  if d.prep ~= nil then
    if type(d.prep) ~= "table" then return nil, "bad prep" end
    local p = {}
    for _, k in ipairs({ "ok", "todo", "unknown" }) do
      p[k] = int(d.prep[k], 0, S.MAX_COUNT)
      if not p[k] then return nil, "bad prep " .. k end
    end
    out.prep = p
  end
  for k in pairs(d) do
    if not ({ v = true, seq = true, exp = true, role = true, level = true, ready = true, prep = true, revoke = true })[k] then
      return nil, "unknown field"
    end
  end
  return out
end

local function canon(sender) return ns.Fellowship and ns.Fellowship.Canon(sender) or sender end
local function inGroup(sender) return ns.Fellowship and ns.Fellowship.InGroup(sender) end

function S.Receive(data, sender, channel, now)
  now = now or time()
  if not (channel == "PARTY" or channel == "RAID") then return false, "group channels only" end
  if not inGroup(sender) then return false, "not in your group" end
  local key = canon(sender)
  local d, why = S.Check(data)
  if not d then
    if why == "newer version" and not S.notes[key] then S.notes[key] = "uses a newer Outrider: ignored" end
    return false, why
  end
  local last = S.seen[key] or 0
  if d.seq <= last then return false, "old or replayed" end
  if d.revoke then
    -- honoured at once, before any rate limit
    S.seen[key] = d.seq
    S.revoked[key] = d.seq
    S.peers[key] = nil
    return true, "revoked"
  end
  if S.lastIn[key] and now - S.lastIn[key] < S.RATE then return false, "too often" end
  S.lastIn[key] = now
  S.seen[key] = d.seq
  S.revoked[key] = nil
  d.at, d.expiresAt = now, now + d.exp
  S.peers[key] = d
  return true
end

-- forget members who left, and expired data
function S.Sweep(now)
  now = now or time()
  for key, d in pairs(S.peers) do
    if now >= d.expiresAt or not inGroup(key) then S.peers[key] = nil end
  end
end

function S.Clear() S.peers, S.revoked, S.lastIn, S.seen, S.notes = {}, {}, {}, {}, {} end

-- what you'd send: exactly these fields (shown before sending)
function S.Payload(st, prepCounts, role, level, seq)
  return { v = S.VERSION, seq = seq, exp = S.MAX_EXP, role = role, level = level, ready = st.ready == true,
    prep = prepCounts and { ok = math.min(S.MAX_COUNT, prepCounts.ok or 0), todo = math.min(S.MAX_COUNT, prepCounts.missing or 0),
      unknown = math.min(S.MAX_COUNT, prepCounts.unknown or 0) } or nil }
end

function S.Preview(p)
  if not p then return "Nothing is shared." end
  local parts = { "Sent to your party or raid only, for 15 minutes:" }
  parts[#parts + 1] = "role " .. (p.role and p.role:lower() or "not set")
  parts[#parts + 1] = "level " .. tostring(p.level or "not set")
  parts[#parts + 1] = "ready " .. (p.ready and "yes" or "no")
  if p.prep then parts[#parts + 1] = string.format("prep checklist %d OK, %d to do, %d can't tell", p.prep.ok, p.prep.todo, p.prep.unknown) end
  return table.concat(parts, "; ") .. ". Nothing else: no names, gear or bags."
end

-- VG04-07: one fact from several sources, without hiding a conflict.
-- sources: { {value, source = native|peer|manual, at} }; precedence manual >
-- native > peer. Returns { value, source, conflicts = { ... } }.
local RANK = { manual = 3, native = 2, peer = 1 }
function S.Reconcile(kind, sources)
  local best, conflicts = nil, {}
  for _, s in ipairs(sources or {}) do
    if s.value ~= nil and RANK[s.source] then
      if not best or RANK[s.source] > RANK[best.source] then best = s end
    end
  end
  if not best then return { kind = kind, value = nil, source = "unknown", conflicts = {} } end
  for _, s in ipairs(sources) do
    if s.value ~= nil and RANK[s.source] and s.value ~= best.value then
      conflicts[#conflicts + 1] = { value = s.value, source = s.source, at = s.at }
    end
  end
  return { kind = kind, value = best.value, source = best.source, at = best.at, conflicts = conflicts }
end

-- Intelligence/Passport.lua  (OI08-02: task-specific snapshot for the companion)
-- A small, chosen part of what Outrider knows, for one question, that the
-- player previews and copies. Opaque ids instead of names: the character is
-- an id made from the account's own random salt (account-wide, kept on this
-- PC), so the companion can tell "same character" without learning who.
--   FIELDS: each field has a default (on or off) and whether it is sensitive.
--   Sensitive fields (exact gold, guild, realm, friends, the walking trail,
--   chat) are off by default and stay off unless the player ticks them.
--   Preview(task, pick) -> { text, size, fields, token, takenAt, build, id }
--   Export(preview, token) -> the text, only with the preview's token
-- The text is "OTRP1:<sum>:<base64>" (Serialize.Export with its own tag),
-- at most MAX_BYTES. Read(text, expect) checks version, size, age (MAX_AGE),
-- build and the character id: stale or another character's passport is
-- refused as current.
-- Review OI-FR12: Read and the companion's passport.read follow one contract
-- (companion/tests/fixtures/passport_contract.json, run by both test suites):
-- the task, a well-formed id ("c" + 8 hex) and build, no time in the future
-- beyond FUTURE_SKEW, and fields kept only when allowed and of the right type
-- and size (FIELD_CHECKS); the rest are listed in data.dropped.

local _, ns = ...
local C = ns.Compat
local P = { VERSION = 1, TAG = "OTRP1", MAX_BYTES = 16 * 1024, MAX_AGE = 6 * 3600, FUTURE_SKEW = 300 }
ns.Passport = P

P.FIELDS = {
  { key = "level", default = true },
  { key = "class", default = true },
  { key = "role", default = true },
  { key = "zone", default = true },
  { key = "goals", default = true },
  { key = "plan", default = true },
  { key = "gearSlots", default = true },
  { key = "professions", default = true },
  { key = "goldBand", default = true },     -- a rough band, not the amount
  { key = "gold", default = false, sensitive = true },
  { key = "realm", default = false, sensitive = true },
  { key = "guild", default = false, sensitive = true },
  { key = "trail", default = false, sensitive = true },
}
P.TASKS = { plan = true, gear = true, gold = true, explain = true, lesson = true }

function P.Salt()
  local g = ns.db.global
  g.passport = ns.KeepTable(g.passport, "Passport:global.passport") or {}
  if type(g.passport.salt) ~= "string" then
    local parts = {}
    for i = 1, 4 do parts[i] = string.format("%08x", math.random(0, 0x7fffffff)) end
    g.passport.salt = table.concat(parts)
  end
  return g.passport.salt
end

function P.Id(key) return "c" .. ns.Serialize.Adler32(P.Salt() .. "|" .. tostring(key or ns.db.key)) end

local function band(copper)
  if not copper then return nil end
  local g = copper / 10000
  if g < 1 then return "under 1g" elseif g < 10 then return "1-10g" elseif g < 100 then return "10-100g" elseif g < 1000 then return "100-1000g" end
  return "1000g+"
end

local function value(key)
  if key == "level" then return tonumber(C.Readable(C.Call("UnitLevel", "player"))) end
  if key == "class" then return ns.PlayerClass() end
  if key == "role" then local cp = ns.ClassProfiles and ns.ClassProfiles.Current and ns.ClassProfiles.Current() or {} return cp.role end
  if key == "zone" then return tonumber(C.Readable(C.PlayerPosition("player"))) end
  if key == "goals" then
    local out = {}
    for _, g in ipairs(ns.NexusGoals and ns.NexusGoals:Active() or {}) do out[#out + 1] = tostring(g.objective) end
    return out
  end
  if key == "plan" then return ns.NexusCore and ns.NexusCore.StepIds and ns.NexusCore:StepIds(5) or {} end
  if key == "gearSlots" then
    local out = {}
    for slot = 1, 19 do local id = tonumber(C.Readable(C.Call("GetInventoryItemID", "player", slot))) if id then out[slot] = id end end
    return out
  end
  if key == "professions" then return ns.Outcomes and ns.Outcomes.Professions and ns.Outcomes:Professions() or {} end
  if key == "goldBand" then return band(tonumber(C.Readable(C.Call("GetMoney")))) end
  if key == "gold" then return tonumber(C.Readable(C.Call("GetMoney"))) end
  if key == "realm" then return ns.db.key:match("%-(.+)$") end
  if key == "guild" then return C.Readable(C.Call("GetGuildInfo", "player")) end
  if key == "trail" then return nil end -- never collected for a passport here; listed so it can't be ticked by accident
end

function P.Preview(task, pick)
  if not P.TASKS[task] then return nil, "unknown task" end
  if C.InCombat() then return nil, "not in combat" end
  pick = pick or {}
  local body = { v = P.VERSION, task = task, id = P.Id(), takenAt = time(), build = ns.World and ns.World.Build(), fields = {} }
  local used = {}
  for _, f in ipairs(P.FIELDS) do
    local on = pick[f.key]
    if on == nil then on = f.default end
    if on then
      local v = value(f.key)
      if v ~= nil then body.fields[f.key] = v used[#used + 1] = f.key end
    end
  end
  local text = ns.Serialize.Export(body):gsub("^" .. ns.Serialize.EXPORT_TAG, P.TAG)
  if #text > P.MAX_BYTES then return nil, "too big: untick some fields" end
  return { text = text, size = #text, fields = used, token = ns.Serialize.Adler32(text), takenAt = body.takenAt, build = body.build, id = body.id }
end

function P.Export(pv, token)
  if type(pv) ~= "table" or token ~= pv.token then return nil, "preview it, then copy that preview" end
  return pv.text
end

-- field checks (the same as CHECKS in the companion's passport.py)
local function isInt(v, lo, hi) return type(v) == "number" and v == math.floor(v) and v >= lo and v <= hi end
local function isText(n) return function(v) return type(v) == "string" and #v > 0 and #v <= n end end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
local function isList(t) return type(t) == "table" and count(t) == #t end
local function ids(n)
  return function(v)
    if not isList(v) or #v > n then return false end
    for _, x in ipairs(v) do if type(x) ~= "string" or #x == 0 or #x > 40 then return false end end
    return true
  end
end
P.FIELD_CHECKS = {
  level = function(v) return isInt(v, 1, 60) end,
  class = isText(16),
  role = isText(16),
  zone = function(v) return isInt(v, 1, 100000) end,
  goals = ids(5),
  plan = ids(10),
  gearSlots = function(v)
    if type(v) ~= "table" or count(v) > 19 then return false end
    for k, x in pairs(v) do if not isInt(k, 1, 19) or not isInt(x, 1, math.huge) then return false end end
    return true
  end,
  professions = function(v) return type(v) == "table" and count(v) <= 20 end,
  goldBand = isText(16),
  gold = function(v) return type(v) == "number" and v >= 0 end,
  realm = isText(64),
  guild = isText(64),
}

-- read a passport back (the companion does the same in Python): nil, why when it can't be used as current
function P.Read(text, expect, now)
  now = now or time()
  if type(text) ~= "string" then return nil, "missing or too big" end
  text = text:match("^%s*(.-)%s*$")
  if #text > P.MAX_BYTES then return nil, "missing or too big" end
  if text:sub(1, #P.TAG + 1) ~= P.TAG .. ":" then return nil, "not a passport" end
  local data, err = ns.Serialize.Import(ns.Serialize.EXPORT_TAG .. text:sub(#P.TAG + 1))
  if type(data) ~= "table" then return nil, err or "not readable" end
  if data.v ~= P.VERSION then return nil, "another passport version" end
  if not P.TASKS[data.task] then return nil, "unknown task" end
  if type(data.id) ~= "string" or not data.id:find("^c[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$") then
    return nil, "bad character id"
  end
  expect = expect or {}
  if expect.id and data.id ~= expect.id then return nil, "another character's passport" end
  if type(data.takenAt) ~= "number" then return nil, "stale: take a new one" end
  if data.takenAt > now + P.FUTURE_SKEW then return nil, "taken in the future" end
  if now - data.takenAt > (expect.maxAge or P.MAX_AGE) then return nil, "stale: take a new one" end
  if data.build ~= nil and not (type(data.build) == "string" and #data.build > 0 and #data.build <= 32) then return nil, "bad build" end
  if expect.build and data.build ~= expect.build then return nil, "made on another game build" end
  local kept, dropped = {}, {}
  for k, v in pairs(type(data.fields) == "table" and data.fields or {}) do
    local check = P.FIELD_CHECKS[k]
    if check and check(v) then kept[k] = v else dropped[#dropped + 1] = tostring(k) end
  end
  table.sort(dropped)
  data.fields, data.dropped = kept, dropped
  return data
end

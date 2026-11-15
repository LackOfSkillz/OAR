-- Advisor/AdviceLoader.lua
-- Phase 9 groundwork. Reads Outrider_Advice (written by the companion app into
-- Advisor/Advice.lua) and keeps only well-formed items whose action is on the
-- whitelist. Advice never acts by itself: each item becomes a row the player
-- may click, and clicks only do the whitelisted, non-protected things below.
--
-- Every item carries a confidence ("verified" in game, "community" reported,
-- "inferred", or "unknown"); the panel shows it next to the advice.
-- Expected shape:
-- Outrider_Advice = {
--   schema = 1,
--   forCharacter = "Torrant-Realm",
--   answersSnapshot = 1731300000,      -- must equal Outrider_Snapshots[char].askedAt (or takenAt)
--   items = {
--     { title = "Tame The Rake", why = "...", action = "waypoint", confidence = "verified",
--       args = { mapID = 1412, x = 0.46, y = 0.37 } },
--   },
-- }

local _, ns = ...
local Advice = { name = "advice", SCHEMA = 1, MAX_ITEMS = 12 }
-- Schema 2 (Outrider Intelligence, AI02-05): adds answer = { headline,
-- summary, limits = {..}, sources = {..} } and items may name the WhatNow
-- candidate they act on (candidateId). Everything in schema 1 still works.
Advice.SCHEMAS = { [1] = true, [2] = true }
ns.Advice = Advice

-- Arg kinds: "id" = positive integer below 2^31, "frac" = finite 0..1,
-- "panel" = one of PANELS. Anything else in args is dropped.
Advice.ALLOWED = {
  waypoint    = { mapID = "id", x = "frac", y = "frac" },
  track_quest = { questID = "id" },
  open_panel  = { panel = "panel" },
  show_item   = { itemID = "id" },
}
Advice.PANELS = { hub = true, rares = true, pet = true, macros = true, gear = true, professions = true, map = true }
Advice.CONFIDENCE = { verified = true, community = true, inferred = true, unknown = true, observed = true }

local function isId(v) return type(v) == "number" and v == v and v >= 1 and v < 2147483648 and v == math.floor(v) end
local function isFrac(v) return type(v) == "number" and v == v and v >= 0 and v <= 1 end

-- Strip WoW UI escape sequences (|c colors, |H links, |T textures, |r ...) and
-- control characters, so advice text is shown as plain text only.
local function plain(s, max)
  if type(s) ~= "string" then return nil end
  s = s:gsub("|", ""):gsub("[%z\1-\31]", " ")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  if #s == 0 then return nil end
  return s:sub(1, max)
end

local CHECK = {
  id = isId,
  frac = isFrac,
  panel = function(v) return type(v) == "string" and Advice.PANELS[v] == true end,
}

local function clean(item)
  if type(item) ~= "table" then return nil end
  local spec = Advice.ALLOWED[item.action]
  if not spec then return nil end
  local title = plain(item.title, 120)
  if not title then return nil end
  local args = {}
  local src = type(item.args) == "table" and item.args or {}
  for k, kind in pairs(spec) do
    if not CHECK[kind](src[k]) then return nil end
    args[k] = src[k]
  end
  -- A waypoint must name a map this client knows (skipped if the API is missing).
  if item.action == "waypoint" and ns.Compat.Has("C_Map.GetMapInfo") and not ns.Compat.Call("C_Map.GetMapInfo", args.mapID) then
    return nil
  end
  local confidence = Advice.CONFIDENCE[item.confidence] and item.confidence or "unknown"
  return { title = title, why = plain(item.why, 400) or "", action = item.action, args = args, confidence = confidence }
end

-- Clean items and "ok", or {} and the reason, for one advice table.
function Advice:Check(a)
  if type(a) ~= "table" then return {}, "no advice file" end
  if not self.SCHEMAS[a.schema] then return {}, "wrong schema" end
  if a.forCharacter ~= ns.db.key then return {}, "advice is for another character" end
  local snaps = rawget(_G, "Outrider_Snapshots")
  local snap = type(snaps) == "table" and snaps[ns.db.key]
  if not snap then return {}, "advice is stale" end
  if snap.askedAt then
    if a.answersSnapshot ~= snap.askedAt then return {}, "advice is stale" end
  else
    -- snapshots from before askedAt existed: accept advice for this one or a
    -- logout refresh of it from the last 6 hours
    local age = (snap.takenAt or 0) - (tonumber(a.answersSnapshot) or 0)
    if age < 0 or age > 6 * 3600 then return {}, "advice is stale" end
  end
  -- schema 2 answers name the snapshot they answer; a mismatch is stale
  if a.schema == 2 and a.answersSnapshotId and snap.snapshotId and a.answersSnapshotId ~= snap.snapshotId then
    return {}, "advice is stale"
  end
  local cands = Advice.Candidates(snap)
  local out = {}
  if type(a.items) == "table" then
    for _, item in ipairs(a.items) do
      local c = clean(item)
      if c and a.schema == 2 and not Advice.Grounded(item, c, cands) then c = nil end
      if c then out[#out + 1] = c end
      if #out >= self.MAX_ITEMS then break end
    end
  end
  return out, "ok", a.schema == 2 and Advice.CleanAnswer(a.answer) or nil
end

-- The WhatNow candidates the snapshot carried, by id (or nil if it had none).
function Advice.Candidates(snap)
  local w = type(snap.modules) == "table" and snap.modules.WhatNow
  if type(w) ~= "table" or type(w.candidates) ~= "table" then return nil end
  local by = {}
  for _, c in ipairs(w.candidates) do if type(c) == "table" and type(c.candidateId) == "string" then by[c.candidateId] = c end end
  return by
end

-- A schema 2 item that names a candidate must name one from this snapshot,
-- and a waypoint must go exactly where Outrider recorded that candidate.
function Advice.Grounded(item, c, cands)
  local id = item.candidateId
  if id == nil then return c.action ~= "waypoint" end   -- a free waypoint is never trusted
  if type(id) ~= "string" or not cands or not cands[id] then return false end
  c.candidateId = id
  if c.action == "waypoint" then
    local t = cands[id].target
    if type(t) ~= "table" or t.mapID ~= c.args.mapID or t.x ~= c.args.x or t.y ~= c.args.y then return false end
  end
  return true
end

function Advice.CleanAnswer(ans)
  if type(ans) ~= "table" then return nil end
  local out = { headline = plain(ans.headline, 120), summary = plain(ans.summary, 600), limits = {}, sources = {} }
  for i, l in ipairs(type(ans.limits) == "table" and ans.limits or {}) do
    if i > 4 then break end
    local t = plain(l, 160)
    if t then out.limits[#out.limits + 1] = t end
  end
  for i, l in ipairs(type(ans.sources) == "table" and ans.sources or {}) do
    if i > 8 then break end
    local t = plain(l, 80)
    if t then out.sources[#out.sources + 1] = t end
  end
  if not (out.headline or out.summary) then return nil end
  return out
end

-- Pasted advice (no reload, ns.db.char.pastedAdvice) wins over Advice.lua
-- when it is valid and answers the current snapshot.
function Advice:Load()
  local pasted = ns.db and ns.db.char and ns.db.char.pastedAdvice
  if type(pasted) == "table" then
    local items, why, answer = self:Check(pasted)
    if why == "ok" then return items, why, answer end
  end
  return self:Check(rawget(_G, "Outrider_Advice"))
end

-- Accept an advice code pasted from the companion; returns count, reason.
function Advice:Paste(text)
  local data, err = ns.Serialize.Import(text)
  if type(data) ~= "table" then return 0, err or "not an Outrider code" end
  if data.kind ~= "advice" then return 0, "that code is not advice" end
  local items, why, answer = self:Check(data)
  if why ~= "ok" then return 0, why end
  if #items == 0 and not answer then return 0, "no usable suggestions in that code" end
  ns.db.char.pastedAdvice = data
  return #items, "ok"
end

Advice._clean = clean

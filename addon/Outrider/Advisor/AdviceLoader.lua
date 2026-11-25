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
local Advice = { name = "advice", SCHEMA = 1, MAX_ITEMS = 12, MAX_PASTE = 64 * 1024 }
-- Schema 2 (Outrider Intelligence, AI02-05): adds answer = { headline,
-- summary, limits = {..}, sources = {..} } and items may name the WhatNow
-- candidate they act on (candidateId). Everything in schema 1 still works.
Advice.SCHEMAS = { [1] = true, [2] = true, [3] = true, [4] = true }
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

-- Schema 3: candidate selection only, NEVER model-authored actions.
-- Rebuild all actions exclusively from a fresh Outrider snapshot.
function Advice:CheckV3(a, snap)
  if not snap.snapshotId or a.answersSnapshotId ~= snap.snapshotId then
    return {}, "advice is stale"
  end
  if a.items ~= nil then return {}, "model-authored items forbidden" end
  if a.actionRequests ~= nil and
      (type(a.actionRequests) ~= "table" or next(a.actionRequests) ~= nil) then
    return {}, "model actions forbidden"
  end
  local allowed = {
    kind=true, schema=true, forCharacter=true, answersSnapshot=true,
    answersSnapshotId=true, rankedCandidateIds=true, rationaleEvidenceIds=true,
    headline=true, summary=true, assumptions=true, limitations=true, actionRequests=true,
  }
  for k in pairs(a) do if not allowed[k] then return {}, "unknown advice field" end end
  local cands = Advice.Candidates(snap)
  if not cands or type(a.rankedCandidateIds) ~= "table" or
      #a.rankedCandidateIds < 1 or #a.rankedCandidateIds > 3 then
    return {}, "invalid candidates"
  end
  local seen, out = {}, {}
  for _, id in ipairs(a.rankedCandidateIds) do
    if type(id) ~= "string" or seen[id] or not cands[id] then
      return {}, "unknown or duplicate candidate"
    end
    seen[id] = true
    local source = cands[id]
    local action, args
    if type(source.target) == "table" then
      action = "waypoint"
      args = { mapID = source.target.mapID, x = source.target.x, y = source.target.y }
    elseif Advice.PANELS[source.panel] then
      action, args = "open_panel", { panel = source.panel }
    elseif source.itemID then
      action, args = "show_item", { itemID = source.itemID }
    end
    if action then
      local item = clean({ title = source.title, why = source.why, confidence = source.label,
                           action = action, args = args })
      if not item then return {}, "invalid source candidate" end
      item.candidateId = id
      out[#out + 1] = item
    end
  end
  local sources = {}
  for id in pairs(cands) do sources["local:" .. id] = true end
  if a.rationaleEvidenceIds ~= nil and type(a.rationaleEvidenceIds) ~= "table" then
    return {}, "invalid evidence"
  end
  local evidenceIds = a.rationaleEvidenceIds or {}
  if #evidenceIds > 12 then return {}, "too many sources" end
  for _, id in ipairs(evidenceIds) do
    if type(id) ~= "string" or not sources[id] then return {}, "unknown evidence" end
  end
  local answer = Advice.CleanAnswer({
    headline = a.headline, summary = a.summary, limits = a.limitations,
    sources = evidenceIds,
  }, cands)
  return out, "ok", answer
end

-- XP60 schema 4: plans are DATA, not instructions. No model-defined actions.
-- Session binding is independent of legacy askedAt, which can survive logout.
function Advice:CheckNextSession(a)
  if a.kind ~= "nextSessionPlan" or a.goal ~= "xp" or a.budgetSeconds ~= 3600 or
      (a.status ~= "tentative" and a.status ~= "evidence_backed" and
       a.status ~= "insufficient_evidence") then
    return {}, "invalid XP60 contract"
  end
  local allowed = {
    kind=true, schema=true, forCharacter=true, basedOnSessionId=true,
    sourceDigest=true, createdAt=true, expiresAt=true, gameBuild=true,
    levelAtPlan=true, goal=true, budgetSeconds=true, status=true,
    headline=true, summary=true, baselineXPPerHour=true,
    estimatedEarnedXP=true, steps=true, qualitativeCandidateIds=true,
    limitations=true, actions=true,
  }
  for k in pairs(a) do if not allowed[k] then return {}, "unknown plan field" end end
  if type(a.sourceDigest) ~= "string" or #a.sourceDigest ~= 64 or
      not a.sourceDigest:match("^[a-f0-9]+$") then return {}, "bad source digest" end
  if type(a.basedOnSessionId) ~= "string" or #a.basedOnSessionId > 80 then
    return {}, "no source session" end
  if type(a.createdAt) ~= "number" or type(a.expiresAt) ~= "number" or
     a.createdAt > time() + 300 or a.expiresAt < time() or
     a.expiresAt - a.createdAt > 86400 then return {}, "next-session plan expired" end
  -- OI03-12: the source is the last play session with its /reload segments
  -- joined (SessionXP:Merged, OI03-01), the same way the companion reads it
  local source
  local X = ns.SessionXP
  if X and X.Merged then
    local ok, merged = pcall(X.Merged, X)
    if ok and type(merged) == "table" then source = merged[#merged] end
  end
  if not source then
    local state = ns.db.char.xp60
    local history = type(state) == "table" and state.history
    source = type(history) == "table" and history[#history] or nil
  end
  if type(source) ~= "table" or source.sessionId ~= a.basedOnSessionId or
     source.final ~= true or (source.flags and source.flags.incomplete) then
    return {}, "source session has changed"
  end
  if tostring(a.gameBuild or "") ~= tostring(source.build or "") then
    return {}, "game build differs from source" end
  local currentLevel = ns.Compat.Readable(ns.Compat.Call("UnitLevel", "player"))
  if type(currentLevel) == "number" and currentLevel ~= a.levelAtPlan then
    return {}, "character level changed"
  end
  if a.actions ~= nil and
      (type(a.actions) ~= "table" or next(a.actions) ~= nil) then
    return {}, "model actions forbidden"
  end
  if type(a.steps) ~= "table" or #a.steps > 12 then return {}, "invalid plan steps" end
  local snapshot = rawget(_G, "Outrider_Snapshots")
  snapshot = type(snapshot) == "table" and snapshot[ns.db.key]
  local candidates = snapshot and Advice.Candidates(snapshot) or nil
  local suggestions = {}
  local ids = a.qualitativeCandidateIds
  if ids ~= nil then
    if type(ids) ~= "table" or #ids > 3 then return {}, "invalid suggestions" end
    local unique = {}
    for _, id in ipairs(ids) do
      if type(id) ~= "string" or unique[id] or not (candidates and candidates[id]) then
        return {}, "untrusted suggestion"
      end
      unique[id] = true
      suggestions[#suggestions + 1] = {
        candidateId = id,
        title = plain(candidates[id].title, 120) or "Quest opportunity",
      }
    end
  end
  local seen, steps, last = {}, {}, 0
  local seenQuest, merged = {}, 0
  local QK = ns.NexusAdapters and ns.NexusAdapters.QuestKey
  for _, raw in ipairs(a.steps) do
    if type(raw) ~= "table" or type(raw.candidateId) ~= "string" or
       seen[raw.candidateId] or not (candidates and candidates[raw.candidateId]) or
       type(raw.startsAt) ~= "number" or type(raw.endsAt) ~= "number" or
       raw.startsAt < last or raw.endsAt <= raw.startsAt or
       raw.endsAt > 3600 or type(raw.xp) ~= "number" or raw.xp < 0 or
       raw.xp ~= math.floor(raw.xp) then
       return {}, "untrusted or oversized plan step"
    end
    seen[raw.candidateId] = true
    local orig = candidates[raw.candidateId]
    -- the same quest under two ids (quest:<name>, dq:<id>) is shown once
    local qk = QK and QK({ key = raw.candidateId, questID = orig.questID })
    if qk and seenQuest[qk] then merged = merged + 1 else
    if qk then seenQuest[qk] = true end
    steps[#steps + 1] = {
      candidateId = raw.candidateId, title = plain(orig.title, 120) or "Quest objective",
      minutes = math.ceil((raw.endsAt - raw.startsAt) / 60),
      startsAt = raw.startsAt, endsAt = raw.endsAt,
    }
    end
    last = raw.endsAt
  end
  local limits = {}
  if type(a.limitations) == "table" then
    for i, l in ipairs(a.limitations) do
      if i > 4 then break end
      local safe = plain(l, 160)
      if safe then limits[#limits + 1] = safe end
    end
  end
  if merged > 0 then limits[#limits + 1] = string.format("%d quest%s listed twice shown once.", merged, merged == 1 and "" or "s") end
  local answer = { headline = plain(a.headline, 120) or "Your next 60 minutes",
    summary = plain(a.summary, 600) or "Continue your current route.",
    plan = steps, budget = 60, planMinutes = math.ceil(last/60),
    limits = limits, sources = { "Saved gameplay session" },
    nextSession = true, planStatus = a.status, suggestions = suggestions,
    basedOnSessionId = a.basedOnSessionId,
    baselineXPPerHour = type(a.baselineXPPerHour) == "number" and
      math.floor(math.max(0, a.baselineXPPerHour)) or nil,
  }
  return {}, "ok", answer
end

-- Clean items and "ok", or {} and the reason, for one advice table.
function Advice:Check(a)
  if type(a) ~= "table" then return {}, "no advice file" end
  if not self.SCHEMAS[a.schema] then return {}, "wrong schema" end
  if a.forCharacter ~= ns.db.key then return {}, "advice is for another character" end
  if a.schema == 4 then return self:CheckNextSession(a) end
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
  if a.schema >= 2 and a.answersSnapshotId and snap.snapshotId and a.answersSnapshotId ~= snap.snapshotId then
    return {}, "advice is stale"
  end
  if a.schema == 3 then return self:CheckV3(a, snap) end
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
  return out, "ok", a.schema == 2 and Advice.CleanAnswer(a.answer, cands) or nil
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

local function minutes(v) return type(v) == "number" and v == v and v >= 0 and v <= 600 and math.floor(v) or nil end

function Advice.CleanAnswer(ans, cands)
  if type(ans) ~= "table" then return nil end
  local out = { headline = plain(ans.headline, 120), summary = plain(ans.summary, 600), limits = {}, sources = {},
    plan = {}, compare = nil, budget = minutes(ans.budget), planMinutes = minutes(ans.planMinutes) }
  -- plan and compare rows (AI03) must name steps from this snapshot; titles
  -- come from the snapshot too, never from the answer
  for i, r in ipairs(type(ans.plan) == "table" and ans.plan or {}) do
    if i > 5 then break end
    local c = type(r) == "table" and cands and cands[r.candidateId]
    if c then out.plan[#out.plan + 1] = { candidateId = r.candidateId, title = plain(c.title, 120) or r.candidateId,
      minutes = minutes(r.minutes) } end
  end
  if type(ans.compare) == "table" then
    local rows = {}
    for i, r in ipairs(ans.compare) do
      if i > 2 then break end
      local c = type(r) == "table" and cands and cands[r.candidateId]
      if c then rows[#rows + 1] = { candidateId = r.candidateId, title = plain(c.title, 120) or r.candidateId,
        minutes = minutes(r.minutes), label = Advice.CONFIDENCE[r.label] and r.label or "unknown", group = r.group == true } end
    end
    if #rows == 2 then out.compare = rows end
  end
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
  -- OI08-04: the companion never makes advice over 64 KB; anything bigger is refused before decoding
  if type(text) == "string" and #text > self.MAX_PASTE then return 0, "that code is too big (over 64 KB): ask again" end
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

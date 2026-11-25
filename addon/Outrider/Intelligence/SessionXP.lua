-- Intelligence/SessionXP.lua: opt-in, bounded XP/session observations.
-- This module never runs combat-log listeners, automation or external I/O.
local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("SessionXP", {
  title = "XP session recorder (private, opt-in)", phase = "P9", order = 98,
  defaultEnabled = false, defaults = { keep = 20 },
})
ns.SessionXP = M
M.SCHEMA, M.MAX_HISTORY, M.MAX_ZONES, M.MAX_QUESTS = 1, 20, 12, 40
M.DUP_SECONDS = 5

-- OI03-01: every record is a segment of a play session (Intelligence/
-- PlaySession.lua). A /reload ends a segment, not the session: that segment
-- gets endReason "reload" and final = false (it was not a completed
-- session), and the next one continues the same playSessionId. A clean
-- logout gives "logout" (final stays true); a login with no logout before it
-- gives "interrupted" (the record already joined history as incomplete).
-- Merged() joins segments into play sessions for anything that reports totals.
function M.Stamp(rec)
  local P = ns.PlaySession
  if P and P:Id() then rec.playSessionId, rec.segment = P:Id(), P:Segment() end
end
function M:OnPlaySession(_, kind, prev)
  local store = self:Store()
  if prev and prev.id then
    for i = #store.history, 1, -1 do
      local r = store.history[i]
      if r.playSessionId == prev.id and (r.segment or 1) == prev.segment then
        r.endReason = prev.reason
        if prev.reason == "reload" then r.final = false end
        break
      end
    end
  end
  if self.current then M.Stamp(self.current) end
end
M.MERGE = { sum = { "durationSeconds", "xpEarned" }, last = { "levelEnd", "endedAt", "final", "endReason" } }
function M:Merged()
  local hist = self:Store().history
  local merged = ns.PlaySession.Merge(hist, M.MERGE)
  -- verified only if every segment was; flags are the union of the segments'
  -- (in a new table: the saved records are never changed)
  local bad, flags = {}, {}
  for _, r in ipairs(hist) do
    local id = r.playSessionId
    if id then
      if r.xpVerified ~= true then bad[id] = true end
      flags[id] = flags[id] or {}
      for k, v in pairs(type(r.flags) == "table" and r.flags or {}) do if v then flags[id][k] = v end end
    end
  end
  for _, s in ipairs(merged) do
    local id = s.playSessionId
    if id then
      if bad[id] then s.xpVerified = false end
      s.flags = flags[id]
    end
  end
  return merged
end
local function integer(v, max)
  return type(v) == "number" and v == math.floor(v) and v >= 0 and v <= (max or 1e10)
end
local function clock()
  return (GetTime and C.Readable(GetTime())) or nil
end
local function wall() return time() end
local function xpstate()
  local level = C.Readable(C.Call("UnitLevel", "player"))
  local xp = C.Readable(C.Call("UnitXP", "player"))
  local cap = C.Readable(C.Call("UnitXPMax", "player"))
  if not integer(level, 200) or level == 0 or not integer(xp, 1e9) or
     not integer(cap, 1e9) or cap == 0 or xp > cap then return nil end
  return { level = level, xp = xp, cap = cap }
end
local function zone()
  local id = C.PlayerPosition("player")
  return integer(id, 1e8) and id or nil
end
function M:Store()
  local c = ns.db.char
  if c.xp60 ~= nil and type(c.xp60) ~= "table" then ns.KeepBad(c.xp60, "SessionXP:c.xp60") c.xp60 = nil end
  -- an older schema is kept whole in the archive before the new store starts;
  -- until it can be, it stays saved and new history goes to a saved staging
  -- store that is merged in afterwards (OI-FR03/FR15)
  local s, staged = ns.Archive:MigrateStore(c, "xp60", { dataset = "xp60OldSchema", path = "char.xp60",
    valid = function(x) return type(x) == "table" and x.schema == M.SCHEMA end,
    fresh = function() return { schema = M.SCHEMA, history = {} } end })
  M.recovery = staged and "old XP records could not be archived yet: left as they were, new ones kept apart" or nil
  if type(s.history) ~= "table" then ns.KeepBad(s.history, "SessionXP:c.xp60.history") s.history = {} end
  return s
end
function M:OnInitialize()
  self:Store()
end
function M:Tick()
  local s = self.current
  if not s then return end
  local t = clock()
  if not t or not self.lastClock then s.flags.clockUnknown = true return end
  local delta = t - self.lastClock
  self.lastClock = t
  if delta < 0 or delta > 86400 then s.flags.clockUnknown = true return end
  s.durationSeconds = math.min(86400, s.durationSeconds + delta)
  local zid = self.zoneId
  if zid then
    local record = self.zoneById and self.zoneById[zid]
    if record then record.durationSeconds = record.durationSeconds + delta end
  end
end
function M:SetZone(id)
  if not id or not self.current then return end
  if not self.zoneById then self.zoneById = {} end
  local rec = self.zoneById[id]
  if not rec and #self.current.zones < M.MAX_ZONES then
    rec = { mapID = id, durationSeconds = 0, xpEarned = 0 }
    self.current.zones[#self.current.zones + 1] = rec
    self.zoneById[id] = rec
  end
  self.zoneId = rec and id or nil
end
function M:Sample()
  if not self.current then return end
  self:Tick()
  local before, now = self.lastXP, xpstate()
  -- FIX (Claude, 2026-11-19, owner-approved; do not revert): one unreadable
  -- XP sample used to set flags.xpUnknown, and the companion's baseline
  -- (xp_baseline.valid_session) then threw the WHOLE session away. The
  -- first real test (session 1795080458-ec0e5702: 16 min, 1139 XP, level 1->2,
  -- 5 turn-ins) lost its XP/hour that way; the failed read was a single sample
  -- around the level-up or logout. Now a failed sample is skipped and counted:
  -- lastXP stays put, so the next good sample's delta covers the gap (same
  -- level or one level-up rollover, checked below as before). Only a session
  -- whose start was unreadable keeps xpUnknown (set in Start). Worst case a
  -- failed final read loses the XP since the previous good sample: an
  -- undercount, which keeps the baseline conservative.
  if not now then
    local f = self.current.flags
    f.xpSamplesSkipped = math.min(1000, (tonumber(f.xpSamplesSkipped) or 0) + 1)
    return
  end
  if before then
    local delta
    if now.level == before.level and now.xp >= before.xp then
      delta = now.xp - before.xp
    elseif now.level == before.level + 1 and before.cap >= before.xp then
      delta = before.cap - before.xp + now.xp
    elseif now.level == before.level and now.xp < before.xp then
      self.current.flags.xpReset = true
    else
      self.current.flags.rolloverUnknown = true
    end
    if integer(delta, 1e9) then
      self.current.xpEarned = self.current.xpEarned + delta
      local z = self.zoneById and self.zoneById[self.zoneId]
      if z then z.xpEarned = z.xpEarned + delta end
    else self.current.xpVerified = false end
  end
  self.lastXP = now
  self.current.levelEnd = now.level
end
function M:Start()
  local store = self:Store()
  -- A reload may interrupt a record; do not turn it into an invented full session.
  if type(store.current) == "table" and store.current.final ~= true then
    store.current.final = false
    store.current.flags = store.current.flags or {}
    store.current.flags.incomplete = true
    store.history[#store.history + 1] = store.current
  end
  while #store.history > M.MAX_HISTORY and ns.Archive:Shift("xpSessions", store.history, { path = "char.xp60.history", scope = "char" }) do end
  local xp = xpstate()
  local id = tostring(wall()) .. "-" .. tostring(ns.session or "session")
  local s = { schema = M.SCHEMA, sessionId = id, startedAt = wall(),
    durationSeconds = 0, levelStart = xp and xp.level or 0,
    levelEnd = xp and xp.level or 0, xpEarned = 0,
    xpVerified = xp ~= nil, final = false, zones = {}, questsTurnedIn = {},
    flags = {}, build = tostring(ns.build or "unknown") }
  if not xp then s.flags.xpUnknown = true end
  M.Stamp(s)
  store.current, self.current, self.lastXP = s, s, xp
  self.zoneById, self.zoneId, self.lastClock = {}, nil, clock()
  self:SetZone(zone())
  return s
end
function M:OnQuest(_, questID, rewardXP)
  if not self.current then return end
  questID = C.Readable(questID)
  if not integer(questID, 2147483647) or questID == 0 then return end
  self:Sample()
  local list = self.current.questsTurnedIn
  -- the same turn-in reported twice (a duplicate event) counts once (OI03-01)
  local at = math.floor(self.current.durationSeconds)
  for _, q in ipairs(list) do
    if q.questID == questID and math.abs((q.atOffsetSeconds or 0) - at) <= M.DUP_SECONDS then return end
  end
  if #list >= M.MAX_QUESTS then self.current.flags.questOverflow = true return end
  rewardXP = C.Readable(rewardXP)
  list[#list + 1] = { questID = questID, atOffsetSeconds = math.floor(self.current.durationSeconds),
    rewardXP = integer(rewardXP, 1e9) and rewardXP or nil,
    rewardSource = integer(rewardXP, 1e9) and "QUEST_TURNED_IN" or "unknown" }
end
function M:Checkpoint(final)
  if not self.current then return false end
  self:Sample()
  self:Tick()
  local s = self.current
  s.endedAt = wall()
  s.final = final == true
  if not s.final then s.flags.incomplete = true end
  local store = self:Store()
  store.history[#store.history + 1] = s
  while #store.history > M.MAX_HISTORY and ns.Archive:Shift("xpSessions", store.history, { path = "char.xp60.history", scope = "char" }) do end
  store.current = nil
  self.current, self.lastXP, self.zoneById, self.zoneId = nil, nil, nil, nil
  return true
end
function M:RefreshCandidateSnapshot()
  if not self.enabled or C.InCombat() or
      not (ns.WhatNow and ns.WhatNow.BuildSnapshot) then return false end
  local t = wall()
  if self.lastCandidateRefresh and t - self.lastCandidateRefresh < 180 then return false end
  -- The existing WhatNow source owns quest eligibility/route facts.
  -- Only an infrequent opt-in snapshot is retained, never a model call.
  local ok, data = pcall(ns.WhatNow.BuildSnapshot, ns.WhatNow)
  if not ok or type(data) ~= "table" then return false end
  data.seenAt = t
  ns.WhatNow.lastSnap = data
  self.lastCandidateRefresh = t
  return true
end
function M:OnEnable()
  self:Start()
  self:RefreshCandidateSnapshot()
  -- Low-frequency, opt-in native bookkeeping; never external AI monitoring.
  self.candidateTicker = ns.Timer.Ticker(300, function()
    if M.enabled then M:RefreshCandidateSnapshot() end
  end, "XP60 candidate refresh")
  self:On("PLAYER_XP_UPDATE", function(mod) mod:Sample() end)
  self:On("PLAYER_LEVEL_UP", function(mod) mod:Sample() end)
  self:On("QUEST_TURNED_IN", self.OnQuest)
  self:On("ZONE_CHANGED_NEW_AREA", function(mod)
    mod:Sample()
    mod:SetZone(zone())
    mod:RefreshCandidateSnapshot()
  end)
  self:On("PLAYER_LOGOUT", function(mod) mod:Checkpoint(true) end)
  self:On("OTR_PLAYSESSION", self.OnPlaySession)
end
function M:OnDisable()
  if self.candidateTicker then self.candidateTicker:Cancel() self.candidateTicker = nil end
  self:Checkpoint(false)
end
function M:Snapshot()
  local store = self:Store()
  local last = store.history[#store.history]
  if not last then return nil end
  return { schema = 1, last = {
    sessionId = last.sessionId, xpEarned = last.xpEarned,
    xpVerified = last.xpVerified, durationSeconds = math.floor(last.durationSeconds),
    levelStart = last.levelStart, levelEnd = last.levelEnd, final = last.final,
  } }
end
function M:Activity()
  local store = self:Store()
  return string.format("%d recorded, %s", #store.history, self.current and "recording" or "idle")
end
ns.AddCommand("xp60", "on|off|status|clear (private session XP recorder)", function(arg)
  arg = type(arg) == "string" and arg:lower():match("^%s*(.-)%s*$") or ""
  if arg == "on" then
    ns.Modules:SetEnabled("SessionXP", true)
    ns.Print("XP session recorder enabled for this character.")
  elseif arg == "off" then
    ns.Modules:SetEnabled("SessionXP", false)
    ns.Print("XP session recorder disabled.")
  elseif arg == "clear" then
    if M.current then M:Checkpoint(false) end
    -- kept, not deleted: the old history goes to the archive first
    local old = ns.db.char.xp60
    if type(old) == "table" and next(old) ~= nil and not ns.Archive:Put("xpSessionsCleared", old, { path = "char.xp60", scope = "char" }) then
      ns.Print("XP session history kept: it couldn't be archived, so nothing was cleared.")
      return
    end
    ns.db.char.xp60 = { schema = 1, history = {} }
    if M.enabled then M:Start() end
    ns.Print("XP session history cleared for this character (the old records are in the archive).")
  else
    ns.Print("XP recorder: %s (%s)", M.enabled and "on" or "off", M:Activity())
  end
end)

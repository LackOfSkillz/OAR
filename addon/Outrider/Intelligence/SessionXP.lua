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
  if type(c.xp60) ~= "table" or c.xp60.schema ~= M.SCHEMA then
    c.xp60 = { schema = M.SCHEMA, history = {} }
  end
  if type(c.xp60.history) ~= "table" then c.xp60.history = {} end
  return c.xp60
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
  if not now then self.current.flags.xpUnknown = true return end
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
  while #store.history > M.MAX_HISTORY do table.remove(store.history, 1) end
  local xp = xpstate()
  local id = tostring(wall()) .. "-" .. tostring(ns.session or "session")
  local s = { schema = M.SCHEMA, sessionId = id, startedAt = wall(),
    durationSeconds = 0, levelStart = xp and xp.level or 0,
    levelEnd = xp and xp.level or 0, xpEarned = 0,
    xpVerified = xp ~= nil, final = false, zones = {}, questsTurnedIn = {},
    flags = {}, build = tostring(ns.build or "unknown") }
  if not xp then s.flags.xpUnknown = true end
  store.current, self.current, self.lastXP = s, s, xp
  self.zoneById, self.zoneId, self.lastClock = {}, nil, clock()
  self:SetZone(zone())
  return s
end
function M:OnQuest(_, questID)
  if not self.current then return end
  questID = C.Readable(questID)
  if not integer(questID, 2147483647) or questID == 0 then return end
  self:Sample()
  local list = self.current.questsTurnedIn
  if #list >= M.MAX_QUESTS then self.current.flags.questOverflow = true return end
  list[#list + 1] = { questID = questID, atOffsetSeconds = math.floor(self.current.durationSeconds) }
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
  while #store.history > M.MAX_HISTORY do table.remove(store.history, 1) end
  store.current = nil
  self.current, self.lastXP, self.zoneById, self.zoneId = nil, nil, nil, nil
  return true
end
function M:OnEnable()
  self:Start()
  self:On("PLAYER_XP_UPDATE", function(mod) mod:Sample() end)
  self:On("PLAYER_LEVEL_UP", function(mod) mod:Sample() end)
  self:On("QUEST_TURNED_IN", self.OnQuest)
  self:On("ZONE_CHANGED_NEW_AREA", function(mod)
    mod:Sample()
    mod:SetZone(zone())
  end)
  self:On("PLAYER_LOGOUT", function(mod) mod:Checkpoint(true) end)
end
function M:OnDisable()
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
    ns.db.char.xp60 = { schema = 1, history = {} }
    if M.enabled then M:Start() end
    ns.Print("XP session history cleared for this character.")
  else
    ns.Print("XP recorder: %s (%s)", M.enabled and "on" or "off", M:Activity())
  end
end)

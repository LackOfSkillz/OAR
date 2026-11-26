-- Core/InspectBroker.lua
-- VG01-04/05: the one place in Outrider that asks the game to inspect another
-- player (D27, Gary 2026-11-26: every inspect goes through one shared broker).
-- Tooltip hover (PlayerInfo) and the Vanguard group scan both queue here.
--
--   local token = ns.InspectBroker:Request({ owner = "Vanguard", unit = "party1",
--     guid = guid, onReady = function(unit, guid, req) end,
--     onFail = function(req, reason) end, replace = true })
--   ns.InspectBroker:Cancel(token, reason) / :CancelOwner(owner, reason)
--
-- State per request: queued -> waiting -> collecting -> done, or failed /
-- canceled (terminal). One request in flight at a time; at least GAP seconds
-- between requests; TIMEOUT seconds to answer; one retry after BACKOFF; the
-- queue holds at most QUEUE_MAX (the raid cap). Nothing here repeats by
-- itself: a request is made only because a player hovered someone or pressed
-- Scan. NotifyInspect is a plain query, not a protected action.
--
-- Ownership (VG01-05): never sends while Blizzard's Inspect window is open
-- (waits instead), never clears inspect data while that window is open, and
-- an INSPECT_READY for anyone else (the player's own inspect, another addon)
-- is ignored. If a reply for someone else arrives while ours is waiting, our
-- request was overtaken: it is retried once, later. A reply is only handed on
-- when the unit token still belongs to the same GUID, so a late answer can't
-- fill in the wrong member. Combat, zoning and logout cancel everything.
-- Events are registered only while something is queued or waiting.
-- No names, realms or GUIDs are logged (D27).

local _, ns = ...
local C = ns.Compat
local B = { name = "InspectBroker", queue = {}, cur = nil, seq = 0, lastSent = nil, listening = false,
  stats = { sent = 0, done = 0, failed = 0, canceled = 0, ignored = 0, timeouts = 0, retries = 0, maxQueue = 0 } }
ns.InspectBroker = B

B.GAP = 2          -- seconds between requests (spec section 6: >= 2)
B.TIMEOUT = 8      -- seconds to wait for INSPECT_READY
B.BACKOFF = 4      -- extra wait before the single retry
B.MAX_RETRY = 1
B.QUEUE_MAX = 40   -- verified raid cap (MAX_RAID_MEMBERS, probe 2026-11-25)
B.DEFER = 1        -- re-check interval while waiting for combat to end / the Inspect window to close

local function now() return (GetTime and GetTime()) or 0 end
local function readable(v) return C.Readable(v) end

function B:InspectWindowOpen()
  local f = rawget(_G, "InspectFrame")
  return (f and f.IsShown and f:IsShown()) and true or false
end

-- ------------------------------------------------------------------ events
function B:Listen(on)
  if on == self.listening then return end
  self.listening = on
  if on then
    ns.Events:On("INSPECT_READY", self, function(_, guid) B:OnReady(guid) end)
    ns.Events:On("PLAYER_REGEN_DISABLED", self, function() B:CancelAll("combat") end)
    ns.Events:On("PLAYER_ENTERING_WORLD", self, function() B:CancelAll("zoning") end)
    ns.Events:On("PLAYER_LOGOUT", self, function() B:CancelAll("logout") end)
  else
    ns.Events:OffAll(self)
  end
end

function B:Idle() return self.cur == nil and #self.queue == 0 end

local function settle()
  if B:Idle() then
    if B.timer then B.timer:Cancel() B.timer = nil end
    B:Listen(false)
  end
end

local function arm(delay, fn, label)
  if B.timer then B.timer:Cancel() end
  B.timer = ns.Timer.After(math.max(0, delay), function() B.timer = nil fn() end, label)
end

-- ------------------------------------------------------------------ requests
function B:Find(guid)
  if self.cur and self.cur.guid == guid then return self.cur end
  for _, r in ipairs(self.queue) do if r.guid == guid then return r end end
end

-- true while the broker is waiting on (or reading) this player's reply
function B:Expecting(guid)
  return self.cur ~= nil and self.cur.guid == guid
end

function B:Request(req)
  if type(req) ~= "table" or type(req.owner) ~= "string" or type(req.unit) ~= "string" then return nil, "bad request" end
  local guid = readable(req.guid)
  if type(guid) ~= "string" or guid == "" then return nil, "no GUID" end
  if C.InCombat() then return nil, "combat" end
  if not C.Resolve("NotifyInspect") then return nil, "unavailable" end
  -- the same player already asked for: share the answer
  local same = self:Find(guid)
  if same then
    if same.owner ~= req.owner then
      same.extra = same.extra or {}
      same.extra[#same.extra + 1] = req
    end
    return same.token, "shared"
  end
  if req.replace then
    for i = #self.queue, 1, -1 do
      if self.queue[i].owner == req.owner then self:Finish(table.remove(self.queue, i), "canceled", "replaced") end
    end
  end
  if #self.queue >= self.QUEUE_MAX then return nil, "queue full" end
  self.seq = self.seq + 1
  local r = { token = self.seq, owner = req.owner, unit = req.unit, guid = guid, onReady = req.onReady, onFail = req.onFail,
    state = "queued", tries = 0, queuedAt = now(), notBefore = 0 }
  if req.front then table.insert(self.queue, 1, r) else self.queue[#self.queue + 1] = r end
  if #self.queue > self.stats.maxQueue then self.stats.maxQueue = #self.queue end
  self:Listen(true)
  if not self.cur then self:Pump() end
  return r.token
end

-- terminal: done, failed or canceled; tells the owner (and anyone sharing)
function B:Finish(r, state, reason)
  if not r or r.final then return end
  r.final, r.state, r.reason = true, state, reason
  if state == "done" then self.stats.done = self.stats.done + 1
  elseif state == "failed" then self.stats.failed = self.stats.failed + 1
  else self.stats.canceled = self.stats.canceled + 1 end
  if state ~= "done" then
    for _, x in ipairs({ r, unpack(r.extra or {}) }) do
      if x.onFail then ns.Safe("InspectBroker:onFail", x.onFail, r, reason or state) end
    end
  end
end

function B:Cancel(token, reason)
  if self.cur and self.cur.token == token then
    local r = self.cur
    self.cur = nil
    self:Finish(r, "canceled", reason or "canceled")
    if self.timer then self.timer:Cancel() self.timer = nil end
    if not self:Idle() then arm(self.GAP, function() B:Pump() end, "inspect:next") end
    settle()
    return true
  end
  for i, r in ipairs(self.queue) do
    if r.token == token then
      table.remove(self.queue, i)
      self:Finish(r, "canceled", reason or "canceled")
      settle()
      return true
    end
  end
  return false
end

function B:CancelOwner(owner, reason)
  local n = 0
  for i = #self.queue, 1, -1 do
    if self.queue[i].owner == owner then self:Finish(table.remove(self.queue, i), "canceled", reason) n = n + 1 end
  end
  if self.cur and self.cur.owner == owner then
    local r = self.cur
    self.cur = nil
    self:Finish(r, "canceled", reason)
    n = n + 1
    if self.timer then self.timer:Cancel() self.timer = nil end
    if not self:Idle() then arm(self.GAP, function() B:Pump() end, "inspect:next") end
  end
  settle()
  return n
end

function B:CancelAll(reason)
  local n = #self.queue + (self.cur and 1 or 0)
  local list = self.queue
  self.queue = {}
  local r = self.cur
  self.cur = nil
  if r then self:Finish(r, "canceled", reason) end
  for _, q in ipairs(list) do self:Finish(q, "canceled", reason) end
  if n > 0 then ns.Log:Debug("inspect", "canceled %d inspect request(s): %s", n, tostring(reason)) end
  settle()
  return n
end

-- ------------------------------------------------------------------ the pump
function B:Pump()
  if self.cur or #self.queue == 0 then settle() return end
  if C.InCombat() then self:CancelAll("combat") return end
  if self:InspectWindowOpen() then arm(self.DEFER, function() B:Pump() end, "inspect:defer") return end
  local t = now()
  local r = self.queue[1]
  local wait = math.max((self.lastSent and (self.lastSent + self.GAP - t)) or 0, r.notBefore - t)
  if wait > 0 then arm(wait, function() B:Pump() end, "inspect:gap") return end
  table.remove(self.queue, 1)
  -- the unit token must still be the same player, and inspectable now
  if readable(C.Call("UnitGUID", r.unit)) ~= r.guid then
    self:Finish(r, "failed", "moved")
    return self:Pump()
  end
  if readable(C.Call("CanInspect", r.unit)) ~= true then
    self:Finish(r, "failed", "out of range")
    return self:Pump()
  end
  local ok = pcall(NotifyInspect, r.unit)
  self.lastSent = t
  if not ok then
    self:Finish(r, "failed", "request refused")
    return self:Pump()
  end
  self.stats.sent = self.stats.sent + 1
  r.tries, r.state, r.sentAt = r.tries + 1, "waiting", t
  self.cur = r
  local token = r.token
  arm(self.TIMEOUT, function() B:OnTimeout(token) end, "inspect:timeout")
end

function B:Retry(r, reason)
  self.cur = nil
  if r.tries <= self.MAX_RETRY then
    self.stats.retries = self.stats.retries + 1
    r.state, r.notBefore = "queued", now() + self.BACKOFF
    table.insert(self.queue, 1, r)
  else
    self:Finish(r, "failed", reason)
  end
  if not self:Idle() then self:Pump() else settle() end
end

function B:OnTimeout(token)
  local r = self.cur
  if not r or r.token ~= token then return end
  self.stats.timeouts = self.stats.timeouts + 1
  self:Retry(r, "no answer")
end

function B:OnReady(guid)
  guid = readable(guid)
  local r = self.cur
  if not r then self.stats.ignored = self.stats.ignored + 1 return end
  if guid ~= r.guid then
    -- someone else's inspect (the player's own, or another addon) overtook ours
    self.stats.ignored = self.stats.ignored + 1
    if self.timer then self.timer:Cancel() self.timer = nil end
    self:Retry(r, "overtaken")
    return
  end
  if self.timer then self.timer:Cancel() self.timer = nil end
  self.cur = nil
  if C.InCombat() then self:Finish(r, "canceled", "combat") settle() return end
  -- the reply is for this GUID; read it only if the unit is still that player
  local unit = r.unit
  if readable(C.Call("UnitGUID", unit)) ~= guid then
    unit = nil
    for _, u in ipairs({ "mouseover", "target" }) do
      if readable(C.Call("UnitGUID", u)) == guid then unit = u break end
    end
  end
  if not unit then
    self:Finish(r, "failed", "moved")
  else
    r.state = "collecting"
    for _, x in ipairs({ r, unpack(r.extra or {}) }) do
      if x.onReady then ns.Safe("InspectBroker:onReady", x.onReady, unit, guid, r) end
    end
    self:Finish(r, "done")
  end
  -- clear only our own inspect, and never under Blizzard's open Inspect window
  if not self:InspectWindowOpen() and C.Resolve("ClearInspectPlayer") then pcall(ClearInspectPlayer) end
  if not self:Idle() then self:Pump() else settle() end
end

function B:Status()
  return { busy = self.cur ~= nil, queued = #self.queue, listening = self.listening, stats = self.stats }
end

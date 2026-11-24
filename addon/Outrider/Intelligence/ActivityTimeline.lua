-- Intelligence/ActivityTimeline.lua  (OI03-03)
-- What the time in a play session went to, from what the game shows, kept
-- by the outcome recorder (Intelligence/Outcomes.lua, same opt-in switch and
-- the same saved store, char.outcomes.activity).
--
-- One label at a time, the first that applies:
--   recovery      dead or a ghost (PLAYER_DEAD until back to life)
--   dungeon       inside a dungeon or raid (IsInInstance)
--   crafting      a profession window is open (TRADE_SKILL_SHOW/CLOSE)
--   travel        on a flight path (UnitOnTaxi)
--   quest         a quest event in the last QUEST_GAP seconds (accept, turn in,
--                 talk to a quest giver, objective progress)
--   inactive      flagged away (AFK), or nothing observed for IDLE seconds
--   unclassified  playing, but nothing above says what at
-- Nothing else is guessed: walking around is not "travel" and fighting is not
-- "quest" unless a quest event says so. No combat log, no screen capture.
--
-- Segments are contiguous: each starts where the last ended, so they never
-- overlap and always add up to the wall time from start to now. A stretch
-- with nothing observed becomes "inactive" from the last observed moment.

local _, ns = ...
local C = ns.Compat
local T = { QUEST_GAP = 300, IDLE = 300, TICK = 30, MAX_PARTS = 120, MAX_RECORDS = 20 }
ns.ActivityTimeline = T
T.LABELS = { "recovery", "dungeon", "crafting", "travel", "quest", "inactive", "unclassified" }

-- the label for a state (pure): s = { dead, instance, crafting, taxi,
-- lastQuestAt, lastActiveAt, afk, now }
function T.Label(s)
  local now = s.now or time()
  if s.dead then return "recovery" end
  if s.instance then return "dungeon" end
  if s.crafting then return "crafting" end
  if s.taxi then return "travel" end
  if s.lastQuestAt and now - s.lastQuestAt <= T.QUEST_GAP then return "quest" end
  if s.afk or (s.lastActiveAt and now - s.lastActiveAt > T.IDLE) then return "inactive" end
  return "unclassified"
end

-- ------------------------------------------------------------ recording
local function instanceNow()
  local inside, kind = C.Call("IsInInstance")
  return inside == true and (kind == "party" or kind == "raid" or kind == "scenario")
end

function T:Records(store) store.activity = ns.KeepTable(store.activity, "Activity:char.outcomes.activity") or {} return store.activity end

-- start a timeline for this play session segment (called by Outcomes:OnEnable)
function T:Start(mod, now)
  now = now or time()
  local P = ns.PlaySession
  self.mod = mod
  self.state = { dead = C.Call("UnitIsDeadOrGhost", "player") == true or C.Call("UnitIsGhost", "player") == true,
    instance = instanceNow(), crafting = false, taxi = C.Call("UnitOnTaxi", "player") == true,
    lastActiveAt = now, afk = C.Call("UnitIsAFK", "player") == true }
  self.rec = { playSessionId = P and P:Id(), segment = P and P:Segment(), from = now, to = now, totals = {}, parts = {} }
  self.cur = { label = T.Label(self.state), from = now }
  local list = self:Records(mod:Store())
  list[#list + 1] = self.rec
  while #list > T.MAX_RECORDS and ns.Archive:Shift("activitySessions", list, { path = "char.outcomes.activity", scope = "char" }) do end
end

local function add(rec, label, from, to)
  if to <= from then return end
  rec.totals[label] = (rec.totals[label] or 0) + (to - from)
  local last = rec.parts[#rec.parts]
  if last and last.label == label and last.to == from then last.to = to return end
  if #rec.parts >= T.MAX_PARTS then
    rec.partsCapped = true -- totals stay exact; only the detailed list stops growing
    return
  end
  rec.parts[#rec.parts + 1] = { label = label, from = from, to = to }
end

-- re-label now; closes the open segment when the label changes
function T:Update(now)
  if not self.rec then return end
  now = now or time()
  local s = self.state
  s.now = now
  local label = T.Label(s)
  local cur = self.cur
  if label == cur.label then self.rec.to = now return end
  -- nothing was observed since lastActiveAt: that stretch is the inactive one
  local cut = now
  if label == "inactive" and not s.afk and s.lastActiveAt then cut = s.lastActiveAt end
  if cut < cur.from then cut = cur.from end
  add(self.rec, cur.label, cur.from, cut)
  self.cur = { label = label, from = cut }
  self.rec.to = now
end

-- close the open segment (logout, disable)
function T:Close(now)
  if not self.rec then return end
  now = now or time()
  self:Update(now)
  add(self.rec, self.cur.label, self.cur.from, now)
  self.cur = { label = self.cur.label, from = now }
  self.rec.to = now
  self.rec.closed = true
end

-- the totals so far, including the open segment (for reports)
function T:Totals(now)
  if not self.rec then return {}, 0 end
  now = now or time()
  local out, sum = {}, 0
  for k, v in pairs(self.rec.totals) do out[k] = v sum = sum + v end
  if not self.rec.closed and now > self.cur.from then
    out[self.cur.label] = (out[self.cur.label] or 0) + (now - self.cur.from)
    sum = sum + (now - self.cur.from)
  end
  return out, sum
end

-- event wiring (Outcomes:OnEnable passes itself)
function T:Wire(mod)
  local function active(m) T.state.lastActiveAt = time() T:Update() end
  local function quest(m) T.state.lastQuestAt, T.state.lastActiveAt = time(), time() T:Update() end
  for _, e in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE",
    "QUEST_WATCH_UPDATE", "QUEST_REMOVED" }) do mod:On(e, quest) end
  for _, e in ipairs({ "PLAYER_STARTED_MOVING", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "LOOT_OPENED",
    "PLAYER_MONEY", "PLAYER_TARGET_CHANGED", "BAG_UPDATE_DELAYED", "PLAYER_XP_UPDATE" }) do mod:On(e, active) end
  mod:On("PLAYER_DEAD", function() T.state.dead = true active() end)
  mod:On("PLAYER_UNGHOST", function() T.state.dead = false active() end)
  mod:On("PLAYER_ALIVE", function()
    T.state.dead = C.Call("UnitIsGhost", "player") == true
    active()
  end)
  mod:On("TRADE_SKILL_SHOW", function() T.state.crafting = true active() end)
  mod:On("TRADE_SKILL_CLOSE", function() T.state.crafting = false active() end)
  for _, e in ipairs({ "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "TAXIMAP_CLOSED" }) do
    mod:On(e, function() T.state.taxi = C.Call("UnitOnTaxi", "player") == true active() end)
  end
  for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do
    mod:On(e, function() T.state.instance = instanceNow() active() end)
  end
  mod:On("PLAYER_FLAGS_CHANGED", function(_, _, unit)
    if unit == nil or unit == "player" then T.state.afk = C.Call("UnitIsAFK", "player") == true T:Update() end
  end)
  mod:On("PLAYER_LOGOUT", function() T:Close() end)
  -- the play session is settled at PLAYER_ENTERING_WORLD, after this started
  mod:On("OTR_PLAYSESSION", function()
    local P = ns.PlaySession
    if T.rec and P then T.rec.playSessionId, T.rec.segment = P:Id(), P:Segment() end
  end)
  self.ticker = ns.Timer.Ticker(T.TICK, function() if mod.enabled then T:Update() end end, "activity timeline")
end

function T:Stop()
  if self.ticker then self.ticker:Cancel() self.ticker = nil end
  self:Close()
  self.rec = nil
end

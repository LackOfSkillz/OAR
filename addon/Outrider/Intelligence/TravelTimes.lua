-- Intelligence/TravelTimes.lua  (OI03-05)
-- Real travel times: a trip runs from the moment a destination is set
-- (Waypoints, OTR_WAYPOINT_SET: the player's Go, a pin, a queue) to arriving
-- there (OTR_WAYPOINT_CLEARED "arrived"). Driven by the outcome recorder (same
-- opt-in switch, same store: char.outcomes.travel). FlightTimes keeps timing
-- flights on its own; this doesn't copy it.
--
-- Each trip records what happened on the way and gets one mode:
--   interrupted  a reload, logout or disconnect cut it (saved as open, closed
--                at the next login), or you died on the way
--   unknown_map  the start or the end map wasn't readable
--   teleport     a spell cast followed by a loading screen or a jump of more
--                than JUMP yards within JUMP_SECONDS (hearthstone, portals)
--   flight       you took a flight path on the way
--   transport    a loading screen without a flight or a teleport (boat,
--                zeppelin, a portal you walked into)
--   ground       none of the above
-- A trip that took more than DETOUR times the planner's own estimate
-- (Travel:TimeTo at the start) is a detour; time flagged AFK on the way is
-- noted. Only ground trips with no detour and no AFK are walking samples: the
-- others are kept, labelled, and never mixed in. A destination replaced
-- before arrival is an abandoned trip (kept, no time).

local _, ns = ...
local C = ns.Compat
local R = { DETOUR = 2, JUMP = 500, JUMP_SECONDS = 15, TICK = 5, MAX = 200 }
ns.TravelTimes = R

-- the mode for a finished trip's flags (pure)
function R.Mode(t)
  if t.interrupted or t.died then return "interrupted" end
  if not (t.fromMap and t.toMap) then return "unknown_map" end
  if t.teleported then return "teleport" end
  if t.flew then return "flight" end
  if t.loading then return "transport" end
  return "ground"
end
function R.WalkingSample(t)
  return t.kind == "arrived" and t.mode == "ground" and not t.detour and not t.afk and t.seconds ~= nil
end

function R:List(store) store.travel = ns.KeepTable(store.travel, "Travel:char.outcomes.travel") or {} return store.travel end
-- every trip of this character, archived ones first (review OI-FR02)
function R:History(store) return ns.Archive:WithActive("travelTrips", self:List(store)) end

local function save(mod, trip)
  local list = R:List(mod:Store())
  list[#list + 1] = trip
  local cap = mod.Cap and mod:Cap("travel") or R.MAX
  while #list > cap and ns.Archive:Shift("travelTrips", list, { path = "char.outcomes.travel", scope = "char" }) do end
end

local function pos()
  local W = ns.Waypoints
  if not (W and W.PlayerWorldPos) then return nil end
  local ok, cont, x, y = pcall(W.PlayerWorldPos)
  if ok and x and y then return cont, x, y end
end

function R:Begin(mod, w, now)
  now = now or time()
  if self.trip then self:Finish(mod, "abandoned", now) end
  local P = ns.PlaySession
  local here = tonumber(C.Readable(C.PlayerPosition("player")))
  local estimate
  local T = ns.Travel
  if T and T.Prepare and T.TimeTo and T.Point then
    -- the raw estimate (Pathfinder corrects TimeTo with these very trips)
    local tt = T.TimeToRaw or T.TimeTo
    local ok, secs = pcall(function() return tt(T, T:Prepare(), T.Point(w.mapID, w.x, w.y, w.title)) end)
    if ok and tonumber(secs) then estimate = math.floor(tonumber(secs)) end
  end
  local _, gameBuild = C.Call("GetBuildInfo")
  self.trip = { startedAt = now, fromMap = here, toMap = tonumber(w.mapID), title = type(w.title) == "string" and w.title:sub(1, 60) or nil,
    estimate = estimate, playSessionId = P and P:Id(), build = C.Readable(gameBuild) }
  mod:Store().openTrip = self.trip
  self.last = { pos(), at = now }
end

function R:Finish(mod, kind, now)
  local t = self.trip
  if not t then return end
  now = now or time()
  t.kind = kind
  t.endedAt = now
  if kind == "arrived" then
    t.seconds = now - t.startedAt
    if t.estimate and t.estimate > 0 and t.seconds > R.DETOUR * t.estimate then t.detour = true end
  end
  t.mode = R.Mode(t)
  t.walking = R.WalkingSample(t) or nil
  save(mod, t)
  self.trip = nil
  mod:Store().openTrip = nil
end

-- a trip left open by the last segment (reload, logout, disconnect) is
-- closed as interrupted, with how that segment ended
function R:Recover(mod, prev)
  local store = mod:Store()
  local open = store.openTrip
  if type(open) ~= "table" or (self.trip and self.trip == open) then return end
  open.interrupted, open.interruptedBy = true, prev and prev.reason or "unknown"
  open.kind, open.mode = "interrupted", "interrupted"
  local list = R:List(store)
  list[#list + 1] = open
  while #list > R.MAX and ns.Archive:Shift("travelTrips", list, { path = "char.outcomes.travel", scope = "char" }) do end
  store.openTrip = nil
end

function R:Tick(now)
  local t = self.trip
  if not t then return end
  now = now or time()
  if C.Call("UnitOnTaxi", "player") == true then t.flew = true end
  local cont, x, y = pos()
  local l = self.last
  if l and l[1] and cont and l[1] == cont and l[2] and x and not t.flew then
    local dx, dy = x - l[2], y - l[3]
    if math.sqrt(dx * dx + dy * dy) > R.JUMP and now - l.at <= R.JUMP_SECONDS and self.castAt and now - self.castAt <= R.JUMP_SECONDS then
      t.teleported = true
    end
  end
  self.last = { cont, x, y, at = now }
end

function R:Wire(mod)
  mod:On("OTR_WAYPOINT_SET", function(m, _, w) if type(w) == "table" then R:Begin(m, w) end end)
  mod:On("OTR_WAYPOINT_CLEARED", function(m, _, w, why)
    if not R.trip then return end
    if why == "arrived" then
      R.trip.toMap = tonumber(C.Readable(C.PlayerPosition("player"))) or R.trip.toMap
      R:Finish(m, "arrived")
    else
      R:Finish(m, "abandoned")
    end
  end)
  mod:On("UNIT_SPELLCAST_SUCCEEDED", function(_, _, unit) if unit == "player" then R.castAt = time() end end)
  mod:On("PLAYER_ENTERING_WORLD", function(_, _, isInitialLogin, isReloadingUi)
    local t = R.trip
    if t and not isInitialLogin and not isReloadingUi then
      t.loading = true
      if R.castAt and time() - R.castAt <= R.JUMP_SECONDS then t.teleported = true end
    end
  end)
  mod:On("PLAYER_CONTROL_LOST", function() if R.trip and C.Call("UnitOnTaxi", "player") == true then R.trip.flew = true end end)
  mod:On("PLAYER_DEAD", function() if R.trip then R.trip.died = true end end)
  mod:On("PLAYER_FLAGS_CHANGED", function() if R.trip and C.Call("UnitIsAFK", "player") == true then R.trip.afk = true end end)
  mod:On("OTR_PLAYSESSION", function(m, _, _, prev) R:Recover(m, prev) end)
  self.ticker = ns.Timer.Ticker(R.TICK, function() if mod.enabled then R:Tick() end end, "travel times")
end

-- forget an open trip (Start fresh): nothing is saved for it
function R:Reset() self.trip = nil end

function R:Stop(mod)
  if self.ticker then self.ticker:Cancel() self.ticker = nil end
  if self.trip and mod then self:Finish(mod, "abandoned") end
end

-- walking samples, and every trip by mode (for reports and the estimator)
function R:Summary(store)
  local by, walking = {}, {}
  for _, t in ipairs(R:History(store)) do
    by[t.mode or "?"] = (by[t.mode or "?"] or 0) + 1
    if t.walking then walking[#walking + 1] = t end
  end
  return { byMode = by, walking = walking }
end

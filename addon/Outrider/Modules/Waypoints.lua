-- Modules/Waypoints.lua  (P3-01)
-- ns.Waypoints:Set(mapID, x, y, title) / :Clear(). Backends, in order:
--   "blizzard"  C_Map.SetUserWaypoint + C_SuperTrack (present on Forever, probe 2026-11-11)
--   "tomtom"    TomTom:AddWaypoint when TomTom is loaded
--   "none"      kept and logged; the fallback arrow (P3-02) draws from it
-- Fires OTR_WAYPOINT_SET / OTR_WAYPOINT_CLEARED. Clears itself on arrival
-- (within `arrive` yards), checked once a second only while one is active.
-- x, y are map fractions 0..1; /ride way takes 0..100 like the map shows.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Waypoints", {
  title = "Waypoints",
  phase = "P3",
  order = 50,
  defaults = { arrive = 10, autoClear = true, queue = {}, queueRunning = false },
})
ns.Waypoints = M

function M:OnDisable() self:Clear("module off") end

function M:Backend()
  if C.Has("C_Map.SetUserWaypoint") and C.Has("UiMapPoint.CreateFromCoordinates") then return "blizzard" end
  if C.IsAddOnLoaded("TomTom") and rawget(_G, "TomTom") and TomTom.AddWaypoint then return "tomtom" end
  return "none"
end

-- World positions in yards, always as (north, west) = UnitPosition's
-- (posX, posY). C_Map.GetWorldPosFromMapPos may hand its axes back in the
-- other order; Calibrate() compares both for the player's own spot and
-- sets M.swap (checked in game, logged once per session).
local function rawWorld(mapID, x, y)
  local get, vec = C.Resolve("C_Map.GetWorldPosFromMapPos"), rawget(_G, "CreateVector2D")
  if type(get) ~= "function" or type(vec) ~= "function" then return nil end
  local ok, continent, pos = pcall(get, mapID, vec(x, y))
  if not ok or not pos then return nil end
  local okXY, a, b = pcall(pos.GetXY, pos)
  if not okXY then return nil end
  return continent, a, b
end

function M.WorldPos(mapID, x, y)
  local continent, a, b = rawWorld(mapID, x, y)
  if not a then return nil end
  if M.swap then return continent, b, a end
  return continent, a, b
end

-- Width and height of a map in yards, measured between its corners. Uses
-- only distances, so it does not matter which world axis is north (the
-- minimap dots drifted the wrong way when that was assumed, 2026-11-11).
local sizes = {}
function M.MapSize(mapID)
  local s = sizes[mapID]
  if s then return s[1], s[2] end
  local _, ax, ay = rawWorld(mapID, 0, 0)
  local _, bx, by = rawWorld(mapID, 1, 0)
  local _, cx, cy = rawWorld(mapID, 0, 1)
  if not (ax and bx and cx) then return nil end
  local w = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
  local h = math.sqrt((cx - ax) ^ 2 + (cy - ay) ^ 2)
  if w <= 0 or h <= 0 then return nil end
  sizes[mapID] = { w, h }
  return w, h
end

function M.PlayerWorldPos()
  local y, x, _, instance = C.Call("UnitPosition", "player")
  if not x then return nil end
  return instance, x, y
end

function M:Calibrate()
  local mapID, mx, my = C.PlayerPosition("player")
  local _, px, py = M.PlayerWorldPos()
  if not (mapID and mx and px) then return nil end
  local _, a, b = rawWorld(mapID, mx, my)
  if not a then return nil end
  local straight = math.abs(a - px) + math.abs(b - py)
  local swapped = math.abs(a - py) + math.abs(b - px)
  M.swap = swapped < straight
  self:Info("world axes: map->world %s (off by %.1f yards; UnitPosition x=%.1f y=%.1f, map gives %.1f, %.1f)",
    M.swap and "SWAPPED" or "same order", math.min(straight, swapped), px, py, a, b)
  return M.swap
end

-- Pins Gary asked Claude for in chat, set once on the named character's next
-- login (never replacing a waypoint he set himself). Coordinates from the
-- Questie Forever DB and Outrider's own sightings.
M.REQUESTS = {
  -- (Vulgara's pin, 2026-11-14 08:08, retired: Gary reached her at 08:12)
  -- moved from 50.1, 48.7 (Questie point in the lake, Gary's screenshot) to the
  -- Warcraft Wiki spot "immediately north of Falaath Village"; guides say 50.2, 51.0
  { id = "slydris-20261114b", char = "Khreos", mapID = 2521, x = 0.506, y = 0.512,
    title = "Slydris (rare elite fox, 1.5s pet), north edge of Falaath Village" },
}

function M:Requests()
  local done = ns.db.global.pinRequestsDone or {}
  ns.db.global.pinRequestsDone = done
  local me = C.Readable(C.Call("UnitName", "player"))
  for _, r in ipairs(M.REQUESTS) do
    if not done[r.id] and (not r.char or r.char == me) and not self.current then
      done[r.id] = time()
      self:Set(r.mapID, r.x, r.y, r.title)
      ns.Print("map pin set: %s", r.title)
    end
  end
end

function M:OnEnable()
  self:On("PLAYER_ENTERING_WORLD", function(mod)
    mod:Requests()
    if mod:Settings().queueRunning and not mod.current then mod:QueueStart() end
    if mod.calibrated then return end
    if mod:Calibrate() ~= nil then mod.calibrated = true end
  end)
  self:On("OTR_WAYPOINT_CLEARED", function(mod, _, waypoint, why)
    if why == "arrived" and waypoint.opts and waypoint.opts.queued then
      local settings = mod:Settings()
      if settings.queueRunning and settings.queue[1] and settings.queue[1].mapID == waypoint.mapID
        and settings.queue[1].x == waypoint.x and settings.queue[1].y == waypoint.y then
        table.remove(settings.queue, 1)
        if #settings.queue > 0 then
          mod:QueueStart()
        else
          settings.queueRunning = false
          ns.Print("waypoint queue finished")
        end
      end
    end
  end)
end

function M:Distance()
  local w = self.current
  if not w then return nil end
  if not w.wx then w.continent, w.wx, w.wy = M.WorldPos(w.mapID, w.x, w.y) end
  local _, px, py = M.PlayerWorldPos()
  if not (w.wx and px) then return nil end
  local dx, dy = w.wx - px, w.wy - py
  return math.sqrt(dx * dx + dy * dy)
end

function M:Set(mapID, x, y, title, opts)
  if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then return false, "bad waypoint" end
  if x < 0 or x > 1 or y < 0 or y > 1 then return false, "x and y must be 0..1" end
  if self:Settings().queueRunning and not (opts and opts.queued) then
    self:Settings().queueRunning = false  -- manual, corpse, or rare pin takes priority
  end
  self:Clear("replaced", true)
  local backend = self:Backend()
  local w = { mapID = mapID, x = x, y = y, title = title or "Waypoint", backend = backend, t = time(), opts = opts }
  if backend == "blizzard" then
    local ok = pcall(function()
      C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
      if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    end)
    if not ok then w.backend = "none" end
  elseif backend == "tomtom" then
    local ok, uid = pcall(TomTom.AddWaypoint, TomTom, mapID, x, y, { title = w.title, persistent = false })
    if ok then w.uid = uid else w.backend = "none" end
  end
  self.current = w
  self:Info("waypoint set %s map=%d %.2f,%.2f backend=%s", w.title, mapID, x * 100, y * 100, w.backend)
  ns.Events:Fire("OTR_WAYPOINT_SET", w)
  if self:Settings().autoClear and not self.ticker then
    self.ticker = ns.Timer.Ticker(1, function() M:CheckArrival() end, "waypoints:arrive")
  end
  return true, w
end

function M:CheckArrival()
  local d = self:Distance()
  if d and d <= (self:Settings().arrive or 10) then self:Clear("arrived") end
end

function M:Clear(why, quiet)
  local w = self.current
  if self.ticker then self.ticker:Cancel() self.ticker = nil end
  if not w then return false end
  self.current = nil
  if w.backend == "blizzard" then
    pcall(function()
      if C_Map.ClearUserWaypoint then C_Map.ClearUserWaypoint() end
      if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(false) end
    end)
  elseif w.backend == "tomtom" and w.uid then
    pcall(TomTom.RemoveWaypoint, TomTom, w.uid)
  end
  if not quiet then
    self:Info("waypoint cleared (%s)", tostring(why))
    ns.Events:Fire("OTR_WAYPOINT_CLEARED", w, why)
  end
  return true
end

M.QUEUE_MAX = 30

function M:QueueAdd(mapID, x, y, title)
  if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number"
     or x < 0 or x > 1 or y < 0 or y > 1 then return false, "bad queued waypoint" end
  local s = self:Settings()
  s.queue = type(s.queue) == "table" and s.queue or {}
  if #s.queue >= M.QUEUE_MAX then return false, "queue is full (30 stops)" end
  s.queue[#s.queue + 1] = { mapID = mapID, x = x, y = y, title = title or "Route stop" }
  return true, #s.queue
end

function M:QueueStart()
  local s = self:Settings()
  if not s.queue or #s.queue == 0 then s.queueRunning = false return false, "queue empty" end
  if self.current and not (self.current.opts and self.current.opts.queued) then
    s.queueRunning = false
    return false, "a manual waypoint is active; clear it before resuming"
  end
  s.queueRunning = true
  local w = s.queue[1]
  return self:Set(w.mapID, w.x, w.y, w.title, { queued = true })
end

function M:QueueNext()
  local s = self:Settings()
  if not s.queue or #s.queue == 0 then return false end
  if self.current and self.current.opts and self.current.opts.queued then self:Clear("skipped", true) end
  table.remove(s.queue, 1)
  if #s.queue == 0 then s.queueRunning = false return true end
  if s.queueRunning then return self:QueueStart() end
  return true
end

function M:MapArgument(text)
  local num = tonumber(text)
  if num and num >= 1 and num == math.floor(num) then return num end
  return ns.Travel and ns.Travel:MapByName(text) or nil
end

ns.AddCommand("way", "<x> <y> [title] | <zone> <x> <y> | add <zone> <x> <y> | start|pause|next|list|clearqueue", function(arg)
  arg = tostring(arg or "")
  if arg == "clear" then
    M:Clear("command")
    M:Settings().queueRunning = false
    ns.Print("waypoint cleared; queue paused")
    return
  end
  if arg == "list" then
    local s = M:Settings()
    ns.Print("route: %d stops (%s)", #(s.queue or {}), s.queueRunning and "running" or "paused")
    for i, p in ipairs(s.queue or {}) do
      if i > 10 then break end
      ns.Print("%d. %s (map %d: %.1f, %.1f)", i, p.title, p.mapID, p.x * 100, p.y * 100)
    end
    return
  end
  if arg == "pause" then M:Settings().queueRunning = false ns.Print("route paused") return end
  if arg == "clearqueue" then
    M:Settings().queueRunning, M:Settings().queue = false, {}
    if M.current and M.current.opts and M.current.opts.queued then M:Clear("route cleared") end
    ns.Print("route queue cleared")
    return
  end
  if arg == "start" or arg == "resume" then
    local ok, msg = M:QueueStart()
    ns.Print(ok and "route started" or tostring(msg))
    return
  end
  if arg == "next" then ns.Print(M:QueueNext() and "next stop selected" or "route empty") return end
  local enqueue = arg:match("^add%s+")
  local raw = enqueue and arg:sub(5) or arg
  -- Explicit 3-number form must be parsed first: mapID x y. Otherwise
  -- "1412 40 50" is silently mistaken for x=1412, y=40.
  local mapID, x, y, title
  local zid, zx, zy, ztitle = raw:match("^(%d+)%s+([%d%.]+)[,%s]+([%d%.]+)%s*(.*)$")
  if zid and zx and zy then
    mapID, x, y, title = M:MapArgument(zid), tonumber(zx), tonumber(zy), ztitle
  else
    local xs, ys, atitle = raw:match("^([%d%.]+)[,%s]+([%d%.]+)%s*(.*)$")
    if xs and ys then
      mapID, x, y, title = C.PlayerPosition("player"), tonumber(xs), tonumber(ys), atitle
    else
      local zone, xx, yy, rest = raw:match("^(.-)%s+([%d%.]+)[,%s]+([%d%.]+)%s*(.*)$")
      mapID, x, y, title = zone and M:MapArgument(zone), tonumber(xx), tonumber(yy), rest
    end
  end
  if not (mapID and x and y and x >= 0 and x <= 100 and y >= 0 and y <= 100) then
    ns.Print("usage: /ride way [add] [zone] 45.2 61.8 [title] | start|next|pause|list|clearqueue")
    return
  end
  if enqueue then
    local ok, why = M:QueueAdd(mapID, x / 100, y / 100, title ~= "" and title or nil)
    ns.Print(ok and string.format("queued stop %d at %.1f, %.1f (map %d)", why, x, y, mapID) or tostring(why))
    return
  end
  local ok, w = M:Set(mapID, x / 100, y / 100, title ~= "" and title or nil)
  if ok then ns.Print("waypoint %s at %.1f, %.1f (%s)", w.title, x, y, w.backend) else ns.Print(tostring(w)) end
end)

-- Original /ride way command replaced above.
--


function M:Activity()
  local w = self.current
  if not w then return "no waypoint (" .. self:Backend() .. " ready)" end
  local d = self:Distance()
  return string.format("to %s, %s", w.title, d and string.format("%d yards", d) or "distance unknown")
end

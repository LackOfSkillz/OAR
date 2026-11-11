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
  defaults = { arrive = 10, autoClear = true },
})
ns.Waypoints = M

function M:OnDisable() self:Clear("module off") end

function M:Backend()
  if C.Has("C_Map.SetUserWaypoint") and C.Has("UiMapPoint.CreateFromCoordinates") then return "blizzard" end
  if C.IsAddOnLoaded("TomTom") and rawget(_G, "TomTom") and TomTom.AddWaypoint then return "tomtom" end
  return "none"
end

-- World position in yards for a map point (nil when the client can't say).
function M.WorldPos(mapID, x, y)
  local get, vec = C.Resolve("C_Map.GetWorldPosFromMapPos"), rawget(_G, "CreateVector2D")
  if type(get) ~= "function" or type(vec) ~= "function" then return nil end
  local ok, continent, pos = pcall(get, mapID, vec(x, y))
  if not ok or not pos then return nil end
  local okXY, wx, wy = pcall(pos.GetXY, pos)
  if not okXY then return nil end
  return continent, wx, wy
end

function M.PlayerWorldPos()
  local y, x, _, instance = C.Call("UnitPosition", "player")
  if not x then return nil end
  return instance, x, y
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

ns.AddCommand("way", "<x> <y> [title] | clear  waypoint on the current map (map numbers 0-100)", function(arg)
  if not arg or arg == "clear" then M:Clear("command") ns.Print("waypoint cleared") return end
  local xs, ys, title = arg:match("^([%d%.]+)[,%s]+([%d%.]+)%s*(.*)$")
  local x, y = tonumber(xs), tonumber(ys)
  local mapID = C.PlayerPosition("player")
  if not (x and y and mapID) then ns.Print("usage: /ride way 45.2 61.8 [title]") return end
  local ok, w = M:Set(mapID, x / 100, y / 100, title ~= "" and title or nil)
  if ok then ns.Print("waypoint %s at %.1f, %.1f (%s)", w.title, x, y, w.backend) else ns.Print(tostring(w)) end
end)

function M:Activity()
  local w = self.current
  if not w then return "no waypoint (" .. self:Backend() .. " ready)" end
  local d = self:Distance()
  return string.format("to %s, %s", w.title, d and string.format("%d yards", d) or "distance unknown")
end

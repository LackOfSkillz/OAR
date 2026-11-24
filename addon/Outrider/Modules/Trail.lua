-- Modules/Trail.lua  (breadcrumbs; requirement 2026-11-15, after getting lost
-- in Dalaran: breadcrumbs on the map showing where to walk)
-- Outrider remembers where you walk and draws it on the world map and the
-- minimap as small gold dots, so a way out of a city (or any path) you have
-- walked once is there for good, for every character on the account.
-- Rides you took (portals, boats, loading screens Travel learned) show as
-- pins at the spot you left from: "Ride to Stormwind".
-- Recording runs only while you move (one ticker between
-- PLAYER_STARTED_MOVING and PLAYER_STOPPED_MOVING, like the coordinates);
-- a dot is added every SPACING yards, skipped where one already is, never on
-- a flight path. Account-wide in ns.db.global.trails[mapID] = { {x, y, t}, ... }.
-- Data only: nothing here moves you or acts for you.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Trail", {
  title = "Breadcrumbs (where you walked)",
  phase = "P3",
  order = 54,
  defaults = {},
})
ns.Trail = M

M.SPACING = 12      -- yards between dots
M.NEAR = 7          -- no new dot within this many yards of an old one
M.MAX = 800         -- dots per map; the oldest go first
M.MAP_HOURS, M.MAP_DOTS, M.MAP_GAP = 3, 200, 0.02 -- what the world map draws
M.EVERY = 2         -- seconds between samples while moving

function M:OnInitialize()
  local g = ns.db.global
  g.trails = ns.KeepTable(g.trails, "Trail:g.trails") or {}
  self.db = g.trails
end

-- Yards between two spots on one map, from the map's size (one lookup per
-- map, cached by Waypoints); about 1000 yards across when it isn't known.
local function yards(mapID, a, b)
  local w, h = ns.Waypoints.MapSize(mapID)
  local dx, dy = (a.x - b.x) * (w or 1000), (a.y - b.y) * (h or 1000)
  return math.sqrt(dx * dx + dy * dy)
end

-- Adds a dot if this spot is new. Returns true when one was added.
function M:Sample()
  if C.Call("UnitOnTaxi", "player") then return false end
  local mapID, x, y = C.PlayerPosition("player")
  if not (mapID and x and y) or (x == 0 and y == 0) then return false end
  local list = self.db[mapID]
  if type(list) ~= "table" then ns.KeepBad(list, "Trail:list") list = {} self.db[mapID] = list end
  local here = { x = x, y = y }
  local last = self.last
  if last and last.mapID == mapID and yards(mapID, last, here) < M.SPACING then return false end
  for i = #list, 1, -1 do
    if yards(mapID, list[i], here) < M.NEAR then
      self.last = { mapID = mapID, x = x, y = y }
      return false
    end
  end
  list[#list + 1] = { x = math.floor(x * 10000 + 0.5) / 10000, y = math.floor(y * 10000 + 0.5) / 10000, t = time() }
  ns.trailRev = (ns.trailRev or 0) + 1 -- Path re-plans on a new revision (review OI01-R13)
  while #list > M.MAX and ns.Archive:Shift("trail", list, { path = "global.trails[mapID]", keys = { mapID = mapID } }) do end
  self.last = { mapID = mapID, x = x, y = y }
  self.added = (self.added or 0) + 1
  if ns.MapPins and ns.MapPins.cache then ns.MapPins.cache[mapID] = nil end
  return true
end

function M:Dots(mapID) return self.db[mapID] or {} end

-- Where a learned ride went, by name ("Stormwind City"), else the map name.
function M.RideName(l)
  local to = l.to or {}
  local info = to.mapID and C.Call("C_Map.GetMapInfoAtPosition", to.mapID, to.x or 0.5, to.y or 0.5)
  local name = type(info) == "table" and C.Readable(info.name)
  if type(name) ~= "string" or name == "" then name = ns.Travel and ns.Travel.ZoneName(to.mapID) or "?" end
  return name
end

-- Pins for MapPins: dots on this map, and rides that start here.
function M:Pins(mapID, hidden)
  local out = {}
  if not hidden.trail then
    -- On the map only the recent path, thinned (premium plan B20: the full
    -- trail drew a dense scribble over towns): the last 3 hours, no two dots
    -- closer than ~2% of the map, at most 200. The saved trail is untouched.
    local dots, cut, shown, lx, ly = self:Dots(mapID), time() - M.MAP_HOURS * 3600, 0, nil, nil
    for i = #dots, 1, -1 do
      local d = dots[i]
      if (d.t or 0) < cut or shown >= M.MAP_DOTS then break end
      if not lx or (d.x - lx) ^ 2 + (d.y - ly) ^ 2 >= M.MAP_GAP ^ 2 then
        out[#out + 1] = { id = string.format("trail-%06d", i), kind = "trail", mapID = mapID, x = d.x, y = d.y,
          name = "You walked here", when = d.t, small = true }
        shown, lx, ly = shown + 1, d.x, d.y
      end
    end
  end
  if not hidden.ride then
    for i, l in ipairs(ns.db.global.travelLinks or {}) do
      if l.from and l.from.mapID == mapID then
        out[#out + 1] = { id = "ride-" .. i, kind = "ride", mapID = mapID, x = l.from.x, y = l.from.y,
          name = "Ride to " .. M.RideName(l), when = l.t,
          title = l.t and ("you took it " .. date("%b %d", l.t)) or nil }
      end
    end
  end
  return out
end

function M:Clear(mapID)
  -- what the player clears is archived first (data preservation override)
  if mapID then
    if self.db[mapID] ~= nil and not ns.Archive:Put("trailCleared", self.db[mapID], { path = "global.trails[mapID]", keys = { mapID = mapID } }) then return false end
    self.db[mapID] = nil
  else
    for k, list in pairs(self.db) do
      if ns.Archive:Put("trailCleared", list, { path = "global.trails[mapID]", keys = { mapID = k } }) then self.db[k] = nil end
    end
  end
  self.last = nil
  ns.trailRev = (ns.trailRev or 0) + 1
  if ns.MapPins then ns.MapPins:Invalidate() end
end

function M:OnEnable()
  self:On("PLAYER_STARTED_MOVING", function(mod)
    if not mod.ticker then mod.ticker = ns.Timer.Ticker(M.EVERY, function() M:Sample() end, "trail") end
  end)
  self:On("PLAYER_STOPPED_MOVING", function(mod)
    if mod.ticker then mod.ticker:Cancel() mod.ticker = nil end
    mod:Sample()
  end)
  self:On("ZONE_CHANGED_NEW_AREA", function(mod) mod.last = nil end)
end

function M:OnDisable()
  if self.ticker then self.ticker:Cancel() self.ticker = nil end
end

function M:Activity()
  local n = 0
  for _, list in pairs(self.db) do n = n + #list end
  return string.format("%d breadcrumbs saved; gold dots on the map show where you walked", n)
end

ns.AddCommand("trail", "[clear|clear here]  breadcrumbs: the paths you walked, on the map", function(arg)
  arg = (arg or ""):lower()
  if arg == "clear" then M:Clear() ns.Print("breadcrumbs cleared") return end
  if arg == "clear here" then
    local mapID = C.PlayerPosition("player")
    M:Clear(mapID) ns.Print("breadcrumbs cleared on this map") return
  end
  ns.Print(M:Activity())
end)

-- Modules/Path.lua  (the way there; Gary, 2026-11-21: "I'm in a city and I
-- have no clue how to get to where the arrow is pointing ... do this any
-- time a player selects a destination, on the big map and the minimap")
-- Whenever there is a destination (a waypoint, a Journey leg, a quest Outrider
-- is guiding you to), Outrider draws a line of bright dots from you to it on
-- the world map and the minimap.
-- The game gives addons no walking paths, so the line follows ground that was
-- really walked: the breadcrumbs (Trail) of every character on the account.
-- Where nobody has walked yet it goes straight, in paler dots, and the next
-- time you walk there the line learns it. Nothing is invented: a dot is
-- either a spot you stood on or a straight line between two of them.
-- Planning: breadcrumbs closer than LINK yards join up into paths; Dijkstra
-- finds the cheapest way from you to the destination, where a yard walked
-- before costs 1 and a yard off the known paths costs OFF. Re-planned when
-- the destination changes and every few seconds while you move.
-- Data only: it draws dots, it never moves you.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Path", {
  title = "The way there (dots to your destination)",
  phase = "P3",
  order = 55,
  defaults = { on = true },
})
ns.Path = M

M.LINK = 30        -- yards: breadcrumbs this close are one walked path
M.LINK_CROSS = 20  -- the same between two maps (a city and its zone, at the gate)
M.OFF = 2.5        -- a yard nobody walked costs this much
M.STEP = 16        -- yards between drawn dots on a walked path
M.STEP_GUESS = 26  -- and on a straight guess
M.MARGIN = 400     -- yards around you and the destination that count
M.EVERY = 3        -- seconds between re-plans while moving
M.MOVED = 12       -- yards you must move before a re-plan
M.MAX_NODES = 4000
M.WALKED = { 0.30, 1.00, 0.75 }
M.GUESS = { 0.85, 0.95, 1.00 }

local W -- ns.Waypoints, set at enable

-- ---------------------------------------------------------------- geometry
-- A map's corners in world yards, to turn world spots back into map spots.
local corners = {}
local function frame(mapID)
  local f = corners[mapID]
  if f ~= nil then return f or nil end
  local c0, ax, ay = W.WorldPos(mapID, 0, 0)
  local _, bx, by = W.WorldPos(mapID, 1, 0)
  local _, cx, cy = W.WorldPos(mapID, 0, 1)
  if not (ax and bx and cx) then corners[mapID] = false return nil end
  local e1x, e1y, e2x, e2y = bx - ax, by - ay, cx - ax, cy - ay
  local det = e1x * e2y - e1y * e2x
  if det == 0 then corners[mapID] = false return nil end
  f = { cont = c0, ax = ax, ay = ay, e1x = e1x, e1y = e1y, e2x = e2x, e2y = e2y, det = det }
  corners[mapID] = f
  return f
end
function M.Forget() corners = {} end

-- World spot -> map spot (x, y in 0..1), or nil when it isn't on this map.
function M.ToMap(mapID, cont, wx, wy)
  local f = frame(mapID)
  if not f or (cont and f.cont and cont ~= f.cont) then return nil end
  local dx, dy = wx - f.ax, wy - f.ay
  local u = (dx * f.e2y - dy * f.e2x) / f.det
  local v = (f.e1x * dy - f.e1y * dx) / f.det
  if u < 0 or u > 1 or v < 0 or v > 1 then return nil end
  return u, v
end

local function dist(a, b)
  local dx, dy = a.wx - b.wx, a.wy - b.wy
  return math.sqrt(dx * dx + dy * dy)
end

-- ---------------------------------------------------------------- the destination
-- Outrider's own waypoint (also every Journey leg), else the quest Outrider
-- handed to the game's quest arrow.
function M:Target()
  local w = W and W.current
  if w and w.mapID and w.x and w.y then return { mapID = w.mapID, x = w.x, y = w.y, title = w.title } end
  local Q = ns.QuestObjectives
  if Q and Q.enabled and Q.guideQuest and Q.Nearest then
    local ok, spot = pcall(Q.Nearest, Q, Q.guideQuest)
    if ok and spot and spot.mapID and spot.x and spot.y then
      return { mapID = spot.mapID, x = spot.x, y = spot.y, title = spot.label }
    end
  end
end

-- ---------------------------------------------------------------- walked ground
-- Every breadcrumb on this continent near the trip, in world yards. World
-- spots per map are cached and rebuilt when that map's trail grows.
local worldCache = {}
local function worldDots(mapID, list)
  local c = worldCache[mapID]
  if c and c.n == #list then return c end
  c = { n = #list }
  for i, d in ipairs(list) do
    local cont, wx, wy = W.WorldPos(mapID, d.x, d.y)
    if wx then c[#c + 1] = { cont = cont, wx = wx, wy = wy, mapID = mapID } c.cont = cont end
  end
  worldCache[mapID] = c
  return c
end

function M:Nodes(cont, a, b)
  local trails = ns.db.global.trails or {}
  local minX, maxX = math.min(a.wx, b.wx) - M.MARGIN, math.max(a.wx, b.wx) + M.MARGIN
  local minY, maxY = math.min(a.wy, b.wy) - M.MARGIN, math.max(a.wy, b.wy) + M.MARGIN
  local out = {}
  for mapID, list in pairs(trails) do
    if type(list) == "table" and #list > 0 then
      local c = worldDots(mapID, list)
      if c.cont == nil or c.cont == cont then
        for _, p in ipairs(c) do
          if p.wx >= minX and p.wx <= maxX and p.wy >= minY and p.wy <= maxY then
            out[#out + 1] = p
            if #out >= M.MAX_NODES then return out end
          end
        end
      end
    end
  end
  return out
end

-- ---------------------------------------------------------------- planning
-- Small binary heap of { cost, node }.
local function push(h, cost, n)
  h[#h + 1] = { cost, n }
  local i = #h
  while i > 1 do
    local p = math.floor(i / 2)
    if h[p][1] <= h[i][1] then break end
    h[p], h[i] = h[i], h[p]
    i = p
  end
end
local function pop(h)
  local top = h[1]
  local last = table.remove(h)
  if #h > 0 then
    h[1] = last
    local i = 1
    while true do
      local l, r, s = 2 * i, 2 * i + 1, i
      if h[l] and h[l][1] < h[s][1] then s = l end
      if h[r] and h[r][1] < h[s][1] then s = r end
      if s == i then break end
      h[s], h[i] = h[i], h[s]
      i = s
    end
  end
  return top
end

-- The way from a to b over walked ground: a list of { wx, wy, walked }
-- (walked = this stretch follows breadcrumbs). Pure apart from reading the
-- nodes given.
function M.Plan(a, b, nodes)
  local n = #nodes
  local S, E = n + 1, n + 2
  local pts = {}
  for i = 1, n do pts[i] = nodes[i] end
  pts[S], pts[E] = a, b
  -- walked links between breadcrumbs, found through a grid
  local cell, grid = M.LINK, {}
  local function key(p) return math.floor(p.wx / cell) .. ":" .. math.floor(p.wy / cell) end
  for i = 1, n do
    local k = key(pts[i])
    grid[k] = grid[k] or {}
    table.insert(grid[k], i)
  end
  local function neighbours(i)
    local p = pts[i]
    local gx, gy = math.floor(p.wx / cell), math.floor(p.wy / cell)
    local out = {}
    for dx = -1, 1 do
      for dy = -1, 1 do
        for _, j in ipairs(grid[(gx + dx) .. ":" .. (gy + dy)] or {}) do
          if j ~= i then
            local d = dist(p, pts[j])
            local limit = (p.mapID == pts[j].mapID) and M.LINK or M.LINK_CROSS
            if d <= limit then out[#out + 1] = { j, d } end
          end
        end
      end
    end
    return out
  end
  local best, from, done, heap = { [S] = 0 }, {}, {}, {}
  push(heap, 0, S)
  while #heap > 0 do
    local top = pop(heap)
    local cost, i = top[1], top[2]
    if not done[i] then
      done[i] = true
      if i == E then break end
      local function relax(j, c, walked)
        local nc = cost + c
        if not best[j] or nc < best[j] then best[j], from[j] = nc, { i, walked } push(heap, nc, j) end
      end
      -- straight to the destination, off the known paths
      relax(E, dist(pts[i], b) * M.OFF, false)
      if i == S then
        for j = 1, n do relax(j, dist(a, pts[j]) * M.OFF, false) end
      else
        for _, e in ipairs(neighbours(i)) do relax(e[1], e[2], true) end
      end
    end
  end
  local route, i = {}, E
  while i do
    local f = from[i]
    table.insert(route, 1, { wx = pts[i].wx, wy = pts[i].wy, walked = f and f[2] or false })
    i = f and f[1]
  end
  return route
end

-- Dots along the route, every STEP yards (closer on walked ground).
function M.Dots(route)
  local out = {}
  for k = 2, #route do
    local p, q = route[k - 1], route[k]
    local step = q.walked and M.STEP or M.STEP_GUESS
    local d = dist(p, q)
    local t = (out.carry or step) -- distance until the next dot
    while t <= d do
      local f = t / d
      out[#out + 1] = { wx = p.wx + (q.wx - p.wx) * f, wy = p.wy + (q.wy - p.wy) * f, walked = q.walked }
      t = t + step
    end
    out.carry = t - d
  end
  out.carry = nil
  return out
end

function M:Replan(why)
  self.dots, self.route = nil, nil
  if not self:Settings().on then return self:Redraw() end
  local target = self:Target()
  local cont, px, py = W.PlayerWorldPos()
  if not (target and px) then return self:Redraw() end
  local tc, tx, ty = W.WorldPos(target.mapID, target.x, target.y)
  if not tx or (tc and cont and tc ~= cont) then return self:Redraw() end -- another continent: Journey plans the legs
  local a, b = { wx = px, wy = py }, { wx = tx, wy = ty }
  local nodes = self:Nodes(cont, a, b)
  local route = M.Plan(a, b, nodes)
  self.route, self.dots, self.cont = route, M.Dots(route), cont
  self.target, self.at = target, { wx = px, wy = py }
  local walked, total = 0, 0
  for k = 2, #route do
    local d = dist(route[k - 1], route[k])
    total = total + d
    if route[k].walked then walked = walked + d end
  end
  self.walked, self.total = walked, total
  if why ~= "moving" or not self.logged then
    self.logged = true
    self:Debug("way to %s: %.0f yards, %.0f on paths walked before (%d breadcrumbs nearby, %s)",
      tostring(target.title), total, walked, #nodes, tostring(why))
  end
  self:Redraw()
end

-- Pins for one map: the dots that fall on it.
function M:Pins(mapID)
  local out = {}
  if not (self.dots and mapID) then return out end
  local title = self.target and self.target.title or "your destination"
  for i, d in ipairs(self.dots) do
    local x, y = M.ToMap(mapID, self.cont, d.wx, d.wy)
    if x then
      out[#out + 1] = { id = "path-" .. i, kind = "path", mapID = mapID, x = x, y = y, small = true, walked = d.walked,
        name = "The way to " .. tostring(title),
        title = d.walked and "a path walked before" or "straight on: nobody walked here yet, so the line can't see walls" }
    end
  end
  return out
end

function M:Redraw()
  if ns.MapPins and ns.MapPins.map and ns.MapPins.map.IsShown and ns.MapPins.map:IsShown() and ns.MapPins.Refresh then
    pcall(ns.MapPins.Refresh, ns.MapPins)
  end
  if ns.MinimapPins and ns.MinimapPins.enabled and ns.MinimapPins.Update then pcall(ns.MinimapPins.Update, ns.MinimapPins) end
end

function M:Tick()
  if not self:Target() then
    if self.dots then self:Replan("no destination") end
    return
  end
  local _, px, py = W.PlayerWorldPos()
  if not px then return end
  if not self.at or dist(self.at, { wx = px, wy = py }) >= M.MOVED then self:Replan("moving") end
end

function M:OnEnable()
  W = ns.Waypoints
  self:On("OTR_WAYPOINT_SET", function(mod) mod:Replan("new destination") end)
  self:On("OTR_WAYPOINT_CLEARED", function(mod) mod:Replan("destination cleared") end)
  self:On("SUPER_TRACKING_CHANGED", function(mod) mod:Replan("quest arrow") end)
  self:On("ZONE_CHANGED_NEW_AREA", function(mod) M.Forget() mod:Replan("new zone") end)
  self:On("PLAYER_STARTED_MOVING", function(mod)
    if not mod.ticker then mod.ticker = ns.Timer.Ticker(M.EVERY, function() M:Tick() end, "path") end
  end)
  self:On("PLAYER_STOPPED_MOVING", function(mod)
    if mod.ticker then mod.ticker:Cancel() mod.ticker = nil end
    mod:Tick()
  end)
end

function M:OnDisable()
  if self.ticker then self.ticker:Cancel() self.ticker = nil end
  self.dots, self.route = nil, nil
end

function M:Activity()
  if not self.dots then return "no destination: pick one and a line of dots shows the way" end
  return string.format("the way to %s: %.0f yards, %.0f of them on paths walked before",
    tostring(self.target and self.target.title), self.total or 0, self.walked or 0)
end

ns.AddCommand("path", "[on|off]  dots on the map and minimap from you to your destination", function(arg)
  arg = (arg or ""):lower()
  if arg == "on" or arg == "off" then
    M:Settings().on = arg == "on"
    M:Replan("switched " .. arg)
    ns.Print("the way there: " .. arg)
    return
  end
  ns.Print(M:Activity())
end)

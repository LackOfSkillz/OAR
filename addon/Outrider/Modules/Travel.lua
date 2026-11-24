-- Modules/Travel.lua
-- Routes from where the player stands to any spot in the world (requirement
-- 2026-11-13: the fastest way through airships, portals and paths).
-- A small graph, rebuilt each time a route is asked for:
--   walk  between any two points on the same continent (world yards / run speed)
--   fly   between two flight points this character knows, same continent
--   ride  boats, zeppelins, skycutters, trams, portals: the guide pack
--         (Data/Transports.lua) plus trips Outrider saw Gary make
-- Dijkstra over the points picks the quickest route. Times are estimates
-- (RUN, FLY, ride lengths below), good for comparing, not for a stopwatch.
-- The travel pack (Outrider_Data_Travel, from ForeverDB / Shortest Path
-- Forever, approved 2026-11-23): real flight legs with their flight
-- times (a flight follows its legs between flight points you know, not a
-- straight line), boats and zeppelins with their timetables (time = the
-- average wait at the dock plus the crossing), exact dock spots, portals and
-- lifts. Without the pack the old estimates are used.
-- Learning (no typing): at the flight master the client lists every flight
-- point and which ones this character knows; and a loading screen that is
-- not a flight, hearthstone, teleport or death moves Gary between two places,
-- which is saved as a learned ride with both exact ends.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Travel", {
  title = "Travel planner (routes across zones)",
  phase = "P3",
  order = 47,
  defaults = {},
})
ns.Travel = M

M.RUN = 7          -- yards per second on foot (estimate; mounts later)
M.FLY = 30         -- yards per second on a flight path (estimate)
M.FLY_START = 20   -- seconds to talk to the flight master and take off
M.RIDE = { boat = 180, zeppelin = 180, skycutter = 180, tram = 60, portal = 10, learned = 120 }
local TELEPORTS = { "hearthstone", "teleport", "portal", "astral recall" }
M.TRAVEL_ADDON = "Outrider_Data_Travel"
M.HOP = 5          -- seconds added per flight leg (landing at a flight point on the way)

-- The travel pack, or false.
function M:Pack()
  if self.pack ~= nil then return self.pack end
  if not rawget(_G, "Outrider_DataTravel") then C.LoadAddOn(self.TRAVEL_ADDON) end
  local d = rawget(_G, "Outrider_DataTravel")
  self.pack = type(d) == "table" and type(d.taxi) == "table" and d or false
  if self.pack then
    -- flight legs both ways, quickest kept: legs[a][b] = seconds
    local legs = {}
    for _, l in ipairs(d.flights or {}) do
      for _, ab in ipairs({ { l[1], l[2] }, { l[2], l[1] } }) do
        legs[ab[1]] = legs[ab[1]] or {}
        if not legs[ab[1]][ab[2]] or l[3] < legs[ab[1]][ab[2]] then legs[ab[1]][ab[2]] = l[3] end
      end
    end
    self.legs = legs
  end
  self:Info(self.pack and "travel pack loaded from %s" or "no travel pack (%s): flights and boats use estimates",
    self.pack and tostring(d.source) or self.TRAVEL_ADDON)
  return self.pack
end

-- Seconds of the quickest way through a timetable from stop i to stop j:
-- the average wait for the next departure (half the period) plus the
-- crossing (arrive at j - depart from i, around the clock).
function M.Crossing(ride, i, j)
  local period, stops = ride[3], ride[4]
  local a, b = stops[i], stops[j]
  if not (a and b and period and period > 0) then return nil end
  local t = (b[2] - a[3]) % period
  return period / 2 + t, t
end

function M:OnInitialize()
  local g = ns.db.global
  g.travelLinks = ns.KeepTable(g.travelLinks, "Travel:g.travelLinks") or {}
  g.taxiNodes = ns.KeepTable(g.taxiNodes, "Travel:g.taxiNodes") or {}
end

local function charTaxi()
  local c = ns.db.char
  c.taxiKnown = ns.KeepTable(c.taxiKnown, "Travel:c.taxiKnown") or {}
  return c.taxiKnown
end

-- ------------------------------------------------------------------ maps
-- Zone names -> uiMapID, from the client's own map tree (top of the
-- player's map chain, all descendants).
function M:MapByName(name)
  if type(name) ~= "string" then return nil end
  -- the top of the player's map chain; Zephras Isle hangs off a different
  -- root than Kalimdor (bug 2026-11-21: a cache built in Thunder Bluff
  -- found no Zephras Isle places), so one cache per root, merged
  local id = C.PlayerPosition("player")
  for _ = 1, 10 do
    local info = id and C.Call("C_Map.GetMapInfo", id)
    local parent = type(info) == "table" and info.parentMapID
    if not parent or parent == 0 then break end
    id = parent
  end
  self.byName = self.byName or {}
  self.rootsRead = self.rootsRead or {}
  if id and not self.rootsRead[id] then
    self.rootsRead[id] = true
    local kids = C.Call("C_Map.GetMapChildrenInfo", id, nil, true)
    for _, k in ipairs(type(kids) == "table" and kids or {}) do
      local n = C.Readable(k.name)
      if type(n) == "string" and not self.byName[n:lower()] then self.byName[n:lower()] = k.mapID end
    end
  end
  return self.byName[name:lower()]
end

function M.ZoneName(mapID)
  local info = mapID and C.Call("C_Map.GetMapInfo", mapID)
  return type(info) == "table" and C.Readable(info.name) or ("map " .. tostring(mapID))
end

-- A point with world position. Without x, y: the middle of the zone, approx.
function M.Point(mapID, x, y, label)
  if not mapID then return nil end
  local approx = not (x and y)
  local p = { mapID = mapID, x = x or 0.5, y = y or 0.5, label = label, approx = approx }
  p.cont, p.wx, p.wy = ns.Waypoints.WorldPos(mapID, p.x, p.y)
  if not p.wx then return nil end
  return p
end

function M.Here()
  local mapID, x, y = C.PlayerPosition("player")
  return mapID and M.Point(mapID, x, y, "you")
end

local function dist(a, b)
  local dx, dy = a.wx - b.wx, a.wy - b.wy
  return math.sqrt(dx * dx + dy * dy)
end

-- ------------------------------------------------------------- learning
-- Flight map open: remember every node (account-wide) and the ones this
-- character can fly to.
function M:OnTaxiMap()
  local tmap = C.Call("GetTaxiMapID") or C.PlayerPosition("player")
  local nodes = tmap and (C.Call("C_TaxiMap.GetAllTaxiNodes", tmap) or C.Call("C_TaxiMap.GetTaxiNodesForMap", tmap))
  if type(nodes) ~= "table" then return 0 end
  local g, known, n, k = ns.db.global.taxiNodes, charTaxi(), 0, 0
  local unreachable = rawget(_G, "Enum") and Enum.FlightPathState and Enum.FlightPathState.Unreachable or 2
  for _, node in ipairs(nodes) do
    local x, y
    if node.position and node.position.GetXY then x, y = node.position:GetXY()
    elseif node.position then x, y = node.position.x, node.position.y end
    if node.nodeID and x and y then
      local cont, wx, wy = ns.Waypoints.WorldPos(tmap, x, y)
      g[node.nodeID] = { name = C.Readable(node.name), mapID = tmap, x = x, y = y, cont = cont, wx = wx, wy = wy }
      n = n + 1
      if node.state ~= unreachable then known[node.nodeID] = true k = k + 1 end
    end
  end
  self:Info("flight map %s: %d flight points, %d you can fly to", tostring(tmap), n, k)
  return k
end

function M:OnSpell(_, unit, _, spellID)
  if unit ~= "player" then return end
  local name = C.SpellName(spellID)
  if type(name) ~= "string" then return end
  local low = name:lower()
  for _, w in ipairs(TELEPORTS) do
    if low:find(w, 1, true) then self.teleportT = C.Call("GetTime") or 0 end
  end
end

function M:OnLoadingStart()
  self.before = M.Here()
  self.beforeT = C.Call("GetTime") or 0
  self.onTaxi = C.Call("UnitOnTaxi", "player") and true or false
end

-- After a loading screen: a ride we didn't know? (not flight, teleport, death, instance)
function M:OnArrive(_, isLogin, isReload)
  local before = self.before
  self.before = nil
  if isLogin or isReload or not before then return end
  local now = C.Call("GetTime") or 0
  if self.onTaxi or C.Call("UnitOnTaxi", "player") then return end
  if self.teleportT and now - self.teleportT < 30 then return end
  if C.Call("UnitIsDeadOrGhost", "player") or C.Call("IsInInstance") then return end
  local after = M.Here()
  if not after or (after.cont == before.cont and dist(after, before) < 200) then return end
  local links = ns.db.global.travelLinks
  for _, l in ipairs(links) do
    if l.from.mapID == before.mapID and l.to.mapID == after.mapID
      and math.abs(l.from.x - before.x) < 0.03 and math.abs(l.from.y - before.y) < 0.03 then
      l.n = (l.n or 1) + 1
      return l
    end
  end
  local l = { kind = "learned", from = { mapID = before.mapID, x = before.x, y = before.y },
    to = { mapID = after.mapID, x = after.x, y = after.y }, n = 1, t = time(), verified = true, oneWay = true,
    faction = C.Call("UnitFactionGroup", "player") }
  links[#links + 1] = l
  self:Info("learned a ride: %s %.1f,%.1f -> %s %.1f,%.1f", M.ZoneName(before.mapID), before.x * 100, before.y * 100,
    M.ZoneName(after.mapID), after.x * 100, after.y * 100)
  return l
end

function M:OnEnable()
  self:On("TAXIMAP_OPENED", self.OnTaxiMap)
  self:On("UNIT_SPELLCAST_SUCCEEDED", self.OnSpell)
  self:On("LOADING_SCREEN_ENABLED", self.OnLoadingStart)
  self:On("PLAYER_ENTERING_WORLD", self.OnArrive)
  self:On("PLAYER_ENTERING_WORLD", function(mod) if not mod.checked then mod.checked = true mod:CheckZones() end end)
end

-- Self-check at login: which guide zone names Forever's map tree doesn't know.
function M:CheckZones()
  local missing, total, seen = {}, 0, {}
  for _, packs in pairs(ns.Data.packs.link or {}) do
    for _, l in ipairs(packs) do
      for _, z in ipairs({ l.from.zone, l.to.zone }) do
        if not seen[z] then
          seen[z] = true
          total = total + 1
          if not self:MapByName(z) then missing[#missing + 1] = z end
        end
      end
    end
  end
  table.sort(missing)
  self:Info("travel: %d of %d guide zones found on the map%s", total - #missing, total,
    #missing > 0 and ("; not found: " .. table.concat(missing, ", ")) or "")
end

-- ---------------------------------------------------------------- graph
-- Rides usable by this character: { kind, from = point, to = point, cost, label, note }
-- A dock the guide pack names without coordinates ("Menethil Harbor"): the
-- town's flight master, from the client's own flight point list (POICapture,
-- source "client", verified). Harbors sit next to their flight master, so the
-- arrow leads to the right town instead of the middle of the zone.
function M:Dock(place)
  if type(place) ~= "string" or place == "" then return nil end
  local want = place:lower()
  for _, p in pairs(ns.db.global.pois or {}) do
    if p.source == "client" and p.kind == "flight_master" and type(p.name) == "string" then
      local town = p.name:lower():match("^([^,]+)")
      if town == want then   -- exact town only: Stormwind's harbor is not by its gryphons
        local pt = M.Point(p.mapID, p.x, p.y, place)
        if pt then pt.nearFlight = true return pt end
      end
    end
  end
  return nil
end

local function endPoint(self, e)
  -- the zeppelin master or shipmaster was seen standing somewhere: that wins
  if e.npc and ns.NPCPack and ns.NPCPack.Seen then
    local sm, sx, sy = ns.NPCPack.Seen(e.npc)
    if sm and sm == self:MapByName(e.zone) then return M.Point(sm, sx, sy, e.place) end
  end
  if e.x and e.y then return M.Point(self:MapByName(e.zone), e.x, e.y, e.place) end
  return self:Dock(e.place) or M.Point(self:MapByName(e.zone), nil, nil, e.place)
end

function M:Rides()
  local faction = C.Call("UnitFactionGroup", "player")
  local race = C.Call("UnitRace", "player")
  local out = {}
  local function add(kind, a, b, cost, label, note, l)
    if a and b then out[#out + 1] = { kind = kind, from = a, to = b, cost = cost, label = label, note = note, link = l } end
  end
  local pack = self:Pack()
  local covered = {}
  if pack then
    local function dock(id)
      local dk = pack.docks and pack.docks[id]
      local pt = dk and M.Point(dk[1][1], dk[1][2], dk[1][3], dk[2] or M.ZoneName(dk[1][1]))
      return pt, dk
    end
    for _, r in ipairs(pack.rides or {}) do
      if not r[2] or r[2] == faction then
        local stops = r[4]
        for i = 1, #stops do
          for j = 1, #stops do
            if i ~= j then
              local a, b = dock(stops[i][1]), dock(stops[j][1])
              local cost, crossing = M.Crossing(r, i, j)
              if a and b and cost then
                if not a.label or a.label:find("^map ") then a.label = M.ZoneName(a.mapID) end
                local note = string.format("leaves about every %s, the trip takes %s", M.Minutes(r[3]), M.Minutes(crossing))
                add(r[1], a, b, cost, tostring(a.label) .. " to " .. M.ZoneName(b.mapID), note, { kind = r[1], pack = true })
                covered[r[1] .. ":" .. a.mapID .. ":" .. b.mapID] = true
              end
            end
          end
        end
      end
    end
    for _, p in ipairs(pack.portals or {}) do
      local a = M.Point(p[3][1], p[3][2], p[3][3], p[2])
      local b = M.Point(p[4][1], p[4][2], p[4][3], M.ZoneName(p[4][1]))
      add(p[1] == "lift" and "lift" or "portal", a, b, p[5] or 10, p[2], nil, { kind = p[1], pack = true })
    end
  end
  for _, packs in pairs(ns.Data.packs.link or {}) do
    for _, l in ipairs(packs) do
      local fromMap, toMap = self:MapByName(l.from.zone), self:MapByName(l.to.zone)
      local dup = pack and fromMap and toMap and (covered[l.kind .. ":" .. fromMap .. ":" .. toMap] or covered[l.kind .. ":" .. toMap .. ":" .. fromMap])
      if not dup and (not l.faction or l.faction == faction) and (not l.race or l.race == race) then
        local a, b = endPoint(self, l.from), endPoint(self, l.to)
        local cost = l.ride or M.RIDE[l.kind] or 180
        add(l.kind, a, b, cost, l.from.place .. " to " .. l.to.place, l.note, l)
        if not l.oneWay then add(l.kind, b, a, cost, l.to.place .. " to " .. l.from.place, l.note, l) end
      end
    end
  end
  for _, l in ipairs(ns.db.global.travelLinks) do
    if not l.faction or l.faction == faction then
      local a = M.Point(l.from.mapID, l.from.x, l.from.y, M.ZoneName(l.from.mapID))
      local b = M.Point(l.to.mapID, l.to.x, l.to.y, M.ZoneName(l.to.mapID))
      add("learned", a, b, M.RIDE.learned, M.ZoneName(l.from.mapID) .. " to " .. M.ZoneName(l.to.mapID), nil, l)
    end
  end
  return out
end

-- Every way to travel from one place to another that this character can
-- use (requirement 2026-11-16: find the portals, ships and airships):
-- { kind, name = "Boat to Theramore", from = point, to = point, where, place }
-- where: "exact" (guide or captured spot), "flight" (the town's flight
-- master, the dock is nearby), "zone" (only the zone is known), "taken"
-- (a ride you took, from the spot you left).
M.KIND_NAME = { boat = "Boat", zeppelin = "Zeppelin", skycutter = "Skyship", tram = "Tram", portal = "Portal", lift = "Lift", learned = "Ride" }
function M:Departures()
  local out = {}
  for _, r in ipairs(self:Rides()) do
    local a = r.from
    local where = r.kind == "learned" and "taken" or (a.approx and "zone") or (a.nearFlight and "flight") or "exact"
    local toName = r.kind == "learned" and M.ZoneName(r.to.mapID) or r.to.label or M.ZoneName(r.to.mapID)
    out[#out + 1] = { kind = r.kind, name = (M.KIND_NAME[r.kind] or "Ride") .. " to " .. tostring(toName), from = a, to = r.to,
      where = where, place = a.label, note = r.note, link = r.link }
  end
  return out
end

-- Flight points this character knows, as points.
function M:Flights()
  local out = {}
  local pack = self:Pack()
  for id in pairs(charTaxi()) do
    local n = ns.db.global.taxiNodes[id]
    local t = pack and pack.taxi[id]
    if (not n or not n.wx) and t then
      local p = M.Point(t[3][1], t[3][2], t[3][3], t[1])
      n = p and { cont = p.cont, wx = p.wx, wy = p.wy, mapID = p.mapID, x = p.x, y = p.y, name = t[1] }
    end
    if n and n.wx then
      out[#out + 1] = { taxi = id, cont = n.cont, wx = n.wx, wy = n.wy, mapID = n.mapID, x = n.x, y = n.y, label = n.name }
    end
  end
  return out
end

-- Quickest route. Returns { seconds, steps = { {kind, to = point, text, ride} } } or nil, why.
-- `prepared` (from M:Prepare) lets many targets share one search.
function M:Prepare(from)
  from = from or M.Here()
  if not from then return nil, "your position is unknown here" end
  local nodes, rides = { from }, self:Rides()
  for _, f in ipairs(self:Flights()) do nodes[#nodes + 1] = f end
  for _, r in ipairs(rides) do
    nodes[#nodes + 1] = r.from
    r.from.ride = r.from.ride or {}
    table.insert(r.from.ride, r)
    nodes[#nodes + 1] = r.to
  end
  -- Dijkstra from the start over all nodes
  local best, prev, how, done = { [1] = 0 }, {}, {}, {}
  local index = {}
  for i, n in ipairs(nodes) do index[n] = i end
  while true do
    local u, ud
    for i = 1, #nodes do
      if not done[i] and best[i] and (not ud or best[i] < ud) then u, ud = i, best[i] end
    end
    if not u then break end
    done[u] = true
    local a = nodes[u]
    local function relax(v, cost, kind, ride)
      if not done[v] and (not best[v] or ud + cost < best[v]) then
        best[v], prev[v], how[v] = ud + cost, u, { kind = kind, ride = ride }
      end
    end
    for v = 1, #nodes do
      local b = nodes[v]
      if v ~= u and a.cont and a.cont == b.cont then
        local d = dist(a, b)
        relax(v, d / M.RUN, "walk")
        if a.taxi and b.taxi then
          local legs = self.legs
          if legs and next(legs) then
            -- the real legs only: a flight goes from flight point to flight point
            local sec = legs[a.taxi] and legs[a.taxi][b.taxi]
            if sec then relax(v, sec + ((how[u] and how[u].kind == "fly") and M.HOP or M.FLY_START), "fly") end
          else
            relax(v, M.FLY_START + d / M.FLY, "fly")
          end
        end
      end
    end
    for _, r in ipairs(a.ride or {}) do
      local v = index[r.to]
      if v then relax(v, r.cost, r.kind, r) end
    end
  end
  return { nodes = nodes, best = best, prev = prev, how = how }
end

-- Seconds to reach a point from a prepared search (walk from the best node).
function M:TimeTo(prep, target)
  if not prep or not target then return nil end
  local bestT, via
  for i, n in ipairs(prep.nodes) do
    if prep.best[i] and n.cont and n.cont == target.cont then
      local t = prep.best[i] + dist(n, target) / M.RUN
      if not bestT or t < bestT then bestT, via = t, i end
    end
  end
  return bestT, via
end

local VERB = { boat = "Take the boat", zeppelin = "Take the zeppelin", skycutter = "Take the skycutter",
  tram = "Take the tram", portal = "Take the portal", lift = "Take the lift", learned = "Take the ride you took before" }

function M:Route(target, prep)
  prep = prep or self:Prepare()
  if not prep then return nil, "your position is unknown here" end
  local total, via = self:TimeTo(prep, target)
  if not total then
    return nil, "no known way to " .. M.ZoneName(target.mapID) .. " yet (Outrider learns boats and portals as you use them)"
  end
  local chain = {}
  local i = via
  while i and i ~= 1 do
    table.insert(chain, 1, { node = prep.nodes[i], how = prep.how[i] })
    i = prep.prev[i]
  end
  local steps = {}
  local function step(kind, to, text, ride)
    local last = steps[#steps]
    if (kind == "walk" or kind == "fly") and last and last.kind == kind then last.to, last.text = to, text return end
    steps[#steps + 1] = { kind = kind, to = to, text = text, ride = ride }
  end
  for _, c in ipairs(chain) do
    local n, h = c.node, c.how
    local where = (n.label or M.ZoneName(n.mapID)) .. ", " .. M.ZoneName(n.mapID)
    if h.kind == "walk" then
      step("walk", n, "Go to " .. where .. (n.approx and " (dock spot not known yet)" or "")
        .. (n.nearFlight and " (the dock is by the flight master)" or ""))
    elseif h.kind == "fly" then
      step("fly", n, "Fly to " .. tostring(n.label))
    else
      local r = h.ride
      step(h.kind, n, string.format("%s: %s%s", VERB[h.kind] or "Travel", r.label, r.note and (" (" .. r.note .. ")") or ""), r)
    end
  end
  step("walk", target, "Go to " .. (target.label or "the spot") .. ", " .. M.ZoneName(target.mapID))
  return { seconds = total, steps = steps }
end

function M.Minutes(sec)
  if not sec then return "?" end
  if sec < 90 then return "1 min" end
  return string.format("%d min", math.floor(sec / 60 + 0.5))
end

function M:Activity()
  local n = 0
  for _ in pairs(charTaxi()) do n = n + 1 end
  return string.format("%d flight points known, %d rides learned", n, #ns.db.global.travelLinks)
end

-- Intelligence/Pathfinder.lua  (OI04-13: measured routes)
-- Travel's estimates, corrected by how long your own walking trips really
-- took (TravelTimes walking samples, OI03-05): the same route (start map >
-- destination map) when you've walked it MIN_ROUTE times, else your walking
-- in general (MIN_ALL trips), else Travel's plain estimate. Only samples from
-- the current game build count (a patch can move roads). Every estimate says
-- where it came from (source, sample count, build).
-- Straight lines aren't roads: Travel's last leg is a straight run from the
-- nearest known point; when that leg is long (STRAIGHT_WARN seconds) and the
-- route hasn't been walked, the estimate is marked "straight line: no known
-- road". No known way stays unknown (never a straight line across water or
-- continents). Slow mode (a setting: walking without a mount, or as a ghost)
-- multiplies by SLOW. Nothing here moves you or sets a waypoint.
-- Travel:TimeTo is wrapped once at login; the original stays as TimeToRaw,
-- which TravelTimes uses for its planned estimate (so the measurement never
-- measures itself).

local _, ns = ...
local C = ns.Compat
local PF = { MIN_ROUTE = 3, MIN_ALL = 5, STRAIGHT_WARN = 120, SLOW = 1.6 }
ns.Pathfinder = PF

local function median(t)
  table.sort(t)
  local n = #t
  if n == 0 then return nil end
  return n % 2 == 1 and t[(n + 1) / 2] or (t[n / 2] + t[n / 2 + 1]) / 2
end

-- the correction factor for a route: factor, source, samples
function PF.Factor(fromMap, toMap, trips, build)
  local route, all = {}, {}
  for _, t in ipairs(trips or {}) do
    if t.walking and t.seconds and t.estimate and t.estimate > 0 and (build == nil or t.build == build) then
      local r = t.seconds / t.estimate
      all[#all + 1] = r
      if t.fromMap == fromMap and t.toMap == toMap then route[#route + 1] = r end
    end
  end
  if #route >= PF.MIN_ROUTE then return median(route), "your trips on this route", #route end
  if #all >= PF.MIN_ALL then return median(all), "your walking in general", #all end
  return 1, "Travel's estimate", 0
end

-- adjust one raw estimate: { seconds, raw, source, samples, build, straightLine, note }
function PF.Estimate(raw, opts)
  if not raw then return nil end
  opts = opts or {}
  local f, source, n = PF.Factor(opts.fromMap, opts.toMap, opts.trips, opts.build)
  local out = { raw = raw, source = source, samples = n, build = opts.build }
  local s = raw * f
  if opts.slow then s = s * PF.SLOW out.slow = true end
  out.seconds = math.floor(s + 0.5)
  if (opts.lastLeg or 0) > PF.STRAIGHT_WARN and source ~= "your trips on this route" then
    out.straightLine = true
    out.note = "straight line: no known road, it may take longer"
  end
  return out
end

-- how far your real trips were from the plan: { trips, medianRatio }
function PF.Deviation(trips, build)
  local r = {}
  for _, t in ipairs(trips or {}) do
    if t.walking and t.seconds and t.estimate and t.estimate > 0 and (build == nil or t.build == build) then r[#r + 1] = t.seconds / t.estimate end
  end
  return { trips = #r, medianRatio = median(r) }
end

function PF.Settings()
  local c = ns.db.char
  c.pathfinder = ns.KeepTable(c.pathfinder, "Pathfinder:char.pathfinder") or {}
  return c.pathfinder
end

function PF.Install()
  local T = ns.Travel
  if not (T and T.TimeTo) or T.TimeToRaw then return false end
  local raw = T.TimeTo
  T.TimeToRaw = raw
  T.TimeTo = function(self, prep, target)
    local secs, via = raw(self, prep, target)
    if not secs then return nil end
    local O = ns.Outcomes
    local trips = O and O.Store and O:Store().travel or {}
    local _, gameBuild = C.Call("GetBuildInfo")
    local lastLeg = via and prep and prep.best and prep.best[via] and (secs - prep.best[via]) or nil
    local est = PF.Estimate(secs, { fromMap = tonumber(C.Readable(C.PlayerPosition("player"))), toMap = target and target.mapID,
      trips = trips, build = C.Readable(gameBuild), lastLeg = lastLeg, slow = PF.Settings().slow })
    return est.seconds, via, est
  end
  return true
end

ns.Events:On("PLAYER_LOGIN", "Pathfinder", function() PF.Install() end)

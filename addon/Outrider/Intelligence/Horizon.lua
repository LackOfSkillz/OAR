-- Intelligence/Horizon.lua  (OI04-01)
-- The session you plan for: how long you have, solo or with a group, and how
-- you want to stop. Saved with the planner's settings (horizon = {...}); no
-- language model or provider involved.
--   minutes   15, 30, 60, 120, or a custom 5..480; nil = no time limit
--   group     "solo" (steps that need a group are left out, and so is anything
--             that needs them first), "group", or "either"
--   stopRest  end the session at a safe rest point (an inn or a city) when there
--             is time (used by the session ending, OI04-03)
-- Goals and the gold reserve stay where they are (NexusGoals, OI02-R07).
-- Migration: with no horizon saved yet, the time you last set elsewhere is
-- copied in (the Ask snapshot's minutes, or a Radar budget you changed); the
-- old settings stay as they are.
-- Review OI-FR05 (2026-11-25): the saved minutes/group/stopRest are your
-- preference; startedAt is the running session clock. A clock starts when you
-- set a time, when a migrated time has none, when you press Start a new
-- session (H.StartNew), and at login once the last session's time has run
-- out (a /reload keeps the clock). Choosing the same length again during a
-- running session keeps it; after it ran out, a new one starts. A clock set
-- in the future is ignored.

local _, ns = ...
local H = { PRESETS = { 15, 30, 60, 120 }, MIN = 5, MAX = 480, GROUP = { solo = true, group = true, either = true } }
ns.NexusHorizon = H

-- check one input set; returns a clean copy, or nil and why
function H.Validate(input)
  if type(input) ~= "table" then return nil, "not a table" end
  local out = { group = input.group or "either", stopRest = input.stopRest == true or nil }
  if not H.GROUP[out.group] then return nil, "group must be solo, group or either" end
  if input.minutes ~= nil then
    local m = tonumber(input.minutes)
    if not m or m ~= m or m ~= math.floor(m) then return nil, "minutes must be a whole number" end
    if m < H.MIN or m > H.MAX then return nil, string.format("minutes must be %d to %d", H.MIN, H.MAX) end
    out.minutes = m
    local at = tonumber(input.startedAt)
    if at and at > time() + 60 then at = nil end
    out.startedAt = at
  end
  return out
end

-- the saved horizon (migrated and checked once); planner = NexusCore
function H.Get(planner)
  local s = planner:Settings()
  if type(s.horizon) ~= "table" then
    local mins = tonumber(ns.db.char.askMinutes)
    local radar = ns.Modules:Get("OpportunityRadar")
    local rb = radar and tonumber(radar:Settings().timeBudget)
    if not mins and rb and rb ~= 45 then mins = rb end
    if mins then mins = math.max(H.MIN, math.min(H.MAX, math.floor(mins))) end
    s.horizon = { minutes = mins, group = "either", migrated = mins and true or nil }
  end
  -- a time limit always has a clock (a migrated one had none: OI-FR05)
  if type(s.horizon) == "table" and s.horizon.minutes and not tonumber(s.horizon.startedAt) then s.horizon.startedAt = time() end
  local ok = H.Validate(s.horizon)
  if not ok then
    -- a damaged saved value is kept aside (owner rule) and the default used
    ns.KeepBad(s.horizon, "Horizon:settings.horizon")
    s.horizon = { group = "either" }
    ok = s.horizon
  end
  return ok
end

function H.Set(planner, input)
  local clean, why = H.Validate(input)
  if not clean then return false, why end
  -- the session clock starts when you set a time (OI04-03)
  local old = type(planner:Settings().horizon) == "table" and planner:Settings().horizon or {}
  if clean.minutes and (old.minutes ~= clean.minutes or not old.startedAt or H.Over(old)) then clean.startedAt = time()
  elseif clean.minutes then clean.startedAt = old.startedAt end
  planner:Settings().horizon = clean
  return true
end

-- has this horizon's session clock run out?
function H.Over(h, now)
  if type(h) ~= "table" or not h.minutes or not tonumber(h.startedAt) then return false end
  return (now or time()) - h.startedAt >= h.minutes * 60
end

-- Start a new session: same length, a fresh clock
function H.StartNew(planner, now)
  local h = H.Get(planner)
  if not h.minutes then return false, "no time limit set" end
  local s = planner:Settings()
  s.horizon.startedAt = now or time()
  return true
end

-- at login: a session whose time ran out while you were away is over, so the
-- clock starts again; a quick relog or a /reload keeps it
function H.OnLogin(planner, now)
  local h = H.Get(planner)
  if h.minutes and H.Over(h, now) then return H.StartNew(planner, now) end
  return false
end

-- what the planner context gets from it
function H.Context(planner)
  local h = H.Get(planner)
  -- the time left, minus the closing reserve (Intelligence/SessionEnd.lua)
  local SE = ns.SessionEnd
  local p = SE and SE.Plan(h) or {}
  local budget = h.minutes and (p.budget or h.minutes * 60) or nil
  return { budgetSeconds = p.closing and p.left or budget, solo = h.group == "solo" or nil,
    group = h.group, stopRest = h.stopRest, closing = p.closing or nil, sessionLeft = p.left, reserve = p.reserve, horizon = h }
end

-- steps that need a group (dungeons, dungeon quests)
function H.NeedsGroup(c)
  if type(c) ~= "table" then return false end
  return c.kind == "dungeon" or tostring(c.key or ""):find("^dq:") ~= nil or c.needsGroup == true
end

function H.Label(h)
  local t = h.minutes and (h.minutes >= 60 and (h.minutes % 60 == 0 and (h.minutes / 60 .. " h") or (h.minutes .. " min")) or (h.minutes .. " min")) or "no time limit"
  return string.format("%s, %s%s", t, h.group == "solo" and "solo" or h.group == "group" and "with a group" or "solo or group",
    h.stopRest and ", end at a rest point" or "")
end

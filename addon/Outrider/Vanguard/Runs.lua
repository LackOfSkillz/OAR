-- Vanguard/Runs.lua
-- VG05-01/02/03/04: what happened in your dungeon and raid runs, saved as
-- anonymous run records (spec section 7, RunRecord and Attempt).
--
-- Contract, version 1:
--   RunRecord { v, runId, instance, difficulty, size?, build, startedAt, endedAt?,
--     outcome = completed | incomplete | abandoned | unknown, censorReason?,
--     features = { members, tank, healer, damage, unknownRole, classes = {CLASS = n},
--                  levelMin, levelMax }, coverage?, assessment = { low, high,
--                  coverage, gate, key }?, attempts = { Attempt }, rosterChanges,
--     bosses (in the data), kills, revision }
--   Attempt { id, encounterId, name, start, ["end"], result = kill | wipe | unknown }
-- Rules:
--   * No names or GUIDs of anyone: only counts and classes (D27).
--   * Outcomes come from the game's own events: ENCOUNTER_START/END (kill
--     when the game says success, wipe when it says not), entering and
--     leaving the instance. No combat log. A reload or disconnect mid-fight
--     leaves that attempt "unknown"; it is never counted as a wipe.
--   * "completed" only when every boss in the installed data was killed
--     (with at least one boss listed); a boss kill alone is not a full clear.
--     Left with kills: incomplete. Left with none: abandoned. A run we lost
--     track of (reload, logout, crash): unknown, with the reason.
--   * Back inside within REJOIN seconds is the same run; a repeated end
--     event for the same attempt is ignored.
--   * The readiness assessment is copied into the run when it starts (before
--     the outcome), and the outcome never changes it (VG05-05).
--   * Saved per character; when the active list passes CAP, the oldest runs
--     move to the Archive (Core/Archive.lua), never deleted.

local _, ns = ...
ns.Vanguard = ns.Vanguard or {}
local V = ns.Vanguard
local R = { VERSION = 1, REJOIN = 600, CAP = 200, DUP = 5 }
V.Runs = R

function R.Store()
  local c = ns.db and ns.db.char
  if not c then return nil end
  local s = c.vanguardRuns
  if type(s) ~= "table" then
    if s ~= nil and ns.Archive then ns.Archive:KeepDamaged("char.vanguardRuns", s) end
    s = { v = R.VERSION, runs = {}, seq = 0 }
    c.vanguardRuns = s
  end
  if type(s.runs) ~= "table" then
    if s.runs ~= nil and ns.Archive then ns.Archive:KeepDamaged("char.vanguardRuns.runs", s.runs) end
    s.runs = {}
  end
  if type(s.v) ~= "number" then s.v = R.VERSION end
  if s.v > R.VERSION then return nil, "saved runs are from a newer Outrider" end
  return s
end

-- aggregate features of the group, no identities
function R.Features(snap, roleOf)
  local f = { members = 0, tank = 0, healer = 0, damage = 0, unknownRole = 0, classes = {} }
  for _, m in ipairs(snap and snap.members or {}) do
    f.members = f.members + 1
    local r = roleOf and roleOf(m)
    r = r and r.value
    if r == "TANK" then f.tank = f.tank + 1 elseif r == "HEALER" then f.healer = f.healer + 1
    elseif r == "DAMAGER" then f.damage = f.damage + 1 else f.unknownRole = f.unknownRole + 1 end
    local c = V.Obs.Value(m.class)
    if type(c) == "string" and V.Roles.BY_CLASS[c] then f.classes[c] = (f.classes[c] or 0) + 1 end
    local l = V.Obs.Num(m.level)
    if l then f.levelMin = math.min(f.levelMin or l, l) f.levelMax = math.max(f.levelMax or l, l) end
  end
  return f
end

local function build() local b = ns.Build and ns.Build.id or nil return type(b) == "string" and b:sub(1, 40) or "?" end

-- start or continue a run in `instance`
function R.Enter(store, instance, info, t)
  local open = store.open
  if open and open.instance == instance and (not open.left or t - open.left < R.REJOIN) then
    open.left = nil
    return open, "continued"
  end
  if open then R.Close(store, open.left and "left" or "switched", t) end
  store.seq = (store.seq or 0) + 1
  local run = { v = R.VERSION, runId = string.format("%s:%d:%d", tostring(instance):sub(1, 40), math.floor(t), store.seq),
    instance = tostring(instance):sub(1, 60), difficulty = info and info.difficulty or "normal", size = info and info.size,
    build = build(), startedAt = t, attempts = {}, rosterChanges = 0, kills = 0, bosses = info and info.bosses or 0,
    features = info and info.features, assessment = info and info.assessment, revision = 1 }
  store.open = run
  return run, "started"
end

function R.Left(store, t)
  local run = store.open
  if run and not run.left then run.left = t end
  return run
end

local function openAttempt(run)
  for i = #run.attempts, 1, -1 do local a = run.attempts[i] if not a["end"] then return a end end
end

function R.EncounterStart(store, encounterId, name, t)
  local run = store.open
  if not run or run.left then return nil end
  local prev = openAttempt(run)
  if prev then prev.result, prev["end"] = "unknown", t end -- a new pull without an end: the old one is unknown
  local a = { id = #run.attempts + 1, encounterId = tostring(encounterId):sub(1, 20), name = tostring(name or "?"):sub(1, 60), start = t, result = "unknown" }
  run.attempts[#run.attempts + 1] = a
  if #run.attempts > 60 then table.remove(run.attempts, 1) end
  return a
end

function R.EncounterEnd(store, encounterId, name, success, t)
  local run = store.open
  if not run then return nil, "no run" end
  local id = tostring(encounterId):sub(1, 20)
  local last = run.attempts[#run.attempts]
  -- a repeated end for an attempt that already ended
  if last and last.encounterId == id and last["end"] and t - last["end"] <= R.DUP then return nil, "duplicate" end
  local a = openAttempt(run)
  if not a or a.encounterId ~= id then
    a = { id = #run.attempts + 1, encounterId = id, name = tostring(name or "?"):sub(1, 60), result = "unknown" }
    run.attempts[#run.attempts + 1] = a
  end
  a["end"] = t
  if success == 1 or success == true then a.result = "kill" run.kills = run.kills + 1
  elseif success == 0 or success == false then a.result = "wipe"
  else a.result = "unknown" end
  run.revision = run.revision + 1
  return a
end

-- close the open run; why: left | switched | logout | lost
function R.Close(store, why, t)
  local run = store.open
  if not run then return nil end
  store.open = nil
  local a = openAttempt(run)
  if a then a.result, a["end"] = "unknown", t end
  run.endedAt = run.left or t
  run.left = nil
  local distinct = {}
  for _, x in ipairs(run.attempts) do if x.result == "kill" then distinct[x.encounterId] = true end end
  local kills = 0
  for _ in pairs(distinct) do kills = kills + 1 end
  if why == "lost" or why == "logout" then
    run.outcome, run.censorReason = "unknown", why == "lost" and "reload or disconnect: lost track" or "logged out inside"
  elseif run.bosses and run.bosses > 0 and kills >= run.bosses then
    run.outcome = "completed"
  elseif kills > 0 then
    run.outcome = "incomplete"
  else
    run.outcome = "abandoned"
  end
  run.distinctKills = kills
  store.runs[#store.runs + 1] = run
  -- over the cap: the oldest go to the archive (never deleted)
  while #store.runs > R.CAP do
    local ok = ns.Archive and ns.Archive:Shift("vanguardRuns", store.runs, { path = "char.vanguardRuns.runs", scope = "char" })
    if not ok then break end
  end
  return run
end

-- after a reload: an open run from before is continued if we're still in
-- that instance soon after, else closed as unknown
function R.Resume(store, instance, t)
  local run = store.open
  if not run then return nil end
  local last = run.left or (run.attempts[#run.attempts] and (run.attempts[#run.attempts]["end"] or run.attempts[#run.attempts].start)) or run.startedAt
  if instance == run.instance and t - last < R.REJOIN then run.left = nil return run, "continued" end
  return R.Close(store, "lost", t), "closed"
end

-- VG05-04: active and archived runs, newest last; bounded
function R.All(store, opts)
  opts = opts or {}
  local list = store and store.runs or {}
  if ns.Archive then
    return ns.Archive:WithActive("vanguardRuns", list, { where = opts.where, max = opts.max or 2000 })
  end
  return list
end

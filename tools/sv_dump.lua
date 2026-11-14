-- tools/sv_dump.lua
-- Prints what Outrider saved, so Claude Code can read in-game results.
--   lua tools/sv_dump.lua <path to SavedVariables\Outrider.lua> [section] [options]
-- sections: summary (default) | log | errors | probe | chars | snapshots | all
--           bugs  (pass the !BugGrabber.lua file instead; prints errors mentioning Outrider)
-- options:  --mark TEXT   only log lines after the last marker containing TEXT
--           --session ID  only that session (default for log: latest session)
--           --all-sessions
--           --last N      at most N log lines (default 60)
-- The file is loaded in an empty sandbox: SavedVariables are plain assignments.

local path, section = arg[1], arg[2] or "summary"
if not path then
  io.write("usage: lua tools/sv_dump.lua <Outrider.lua> [summary|log|errors|probe|chars|snapshots|all|bugs] [--mark TEXT] [--last N]\n")
  os.exit(2)
end
if section:sub(1, 2) == "--" then section = "summary" end

local opts = { last = 60 }
do
  local i = 2
  while arg[i] do
    local a = arg[i]
    if a == "--mark" then opts.mark = arg[i + 1] i = i + 1
    elseif a == "--session" then opts.session = arg[i + 1] i = i + 1
    elseif a == "--last" then opts.last = tonumber(arg[i + 1]) or opts.last i = i + 1
    elseif a == "--all-sessions" then opts.allSessions = true end
    i = i + 1
  end
end

local env = {}
local chunk, err = loadfile(path)
if not chunk then io.write("cannot load ", tostring(path), ": ", tostring(err), "\n") os.exit(1) end
setfenv(chunk, env)
local ok, runErr = pcall(chunk)
if not ok then io.write("SavedVariables file did not run: ", tostring(runErr), "\n") os.exit(1) end

local out = io.write
local LEVELS = { "ERROR", "WARN ", "INFO ", "DEBUG" }

local function stamp(t)
  if type(t) ~= "number" then return "?" end
  return os.date("%Y-%m-%d %H:%M:%S", t)
end

local function sortedKeys(t)
  local keys = {}
  for k in pairs(t or {}) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  return keys
end

-- ------------------------------------------------------------------ bugs
if section == "bugs" then
  local db = env.BugGrabberDB
  if type(db) ~= "table" or type(db.errors) ~= "table" then out("no BugGrabberDB.errors in this file\n") os.exit(0) end
  local n = 0
  for i = #db.errors, 1, -1 do
    local e = db.errors[i]
    local text = tostring(e.message or "") .. "\n" .. tostring(e.stack or "")
    if text:find("Outrider", 1, true) then
      n = n + 1
      out(string.format("[%s] x%s session %s\n%s\n%s\n\n", tostring(e.time), tostring(e.counter or 1),
        tostring(e.session), tostring(e.message), tostring(e.stack or "")))
      if n >= 15 then break end
    end
  end
  if n == 0 then out("no BugGrabber errors mention Outrider\n") end
  os.exit(0)
end

local DB, LOG = env.Outrider_DB, env.Outrider_Log
if type(DB) ~= "table" then out("Outrider_DB not found in this file (has the addon run and has Gary typed /reload?)\n") end
local global = type(DB) == "table" and DB.global or {}
local lines = type(LOG) == "table" and LOG.lines or {}

local function latestSession()
  for i = #lines, 1, -1 do
    if lines[i].s and lines[i].s ~= "boot" then return lines[i].s end
  end
end

local function printSummary()
  out("== summary\n")
  out(string.format("schema %s | loads %s | debug %s\n", tostring(DB and DB.schema), tostring(global.loads), tostring(global.debug)))
  local ls = global.lastSave
  if ls then out(string.format("last save %s by %s (session %s, build %s)\n", stamp(ls.t), tostring(ls.char), tostring(ls.session), tostring(ls.build))) end
  out("recent sessions:\n")
  local sessions = global.sessions or {}
  for i = math.max(1, #sessions - 5), #sessions do
    local s = sessions[i]
    out(string.format("  %s  %s  %s  v%s build %s\n", stamp(s.t), tostring(s.id), tostring(s.char), tostring(s.version), tostring(s.build)))
  end
  local errs = type(LOG) == "table" and LOG.errors or {}
  out(string.format("errors saved: %d | log lines: %d\n", #errs, #lines))
  if global.probe then
    local p = global.probe
    out(string.format("probe: %s build %s interface %s, %d present, %d missing\n", stamp(p.at),
      tostring(p.build and p.build.build), tostring(p.build and p.build.interface),
      p.summary and p.summary.present or 0, p.summary and p.summary.missing or 0))
  else
    out("probe: none yet\n")
  end
end

local function printLog()
  local from, session = 1, opts.session
  if opts.mark then
    for i = #lines, 1, -1 do
      if lines[i].m == "MARK" and tostring(lines[i].x):find(opts.mark, 1, true) then from = i break end
    end
  elseif not opts.allSessions then
    session = session or latestSession()
  end
  local picked = {}
  for i = from, #lines do
    local l = lines[i]
    if opts.mark or opts.allSessions or not session or l.s == session then picked[#picked + 1] = l end
  end
  out(string.format("== log (%s, %d lines)\n", opts.mark and ("after mark '" .. opts.mark .. "'") or
    (opts.allSessions and "all sessions" or ("session " .. tostring(session))), #picked))
  for i = math.max(1, #picked - opts.last + 1), #picked do
    local l = picked[i]
    out(string.format("%s %s [%s] %s\n", os.date("%H:%M:%S", l.t or 0), LEVELS[l.l] or "?", tostring(l.m), tostring(l.x)))
  end
end

local function printErrors()
  local errs = type(LOG) == "table" and LOG.errors or {}
  out(string.format("== errors (%d)\n", #errs))
  for i = #errs, math.max(1, #errs - 19), -1 do
    local e = errs[i]
    out(string.format("x%d %s (last %s, session %s)\n  %s\n", e.count or 1, tostring(e.where), stamp(e.last), tostring(e.session), tostring(e.msg)))
    if e.trace and e.trace ~= "" then out("  ", tostring(e.trace):gsub("\n", "\n  "), "\n") end
  end
end

local function printProbe()
  local p = global.probe
  if not p then out("== probe\nnone yet: Gary types /ride probe then /reload\n") return end
  out(string.format("== probe %s\n", stamp(p.at)))
  for _, k in ipairs(sortedKeys(p.build)) do out(string.format("build.%s = %s\n", k, tostring(p.build[k]))) end
  for _, k in ipairs(sortedKeys(p.constants)) do out(string.format("const %s = %s\n", k, tostring(p.constants[k]))) end
  out("missing APIs:\n")
  for _, k in ipairs(sortedKeys(p.apis)) do if not p.apis[k] then out("  - ", k, "\n") end end
  out("present APIs:\n")
  for _, k in ipairs(sortedKeys(p.apis)) do if p.apis[k] then out("  + ", k, "\n") end end
  out("events:\n")
  for _, k in ipairs(sortedKeys(p.events)) do
    local v = p.events[k]
    out(string.format("  %s %s%s\n", v == true and "+" or "-", k, v == true and "" or ("  (" .. tostring(v) .. ")")))
  end
  local em = p.editMode
  if type(em) == "table" then
    out(string.format("edit mode: manager %s, active layout %s\n", tostring(em.manager), tostring(em.activeLayout)))
    for _, k in ipairs(sortedKeys(em.api or {})) do out(string.format("  api %s %s\n", em.api[k] and "+" or "-", k)) end
    for i, l in ipairs(em.layouts or {}) do out(string.format("  layout %d: %s (type %s)\n", i, tostring(l.name), tostring(l.type))) end
    out("  system frames: ", table.concat(em.systems or {}, ", "), "\n")
    for _, k in ipairs(sortedKeys(em.frames or {})) do out(string.format("  frame %s: %s\n", k, tostring(em.frames[k]))) end
  end
  local runs = global.probeUnits or { p.units }
  for i, units in ipairs(runs) do
    out(string.format("units, run %d of %d (%s, in combat: %s):\n", i, #runs, stamp(units.at), tostring(units.inCombat)))
    for _, k in ipairs(sortedKeys(units)) do
      local u = units[k]
      if type(u) == "table" then
        local parts = {}
        for _, f in ipairs(sortedKeys(u)) do parts[#parts + 1] = f .. "=" .. tostring(u[f]) end
        out("  ", k, ": ", table.concat(parts, " "), "\n")
      elseif k ~= "at" and k ~= "inCombat" then
        out("  ", k, ": ", tostring(u), "\n")
      end
    end
  end
end

local function printChars()
  out("== characters\n")
  local chars = type(DB) == "table" and DB.chars or {}
  for _, key in ipairs(sortedKeys(chars)) do
    local c = chars[key]
    local m = c.meta or {}
    local on, off = {}, {}
    for _, name in ipairs(sortedKeys(c.modules)) do
      local st = c.modules[name].enabled
      if st == true then on[#on + 1] = name elseif st == false then off[#off + 1] = name end
    end
    out(string.format("%s  %s %s lvl %s  logins %s  last %s\n", key, tostring(m.race), tostring(m.class), tostring(m.level),
      tostring(m.logins), stamp(m.lastLogin)))
    if #on > 0 then out("  forced on: ", table.concat(on, ", "), "\n") end
    if #off > 0 then out("  switched off: ", table.concat(off, ", "), "\n") end
  end
end

local function printSnapshots()
  local snaps = env.Outrider_Snapshots
  out("== snapshots\n")
  if type(snaps) ~= "table" then out("none\n") return end
  for _, key in ipairs(sortedKeys(snaps)) do
    local s = snaps[key]
    out(string.format("%s  taken %s  level %s %s  map %s\n", key, stamp(s.takenAt), tostring(s.level), tostring(s.class),
      tostring(s.where and s.where.mapID)))
  end
end

if section == "summary" then printSummary() printErrors() printLog()
elseif section == "log" then printLog()
elseif section == "errors" then printErrors()
elseif section == "probe" then printProbe()
elseif section == "chars" then printChars()
elseif section == "snapshots" then printSnapshots()
elseif section == "all" then printSummary() printChars() printErrors() printProbe() printSnapshots() printLog()
else out("unknown section ", section, "\n") os.exit(2) end

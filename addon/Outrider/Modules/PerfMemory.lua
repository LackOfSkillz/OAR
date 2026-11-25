-- Modules/PerfMemory.lua  (Gary, 2026-11-25: "we need to know which modules
-- are using what memory"; Outrider measured 35-60 MB against a 3 MB budget)
--
-- The game reports memory per add-on, not per module, so this ESTIMATES it:
-- it walks Outrider's own tables (saved data first, then each module, then
-- the rest of the namespace) and sizes every table and string it reaches,
-- each one once (the first part to reach a table owns it). Sizes use Lua 5.1
-- costs (a table 40 bytes, 16 per array slot, 40 per hash slot, a string
-- 24 + its length) and are labelled estimates. Code, frames and textures
-- aren't tables Outrider can walk: they are the rest of the game's figure.
--
-- Cost: the walk runs in small slices (STEP_MS of work, then it waits for
-- the next frame), never in combat (it pauses), once per session SETTLE_S
-- after login, and when the Performance page asks. Each result is saved
-- (global.perfMemory; past KEEP the oldest go to the archive) and logged.
-- Also lists every loaded add-on's memory, the comparison that matters.

local ADDON, ns = ...
local C = ns.Compat
local M = ns:NewModule("PerfMemory", {
  title = "Memory by part (estimate)",
  phase = "P8",
  order = 94,
  defaults = {},
})
ns.PerfMemory = M

M.STEP_MS = 3
M.SETTLE_S = 120
M.AGAIN_S = 900          -- and every 15 minutes after, to see which part grows
M.KEEP = 20
M.TABLE, M.ARRAY, M.HASH, M.STRING = 40, 16, 40, 24

-- Scheduled on the game's own engine timer (like the always-on watch), so a
-- measurement waiting to start or between slices is never Outrider's pending
-- work and never keeps a per-frame script alive.
local function later(delay, fn, label)
  local CT = rawget(_G, "C_Timer")
  if CT and type(CT.After) == "function" then
    CT.After(delay, function() ns.Safe(label, fn) end)
  else
    ns.Timer.After(delay, fn, label)
  end
end

function M:OnEnable()
  self:On("PLAYER_ENTERING_WORLD", function(mod)
    if mod.autoDone then return end
    mod.autoDone = true
    -- the automatic run needs the engine timer; without it, only the button measures
    local CT = rawget(_G, "C_Timer")
    if CT and type(CT.After) == "function" then
      later(M.SETTLE_S, function() if M.enabled then M:Start("auto") end end, "perfmemory:auto")
    end
  end)
end
function M:OnDisable() self.job = nil end

function M:Running() return self.job ~= nil end
function M:Latest()
  local list = ns.db.global.perfMemory
  return type(list) == "table" and list[#list] or nil
end

-- size of one table by itself (not what it points to)
local function own(t)
  local n, arr = 0, #t
  for _ in pairs(t) do n = n + 1 end
  return M.TABLE + arr * M.ARRAY + math.max(0, n - arr) * M.HASH
end

-- the roots, in the order they claim tables: saved data, modules, the rest
function M.Roots()
  local roots = {}
  local g = ns.db and ns.db.global or {}
  local keys = {}
  for k in pairs(g) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  for _, k in ipairs(keys) do
    if type(g[k]) == "table" then roots[#roots + 1] = { "saved: " .. tostring(k), g[k], "saved" } end
  end
  local raw = ns.db and ns.db.raw
  if raw and type(raw.chars) == "table" then roots[#roots + 1] = { "saved: characters", raw.chars, "saved" } end
  for _, name in ipairs({ "Outrider_Log", "Outrider_Snapshots" }) do
    local t = rawget(_G, name)
    if type(t) == "table" then roots[#roots + 1] = { "saved: " .. name, t, "saved" } end
  end
  for _, m in ipairs(ns.Modules.list) do roots[#roots + 1] = { m.name, m, "module" } end
  local rest = {}
  for k, v in pairs(ns) do if type(v) == "table" then rest[#rest + 1] = k end end
  table.sort(rest, function(a, b) return tostring(a) < tostring(b) end)
  for _, k in ipairs(rest) do roots[#roots + 1] = { "ns." .. tostring(k), ns[k], "core" } end
  return roots
end

-- The walk, as a coroutine that yields when its time slice is used up.
function M.Walk(clock, budgetMs)
  local seen = { [ns] = true, [_G] = true }
  local out = {}
  local t0 = clock()
  local bytes = 0
  -- true when x is a table still to walk; strings are counted here, once each.
  -- Another add-on's or the game's named frame is not ours: not walked.
  local function visit(x)
    local tx = type(x)
    if tx == "string" then
      if not seen[x] then seen[x] = true bytes = bytes + M.STRING + #x end
      return false
    end
    if tx ~= "table" or seen[x] then return false end
    if type(rawget(x, 0)) == "userdata" and type(x.GetName) == "function" then
      local ok, nm = pcall(x.GetName, x)
      if ok and type(nm) == "string" and not nm:find("^Outrider") then seen[x] = true return false end
    end
    return true
  end
  for _, r in ipairs(M.Roots()) do
    local name, root, kind = r[1], r[2], r[3]
    bytes = 0
    local stack = { root }
    if seen[root] then stack = {} end
    while #stack > 0 do
      local t = table.remove(stack)
      if not seen[t] then
        seen[t] = true
        bytes = bytes + own(t)
        for k, v in pairs(t) do
          if visit(k) then stack[#stack + 1] = k end
          if visit(v) then stack[#stack + 1] = v end
        end
        if budgetMs and clock() - t0 >= budgetMs then
          coroutine.yield()
          t0 = clock()
        end
      end
    end
    out[#out + 1] = { name = name, kind = kind, kb = bytes / 1024 }
  end
  return out
end

function M:Start(why)
  if self.job then return false, "already measuring" end
  local clock = rawget(_G, "debugprofilestop")
  if not clock then return false, "no clock on this client" end
  local co = coroutine.create(function() return M.Walk(clock, M.STEP_MS) end)
  self.job = { co = co, why = why, started = C.Call("GetTime") or 0 }
  local function step()
    local job = M.job
    if not job then return end
    -- never adds work to a fight: wait it out
    if C.Readable(C.Call("InCombatLockdown")) == true then later(1, step, "perfmemory:combat") return end
    local ok, res = coroutine.resume(job.co)
    if not ok then
      M.job = nil
      M:Warn("memory estimate stopped: %s", tostring(res))
      return
    end
    if coroutine.status(job.co) == "dead" then M:Finish(res) return end
    later(0.01, step, "perfmemory:step")
  end
  step()
  return true
end

-- every loaded add-on's memory (the game's own figure)
function M.AddOns()
  local A = rawget(_G, "C_AddOns") or {}
  local get = A.GetAddOnMemoryUsage or rawget(_G, "GetAddOnMemoryUsage")
  local update = A.UpdateAddOnMemoryUsage or rawget(_G, "UpdateAddOnMemoryUsage")
  local count = A.GetNumAddOns or rawget(_G, "GetNumAddOns")
  local info = A.GetAddOnInfo or rawget(_G, "GetAddOnInfo")
  local loaded = A.IsAddOnLoaded or rawget(_G, "IsAddOnLoaded")
  if not (get and count and info) then return {} end
  if update then pcall(update) end
  local out = {}
  local ok, n = pcall(count)
  for i = 1, ok and tonumber(n) or 0 do
    local okn, name = pcall(info, i)
    if okn and name and (not loaded or select(2, pcall(loaded, name)) == true) then
      local okm, kb = pcall(get, name)
      if okm and type(kb) == "number" and kb > 0 then out[#out + 1] = { name = name, kb = kb } end
    end
  end
  table.sort(out, function(a, b) return a.kb > b.kb end)
  return out
end

function M:Finish(parts)
  local job = self.job
  self.job = nil
  table.sort(parts, function(a, b) return a.kb > b.kb end)
  local measured, saved = 0, 0
  for _, p in ipairs(parts) do
    measured = measured + p.kb
    if p.kind == "saved" then saved = saved + p.kb end
  end
  local addons = M.AddOns()
  local total
  for _, a in ipairs(addons) do if a.name == ADDON then total = a.kb end end
  local keep = {}
  for i = 1, math.min(40, #parts) do keep[i] = { name = parts[i].name, kind = parts[i].kind, kb = math.floor(parts[i].kb + 0.5) } end
  local top = {}
  for i = 1, math.min(15, #addons) do top[i] = { name = addons[i].name, kb = math.floor(addons[i].kb + 0.5) } end
  local row = { at = time(), build = ns.build, why = job and job.why, session = ns.session, totalKB = total, measuredKB = measured, savedKB = saved,
    parts = keep, addons = top, secs = job and ((C.Call("GetTime") or 0) - job.started) or nil }
  local g = ns.db.global
  g.perfMemory = ns.KeepTable(g.perfMemory, "PerfMemory:g.perfMemory") or {}
  local list = g.perfMemory
  list[#list + 1] = row
  while #list > M.KEEP and ns.Archive:Shift("perfMemory", list, { path = "global.perfMemory", scope = "account" }) do end
  -- what grew since the last estimate this session (a part that keeps growing
  -- is a cache without a limit, or a leak)
  local prev = list[#list - 1]
  if prev and prev.session == ns.session then
    local before = {}
    for _, p in ipairs(prev.parts or {}) do before[p.name] = p.kb end
    local grew = {}
    for _, p in ipairs(keep) do
      local d = p.kb - (before[p.name] or 0)
      if d >= 256 then grew[#grew + 1] = { name = p.name, kb = d } end
    end
    table.sort(grew, function(a, b) return a.kb > b.kb end)
    local g = {}
    for i = 1, math.min(8, #grew) do g[i] = string.format("%s +%.1f MB", grew[i].name, grew[i].kb / 1024) end
    row.grew = grew
    self:Info("memory grew since %s: game %+.1f MB, tables %+.1f MB; %s", date("%H:%M", prev.at),
      ((total or 0) - (prev.totalKB or 0)) / 1024, (measured - (prev.measuredKB or 0)) / 1024,
      #g > 0 and table.concat(g, ", ") or "no part grew by 0.25 MB or more")
  end
  local names = {}
  for i = 1, math.min(10, #keep) do names[#names + 1] = string.format("%s %.1f MB", keep[i].name, keep[i].kb / 1024) end
  self:Info("memory estimate (%s): game says %s, tables found %.1f MB (saved data %.1f MB); biggest: %s",
    tostring(row.why), total and string.format("%.1f MB", total / 1024) or "?", measured / 1024, saved / 1024, table.concat(names, ", "))
  ns.Events:Fire("OTR_PERFMEMORY", "done")
  -- the automatic runs repeat, so a part that keeps growing shows up
  if row.why == "auto" then
    local CT = rawget(_G, "C_Timer")
    if CT and type(CT.After) == "function" then
      later(M.AGAIN_S, function() if M.enabled then M:Start("auto") end end, "perfmemory:again")
    end
  end
  return row
end

function M:Activity()
  if self.job then return "measuring memory by part..." end
  local r = self:Latest()
  if not r then return "measures memory by part 2 minutes after login" end
  return string.format("last estimate: %.1f MB in tables, %.1f MB of it saved data", (r.measuredKB or 0) / 1024, (r.savedKB or 0) / 1024)
end

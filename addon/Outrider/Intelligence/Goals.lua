-- Intelligence/Goals.lua  (OI02-05)
-- The player's goals for the Nexus: several at once, each a v4 Goal record
-- (Intelligence/Contracts.lua): level, gold, gear, professions, explore or mix,
-- a priority (1 highest .. 5), an optional target, deadline and gold reserve.
-- Character goals live in ns.db.char.nexusGoals, account goals in
-- ns.db.global.nexusGoals. "Delete" archives the goal (status "archived",
-- owner data preservation override): nothing is removed.
-- Problems are explained, never silently fixed: Check() returns the conflicts
-- and infeasible goals with a reason code and a plain sentence; it changes
-- nothing. With no goals at all, WhatNow's single goal stands in (read only).

local _, ns = ...
local G = {}
ns.NexusGoals = G

G.OBJECTIVES = { level = true, gold = true, gear = true, professions = true, explore = true, mix = true }
G.MAX_LEVEL = 60

function G:Store(scope)
  if not ns.db then return nil end
  local root = scope == "account" and ns.db.global or ns.db.char
  local s = ns.KeepTable(root.nexusGoals, "Goals:nexusGoals") or {}
  root.nexusGoals = s
  s.list = ns.KeepTable(s.list, "Goals:nexusGoals.list") or {}
  s.next = tonumber(s.next) or 0
  return s
end

function G:All()
  local out = {}
  for _, scope in ipairs({ "char", "account" }) do
    local s = self:Store(scope)
    for _, g in ipairs(s and s.list or {}) do out[#out + 1] = g end
  end
  return out
end

function G:Find(id)
  for _, scope in ipairs({ "char", "account" }) do
    local s = self:Store(scope)
    for _, g in ipairs(s and s.list or {}) do if g.goalId == id then return g, s end end
  end
end

-- opts: { scope = "char"|"account", priority, target, deadline, reserveCopper }
function G:Create(objective, opts)
  opts = opts or {}
  if not G.OBJECTIVES[objective] then return nil, "objective" end
  local scope = opts.scope or "char"
  local s = self:Store(scope)
  if not s then return nil, "no saved data" end
  s.next = s.next + 1
  local g = { goalId = string.format("goal:%s:%d", scope == "account" and "a" or "c", s.next), scope = scope,
    objective = objective, priority = opts.priority or 3, status = "active", createdAt = time(),
    target = opts.target, deadline = opts.deadline, reserveCopper = opts.reserveCopper }
  local ok, field = ns.Nexus.Validate("Goal", g)
  if not ok then s.next = s.next - 1 return nil, field end
  s.list[#s.list + 1] = g
  if ns.Events then ns.Events:Fire("OTR_NEXUS_GOALS_CHANGED", g.goalId) end
  return g
end

-- change some fields; the result must still be a valid Goal or nothing changes
function G:Edit(id, fields)
  local g = self:Find(id)
  if not g then return false, "missing" end
  local copy = ns.CopyTable(g)
  for k, v in pairs(fields or {}) do
    if k == "goalId" or k == "scope" or k == "createdAt" then return false, k end
    copy[k] = v
  end
  local ok, field = ns.Nexus.Validate("Goal", copy)
  if not ok then return false, field end
  for k in pairs(g) do g[k] = nil end
  for k, v in pairs(copy) do g[k] = v end
  if ns.Events then ns.Events:Fire("OTR_NEXUS_GOALS_CHANGED", id) end
  return true
end

function G:Pause(id) return self:Edit(id, { status = "paused" }) end
function G:Resume(id) return self:Edit(id, { status = "active" }) end
function G:Complete(id) return self:Edit(id, { status = "done" }) end
-- the player's delete: archived, kept
function G:Delete(id) return self:Edit(id, { status = "archived" }) end

-- active goals, highest priority first, then oldest
function G:Active()
  local out = {}
  for _, g in ipairs(self:All()) do if g.status == "active" then out[#out + 1] = g end end
  table.sort(out, function(a, b)
    if a.priority ~= b.priority then return a.priority < b.priority end
    if a.createdAt ~= b.createdAt then return a.createdAt < b.createdAt end
    return a.goalId < b.goalId
  end)
  if #out == 0 and ns.WhatNow and ns.WhatNow.Goal then
    local ok, w = pcall(ns.WhatNow.Goal, ns.WhatNow)
    if ok and G.OBJECTIVES[w] then
      out[1] = { goalId = "goal:whatnow", scope = "char", objective = w, priority = 3, status = "active", createdAt = 0, implicit = true }
    end
  end
  return out
end

-- Problems with the active goals: { {code, goalId, text} }. Changes nothing.
function G:Check(now, state)
  now = now or time()
  state = state or {}
  local out = {}
  local function add(code, g, text) out[#out + 1] = { code = code, goalId = g.goalId, text = text } end
  local level, copper = tonumber(state.level), tonumber(state.copper)
  local seen = {}
  for _, g in ipairs(self:Active()) do
    if g.deadline and g.deadline < now then add("deadline_passed", g, "Its deadline has passed: keep it, change the date or archive it.") end
    if g.objective == "level" and g.target then
      if g.target > G.MAX_LEVEL then add("target_unreachable", g, "Level " .. g.target .. " is above the level cap (" .. G.MAX_LEVEL .. ").")
      elseif level and g.target <= level then add("already_reached", g, "You are already level " .. level .. ".") end
    end
    if g.objective == "gold" and g.target and copper and g.target <= copper then
      add("already_reached", g, "You already carry that much gold.")
    end
    if g.reserveCopper and copper and g.reserveCopper > copper then
      add("reserve_above_gold", g, "The gold reserve is more than you carry: nothing that costs gold can be suggested until it is lowered.")
    end
    local key = g.scope .. ":" .. g.objective
    if seen[key] then add("duplicate", g, "Another active goal has the same aim; the higher priority one leads.") end
    seen[key] = true
  end
  -- two "most important" goals pulling different ways
  local top = {}
  for _, g in ipairs(self:Active()) do if g.priority == 1 then top[#top + 1] = g end end
  if #top > 1 then
    for i = 2, #top do add("priority_tie", top[i], "More than one goal has the top priority; the older one leads.") end
  end
  return out
end

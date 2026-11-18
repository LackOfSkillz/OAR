-- Modules/LevelRoutes.lua: DEEP-33, original leveling step engine.
-- No paid guide text or paths. Routes may be authored locally or generated
-- from the available Outrider NPC pack. All actions remain player-initiated.
-- Step: {id, kind="quest"|"kill"|"loot"|"place", questID?, npcID?,
--        itemID?, count?, mapID?, x?, y?, name?, level?}
local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("LevelRoutes", {
  title = "Leveling steps", phase = "P3", order = 54,
  defaults = { routes = {}, current = nil, skip = {}, progress = {}, undo = {} },
})
ns.LevelRoutes = M
M.MAX = 500
M.KINDS = { quest = true, kill = true, loot = true, place = true }

function M:Store() return self:Settings() end

function M:Validate(step)
  if type(step) ~= "table" or not M.KINDS[step.kind] then return false end
  if type(step.name) ~= "string" or step.name == "" or #step.name > 150 then return false end
  if step.questID ~= nil and (type(step.questID) ~= "number" or step.questID < 1) then return false end
  if step.count ~= nil and (type(step.count) ~= "number" or step.count < 1 or step.count > 10000) then return false end
  if step.mapID then
    if type(step.mapID) ~= "number" or type(step.x) ~= "number" or type(step.y) ~= "number"
      or step.x < 0 or step.x > 1 or step.y < 0 or step.y > 1 then return false end
  end
  return true
end

function M:Create(name, steps)
  if type(name) ~= "string" or #name < 1 or #name > 80
    or type(steps) ~= "table" or #steps < 1 or #steps > M.MAX then return false end
  local clean = {}
  for i, step in ipairs(steps) do
    if not self:Validate(step) then return false, "invalid step " .. i end
    local copy = {}
    for _, field in ipairs({ "id", "kind", "questID", "npcID", "itemID", "count",
      "mapID", "x", "y", "name", "level" }) do copy[field] = step[field] end
    copy.id = tostring(copy.id or (name .. ":" .. i))
    clean[#clean + 1] = copy
  end
  self:Store().routes[name:lower()] = { name = name, steps = clean, source = "original Outrider" }
  return true
end

-- Generate the first usable Horde 1-20 *candidate* route from known map
-- quest-givers. Not a complete walkthrough: missing and Forever-only quests
-- are excluded, and candidates still require review before parity.
function M:SeedHorde(startLevel)
  if C.Readable(C.Call("UnitFactionGroup", "player")) ~= "Horde" then
    return false, "Horde route only"
  end
  local list = ns.NPCPack and ns.NPCPack:AvailableEverywhere() or {}
  local steps, seen = {}, {}
  local floor = math.max(1, math.min(20, tonumber(startLevel) or 1))
  for _, q in ipairs(list) do
    if #steps >= 200 then break end
    local level = tonumber(q.level)
    local mapID = tonumber(q.mapID)
    if level and level >= floor and level <= 20 and mapID and
      type(q.x) == "number" and type(q.y) == "number" and
      type(q.name) == "string" and not seen[q.name:lower()] and
      q.x >= 0 and q.x <= 1 and q.y >= 0 and q.y <= 1 and
      q.diff ~= "red" and q.diff ~= "grey" then
      seen[q.name:lower()] = true
      steps[#steps + 1] = { id = "quest:" .. q.name:lower(), kind = "quest",
        name = q.name, questID = tonumber(q.questID), level = level,
        mapID = mapID, x = q.x, y = q.y }
    end
  end
  table.sort(steps, function(a, b)
    if a.level ~= b.level then return a.level < b.level end
    if a.mapID ~= b.mapID then return a.mapID < b.mapID end
    return a.name < b.name
  end)
  if #steps == 0 then return false, "no suitable quest-giver data" end
  local name = "Horde 1-20 (data-derived)"
  return self:Create(name, steps), name
end

function M:Start(name)
  local store = self:Store()
  local route = store.routes[tostring(name or ""):lower()]
  if not route then return false, "route unknown" end
  store.current = name:lower()
  store.skip, store.progress, store.undo = {}, {}, {}
  return true, self:Current()
end

function M:Current()
  local s = self:Store()
  local route = s.current and s.routes[s.current]
  if not route then return nil end
  for index, step in ipairs(route.steps) do
    if not s.progress[step.id] and not s.skip[step.id] then return step, index, route end
  end
  return nil, #route.steps + 1, route
end

function M:Mark(step, status)
  local s = self:Store()
  if not step then return false end
  local before = s.progress[step.id] and "done" or s.skip[step.id] and "skipped" or "open"
  s.undo[#s.undo + 1] = { id = step.id, before = before }
  while #s.undo > 40 do table.remove(s.undo, 1) end
  s.progress[step.id] = status == "done" and true or nil
  s.skip[step.id] = status == "skipped" and true or nil
  return true
end

function M:Undo()
  local s = self:Store()
  local change = table.remove(s.undo)
  if not change then return false end
  s.progress[change.id] = change.before == "done" and true or nil
  s.skip[change.id] = change.before == "skipped" and true or nil
  return true
end

function M:OnQuest(_, questID)
  questID = tonumber(C.Readable(questID))
  if not questID then return end
  local step = self:Current()
  if step and step.kind == "quest" and step.questID == questID then self:Mark(step, "done") end
end
function M:OnLoot(_, category, items)
  local step = self:Current()
  if not step or step.kind ~= "loot" or not step.itemID then return end
  for _, item in ipairs(type(items) == "table" and items or {}) do
    if item.id == step.itemID then
      local s = self:Store()
      s.loot = s.loot or {}
      s.loot[step.id] = (s.loot[step.id] or 0) + (tonumber(item.count) or 1)
      if s.loot[step.id] >= (step.count or 1) then self:Mark(step, "done") end
    end
  end
end
function M:OnKill()
  -- A kill is credited only from the player's own quest objective updates,
  -- not COMBAT_LOG_EVENT_UNFILTERED (unsafe on Forever). An ordinary mob
  -- kill without a quest objective cannot be confirmed and stays manual.
  local step = self:Current()
  if not step or step.kind ~= "kill" or not step.questID then return false end
  local f = C.Resolve("C_QuestLog.GetQuestObjectives")
  if type(f) ~= "function" then return false end
  local ok, list = pcall(f, step.questID)
  if not ok or type(list) ~= "table" then return false end
  for _, objective in ipairs(list) do
    local name = C.Readable(objective.text)
    local finished = C.Readable(objective.finished)
    if type(name) == "string" and name:lower():find(step.name:lower(), 1, true)
      and finished == true then
      self:Mark(step, "done")
      return true
    end
  end
  return false
end
function M:CheckPlace()
  local step = self:Current()
  if not step or step.kind ~= "place" or not step.mapID then return false end
  local mapID, x, y = C.PlayerPosition("player")
  if mapID == step.mapID and x and y
    and (x - step.x)^2 + (y - step.y)^2 <= 0.0001 then
    self:Mark(step, "done")
    return true
  end
  return false
end
function M:Guide()
  local step = self:Current()
  if not step then return false, "route finished or not started" end
  if not (step.mapID and step.x and step.y) then return false, "no verified position for this step" end
  return ns.Waypoints:Set(step.mapID, step.x, step.y, "Route: " .. step.name)
end

function M:OnEnable()
  self:On("QUEST_TURNED_IN", self.OnQuest)
  self:On("QUEST_LOG_UPDATE", function(mod) mod:OnKill() end)
  self:On("OTR_LOOT", self.OnLoot)
  self:On("ZONE_CHANGED_NEW_AREA", function(mod) mod:CheckPlace() end)
  self:On("PLAYER_ENTERING_WORLD", function(mod) mod:CheckPlace() end)
end
function M:Activity()
  local step, index, route = self:Current()
  return route and (step and (string.format("step %d/%d: %s", index, #route.steps, step.name)) or "route complete")
    or "no route selected"
end

ns.AddCommand("levelroute", "levelroute seed [level]|list|start <name>|next|skip|undo|guide|stop", function(arg)
  arg = tostring(arg or "list")
  local action, rest = arg:match("^(%S+)%s*(.*)$")
  if action == "seed" then
    local ok, reason = M:SeedHorde(rest)
    ns.Print(ok and ("route candidate created: " .. reason) or tostring(reason))
  elseif action == "list" then
    for _, route in pairs(M:Store().routes) do ns.Print("%s: %d steps", route.name, #route.steps) end
    ns.Print(M:Activity())
  elseif action == "start" then
    local ok, reason = M:Start(rest)
    ns.Print(ok and "route started" or tostring(reason))
  elseif action == "skip" or action == "next" then
    local step = M:Current()
    if step then M:Mark(step, "skipped") ns.Print("skipped: %s", step.name) end
  elseif action == "undo" then ns.Print(M:Undo() and "last step change undone" or "nothing to undo")
  elseif action == "guide" then local ok, reason = M:Guide() ns.Print(ok and "waypoint set" or tostring(reason))
  elseif action == "stop" then M:Store().current = nil ns.Print("route paused")
  else ns.Print("usage: /ride levelroute seed [level]|list|start <name>|skip|undo|guide|stop") end
end)

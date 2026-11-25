-- Intelligence/Recovery.lua  (OI03-13)
-- Coming back after time away: the plan you left is checked against what is
-- true now, and you choose whether to pick it up or start a new one.
--   At logout: a small summary of the plan is saved with the planner's
--     settings (char.modules.Nexus.settings.lastPlan): each step's title, quest,
--     item and map, the pin, and your level, gold, map, game build and goals.
--   At the next fresh login (not a /reload): Check() compares it with now:
--     a step's quest done since, or no longer on offer; an item now worn; a
--     different map, level, gold, game build or goals; how long you were away
--     (LONG_AWAY or more: everything is treated as advice to look again).
--   Nothing is reapplied by itself: the old plan is not restored. The Plan
--     page shows what changed with two choices: Resume (the first step that
--     is still good is pinned and a new plan is made around it) or New plan
--     (the pin is dropped). Either way the summary is set aside.
-- The saved summary is the player's own planner state: when a new one
-- replaces it, the old one is archived (nexusLastPlan), never just dropped.

local _, ns = ...
local C = ns.Compat
local R = { LONG_AWAY = 3 * 86400 }
ns.NexusRecovery = R

local function readable(v) if v == nil or C.IsSecret(v) then return nil end return C.Readable(v) end

-- a summary of the current plan (or nil)
function R.Summarize(planner)
  local cur = planner.current
  local res = cur and cur.result
  if not (res and res.plan) then return nil end
  local steps = {}
  for _, id in ipairs(res.plan.steps) do
    local c = cur.runtime and cur.runtime[id] or {}
    local node = cur.graph and cur.graph.nodes[id]
    steps[#steps + 1] = { id = id, title = node and node.opp.title or tostring(id), questID = tonumber(c.questID),
      itemID = tonumber(c.itemID), mapID = tonumber(c.mapID) }
  end
  local _, gameBuild = C.Call("GetBuildInfo")
  local goals = {}
  for _, g in ipairs(ns.NexusGoals:Active()) do goals[#goals + 1] = tostring(g.objective) .. ":" .. tostring(g.priority) end
  return { at = time(), steps = steps, pinned = planner:Settings().pinned, level = tonumber(readable(C.Call("UnitLevel", "player"))),
    copper = tonumber(readable(C.Call("GetMoney"))), mapID = tonumber(readable(C.PlayerPosition("player"))),
    build = readable(gameBuild), goals = table.concat(goals, ","), char = ns.db and ns.db.key }
end

function R.Save(planner)
  local sum = R.Summarize(planner)
  if not sum then return end
  local s = planner:Settings()
  if type(s.lastPlan) == "table" and not ns.Archive:Put("nexusLastPlan", s.lastPlan, { path = "char.modules.Nexus.settings.lastPlan", scope = "char" }) then
    return -- keep the old one rather than lose it
  end
  s.lastPlan = sum
end

-- what changed since the saved plan: { lines = {...}, steps = { {id, status, why} },
-- resumeStep = id or nil, away = seconds, long = bool }
function R.Check(saved, now)
  now = now or time()
  if type(saved) ~= "table" or type(saved.steps) ~= "table" then return nil end
  -- OI07-09: a summary another character left is not this one's
  if saved.char and ns.db and saved.char ~= ns.db.key then return nil end
  local out = { lines = {}, steps = {}, away = now - (tonumber(saved.at) or now) }
  local function line(t) out.lines[#out.lines + 1] = t end
  out.long = out.away >= R.LONG_AWAY
  if out.long then line(string.format("You've been away %d days: look again before you pick anything up.", math.floor(out.away / 86400))) end
  local _, gameBuild = C.Call("GetBuildInfo")
  local patched = saved.build and readable(gameBuild) and saved.build ~= readable(gameBuild)
  if patched then line("The game was updated since: quest and route data may have changed.") end
  out.patched = patched or nil
  local level = tonumber(readable(C.Call("UnitLevel", "player")))
  if level and saved.level and level ~= saved.level then line(string.format("You're level %d now (was %d).", level, saved.level)) end
  local map = tonumber(readable(C.PlayerPosition("player")))
  if map and saved.mapID and map ~= saved.mapID then line("You're somewhere else than when you left.") end
  local goals = {}
  for _, g in ipairs(ns.NexusGoals:Active()) do goals[#goals + 1] = tostring(g.objective) .. ":" .. tostring(g.priority) end
  if table.concat(goals, ",") ~= (saved.goals or "") then line("Your goals changed since.") end
  -- the quests the pack lists in a step's own zone (available, taken, or
  -- locked for now), to tell "gone" apart; unknown when that zone isn't loaded
  local zones = {}
  local NP = ns.NPCPack
  local function listedIn(mapID)
    if not (mapID and NP and NP.ZoneReport) then return nil end
    if zones[mapID] == nil then
      local ok, rep = pcall(NP.ZoneReport, NP, mapID, true)
      local set = false
      if ok and type(rep) == "table" then
        set = {}
        for _, part in ipairs({ "available", "active", "locked" }) do
          for _, q in ipairs(type(rep[part]) == "table" and rep[part] or {}) do if tonumber(q.id) then set[tonumber(q.id)] = true end end
        end
      end
      zones[mapID] = set
    end
    return zones[mapID] or nil
  end
  local worn = {}
  for slot = 1, 19 do
    local id = tonumber(readable(C.Call("GetInventoryItemID", "player", slot)))
    if id then worn[id] = true end
  end
  for _, st in ipairs(saved.steps) do
    local status, why = "ok", nil
    if st.questID then
      if C.Call("C_QuestLog.IsQuestFlaggedCompleted", st.questID) == true then status, why = "done", "you finished it since"
      elseif listedIn(st.mapID) and not listedIn(st.mapID)[st.questID] and C.Call("C_QuestLog.IsOnQuest", st.questID) ~= true then
        status, why = "gone", "no longer offered (removed, or not for you now)"
      end
    end
    if status == "ok" and st.itemID and worn[st.itemID] then status, why = "done", "you're wearing it now" end
    -- after a game update a quest can read as finished or gone when it isn't:
    -- never claim it, ask the player to look
    if patched and st.questID and (status == "done" or status == "gone") then status, why = "check", "the game was updated: check this one yourself" end
    out.steps[#out.steps + 1] = { id = st.id, title = st.title, status = status, why = why }
    if status == "ok" and not out.resumeStep and not out.long then out.resumeStep = st.id end
    if why then line(string.format("%s: %s.", st.title, why)) end
  end
  if #out.lines == 0 then line("Nothing has changed since you left.") end
  return out
end

-- on a fresh login with a saved plan: work out what changed (shown on the Plan page)
function R.OnLogin(planner, kind)
  if kind ~= "new" then return end
  local saved = planner:Settings().lastPlan
  if type(saved) ~= "table" then return end
  planner.recovery = R.Check(saved)
end

-- the player's choice; the old plan is never applied by itself
function R.Resume(planner)
  local rec = planner.recovery
  if not rec then return false end
  planner.recovery = nil
  planner:Settings().pinned = rec.resumeStep
  planner:Replan("resume after time away")
  return true
end
function R.NewPlan(planner)
  if not planner.recovery then return false end
  planner.recovery = nil
  planner:Settings().pinned = nil
  planner:Replan("new plan after time away")
  return true
end

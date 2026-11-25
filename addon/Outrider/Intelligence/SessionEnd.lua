-- Intelligence/SessionEnd.lua  (OI04-03)
-- Ending a session well. With a time limit set (Horizon), the planner works
-- from the time left (from when you set it), minus a reserve for closing up:
--   repairs     gear below REPAIR_AT durability: the trip to the nearest repair
--               vendor plus a minute
--   hand-ins    quests in your log that are complete: HANDIN_EACH seconds each
--               (their trips are part of the quests' own steps)
--   rest point  when you chose "End at a rest point": the trip to the nearest inn
-- Inside the last CLOSING seconds, or the last quarter of a short session (after the reserve), the plan switches to
-- closing steps only (repair, hand in, head to an inn) and never starts a step
-- that can't finish in the time left (with the planner's margin). With no
-- closing step that fits, it says it's a good moment to stop. Nothing here
-- logs you out or acts: every closing step is a waypoint or a page, your click.

local _, ns = ...
local C = ns.Compat
local E = { REPAIR_AT = 0.3, HANDIN_EACH = 60, CLOSING = 600, WALK = 7 }
ns.SessionEnd = E

local function tripTo(kind)
  local N = ns.Nearest
  if not (N and N.Find) then return nil end
  local ok, p, yards = pcall(N.Find, N, kind)
  if ok and p and tonumber(yards) then return math.floor(yards / E.WALK), p end
end

function E.ReadyQuests()
  local n = tonumber(C.Readable(C.Call("C_QuestLog.GetNumQuestLogEntries"))) or 0
  local ready = 0
  for i = 1, math.min(n, 40) do
    local info = C.Call("C_QuestLog.GetInfo", i)
    local id = type(info) == "table" and not info.isHeader and tonumber(C.Readable(info.questID))
    if id and C.Call("C_QuestLog.IsComplete", id) == true then ready = ready + 1 end
  end
  return ready
end

-- the closing reserve: seconds, and its parts { {what, seconds} }
function E.Reserve(horizon)
  local parts, total = {}, 0
  local function add(what, s) parts[#parts + 1] = { what, s } total = total + s end
  local d = ns.Errands and ns.Errands.Durability and ns.Errands.Durability()
  if d and d < E.REPAIR_AT then add("repair", (tripTo("repair") or 300) + 60) end
  local ready = E.ReadyQuests()
  if ready > 0 then add("hand-ins", ready * E.HANDIN_EACH) end
  if horizon and horizon.stopRest then add("rest point", (tripTo("inn") or 300) + 30) end
  return total, parts
end

-- seconds left in the session (nil = no limit)
function E.Left(horizon, now)
  if not (horizon and horizon.minutes) then return nil end
  local started = tonumber(horizon.startedAt) or (now or time())
  return math.max(0, horizon.minutes * 60 - ((now or time()) - started))
end

-- the closing steps as candidates (WhatNow's shape), only the ones that apply
function E.Candidates(horizon)
  local out = {}
  local d = ns.Errands and ns.Errands.Durability and ns.Errands.Durability()
  if d and d < E.REPAIR_AT then
    local secs = tripTo("repair")
    out[#out + 1] = { key = "close:repair", kind = "errand", title = "Repair before you stop", benefit = 0.8, confidence = 0.9,
      label = "observed", seconds = secs, estimatedActivitySeconds = 60, why = "Your gear is worn: repair now so the next session starts ready.",
      go = function() return ns.Nearest:Go("repair") end }
  end
  local ready = E.ReadyQuests()
  if ready > 0 then
    out[#out + 1] = { key = "close:handin", kind = "quest", title = string.format("Hand in %d finished quest%s", ready, ready == 1 and "" or "s"),
      benefit = 0.9, confidence = 0.9, label = "observed", seconds = 0, estimatedActivitySeconds = ready * E.HANDIN_EACH,
      why = "Their XP and rewards are waiting.", panel = "questchains" }
  end
  if horizon and horizon.stopRest then
    local secs = tripTo("inn")
    out[#out + 1] = { key = "close:inn", kind = "travel", title = "Head to an inn to stop", benefit = 0.7, confidence = 0.8,
      label = "observed", seconds = secs, estimatedActivitySeconds = 0, why = "Logging out at an inn earns rested XP.",
      go = function() return ns.Nearest:Go("inn") end }
  end
  return out
end

-- the planner's view: budget seconds, and whether it is closing time
function E.Plan(horizon, now)
  local left = E.Left(horizon, now)
  if not left then return { closing = false } end
  local reserve, parts = E.Reserve(horizon)
  local budget = math.max(0, left - reserve)
  -- closing time scales with the session: the last CLOSING seconds, or the
  -- last quarter of a short one
  local window = math.min(E.CLOSING, horizon.minutes * 60 * 0.25)
  return { left = left, reserve = reserve, parts = parts, budget = budget, closing = budget <= window }
end

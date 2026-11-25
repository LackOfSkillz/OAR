-- tests/lib/afteraction_fixture.lua
-- A repeatable set of AfterAction observations (OI03-14): quests, walking
-- trips, outcomes and sessions from a fixed seed, so the same fixture always
-- gives the same evidence report. Test data, not anyone's play.
local F = {}

-- a small linear congruential generator: same seed, same numbers, any Lua
local function rng(seed)
  local s = seed
  return function(lo, hi)
    s = (s * 1103515245 + 12345) % 2147483648
    return lo + (s % (hi - lo + 1))
  end
end

function F.Build(seed)
  local r = rng(seed or 42)
  local t0 = 1800000000
  local quests, trips, events, sessions = {}, {}, {}, {}
  for i = 1, 40 do
    quests[#quests + 1] = { kind = "complete", seconds = 420 + r(0, 360), level = 20 + (i % 3), endedAt = t0 + i * 900, build = "B" }
  end
  quests[#quests + 1] = { kind = "multi", startedAt = t0 }
  quests[#quests + 1] = { kind = "abandoned", startedAt = t0 }
  local routes = { { 1, 2 }, { 1, 3 }, { 2, 3 }, { 4, 5 } }
  for i = 1, 12 do
    local rt = routes[(i % 3) + 1]
    trips[#trips + 1] = { walking = true, fromMap = rt[1], toMap = rt[2], estimate = 100 + rt[2] * 20, seconds = 110 + rt[2] * 20 + r(0, 60), endedAt = t0 + i * 600 }
  end
  trips[#trips + 1] = { walking = true, fromMap = 4, toMap = 5, estimate = 200, seconds = 260, endedAt = t0 } -- walked once
  trips[#trips + 1] = { mode = "flight", fromMap = 1, toMap = 9, estimate = 100, seconds = 90, endedAt = t0 } -- not walking
  for i = 1, 8 do
    local ps = "ps:" .. i
    sessions[#sessions + 1] = { playSessionId = ps, final = true, xpVerified = true, durationSeconds = 3600, xpEarned = 9000 + r(0, 3000),
      levelStart = 21, build = "B" }
    events[#events + 1] = { kind = "quest_completed", sessionId = ps, attribution = (i % 2 == 0) and "likely" or "unknown", subject = "quest:" .. i }
    events[#events + 1] = { kind = "death", sessionId = ps, attribution = "unknown" }
  end
  return { quests = quests, trips = trips, events = events, sessions = sessions, prior = 300, fixture = true }
end

return F

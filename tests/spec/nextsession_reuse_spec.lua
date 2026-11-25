-- OI03-12: the offline next-session plan meets play sessions, the planner and your own estimates.
local T, mock = ...

local function session()
  local game = mock.new({ level = 20 })
  local ns = game:loadAddon()
  game:login()
  return game, ns
end
local function snapshot(game, ns, cands)
  game.env.Outrider_Snapshots = { [ns.db.key] = { modules = { WhatNow = { candidates = cands } } } }
end
local function history(ns, rows)
  ns.db.char.xp60 = { schema = 1, history = rows }
end
local function plan(game, ns, steps, over)
  local a = { schema = 4, kind = "nextSessionPlan", forCharacter = ns.db.key, basedOnSessionId = "seg-1",
    sourceDigest = string.rep("a", 64), createdAt = game.now, expiresAt = game.now + 3600, gameBuild = tostring(ns.build),
    levelAtPlan = 20, goal = "xp", budgetSeconds = 3600, status = "tentative", headline = "Next hour", summary = "Go.",
    steps = steps or {}, actions = {} }
  for k, v in pairs(over or {}) do a[k] = v end
  return a
end
local function step(id, from, to) return { candidateId = id, startsAt = from, endsAt = to, xp = 100 } end
local function twoSegments(ns)
  history(ns, {
    { sessionId = "seg-1", playSessionId = "ps:1", segment = 1, final = false, endReason = "reload", build = tostring(ns.build), flags = {},
      xpEarned = 1000, durationSeconds = 900, xpVerified = true, levelStart = 20, levelEnd = 20 },
    { sessionId = "seg-2", playSessionId = "ps:1", segment = 2, final = true, endReason = "logout", build = tostring(ns.build), flags = {},
      xpEarned = 2000, durationSeconds = 900, xpVerified = true, levelStart = 20, levelEnd = 20 },
  })
end

T.describe("next-session planner reuse (OI03-12)", function()
  T.it("a session with a reload is one source: a plan based on it is accepted", function()
    local game, ns = session()
    twoSegments(ns)
    snapshot(game, ns, {})
    local _, why = ns.Advice:Check(plan(game, ns))
    T.eq(why, "ok", "bound to the merged play session, not the last segment")
    local _, why2 = ns.Advice:Check(plan(game, ns, {}, { basedOnSessionId = "seg-2" }))
    T.eq(why2, "source session has changed", "a segment id is not the session")
  end)

  T.it("time budget, stale plans, other builds and model actions are still refused", function()
    local game, ns = session()
    twoSegments(ns)
    snapshot(game, ns, { { candidateId = "quest:A", title = "A", kind = "quest" } })
    local function why(a) return select(2, ns.Advice:Check(a)) end
    T.eq(why(plan(game, ns, { step("quest:A", 0, 3700) })), "untrusted or oversized plan step")
    T.eq(why(plan(game, ns, {}, { expiresAt = game.now - 1 })), "next-session plan expired")
    T.eq(why(plan(game, ns, {}, { gameBuild = "other" })), "game build differs from source")
    T.eq(why(plan(game, ns, {}, { actions = { { run = "/cast x" } } })), "model actions forbidden")
    T.eq(why(plan(game, ns, {}, { forCharacter = "Someone-Else" })), "advice is for another character")
  end)

  T.it("one quest under two ids is shown once, with a note", function()
    local game, ns = session()
    twoSegments(ns)
    snapshot(game, ns, { { candidateId = "quest:Red Silk Bandanas", title = "Red Silk", kind = "quest", questID = 214 },
      { candidateId = "dq:214", title = "Red Silk (dungeon)", kind = "dungeon" } })
    local _, why, answer = ns.Advice:Check(plan(game, ns, { step("quest:Red Silk Bandanas", 0, 600), step("dq:214", 600, 1200) }))
    T.eq(why, "ok")
    T.eq(#answer.plan, 1)
    T.ok(answer.limits[#answer.limits]:find("listed twice"))
  end)

  T.it("a step the planner knows can't be done now is taken out, with the reason", function()
    local game, ns = session()
    twoSegments(ns)
    snapshot(game, ns, { { candidateId = "quest:One", title = "One", kind = "quest" }, { candidateId = "quest:Two", title = "Two", kind = "quest" } })
    game.env.Outrider_Advice = plan(game, ns, { step("quest:One", 0, 600), step("quest:Two", 600, 1200) })
    ns.NexusCore.current = { graph = { nodes = {
      ["opp:quests:quest:One"] = { opp = { legacyCandidateId = "quest:One" } },
      ["opp:quests:quest:Two"] = { opp = { legacyCandidateId = "quest:Two" } } },
      invalid = { ["opp:quests:quest:One"] = "faction: for Alliance" } },
      result = { plan = { steps = { "opp:quests:quest:Two" } } }, rejected = {} }
    local p = ns.NextSession:Plan()
    T.eq(#p.plan, 1) T.eq(p.plan[1].candidateId, "quest:Two") T.eq(p.plan[1].inYourPlan, true)
    local found = false
    for _, l in ipairs(p.limits) do if l:find("One can't be done now: faction") then found = true end end
    T.ok(found, "the reason is shown")
  end)

  T.it("your own quest times add a note when the plan looks optimistic", function()
    local game, ns = session()
    twoSegments(ns)
    snapshot(game, ns, { { candidateId = "quest:One", title = "One", kind = "quest" } })
    game.env.Outrider_Advice = plan(game, ns, { step("quest:One", 0, 120) })
    ns.QuestTimes.Mine = function()
      local out = {}
      for i = 1, 6 do out[i] = { kind = "complete", seconds = 900, level = 20, endedAt = game.now - i } end
      return out
    end
    local p = ns.NextSession:Plan()
    local text = table.concat(p.limits, " | ")
    T.ok(text:find("Your quests take about 15 min") and text:find("optimistic"), text)
  end)

  T.it("with no offline plan the window still says keep your route, plus ideas from Outrider", function()
    local game, ns = session()
    ns.WhatNow.List = function() return { { title = "Repair at Razor Hill" } } end
    ns.WhatNow.enabled = true
    game:slash("nextsession")
    local text = ns.NextSession.window.details:GetText()
    T.ok(text:find("Keep your current route") and text:find("Ideas from Outrider %(not a plan%): Repair at Razor Hill"), text)
  end)

  T.it("a full suppression list is archived before a new one starts", function()
    local game, ns = session()
    twoSegments(ns)
    local saved = {}
    for i = 1, 81 do saved["quest:" .. i] = { verdict = "wrong", at = 1, level = 20 } end
    ns.db.char.xp60Suppressed = saved
    snapshot(game, ns, { { candidateId = "quest:x", title = "X", kind = "quest" } })
    game.env.Outrider_Advice = plan(game, ns, {}, { qualitativeCandidateIds = { "quest:x" } })
    T.ok(ns.NextSession:Feedback("not_interested"))
    T.ok(#ns.Archive:Rows("xp60Suppressed") >= 1, "kept in the archive")
  end)
end)

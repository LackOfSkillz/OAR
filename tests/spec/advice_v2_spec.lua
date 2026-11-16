-- Advice schema 2 (Outrider Intelligence AI02-05): answer text, grounded cards.
local T, mock = ...

local function session()
  local game = mock.new({ ammo = 1000 })
  local ns = game:loadAddon()
  game:login()
  local W = ns.WhatNow
  W.SOURCES.spec = function()
    return { { key = "gather:Peacebloom", kind = "gather", title = "Gather Peacebloom", benefit = 0.9, confidence = 1,
      label = "observed", target = { mapID = 1412, x = 0.4, y = 0.5 } } }
  end
  table.insert(W.ORDER, "spec")
  local snap = ns.Snapshot:Collect(true)
  table.remove(W.ORDER)
  return game, ns, snap
end

local function code(ns, snap, extra)
  local a = { kind = "advice", schema = 2, forCharacter = ns.db.key, answersSnapshot = snap.askedAt,
    answersSnapshotId = snap.snapshotId,
    answer = { headline = "|cffff0000Gather|r first", summary = "Peacebloom is up nearby.", limits = { "travel not checked" } },
    items = {} }
  for k, v in pairs(extra or {}) do a[k] = v end
  return ns.Serialize.Export(a)
end

T.describe("advice schema 2", function()
  T.it("keeps grounded cards and the answer, drops everything ungrounded", function()
    local _, ns, snap = session()
    local items = {
      { title = "Go gather", action = "waypoint", candidateId = "gather:Peacebloom", confidence = "observed",
        args = { mapID = 1412, x = 0.4, y = 0.5 } },
      { title = "Moved waypoint", action = "waypoint", candidateId = "gather:Peacebloom", args = { mapID = 1412, x = 0.41, y = 0.5 } },
      { title = "Unknown id", action = "open_panel", candidateId = "quest:Made Up", args = { panel = "gear" } },
      { title = "Free waypoint", action = "waypoint", args = { mapID = 1412, x = 0.1, y = 0.1 } },
      { title = "Open gear", action = "open_panel", args = { panel = "gear" } },
      { title = "Run code", action = "run_lua", args = { code = "x" } },
    }
    local n, why = ns.Advice:Paste(code(ns, snap, { items = items }))
    T.eq(why, "ok")
    T.eq(n, 2)
    local got, reason, answer = ns.Advice:Load()
    T.eq(reason, "ok")
    T.eq(got[1].title, "Go gather")
    T.eq(got[1].confidence, "observed")
    T.eq(got[2].title, "Open gear")
    T.eq(answer.headline, "cffff0000Gatherr first")   -- escape codes can't colour or link anything
    T.eq(answer.limits[1], "travel not checked")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("an answer for another snapshot is stale; schema 1 still works", function()
    local _, ns, snap = session()
    local n, why = ns.Advice:Paste(code(ns, snap, { answersSnapshotId = "hunter-1",
      items = { { title = "Open gear", action = "open_panel", args = { panel = "gear" } } } }))
    T.eq(n, 0)
    T.eq(why, "advice is stale")
    local v1 = ns.Serialize.Export({ kind = "advice", schema = 1, forCharacter = ns.db.key, answersSnapshot = snap.askedAt,
      items = { { title = "Open gear", action = "open_panel", args = { panel = "gear" } } } })
    T.eq(ns.Advice:Paste(v1), 1)
  end)

  T.it("the Advisor tab shows the answer above the cards", function()
    local _, ns, snap = session()
    ns.Advice:Paste(code(ns, snap, { items = { { title = "Open gear", action = "open_panel", args = { panel = "gear" } } } }))
    ns.Hub:Build():Show()
    ns.Hub:ShowTab("advisor")
    local p = ns.Hub.byId.advisor.panel
    T.ok(p.answer:IsShown())
    T.contains(p.answer.summary.__text, "Peacebloom")
    T.contains(p.answer.limits.__text, "travel not checked")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("question and minutes from the Advisor tab ride in the snapshot; feedback hides done steps", function()
    local game, ns = session()
    T.eq(ns.Advisor.Minutes("45"), 45)
    T.eq(ns.Advisor.Minutes("1h"), 60)
    T.eq(ns.Advisor.Minutes("2"), 5)
    T.eq(ns.Advisor.Minutes("nope"), nil)
    ns.db.char.askQuestion = "I have 45 minutes"
    ns.db.char.askMinutes = 45
    local s = ns.Snapshot:Collect(true)
    T.eq(s.question, "I have 45 minutes")
    T.eq(s.timeBudget, 45)
    T.eq(ns.Snapshot:Collect(false).question, nil)
    T.no(ns.Advisor:Feedback({ title = "x" }, "useful"))
    T.ok(ns.Advisor:Feedback({ candidateId = "errand:repair" }, "done"))
    T.ok(ns.WhatNow:Store().skip["errand:repair"] ~= nil)
    local again = ns.Snapshot:Collect(true)
    T.eq(again.modules.WhatNow.feedback[1].id, "errand:repair")
    T.eq(again.modules.WhatNow.feedback[1].v, "done")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("plan and compare rows keep only steps from this snapshot, with the snapshot's titles", function()
    local _, ns, snap = session()
    local ans = { headline = "Plan", summary = "s", budget = 30, planMinutes = 12,
      plan = { { candidateId = "gather:Peacebloom", minutes = 6 }, { candidateId = "quest:Fake", minutes = 5 } },
      compare = { { candidateId = "gather:Peacebloom", minutes = 6, label = "observed" }, { candidateId = "quest:Fake" } } }
    ns.Advice:Paste(code(ns, snap, { answer = ans, items = { { title = "Open gear", action = "open_panel", args = { panel = "gear" } } } }))
    local _, _, answer = ns.Advice:Load()
    T.eq(#answer.plan, 1)
    T.eq(answer.plan[1].title, "Gather Peacebloom")
    T.eq(answer.compare, nil)   -- one of the two is unknown: no compare
    T.contains(ns.Advisor.PlanLine(answer), "about 12 min of 30")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("cards show text source chips, done marks and plan progress; status tells the snapshot's age", function()
    local game, ns, snap = session()
    T.contains(ns.Advisor.Chip("community"), "[Community]")
    T.contains(ns.Advisor.Chip("nonsense"), "[Unknown]")
    T.contains(ns.Advisor:Status(), "just taken")
    local ans = { headline = "Plan", summary = "s", planMinutes = 10, plan = { { candidateId = "gather:Peacebloom", minutes = 6 } } }
    ns.Advice:Paste(code(ns, snap, { answer = ans, items = {
      { title = "Go gather", action = "waypoint", candidateId = "gather:Peacebloom", confidence = "observed",
        args = { mapID = 1412, x = 0.4, y = 0.5 } } } }))
    ns.Hub:Build():Show()
    ns.Hub:ShowTab("advisor")
    local p = ns.Hub.byId.advisor.panel
    T.contains(p.answer.plan.__text, "(0 of 1 done)")
    T.ok(ns.Advisor:Feedback({ candidateId = "gather:Peacebloom" }, "done"))
    p:Refresh()
    T.contains(p.answer.plan.__text, "(1 of 1 done)")
    T.ok(ns.Advisor:IsDone("gather:Peacebloom"))
    game:advance(2 * 3600)
    T.contains(ns.Advisor:Status(), "Ask again")
    T.eq(#ns.Errors.list, 0)
  end)
end)

-- OI03-13: coming back after time away.
local T, mock = ...

local function boot(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  return game, ns
end
local function planned(questDone)
  local game, ns = boot({ level = 20 })
  game:login()
  local N = ns.NexusCore
  N:Settings().on = true
  local S = ns.WhatNow.SOURCES
  for k in pairs(S) do S[k] = function() return {} end end
  S.quests = function() return {
    { key = "quest:A", kind = "quest", title = "Quest A", benefit = 0.9, confidence = 0.8, seconds = 300, label = "observed", questID = 101, mapID = 1, go = function() end },
    { key = "quest:B", kind = "quest", title = "Quest B", benefit = 0.7, confidence = 0.8, seconds = 300, label = "observed", questID = 102, mapID = 1, go = function() end },
  } end
  N:Replan("x")
  return game, ns, N
end
-- log out and come back; how = "reload" or "login"; prep(game) runs before login
local function comeBack(game, how, advance, prep)
  local saved = game:logout()
  local g2, ns2 = boot({ savedVariables = saved, level = 20, now = game.now + (advance or 0) })
  if prep then prep(g2, ns2) end
  g2:fire("ADDON_LOADED", "Outrider") g2:fire("PLAYER_LOGIN")
  g2:fire("PLAYER_ENTERING_WORLD", how ~= "reload", how == "reload")
  return g2, ns2, ns2.NexusCore
end

T.describe("recovery after time away (OI03-13)", function()
  T.it("at logout a summary is saved; at the next login what changed is listed and nothing is reapplied", function()
    local game, ns, N = planned()
    local g2, ns2, N2 = comeBack(game, "login", 3600, function(g)
      g.env.C_QuestLog = g.env.C_QuestLog or {}
      local done = { [101] = true }
      g.env.C_QuestLog.IsQuestFlaggedCompleted = function(id) return done[id] == true end
    end)
    T.eq(N2.current, nil, "the old plan is not restored")
    local rec = N2.recovery
    T.ok(rec, "a recovery summary")
    local st = {}
    for _, s in ipairs(rec.steps) do st[s.title] = s end
    T.eq(st["Quest A"].status, "done")
    T.eq(st["Quest B"].status, "ok")
    T.eq(rec.resumeStep, st["Quest B"].id)
    T.ok(table.concat(rec.lines, " "):find("finished it since"))
  end)

  T.it("a reload is not time away: no recovery prompt", function()
    local game = planned()
    local _, _, N2 = comeBack(game, "reload", 5)
    T.eq(N2.recovery, nil)
  end)

  T.it("the player chooses: Resume pins the first still-good step; New plan drops the pin", function()
    local game = planned()
    local _, ns2, N2 = comeBack(game, "login", 600)
    N2:Settings().on = true
    local resume = N2.recovery.resumeStep
    T.ok(resume)
    T.ok(ns2.NexusRecovery.Resume(N2))
    T.eq(N2:Settings().pinned, resume)
    T.eq(N2.recovery, nil)
    local _, ns3, N3 = comeBack(game, "login", 600)
    N3:Settings().pinned = "something"
    T.ok(ns3.NexusRecovery.NewPlan(N3))
    T.eq(N3:Settings().pinned, nil)
  end)

  T.it("a long absence: everything is to look at again, nothing offered to resume", function()
    local game = planned()
    local _, _, N2 = comeBack(game, "login", 10 * 86400)
    T.ok(N2.recovery.long)
    T.eq(N2.recovery.resumeStep, nil)
    T.ok(N2.recovery.lines[1]:find("away 10 days"))
  end)

  T.it("a quest no longer on offer anywhere (deleted or withdrawn) is marked gone", function()
    local game = planned()
    local _, ns2, N2 = comeBack(game, "login", 600, function(g, n)
      -- the zone's quest list no longer has quest 101 (deleted or withdrawn)
      n.NPCPack.ZoneReport = function() return { available = { { id = 102 } }, active = {}, locked = {} } end
    end)
    local st = {}
    for _, s in ipairs(N2.recovery.steps) do st[s.title] = s end
    T.eq(st["Quest A"].status, "gone")
    T.eq(st["Quest B"].status, "ok")
  end)

  T.it("changed level, place, goals or game build are listed", function()
    local game, ns, N = planned()
    N:Settings().lastPlan = nil
    ns.NexusRecovery.Save(N)
    local saved = N:Settings().lastPlan
    saved.level, saved.mapID, saved.build, saved.goals = 12, 9999, "old-build", "gold:1"
    local rec = ns.NexusRecovery.Check(saved, game.now + 60)
    local text = table.concat(rec.lines, " ")
    T.ok(text:find("level 20 now") and text:find("somewhere else") and text:find("goals changed") and text:find("game was updated"), text)
  end)

  T.it("a new summary archives the old one; the Plan page shows the welcome-back card with tooltips", function()
    local game, ns, N = planned()
    ns.NexusRecovery.Save(N)
    ns.NexusRecovery.Save(N)
    T.ok(#ns.Archive:Rows("nexusLastPlan") >= 1)
    N.recovery = ns.NexusRecovery.Check(N:Settings().lastPlan, game.now + 60)
    ns.Hub:Build():Show()
    ns.Hub:ShowTab("nexusplan")
    T.eq(#ns.Errors.list, 0)
    local missing = {}
    for label in pairs(ns.UI.untipped or {}) do missing[#missing + 1] = label end
    T.eq(#missing, 0, table.concat(missing, ", "))
  end)
end)

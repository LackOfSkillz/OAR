-- OI04-01: Horizon session inputs.
local T, mock = ...

local function session(prep)
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  if prep then prep(game, ns) end
  local N = ns.NexusCore
  N:Settings().on = true
  local S = ns.WhatNow.SOURCES
  for k in pairs(S) do S[k] = function() return {} end end
  S.quests = function() return {
    { key = "quest:Solo", kind = "quest", title = "A solo quest", benefit = 0.6, confidence = 0.8, seconds = 300, label = "observed", questID = 1, mapID = 1 },
    { key = "quest:After", kind = "quest", title = "After the dungeon", benefit = 0.9, confidence = 0.8, seconds = 300, label = "observed", questID = 3, mapID = 1, preAll = { 2 } },
  } end
  S.dungeonquests = function() return {
    { key = "dq:2", kind = "dungeon", title = "A dungeon quest", benefit = 0.8, confidence = 0.6, seconds = 1200, label = "guide", questID = 2, mapID = 1 },
  } end
  local A = ns.NexusAdapters
  A.LevelRouteStep, A.DealLots, A.HandoffItems = function() return {} end, function() return {} end, function() return {} end
  return game, ns, N, ns.NexusHorizon
end

T.describe("Horizon session inputs (OI04-01)", function()
  T.it("inputs validate: presets, custom bounds, group choice", function()
    local _, _, _, H = session()
    T.ok(H.Validate({ minutes = 30, group = "solo" }))
    T.ok(H.Validate({ minutes = 7, group = "either" }), "custom")
    T.eq(select(2, H.Validate({ minutes = 3 })), "minutes must be 5 to 480")
    T.eq(select(2, H.Validate({ minutes = 600 })), "minutes must be 5 to 480")
    T.eq(select(2, H.Validate({ minutes = 12.5 })), "minutes must be a whole number")
    T.eq(select(2, H.Validate({ group = "raid" })), "group must be solo, group or either")
    T.ok(H.Validate({}), "no limit, either")
  end)

  T.it("the time budget reaches the planner and limits the plan", function()
    local _, _, N, H = session()
    H.Set(N, { minutes = 15, group = "either" })
    local cur = N:Replan("x")
    T.eq(N:Context().budgetSeconds, 900)
    -- the plan's own estimate (shared travel counted once), with its margin
    T.ok(cur.result.bufferedSeconds <= 900, "the plan fits 15 minutes: " .. tostring(cur.result.bufferedSeconds))
  end)

  T.it("solo leaves out steps that need a group, and what needs them first", function()
    local _, _, N, H = session()
    H.Set(N, { group = "solo" })
    local cur = N:Replan("x")
    local why = {}
    for id, r in pairs(cur.rejected) do why[id] = r end
    local dq, after
    for id in pairs(cur.graph.nodes) do
      if id:find("dq:2") then dq = id end
      if id:find("After") then after = id end
    end
    T.ok(tostring(why[dq]):find("needs a group"), tostring(why[dq]))
    T.ok(tostring(why[after]):find("dq") or tostring(why[after]):find("needs"), tostring(why[after]))
    H.Set(N, { group = "either" })
    cur = N:Replan("x")
    T.eq(cur.rejected[dq], nil, "either keeps the group step")
  end)

  T.it("existing saved preferences migrate; the old ones stay", function()
    local _, ns, N, H = session(function(_, n) n.db.char.askMinutes = 30 end)
    N:Settings().horizon = nil
    local h = H.Get(N)
    T.eq(h.minutes, 30) T.eq(h.group, "either")
    T.eq(ns.db.char.askMinutes, 30, "the old setting is kept")
    local _, ns2, N2, H2 = session(function(_, n)
      n.Modules:Get("OpportunityRadar"):Settings().timeBudget = 90
    end)
    N2:Settings().horizon = nil
    T.eq(H2.Get(N2).minutes, 90, "a changed Radar budget migrates")
    local _, _, N3, H3 = session()
    N3:Settings().horizon = nil
    T.eq(H3.Get(N3).minutes, nil, "the untouched Radar default is not a choice")
  end)

  T.it("a damaged saved horizon is kept aside and the default used", function()
    local _, ns, N, H = session()
    N:Settings().horizon = { minutes = "lots", group = "x" }
    local h = H.Get(N)
    T.eq(h.group, "either") T.eq(h.minutes, nil)
  end)

  T.it("changing the horizon makes the current plan stale at once; the page shows it, with tooltips", function()
    local _, ns, N, H = session()
    N:Replan("x")
    N:Settings().paused = true
    T.eq(select(1, N:IsStale()), false)
    H.Set(N, { minutes = 30, group = "solo" })
    T.eq(select(1, N:IsStale()), true)
    ns.Hub:Build():Show()
    ns.Hub:ShowTab("nexusplan")
    T.eq(#ns.Errors.list, 0)
    local missing = {}
    for label in pairs(ns.UI.untipped or {}) do missing[#missing + 1] = label end
    T.eq(#missing, 0, table.concat(missing, ", "))
    T.eq(H.Label(H.Get(N)), "30 min, solo")
  end)
end)

T.describe("session clock (review OI-FR05)", function()
  T.it("a migrated time gets a clock; a clock in the future is ignored", function()
    local game, ns, N, H = session(function(_, ns) ns.db.char.askMinutes = 30 end)
    N:Settings().horizon = nil
    local h = H.Get(N)
    T.eq(h.minutes, 30)
    T.ok(tonumber(h.startedAt), "migrated time has a start")
    T.eq(H.Validate({ minutes = 30, startedAt = game.now + 3600 }).startedAt, nil)
    T.ok(ns)
  end)

  T.it("the same length again keeps a running clock, but starts a new one after it ran out", function()
    local game, _, N, H = session()
    H.Set(N, { minutes = 60 })
    local first = N:Settings().horizon.startedAt
    game.now = game.now + 600
    H.Set(N, { minutes = 60 })
    T.eq(N:Settings().horizon.startedAt, first, "still running")
    N:Settings().horizon.startedAt = game.now - 3601
    H.Set(N, { minutes = 60 })
    T.ok(game.now - N:Settings().horizon.startedAt < 5, "a fresh clock")
  end)

  T.it("Start a new session and a login after the time ran out restart the clock; a reload keeps it", function()
    local game, _, N, H = session()
    H.Set(N, { minutes = 30 })
    N:Settings().horizon.startedAt = game.now - 600
    T.eq(H.OnLogin(N), false, "time left: kept")
    T.ok(game.now - N:Settings().horizon.startedAt >= 600)
    N:Settings().horizon.startedAt = game.now - 4000
    T.ok(H.OnLogin(N), "ran out while away")
    T.ok(game.now - N:Settings().horizon.startedAt < 5)
    N:Settings().horizon.startedAt = game.now - 900
    T.ok(H.StartNew(N))
    T.ok(game.now - N:Settings().horizon.startedAt < 5)
  end)

  T.it("a plan that no longer fits the time left, or closing time, makes it stale", function()
    local game, _, N, H = session()
    H.Set(N, { minutes = 60 })
    local cur = N:Replan("x")
    T.ok(cur and cur.result.plan, "a plan")
    T.eq((N:IsStale()), false)
    -- most of the hour passes: the plan's buffered time is over what is left
    N:Settings().horizon.startedAt = game.now - 3540
    T.ok((N:IsStale()), "stale once it can't fit")
  end)
end)

-- OI02-06: progression adapters turn existing suggestions into v4 Opportunities.
local T, mock = ...

local function session()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.NexusAdapters
end

-- swap WhatNow's producers for fixed fixture lists, restore after
local function withSources(ns, fixtures, fn)
  local S = ns.WhatNow.SOURCES
  local saved = {}
  for k, v in pairs(fixtures) do saved[k] = S[k] S[k] = v end
  local ok, err = pcall(fn)
  for k in pairs(fixtures) do S[k] = saved[k] end
  if not ok then error(err, 0) end
end

T.describe("nexus progression adapters", function()
  T.it("existing ids map deterministically to valid v4 opportunities", function()
    local game, ns, A = session()
    withSources(ns, {
      quests = function() return { { key = "quest:Wanted: Gnoll", kind = "quest", title = "Pick up Wanted: Gnoll [12]",
        benefit = 0.8, confidence = 0.6, seconds = 300, label = "community", questID = 176, go = function() end } } end,
      errands = function() return { { key = "errand:repair", kind = "errand", title = "Repair at a smith", benefit = 0.5, label = "observed", panel = "home" } } end,
      dungeons = function() return {} end,
      dungeonquests = function() return {} end,
    }, function()
      local a = A:Progression(1, game.now)
      local b = A:Progression(1, game.now)
      T.eq(#a, 2)
      for i, rec in ipairs(a) do
        T.ok(ns.Nexus.Validate("Opportunity", rec), rec.opportunityId)
        T.eq(rec.opportunityId, b[i].opportunityId, "same input, same ids")
      end
      local q = a[2].kind == "quest" and a[2] or a[1]
      T.eq(q.opportunityId, "opp:quests:quest:Wanted:_Gnoll")
      T.eq(q.legacyCandidateId, "quest:Wanted:_Gnoll")
      T.eq(q.intent, "waypoint")
      T.eq(q.costSeconds, 300)
      T.ok(math.abs(q.risk - 0.4) < 1e-9)
    end)
  end)

  T.it("missing or bad data is excluded with a reason, never guessed", function()
    local game, ns, A = session()
    withSources(ns, {
      quests = function() return {
        { key = "quest:a", kind = "quest", title = "", benefit = 0.5 },
        { key = "quest:b", kind = "quest", title = "B", benefit = nil },
        { key = "tip:1", kind = "tip", title = "A tip", benefit = 0.5 },
        { kind = "quest", title = "no key", benefit = 0.5 },
      } end,
      errands = function() error("producer broke") end,
      dungeons = function() return {} end,
      dungeonquests = function() return {} end,
    }, function()
      local list, excluded, unavailable = A:Progression(1, game.now)
      T.eq(#list, 0)
      local reasons = {}
      for _, e in ipairs(excluded) do reasons[e.reason] = true end
      T.ok(reasons["no title"] and reasons["no benefit"] and reasons["no key"])
      T.ok(reasons["not an opportunity (tip)"])
      T.eq(unavailable[1], "errands", "a failing producer is reported, the rest carry on")
    end)
  end)

  T.it("the same quest from two producers is one opportunity (no duplicate rewards)", function()
    local game, ns, A = session()
    withSources(ns, {
      quests = function() return { { key = "quest:Deadmines run", kind = "quest", title = "Pick up Red Silk Bandanas", benefit = 0.5, questID = 214 } } end,
      dungeonquests = function() return { { key = "dq:214", kind = "dungeon", title = "Pick up Red Silk Bandanas for Deadmines", benefit = 0.6 } } end,
      errands = function() return {} end,
      dungeons = function() return {} end,
    }, function()
      local list, excluded = A:Progression(1, game.now)
      T.eq(#list, 1)
      T.eq(list[1].legacyCandidateId, "dq:214", "the better benefit wins")
      T.ok(excluded[1].reason:find("duplicate of", 1, true))
    end)
  end)

  T.it("the current level route step joins as an opportunity", function()
    local game, ns, A = session()
    local L = ns.Modules:Get("LevelRoutes")
    T.ok(L:Create("Test", { { id = "s1", kind = "quest", name = "Kill 10 boars", questID = 300 } }))
    T.ok(L:Start("Test"))
    withSources(ns, { quests = function() return {} end, errands = function() return {} end,
      dungeons = function() return {} end, dungeonquests = function() return {} end }, function()
      local list = A:Progression(1, game.now)
      T.eq(#list, 1)
      T.eq(list[1].title, "Kill 10 boars")
      T.eq(list[1].confidence, "observed")
    end)
  end)

  T.it("real producers run end to end without errors and give only valid records", function()
    local game, ns, A = session()
    local list = A:Progression(1, game.now)
    for _, rec in ipairs(list) do T.ok(ns.Nexus.Validate("Opportunity", rec)) end
    T.eq(#ns.Errors.list, 0)
  end)
end)

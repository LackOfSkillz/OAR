-- OI02-13: confidence and troubleshooting.
local T, mock = ...

local function session(fixtures)
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  local S = ns.WhatNow.SOURCES
  for k in pairs(S) do S[k] = function() return {} end end
  for k, v in pairs(fixtures or {}) do S[k] = v end
  ns.NexusCore:Settings().on = true
  return game, ns, ns.NexusCore
end

local function codes(list)
  local out = {}
  for _, d in ipairs(list) do out[d.code] = d end
  return out
end

T.describe("nexus troubleshooting", function()
  T.it("every rejected step and a missing plan have a reason code and plain text", function()
    local game, ns, N = session({
      gear = function() return { { key = "gear:Big Axe", kind = "gear", title = "Buy Big Axe", benefit = 0.9, costCopper = 900000, label = "observed" } } end,
    })
    game.money = 1000
    N:Replan("test")
    local d = codes(N:Diagnose())
    T.ok(d.over_budget, "the expensive step is explained")
    T.ok(d.over_budget.text:find("1 step left out", 1, true))
    T.ok(d.over_budget.remedy)
    T.ok(d.no_candidates or d.no_plan, "no plan, with a code")
    for _, x in ipairs(N:Diagnose()) do T.ok(type(x.code) == "string" and x.code ~= "" and type(x.text) == "string") end
  end)

  T.it("an error (sources couldn't be read) is told apart from simply nothing to do", function()
    local _, ns, N = session()
    N:Replan("nothing")
    local d = codes(N:Diagnose())
    T.eq(d.all_sources_failed, nil)
    T.eq(d.no_candidates.kind, "info", "nothing to do is not an error")
    local S = ns.WhatNow.SOURCES
    for k in pairs(S) do S[k] = function() error("broken") end end
    ns.Modules:SetEnabled("Handoffs", false)
    ns.NexusAdapters.LevelRouteStep = function() error("broken") end
    ns.NexusAdapters.DealLots = function() error("broken") end
    ns.NexusAdapters.HandoffItems = function() error("broken") end
    N:Replan("broken")
    d = codes(N:Diagnose())
    T.eq(d.source_unavailable.kind, "error")
    T.ok(d.all_sources_failed, "all failed is called a fault")
    T.eq(d.no_candidates.kind, "error", "the missing plan is tied to the fault")
  end)

  T.it("stale plans, uncertain estimates and goal problems are listed; nothing private leaks", function()
    local game, ns, N = session({
      quests = function() return { { key = "quest:X", kind = "quest", title = "Quest X", benefit = 0.7, label = "inferred" } } end,
    })
    game.money = 5000
    ns.NexusGoals:Create("gold", { reserveCopper = 999999 })
    N:Replan("test")
    game:fire("PLAYER_EQUIPMENT_CHANGED")
    local list = N:Diagnose()
    local d = codes(list)
    T.ok(d.stale)
    T.ok(d.uncertain_estimates)
    T.ok(d.goal_reserve_above_gold)
    local name = ns.db.key:match("^[^%-]+")
    for _, x in ipairs(list) do
      T.eq(x.text:find(name, 1, true), nil, "no character name")
      T.eq(x.text:find("5000", 1, true), nil, "no exact gold")
    end
  end)

  T.it("the page shows the troubleshooting section", function()
    local _, ns, N = session()
    N:Replan("x")
    ns.Hub:Build():Show()
    ns.Hub:ShowTab("nexusplan")
    T.eq(#ns.Errors.list, 0)
  end)
end)

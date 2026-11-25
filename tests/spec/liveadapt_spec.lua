-- OI04-04: Horizon live adaptation without thrashing.
local T, mock = ...

local function session()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  local N = ns.NexusCore
  N:Settings().on = true
  local S = ns.WhatNow.SOURCES
  for k in pairs(S) do S[k] = function() return {} end end
  game.bonus = 0
  S.quests = function() return {
    { key = "quest:A", kind = "quest", title = "Quest A", benefit = 0.80, confidence = 0.8, seconds = 300, label = "observed", questID = 1, mapID = 1 },
    { key = "quest:B", kind = "quest", title = "Quest B", benefit = 0.78 + game.bonus, confidence = 0.8, seconds = 300, label = "observed", questID = 2, mapID = 1 },
  } end
  local A = ns.NexusAdapters
  A.LevelRouteStep, A.DealLots, A.HandoffItems = function() return {} end, function() return {} end, function() return {} end
  return game, ns, N
end
local function first(N) return N.current.result.plan.steps[1] end

T.describe("live adaptation (OI04-04)", function()
  T.it("a burst of game events can't re-plan more often than every MIN_GAP seconds", function()
    local game, ns, N = session()
    N:Replan("start")
    local before = N.replans
    for _ = 1, 5 do
      game:fire("BAG_UPDATE_DELAYED")
      game:advance(N.DEBOUNCE + 0.5)
    end
    T.eq(N.replans, before, "inside the gap: nothing yet")
    game:advance(N.MIN_GAP)
    T.eq(N.replans, before + 1, "one re-plan after the gap")
  end)

  T.it("the player's own presses re-plan at once, gap or not", function()
    local game, ns, N = session()
    N:Replan("start")
    local before = N.replans
    ns.NexusGoals:Create("gold", { priority = 1 })
    game:advance(N.DEBOUNCE + 0.5)
    T.eq(N.replans, before + 1)
  end)

  T.it("an automatic re-plan keeps the current first step unless the new plan is clearly better", function()
    local game, ns, N = session()
    N:Replan("start")
    local was = first(N)
    T.ok(was:find("quest:A"))
    game.bonus = 0.03 -- B now slightly better
    N:Replan("BAG_UPDATE_DELAYED")
    T.eq(first(N), was, "a small change doesn't flip the plan")
    T.ok(N.current.result.kept)
    game.bonus = 0.5 -- B now clearly better
    N:Replan("BAG_UPDATE_DELAYED")
    T.ok(first(N):find("quest:B"), "a clear improvement does")
    N:Replan("start")
    game.bonus = 0.03
    N:Replan("button")
    T.ok(first(N):find("quest:B"), "a manual Re-plan takes the best plan freely")
  end)

  T.it("a pinned plan stays unless the pin becomes impossible", function()
    local game, ns, N = session()
    N:Replan("start")
    local pinB
    for id in pairs(N.current.graph.nodes) do if id:find("quest:B") then pinB = id end end
    N:Settings().pinned = pinB
    N:Replan("pin")
    T.eq(first(N), pinB)
    game.bonus = 0.5
    N:Replan("BAG_UPDATE_DELAYED")
    T.eq(first(N), pinB)
    ns.WhatNow.SOURCES.quests = function() return {} end
    local cur = N:Replan("BAG_UPDATE_DELAYED")
    T.eq(cur.result.pin.code, "pin_gone", "infeasible pin: reported, not forced")
  end)

  T.it("Try another start pins the best alternative; with none it says so", function()
    local game, ns, N = session()
    N:Replan("start")
    local was = first(N)
    T.ok(N:UseAlternative())
    T.ok(first(N) ~= was)
    ns.WhatNow.SOURCES.quests = function() return {} end
    N:Replan("button")
    local ok, why = N:UseAlternative()
    T.eq(ok, false) T.ok(why)
  end)

  T.it("combat, pause and late events: nothing during, one re-plan after", function()
    local game, ns, N = session()
    N:Replan("start")
    local before = N.replans
    game.combat = true
    game:fire("PLAYER_EQUIPMENT_CHANGED")
    game:advance(60)
    T.eq(N.replans, before, "nothing in combat")
    game.combat = false
    game:fire("PLAYER_REGEN_ENABLED")
    game:advance(N.MIN_GAP + 5)
    T.eq(N.replans, before + 1, "one after combat")
    N:Pause()
    game:fire("QUEST_TURNED_IN", 1)
    game:advance(60)
    T.eq(N.replans, before + 1, "paused: no re-plan, the plan is just stale")
    T.eq(select(1, N:IsStale()), true)
    N:Resume()
    game:advance(N.DEBOUNCE + 0.5)
    T.eq(N.replans, before + 2)
  end)
end)

-- OI02-11: invalidation and the execution boundary.
local T, mock = ...

local function session()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  local N = ns.NexusCore
  N:Settings().on = true
  -- fixed producers so plans are predictable; go() is a spy
  local calls = { go = 0 }
  local S = ns.WhatNow.SOURCES
  for k in pairs(S) do S[k] = function() return {} end end
  S.quests = function() return {
    { key = "quest:A", kind = "quest", title = "Quest A", benefit = 0.9, confidence = 0.8, seconds = 300, label = "observed", questID = 1,
      go = function() calls.go = calls.go + 1 end },
    { key = "quest:B", kind = "quest", title = "Quest B", benefit = 0.6, confidence = 0.8, seconds = 300, label = "observed", questID = 2,
      go = function() calls.go = calls.go + 1 end },
    { key = "errand:C", kind = "errand", title = "Errand C", benefit = 0.5, confidence = 0.8, seconds = 60, label = "observed", panel = "home" },
  } end
  return game, ns, N, calls
end

T.describe("nexus core: invalidation and execution boundary", function()
  T.it("off by default; plans only when switched on", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    T.eq(ns.NexusCore:Settings().on, false)
    T.eq(ns.NexusCore:Replan("x"), nil)
  end)

  T.it("planning never acts: go() runs only on Act (the player's click)", function()
    local _, _, N, calls = session()
    local cur = N:Replan("test")
    T.ok(cur.result.plan, "a plan")
    T.eq(calls.go, 0, "evaluating the plan ran no action")
    local first = cur.result.plan.steps[1]
    local ok, kind = N:Act(first)
    T.ok(ok) T.eq(kind, "waypoint")
    T.eq(calls.go, 1)
  end)

  T.it("a burst of events makes one re-plan after the debounce", function()
    local game, _, N = session()
    N:Replan("start")
    local before = N.replans
    for _ = 1, 10 do game:fire("BAG_UPDATE_DELAYED") game:fire("PLAYER_MONEY") end
    T.eq(N.replans, before, "nothing yet")
    -- automatic re-plans keep MIN_GAP from the last one (OI04-04)
    game:advance(N.MIN_GAP + 1)
    T.eq(N.replans, before + 1, "one re-plan for the whole burst")
  end)

  T.it("in combat nothing is planned; the request runs after combat", function()
    local game, _, N = session()
    N:Replan("start")
    local before = N.replans
    game.combat = true
    game:fire("PLAYER_EQUIPMENT_CHANGED")
    game:advance(5)
    T.eq(N.replans, before, "no planning in combat")
    game.combat = false
    game:fire("PLAYER_REGEN_ENABLED")
    game:advance(N.MIN_GAP + 1)
    T.eq(N.replans, before + 1)
  end)

  T.it("changed gear makes the plan stale; a stale plan won't act", function()
    local game, _, N = session()
    local cur = N:Replan("start")
    T.eq(N:IsStale(), false)
    game:fire("PLAYER_EQUIPMENT_CHANGED")
    local stale, why = N:IsStale()
    T.ok(stale) T.ok(why:find("changed", 1, true))
    local ok, msg = N:Act(cur.result.plan.steps[1])
    T.eq(ok, false) T.eq(msg, why)
    T.ok(N:IsStale(game.now + N.MAX_AGE + 1))
  end)

  T.it("pin, skip, pause and resume steer the plan and persist", function()
    local game, ns, N = session()
    N:Replan("start")
    local steps = N.current.result.plan.steps
    local last = steps[#steps]
    N:Pin(last)
    N:Replan("pin")
    T.eq(N.current.result.plan.steps[1], last, "pinned step first")
    N:Unpin()
    N:Skip(steps[1])
    N:Replan("skip")
    for _, s in ipairs(N.current.result.plan.steps) do T.ok(s ~= steps[1], "skipped step left out") end
    N:Pause()
    local cur = N.current
    N:Replan("paused")
    T.ok(N.current == cur, "no re-planning while paused")
    N:Resume()
    T.eq(N:Settings().paused, false)
    T.ok(N:Settings().skipped[steps[1]], "skips saved per character")
  end)

  T.it("a late event after disable or logout does nothing", function()
    local game, ns, N = session()
    N:Replan("start")
    local before = N.replans
    ns.Modules:Disable(N)
    game:fire("PLAYER_MONEY")
    game:advance(5)
    T.eq(N.replans, before)
    T.eq(N.current, nil)
    ns.Modules:Enable(N)
    N:Replan("again")
    game:fire("PLAYER_LOGOUT")
    T.eq(N.current, nil, "nothing kept past logout")
    T.eq(#ns.Errors.list, 0)
  end)
end)

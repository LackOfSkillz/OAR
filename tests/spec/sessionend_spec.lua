-- OI04-03: ending the session well.
local T, mock = ...

local function session()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  local N = ns.NexusCore
  N:Settings().on = true
  local S = ns.WhatNow.SOURCES
  for k in pairs(S) do S[k] = function() return {} end end
  S.quests = function() return {
    { key = "quest:Long", kind = "quest", title = "A long quest", benefit = 0.9, confidence = 0.8, seconds = 600, estimatedActivitySeconds = 900,
      label = "observed", questID = 1, mapID = 1, go = function() end },
  } end
  local A = ns.NexusAdapters
  A.LevelRouteStep, A.DealLots, A.HandoffItems = function() return {} end, function() return {} end, function() return {} end
  ns.Nearest.Find = function(_, kind) return { mapID = 1, x = 0.5, y = 0.5, name = kind }, 700 end -- 100 s away on foot
  return game, ns, N, ns.SessionEnd
end

T.describe("session ending (OI04-03)", function()
  T.it("the reserve counts repairs, finished quests and the rest point", function()
    local game, ns, N, E = session()
    ns.Errands.Durability = function() return 0.2 end
    game.questLog = { { questID = 5, complete = true }, { questID = 6, complete = false }, { questID = 7, complete = true } }
    ns.NexusHorizon.Set(N, { minutes = 60, group = "either", stopRest = true })
    local total, parts = E.Reserve(ns.NexusHorizon.Get(N))
    T.eq(total, (100 + 60) + 2 * E.HANDIN_EACH + (100 + 30))
    T.eq(#parts, 3)
  end)

  T.it("the planner's budget is the time left minus the reserve", function()
    local game, ns, N, E = session()
    ns.NexusHorizon.Set(N, { minutes = 60, group = "either" })
    game:advance(1200)
    local ctx = N:Context()
    T.eq(ctx.budgetSeconds, 2400)
    T.ok(not ctx.closing)
  end)

  T.it("near the end only closing steps are planned, and a long step is never started", function()
    local game, ns, N, E = session()
    ns.Errands.Durability = function() return 0.2 end
    game.questLog = { { questID = 5, complete = true } }
    ns.NexusHorizon.Set(N, { minutes = 60, group = "either", stopRest = true })
    game:advance(3600 - 500)
    local cur = N:Replan("x")
    T.ok(cur.result.closing)
    for _, id in ipairs(cur.result.plan.steps) do
      T.ok(id:find("close:"), "closing steps only: " .. id)
      T.ok(not id:find("Long"))
    end
    T.ok(cur.result.bufferedSeconds <= 500, "fits the time left with the margin")
  end)

  T.it("with no time left for anything it says it's a good moment to stop", function()
    local game, ns, N = session()
    ns.NexusHorizon.Set(N, { minutes = 30, group = "either" })
    game:advance(30 * 60 - 20)
    local cur = N:Replan("x")
    T.eq(cur.result.plan, nil)
    T.eq(cur.result.code, "session_over")
    T.ok(cur.result.why:find("good moment to stop"))
  end)

  T.it("a short session isn't closing from the start; nothing logs out or acts", function()
    local game, ns, N, E = session()
    ns.NexusHorizon.Set(N, { minutes = 15, group = "either" })
    T.ok(not N:Context().closing)
    local fh = assert(io.open("addon/Outrider/Intelligence/SessionEnd.lua"))
    local code = fh:read("*a"):gsub("%-%-[^\n]*", "")
    fh:close()
    T.ok(not code:find("Logout") and not code:find("Quit"), "no logout")
    T.ok(not code:find("CastSpell") and not code:find("UseItem"), "no actions")
  end)

  T.it("changing the session length restarts the clock", function()
    local game, ns, N = session()
    ns.NexusHorizon.Set(N, { minutes = 60, group = "either" })
    game:advance(1800)
    ns.NexusHorizon.Set(N, { minutes = 60, group = "solo" })
    T.eq(N:Context().budgetSeconds, 1800, "same length: the clock carries on")
    ns.NexusHorizon.Set(N, { minutes = 30, group = "solo" })
    T.eq(N:Context().budgetSeconds, 1800, "a new length starts again")
  end)
end)

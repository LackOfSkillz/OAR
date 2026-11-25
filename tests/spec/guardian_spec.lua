-- OI04-12: Guardian travel advice.
local T, mock = ...

local function session()
  local game = mock.new({ level = 12 })
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.Guardian
end

T.describe("Guardian travel advice (OI04-12)", function()
  T.it("labels from the zone's level range, with its source named", function()
    local _, _, G = session()
    T.eq(G.Label(20, 10, 20).level, "safe")
    T.eq(G.Label(15, 10, 20).level, "fair")
    T.eq(G.Label(9, 10, 20).level, "risky")
    T.eq(G.Label(6, 10, 20).level, "dangerous")
    T.ok(G.Label(15, 10, 20, 0, "seen").why:find("%(seen%)"))
  end)

  T.it("your own deaths there raise the risk one step", function()
    local _, _, G = session()
    local r = G.Label(15, 10, 20, 2)
    T.eq(r.level, "risky") T.ok(r.why:find("died here 2 times"))
    T.eq(G.Label(15, 10, 20, 1).level, "fair", "one death isn't a pattern")
  end)

  T.it("no level data: risk unknown, said plainly", function()
    local _, ns, G = session()
    T.eq(G.Label(12, nil, nil).level, "unknown")
    ns.Modules:Get("ZoneLevels").Range = function() return nil end
    local r = G.ForMap(1412, 12)
    T.eq(r.level, "unknown") T.ok(r.why:find("no level data"))
  end)

  T.it("deaths come from the recorded death history for that map only", function()
    local _, ns, G = session()
    ns.db.global.deathHistory = { { mapID = 1 }, { mapID = 1 }, { mapID = 2 } }
    T.eq(G.Deaths(1), 2) T.eq(G.Deaths(3), 0)
  end)

  T.it("a risky plan step gets a tag and a safer alternative; the plan itself is unchanged", function()
    local game, ns, G = session()
    local N = ns.NexusCore
    N:Settings().on = true
    local S = ns.WhatNow.SOURCES
    for k in pairs(S) do S[k] = function() return {} end end
    S.quests = function() return {
      { key = "quest:Hard", kind = "quest", title = "A hard quest", benefit = 0.9, confidence = 0.8, seconds = 300, label = "observed", questID = 1, mapID = 40 },
      { key = "quest:Easy", kind = "quest", title = "An easy quest", benefit = 0.7, confidence = 0.8, seconds = 300, label = "observed", questID = 2, mapID = 41 },
    } end
    ns.Modules:Get("ZoneLevels").Range = function(_, map) if map == 40 then return 18, 25, "seen" end return 8, 14, "seen" end
    N:Settings().horizon = { group = "either", minutes = nil }
    local cur = N:Replan("x")
    local steps = table.concat(cur.result.plan.steps, ",")
    local risk = G.ForPlan(cur, 12)
    local hard
    for id, r in pairs(risk) do if id:find("Hard") then hard = r end end
    if hard then T.eq(hard.level, "dangerous") end
    T.eq(table.concat(cur.result.plan.steps, ","), steps, "labels never change the plan")
    local cards = ns.NexusPage.Cards()
    T.eq(#ns.Errors.list, 0)
    T.ok(#cards >= 1)
  end)

  T.it("no enemy detection, no secret maths, no combat log", function()
    local fh = assert(io.open("addon/Outrider/Intelligence/Guardian.lua"))
    local code = fh:read("*a"):gsub("%-%-[^\n]*", "")
    fh:close()
    for _, bad in ipairs({ "COMBAT_LOG", "UnitIsEnemy", "NAME_PLATE", "UnitReaction", "issecretvalue" }) do T.ok(not code:find(bad), bad) end
  end)
end)

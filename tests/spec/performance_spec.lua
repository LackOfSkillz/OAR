-- OI03-07: performance and survival observations.
local T, mock = ...

local function session(meter)
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  if meter then
    game.env.C_DamageMeter = {
      GetAvailableCombatSessions = function() return game.meterSessions or {} end,
      GetCombatSessionFromID = function(id) return game.meter and game.meter[id] end,
    }
  end
  ns.Modules:SetEnabled("FightMeter", true)
  return game, ns, ns.PerformanceStats
end
local function fight(game, id, mine, secs)
  game.meterSessions = game.meterSessions or {}
  table.insert(game.meterSessions, { sessionID = id, name = "Fight " .. id })
  game.meter = game.meter or {}
  game.meter[id] = { durationSeconds = secs, totalAmount = mine,
    combatSources = { { name = "Torrant", totalAmount = mine, isLocalPlayer = true } } }
end
local function row(talents, build, dps, extra)
  local r = { player = dps * 10, duration = 10, context = { level = 12, talents = talents, build = build, grouped = false } }
  for k, v in pairs(extra or {}) do r[k] = v end
  return r
end

T.describe("performance and survival (OI03-07)", function()
  T.it("a captured fight carries its context: level, talent build, game build, group, session", function()
    local game, ns = session(true)
    fight(game, 1, 300, 10)
    ns.FightMeter:Capture()
    local h = ns.FightMeter:History()
    local ctx = h[#h].context
    T.ok(type(ctx.level) == "number", "level")
    T.ok(ctx.build, "game build")
    T.eq(ctx.grouped, false)
    T.eq(ctx.playSessionId, ns.PlaySession:Id())
  end)

  T.it("in combat, with no meter, or with no readable result nothing is stored; the reason is counted", function()
    local game, ns = session(false)
    ns.FightMeter:Capture() -- no meter at all: no sessions, nothing stored
    T.eq(#ns.FightMeter:History(), 0)
    local g2, ns2 = session(true)
    g2.combat = true
    ns2.FightMeter:Capture()
    T.eq(ns2.FightMeter.excluded["combat still active"], 1)
    g2.combat = false
    g2.meterSessions = { { sessionID = 9 } }
    g2.meter = { [9] = { durationSeconds = 0, totalAmount = 5 } }
    ns2.FightMeter:Capture()
    T.eq(ns2.FightMeter.excluded["session values restricted"], 1)
    T.eq(#ns2.FightMeter:History(), 0)
  end)

  T.it("fights are grouped by talent and game build; old rows without context are excluded", function()
    local _, _, P = session()
    local rows = { { player = 100, duration = 10 } }
    for i = 1, 5 do rows[#rows + 1] = row("31/0/0", "70862", 20 + i) end
    rows[#rows + 1] = row("0/31/0", "70862", 50)
    rows[#rows + 1] = row("31/0/0", "70862", 0)
    local f = P.Fights(rows)
    T.eq(#f.strata, 2)
    T.eq(f.excluded["no context (recorded before OI03-07)"], 1)
    T.eq(f.excluded["no readable amount for you"], 1)
    local a
    for _, s in ipairs(f.strata) do if s.talents == "31/0/0" then a = s end end
    T.eq(a.n, 5) T.ok(a.enough) T.eq(a.median, 23)
  end)

  T.it("a respec or a new game build is never compared with the old one", function()
    local _, _, P = session()
    local base = { talents = "31/0/0", build = "1", median = 20, enough = true }
    T.eq(select(2, P.Compare(base, { talents = "0/31/0", build = "1", median = 30, enough = true })), "different talent builds")
    T.eq(select(2, P.Compare(base, { talents = "31/0/0", build = "2", median = 30, enough = true })), "different game builds")
    T.eq(select(2, P.Compare(base, { talents = "31/0/0", build = "1", median = 30, enough = false })), "not enough fights")
    T.eq(P.Compare(base, { talents = "31/0/0", build = "1", median = 30, enough = true }), 0.5)
  end)

  T.it("survival: deaths, time to get back, and deaths per hour only with enough play", function()
    local _, _, P = session()
    local ev = { { kind = "death", at = 100 }, { kind = "recovery", at = 160 }, { kind = "death", at = 500 }, { kind = "recovery", at = 620 },
      { kind = "death", at = 900 } }
    local s = P.Survival(ev, 3600)
    T.eq(s.deaths, 3) T.eq(s.recoveries, 2) T.eq(s.medianRecovery, 90) T.eq(s.stillDead, true)
    T.eq(s.deathsPerHour, 3)
    local short = P.Survival(ev, 600)
    T.eq(short.deathsPerHour, nil) T.ok(short.perHourWhy)
  end)

  T.it("no combat log anywhere in the stats or the meter reader", function()
    for _, path in ipairs({ "addon/Outrider/Intelligence/PerformanceStats.lua", "addon/Outrider/Modules/FightMeter.lua" }) do
      local fh = assert(io.open(path))
      local code = fh:read("*a"):gsub("%-%-[^\n]*", "")
      fh:close()
      T.ok(not code:find("COMBAT_LOG"), path)
    end
  end)
end)

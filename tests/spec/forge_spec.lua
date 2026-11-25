-- OI05-03..09 the Forge: combat model, timing, damage ranges, roles, runner, comparison, dummy calibration.
local T, mock = ...

local function session()
  local game = mock.new({ level = 30, class = "HUNTER" })
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.Forge
end

T.describe("Forge model and timing (OI05-03, OI05-04)", function()
  T.it("an ability keeps its tooltip source; unmodelled mechanics are listed", function()
    local _, _, F = session()
    local a = F.Ability({ name = "Arcane Shot", avg = 50, cd = 6, cost = 25, resource = "MANA" })
    T.eq(a.source, "tooltip") T.eq(a.cost, 25)
    T.ok(table.concat(F.NOT_MODELLED, "|"):find("procs"))
    T.eq(F.Ability(nil), nil)
  end)

  T.it("the timeline honours the global cooldown, cast times and cooldowns", function()
    local _, _, F = session()
    local tl = F.Timeline({ { name = "Big", avg = 100, cd = 10 }, { name = "Filler", avg = 10, cast = 2.5 } }, { fight = 30 })
    T.eq(tl.casts.Big, 3, "every 10 s in 30 s")
    T.ok(tl.casts.Filler >= 10 and tl.casts.Filler <= 11, tostring(tl.casts.Filler))
    T.ok(tl.steps < F.MAX_STEPS)
  end)

  T.it("a damage over time isn't recast while it ticks, and counts only the part inside the fight", function()
    local _, _, F = session()
    local tl = F.Timeline({ { name = "Sting", avg = 120, dot = 15 } }, { fight = 20 })
    T.eq(tl.casts.Sting, 2)
    T.ok(math.abs(tl.damage - (120 + 120 * 5 / 15)) < 0.01, tostring(tl.damage))
  end)

  T.it("mana runs out when pool and regen are known; otherwise it is reported as not modelled", function()
    local _, _, F = session()
    local ab = { { name = "Bolt", avg = 30, cost = 50 } }
    local tl = F.Timeline(ab, { fight = 60, pool = 200, regen = 5 })
    T.ok(tl.outOfManaAt and tl.outOfManaAt < 60)
    local free = F.Timeline(ab, { fight = 60 })
    T.ok(free.notes[1]:find("not modelled"))
    T.ok(free.damage > tl.damage)
  end)

  T.it("the runner is bounded, deterministic and refuses in combat", function()
    local game, _, F = session()
    local opts = { abilities = { { name = "Zero", avg = 1, cd = 0 } }, fight = 100000 }
    local r1, r2 = F.Run(opts), F.Run(opts)
    T.ok(r1.timeline.bounded)
    T.eq(r1.damage.hi, r2.damage.hi)
    game.combat = true
    T.eq(select(2, F.Run(opts)), "not in combat")
  end)
end)

T.describe("Forge damage, roles, comparison and calibration (OI05-05..09)", function()
  T.it("unknown hit and armour widen the low end; resistance is named, not applied", function()
    local _, _, F = session()
    local r = F.Range(100, { physical = true })
    T.eq(r.hi, 100) T.ok(r.lo < 100 * (1 - F.MISS_WIDEN))
    T.eq(#r.why, 2)
    local s = F.Range(100, { resistable = true, hitKnown = true })
    T.eq(s.lo, 100) T.ok(s.why[1]:find("resistance"))
  end)

  T.it("healing, sustain and survival are separate results; incoming damage is an assumption", function()
    local _, _, F = session()
    local r = F.Run({ abilities = { { name = "Heal", avg = 200, heal = true, cast = 3, cost = 60 } }, fight = 60,
      pool = 1000, regen = 4, hp = 1500, armor = 1000, avoid = 0.1, level = 30 })
    T.ok(r.healing.perSecond > 0) T.eq(r.damage, nil)
    T.ok(r.sustain.seconds or r.sustain.forever)
    T.eq(#r.survival.rows, #F.ASSUMED_INCOMING)
    T.ok(r.survival.assumption:find("assumed") and r.survival.armorNote:find("unverified"))
    T.ok(F.Survival(nil).unknown)
  end)

  T.it("comparison keeps eligibility, ownership and respec cost apart and lists the limits", function()
    local _, _, F = session()
    local c = F.Compare({ label = "now", opts = { abilities = { { name = "A", avg = 50 } } }, owned = true },
      { label = "build B", opts = { abilities = { { name = "A", avg = 70 } } }, eligible = false })
    T.ok(c.rows[1].b[2] > c.rows[1].a[2])
    T.eq(c.aOwned, true) T.eq(c.bEligible, false)
    T.ok(c.bRespec:find("unknown"))
    T.ok(#c.limits > 0)
  end)

  T.it("dummy calibration matches like for like and won't judge from one fight", function()
    local _, _, F = session()
    local est = { lo = 40, hi = 60 }
    local fights = { { dps = 50, build = "x", duration = 60 }, { dps = 52, build = "x", duration = 55 },
      { dps = 90, build = "y", duration = 60 }, { dps = 48, build = "x", duration = 200 } }
    T.ok(F.Calibrate(est, fights, { build = "x", fight = 60 }).verdict:find("not enough"))
    fights[#fights + 1] = { dps = 55, build = "x", duration = 65 }
    local c = F.Calibrate(est, fights, { build = "x", fight = 60 })
    T.eq(c.n, 3) T.eq(c.measured, 52) T.eq(c.inside, true)
    T.eq(F.Calibrate(est, {}, {}).verdict, "no matching dummy fight yet")
  end)

  T.it("live inputs fail soft when the client has no numbers", function()
    local _, ns, F = session()
    local live = F.Live("ranged")
    T.eq(type(live.abilities), "table")
    local r = F.Run(live)
    T.ok(r and r.version == F.VERSION)
    T.eq(#ns.Errors.list, 0)
  end)
end)

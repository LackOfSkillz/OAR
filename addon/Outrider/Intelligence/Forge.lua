-- Intelligence/Forge.lua  (OI05-03 .. OI05-09)
-- A versioned combat model on top of TalentSim (Modules/TalentSim.lua), which
-- already reads each spell's numbers from the client's own tooltip, removes
-- your current talents before applying a build's, adds auto attack and keeps
-- training-dummy results. The Forge adds, without inventing coefficients
-- (hard rule 7): only client-readable values or cited facts; anything else is
-- listed as not modelled, and makes the result a range or a partial report.
--   OI05-03 model   Ability(spell): cast, cooldown, average amount, damage over
--                   time, healing, resource cost and type (C_Spell.GetSpellPowerCost),
--                   source = "tooltip"; a model carries its version and the
--                   mechanics it does NOT model.
--   OI05-04 timing  Timeline(abilities, opts): global cooldown, cast times,
--                   cooldowns, periodic ticks, and mana when the pool and the
--                   regen are known (GetManaRegen); rage, energy and combo points
--                   aren't readable as rates here, so they are "not modelled"
--                   (never a silent default).
--   OI05-05 damage  crit from the client (GetCritChance / GetSpellCritChance); hit,
--                   resistances and target armour aren't known for a target, so
--                   the result is a range: up to MISS_WIDEN lower when hit is
--                   unknown, ARMOR_WIDEN lower for physical damage when armour is.
--   OI05-06 roles   separate results, never one score: damage per second,
--                   healing per second with how long the mana lasts, and
--                   survival (health, armour, avoidance) as time to die at a few
--                   assumed incoming damage rates, the assumption shown.
--   OI05-07 runner  Run(): deterministic (no randomness), bounded steps, never
--                   in combat, a partial report for anything unsupported.
--   OI05-08 compare Compare(a, b): two builds or weapons on the same model;
--                   eligibility and ownership kept apart; respec cost unknown
--                   unless given; nothing is spent or equipped.
--   OI05-09 dummy   Calibrate(estimate, measured): only like for like (same build
--                   key, fight length within 30%, same buff count); one fight
--                   is "not enough to judge" (MIN_DUMMY).

local _, ns = ...
local C = ns.Compat
local F = { VERSION = "forge-1", GCD = 1.5, TICK = 3, FIGHT = 60, MAX_STEPS = 1000,
  MISS_WIDEN = 0.09, ARMOR_WIDEN = 0.35, MIN_DUMMY = 3, SPELL_CRIT = 0.5, MELEE_CRIT = 1.0 }
ns.Forge = F
F.NOT_MODELLED = { "procs", "talents that add or change spells", "hit and miss on the target", "target resistances",
  "target armour", "rage, energy and combo points as rates", "haste changes during the fight", "buffs and debuffs from others" }

-- OI05-03: one ability from a TalentSim spell plus its resource cost
function F.Ability(s)
  if type(s) ~= "table" then return nil end
  local a = { name = s.name, id = s.id, cast = s.cast or 0, cd = s.cd or 0, avg = s.avg, dot = s.dot, heal = s.heal,
    source = "tooltip", physical = s.physical }
  if s.id then
    local costs = C.Call("C_Spell.GetSpellPowerCost", s.id)
    local c = type(costs) == "table" and costs[1]
    if type(c) == "table" then a.cost, a.resource = tonumber(C.Readable(c.cost)), C.Readable(c.name) end
  end
  if a.cost == nil and s.cost then a.cost, a.resource = s.cost, s.resource end
  return a
end

-- OI05-04: the timeline. abilities in priority order; opts { fight, gcd, pool, regen, resource }
function F.Timeline(abilities, opts)
  opts = opts or {}
  local fight = opts.fight or F.FIGHT
  local gcd = opts.gcd or F.GCD
  local t, steps, total, healed, spent = 0, 0, 0, 0, 0
  local ready, ticking, casts, ticks = {}, {}, {}, 0
  local pool, regen = opts.pool, opts.regen
  local modelMana = pool ~= nil and regen ~= nil and (opts.resource == nil or opts.resource == "MANA" or opts.resource == "mana")
  local notes, oom = {}, nil
  local mana = pool
  while t < fight and steps < F.MAX_STEPS do
    steps = steps + 1
    local pick
    for _, a in ipairs(abilities) do
      if a.avg and a.avg > 0 and (ready[a.name] or 0) <= t and (not a.dot or (ticking[a.name] or 0) <= t) then
        if not modelMana or not a.cost or a.cost <= mana then pick = a break end
      end
    end
    if not pick then
      local nextT
      for _, a in ipairs(abilities) do
        local w = math.max(ready[a.name] or 0, a.dot and (ticking[a.name] or 0) or 0)
        if a.avg and w > t and (not nextT or w < nextT) then nextT = w end
      end
      if modelMana and regen > 0 then
        -- out of mana: wait until the cheapest spell is affordable
        local cheapest
        for _, a in ipairs(abilities) do if a.cost and (not cheapest or a.cost < cheapest) then cheapest = a.cost end end
        if cheapest and mana < cheapest then
          local w = t + (cheapest - mana) / regen
          if not nextT or w < nextT then nextT = w end
          oom = oom or t
        end
      end
      if not nextT or nextT >= fight then break end
      if modelMana then mana = math.min(pool, mana + regen * (nextT - t)) end
      t = nextT
    else
      local took = math.max(gcd, pick.cast or 0)
      local amount = pick.avg
      if pick.dot then
        local share = math.min(1, (fight - t) / pick.dot)
        amount = amount * share
        ticks = ticks + math.floor(math.min(pick.dot, fight - t) / F.TICK)
        ticking[pick.name] = t + pick.dot
      end
      if pick.heal then healed = healed + amount else total = total + amount end
      casts[pick.name] = (casts[pick.name] or 0) + 1
      if (pick.cd or 0) > 0 then ready[pick.name] = t + pick.cd end
      if modelMana and pick.cost then mana = mana - pick.cost spent = spent + pick.cost end
      if modelMana then mana = math.min(pool, mana + regen * took) end
      t = t + took
    end
  end
  if not modelMana then
    local uses = false
    for _, a in ipairs(abilities) do if a.cost and a.cost > 0 then uses = true end end
    if uses then notes[#notes + 1] = "resource not modelled: cost known, but the pool or the regen isn't" end
  end
  return { damage = total, healing = healed, casts = casts, ticks = ticks, steps = steps, fight = fight,
    manaSpent = modelMana and spent or nil, outOfManaAt = oom, bounded = steps >= F.MAX_STEPS or nil, notes = notes }
end

-- OI05-05: amount per second as a range, with the reasons it is one
function F.Range(perSec, opts)
  opts = opts or {}
  local lo, why = perSec, {}
  if not opts.hitKnown then lo = lo * (1 - F.MISS_WIDEN) why[#why + 1] = "hit chance on the target unknown" end
  if opts.physical and not opts.armorKnown then lo = lo * (1 - F.ARMOR_WIDEN) why[#why + 1] = "target armour unknown" end
  if opts.resistable and not opts.resistKnown then why[#why + 1] = "target resistance unknown (not reduced)" end
  return { lo = lo, hi = perSec, why = why }
end

-- OI05-06: survival as time to die at assumed incoming damage rates
F.ASSUMED_INCOMING = { 20, 50, 100 }
function F.Survival(hp, armor, avoid, level)
  if not hp then return { unknown = "health not readable" } end
  local out = { hp = hp, avoid = avoid or 0, rows = {} }
  -- armour reduction for an equal-level attacker: Classic formula, unverified on Forever
  if armor and level then
    local red = armor / (armor + 400 + 85 * level)
    out.armorReduction = math.min(0.75, red)
    out.armorNote = "Classic armour formula, unverified on Forever"
  end
  for _, dps in ipairs(F.ASSUMED_INCOMING) do
    local eff = dps * (1 - (out.armorReduction or 0)) * (1 - math.min(0.75, out.avoid))
    out.rows[#out.rows + 1] = { incoming = dps, seconds = eff > 0 and hp / eff or nil }
  end
  out.assumption = "incoming damage is assumed (enemy damage unknown); the rows show a few rates"
  return out
end
function F.Sustain(pool, regen, spentPerSec)
  if not (pool and regen and spentPerSec) then return { unknown = "mana pool, regen or spending unknown" } end
  local net = spentPerSec - regen
  if net <= 0 then return { forever = true } end
  return { seconds = pool / net }
end

-- OI05-07: the runner. opts { abilities, fight, pool, regen, critMelee, critSpell, hp, armor, avoid, level }
function F.Run(opts)
  opts = opts or {}
  if C.InCombat() then return nil, "not in combat" end
  local rep = { version = F.VERSION, notModelled = F.NOT_MODELLED, partial = {} }
  local abilities = opts.abilities or {}
  if #abilities == 0 then rep.partial[#rep.partial + 1] = "no spell with a number in its tooltip: damage and healing unknown" end
  local tl = F.Timeline(abilities, opts)
  rep.timeline = tl
  for _, n in ipairs(tl.notes) do rep.partial[#rep.partial + 1] = n end
  local crit = (opts.critSpell or 0) / 100
  local dps = tl.damage / tl.fight * (1 + crit * F.SPELL_CRIT)
  local physical = false
  for _, a in ipairs(abilities) do if a.physical then physical = true end end
  if tl.damage > 0 then rep.damage = F.Range(dps, { physical = physical, resistable = not physical }) end
  if tl.healing > 0 then
    rep.healing = { perSecond = tl.healing / tl.fight * (1 + crit * F.SPELL_CRIT) }
    rep.sustain = F.Sustain(opts.pool, opts.regen, tl.manaSpent and tl.manaSpent / tl.fight or nil)
  end
  rep.survival = F.Survival(opts.hp, opts.armor, opts.avoid, opts.level)
  return rep
end

-- OI05-08: compare two option sets on the same model; eligibility and
-- ownership are separate facts passed in, nothing is spent or equipped
function F.Compare(a, b)
  local ra, rb = F.Run(a.opts), F.Run(b.opts)
  if not (ra and rb) then return nil, "not in combat" end
  local out = { a = a.label, b = b.label, rows = {} }
  local function row(name, x, y, note) out.rows[#out.rows + 1] = { name = name, a = x, b = y, note = note } end
  row("damage per second (low to high)", ra.damage and { ra.damage.lo, ra.damage.hi }, rb.damage and { rb.damage.lo, rb.damage.hi })
  row("healing per second", ra.healing and ra.healing.perSecond, rb.healing and rb.healing.perSecond)
  for _, side in ipairs({ { a, "a" }, { b, "b" } }) do
    local o = side[1]
    out[side[2] .. "Eligible"] = o.eligible ~= false
    out[side[2] .. "Owned"] = o.owned == true
    out[side[2] .. "Respec"] = o.respecCost or "respec cost unknown (ask your class trainer)"
  end
  out.limits = F.NOT_MODELLED
  return out
end

-- OI05-09: dummy calibration, like for like only
function F.Calibrate(estimate, fights, cond)
  cond = cond or {}
  local match = {}
  for _, f in ipairs(fights or {}) do
    local okBuild = cond.build == nil or f.build == cond.build
    local okLen = not cond.fight or (f.duration and math.abs(f.duration - cond.fight) <= cond.fight * 0.3)
    local okBuffs = cond.buffs == nil or f.buffs == cond.buffs
    if okBuild and okLen and okBuffs and tonumber(f.dps) then match[#match + 1] = f.dps end
  end
  if #match < F.MIN_DUMMY then
    return { n = #match, verdict = #match == 0 and "no matching dummy fight yet" or "not enough to judge (" .. #match .. " fight" .. (#match == 1 and "" or "s") .. ")" }
  end
  table.sort(match)
  local med = match[math.floor((#match + 1) / 2)]
  local inside = estimate and estimate.lo and med >= estimate.lo and med <= estimate.hi
  return { n = #match, measured = med, inside = inside or false,
    verdict = inside and "your dummy fights fall inside the estimate" or "your dummy fights fall outside the estimate: the model misses something" }
end

-- live inputs for the runner, from the client and TalentSim
function F.Live(kind)
  local T = ns.TalentSim
  local abilities = {}
  for _, name in ipairs(T and T.KeySpells and T.KeySpells(kind or "ranged") or {}) do
    local a = F.Ability(T.Spell(name))
    if a and a.avg then abilities[#abilities + 1] = a end
  end
  local pool = tonumber(C.Readable(C.Call("UnitPowerMax", "player", 0)))
  local regen = tonumber(C.Readable((C.Call("GetManaRegen"))))
  return { abilities = abilities, pool = pool and pool > 0 and pool or nil, regen = regen,
    critSpell = tonumber(C.Readable(C.Call("GetSpellCritChance", 2))) or 0,
    hp = tonumber(C.Readable(C.Call("UnitHealthMax", "player"))),
    armor = tonumber(C.Readable((select(2, C.Call("UnitArmor", "player"))))),
    avoid = ((tonumber(C.Readable(C.Call("GetDodgeChance"))) or 0) + (tonumber(C.Readable(C.Call("GetParryChance"))) or 0)) / 100,
    level = tonumber(C.Readable(C.Call("UnitLevel", "player"))) }
end

-- Fight macros for warrior, rogue, warlock, druid, paladin and shaman: built
-- from known spells only, ordered once-per-pull -> cooldowns -> filler, rewritten
-- when spells, gear, buffs or forms change. Spell lists here are test data.
local T, mock = ...

local function sp(...)
  local out = {}
  for i, n in ipairs({ ... }) do out[i] = { name = n, id = 8000 + i } end
  return out
end

local function session(class, level, spells, opts)
  local game = mock.new({ class = class, level = level })
  game.spells = spells
  game.items = { [100] = { name = "Big Axe", equipLoc = "INVTYPE_2HWEAPON" }, [101] = { name = "Wand", equipLoc = "INVTYPE_RANGEDRIGHT" } }
  game.worn = (opts and opts.worn) or {}
  game.forms = opts and opts.forms
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  -- these pin the hand-built fallback orders; the research plans have their own spec
  ns.Modules:SetEnabled("FightPlan", false)
  game:advance(3)
  game:slash("fight")
  game:advance(3)
  return game, ns
end

local function macro(game, name)
  for _, m in ipairs(game.macros) do if m.name == name then return m.body end end
  return ""
end

local function before(body, a, b)
  local x, y = body:find(a, 1, true), body:find(b, 1, true)
  return x and y and x < y
end

T.describe("fight macros for every class", function()
  T.it("warrior: Charge, Shout, Rend once, Mortal Strike, Heroic Strike; key 2 the reactive strikes", function()
    local game, ns = session("WARRIOR", 30, sp("Charge", "Battle Shout", "Rend", "Mortal Strike", "Heroic Strike",
      "Overpower", "Execute", "Thunder Clap"))
    local f = macro(game, "Fight")
    T.contains(f, "/cast [nocombat] Charge")
    T.contains(f, "/cast [mod:alt] Battle Shout")
    T.contains(f, "/castsequence reset=combat/target Rend,Heroic Strike,Heroic Strike")
    T.ok(not f:find(",null", 1, true), "no ,null (it wraps on Forever)")
    T.ok(before(f, "Mortal Strike", "Rend,"), "cooldown above the Rend and Heroic Strike loop")
    local s = macro(game, "Strike")
    T.ok(before(s, "Overpower", "Thunder Clap"))
    T.contains(s, "/cast Execute")
    T.ok(#f <= 255 and #s <= 255)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("rogue: Cheap Shot from Stealth, then the combo loop; key 2 Stealth and Kick", function()
    local game = session("ROGUE", 20, sp("Stealth", "Cheap Shot", "Sinister Strike", "Slice and Dice", "Eviscerate", "Kick", "Evasion"))
    local f = macro(game, "Fight")
    T.contains(f, "/cast [stealth] Cheap Shot")
    T.contains(f, "Sinister Strike,Sinister Strike,Slice and Dice,Sinister Strike,Sinister Strike,Sinister Strike,Eviscerate")
    local s = macro(game, "Strike")
    T.contains(s, "/cast [nocombat,nostealth] Stealth")
    T.ok(before(s, "Kick", "Evasion"))
  end)

  T.it("warlock: Forever's Bane of Agony, dots once, wand before 30 and Drain Life from 30", function()
    local game = session("WARLOCK", 20, sp("Bane of Agony", "Corruption", "Immolate", "Shadow Bolt", "Shoot", "Drain Life", "Life Tap", "Demon Skin"),
      { worn = { [18] = 101 } })
    local f = macro(game, "Fight")
    T.contains(f, "Bane of Agony,Corruption,Immolate,Shadow Bolt,Shadow Bolt,Shadow Bolt,Shadow Bolt")
    T.contains(f, "/cast [mod:shift] !Shoot")
    T.contains(f, "/cast [nocombat,@player] Demon Skin")
    local g30 = session("WARLOCK", 30, sp("Corruption", "Shadow Bolt", "Drain Life"))
    T.contains(macro(g30, "Fight"), "Corruption,Drain Life,Drain Life,Drain Life,Drain Life")
  end)

  T.it("druid: one key follows the form numbers on the stance bar", function()
    local spells = sp("Wrath", "Moonfire", "Bear Form", "Maul", "Demoralizing Roar", "Swipe", "Cat Form", "Claw", "Rake",
      "Ferocious Bite", "Healing Touch", "Mark of the Wild")
    local game = session("DRUID", 22, spells, { forms = { 8003, 8007 } })
    local f = macro(game, "Fight")
    T.contains(f, "/startattack [form:1/2]")
    T.contains(f, "/cast [form:1] Maul")
    T.contains(f, "/castsequence [form:2] reset=combat/target Rake,Claw,Claw,Claw,Ferocious Bite")
    T.contains(f, "/cast [noform] Wrath")
    local h = macro(game, "Heal")
    T.contains(h, "[form:1] Swipe")
    T.contains(h, "[noform,@player] Healing Touch")
    T.ok(#f <= 255)
  end)

  T.it("paladin: Seal of Command only with a two-hander from 20; Seal and Judgement loop; Holy Strike", function()
    local spells = sp("Seal of Righteousness", "Seal of Command", "Judgement", "Holy Strike", "Blessing of Might", "Devotion Aura", "Holy Light")
    local game = session("PALADIN", 22, spells, { worn = { [16] = 100 } })
    local f = macro(game, "Fight")
    -- ",null" wraps on Forever (Gul, 2026-11-21): the Seal waits behind three Judgements instead
    T.contains(f, "/castsequence reset=combat Seal of Command,Judgement,Judgement,Judgement")
    T.ok(not f:find(",null", 1, true), "no null in the paladin fight key")
    T.contains(f, "/cast Holy Strike")
    T.contains(f, "/cast [nocombat,@player] Blessing of Might")
    T.contains(macro(game, "Heal"), "[@player] Holy Light")
    local one = session("PALADIN", 22, spells)
    T.contains(macro(one, "Fight"), "Seal of Righteousness,Judgement")
  end)

  T.it("shaman: imbue while the weapon has none, totem and Flame Shock once, shocks on cooldown", function()
    local spells = sp("Lightning Bolt", "Rockbiter Weapon", "Searing Totem", "Flame Shock", "Earth Shock", "Lightning Shield", "Healing Wave")
    local game, ns = session("SHAMAN", 15, spells)
    local f = macro(game, "Fight")
    T.contains(f, "/cast [nocombat] Rockbiter Weapon")
    T.contains(f, "/cast [mod:ctrl] Searing Totem")
    T.contains(f, "/castsequence reset=combat/target Flame Shock,Earth Shock")
    game.mhEnchant = true
    game.units = game.units or {}
    game.units.player = { auras = {} }
    game:fire("UNIT_AURA", "player")
    game:advance(3)
    T.ok(not macro(game, "Fight"):find("Rockbiter", 1, true), "imbued: no wasted press")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a buff that's already up leaves the macro; mage and priest get theirs too", function()
    local game = session("PRIEST", 20, sp("Shadow Word: Pain", "Smite", "Power Word: Fortitude", "Lesser Heal"))
    T.contains(macro(game, "Fight"), "/cast [nocombat,@player] Power Word: Fortitude")
    game.units = game.units or {}
    game.units.player = { auras = { { name = "Power Word: Fortitude", spellId = 1 } } }
    game:fire("UNIT_AURA", "player")
    game:advance(3)
    T.ok(not macro(game, "Fight"):find("Fortitude", 1, true))
  end)
end)

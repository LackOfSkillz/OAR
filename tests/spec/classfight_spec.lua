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
    T.contains(f, "/cast [nocombat,stance:1] Charge;[nocombat] Battle Stance")
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

-- Gary, 2026-11-23: a druid's Strike did the same as Fight before any form,
-- there was no Pull, and after a pull he had to click the mob to start swinging.
T.describe("pull key and auto attack", function()
  local function druid(spells, forms)
    local game = mock.new({ class = "DRUID", level = 9 })
    game.spells = spells
    game.forms = forms
    local ns = game:loadAddon()
    game:login()
    ns.Modules:SetEnabled("AutoCheck", false)
    game:advance(3)
    game:slash("fight")
    game:advance(3)
    return game, ns
  end
  local function body(game, name) for _, m in ipairs(game.macros) do if m.name == name then return m.body end end end

  T.it("a druid with no form yet gets Fight and Pull, not a second Fight called Strike", function()
    local game, ns = druid(sp("Wrath", "Moonfire", "Healing Touch", "Rejuvenation"))
    local kinds = table.concat(ns.HunterFight:Kinds(), ",")
    T.ok(not kinds:find("melee", 1, true), "no Strike before Bear or Cat Form: " .. kinds)
    T.contains(kinds, "pull")
    local pull = body(game, "Pull")
    T.ok(pull, "Pull written with Fight")
    T.contains(pull, "/cast Moonfire")
    T.contains(pull, "/startattack")
    T.contains(body(game, "Fight"), "/startattack")
    T.eq(body(game, "Strike"), nil)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a wand pulls with Shoot and doesn't start melee (it would stop the wand)", function()
    local game = mock.new({ class = "PRIEST", level = 10 })
    game.spells = sp("Smite", "Shadow Word: Pain", "Shoot", "Lesser Heal")
    game.items = { [101] = { name = "Wand", equipLoc = "INVTYPE_RANGEDRIGHT", itemSubType = "Wands" } }
    game.worn = { [18] = 101 }
    local ns = game:loadAddon()
    game:login()
    ns.Modules:SetEnabled("AutoCheck", false)
    game:advance(3)
    local lines = ns.HunterFight:PullLines()
    T.eq(lines[2].text, "/cast Shoot")
    local b = ns.HunterFight:Body("pull")
    T.ok(not b:find("/startattack", 1, true), "no melee with a wand shot")
    T.eq(#ns.Errors.list, 0)
  end)
end)

-- Gary, 2026-11-25 (level 2 shaman): "if you press fight and your buffs are
-- not up, it buffs you then pulls or casts", for every class. The Fight key
-- comes from the research plans (FightPlan on), which left some buffs out.
T.describe("fight key buffs first, with the class plans on", function()
  local function planned(class, level, spells, opts)
    local game = mock.new({ class = class, level = level })
    game.spells = spells
    game.worn = (opts and opts.worn) or {}
    local ns = game:loadAddon()
    game:login()
    ns.Modules:SetEnabled("AutoCheck", false)
    game:advance(3)
    game:slash("fight")
    game:advance(3)
    return game, ns
  end
  local function count(body, s)
    local n, i = 0, 1
    while true do
      local a = body:find(s, i, true)
      if not a then return n end
      n, i = n + 1, a + 1
    end
  end

  T.it("a level 2 shaman's Fight imbues the weapon first, then pulls; imbued, it just pulls", function()
    local game, ns = planned("SHAMAN", 2, sp("Lightning Bolt", "Rockbiter Weapon", "Healing Wave"))
    T.ok(ns.FightPlan.enabled, "the plans are on, as in game")
    local f = macro(game, "Fight")
    T.contains(f, "/cast [nocombat] Rockbiter Weapon")
    T.ok(before(f, "Rockbiter Weapon", "Lightning Bolt"), "buff before the pull: " .. f)
    T.ok(before(f, "/targetenemy", "Rockbiter Weapon"), "targeting stays first")
    game.mhEnchant = true
    game.units = game.units or {}
    game.units.player = { auras = {} }
    game:fire("UNIT_AURA", "player")
    game:advance(3)
    T.ok(not macro(game, "Fight"):find("Rockbiter", 1, true), "imbued: no wasted press")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a shaman's Fight drops missing totems after the buffs, before the pull, and leaves them out once down", function()
    local game, ns = planned("SHAMAN", 20, sp("Lightning Bolt", "Rockbiter Weapon", "Lightning Shield", "Searing Totem",
      "Strength of Earth Totem", "Stoneskin Totem", "Earth Shock", "Healing Wave"))
    local f = macro(game, "Fight")
    T.contains(f, "/cast [nocombat] Strength of Earth Totem", "the best earth totem")
    T.ok(not f:find("Stoneskin", 1, true), "one per element")
    T.contains(f, "/cast [nocombat] Searing Totem")
    T.ok(before(f, "Lightning Shield", "Strength of Earth Totem"), "totems after the buffs: " .. f)
    T.ok(before(f, "Searing Totem", "Lightning Bolt"), "totems before the pull")
    T.ok(not f:find("Mana Spring", 1, true), "not learned: left out")
    T.ok(#f <= 255, "fits a macro")
    -- the earth totem goes down: rewritten without it; the fire one stays
    game.totems = { [2] = "Strength of Earth Totem" }
    game:fire("PLAYER_TOTEM_UPDATE", 2)
    game:advance(3)
    f = macro(game, "Fight")
    T.ok(not f:find("Strength of Earth", 1, true), "earth down: no wasted press")
    T.contains(f, "/cast [nocombat] Searing Totem")
    -- it ends: back in
    game.totems = {}
    game:fire("PLAYER_TOTEM_UPDATE", 2)
    game:advance(3)
    T.contains(macro(game, "Fight"), "Strength of Earth Totem")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("the imbue leaves the macro after the cast with no aura event (a weapon enchant isn't an aura)", function()
    local game, ns = planned("SHAMAN", 6, sp("Lightning Bolt", "Rockbiter Weapon", "Earth Shock", "Healing Wave"))
    T.contains(macro(game, "Fight"), "Rockbiter Weapon")
    game.mhEnchant = true
    game:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 8002)
    game:advance(4)
    T.ok(not macro(game, "Fight"):find("Rockbiter", 1, true), "imbued: gone without UNIT_AURA")
    -- it wears off: the weapon slot changes and it comes back
    game.mhEnchant = false
    game:fire("UNIT_INVENTORY_CHANGED", "player")
    game:advance(4)
    T.contains(macro(game, "Fight"), "Rockbiter Weapon")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("without GetTotemInfo no totem lines (can't tell they're up)", function()
    local game, ns = planned("SHAMAN", 20, sp("Lightning Bolt", "Searing Totem", "Healing Wave"))
    -- a client that answers "have" for an empty slot: still missing
    game.env.GetTotemInfo = function() return true, "", 0, 0, "" end
    T.eq(#ns.HunterFight.MissingTotems(), 1, "empty slot counts as missing")
    T.contains(ns.HunterFight.TotemState(), "fire Searing Totem missing")
    game.env.GetTotemInfo = nil
    T.eq(#ns.HunterFight.MissingTotems(), 0)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("every class with a self-buff gets it on Fight while missing, once, before the first cast", function()
    local cases = {
      { "SHAMAN", 10, { "Lightning Bolt", "Earth Shock", "Lightning Shield", "Healing Wave" }, "Lightning Shield" },
      { "WARLOCK", 6, { "Shadow Bolt", "Immolate", "Demon Skin", "Corruption" }, "Demon Skin" },
      { "PALADIN", 10, { "Seal of Righteousness", "Judgement", "Blessing of Might", "Devotion Aura", "Holy Light" }, "Blessing of Might" },
      { "DRUID", 10, { "Wrath", "Moonfire", "Mark of the Wild", "Thorns", "Healing Touch" }, "Mark of the Wild" },
      { "MAGE", 6, { "Fireball", "Frostbolt", "Arcane Intellect", "Frost Armor" }, "Arcane Intellect" },
      { "PRIEST", 6, { "Smite", "Shadow Word: Pain", "Power Word: Fortitude", "Lesser Heal" }, "Power Word: Fortitude" },
    }
    for _, c in ipairs(cases) do
      local game, ns = planned(c[1], c[2], sp(unpack(c[3])))
      local f = macro(game, "Fight")
      T.eq(count(f, c[4]), 1, c[1] .. ": " .. c[4] .. " once in " .. f)
      T.contains(f, "nocombat", c[1] .. ": buffs only out of combat")
      T.ok(#f <= 255, c[1] .. ": fits a macro")
      T.eq(#ns.Errors.list, 0, c[1])
    end
  end)
end)

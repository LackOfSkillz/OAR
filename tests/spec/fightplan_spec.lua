-- Fight plans by class, spec, race and level (Modules/FightPlan.lua, Data/FightPlans.lua;
-- research docs/FIGHT_MACRO_RESEARCH_2026-11-18.md). Spells and talents are test data.
local T, mock = ...

local BOW = 2504
local function sp(list)
  local out = {}
  for i, n in ipairs(list) do out[i] = { name = n, id = 9000 + i } end
  return out
end
local function points(n) return { { name = "t", tier = 1, column = 1, rank = n, max = n } } end

local HUNTER20 = { "Auto Shot", "Raptor Strike", "Aspect of the Monkey", "Serpent Sting", "Arcane Shot", "Hunter's Mark",
  "Concussive Shot", "Aspect of the Hawk", "Call Pet", "Revive Pet", "Mend Pet", "Wing Clip", "Immolation Trap",
  "Mongoose Bite", "Multi-Shot", "Aimed Shot", "Freezing Trap", "Feign Death" }

local function hunter(level, spells, talents, opts)
  opts = opts or {}
  local game = mock.new({ class = "HUNTER", level = level, race = opts.race or "Orc" })
  game.spells = sp(spells)
  game.items = { [BOW] = { name = "Worn Shortbow", equipLoc = "INVTYPE_RANGED", class = 2, subclass = 2 } }
  game.worn = { [18] = BOW }
  game.talents = talents
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game:advance(3)
  return game, ns, ns.FightPlan, ns.HunterFight
end

T.describe("fight plans", function()
  T.it("reads the spec from talent points: the biggest tree, or levelling under 10 points", function()
    local _, _, FP = hunter(20, HUNTER20, { { name = "Beast Mastery", talents = points(11) }, { name = "Marksmanship", talents = points(0) },
      { name = "Survival", talents = points(0) } })
    T.eq(FP:Spec(), "bm")
    local _, _, FP2 = hunter(20, HUNTER20, { { name = "Beast Mastery", talents = points(2) }, { name = "Marksmanship", talents = points(3) },
      { name = "Survival", talents = points(0) } })
    T.eq(FP2:Spec(), "levelling", "5 points is still levelling")
  end)

  T.it("a level 20 Beast Mastery hunter gets the plan's Fight with Aimed Shot and a Trap key with Freezing Trap", function()
    local game, ns, FP, F = hunter(20, HUNTER20, { { name = "Beast Mastery", talents = points(11) }, { name = "Marksmanship", talents = points(0) },
      { name = "Survival", talents = points(0) } })
    local fight = F:Body("ranged")
    T.contains(fight, "Aimed Shot")
    T.ok(#fight <= 255)
    local kinds = table.concat(F:Kinds(), ",")
    T.contains(kinds, "trap", "the Trap key is offered")
    local trap = F:Body("trap")
    T.contains(trap, "Freezing Trap")
    T.ok(#trap <= 255)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a spell not trained yet falls back to the bracket before it", function()
    local spells = {}
    for _, n in ipairs(HUNTER20) do if n ~= "Aimed Shot" and n ~= "Multi-Shot" then spells[#spells + 1] = n end end
    local _, _, FP, F = hunter(20, spells, { { name = "Beast Mastery", talents = points(11) }, { name = "Marksmanship", talents = points(0) },
      { name = "Survival", talents = points(0) } })
    local fight = F:Body("ranged")
    T.no(fight:find("Aimed Shot", 1, true), "no line for a spell you don't know")
    T.contains(fight, "Arcane Shot")
  end)

  T.it("PvP mode picks the PvP plan; the setting is per character", function()
    local _, _, FP = hunter(20, HUNTER20, {})
    T.eq(FP:Mode(), "pve")
    FP:Settings().mode = "pvp"
    T.eq(FP:Mode(), "pvp")
    T.ok(FP:Slots("ranged"), "there is a PvP plan")
  end)

  T.it("Undead gets its racial keys only with the spells it knows", function()
    local game = mock.new({ class = "PRIEST", level = 20, race = "Scourge" })
    game.spells = sp({ "Smite", "Shadow Word: Pain", "Mind Blast", "Lesser Heal", "Power Word: Shield", "Cannibalize", "Will of the Forsaken" })
    local ns = game:loadAddon()
    game:login()
    local FP = ns.FightPlan
    T.eq(FP.Race(), "Undead")
    local names = {}
    for _, u in ipairs(FP:Utility()) do names[u.name] = u.text end
    T.ok(names.Recover and names.Recover:find("Cannibalize", 1, true), "Recover: Cannibalize")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("keeps modifier-only abilities gated when an untrained alternative is removed", function()
    local game, ns, FP = hunter(20, HUNTER20, {})
    local line = FP.KnownLine("/cast [mod:shift] Freezing Trap; [mod:ctrl] Untrained Trap")
    T.eq(line, "/cast [mod:shift] Freezing Trap")
  end)

  T.it("does not guess an unknown Skyborne faction or talent specialization", function()
    local game, ns, FP = hunter(20, HUNTER20, {})
    local original = ns.Talents.Read
    ns.Talents.Read = function()
      return { tabs = { { spent = "unreadable" }, { spent = 15 }, { spent = 0 } } }
    end
    T.eq(FP:Spec(), "levelling")
    ns.Talents.Read = original
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("scores a hand-written macro: a channel with no guard is flagged, a full rotation scores high", function()
    local game = mock.new({ class = "WARLOCK", level = 30 })
    game.spells = sp({ "Shadow Bolt", "Corruption", "Immolate", "Drain Life", "Life Tap", "Demon Skin", "Bane of Agony", "Fear" })
    local ns = game:loadAddon()
    game:login()
    local FP = ns.FightPlan
    local _, _, issues = FP:Score("/cast Corruption\n/cast Drain Life", "ranged")
    T.ok(#issues > 0, "Drain Life without /stopmacro [channeling]")
    local _, _, ok = FP:Score("/stopmacro [channeling]\n/cast Drain Life", "ranged")
    T.eq(#ok, 0)
  end)

  T.it("every class's plan builds macros of 255 characters or fewer at level 60 with all its spells", function()
    for _, cls in ipairs({ "HUNTER", "PRIEST", "MAGE", "WARRIOR", "ROGUE", "WARLOCK", "DRUID", "PALADIN", "SHAMAN" }) do
      local game = mock.new({ class = cls, level = 60 })
      local ns0 = {}
      local plans = assert(loadfile("addon/Outrider/Data/FightPlans.lua"))("Outrider", ns0)
      local plan = ns0.FightPlans:Class(cls)
      local names, seen = {}, {}
      for _, s in pairs(plan.specs) do for _, m in pairs(s) do for _, br in pairs(m) do for _, b in ipairs(br) do
        for _, sl in ipairs(b.slots) do if type(sl) == "table" then for _, n in ipairs(sl.spells) do
          n = n:gsub("^!", "") if not seen[n] then seen[n] = true names[#names + 1] = n end end end end
      end end end end
      game.spells = sp(names)
      local ns = game:loadAddon()
      game:login()
      for _, kind in ipairs(ns.HunterFight:Kinds()) do
        local body = ns.HunterFight:Body(kind)
        T.ok(#body <= 255, cls .. " " .. kind .. " is " .. #body .. " characters")
      end
      T.eq(#ns.Errors.list, 0, cls .. " built without errors")
    end
  end)
end)

T.describe("fight plans: world PvP", function()
  T.it("auto mode picks PvP when a hostile player is targeted, PvE again on a mob", function()
    local game = mock.new({ class = "HUNTER", level = 20 })
    game.base.UnitCanAttack = function(_, unit) return game.units and game.units[unit] ~= nil end
    rawset(game.env, "UnitCanAttack", game.base.UnitCanAttack)
    local ns = game:loadAddon()
    game:login()
    local FP = ns.FightPlan
    game.units = { target = { name = "Gankster", player = true, guid = "Player-1-0001" } }
    T.eq(FP:Mode(), "pvp")
    game.units = { target = { name = "Boar", guid = "Creature-0-1-0-1-113-001" } }
    T.eq(FP:Mode(), "pve")
    FP:Settings().mode = "pve"
    game.units = { target = { name = "Gankster", player = true, guid = "Player-1-0001" } }
    T.eq(FP:Mode(), "pve", "a fixed choice wins")
  end)
end)

T.describe("fight plans: hunter PvP from the Forever guides", function()
  T.it("PvP Fight skips Serpent Sting (it breaks your own trap), kites with Multi-Shot, Shift for Aimed Shot, Ctrl for Intimidation", function()
    local spells = {}
    for _, n in ipairs(HUNTER20) do spells[#spells + 1] = n end
    for _, n in ipairs({ "Summon Hawk", "Intimidation", "Bestial Wrath", "Rapid Fire" }) do spells[#spells + 1] = n end
    local _, _, FP, F = hunter(44, spells, { { name = "Beast Mastery", talents = points(31) }, { name = "Marksmanship", talents = points(0) },
      { name = "Survival", talents = points(0) } })
    FP:Settings().mode = "pvp"
    local fight = F:Body("ranged")
    T.no(fight:find("Serpent Sting", 1, true), "no Serpent Sting in PvP")
    T.contains(fight, "[mod:shift] Aimed Shot; Multi-Shot")
    T.contains(fight, "[mod:ctrl] Intimidation", fight)
    T.contains(fight, "Hunter's Mark,!Auto Shot,Arcane Shot")
    T.no(fight:find(",null", 1, true), "no ,null")
    T.no(fight:find("Bestial Wrath", 1, true), "Bestial Wrath stays on the Burst key")
    T.ok(#fight <= 255, #fight .. " characters")
  end)
end)

T.describe("fight plans: rogue Stealth on the Fight key", function()
  -- the rogue Fight key is HunterFight kind "ranged" (FightPlan.KIND_MAP)
  local function rogue(level, spells, talents)
    local game = mock.new({ class = "ROGUE", level = level, race = "Orc" })
    game.spells = sp(spells)
    game.talents = talents
    local ns = game:loadAddon()
    game:login()
    return ns
  end
  T.it("level 2: the first press Stealths, the next opens with Sinister Strike (nothing else works while sneaking)", function()
    local ns = rogue(2, { "Sinister Strike", "Eviscerate", "Stealth" }, {})
    local fight = ns.HunterFight:Body("ranged")
    T.contains(fight, "/cast [nocombat,nostealth] Stealth")
    -- the builder line has no [nostealth]: it opens from Stealth too
    T.contains(fight, "/castsequence reset=target Sinister Strike")
    T.eq(#ns.Errors.list, 0)
  end)
  T.it("level 4: Backstab opens from Stealth with a dagger; the Strike key Pick Pockets while sneaking, not before you learn it", function()
    local ns = rogue(2, { "Sinister Strike", "Eviscerate", "Stealth" }, {})
    T.no(ns.HunterFight:Body("melee"):find("Pick Pocket", 1, true), "level 2: no Pick Pocket yet")
    ns = rogue(4, { "Sinister Strike", "Eviscerate", "Stealth", "Backstab", "Pick Pocket" }, {})
    local fight, dropped = ns.HunterFight:Body("ranged")
    T.contains(fight, "/cast [nocombat,nostealth] Stealth;[stealth,equipped:Daggers] Backstab")
    -- 2026-11-19 in game: the Backstab line pushed it over 255 and the builder line was dropped
    T.contains(fight, "/castsequence reset=target Sinister Strike")
    T.eq(#dropped, 0, "nothing left out")
    T.contains(ns.HunterFight:Body("melee"), "/cast [nocombat,nostealth] Stealth;[stealth] Pick Pocket")
    T.eq(#ns.Errors.list, 0)
  end)
  T.it("the Pull key uses whatever ranged weapon is on: throwing knives or a bow (unlearned shots drop out)", function()
    local ns = rogue(4, { "Sinister Strike", "Eviscerate", "Stealth", "Throw", "Shoot Bow" }, {})
    local pull = ns.HunterFight:Body("pull")
    T.contains(pull, "[nostealth,equipped:Thrown] Throw")
    T.contains(pull, "[nostealth,equipped:Bows] Shoot Bow")
    T.no(pull:find("Shoot Gun", 1, true), "no gun skill: no gun clause")
    ns = rogue(4, { "Sinister Strike", "Eviscerate", "Stealth", "Throw" }, {})
    T.no(ns.HunterFight:Body("pull"):find("Shoot Bow", 1, true), "only Throw learned")
    T.contains(ns.HunterFight:Body("pull"), "Throw")
    T.eq(#ns.Errors.list, 0)
  end)
  T.it("every level from 1 to 60 and every build keeps Stealth and a Stealth opener within 255 characters", function()
    local all = { "Sinister Strike", "Eviscerate", "Stealth", "Backstab", "Pick Pocket", "Gouge", "Evasion", "Slice and Dice", "Sprint", "Kick",
      "Garrote", "Ambush", "Riposte", "Rupture", "Vanish", "Shank", "Cold Blood", "Ghostly Strike", "Cheap Shot", "Blade Flurry",
      "Hemorrhage", "Kidney Shot", "Blind", "Adrenaline Rush", "Mutilate" }
    for _, tree in ipairs({ 0, 1, 2, 3 }) do
      for level = 1, 60 do
        local talents = {}
        for t = 1, 3 do talents[t] = { name = "t" .. t, talents = points(t == tree and math.max(0, level - 9) or 0) } end
        local ns = rogue(level, all, talents)
        for _, mode in ipairs({ "pve", "pvp" }) do
          ns.FightPlan:Settings().mode = mode
          local fight, dropped = ns.HunterFight:Body("ranged")
          local where = ("tree %d level %d %s"):format(tree, level, mode)
          T.contains(fight, "/castsequence", where .. ": the builders and finisher are there")
          T.eq(#dropped, 0, where .. ": nothing dropped to fit (" .. table.concat(dropped, "; ") .. ")")
          T.contains(fight, "Stealth", where)
          -- from 4 a Stealth opener clause (Backstab, Garrote, Ambush, Cheap Shot); below
          -- that the builder line opens with Sinister Strike
          if level >= 4 then T.ok(fight:find("[stealth", 1, true), where .. ": a Stealth opener") end
          T.ok(#fight <= 255, where .. " is " .. #fight)
        end
        T.eq(#ns.Errors.list, 0)
      end
    end
  end)
end)

-- Druid (Gary, 2026-11-22: "make sure the druid combat macros work"). ",null"
-- wraps on Forever (the paladin's Seal spam), so no druid line may use it; the
-- forms are written with this character's own stance bar numbers.
T.describe("fight plans: druid", function()
  local DRUID22 = { "Wrath", "Healing Touch", "Mark of the Wild", "Moonfire", "Rejuvenation", "Thorns", "Bear Form", "Maul",
    "Demoralizing Roar", "Swipe", "Cat Form", "Claw", "Rip", "Regrowth", "Entangling Roots", "Faerie Fire" }
  local function druid(level, spells, forms)
    local game = mock.new({ class = "DRUID", level = level, race = "NightElf" })
    game.spells = sp(spells)
    game.forms = forms
    local ns = game:loadAddon()
    game:login()
    ns.Modules:SetEnabled("AutoCheck", false)
    game:advance(3)
    return game, ns, ns.HunterFight
  end

  T.it("caster: Moonfire, then Wrath while it ticks; no ,null anywhere", function()
    local game, ns, F = druid(22, DRUID22, { 9007, 9011 }) -- Bear 1, Cat 2 (no Aquatic Form yet)
    local fight, strike, heal = F:Body("ranged"), F:Body("melee"), F:Body("heal")
    T.contains(fight, "/castsequence [noform] reset=combat/target Moonfire,Wrath,Wrath,Wrath")
    for _, b in ipairs({ fight, strike, heal }) do
      T.ok(not b:find(",null", 1, true), "no ,null: " .. b)
      T.ok(#b <= 255)
    end
    -- Bear: no caster Faerie Fire (it can't be cast in a form and stuck the line); Roar on Ctrl, Maul
    T.ok(not strike:find("Faerie Fire", 1, true), "no Faerie Fire in Bear")
    T.contains(strike, "/cast [form:1,mod:ctrl] Demoralizing Roar")
    T.contains(strike, "/cast [form:1] Maul")
    -- Cat is the second form on this stance bar, not the Classic third
    T.contains(strike, "/startattack [form:1/2]")
    T.contains(strike, "[form:2] reset=combat/target Claw,Claw,Claw,Rip")
    -- Heal: Rejuvenation, then Regrowth (the most healing per mana on Forever), Healing Touch on Ctrl
    T.contains(heal, "/cancelform")
    T.contains(heal, "/castsequence [@mouseover,help,nodead][] reset=target Rejuvenation,Regrowth,Regrowth,Healing Touch")
    T.contains(heal, "/cast [mod:ctrl] Healing Touch")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a level 1 druid: Wrath and Mark of the Wild, Healing Touch on Heal", function()
    local _, ns, F = druid(1, { "Wrath", "Healing Touch", "Mark of the Wild" })
    local fight = F:Body("ranged")
    T.contains(fight, "/cast [noform] Wrath")
    T.contains(fight, "Mark of the Wild")
    T.contains(F:Body("heal"), "Healing Touch")
    T.eq(#ns.Errors.list, 0)
  end)
end)

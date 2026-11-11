-- Data/Macros_Hunter.lua
-- The hunter macros from the blueprint's Macro Library (Forever macro guides:
-- Endgame Tools, Wowcalc, Kami Labs, wowf.io). Data only; the P4 library
-- installs them. {PLACEHOLDERS} are filled at install time from bags, the
-- rare pack or the player's choice. verified = true only after Gary pressed
-- the macro in game on WoW Forever (the tame macro is confirmed).
-- needsSpells uses English client names; P4-05 resolves them to spell IDs
-- from the spellbook so other locales work.

local _, ns = ...

ns.Data:Register("macro", "hunter", {
  { id = "hunter-pull", name = "Pull", class = "HUNTER", verified = false, tags = { "combat" },
    body = "#showtooltip Hunter's Mark\n/cleartarget [dead]\n/targetenemy [noharm]\n/cast !Auto Shot\n/petattack\n/cast Hunter's Mark",
    needsSpells = { "Hunter's Mark", "Auto Shot" },
    explain = "Drops a dead target, grabs the nearest enemy, starts shooting, sends the pet and marks it.",
    source = "wowf.io hunter macros" },

  { id = "hunter-autoshot", name = "AutoShot", class = "HUNTER", verified = false, tags = { "combat" },
    body = "#showtooltip Auto Shot\n/targetenemy [noexists][dead][help]\n/cast !Auto Shot",
    needsSpells = { "Auto Shot" },
    explain = "The ! means a second press never stops your shooting.", source = "Endgame Tools" },

  { id = "hunter-aimed-multi", name = "Aimed", class = "HUNTER", verified = false, tags = { "combat" }, level = 20,
    body = "#showtooltip\n/cast [mod:shift] Multi-Shot; Aimed Shot\n/cast !Auto Shot",
    needsSpells = { "Aimed Shot", "Multi-Shot" },
    explain = "Aimed Shot and Multi-Shot share a cooldown in Forever, so one key holds both.", source = "Endgame Tools" },

  { id = "hunter-hawk-arcane", name = "Hawk", class = "HUNTER", verified = false, tags = { "combat", "bm" }, level = 25,
    body = "#showtooltip\n/cast [mod:shift] Arcane Shot; Summon Hawk\n/cast !Auto Shot",
    needsSpells = { "Summon Hawk", "Arcane Shot" },
    explain = "Summon Hawk (Forever talent) shares Arcane Shot's cooldown.", source = "Endgame Tools" },

  { id = "hunter-stings", name = "Stings", class = "HUNTER", verified = false, tags = { "combat" },
    body = "#showtooltip\n/cast [mod:shift] Viper Sting; [mod:ctrl] Scorpid Sting; Serpent Sting",
    needsSpells = { "Serpent Sting" },
    explain = "Serpent by default, Shift drains mana, Ctrl lowers the target's hit chance.", source = "Kami Labs" },

  { id = "hunter-rapidfire", name = "RapidFire", class = "HUNTER", verified = false, tags = { "combat", "cooldown" },
    body = "#showtooltip Rapid Fire\n/use 13\n/use 14\n/cast Rapid Fire",
    needsSpells = { "Rapid Fire" },
    explain = "Both trinkets (slots 13 and 14) with Rapid Fire.", source = "Kami Labs" },

  { id = "hunter-melee", name = "Melee", class = "HUNTER", verified = false, tags = { "combat", "survival" },
    body = "#showtooltip\n/startattack\n/cast Counterattack\n/cast Mongoose Bite\n/cast Raptor Strike",
    needsSpells = { "Raptor Strike" },
    explain = "Tries each strike in turn; Raptor Strike is off the global cooldown in Forever. Drop Counterattack without the talent.",
    source = "Endgame Tools" },

  { id = "hunter-pet-care", name = "PetCare", class = "HUNTER", verified = false, tags = { "pet" },
    body = "#showtooltip\n/cast [@pet,dead][mod:shift] Revive Pet; [nopet] Call Pet; Mend Pet",
    needsSpells = { "Call Pet", "Mend Pet", "Revive Pet" },
    explain = "Mend Pet when it's out, Call Pet when it isn't, Revive Pet when it's dead (Shift if the icon is wrong).",
    source = "Wowcalc" },

  { id = "hunter-pet-attack", name = "PetAttack", class = "HUNTER", verified = false, tags = { "pet" },
    body = "/petattack [nomod,@mouseover,harm,nodead][nomod]\n/petfollow [mod:shift]",
    explain = "Sends the pet at your mouseover without changing your target; Shift recalls it.", source = "Wowcalc" },

  { id = "hunter-feed", name = "Feed", class = "HUNTER", verified = false, tags = { "pet" },
    body = "#showtooltip Feed Pet\n/cast Feed Pet\n/use {PET_FOOD}",
    needsSpells = { "Feed Pet" }, template = { PET_FOOD = "bag food the pet eats" },
    explain = "One press feeds the pet; the library keeps the food name current.", source = "Kami Labs" },

  { id = "hunter-feign", name = "Feign", class = "HUNTER", verified = false, tags = { "utility" }, level = 30,
    body = "#showtooltip Feign Death\n/stopattack\n/petfollow\n/cast Feign Death",
    needsSpells = { "Feign Death" },
    explain = "Stops your attack and recalls the pet first so neither drags the mob back.", source = "Endgame Tools" },

  { id = "hunter-traps", name = "Traps", class = "HUNTER", verified = false, tags = { "control" }, level = 20,
    body = "#showtooltip\n/cast [mod:shift] Frost Trap; Freezing Trap",
    needsSpells = { "Freezing Trap" },
    explain = "Only one Frost-type trap can be down at a time, so they share a key. Frost Trap at 28.", source = "Endgame Tools" },

  { id = "hunter-scatter-trap", name = "ScatTrap", class = "HUNTER", verified = false, tags = { "control", "mm" }, level = 30,
    body = "#showtooltip\n/petfollow\n/petpassive\n/castsequence reset=6 Scatter Shot, Freezing Trap",
    needsSpells = { "Scatter Shot", "Freezing Trap" },
    explain = "First press scatters and recalls the pet, second press drops the trap. Step back so the target walks in.",
    source = "Endgame Tools" },

  { id = "hunter-tame-rare", name = "Outrider Tame", class = "HUNTER", verified = true, tags = { "pet", "rare" },
    body = "#showtooltip Tame Beast\n/stopmacro [channeling]\n/cleartarget\n/targetexact {TARGET}\n/stopmacro [noexists][noharm][dead]\n/cast Tame Beast",
    needsSpells = { "Tame Beast" }, template = { TARGET = "rare beast name" },
    explain = "Safe to mash: presses during the channel do nothing, and [noharm] skips other hunters' pets with the same name.",
    source = "built with Gary; confirmed working on The Rake",
    confidence = "verified", verifiedOn = { date = "2026-11-10", note = "tamed The Rake with it" } },

  { id = "hunter-aspects", name = "Aspects", class = "HUNTER", verified = false, tags = { "utility" },
    body = "#showtooltip\n/cast [mod:shift] !Aspect of the Monkey; [combat] !Aspect of the Hawk; !Aspect of the Cheetah",
    needsSpells = { "Aspect of the Hawk" },
    explain = "Hawk in combat, Cheetah out of it, Shift for Monkey. Swap Cheetah for Pack in a group.", source = "Wowcalc" },

  { id = "hunter-tracking", name = "Track", class = "HUNTER", verified = false, tags = { "utility", "rare" },
    body = "#showtooltip\n/cast [mod:shift] Track Hidden; [mod:ctrl] Track Humanoids; Track Beasts",
    needsSpells = { "Track Beasts" },
    explain = "Track Beasts by default for rare hunting; Ctrl for Humanoids, Shift for Hidden.", source = "Kami Labs (reordered)" },

  { id = "hunter-focus-set", name = "SetFocus", class = "HUNTER", verified = false, tags = { "utility" },
    body = "/clearfocus [mod:shift]\n/focus [nomod,@mouseover,exists][nomod]",
    explain = "Sets focus on your mouseover or target; Shift clears it.", source = "Wowcalc" },

  { id = "hunter-tranq-focus", name = "TranqFocus", class = "HUNTER", verified = false, tags = { "utility" },
    body = "#showtooltip Tranquilizing Shot\n/cast [@focus,harm,nodead][] Tranquilizing Shot",
    needsSpells = { "Tranquilizing Shot" },
    explain = "Removes an enrage from your focus without switching targets.", source = "Wowcalc" },

  { id = "hunter-rare-scan", name = "Outrider Scan", class = "HUNTER", verified = false, tags = { "rare" },
    body = "/cleartarget\n{RARE_LINES}",
    template = { RARE_LINES = "one /targetexact line per rare in the current zone (about ten fit)" },
    explain = "Press while riding through a zone; a listed rare in range becomes your target. Rebuilt per zone.",
    source = "ours" },
})

-- Macros for every class (mount, food). Account-wide General tab.
ns.Data:Register("macro", "general", {
  { id = "all-mount", name = "Mount", class = "ALL", verified = false, tags = { "utility" }, scope = "account",
    body = "#showtooltip\n/dismount [mounted]\n/use [nomounted] {MOUNT}",
    template = { MOUNT = "mount item or spell" }, explain = "One key on and off.", source = "Kami Labs" },

  { id = "all-eat-drink", name = "EatDrink", class = "ALL", verified = false, tags = { "utility" }, scope = "account",
    body = "/use {DRINK}\n/use {FOOD}",
    template = { DRINK = "best drink in bags", FOOD = "best food in bags" },
    explain = "Sit once instead of twice; names follow what's in your bags.", source = "Kami Labs" },
})

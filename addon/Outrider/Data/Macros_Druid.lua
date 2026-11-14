-- Data/Macros_Druid.lua  (P4-08)
-- Druid macros in Classic/Forever syntax. Patterns from community Forever
-- macro guides (Rankedboost "Druid Macros in WoW Forever", Kami-Labs "Macros
-- WoW Forever", 2026), Warcraft Wiki "Useful macros/Druid" and standard
-- Classic conventions. Data only; verified = false until Gary presses them on
-- a druid. Form numbers are the Classic order: 1 Bear, 2 Aquatic, 3 Cat,
-- 4 Travel. "!" before a form stops a second press from leaving it
-- (Kami-Labs). Caster spells start with /cancelform. Forever changes per
-- Rankedboost: Innervate, Rebirth and Remove Curse work in Moonkin Form, plain
-- Faerie Fire works in Cat and Bear (the Feral talent is gone), Nature's Grasp
-- is a level 10 trainer spell, Entangling Roots works indoors, Barkskin no
-- longer slows casts, and a Revive spell at 12 (left out until seen in game).

local _, ns = ...
local SRC = "Rankedboost / Kami-Labs / Warcraft Wiki druid macros (2026), Classic conventions"

ns.Data:Register("macro", "druid", {
  { id = "druid-bear", name = "Bear", class = "DRUID", verified = false, tags = { "combat" }, level = 10,
    body = "#showtooltip\n/startattack [form:1]\n/cast [noform:1] !Bear Form; Maul",
    needsSpells = { "Bear Form" },
    explain = "First press shifts to Bear, after that each press is Maul.", source = SRC },

  { id = "druid-cat", name = "Cat", class = "DRUID", verified = false, tags = { "combat" }, level = 20,
    body = "#showtooltip\n/startattack [form:3]\n/cast [noform:3] !Cat Form; Claw",
    needsSpells = { "Cat Form" },
    explain = "First press shifts to Cat, after that each press is Claw.", source = SRC },

  { id = "druid-prowl", name = "Prowl", class = "DRUID", verified = false, tags = { "combat" }, level = 32,
    body = "#showtooltip\n/cast [noform:3] !Cat Form; [nostealth] Prowl; Ravage",
    needsSpells = { "Prowl", "Ravage" },
    explain = "Cat Form, then Prowl, then Ravage from behind, all on one key.", source = SRC },

  { id = "druid-travel", name = "Travel", class = "DRUID", verified = false, tags = { "utility" }, level = 30,
    body = "#showtooltip\n/cast [swimming] !Aquatic Form; [indoors] !Cat Form; !Travel Form",
    needsSpells = { "Travel Form" },
    explain = "Aquatic in water, Cat indoors, Travel Form outdoors.", source = SRC },

  { id = "druid-heal-mo", name = "Heal", class = "DRUID", verified = false, tags = { "heal" }, level = 1,
    body = "#showtooltip\n/cancelform\n/cast [mod:shift,@mouseover,help,nodead][mod:shift] Regrowth; [@mouseover,help,nodead][help,nodead][@player] Healing Touch",
    needsSpells = { "Healing Touch" },
    explain = "Leaves any form and heals the mouseover, else target, else you; Shift for Regrowth.", source = SRC },

  { id = "druid-rejuv-mo", name = "Rejuv", class = "DRUID", verified = false, tags = { "heal" }, level = 4,
    body = "#showtooltip Rejuvenation\n/cancelform\n/cast [@mouseover,help,nodead][help,nodead][@player] Rejuvenation",
    needsSpells = { "Rejuvenation" },
    explain = "Heal over time on the mouseover, else target, else you.", source = SRC },

  { id = "druid-decurse-mo", name = "Decurse", class = "DRUID", verified = false, tags = { "heal" }, level = 24,
    body = "#showtooltip\n/cancelform\n/cast [mod:shift,@mouseover,help,nodead][mod:shift] Abolish Poison; [@mouseover,help,nodead][help,nodead][@player] Remove Curse",
    needsSpells = { "Remove Curse" },
    explain = "Removes a curse from the mouseover, else target, else you; Shift cures poison.", source = SRC },

  { id = "druid-innervate-mo", name = "Innervate", class = "DRUID", verified = false, tags = { "utility" }, level = 40,
    body = "#showtooltip Innervate\n/cancelform\n/cast [@mouseover,help,nodead][help,nodead][@player] Innervate",
    needsSpells = { "Innervate" },
    explain = "Gives mana back to the mouseover healer, else target, else you.", source = SRC },

  { id = "druid-rebirth-mo", name = "Rebirth", class = "DRUID", verified = false, tags = { "heal" }, level = 20,
    body = "#showtooltip Rebirth\n/cancelform\n/cast [@mouseover,help,dead][help,dead] Rebirth",
    needsSpells = { "Rebirth" },
    explain = "Battle-res the dead friend under your mouse, else your dead target.", source = SRC },

  { id = "druid-roots", name = "Roots", class = "DRUID", verified = false, tags = { "control" }, level = 8,
    body = "#showtooltip Entangling Roots\n/cancelform\n/cast [@focus,harm,nodead][@mouseover,harm,nodead][] Entangling Roots",
    needsSpells = { "Entangling Roots" },
    explain = "Roots your focus, else the mouseover, else your target.", source = SRC },

  { id = "druid-motw-mo", name = "MarkWild", class = "DRUID", verified = false, tags = { "utility" }, level = 1,
    body = "#showtooltip Mark of the Wild\n/cancelform\n/cast [@mouseover,help,nodead][help,nodead][@player] Mark of the Wild",
    needsSpells = { "Mark of the Wild" },
    explain = "Buff whoever is under your mouse, else target, else you.", source = SRC },
})

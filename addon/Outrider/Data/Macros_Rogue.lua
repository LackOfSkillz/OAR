-- Data/Macros_Rogue.lua  (P4-08)
-- Rogue macros in Classic/Forever syntax. Patterns from community Forever
-- macro guides (Rankedboost "Rogue Macros in WoW Forever", Kami-Labs "Macros
-- WoW Forever", 2026), Almar's Guides "Classic Rogue Macros" and standard
-- Classic conventions. Data only; verified = false until Gary presses them on
-- a rogue. Rank-less /cast uses the highest rank known (Kami-Labs). Forever
-- changes per Rankedboost: new passive Poised (next ability 10 Energy cheaper
-- at full Energy out of combat), new trainer strike Shank (left out here
-- until seen in game), poisons stack with a sharpening stone.

local _, ns = ...
local SRC = "Rankedboost / Kami-Labs Forever rogue macros (2026), Almar's Guides, Classic conventions"

ns.Data:Register("macro", "rogue", {
  { id = "rogue-opener", name = "Opener", class = "ROGUE", verified = false, tags = { "combat", "control" }, level = 26,
    body = "#showtooltip\n/startattack [nostealth]\n/cast [stealth] Cheap Shot; Sinister Strike",
    needsSpells = { "Cheap Shot" },
    explain = "Cheap Shot from Stealth, Sinister Strike after that.", source = SRC },

  { id = "rogue-ambush", name = "Ambush", class = "ROGUE", verified = false, tags = { "combat" }, level = 18,
    body = "#showtooltip\n/cast [stealth] Ambush; Backstab",
    needsSpells = { "Ambush" },
    explain = "Ambush from Stealth, Backstab after that. Both need a dagger and you behind the target.", source = SRC },

  { id = "rogue-garrote", name = "Garrote", class = "ROGUE", verified = false, tags = { "combat" }, level = 14,
    body = "#showtooltip\n/cast [stealth] Garrote; Rupture",
    needsSpells = { "Garrote" },
    explain = "Garrote from Stealth; once in combat the same key casts Rupture.", source = SRC },

  { id = "rogue-sap", name = "Sap", class = "ROGUE", verified = false, tags = { "control" }, level = 10,
    body = "#showtooltip Sap\n/cast [@mouseover,harm,nodead][] Sap",
    needsSpells = { "Sap" },
    explain = "Saps the enemy under your mouse without changing target, else your target.", source = SRC },

  { id = "rogue-kick", name = "Kick", class = "ROGUE", verified = false, tags = { "control" }, level = 12,
    body = "#showtooltip Kick\n/cast [@focus,harm,nodead][] Kick",
    needsSpells = { "Kick" },
    explain = "Kicks your focus target if set and in range, else your target.", source = SRC },

  { id = "rogue-gouge", name = "Gouge", class = "ROGUE", verified = false, tags = { "control" }, level = 6,
    body = "#showtooltip Gouge\n/stopattack\n/cast Gouge",
    needsSpells = { "Gouge" },
    explain = "Gouges and stops your swing so you do not break it right away.", source = SRC },

  { id = "rogue-blind", name = "Blind", class = "ROGUE", verified = false, tags = { "control" }, level = 34,
    body = "#showtooltip Blind\n/cast [@focus,harm,nodead][@mouseover,harm,nodead][] Blind",
    needsSpells = { "Blind" },
    explain = "Blinds your focus, else the mouseover, else your target. Uses Blinding Powder.", source = SRC },

  { id = "rogue-vanish", name = "Vanish", class = "ROGUE", verified = false, tags = { "defensive" }, level = 22,
    body = "#showtooltip Vanish\n/stopattack\n/cast Vanish",
    needsSpells = { "Vanish" },
    explain = "Stops attacking and vanishes, dropping you out of combat.", source = SRC },

  { id = "rogue-evasion", name = "Evasion", class = "ROGUE", verified = false, tags = { "defensive" }, level = 8,
    body = "#showtooltip\n/cast [mod:shift] Sprint; Evasion",
    needsSpells = { "Evasion" },
    explain = "Evasion to dodge more; Shift for Sprint to run away.", source = SRC },

  { id = "rogue-poison", name = "Poison", class = "ROGUE", verified = false, tags = { "utility" }, level = 20,
    body = "#showtooltip Instant Poison\n/use Instant Poison\n/use [nomod] 16; 17",
    explain = "Puts Instant Poison on your main hand; Shift for the off hand.", source = SRC },
})

-- Data/Macros_Shaman.lua  (P4-08)
-- Shaman macros in Classic/Forever syntax. Patterns from community Forever
-- macro guides (Rankedboost "Shaman Macros in WoW Forever", Kami-Labs "Macros
-- WoW Forever", 2026) and standard Classic conventions. Data only;
-- verified = false until Gary presses them on a shaman. Forever changes per
-- Rankedboost: Fire Nova Totem is removed (Fire Nova is a level 12 burst from
-- your Fire totem), Totemic Call (22) and Totemic Recall (20) are new trainer
-- spells (left out here until seen in game), weapon imbues last 60 minutes.

local _, ns = ...
local SRC = "Rankedboost / Kami-Labs Forever shaman macros (2026), Classic conventions"

ns.Data:Register("macro", "shaman", {
  { id = "shaman-interrupt", name = "EarthShock", class = "SHAMAN", verified = false, tags = { "control" }, level = 4,
    body = "#showtooltip Earth Shock\n/stopcasting\n/cast [@focus,harm,nodead][] Earth Shock",
    needsSpells = { "Earth Shock" },
    explain = "Stops your cast and interrupts your focus if set, else your target.", source = SRC },

  { id = "shaman-opener", name = "Opener", class = "SHAMAN", verified = false, tags = { "combat" }, level = 1,
    body = "#showtooltip\n/targetenemy [noexists][dead][help]\n/cast [mod:shift] Earth Shock; Lightning Bolt",
    needsSpells = { "Lightning Bolt" },
    explain = "Grabs an enemy and opens with Lightning Bolt; Shift for Earth Shock.", source = SRC },

  { id = "shaman-frostshock-mo", name = "FrostShock", class = "SHAMAN", verified = false, tags = { "control" }, level = 20,
    body = "#showtooltip Frost Shock\n/cast [@mouseover,harm,nodead][] Frost Shock",
    needsSpells = { "Frost Shock" },
    explain = "Slows the enemy under your mouse, else your target.", source = SRC },

  { id = "shaman-purge-mo", name = "Purge", class = "SHAMAN", verified = false, tags = { "utility" }, level = 12,
    body = "#showtooltip\n/cast [@mouseover,harm,nodead][harm,nodead] Purge; [@mouseover,help,nodead][help,nodead][@player] Cure Poison",
    needsSpells = { "Purge" },
    explain = "Purges an enemy buff; on a friend (or nobody) it cures poison instead.", source = SRC },

  { id = "shaman-heal-mo", name = "Heal", class = "SHAMAN", verified = false, tags = { "heal" }, level = 1,
    body = "#showtooltip\n/cast [mod:shift,@mouseover,help,nodead][mod:shift] Lesser Healing Wave; [@mouseover,help,nodead][help,nodead][@player] Healing Wave",
    needsSpells = { "Healing Wave" },
    explain = "Heals the mouseover, else target, else you; Shift for the faster Lesser Healing Wave.", source = SRC },

  { id = "shaman-totems", name = "Totems", class = "SHAMAN", verified = false, tags = { "utility" }, level = 20,
    body = "#showtooltip\n/castsequence reset=combat Searing Totem, Stoneskin Totem, Healing Stream Totem",
    needsSpells = { "Searing Totem", "Stoneskin Totem", "Healing Stream Totem" },
    explain = "Press three times to drop fire, earth and water totems; starts over after combat.", source = SRC },

  { id = "shaman-grounding", name = "Grounding", class = "SHAMAN", verified = false, tags = { "defensive" }, level = 30,
    body = "#showtooltip\n/stopcasting\n/cast [mod:shift] Tremor Totem; Grounding Totem",
    needsSpells = { "Grounding Totem" },
    explain = "Stops your cast and drops Grounding to eat a spell; Shift for Tremor against fear.", source = SRC },

  { id = "shaman-weapon", name = "Weapon", class = "SHAMAN", verified = false, tags = { "utility" }, level = 1,
    body = "#showtooltip\n/cast [mod:shift] Flametongue Weapon; Rockbiter Weapon",
    needsSpells = { "Rockbiter Weapon" },
    explain = "Imbues your weapon with Rockbiter; Shift for Flametongue.", source = SRC },

  { id = "shaman-lshield", name = "LShield", class = "SHAMAN", verified = false, tags = { "defensive" }, level = 8,
    body = "#showtooltip Lightning Shield\n/cast Lightning Shield",
    needsSpells = { "Lightning Shield" }, explain = "Your self-shield on one key (keep it on a bar to see when it drops).", source = SRC },

  { id = "shaman-ghostwolf", name = "GhostWolf", class = "SHAMAN", verified = false, tags = { "utility" }, level = 20,
    body = "#showtooltip Ghost Wolf\n/cast !Ghost Wolf",
    needsSpells = { "Ghost Wolf" }, explain = "Turns into a wolf to run faster; a second press won't turn it off.", source = SRC },
})

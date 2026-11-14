-- Data/Macros_Priest.lua  (P4-08)
-- Priest macros in Classic/Forever syntax. Patterns from community Forever
-- macro guides (Rankedboost "Priest Macros in WoW Forever", Kami-Labs "Macros
-- WoW Forever", 2026) and standard Classic mouseover conventions. Data only;
-- verified = false until Gary presses them on his priest. Rank-less /cast
-- uses the highest rank known (Kami-Labs). Levels are when the main spell is
-- usually learned in Classic and only gate the "level N" hint.

local _, ns = ...
local SRC = "Rankedboost / Kami-Labs Forever priest macros (2026), Classic conventions"

ns.Data:Register("macro", "priest", {
  { id = "priest-shield-mo", name = "Shield", class = "PRIEST", verified = false, tags = { "heal" }, level = 6,
    body = "#showtooltip Power Word: Shield\n/cast [@mouseover,help,nodead][help,nodead][@player] Power Word: Shield",
    needsSpells = { "Power Word: Shield" },
    explain = "Shields whoever is under your mouse, else your friendly target, else you.", source = SRC },

  { id = "priest-renew-mo", name = "Renew", class = "PRIEST", verified = false, tags = { "heal" }, level = 8,
    body = "#showtooltip Renew\n/cast [@mouseover,help,nodead][help,nodead][@player] Renew",
    needsSpells = { "Renew" }, explain = "Mouseover heal over time, falls back to target, then you.", source = SRC },

  { id = "priest-heal-mo", name = "Heal", class = "PRIEST", verified = false, tags = { "heal" },
    body = "#showtooltip\n/cast [mod:shift,@mouseover,help,nodead][mod:shift] Flash Heal; [@mouseover,help,nodead][help,nodead][@player] Lesser Heal",
    needsSpells = { "Lesser Heal" },
    explain = "Mouseover heal; Shift for the fast Flash Heal once you have it.", source = SRC },

  { id = "priest-dispel-mo", name = "Dispel", class = "PRIEST", verified = false, tags = { "heal" }, level = 18,
    body = "#showtooltip Dispel Magic\n/cast [@mouseover,exists,nodead][exists,nodead][@player] Dispel Magic",
    needsSpells = { "Dispel Magic" }, explain = "Dispels on the mouseover (friend or foe), else target, else you.", source = SRC },

  { id = "priest-swp-mo", name = "SWPain", class = "PRIEST", verified = false, tags = { "combat" }, level = 4,
    body = "#showtooltip Shadow Word: Pain\n/cast [@mouseover,harm,nodead][harm,nodead] Shadow Word: Pain",
    needsSpells = { "Shadow Word: Pain" },
    explain = "Dot whatever enemy is under your mouse without changing target.", source = SRC },

  { id = "priest-starter", name = "Opener", class = "PRIEST", verified = false, tags = { "combat" }, level = 10,
    body = "#showtooltip\n/targetenemy [noexists][dead][help]\n/cast [mod:shift] Shadow Word: Pain; Mind Blast",
    needsSpells = { "Mind Blast" }, explain = "Grabs an enemy and opens with Mind Blast; Shift dots instead.", source = SRC },

  { id = "priest-scream", name = "Scream", class = "PRIEST", verified = false, tags = { "defensive" }, level = 14,
    body = "#showtooltip Psychic Scream\n/stopcasting\n/cast Psychic Scream",
    needsSpells = { "Psychic Scream" }, explain = "Stops whatever you were casting and fears everything near you.", source = SRC },

  { id = "priest-fade", name = "Fade", class = "PRIEST", verified = false, tags = { "defensive" }, level = 8,
    body = "#showtooltip Fade\n/stopcasting\n/cast Fade",
    needsSpells = { "Fade" }, explain = "Drops threat right away, even mid-cast.", source = SRC },

  { id = "priest-shackle", name = "Shackle", class = "PRIEST", verified = false, tags = { "control" }, level = 20,
    body = "#showtooltip Shackle Undead\n/cast [@focus,harm,nodead][@mouseover,harm,nodead][] Shackle Undead",
    needsSpells = { "Shackle Undead" },
    explain = "Re-shackles your focus target; set focus on the undead first. Else mouseover, else target.", source = SRC },

  { id = "priest-inner-fire", name = "InnerFire", class = "PRIEST", verified = false, tags = { "utility" }, level = 12,
    body = "#showtooltip Inner Fire\n/cast Inner Fire",
    needsSpells = { "Inner Fire" }, explain = "One key for your self-buff (keep it on a bar to see when it drops).", source = SRC },

  { id = "priest-fortitude-mo", name = "Fortitude", class = "PRIEST", verified = false, tags = { "utility" },
    body = "#showtooltip Power Word: Fortitude\n/cast [@mouseover,help,nodead][help,nodead][@player] Power Word: Fortitude",
    needsSpells = { "Power Word: Fortitude" }, explain = "Buff whoever is under your mouse, else target, else you.", source = SRC },
})

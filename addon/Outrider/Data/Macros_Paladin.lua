-- Data/Macros_Paladin.lua  (P4-08)
-- Paladin macros in Classic/Forever syntax. Patterns from community Forever
-- macro guides (Rankedboost "Paladin Macros in WoW Forever", Kami-Labs "Macros
-- WoW Forever", 2026) and standard Classic mouseover conventions. Data only;
-- verified = false until Gary presses them on a paladin. Forever changes per
-- Rankedboost: Judgement no longer uses up the Seal and melee hits refresh it,
-- Divine Shield (34) shares a cooldown with Divine Protection, and a new
-- trainer strike Holy Strike at level 6 (left out here until seen in game).

local _, ns = ...
local SRC = "Rankedboost / Kami-Labs Forever paladin macros (2026), Classic conventions"

ns.Data:Register("macro", "paladin", {
  { id = "paladin-seal-judge", name = "SealJudge", class = "PALADIN", verified = false, tags = { "combat" }, level = 4,
    body = "#showtooltip\n/startattack\n/cast [mod:shift] Seal of Righteousness; Judgement",
    needsSpells = { "Judgement" },
    explain = "Judges your Seal and keeps you swinging; Shift puts Seal of Righteousness up.", source = SRC },

  { id = "paladin-crusader", name = "Crusader", class = "PALADIN", verified = false, tags = { "combat" }, level = 6,
    body = "#showtooltip\n/startattack\n/castsequence reset=target Seal of the Crusader, Judgement, Seal of Righteousness",
    needsSpells = { "Seal of the Crusader", "Judgement" },
    explain = "Each press: Crusader seal, judge it, then back to Righteousness. New target starts over.", source = SRC },

  { id = "paladin-heal-mo", name = "Heal", class = "PALADIN", verified = false, tags = { "heal" }, level = 1,
    body = "#showtooltip\n/cast [mod:shift,@mouseover,help,nodead][mod:shift] Flash of Light; [@mouseover,help,nodead][help,nodead][@player] Holy Light",
    needsSpells = { "Holy Light" },
    explain = "Heals the mouseover, else target, else you; Shift for the fast Flash of Light.", source = SRC },

  { id = "paladin-cleanse-mo", name = "Cleanse", class = "PALADIN", verified = false, tags = { "heal" }, level = 42,
    body = "#showtooltip Cleanse\n/cast [@mouseover,help,nodead][help,nodead][@player] Cleanse",
    needsSpells = { "Cleanse" },
    explain = "Removes poison, disease and magic from the mouseover, else target, else you.", source = SRC },

  { id = "paladin-purify-mo", name = "Purify", class = "PALADIN", verified = false, tags = { "heal" }, level = 8,
    body = "#showtooltip Purify\n/cast [@mouseover,help,nodead][help,nodead][@player] Purify",
    needsSpells = { "Purify" },
    explain = "Removes poison and disease before you learn Cleanse.", source = SRC },

  { id = "paladin-might-mo", name = "Blessing", class = "PALADIN", verified = false, tags = { "utility" }, level = 4,
    body = "#showtooltip\n/cast [mod:shift,@mouseover,help,nodead][mod:shift] Blessing of Wisdom; [@mouseover,help,nodead][help,nodead][@player] Blessing of Might",
    needsSpells = { "Blessing of Might" },
    explain = "Might on the mouseover, else target, else you; Shift for Wisdom on casters.", source = SRC },

  { id = "paladin-bop-mo", name = "BoP", class = "PALADIN", verified = false, tags = { "defensive" }, level = 10,
    body = "#showtooltip Blessing of Protection\n/cast [@mouseover,help,nodead][help,nodead][@player] Blessing of Protection",
    needsSpells = { "Blessing of Protection" },
    explain = "Shields a friend from physical hits: mouseover, else target, else you.", source = SRC },

  { id = "paladin-freedom-mo", name = "Freedom", class = "PALADIN", verified = false, tags = { "utility" }, level = 18,
    body = "#showtooltip Blessing of Freedom\n/cast [@mouseover,help,nodead][help,nodead][@player] Blessing of Freedom",
    needsSpells = { "Blessing of Freedom" },
    explain = "Frees the mouseover, else target, else you from roots and slows.", source = SRC },

  { id = "paladin-loh-mo", name = "LayOnHands", class = "PALADIN", verified = false, tags = { "heal" }, level = 10,
    body = "#showtooltip Lay on Hands\n/cast [@mouseover,help,nodead][help,nodead][@player] Lay on Hands",
    needsSpells = { "Lay on Hands" },
    explain = "Full heal on the mouseover, else target, else you. Uses all your mana.", source = SRC },

  { id = "paladin-hoj-focus", name = "Hammer", class = "PALADIN", verified = false, tags = { "control" }, level = 8,
    body = "#showtooltip Hammer of Justice\n/cast [@focus,harm,nodead][] Hammer of Justice",
    needsSpells = { "Hammer of Justice" },
    explain = "Stuns your focus target if set, else your target.", source = SRC },

  { id = "paladin-bubble", name = "Bubble", class = "PALADIN", verified = false, tags = { "defensive" }, level = 34,
    body = "#showtooltip Divine Shield\n/stopcasting\n/cast Divine Shield",
    needsSpells = { "Divine Shield" },
    explain = "Stops your cast and makes you immune to damage for a short time.", source = SRC },
})

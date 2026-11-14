-- Data/Macros_Mage.lua  (P4-08)
-- Mage macros in Classic/Forever syntax. Patterns from community Forever
-- macro guides (Rankedboost "Mage Macros in WoW Forever", Kami-Labs "Macros
-- WoW Forever", Warcraft Wiki "Useful macros/Mage", 2026) and standard
-- Classic conventions. Data only; verified = false until Gary presses them on
-- his mage. Ice Block, Ice Barrier and Cold Snap are talents on Forever
-- (Rankedboost), so those entries only show as ready once learned.

local _, ns = ...
local SRC = "Rankedboost / Kami-Labs / Warcraft Wiki mage macros (2026), Classic conventions"

ns.Data:Register("macro", "mage", {
  { id = "mage-poly-focus", name = "Polymorph", class = "MAGE", verified = false, tags = { "control" }, level = 8,
    body = "#showtooltip Polymorph\n/cast [@focus,harm,nodead][@mouseover,harm,nodead][] Polymorph",
    needsSpells = { "Polymorph" },
    explain = "Sheeps your focus (set it on the add first), else the mouseover, else your target.", source = SRC },

  { id = "mage-setfocus", name = "Focus", class = "MAGE", verified = false, tags = { "control" },
    body = "/clearfocus [mod:shift]\n/focus [nomod,@mouseover,exists][nomod]",
    explain = "Sets focus to the mouseover (else target); Shift clears it. Pairs with Polymorph.", source = SRC },

  { id = "mage-nova", name = "Nova", class = "MAGE", verified = false, tags = { "defensive" }, level = 10,
    body = "#showtooltip Frost Nova\n/stopcasting\n/cast Frost Nova",
    needsSpells = { "Frost Nova" }, explain = "Stops your cast and roots everything in melee range.", source = SRC },

  { id = "mage-counterspell", name = "Counter", class = "MAGE", verified = false, tags = { "control" }, level = 24,
    body = "#showtooltip Counterspell\n/stopcasting\n/cast [@focus,harm,nodead][] Counterspell",
    needsSpells = { "Counterspell" }, explain = "Interrupts at once, on your focus if set, else your target.", source = SRC },

  { id = "mage-fireblast", name = "FireBlast", class = "MAGE", verified = false, tags = { "combat" }, level = 6,
    body = "#showtooltip Fire Blast\n/stopcasting\n/cast Fire Blast",
    needsSpells = { "Fire Blast" }, explain = "Instant finisher; cancels a slow cast to land it now.", source = SRC },

  { id = "mage-opener", name = "Opener", class = "MAGE", verified = false, tags = { "combat" },
    body = "#showtooltip\n/targetenemy [noexists][dead][help]\n/cast [mod:shift] Fireball; Frostbolt",
    needsSpells = { "Frostbolt" }, explain = "Grabs an enemy and opens with Frostbolt; Shift for Fireball.", source = SRC },

  { id = "mage-missiles", name = "Missiles", class = "MAGE", verified = false, tags = { "combat" }, level = 8,
    body = "#showtooltip Arcane Missiles\n/cast Arcane Missiles",
    needsSpells = { "Arcane Missiles" }, explain = "Channel; keep it on its own key so mashing doesn't clip it.", source = SRC },

  { id = "mage-conjure", name = "Conjure", class = "MAGE", verified = false, tags = { "utility" }, level = 6,
    body = "#showtooltip\n/cast [mod:shift] Conjure Food; Conjure Water",
    needsSpells = { "Conjure Water", "Conjure Food" }, explain = "Water by default, Shift for food. Highest rank you know.", source = SRC },

  { id = "mage-intellect-mo", name = "Intellect", class = "MAGE", verified = false, tags = { "utility" },
    body = "#showtooltip Arcane Intellect\n/cast [@mouseover,help,nodead][help,nodead][@player] Arcane Intellect",
    needsSpells = { "Arcane Intellect" }, explain = "Buff whoever is under your mouse, else target, else you.", source = SRC },

  { id = "mage-iceblock", name = "IceBlock", class = "MAGE", verified = false, tags = { "defensive", "talent" }, level = 30,
    body = "#showtooltip Ice Block\n/stopcasting\n/cancelaura Ice Block\n/cast Ice Block",
    needsSpells = { "Ice Block" }, explain = "Press to block, press again to come out early (talent).", source = SRC },

  { id = "mage-evocation", name = "Evocate", class = "MAGE", verified = false, tags = { "utility" }, level = 20,
    body = "#showtooltip Evocation\n/stopcasting\n/cast Evocation",
    needsSpells = { "Evocation" }, explain = "Refills mana; stops any cast first.", source = SRC },
})

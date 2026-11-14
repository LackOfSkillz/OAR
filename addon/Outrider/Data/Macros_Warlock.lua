-- Data/Macros_Warlock.lua  (P4-08)
-- Warlock macros in Classic/Forever syntax. Patterns from community Forever
-- macro guides (Rankedboost "Warlock Macros in WoW Forever", Kami-Labs "Macros
-- WoW Forever", 2026) and standard Classic pet and focus conventions. Data
-- only; verified = false until Gary presses them on a warlock. Demon spells
-- (Seduction, Spell Lock, Torment) live in the pet spellbook, so those entries
-- gate on level only, not needsSpells. Forever changes per Rankedboost: Curse
-- of Agony is renamed Bane of Agony and has its own slot (left out here until
-- seen in game), Dark Pact and Curse of Shadow are removed.

local _, ns = ...
local SRC = "Rankedboost / Kami-Labs Forever warlock macros (2026), Classic conventions"

ns.Data:Register("macro", "warlock", {
  { id = "warlock-petattack", name = "PetBolt", class = "WARLOCK", verified = false, tags = { "combat", "pet" }, level = 1,
    body = "#showtooltip Shadow Bolt\n/petattack [mod:shift]\n/petfollow [mod:ctrl]\n/cast [nomod:ctrl] Shadow Bolt",
    needsSpells = { "Shadow Bolt" },
    explain = "Shadow Bolt; Shift also sends the demon in, Ctrl calls it back.", source = SRC },

  { id = "warlock-corruption-mo", name = "Corruption", class = "WARLOCK", verified = false, tags = { "combat" }, level = 4,
    body = "#showtooltip Corruption\n/cast [@mouseover,harm,nodead][harm,nodead] Corruption",
    needsSpells = { "Corruption" },
    explain = "Dot whatever enemy is under your mouse without changing target.", source = SRC },

  { id = "warlock-fear-focus", name = "Fear", class = "WARLOCK", verified = false, tags = { "control" }, level = 8,
    body = "#showtooltip Fear\n/cast [@focus,harm,nodead][@mouseover,harm,nodead][] Fear",
    needsSpells = { "Fear" },
    explain = "Fears your focus (set it on the add first), else the mouseover, else your target.", source = SRC },

  { id = "warlock-banish-focus", name = "Banish", class = "WARLOCK", verified = false, tags = { "control" }, level = 28,
    body = "#showtooltip Banish\n/cast [@focus,harm,nodead][@mouseover,harm,nodead][] Banish",
    needsSpells = { "Banish" },
    explain = "Banishes your focus, else mouseover, else target. Demons and elementals only.", source = SRC },

  { id = "warlock-seduce", name = "Seduce", class = "WARLOCK", verified = false, tags = { "control", "pet" }, level = 26,
    body = "#showtooltip Seduction\n/cast [@focus,harm,nodead][] Seduction",
    explain = "Your Succubus seduces your focus target, else your target.", source = SRC },

  { id = "warlock-spelllock", name = "SpellLock", class = "WARLOCK", verified = false, tags = { "control", "pet" }, level = 30,
    body = "#showtooltip Spell Lock\n/cast [@focus,harm,nodead][] Spell Lock",
    explain = "Your Felhunter interrupts your focus target, else your target.", source = SRC },

  { id = "warlock-torment", name = "Torment", class = "WARLOCK", verified = false, tags = { "pet" }, level = 10,
    body = "#showtooltip Torment\n/petattack\n/cast Torment",
    explain = "Sends your Voidwalker in and has it taunt your target.", source = SRC },

  { id = "warlock-drainsoul", name = "DrainSoul", class = "WARLOCK", verified = false, tags = { "utility" }, level = 10,
    body = "#showtooltip Drain Soul\n/cast Drain Soul",
    needsSpells = { "Drain Soul" },
    explain = "Channel as the enemy dies to get a Soul Shard. Keep it on its own key.", source = SRC },

  { id = "warlock-lifetap", name = "LifeTap", class = "WARLOCK", verified = false, tags = { "utility" }, level = 6,
    body = "#showtooltip Life Tap\n/cast Life Tap",
    needsSpells = { "Life Tap" }, explain = "Turns health into mana.", source = SRC },

  { id = "warlock-healthstone", name = "Healthstone", class = "WARLOCK", verified = false, tags = { "defensive" }, level = 10,
    body = "#showtooltip\n/use Major Healthstone\n/use Greater Healthstone\n/use Healthstone\n/use Lesser Healthstone\n/use Minor Healthstone",
    explain = "Eats whichever Healthstone you carry, biggest first.", source = SRC },

  { id = "warlock-deathcoil", name = "DeathCoil", class = "WARLOCK", verified = false, tags = { "defensive", "control" }, level = 42,
    body = "#showtooltip Death Coil\n/stopcasting\n/cast Death Coil",
    needsSpells = { "Death Coil" },
    explain = "Stops your cast and horrifies the target at once; heals you a little.", source = SRC },
})

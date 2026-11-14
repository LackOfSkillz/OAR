-- Data/Macros_Warrior.lua  (P4-08)
-- Warrior macros in Classic/Forever syntax. Patterns from community Forever
-- macro guides (Rankedboost "Warrior Macros in WoW Forever", Kami-Labs "Macros
-- WoW Forever", 2026) and standard Classic stance conventions. Data only;
-- verified = false until Gary presses them on a warrior. Stance numbers are
-- the Classic ones: 1 Battle, 2 Defensive, 3 Berserker. Forever changes per
-- Rankedboost: Tactical Mastery is a level 14 trainer passive (keeps up to 10
-- Rage through stance swaps), Berserker Rage at 30, Thunder Clap has a 6 sec
-- cooldown, Retaliation and Shield Wall are on 15 min cooldowns, Victory Rush
-- exists at level 20 (left out here until seen in game).

local _, ns = ...
local SRC = "Rankedboost / Kami-Labs Forever warrior macros (2026), Classic conventions"

ns.Data:Register("macro", "warrior", {
  { id = "warrior-charge", name = "Charge", class = "WARRIOR", verified = false, tags = { "combat" }, level = 4,
    body = "#showtooltip\n/cast [nocombat,stance:1] Charge; [combat,stance:3] Intercept; [nocombat] Battle Stance; Berserker Stance",
    needsSpells = { "Charge" },
    explain = "Charge out of combat, Intercept in combat; swaps to the right stance first.", source = SRC },

  { id = "warrior-interrupt", name = "Interrupt", class = "WARRIOR", verified = false, tags = { "control" }, level = 12,
    body = "#showtooltip\n/cast [stance:3] Pummel; Shield Bash",
    needsSpells = { "Shield Bash" },
    explain = "Pummel in Berserker Stance, Shield Bash in the others (needs a shield).", source = SRC },

  { id = "warrior-sunder", name = "Sunder", class = "WARRIOR", verified = false, tags = { "combat" }, level = 10,
    body = "#showtooltip\n/startattack\n/cast [mod:shift] Heroic Strike; Sunder Armor",
    needsSpells = { "Sunder Armor" },
    explain = "Stacks Sunder Armor and keeps you swinging; Shift for Heroic Strike.", source = SRC },

  { id = "warrior-overpower", name = "Overpower", class = "WARRIOR", verified = false, tags = { "combat" }, level = 12,
    body = "#showtooltip Overpower\n/startattack\n/cast [stance:1] Overpower; Battle Stance",
    needsSpells = { "Overpower" },
    explain = "Overpower after a dodge; the first press swaps to Battle Stance if needed.", source = SRC },

  { id = "warrior-execute", name = "Execute", class = "WARRIOR", verified = false, tags = { "combat" }, level = 24,
    body = "#showtooltip Execute\n/startattack\n/cast [stance:1/3] Execute; Battle Stance",
    needsSpells = { "Execute" },
    explain = "Finisher below 20% health; leaves Defensive Stance first if you are in it.", source = SRC },

  { id = "warrior-thunderclap", name = "ThunderClap", class = "WARRIOR", verified = false, tags = { "combat" }, level = 6,
    body = "#showtooltip\n/cast [mod:shift] Demoralizing Shout; [stance:1] Thunder Clap; Battle Stance",
    needsSpells = { "Thunder Clap" },
    explain = "Thunder Clap in Battle Stance; Shift for Demoralizing Shout.", source = SRC },

  { id = "warrior-taunt", name = "Taunt", class = "WARRIOR", verified = false, tags = { "control" }, level = 10,
    body = "#showtooltip\n/cast [stance:2] Taunt; [stance:1] Mocking Blow; Defensive Stance",
    needsSpells = { "Taunt" },
    explain = "Taunt in Defensive Stance, Mocking Blow in Battle Stance, else go Defensive.", source = SRC },

  { id = "warrior-shout", name = "Shout", class = "WARRIOR", verified = false, tags = { "utility" }, level = 1,
    body = "#showtooltip Battle Shout\n/cast Battle Shout",
    needsSpells = { "Battle Shout" }, explain = "Your party attack power buff on one key.", source = SRC },

  { id = "warrior-bloodrage", name = "Bloodrage", class = "WARRIOR", verified = false, tags = { "combat" }, level = 10,
    body = "#showtooltip Bloodrage\n/cast Bloodrage\n/startattack",
    needsSpells = { "Bloodrage" }, explain = "Gives you Rage to start a fight and starts swinging.", source = SRC },

  { id = "warrior-fear", name = "Intimidate", class = "WARRIOR", verified = false, tags = { "defensive" }, level = 22,
    body = "#showtooltip Intimidating Shout\n/stopattack\n/cast Intimidating Shout",
    needsSpells = { "Intimidating Shout" },
    explain = "Stops your swing so it does not break the fear, then fears nearby enemies.", source = SRC },

  { id = "warrior-shieldwall", name = "ShieldWall", class = "WARRIOR", verified = false, tags = { "defensive" }, level = 28,
    body = "#showtooltip\n/cast [stance:2] Shield Wall; Defensive Stance",
    needsSpells = { "Shield Wall" },
    explain = "Emergency damage cut; the first press swaps to Defensive Stance if needed.", source = SRC },
})

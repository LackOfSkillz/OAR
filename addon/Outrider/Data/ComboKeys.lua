-- Data/ComboKeys.lua: combined keys (Gary, 2026-11-20: "combine as many best
-- sequences into fewer macros"). Each key folds several single macros into one
-- button with up to four layers: a plain press, Shift, Ctrl and Alt. Every
-- layer is a normal macro condition ([nomod], [mod:shift] ...) that Gary holds
-- himself, so this is the same as any hand-written modifier macro: one press,
-- one action, chosen by the player. Nothing in a macro looks at cooldowns or
-- picks a spell by itself (that is protected; rule 1).
--
-- A layer lists alternatives; the first spell the character knows wins, and
-- an alternative may carry its own condition (equipped:Shields ...). `at` picks
-- who it lands on: "focus" (your focus if hostile, else your target),
-- "mouseover" (the enemy under your mouse, else your target) or "player".
-- `replaces` names the single macros the key makes unnecessary; the Macros
-- page hides those unless "Show singles" is on.
--
-- Spell names are checked against Data/SpellInfo.lua (the client spellbook
-- pages, foreverchanges.pro) by tests/spec/combokeys_spec.lua; verified = false
-- until Gary presses each layer in game.

local _, ns = ...

ns.ComboKeyData = {
  -- the same for every class
  ALL = {
    { name = "Recover", items = true, explain = "Plain press out of combat: eat and drink. In combat: healthstone, then a healing potion. Shift: bandage yourself.",
      replaces = { "all-eat-drink", "all-healpot", "all-bandage" } },
    { name = "Team", team = true, explain = "Plain press: assist (take the target of the friend under your mouse, else of your target). Shift: set focus (mouse-over, else target). Ctrl: clear focus.",
      replaces = { "all-assist", "all-focus" } },
    { name = "Burst", burst = true, explain = "Both trinkets and your big cooldown in one press; Shift for the second cooldown. Save it for a hard pull or a boss.",
      replaces = { "all-trinkets" } },
  },

  ROGUE = {
    Stop = { { "Kick", at = "focus" } }, StopShift = { { "Gouge" } }, StopCtrl = { { "Kidney Shot" } }, StopAlt = { { "Blind", at = "mouseover" } },
    Save = { { "Evasion" } }, SaveShift = { { "Vanish" } }, SaveCtrl = { { "Sprint" } }, SaveAlt = { { "Feint" } },
    Burst = { { "Adrenaline Rush" }, { "Cold Blood" }, { "Premeditation" } }, BurstShift = { { "Blade Flurry" }, { "Preparation" } },
  },
  WARRIOR = {
    Stop = { { "Shield Bash", cond = "equipped:Shields", at = "focus" }, { "Pummel", at = "focus" } }, StopShift = { { "Hamstring" } },
    StopCtrl = { { "Intimidating Shout" } }, StopAlt = { { "Concussion Blow" } },
    Save = { { "Shield Wall" } }, SaveShift = { { "Last Stand" } }, SaveCtrl = { { "Shield Block" } },
    Burst = { { "Death Wish" }, { "Recklessness" } }, BurstShift = { { "Sweeping Strikes" }, { "Bloodrage" } },
  },
  MAGE = {
    Stop = { { "Counterspell", at = "focus" } }, StopShift = { { "Polymorph", at = "mouseover" } }, StopCtrl = { { "Frost Nova" } }, StopAlt = { { "Cone of Cold" } },
    Save = { { "Ice Block" } }, SaveShift = { { "Blink" } }, SaveCtrl = { { "Ice Barrier" }, { "Mana Shield" } },
    Burst = { { "Arcane Power" }, { "Combustion" }, { "Presence of Mind" } }, BurstShift = { { "Presence of Mind" }, { "Cold Snap" } },
  },
  PRIEST = {
    Stop = { { "Silence", at = "focus" } }, StopShift = { { "Psychic Scream" } }, StopCtrl = { { "Shackle Undead", at = "mouseover" } },
    Save = { { "Power Word: Shield", at = "player" } }, SaveShift = { { "Fade" } }, SaveCtrl = { { "Desperate Prayer" } },
    Burst = { { "Power Infusion", at = "player" }, { "Inner Focus" } }, BurstShift = { { "Inner Focus" } },
  },
  HUNTER = {
    Stop = { { "Scatter Shot", at = "focus" } }, StopShift = { { "Concussive Shot" } }, StopCtrl = { { "Freezing Trap" } },
    Save = { { "Feign Death" } }, SaveShift = { { "Disengage" } }, SaveCtrl = { { "Deterrence" } },
    Burst = { { "Bestial Wrath" }, { "Rapid Fire" } }, BurstShift = { { "Rapid Fire" } },
  },
  WARLOCK = {
    Stop = { { "Fear", at = "mouseover" } }, StopShift = { { "Howl of Terror" } }, StopCtrl = { { "Death Coil" } }, StopAlt = { { "Banish", at = "mouseover" } },
    Save = { { "Shadow Ward" } }, SaveShift = { { "Death Coil" } }, SaveCtrl = { { "Life Tap" } },
    Burst = { { "Amplify Curse" }, { "Fel Domination" } }, BurstShift = { { "Fel Domination" } },
  },
  DRUID = {
    Stop = { { "Bash", at = "focus" } }, StopShift = { { "Entangling Roots", at = "mouseover" } }, StopCtrl = { { "Hibernate", at = "mouseover" } },
    Save = { { "Barkskin" } }, SaveShift = { { "Frenzied Regeneration" } }, SaveCtrl = { { "Dash" } },
    Burst = { { "Nature's Swiftness" }, { "Innervate", at = "player" } }, BurstShift = { { "Innervate", at = "player" } },
  },
  SHAMAN = {
    Stop = { { "Earth Shock", at = "focus" } }, StopShift = { { "Frost Shock" } }, StopCtrl = { { "Purge" } },
    Save = { { "Grounding Totem" } }, SaveShift = { { "Stoneclaw Totem" } },
    Burst = { { "Nature's Swiftness" } },
  },
  PALADIN = {
    Stop = { { "Hammer of Justice", at = "focus" } }, StopShift = { { "Repentance" } }, StopCtrl = { { "Turn Undead" } },
    Save = { { "Divine Shield" }, { "Divine Protection" } }, SaveShift = { { "Blessing of Protection", at = "player" } }, SaveCtrl = { { "Lay on Hands", at = "player" } },
    Burst = { { "Divine Favor" } },
  },
}

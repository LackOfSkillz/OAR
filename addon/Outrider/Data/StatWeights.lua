-- Data/StatWeights.lua  (P6-01)
-- Starting-point stat weights for levelling, per class (one default role
-- each). Keys are the client's item stat tokens from C_Item.GetItemStats.
-- These are judgement-based starting points in line with common Classic
-- levelling advice (Agility/AP for hunters and rogues, Strength for warriors,
-- Intellect/Spirit/spell power for casters, Stamina for everyone), NOT
-- measured game data: Gary can override per character (/ride weights).
-- Weapon DPS is weighted per point of DPS; armor per point.

local _, ns = ...
local S = "Outrider starting points (Classic levelling conventions), unverified"

local function w(t) t.source = S return t end

ns.StatWeights = {
  HUNTER = w { role = "Ranged (levelling)", ITEM_MOD_AGILITY_SHORT = 1.0, ITEM_MOD_ATTACK_POWER_SHORT = 0.45,
    ITEM_MOD_RANGED_ATTACK_POWER_SHORT = 0.45, ITEM_MOD_STAMINA_SHORT = 0.55, ITEM_MOD_INTELLECT_SHORT = 0.25,
    ITEM_MOD_STRENGTH_SHORT = 0.05, ITEM_MOD_SPIRIT_SHORT = 0.05, ITEM_MOD_CRIT_RATING_SHORT = 0.8,
    ITEM_MOD_HIT_RATING_SHORT = 0.9, RESISTANCE0_NAME = 0.01, rangedDPS = 3.0, meleeDPS = 0.3 },
  ROGUE = w { role = "Melee (levelling)", ITEM_MOD_AGILITY_SHORT = 1.0, ITEM_MOD_STRENGTH_SHORT = 0.5,
    ITEM_MOD_ATTACK_POWER_SHORT = 0.45, ITEM_MOD_STAMINA_SHORT = 0.5, ITEM_MOD_CRIT_RATING_SHORT = 0.8,
    ITEM_MOD_HIT_RATING_SHORT = 0.9, RESISTANCE0_NAME = 0.01, meleeDPS = 2.5 },
  WARRIOR = w { role = "Melee (levelling)", ITEM_MOD_STRENGTH_SHORT = 1.0, ITEM_MOD_AGILITY_SHORT = 0.6,
    ITEM_MOD_ATTACK_POWER_SHORT = 0.45, ITEM_MOD_STAMINA_SHORT = 0.6, ITEM_MOD_CRIT_RATING_SHORT = 0.8,
    ITEM_MOD_HIT_RATING_SHORT = 0.9, RESISTANCE0_NAME = 0.015, meleeDPS = 2.5 },
  PALADIN = w { role = "Melee (levelling)", ITEM_MOD_STRENGTH_SHORT = 1.0, ITEM_MOD_STAMINA_SHORT = 0.6,
    ITEM_MOD_INTELLECT_SHORT = 0.35, ITEM_MOD_AGILITY_SHORT = 0.4, ITEM_MOD_ATTACK_POWER_SHORT = 0.45,
    ITEM_MOD_SPELL_POWER_SHORT = 0.3, ITEM_MOD_CRIT_RATING_SHORT = 0.7, RESISTANCE0_NAME = 0.015, meleeDPS = 2.2 },
  SHAMAN = w { role = "Hybrid (levelling)", ITEM_MOD_STRENGTH_SHORT = 0.8, ITEM_MOD_AGILITY_SHORT = 0.6,
    ITEM_MOD_INTELLECT_SHORT = 0.6, ITEM_MOD_STAMINA_SHORT = 0.55, ITEM_MOD_SPELL_POWER_SHORT = 0.6,
    ITEM_MOD_ATTACK_POWER_SHORT = 0.4, ITEM_MOD_SPIRIT_SHORT = 0.2, RESISTANCE0_NAME = 0.01, meleeDPS = 2.0 },
  DRUID = w { role = "Hybrid (levelling)", ITEM_MOD_STRENGTH_SHORT = 0.7, ITEM_MOD_AGILITY_SHORT = 0.6,
    ITEM_MOD_INTELLECT_SHORT = 0.6, ITEM_MOD_SPIRIT_SHORT = 0.4, ITEM_MOD_STAMINA_SHORT = 0.55,
    ITEM_MOD_SPELL_POWER_SHORT = 0.6, RESISTANCE0_NAME = 0.01 },
  PRIEST = w { role = "Caster (levelling)", ITEM_MOD_INTELLECT_SHORT = 0.8, ITEM_MOD_SPIRIT_SHORT = 0.8,
    ITEM_MOD_SPELL_POWER_SHORT = 1.0, ITEM_MOD_STAMINA_SHORT = 0.5, ITEM_MOD_CRIT_RATING_SHORT = 0.5,
    RESISTANCE0_NAME = 0.005 },
  MAGE = w { role = "Caster (levelling)", ITEM_MOD_INTELLECT_SHORT = 0.8, ITEM_MOD_SPIRIT_SHORT = 0.5,
    ITEM_MOD_SPELL_POWER_SHORT = 1.0, ITEM_MOD_STAMINA_SHORT = 0.5, ITEM_MOD_CRIT_RATING_SHORT = 0.6,
    ITEM_MOD_HIT_RATING_SHORT = 0.7, RESISTANCE0_NAME = 0.005 },
  WARLOCK = w { role = "Caster (levelling)", ITEM_MOD_INTELLECT_SHORT = 0.6, ITEM_MOD_SPIRIT_SHORT = 0.5,
    ITEM_MOD_SPELL_POWER_SHORT = 1.0, ITEM_MOD_STAMINA_SHORT = 0.7, ITEM_MOD_HIT_RATING_SHORT = 0.7,
    RESISTANCE0_NAME = 0.005 },
}

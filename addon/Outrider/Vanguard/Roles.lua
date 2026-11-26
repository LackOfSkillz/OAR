-- Vanguard/Roles.lua
-- VG02-01: role evidence registry. Which roles each of the nine classes can
-- fill, what kind of player that role is (melee, ranged, caster), which gear
-- stats to read for it, and which mechanics Outrider can't model (so they
-- show as "not modeled" instead of a made-up number).
--
-- Source: the class design every Classic-based client shares (which class can
-- tank, heal or deal damage). verified = false on WoW Forever until seen in
-- game; faction limits for paladins and shamans are not assumed (unknown).
-- A hybrid role lists every kind; the build picks one, and until we know the
-- build, indicators for every kind are shown.

local _, ns = ...
ns.Vanguard = ns.Vanguard or {}
local R = { VERSION = 1, SOURCE = "Classic class design (role availability), verified = false on Forever" }
ns.Vanguard.Roles = R

R.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

-- stat tokens are the client's item stat keys (C_Item.GetItemStats)
local ST = {
  str = "ITEM_MOD_STRENGTH_SHORT", agi = "ITEM_MOD_AGILITY_SHORT", sta = "ITEM_MOD_STAMINA_SHORT",
  int = "ITEM_MOD_INTELLECT_SHORT", spi = "ITEM_MOD_SPIRIT_SHORT", ap = "ITEM_MOD_ATTACK_POWER_SHORT",
  rap = "ITEM_MOD_RANGED_ATTACK_POWER_SHORT", sp = "ITEM_MOD_SPELL_POWER_SHORT", heal = "ITEM_MOD_SPELL_HEALING_DONE_SHORT",
  mp5 = "ITEM_MOD_MANA_REGENERATION_SHORT", crit = "ITEM_MOD_CRIT_RATING_SHORT", hit = "ITEM_MOD_HIT_RATING_SHORT",
  def = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", dodge = "ITEM_MOD_DODGE_RATING_SHORT", parry = "ITEM_MOD_PARRY_RATING_SHORT",
  block = "ITEM_MOD_BLOCK_RATING_SHORT", armor = "RESISTANCE0_NAME", dps = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT",
  fire = "RESISTANCE2_NAME", nature = "RESISTANCE3_NAME", frost = "RESISTANCE4_NAME", shadow = "RESISTANCE5_NAME", arcane = "RESISTANCE6_NAME",
}
R.STAT = ST

-- indicator id -> how to read it from the derived gear stats
R.INDICATORS = {
  stamina = { label = "Stamina", stat = ST.sta, unit = "points" },
  armor = { label = "Armor", stat = ST.armor, unit = "points" },
  defense = { label = "Defense rating", stat = ST.def, unit = "rating" },
  avoidance = { label = "Dodge, parry, block rating", stats = { ST.dodge, ST.parry, ST.block }, unit = "rating" },
  resist = { label = "Resistances (all schools)", stats = { ST.fire, ST.nature, ST.frost, ST.shadow, ST.arcane }, unit = "points" },
  intellect = { label = "Intellect", stat = ST.int, unit = "points" },
  spirit = { label = "Spirit", stat = ST.spi, unit = "points" },
  healing = { label = "Healing and spell power", stats = { ST.heal, ST.sp }, unit = "points" },
  mp5 = { label = "Mana every 5 seconds", stat = ST.mp5, unit = "mana" },
  strength = { label = "Strength", stat = ST.str, unit = "points" },
  agility = { label = "Agility", stat = ST.agi, unit = "points" },
  attack = { label = "Attack power", stats = { ST.ap, ST.rap }, unit = "points" },
  spellpower = { label = "Spell power", stat = ST.sp, unit = "points" },
  crit = { label = "Critical strike rating", stat = ST.crit, unit = "rating" },
  hit = { label = "Hit rating", stat = ST.hit, unit = "rating" },
  weapon = { label = "Main weapon damage per second", stat = ST.dps, slot = 16, unit = "dps" },
  ranged = { label = "Ranged weapon damage per second", stat = ST.dps, slot = 18, unit = "dps" },
}

-- what each kind of role reads, and what it can't model
local KIND = {
  tank = { indicators = { "stamina", "armor", "defense", "avoidance", "resist" },
    missing = { "damage taken after armor (no verified armor formula on Forever)", "threat (no verified threat formula)",
      "avoidance chance (rating to percent not verified)" } },
  healer = { indicators = { "intellect", "spirit", "healing", "mp5", "stamina" },
    missing = { "healing per second (needs spell ranks and rotation)", "how long the mana lasts (regen rules not verified)" } },
  melee = { indicators = { "strength", "agility", "attack", "crit", "hit", "weapon", "stamina" },
    missing = { "damage per second (rotation, procs and buffs not modeled)", "hit and crit chance (rating conversion not verified)" } },
  ranged = { indicators = { "agility", "attack", "crit", "hit", "ranged", "stamina" },
    missing = { "damage per second (rotation, procs and pet not modeled)", "hit and crit chance (rating conversion not verified)" } },
  caster = { indicators = { "intellect", "spellpower", "crit", "hit", "spirit", "stamina" },
    missing = { "damage per second (spell ranks and rotation not modeled)", "how long the mana lasts" } },
}
R.KIND = KIND

-- class -> role -> kinds (hybrids list more than one)
R.BY_CLASS = {
  WARRIOR = { TANK = { "tank" }, DAMAGER = { "melee" } },
  PALADIN = { TANK = { "tank" }, HEALER = { "healer" }, DAMAGER = { "melee" } },
  HUNTER = { DAMAGER = { "ranged" } },
  ROGUE = { DAMAGER = { "melee" } },
  PRIEST = { HEALER = { "healer" }, DAMAGER = { "caster" } },
  SHAMAN = { HEALER = { "healer" }, DAMAGER = { "melee", "caster" } },
  MAGE = { DAMAGER = { "caster" } },
  WARLOCK = { DAMAGER = { "caster" } },
  DRUID = { TANK = { "tank" }, HEALER = { "healer" }, DAMAGER = { "melee", "caster" } },
}

R.FACTION_NOTE = "faction limits (paladins, shamans) not assumed on Forever"

function R.Roles(class)
  local t = R.BY_CLASS[class]
  if not t then return nil end
  local out = {}
  for _, role in ipairs({ "TANK", "HEALER", "DAMAGER" }) do if t[role] then out[#out + 1] = role end end
  return out
end

-- the profile for a class and role, or nil and why
function R.Get(class, role)
  local t = R.BY_CLASS[class]
  if not t then return nil, "class not known" end
  if not role then return nil, "role not known" end
  local kinds = t[role]
  if not kinds then return nil, "this class has no " .. tostring(role):lower() .. " role in the registry" end
  local ids, seen, missing = {}, {}, {}
  for _, k in ipairs(kinds) do
    for _, id in ipairs(KIND[k].indicators) do if not seen[id] then seen[id] = true ids[#ids + 1] = id end end
    for _, m in ipairs(KIND[k].missing) do missing[#missing + 1] = m end
  end
  return { version = R.VERSION, class = class, role = role, kinds = kinds, hybrid = #kinds > 1 or nil,
    indicators = ids, missing = missing, source = R.SOURCE, verified = false }
end

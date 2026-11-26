-- Vanguard/Utility.lua
-- VG02-06/07: what a group can bring besides damage, healing and tanking:
-- interrupts, dispels by type, crowd control, resurrection, buffs and taunts.
--
-- Where the facts come from:
--   * candidate spells per class and capability are Outrider's list;
--   * a spell only counts if the Forever spellbook data has it for that class
--     (Data/SpellInfo.lua, foreverchanges.pro, verified = false), and its
--     trainer level comes from there. A talent spell has no trainer level.
-- States for one member (never mixed up):
--   verified   you, and your spellbook has it (seen by Outrider)
--   potential  their class learns it by their level; trained or not, we can't see
--   unlikely   their level is below the trainer level in the data (data unverified)
--   talent     a talent spell: only if they took it, which we can't see
--   unknown    class or level not readable
-- Coverage for the group (stacking, VG02-07): a buff from two providers of
-- the same kind counts once (duplicates never inflate); party-scope effects
-- reach only their own subgroup in a raid; a rule we don't know stays unknown.

local _, ns = ...
local C = ns.Compat
ns.Vanguard = ns.Vanguard or {}
local Obs = ns.Vanguard.Obs
local U = { VERSION = 1, SOURCE = "Outrider candidate list; spells and levels from Data/SpellInfo.lua (verified = false)" }
ns.Vanguard.Utility = U

-- scope: target (one player), party (own subgroup), raid (everyone), self
-- stack: "one" = several providers count once; "each" = each provider adds a
-- different instance (blessings); nil = rule unknown (counted once, marked)
U.CAPS = {
  interrupt = { label = "Interrupt", scope = "target", stack = "each",
    spells = { WARRIOR = { "Pummel", "Shield Bash" }, ROGUE = { "Kick" }, MAGE = { "Counterspell" }, SHAMAN = { "Earth Shock" }, PRIEST = { "Silence" } } },
  dispel_magic = { label = "Remove magic", scope = "target", stack = "each",
    spells = { PRIEST = { "Dispel Magic" }, PALADIN = { "Cleanse" } } },
  dispel_curse = { label = "Remove curse", scope = "target", stack = "each",
    spells = { MAGE = { "Remove Lesser Curse" }, DRUID = { "Remove Curse" } } },
  dispel_poison = { label = "Remove poison", scope = "target", stack = "each",
    spells = { DRUID = { "Cure Poison", "Abolish Poison" }, PALADIN = { "Purify", "Cleanse" }, SHAMAN = { "Cure Poison" } } },
  dispel_disease = { label = "Remove disease", scope = "target", stack = "each",
    spells = { PRIEST = { "Cure Disease", "Abolish Disease" }, PALADIN = { "Purify", "Cleanse" }, SHAMAN = { "Cure Disease" } } },
  purge = { label = "Remove enemy magic", scope = "target", stack = "each",
    spells = { PRIEST = { "Dispel Magic" }, SHAMAN = { "Purge" } } },
  cc = { label = "Crowd control", scope = "target", stack = "each",
    spells = { MAGE = { "Polymorph" }, ROGUE = { "Sap" }, WARLOCK = { "Fear", "Banish" }, HUNTER = { "Freezing Trap" },
      PRIEST = { "Shackle Undead" }, DRUID = { "Hibernate" }, PALADIN = { "Turn Undead", "Repentance" } } },
  stun = { label = "Stun", scope = "target", stack = "each",
    spells = { PALADIN = { "Hammer of Justice" } } },
  rez = { label = "Resurrect (out of combat)", scope = "target", stack = "each",
    spells = { PRIEST = { "Resurrection" }, PALADIN = { "Redemption" }, SHAMAN = { "Ancestral Spirit" } } },
  battle_rez = { label = "Resurrect in combat", scope = "target", stack = "each",
    spells = { DRUID = { "Rebirth" }, WARLOCK = { "Create Soulstone" } } },
  taunt = { label = "Taunt", scope = "target", stack = "each",
    spells = { WARRIOR = { "Taunt" }, DRUID = { "Growl" } } },
  buff_stamina = { label = "Stamina buff", scope = "raid", stack = "one",
    spells = { PRIEST = { "Power Word: Fortitude", "Prayer of Fortitude" } } },
  buff_intellect = { label = "Intellect buff", scope = "raid", stack = "one",
    spells = { MAGE = { "Arcane Intellect" } } },
  buff_wild = { label = "Mark of the Wild", scope = "raid", stack = "one",
    spells = { DRUID = { "Mark of the Wild" } } },
  buff_spirit = { label = "Spirit buff", scope = "raid", stack = "one",
    spells = { PRIEST = { "Divine Spirit" } } },
  blessing = { label = "Blessings", scope = "raid", stack = "each",
    spells = { PALADIN = { "Blessing of Might", "Blessing of Wisdom", "Blessing of Kings" } } },
  aura = { label = "Paladin aura", scope = "party", stack = "each",
    spells = { PALADIN = { "Devotion Aura" } } },
  shout = { label = "Battle Shout", scope = "party", stack = "one",
    spells = { WARRIOR = { "Battle Shout" } } },
  trueshot = { label = "Trueshot Aura", scope = "party", stack = "one",
    spells = { HUNTER = { "Trueshot Aura" } } },
  innervate = { label = "Mana for a healer (Innervate)", scope = "target", stack = "each",
    spells = { DRUID = { "Innervate" } } },
  tranq = { label = "Remove enrage (Tranquilizing Shot)", scope = "target", stack = "each",
    spells = { HUNTER = { "Tranquilizing Shot" } } },
  breath = { label = "Water breathing", scope = "target", stack = "one",
    spells = { WARLOCK = { "Unending Breath" }, SHAMAN = { "Water Breathing" } } },
}
U.ORDER = { "interrupt", "dispel_magic", "dispel_curse", "dispel_poison", "dispel_disease", "purge", "cc", "stun",
  "rez", "battle_rez", "taunt", "buff_stamina", "buff_intellect", "buff_wild", "buff_spirit", "blessing", "aura",
  "shout", "trueshot", "innervate", "tranq", "breath" }

local function info(class, spell)
  local book = ns.SpellInfo and ns.SpellInfo[class]
  return type(book) == "table" and book[spell] or nil
end

-- the candidate spells for a capability and class that the Forever data has
function U.Spells(cap, class)
  local c = U.CAPS[cap]
  local out = {}
  for _, name in ipairs(c and c.spells[class] or {}) do
    local i = info(class, name)
    if i then out[#out + 1] = { name = name, level = i.level, talent = i.level == nil } end
  end
  return out
end

-- your own spellbook: the Spellbook module's last scan, else its saved copy.
-- true = known, false = the spellbook was read and it isn't there, nil = no spellbook read
function U.Knows(spell)
  local key = type(spell) == "string" and spell:lower() or nil
  if not key then return nil end
  local sb = ns.Modules and ns.Modules:Get("Spellbook")
  local live = sb and type(sb.spells) == "table" and sb.spells or nil
  local saved = ns.db and ns.db.char and type(ns.db.char.spellbook) == "table" and type(ns.db.char.spellbook.spells) == "table"
    and ns.db.char.spellbook.spells or nil
  if (live and live[key]) or (saved and saved[key]) then return true end
  if (live and next(live)) or (saved and next(saved)) then return false end
  return nil
end

-- one member, one capability -> { state, spell, level, reason }
function U.Member(member, cap)
  local class = Obs.Value(member.class)
  local level = Obs.Num(member.level)
  if not class then return { state = "unknown", reason = "class not readable" } end
  local list = U.Spells(cap, class)
  if #list == 0 then return { state = "none", reason = "class has none in the Forever spellbook data" } end
  if member.self then
    for _, s in ipairs(list) do
      if U.Knows(s.name) then return { state = "verified", spell = s.name, reason = "in your spellbook" } end
    end
  end
  local best
  for _, s in ipairs(list) do
    if s.talent then
      best = best or { state = "talent", spell = s.name, reason = "a talent: only if they took it" }
    elseif level and level >= s.level then
      return { state = "potential", spell = s.name, level = s.level, reason = "class learns it at " .. s.level }
    elseif level then
      if not best or best.state ~= "talent" then
        best = best or { state = "unlikely", spell = s.name, level = s.level, reason = "learned at " .. s.level .. " (data not verified)" }
      end
    else
      return { state = "unknown", spell = s.name, reason = "level not readable" }
    end
  end
  return best
end

-- whole group: members = roster members (with subgroup in a raid)
-- -> { [cap] = { state, providers = { verified, potential, talent, unlikely, unknown }, count, groups } }
-- state: covered (someone verified), potential (someone could), talent (only
-- via a talent), none (every member's class is known and none has it),
-- unknown (someone we can't read might have it)
function U.Coverage(members)
  local out = {}
  for _, cap in ipairs(U.ORDER) do
    local c = U.CAPS[cap]
    local prov = { verified = 0, potential = 0, talent = 0, unlikely = 0, unknown = 0, none = 0 }
    local kinds, groups = {}, {}
    for _, m in ipairs(members or {}) do
      local r = U.Member(m, cap)
      prov[r.state] = (prov[r.state] or 0) + 1
      if (r.state == "verified" or r.state == "potential") then
        kinds[r.spell] = true
        local g = Obs.Num(m.subgroup)
        if g then groups[g] = true end
      end
    end
    local useful = prov.verified + prov.potential
    -- stacking: "one" counts a single provider however many there are
    local count = useful
    if c.stack == "one" or c.stack == nil then count = math.min(useful, 1) end
    local state
    if prov.verified > 0 then state = "covered"
    elseif prov.potential > 0 then state = "potential"
    elseif prov.unknown > 0 then state = "unknown"
    elseif prov.talent > 0 then state = "talent"
    elseif prov.unlikely > 0 then state = "unlikely"
    else state = "none" end
    out[cap] = { cap = cap, label = c.label, scope = c.scope, stack = c.stack or "unknown", state = state,
      providers = prov, count = count, groups = groups }
  end
  return out
end

local WORD = { covered = "|cff66dd77covered|r", potential = "could (class and level)", talent = "only by talent",
  unlikely = "below level", unknown = "|cffffd100unknown|r", none = "|cffff6060nobody|r" }
U.WORD = WORD
function U.Lines(cov, filter)
  local lines = {}
  for _, cap in ipairs(U.ORDER) do
    local r = cov[cap]
    if r and (not filter or filter[cap]) then
      lines[#lines + 1] = string.format("%s: %s%s", r.label, WORD[r.state] or r.state,
        (r.count > 1 and r.stack == "each") and (" (" .. r.count .. ")") or "")
    end
  end
  return lines
end

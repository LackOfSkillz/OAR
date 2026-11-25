-- Modules/ClassFight.lua  (Fight macros for the other six classes; requirement 2026-11-16:
-- the same as the hunter for every class, macros dragged to slot 1 and slot 2
-- and kept current for the character's whole levelling life)
-- Same rules as the hunter's (Modules/HunterFight.lua does the writing):
-- built only from spells this character knows, rewritten out of combat when
-- a spell is learned, gear changes, a buff goes on or off, or (druid) the
-- forms change. Every press is an ordinary macro press (hard rule 1).
--
-- What Forever allows (measured on the hunter, FOREVER_CONSTRAINTS): one spell
-- attempt per press; only "Spell is not ready yet" (cooldown, global
-- cooldown) moves on to the next line. So each macro goes: buffs before the
-- pull (only while missing), once-per-pull spells (castsequence ...,null,
-- re-armed when combat ends or the target changes), cooldown spells, then the
-- always-usable filler last. Abilities that only work after a dodge, parry or
-- below 20% health (Overpower, Revenge, Execute, Riposte) sit on key 2, so a
-- refused press there never costs the main rotation.
--
-- Orders follow the WoW Forever levelling guides (read 2026-11-16):
--   warcrafttavern.com/forever/guides/<class>-leveling/ (warrior, rogue,
--   paladin, warlock, druid), method.gg/wow-forever/...-shaman-leveling-guide.
-- Forever renamed some spells (Bane of Agony, Holy Strike, Primal Bite,
-- Shank): every slot lists the names to try, first known wins.
-- Unverified until each class's fight log has been read (verified = false).

local _, ns = ...
local C = ns.Compat
local F = ns.HunterFight
if not F then return end

local function known(name) return ns.Spellbook and ns.Spellbook:Known(name) ~= nil end
-- first known of a list of names
local function first(...)
  for i = 1, select("#", ...) do
    local n = select(i, ...)
    if n and known(n) then return n end
  end
end
local function level() return tonumber(C.Call("UnitLevel", "player")) or 1 end
local function equipLoc(slot)
  local link = C.Call("GetInventoryItemLink", "player", slot)
  local info = link and C.ItemInfo(link)
  return info and info.equipLoc
end
local function twoHander() return equipLoc(16) == "INVTYPE_2HWEAPON" end
local function wand() return equipLoc(18) == "INVTYPE_RANGEDRIGHT" end

-- Self buffs: a "before the pull" line only while the buff is missing (a
-- macro can't see buffs; Outrider rewrites it when the buff changes).
-- { names to try in order, extra conditions }
local BUFFS = {
  WARRIOR = {},
  ROGUE = {},
  WARLOCK = { { { "Demon Armor", "Demon Skin" } } },
  DRUID = { { { "Mark of the Wild" }, "noform," }, { { "Thorns" }, "noform," } },
  PALADIN = { { { "Blessing of Might" } }, { { "Retribution Aura", "Devotion Aura" } } },
  SHAMAN = { { { "Lightning Shield" } } },
  MAGE = { { { "Arcane Intellect" } }, { { "Ice Armor", "Frost Armor" } } },
  PRIEST = { { { "Power Word: Fortitude" } }, { { "Inner Fire" } } },
}
for cls, list in pairs(BUFFS) do
  F.WATCH[cls] = F.WATCH[cls] or {}
  for _, b in ipairs(list) do for _, n in ipairs(b[1]) do table.insert(F.WATCH[cls], n) end end
end

local function buffLines(cls, add, keep)
  for _, b in ipairs(BUFFS[cls] or {}) do
    local n = first(unpack(b[1]))
    if n and not F.AuraOn(n) then
      add(keep or 7, string.format("/cast [nocombat,%s@player] %s", b[2] or "", n), "before the pull, while " .. n .. " is missing")
    end
  end
end

-- Shaman weapon imbue: a weapon enchant, not a buff.
local function mainHandEnchanted()
  local has = C.Call("GetWeaponEnchantInfo")
  return C.Readable(has) == true
end
local function imbueName()
  return (level() >= 30 and twoHander() and first("Windfury Weapon")) or first("Rockbiter Weapon", "Flametongue Weapon")
end

-- The self-buffs missing right now, for the Fight key of every class (Gary,
-- 2026-11-25: "if you press fight and your buffs are not up, it buffs you
-- then pulls"). FightPlan puts them first when its plan doesn't cast them
-- already. One spell per press: a press with a buff missing casts the buff,
-- the next one pulls. { { text, why, spell }, ... }
function F.SelfBuffs(cls)
  local out = {}
  if cls == "SHAMAN" then
    local imbue = imbueName()
    if imbue and not mainHandEnchanted() then
      out[#out + 1] = { text = "/cast [nocombat] " .. imbue, why = "before the pull, while the weapon has no imbue", spell = imbue }
    end
  end
  buffLines(cls, function(_, text, why)
    out[#out + 1] = { text = text, why = why, spell = text:match("%] (.+)$") }
  end)
  return out
end
F.WatchExtra = function()
  if ns.PlayerClass() == "SHAMAN" then return mainHandEnchanted() and "imbue on" or "imbue off" end
  return nil
end

-- Druid forms by number on the stance bar ([form:N]); learning a form can
-- renumber them, so the macro is rewritten on UPDATE_SHAPESHIFT_FORMS.
function F.FormIndex(...)
  local n = tonumber(C.Call("GetNumShapeshiftForms")) or 0
  for i = 1, n do
    local spellID = select(4, C.Call("GetShapeshiftFormInfo", i))
    local name = spellID and C.SpellName(spellID)
    for k = 1, select("#", ...) do if name == select(k, ...) then return i end end
  end
end

-- DoTs then the filler while they tick, as one sequence of real spells
-- (",null" wraps on Forever and recast the first DoT every press). It never
-- waits, so callers add it last.
local function seq(add, keep, cond, list, pad, n)
  local s, dots = {}, {}
  for i = 1, 4 do if list[i] then s[#s + 1] = list[i] dots[#dots + 1] = list[i] end end
  if #s == 0 or not pad then return false end
  for _ = 1, n or 4 do s[#s + 1] = pad end
  add(keep, string.format("/castsequence %sreset=combat/target %s", cond or "", table.concat(s, ",")),
    table.concat(dots, ", ") .. ", then " .. pad .. " while they tick")
  return true
end

local CASTER = F.CASTER

-- Warrior. Key 1: Charge, Battle Shout, Rend once, the big cooldown strike,
-- Heroic Strike with spare rage. Key 2: what lights up (Overpower after a
-- dodge, Revenge after a block, Execute under 20%), then Thunder Clap.
function CASTER.WARRIOR(kind, add)
  add(1, "/targetenemy [noharm][dead]", "picks the nearest enemy when you have none")
  add(1, "/startattack", "keeps swinging")
  if kind == "melee" then
    if known("Overpower") then add(2, "/cast Overpower", "after the target dodges") end
    if known("Revenge") then add(3, "/cast Revenge", "after you block, dodge or parry") end
    if known("Execute") then add(2, "/cast Execute", "target under 20% health") end
    if known("Thunder Clap") then add(4, "/cast Thunder Clap", "several mobs on you: on cooldown") end
    if known("Cleave") then add(5, "/cast Cleave", "several mobs: rage dump") end
    return
  end
  if known("Charge") then add(2, "/cast [nocombat,stance:1] Charge;[nocombat] Battle Stance", "opens the pull from range; in another stance, Battle Stance first") end
  if known("Battle Shout") then add(5, "/cast [mod:alt] Battle Shout", "Alt: Battle Shout (3 minutes)") end
  local big = first("Mortal Strike", "Bloodthirst", "Shield Slam")
  if big then add(3, "/cast " .. big, "whenever it is off cooldown") end
  if known("Rend") and known("Heroic Strike") then
    add(2, "/castsequence reset=combat/target Rend,Heroic Strike,Heroic Strike,Heroic Strike", "Rend, then Heroic Strike with spare rage; Rend again on a new target")
  elseif known("Heroic Strike") then add(2, "/cast Heroic Strike", "spare rage into the next swing") end
end

-- Rogue. Key 1: Cheap Shot from Stealth, then a combo loop: builder, builder,
-- Slice and Dice, three builders, Eviscerate (a castsequence only moves on
-- when the spell lands, so a press without energy waits). Key 2: Stealth out
-- of combat, in combat Kick, then the cooldowns.
function CASTER.ROGUE(kind, add)
  if kind == "melee" then
    if known("Stealth") then add(2, "/cast [nocombat,nostealth] Stealth", "out of combat: Stealth") end
    if known("Kick") then add(2, "/cast [combat] Kick", "interrupts a cast") end
    local cds = {}
    for _, n in ipairs({ "Adrenaline Rush", "Blade Flurry", "Evasion" }) do if known(n) then cds[#cds + 1] = n end end
    for i, n in ipairs(cds) do add(3 + i, "/cast [combat] " .. n, "when Kick is cooling down") end
    return
  end
  add(1, "/targetenemy [noharm][dead]", "picks the nearest enemy when you have none")
  local opener = first("Cheap Shot", "Garrote")
  if opener then add(2, "/cast [stealth] " .. opener, "opens from Stealth") end
  add(1, "/startattack [nostealth]", "keeps swinging (not while sneaking)")
  if known("Shank") then add(5, "/cast [nostealth] Shank", "extra energy, on cooldown") end
  local b = first("Mutilate", "Hemorrhage", "Sinister Strike")
  if b then
    local s = { b, b }
    if known("Slice and Dice") then s[#s + 1] = "Slice and Dice" end
    s[#s + 1] = b
    s[#s + 1] = b
    s[#s + 1] = b
    if known("Eviscerate") then s[#s + 1] = "Eviscerate" end
    add(2, "/castsequence [nostealth] reset=combat/target " .. table.concat(s, ","),
      table.concat(s, ", "):gsub(b .. ", " .. b, "2x " .. b) .. ", round and round")
  end
end

-- Warlock. Key 1: pet in, the curse, Corruption, Immolate, Siphon Life once
-- each, then the filler: Drain Life from 30, else the wand, else Shadow Bolt.
-- Key 2: Life Tap (Shift: Fear the target).
function CASTER.WARLOCK(kind, add)
  if kind == "melee" then
    if known("Fear") then add(2, "/cast [mod:shift,harm,nodead] Fear", "Shift: fear a second mob away") end
    if known("Life Tap") then add(2, "/cast Life Tap", "health into mana") end
    return
  end
  -- a press during Drain Life would restart the channel (research 2026-11-18;
  -- the guard is proven on Forever by the tame macro)
  if known("Drain Life") and level() >= 30 then add(1, "/stopmacro [channeling]", "doesn't cut Drain Life short") end
  add(1, "/targetenemy [noharm][dead]", "picks the nearest enemy when you have none")
  add(8, "/petattack [pet,harm]", "sends the demon in")
  buffLines("WARLOCK", add)
  if known("Shoot") and wand() then add(3, "/cast [mod:shift] !Shoot", "Shift: the wand (when mana runs low)") end
  local filler = (known("Drain Life") and level() >= 30) and "Drain Life" or first("Shadow Bolt")
  local dots = { first("Bane of Agony", "Curse of Agony"), first("Corruption"), first("Immolate"), first("Siphon Life") }
  if not seq(add, 2, nil, dots, filler, 4) and filler then add(3, "/cast " .. filler, "filler until it dies") end
end

-- Druid. One key follows your form: caster Wrath then Moonfire once and Wrath;
-- Bear: Faerie Fire and Demoralizing Roar once, Primal Bite on cooldown,
-- Maul; Cat: Rake, three Claws, then Rip (or Ferocious Bite), round and round.
-- Key 2: Swipe in Bear, Tiger's Fury in Cat, a heal out of form.
function CASTER.DRUID(kind, add)
  local bear = F.FormIndex("Bear Form", "Dire Bear Form")
  local cat = F.FormIndex("Cat Form")
  if kind == "heal" then
    local parts = {}
    if bear and known("Swipe") then parts[#parts + 1] = "[form:" .. bear .. "] Swipe" end
    if cat and known("Tiger's Fury") then parts[#parts + 1] = "[form:" .. cat .. "] Tiger's Fury" end
    local heal = first("Healing Touch")
    if heal then parts[#parts + 1] = "[noform,@mouseover,help,nodead][noform,@target,help,nodead][noform,@player] " .. heal end
    if #parts > 0 then add(1, "/cast " .. table.concat(parts, "; "), "Bear: Swipe; Cat: Tiger's Fury; no form: heal who you point at or you") end
    if known("Rejuvenation") then add(3, "/cast [noform,@player] Rejuvenation", "heal over time on you") end
    return
  end
  add(1, "/targetenemy [noharm][dead]", "picks the nearest enemy when you have none")
  buffLines("DRUID", add)
  local forms = {}
  if bear then forms[#forms + 1] = bear end
  if cat then forms[#forms + 1] = cat end
  if #forms > 0 then add(1, "/startattack [form:" .. table.concat(forms, "/") .. "]", "swings in Bear or Cat") end
  if bear then
    local b = "[form:" .. bear .. "] "
    -- ",null" wraps on Forever (FOREVER_CONSTRAINTS): Roar on Ctrl instead
    if known("Demoralizing Roar") then add(5, "/cast [form:" .. bear .. ",mod:ctrl] Demoralizing Roar", "Ctrl in Bear: Demoralizing Roar") end
    if known("Primal Bite") then add(4, "/cast " .. b .. "Primal Bite", "Bear: on cooldown") end
    if known("Maul") then add(2, "/cast " .. b .. "Maul", "Bear: rage into the next swing") end
  end
  if cat then
    local fin = first("Rip", "Ferocious Bite")
    local claw = "Claw" -- Shred needs you behind the target: left to you
    if known(claw) then
      local s = {}
      if known("Rake") then s[#s + 1] = "Rake" end
      s[#s + 1] = claw
      s[#s + 1] = claw
      s[#s + 1] = claw
      if fin then s[#s + 1] = fin end
      add(2, "/castsequence [form:" .. cat .. "] reset=combat/target " .. table.concat(s, ","), "Cat: " .. table.concat(s, ", ") .. ", round and round")
    end
  end
  local moonkin = F.FormIndex("Moonkin Form")
  local nf = moonkin and ("[noform][form:" .. moonkin .. "] ") or ((#forms > 0) and "[noform] " or "")
  -- DoTs, then the filler while they tick, as one sequence of real spells
  -- (",null" wraps on Forever and would recast Moonfire every press)
  local dots = {}
  for _, n in ipairs({ "Moonfire", "Insect Swarm" }) do if known(n) then dots[#dots + 1] = n end end
  if #dots > 0 and known("Wrath") then
    local fill = (known("Starfire") and level() >= 30) and { "Starfire", "Starfire" } or { "Wrath", "Wrath", "Wrath" }
    for _, n in ipairs(fill) do dots[#dots + 1] = n end
    add(2, "/castsequence " .. nf .. "reset=combat/target " .. table.concat(dots, ","), "no form: " .. table.concat(dots, ", ") .. ", round and round")
  end
  if known("Wrath") then add(2, "/cast " .. nf .. "Wrath", "no form: the filler") end
end

-- Paladin. Key 1: Blessing and Aura before the pull (while missing), then
-- Seal, Judgement, Seal, Judgement (the sequence waits while Judgement cools
-- down and the press goes on), Holy Strike and Crusader Strike on cooldown,
-- Consecration if you have it. Key 2: Holy Light on who you point at or you.
function CASTER.PALADIN(kind, add)
  if kind == "heal" then
    local heal = first("Holy Light")
    if heal then add(1, "/cast [@mouseover,help,nodead][@target,help,nodead][@player] " .. heal, "heals who you point at, your friendly target, or you") end
    if known("Flash of Light") then add(2, "/cast [mod:shift,@player] Flash of Light", "Shift: a quick heal on you") end
    return
  end
  add(1, "/targetenemy [noharm][dead]", "picks the nearest enemy when you have none")
  add(1, "/startattack", "keeps swinging")
  buffLines("PALADIN", add)
  local seal = (level() >= 20 and twoHander() and first("Seal of Command")) or first("Seal of Righteousness")
  -- On Forever Judgement doesn't use up the Seal (research 2026-11-18), so
  -- re-sealing after each Judgement wasted a global cooldown and mana: Seal
  -- once per fight, Judgement whenever it's off cooldown.
  -- Field test 2026-11-21 (Gul's fights): ",null" doesn't hold on Forever, the
  -- sequence wraps and the Seal was recast every press (25 casts in 15 s). A
  -- sequence of real spells parks on Judgement while it cools down: Seal, then
  -- three Judgements (about 30 s, the Seal's length), then Seal again.
  if seal and known("Judgement") then
    add(2, "/castsequence reset=combat " .. seal .. ",Judgement,Judgement,Judgement", "Seal, then Judgement on cooldown; Seal again after three Judgements")
  elseif seal then
    add(2, "/cast [nocombat] " .. seal, "Seal before the pull (it lasts 30 s)")
  end
  for i, n in ipairs({ "Holy Strike", "Crusader Strike", "Consecration" }) do
    if known(n) then add(2 + i, "/cast " .. n, "whenever it is off cooldown") end
  end
  -- the game only allows it under 20% health, so it waits last (like Mongoose Bite)
  if known("Hammer of Wrath") then add(5, "/cast Hammer of Wrath", "target under 20% health") end
end

-- Shaman. Key 1: weapon imbue and Lightning Shield before the pull (while
-- missing), Lightning Bolt to pull, Searing Totem once per fight, Flame Shock
-- once per target, Stormstrike and Earth Shock on cooldown. Key 2: Healing
-- Wave on who you point at or you.
function CASTER.SHAMAN(kind, add)
  if kind == "heal" then
    local heal = first("Healing Wave")
    if heal then add(1, "/cast [@mouseover,help,nodead][@target,help,nodead][@player] " .. heal, "heals who you point at, your friendly target, or you") end
    if known("Lesser Healing Wave") then add(2, "/cast [mod:shift,@player] Lesser Healing Wave", "Shift: a quick heal on you") end
    return
  end
  add(1, "/targetenemy [noharm][dead]", "picks the nearest enemy when you have none")
  add(1, "/startattack", "keeps swinging")
  local imbue = imbueName()
  if imbue and not mainHandEnchanted() then add(6, "/cast [nocombat] " .. imbue, "before the pull, while the weapon has no imbue") end
  buffLines("SHAMAN", add)
  if known("Lightning Bolt") then add(5, "/cast [nocombat] Lightning Bolt", "pulls from range") end
  if known("Searing Totem") then add(4, "/cast [mod:ctrl] Searing Totem", "Ctrl: Searing Totem") end
  if known("Stormstrike") then add(2, "/cast Stormstrike", "whenever it is off cooldown") end
  -- the shocks share a cooldown: Flame Shock, then the other shock, waiting on it
  local shock = first("Earth Shock", "Frost Shock")
  if known("Flame Shock") and shock then add(2, "/castsequence reset=combat/target Flame Shock," .. shock, "Flame Shock, then " .. shock .. " on the shared shock cooldown")
  elseif shock then add(2, "/cast " .. shock, "whenever it is off cooldown")
  elseif known("Flame Shock") then add(3, "/cast Flame Shock", "whenever it is off cooldown") end
end

-- Mage and priest keep their builders in HunterFight.lua; add their buffs.
for _, cls in ipairs({ "MAGE", "PRIEST" }) do
  local base = CASTER[cls]
  CASTER[cls] = function(kind, add)
    if kind == "ranged" then
      local queued = {}
      base(kind, function(k, t, w) queued[#queued + 1] = { k, t, w } end)
      -- targeting first, then buffs, then the rest
      local i = 1
      if queued[1] and queued[1][2]:find("^/targetenemy") then add(unpack(queued[1])) i = 2 end
      buffLines(cls, add)
      for j = i, #queued do add(unpack(queued[j])) end
    else
      base(kind, add)
    end
  end
end

for cls, kinds in pairs({ WARRIOR = { "ranged", "melee" }, ROGUE = { "ranged", "melee" }, WARLOCK = { "ranged", "melee" },
  DRUID = { "ranged", "heal" }, PALADIN = { "ranged", "heal" }, SHAMAN = { "ranged", "heal" } }) do
  F.CLASS_KINDS[cls] = kinds
end

local E = F.EXPLAIN
E.WARRIOR = { ranged = "Key 1, spam it: Charge, Battle Shout, Rend once, your big strike on cooldown, Heroic Strike.",
  melee = "Key 2: press when Overpower, Revenge or Execute lights up; Thunder Clap on a pack." }
-- Rogue: no key numbers (tour 2026-11-19: Gary's bar is Fight 1, Pull 2,
-- Strike 3, so "key 2" was wrong); the text names the macro instead.
E.ROGUE = { ranged = "Fight, spam it: Stealth out of combat, open from it (Backstab with a dagger; Garrote, Ambush or Cheap Shot later), then Sinister Strike, Slice and Dice, Eviscerate.",
  melee = "Strike: Stealth out of combat; pressed again while sneaking, Pick Pocket. In a fight: Evasion (8), Kick (12). Pull (Throw or your bow) is its own macro." }
E.WARLOCK = { ranged = "Key 1, spam it: demon in, curse, Corruption, Immolate once each, then Drain Life or the wand.",
  melee = "Key 2: Life Tap; Shift fears the target." }
E.DRUID = { ranged = "Key 1, spam it: follows your form (caster, Bear or Cat).",
  heal = "Key 2: Swipe in Bear, Tiger's Fury in Cat, a heal out of form." }
E.PALADIN = { ranged = "Key 1, spam it: Blessing and Aura, Seal and Judgement, Holy Strike on cooldown.",
  heal = "Key 2: Holy Light on who you point at, or you." }
E.SHAMAN = { ranged = "Key 1, spam it: imbue and Lightning Shield, bolt to pull, totem, Flame Shock, shocks.",
  heal = "Key 2: Healing Wave on who you point at, or you." }

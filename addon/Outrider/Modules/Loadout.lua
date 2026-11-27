-- Modules/Loadout.lua  (Smart loadout, docs/SMART_LOADOUT.md; Gary 2026-11-27)
-- Picks the weapon imbue, totems, shock (and per class: nuke, seal, curse...)
-- that suit the mob you target, so the fight keys already hold the right
-- spell before the pull. Advice only: Outrider rewrites the fight macro text
-- out of combat (HunterFight:Update through ns.Combat), and every cast is
-- still Gary's own key press (hard rule 1). In combat nothing changes.
--
-- What a mob resists, is immune to and casts comes from the creatures pack
-- (private/Outrider_Data_Mobs/Res.lua: VMaNGOS 1.12 server values + Forever's
-- own spell schools, tools/import_mob_res.py). verified = false: Forever's new
-- mobs and changes are not in it. Learned values (ns.db.global.mobSchools,
-- filled later from Gary's own fights) win over the pack.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Loadout", {
  title = "Smart loadout (imbue, totems, spells per mob)",
  phase = "P4", order = 102,
  defaults = { on = true },
})
ns.Loadout = M

M.ADDON = "Outrider_Data_Mobs"
M.SCHOOL_BITS = { physical = 1, holy = 2, fire = 4, nature = 8, frost = 16, shadow = 32, arcane = 64 }
M.SCHOOL_ORDER = { "physical", "holy", "fire", "nature", "frost", "shadow", "arcane" }
-- 1.12 mechanics a player counters (fear: Tremor, Fear Ward, Will of the Forsaken)
M.FEAR_MECH = { [1] = true, [5] = true, [10] = true, [24] = true } -- charm, fear, sleep, horror
M.DISPEL = { [1] = "magic", [2] = "curse", [3] = "disease", [4] = "poison" }
-- swap only for a real gain: at least this much better, and not worse than half damage
M.GAIN, M.FLOOR = 1.5, 0.5
-- Forever's weapon imbue enchant ids (client SpellEffect, Effect 54 temporary
-- enchant, EffectMiscValue_0; build 1.60.1.71037). verified = false.
M.IMBUE_ENCHANT = { [7566] = "Frostbrand Weapon", [7567] = "Flametongue Weapon",
  [7568] = "Rockbiter Weapon", [7569] = "Windfury Weapon" }
M.IMBUE_WORD = { ["Frostbrand Weapon"] = "Frostbrand", ["Flametongue Weapon"] = "Flametongue",
  ["Rockbiter Weapon"] = "Rockbiter", ["Windfury Weapon"] = "Windfury" }

local function known(name) return ns.Spellbook and ns.Spellbook:Known(name) ~= nil end

-- counter buffs and auras going on or off rewrite the fight keys (HunterFight watch)
do
  local F = ns.HunterFight
  if F and F.WATCH then
    for _, cls in ipairs({ "MAGE", "PRIEST", "PALADIN", "HUNTER" }) do
      F.WATCH[cls] = F.WATCH[cls] or {}
      local seen = {}
      for _, n in ipairs(F.WATCH[cls]) do seen[n] = true end
      for _, c in ipairs(({ MAGE = { { "Fire Ward" }, { "Frost Ward" } }, PRIEST = { { "Shadow Protection" } },
        PALADIN = { { "Fire Resistance Aura" }, { "Frost Resistance Aura" }, { "Shadow Resistance Aura" } },
        HUNTER = { { "Aspect of the Wild" } } })[cls]) do
        if not seen[c[1]] then table.insert(F.WATCH[cls], c[1]) end
      end
    end
  end
end
local function level() return tonumber(C.Call("UnitLevel", "player")) or 1 end

-- ------------------------------------------------------------------ the data
function M:Data(load)
  local d = rawget(_G, "Outrider_DataMobRes")
  if not d and load and not self.triedLoad then
    self.triedLoad = true
    C.LoadAddOn(self.ADDON)
    d = rawget(_G, "Outrider_DataMobRes")
    self:Info("mob resistance pack %s", d and "loaded" or "not installed")
  end
  return type(d) == "table" and d or nil
end

function M.SchoolsOf(mask)
  local out = {}
  for _, s in ipairs(M.SCHOOL_ORDER) do
    local b = M.SCHOOL_BITS[s]
    if mask and mask % (b * 2) >= b then out[#out + 1] = s end
  end
  return out
end
local function hasBit(mask, bit) return type(mask) == "number" and mask % (bit * 2) >= bit end

-- Average share of a spell's damage that gets through a resistance: Classic's
-- average resist is 0.75 * R / (5 * caster level), capped at 75%.
function M.ResistMult(r, lvl)
  r, lvl = tonumber(r) or 0, math.max(1, tonumber(lvl) or 1)
  if r <= 0 then return 1 end
  return 1 - math.min(0.75, 0.75 * r / (5 * lvl))
end

-- What we know about one mob: { npc, mult(school), immune = {school}, fears,
-- casts = {school = n} (aimed at you), dispels = {poison = true}, spells = {"Fireball (fire)"} }
function M:Profile(npcID, lvl, load)
  npcID = tonumber(npcID)
  if not npcID then return nil end
  local d = self:Data(load)
  local row = d and d.mobs and d.mobs[npcID]
  local learned = ns.db and ns.db.global.mobSchools and ns.db.global.mobSchools[npcID]
  if not row and not learned then return nil end
  row = row or {}
  local P = { npc = npcID, immune = {}, casts = {}, dispels = {}, spells = {}, fears = false, source = {} }
  for _, s in ipairs(M.SchoolsOf(row.imm)) do P.immune[s] = true end
  P.res = row.res or {}
  P.mech = row.mech
  P.fearImmune = hasBit(row.mech, 2 ^ 4)
  if row.melee and row.melee > 0 then P.melee = M.SCHOOL_ORDER[row.melee + 1] end
  for _, id in ipairs(row.casts or {}) do
    local sp = d.spells and d.spells[id]
    if sp and sp[5] == 1 then
      local schools = M.SchoolsOf(sp[2])
      for _, s in ipairs(schools) do if s ~= "physical" then P.casts[s] = (P.casts[s] or 0) + 1 end end
      if M.DISPEL[sp[3]] then P.dispels[M.DISPEL[sp[3]]] = true end
      if M.FEAR_MECH[sp[4]] then P.fears = true end
      if #P.spells < 4 then P.spells[#P.spells + 1] = string.format("%s (%s)", tostring(sp[1]), table.concat(schools, "/")) end
    end
  end
  if P.melee and P.melee ~= "physical" then P.casts[P.melee] = (P.casts[P.melee] or 0) + 1 end
  if row.imm or row.res or row.casts then P.source[#P.source + 1] = "VMaNGOS" end
  P.learned = learned
  if learned then P.source[#P.source + 1] = "your fights" end
  lvl = lvl or level()
  function P.mult(school)
    local l = learned and learned.schools and learned.schools[school]
    if l and (tonumber(l.n) or 0) >= 8 and tonumber(l.mult) then return tonumber(l.mult) end
    if P.immune[school] then return 0 end
    return M.ResistMult(P.res[school], lvl)
  end
  return P
end

-- One line for the tooltip and the log: "immune fire; resists nature 60; casts Fireball (fire)"
function M.Describe(P)
  if not P then return nil end
  local parts = {}
  local imm = {}
  for _, s in ipairs(M.SCHOOL_ORDER) do if P.immune[s] then imm[#imm + 1] = s end end
  if #imm > 0 then parts[#parts + 1] = "immune " .. table.concat(imm, ", ") end
  local res = {}
  for _, s in ipairs(M.SCHOOL_ORDER) do if (P.res[s] or 0) > 0 then res[#res + 1] = s .. " " .. P.res[s] end end
  if #res > 0 then parts[#parts + 1] = "resists " .. table.concat(res, ", ") end
  local l = P.learned and P.learned.schools
  if l then
    for _, s in ipairs(M.SCHOOL_ORDER) do
      local e = l[s]
      if e and (tonumber(e.n) or 0) >= 8 and tonumber(e.mult) then
        parts[#parts + 1] = string.format("%s x%.1f (%d hits)", s, e.mult, e.n)
      end
    end
  end
  if P.fears then parts[#parts + 1] = "fears" end
  if P.fearImmune then parts[#parts + 1] = "can't be feared" end
  local dis = {}
  for _, k in ipairs({ "poison", "disease", "curse" }) do if P.dispels[k] then dis[#dis + 1] = k end end
  if #dis > 0 then parts[#parts + 1] = "uses " .. table.concat(dis, ", ") end
  if #P.spells > 0 then parts[#parts + 1] = "casts " .. table.concat(P.spells, ", ") end
  if #parts == 0 then return nil end
  return table.concat(parts, "; ")
end

-- --------------------------------------------------------------- choosing
-- Among options { {name, school}, ... }, the best one for this mob starting
-- from `current` (the spell the plan would cast). Unknown spells never win;
-- a swap needs GAIN times the damage and at least FLOOR of normal.
function M.Best(P, options, current)
  local curSchool
  for _, o in ipairs(options) do if o[1] == current then curSchool = o[2] end end
  if not curSchool or not P then return current end
  local best, bestM = current, P.mult(curSchool)
  for _, o in ipairs(options) do
    if o[1] ~= current and known(o[1]) then
      local m = P.mult(o[2])
      if m >= M.FLOOR and m >= bestM * M.GAIN and m > bestM then best, bestM = o[1], m end
    end
  end
  return best, bestM, P.mult(curSchool)
end

-- Per class: groups of interchangeable spells (any member found in a fight
-- line is swapped for the best member), plus totems for shamans.
M.GROUPS = {
  SHAMAN = {
    imbue = { { "Rockbiter Weapon", "physical" }, { "Windfury Weapon", "physical" },
      { "Flametongue Weapon", "fire" }, { "Frostbrand Weapon", "frost" } },
    shock = { { "Earth Shock", "nature" }, { "Flame Shock", "fire" }, { "Frost Shock", "frost" } },
    -- Lava Burst has a cooldown: only wins when nature does next to nothing
    nuke = { { "Lightning Bolt", "nature" }, { "Lava Burst", "fire" } },
  },
  MAGE = {
    nuke = { { "Frostbolt", "frost" }, { "Fireball", "fire" }, { "Arcane Missiles", "arcane" } },
  },
  WARLOCK = {
    nuke = { { "Shadow Bolt", "shadow" }, { "Searing Pain", "fire" } },
    dot = { { "Corruption", "shadow" }, { "Immolate", "fire" } },
  },
  PRIEST = {
    filler = { { "Smite", "holy" }, { "Mind Flay", "shadow" } },
    dot = { { "Shadow Word: Pain", "shadow" }, { "Holy Fire", "holy" } },
  },
  PALADIN = {
    seal = { { "Seal of Righteousness", "holy" }, { "Seal of Command", "physical" }, { "Seal of the Crusader", "physical" } },
  },
  DRUID = {
    nuke = { { "Wrath", "nature" }, { "Starfire", "arcane" } },
  },
  HUNTER = {
    sting = { { "Serpent Sting", "nature" }, { "Arcane Shot", "arcane" } },
  },
}

-- What the mob throws at you, countered: `swap` replaces those spells (an
-- aura), otherwise it is one more pre-pull buff while it is missing.
-- Classic spells; each only when this character knows it.
M.COUNTERS = {
  MAGE = { { "Fire Ward", "fire" }, { "Frost Ward", "frost" } },
  PRIEST = { { "Shadow Protection", "shadow" } },
  PALADIN = {
    { "Fire Resistance Aura", "fire", swap = { "Devotion Aura", "Retribution Aura" } },
    { "Frost Resistance Aura", "frost", swap = { "Devotion Aura", "Retribution Aura" } },
    { "Shadow Resistance Aura", "shadow", swap = { "Devotion Aura", "Retribution Aura" } },
  },
  HUNTER = { { "Aspect of the Wild", "nature", swap = { "Aspect of the Monkey" } } },
}
-- Fears that do nothing on a mob that can't be feared: left out of the keys.
M.FEARS = { "Fear", "Psychic Scream", "Howl of Terror", "Intimidating Shout", "Scare Beast", "Turn Undead" }

-- Shaman totems by slot (1 fire, 2 earth, 3 water, 4 air): the totem this mob
-- calls for, false for "drop no totem here", nil for the plan's own.
function M.ShamanTotem(P, slot)
  if not P then return nil end
  local function k(n) return known(n) and n or nil end
  if slot == 2 then
    if P.fears then return k("Tremor Totem"), "it fears" end
  elseif slot == 1 then
    if P.mult("fire") < M.FLOOR then
      if (P.casts.frost or 0) > 0 and k("Frost Resistance Totem") then return "Frost Resistance Totem", "casts frost" end
      return false, "shrugs off fire"
    end
    if (P.casts.frost or 0) > 0 then return k("Frost Resistance Totem"), "casts frost" end
  elseif slot == 3 then
    if P.dispels.poison and k("Poison Cleansing Totem") then return "Poison Cleansing Totem", "poisons" end
    if P.dispels.disease and k("Disease Cleansing Totem") then return "Disease Cleansing Totem", "diseases" end
    if (P.casts.fire or 0) > 0 then return k("Fire Resistance Totem"), "casts fire" end
  elseif slot == 4 then
    if (P.casts.nature or 0) > 0 then return k("Nature Resistance Totem"), "casts nature" end
  end
  return nil
end

-- The picks for the current target: { swaps = {from = to}, totems = {slot = name|false},
-- why = {lines}, sig = "...", P = profile }. Empty picks when nothing is known.
function M:Picks(P)
  local cls = ns.PlayerClass()
  local out = { swaps = {}, totems = {}, why = {}, drops = {}, buffs = {}, P = P }
  if not P then out.sig = "" return out end
  for gname, group in pairs(M.GROUPS[cls] or {}) do
    for _, o in ipairs(group) do
      local best, bm, cm = M.Best(P, group, o[1])
      if best ~= o[1] then
        out.swaps[o[1]] = best
        out.why[#out.why + 1] = string.format("%s instead of %s (%s x%.2f vs x%.2f)", best, o[1], gname, bm or 0, cm or 0)
      end
    end
  end
  for _, c in ipairs(M.COUNTERS[cls] or {}) do
    if (P.casts[c[2]] or 0) > 0 and known(c[1]) then
      if c.swap then
        for _, from in ipairs(c.swap) do if not out.swaps[from] then out.swaps[from] = c[1] end end
        out.why[#out.why + 1] = string.format("%s (casts %s)", c[1], c[2])
      elseif #out.buffs == 0 then -- one counter buff: the macro has room for one
        out.buffs[#out.buffs + 1] = c[1]
        out.why[#out.why + 1] = string.format("%s before the pull (casts %s)", c[1], c[2])
      end
    end
  end
  if P.fearImmune then
    for _, f in ipairs(M.FEARS) do if known(f) then out.drops[f] = true out.why[#out.why + 1] = f .. " left out (can't be feared)" end end
  end
  if cls == "SHAMAN" then
    for slot = 1, 4 do
      local t, why = M.ShamanTotem(P, slot)
      if t ~= nil then
        out.totems[slot] = t
        out.why[#out.why + 1] = string.format("totem %d: %s (%s)", slot, t or "none", tostring(why))
      end
    end
  end
  local keys = {}
  for a, b in pairs(out.swaps) do keys[#keys + 1] = a .. ">" .. b end
  for s = 1, 4 do if out.totems[s] ~= nil then keys[#keys + 1] = s .. "=" .. tostring(out.totems[s]) end end
  for d in pairs(out.drops) do keys[#keys + 1] = "-" .. d end
  for _, b in ipairs(out.buffs) do keys[#keys + 1] = "+" .. b end
  table.sort(keys)
  out.sig = table.concat(keys, ",")
  return out
end

-- -------------------------------------------------- used by the macro builder
function M:Current() return self.enabled and self:Settings().on and self.picks or nil end

-- A whole spell name at a..b: not part of a longer name ("Wrath" in "Hammer of Wrath")
-- (a spell starts after the command, a ] ; , or !, and ends at , ; or the line's end)
local function whole(text, a, b)
  local pre = text:sub(1, a - 1):gsub("%s+$", "")
  local okBefore = pre == "" or pre:find("[%];,!]$") or pre:find("/cast$") or pre:find("/castsequence$")
    or pre:find("reset=%S+$") or pre:find("/use$")
  local post = text:sub(b + 1):gsub("^ +", "")
  local okAfter = post == "" or post:find("^[,;\n]")
  return okBefore and okAfter
end

local function replaceAll(text, from, to)
  local a, b = text:find(from, 1, true)
  while a do
    if whole(text, a, b) then
      text = text:sub(1, a - 1) .. to .. text:sub(b + 1)
      a, b = text:find(from, a + #to, true)
    else
      a, b = text:find(from, b + 1, true)
    end
  end
  return text
end

-- "/castsequence [x] reset=combat/target A,B,C" -> head, { "A", "B", "C" }
local function splitSequence(text)
  if not text:find("^/castsequence") then return nil end
  local head, list = text:match("^(/castsequence.-reset=%S+%s+)(.+)$")
  if not head then head, list = text:match("^(/castsequence%s*%b[]%s*)(.+)$") end
  if not head then head, list = text:match("^(/castsequence%s+)(.+)$") end
  if not head then return nil end
  local items = {}
  for it in (list .. ","):gmatch("([^,]*),") do items[#items + 1] = it end
  return head, items
end

-- Swap the spells of one fight line for this mob's better ones; false when
-- the line casts nothing useful any more (a fear on a mob that can't be feared).
-- In a cast sequence a swap into a spell that is already there drops the old
-- one instead (Corruption -> Immolate when Immolate is in the sequence).
function M:Apply(text)
  local p = self:Current()
  if not p or type(text) ~= "string" then return text end
  if not next(p.swaps) and not next(p.drops) then return text end
  local head, items = splitSequence(text)
  if head then
    local had = {}
    for _, it in ipairs(items) do had[it] = true end
    local out = {}
    for _, it in ipairs(items) do
      local to = p.swaps[it]
      if p.drops[it] or (to and had[to]) then -- left out
      else out[#out + 1] = to or it end
    end
    if #out == 0 then return false end
    return head .. table.concat(out, ",")
  end
  -- a /cast line that casts only a dropped spell
  local only = text:match("^/cast%s*%b[]%s*([^;]+)$") or text:match("^/cast%s+([^;%[]+)$")
  if only and p.drops[(only:gsub("%s+$", ""))] then return false end
  for from, to in pairs(p.swaps) do text = replaceAll(text, from, to) end
  return text
end

-- Counter buffs for this mob (Fire Ward, Shadow Protection), for the pre-pull lines
function M:Buffs()
  local p = self:Current()
  return p and p.buffs or {}
end

-- totem override for a slot: name, false (no totem), or nil (the plan's own)
function M:Totem(slot)
  local p = self:Current()
  if not p then return nil end
  return p.totems[slot]
end

-- Which imbue is on the main hand: its name, "unknown" (enchanted, can't tell
-- which), or nil. The 4th GetWeaponEnchantInfo return is the enchant id; the
-- weapon tooltip's "Flametongue ..." line is the fallback.
function M.CurrentImbue()
  local has, _, _, id = C.Call("GetWeaponEnchantInfo")
  if C.Readable(has) ~= true then return nil end
  local name = M.IMBUE_ENCHANT[tonumber(C.Readable(id)) or -1]
  if name then return name end
  local tip = C.Call("C_TooltipInfo.GetInventoryItem", "player", 16)
  if type(tip) == "table" and type(tip.lines) == "table" then
    for _, l in ipairs(tip.lines) do
      local t = C.Readable(l.leftText)
      if type(t) == "string" then
        for full, word in pairs(M.IMBUE_WORD) do if t:find("^" .. word) then return full end end
      end
    end
  end
  if not M.toldUnknown then
    M.toldUnknown = true
    M:Info("weapon imbue on but not readable (enchant id %s)", tostring(id))
  end
  return "unknown"
end

-- the imbue `name` is the one on the weapon (unknown counts as on: no re-imbue loop)
function M.ImbueOn(name)
  if not M.IMBUE_WORD[name] then return false end
  local cur = M.CurrentImbue()
  return cur == name or cur == "unknown"
end

-- ---------------------------------------------------------------- targeting
function M:TargetProfile(load)
  if C.Readable(C.Call("UnitExists", "target")) ~= true then return nil end
  if C.Readable(C.Call("UnitIsDead", "target")) == true then return nil end
  if C.Readable(C.Call("UnitCanAttack", "player", "target")) == false then return nil end
  local id = C.UnitNpcID("target")
  if not id then return nil end
  return self:Profile(id, nil, load), id
end

function M:OnTarget()
  if C.InCombat() or not self:Settings().on then return end
  local P, id = self:TargetProfile(true)
  if not id then return end -- no hostile NPC: keep the last mob's picks
  local picks = self:Picks(P)
  local name = C.Readable(C.Call("UnitName", "target"))
  picks.mob = type(name) == "string" and name or tostring(id)
  local was = self.picks and self.picks.sig or ""
  self.picks = picks
  if picks.sig ~= was then
    self:Info("loadout for %s (%s): %s%s", picks.mob, tostring(id),
      #picks.why > 0 and table.concat(picks.why, "; ") or "plan's own picks",
      P and ("; " .. (M.Describe(P) or "nothing special")) or "; not in the pack")
    if ns.HunterFight and ns.HunterFight.Update then
      ns.Throttle("hunterfight", 1, function() ns.HunterFight:Update("target") end)
    end
  end
end

function M:OnEnable()
  self:On("PLAYER_TARGET_CHANGED", self.OnTarget)
end

-- Tooltip: what this mob resists and casts (only once the pack is loaded:
-- hovering never loads 300 KB).
if ns.TooltipLines then
  ns.TooltipLines:Add("unit", "loadout", M, function(tip)
    if not tip.GetUnit then return nil end
    local _, unit = tip:GetUnit()
    if not unit or C.Readable(C.Call("UnitIsPlayer", unit)) == true then return nil end
    local id = C.UnitNpcID(unit)
    local P = id and M:Profile(id, nil, false)
    local text = M.Describe(P)
    if not text then return nil end
    return { { "Outrider: " .. text, "muted" } }
  end)
end

function M:Activity()
  local p = self.picks
  if not p or p.sig == "" then return "No swaps for the last target" end
  return string.format("%s: %s", tostring(p.mob), table.concat(p.why, "; "))
end

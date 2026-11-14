-- Modules/GearScore.lua  (P6-01 weights, P6-02 scoring, P6-03 tooltip verdict)
-- Score = sum(stat x weight) from C_Item.GetItemStats, plus weapon DPS
-- (ranged DPS weighs heavily for hunters). Compared with what is worn in
-- the same slot: rings and trinkets against the weaker one, a two-hander
-- against main hand + off hand. Usable checks: required level and armor
-- type for the class. Item tooltips get one line, e.g.
--   "+12% upgrade (Ranged, levelling)"  green
--   "downgrade -5%"                      muted
--   "usable at 26 (+8%)"                 amber
-- Weights are starting points (Data/StatWeights.lua); /ride weights shows them.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("GearScore", {
  title = "Gear advisor",
  phase = "P6",
  order = 80,
  defaults = { weights = {} },
})
ns.GearScore = M

local SLOTS = {
  INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 }, INVTYPE_CHEST = { 5 },
  INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 },
  INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
  INVTYPE_WEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
  INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 },
  INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
M.SLOTS = SLOTS
M.SLOT_NAMES = { [1] = "head", [2] = "neck", [3] = "shoulder", [4] = "shirt", [5] = "chest", [6] = "waist", [7] = "legs",
  [8] = "feet", [9] = "wrist", [10] = "hands", [11] = "ring", [12] = "ring", [13] = "trinket", [14] = "trinket",
  [15] = "back", [16] = "weapon", [17] = "off-hand", [18] = "ranged" }
local RANGED = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }
-- armor subclass: 1 cloth, 2 leather, 3 mail, 4 plate; best each class wears (by level)
local ARMOR = { PRIEST = 1, MAGE = 1, WARLOCK = 1, ROGUE = 2, DRUID = 2 }
local ARMOR40 = { HUNTER = { 2, 3 }, SHAMAN = { 2, 3 }, WARRIOR = { 3, 4 }, PALADIN = { 3, 4 } }
M.MIN_BASE, M.MAX_PCT = 5, 300
local SHIELD_CLASSES = { WARRIOR = true, PALADIN = true, SHAMAN = true }
-- Weapon types each class can learn from weapon masters on WoW Forever:
-- Classic rules (wowpedia "Weapon skills"; hunters per Wowhead's Classic hunter
-- weapons guide: no fist weapons, wands or shields) plus Forever's changes
-- (warcrafttavern.com/forever/guides/weapon-trainers, read 2026-11-14: rogues
-- learn one-handed axes, druids learn polearms). Race never restricts a type;
-- it only changes the starting skills, which are read from the client
-- (KnowsWeapon), so a race's head start is covered without a table.
-- Shields: warriors, paladins, shamans. Unverified in game on Forever.
-- item weapon subclass ids: 0 axe, 1 2h axe, 2 bow, 3 gun, 4 mace, 5 2h mace,
-- 6 polearm, 7 sword, 8 2h sword, 10 staff, 13 fist, 15 dagger, 16 thrown,
-- 18 crossbow, 19 wand. Unverified on Forever.
local function set(...) local t = {} for _, v in ipairs({ ... }) do t[v] = true end return t end
M.WEAPON_TYPES = {
  WARRIOR = set(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18),
  PALADIN = set(0, 1, 4, 5, 6, 7, 8),
  HUNTER = set(0, 1, 2, 3, 6, 7, 8, 10, 15, 16, 18),
  ROGUE = set(0, 2, 3, 4, 7, 13, 15, 16, 18),
  PRIEST = set(4, 10, 15, 19),
  SHAMAN = set(0, 1, 4, 5, 10, 13, 15),
  MAGE = set(7, 10, 15, 19),
  WARLOCK = set(7, 10, 15, 19),
  DRUID = set(4, 5, 6, 10, 13, 15),
}
-- The weapon skill each weapon type needs (Classic spell ids) and its name.
-- Gary, 2026-11-14: offer only weapons the character can use, for every class:
-- a skill the class can learn but this character hasn't is "learn X first".
M.WEAPON_SKILL = { [0] = { 196, "Axes" }, [1] = { 197, "Two-Handed Axes" }, [2] = { 264, "Bows" }, [3] = { 266, "Guns" },
  [4] = { 198, "Maces" }, [5] = { 199, "Two-Handed Maces" }, [6] = { 200, "Polearms" }, [7] = { 201, "Swords" },
  [8] = { 202, "Two-Handed Swords" }, [10] = { 227, "Staves" }, [13] = { 15590, "Fist Weapons" }, [15] = { 1180, "Daggers" },
  [16] = { 2567, "Thrown" }, [18] = { 5011, "Crossbows" }, [19] = { 5009, "Wands" } }

local function rawKnows(id)
  local known = C.Call("IsPlayerSpell", id)
  if known == nil then known = C.Call("C_SpellBook.IsSpellKnown", id) end
  if known == nil then return nil end
  return C.Readable(known) and true or false
end

-- Can this client tell us? Only if at least one weapon skill reads as known
-- (if Forever's spell ids differ, everything would read "not learned").
function M.SkillsReadable()
  if M.skillsReadable ~= nil then return M.skillsReadable end
  local any = false
  for _, sk in pairs(M.WEAPON_SKILL) do if rawKnows(sk[1]) then any = true break end end
  M.skillsReadable = any
  return any
end

-- true / false, or nil when the client can't say
function M.KnowsWeapon(subclass)
  local sk = M.WEAPON_SKILL[subclass]
  if not sk or not M.SkillsReadable() then return nil end
  return rawKnows(sk[1])
end

-- "Bows, Daggers, Swords" (logged at login so the ids can be checked in game)
function M.KnownWeapons()
  local out = {}
  for _, sk in pairs(M.WEAPON_SKILL) do if rawKnows(sk[1]) then out[#out + 1] = sk[2] end end
  table.sort(out)
  return out
end

-- The armor type a class should buy (its heaviest; Gary, 2026-11-14: "no mail
-- for a priest, no cloth for a hunter"): 1 cloth, 2 leather, 3 mail, 4 plate.
function M.ArmorType(cls, level)
  cls = cls or ns.PlayerClass()
  level = level or C.Call("UnitLevel", "player") or 1
  if ARMOR[cls] then return ARMOR[cls] end
  local a = ARMOR40[cls]
  if a then return level >= 40 and a[2] or a[1] end
  return nil
end
local OFFHAND = { INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true }

-- Stat weights for this character, or for another class (KitShare scores
-- items for other Outrider users with their class's weights).
function M:Weights(cls)
  local base = ns.StatWeights[cls or ns.PlayerClass()] or ns.StatWeights.WARRIOR
  local out = {}
  for k, v in pairs(base) do out[k] = v end
  if not cls then for k, v in pairs(self:Settings().weights) do out[k] = v end end
  return out
end

function M.Stats(link)
  local get = C.Resolve("C_Item.GetItemStats") or rawget(_G, "GetItemStats")
  if type(get) ~= "function" or not link then return {} end
  local ok, stats = pcall(get, link)
  return ok and type(stats) == "table" and stats or {}
end

function M:Score(link, equipLoc, cls)
  local w = self:Weights(cls)
  local total = 0
  for stat, value in pairs(M.Stats(link)) do
    local v = C.Readable(value)
    if type(v) == "number" then
      if stat == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" then
        total = total + v * ((RANGED[equipLoc or ""] and w.rangedDPS) or w.meleeDPS or 0)
      elseif type(w[stat]) == "number" then
        total = total + v * w[stat]
      end
    end
  end
  return total
end

local function linkID(link) return link and tonumber(link:match("item:(%d+)")) end

local function itemClass(link)
  local get = C.Resolve("C_Item.GetItemInfoInstant") or rawget(_G, "GetItemInfoInstant")
  if type(get) ~= "function" then return nil end
  local ok, _, _, _, equipLoc, _, class, subclass = pcall(get, link)
  if ok then return equipLoc, class, subclass end
end

-- nil when fine, else "level N" / "can't wear"
function M:Usable(link, info)
  local level = C.Call("UnitLevel", "player") or 1
  if info and info.reqLevel and info.reqLevel > level then return "level " .. info.reqLevel, info.reqLevel end
  local equipLoc, class, subclass = itemClass(link)
  if class == 4 and subclass == 6 and not SHIELD_CLASSES[ns.PlayerClass()] then return "can't wear" end
  if class == 2 and subclass then
    local ok = M.WEAPON_TYPES[ns.PlayerClass()]
    if subclass ~= 20 and ok and not ok[subclass] then return "can't wear" end
    -- the class can use it, but has this character learned the skill yet?
    if subclass ~= 20 and M.KnowsWeapon(subclass) == false then
      return "learn " .. M.WEAPON_SKILL[subclass][2]
    end
  end
  -- Hunter shots and Auto Shot need a bow, gun or crossbow: a thrown weapon in the ranged
  -- slot turns them off (Gary's Khreos was offered throwing daggers at +86%, 2026-11-12)
  if ns.PlayerClass() == "HUNTER" and (equipLoc or (info and info.equipLoc)) == "INVTYPE_THROWN" then return "hunter thrown" end
  -- off-hand items do nothing while a two-hander is in the main hand
  -- (Gary's hunter was told an orb was a +100% upgrade, 2026-11-11)
  if OFFHAND[equipLoc or (info and info.equipLoc) or ""] then
    local mh = C.Call("GetInventoryItemLink", "player", 16)
    if mh and select(1, itemClass(mh)) == "INVTYPE_2HWEAPON" then return "two-hander" end
  end
  if class == 4 and subclass and subclass >= 1 and subclass <= 4 then
    local cls = ns.PlayerClass()
    local max = ARMOR[cls]
    if not max and ARMOR40[cls] then max = level >= 40 and ARMOR40[cls][2] or ARMOR40[cls][1] end
    if max and subclass > max then
      if ARMOR40[cls] and subclass == ARMOR40[cls][2] then return "level 40", 40 end
      return "can't wear"
    end
  end
  return nil
end

-- Returns { pct, new, old, slot, why, future }; nil if not gear.
function M:Compare(link)
  local info = C.ItemInfo(link)
  local equipLoc = info and info.equipLoc or select(1, itemClass(link))
  local slots = equipLoc and SLOTS[equipLoc]
  if not slots then return nil end
  local new = self:Score(link, equipLoc)
  local old, empty = nil, true
  local against = {} -- the worn item(s) this replaces, for the stat-by-stat difference
  if equipLoc == "INVTYPE_2HWEAPON" then
    local mh, oh = C.Call("GetInventoryItemLink", "player", 16), C.Call("GetInventoryItemLink", "player", 17)
    old = (mh and self:Score(mh, "INVTYPE_WEAPON") or 0) + (oh and self:Score(oh, "INVTYPE_WEAPONOFFHAND") or 0)
    empty = not mh and not oh
    against = { mh, oh }
  else
    for _, slot in ipairs(slots) do
      local worn = C.Call("GetInventoryItemLink", "player", slot)
      local s = worn and self:Score(worn, equipLoc) or 0
      if worn then empty = false end
      if worn and linkID(worn) == linkID(link) then s = new end
      if not old or s < old then old = s against = { worn } end -- compare with the weaker ring/trinket
    end
  end
  old = old or 0
  -- A worn item that scores near zero (e.g. a melee weapon for a hunter) made
  -- anything look like "+5617%" (Gary's snapshot, 2026-11-11): compare against
  -- at least MIN_BASE points and cap the result at MAX_PCT ("big upgrade").
  local pct, capped = 0, false
  if new ~= old then pct = (new - old) / math.max(old, M.MIN_BASE) * 100 end
  if pct > M.MAX_PCT then pct, capped = M.MAX_PCT, true end
  local why, futureLevel = self:Usable(link, info)
  return { pct = pct, new = new, old = old, slot = slots[1], why = why, future = futureLevel, empty = empty, capped = capped,
    against = against }
end

-- Stat by stat, new item minus what it replaces (Gary, 2026-11-14: "tell how
-- much it improves each stat ... am I trading raw damage for -20 agility"):
-- { {label, delta} }, damage per second first, then the stats this class
-- weighs most. Armor and DPS keep one decimal.
M.STAT_LABEL = {
  ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS", ITEM_MOD_AGILITY_SHORT = "Agi", ITEM_MOD_STRENGTH_SHORT = "Str",
  ITEM_MOD_STAMINA_SHORT = "Sta", ITEM_MOD_INTELLECT_SHORT = "Int", ITEM_MOD_SPIRIT_SHORT = "Spi",
  RESISTANCE0_NAME = "Armor", ITEM_MOD_ATTACK_POWER_SHORT = "AP", ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RAP",
  ITEM_MOD_CRIT_RATING_SHORT = "Crit", ITEM_MOD_HIT_RATING_SHORT = "Hit", ITEM_MOD_SPELL_POWER_SHORT = "SP",
  ITEM_MOD_MANA_REGENERATION_SHORT = "MP5", ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "Def",
}
function M:Diff(link, against)
  local sum = {}
  local function add(l, sign)
    if not l then return end
    for stat, v in pairs(M.Stats(l)) do
      v = C.Readable(v)
      if type(v) == "number" then sum[stat] = (sum[stat] or 0) + sign * v end
    end
  end
  add(link, 1)
  for _, l in pairs(against or {}) do add(l, -1) end
  local w = self:Weights()
  local out = {}
  for stat, d in pairs(sum) do
    if math.abs(d) >= 0.05 then
      local label = M.STAT_LABEL[stat] or (stat:gsub("^ITEM_MOD_", ""):gsub("_SHORT$", ""):gsub("_", " "):lower())
      local weight = stat == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" and 1000 or math.abs(w[stat] or 0)
      out[#out + 1] = { label = label, delta = d, weight = weight, stat = stat }
    end
  end
  table.sort(out, function(a, b) if a.weight ~= b.weight then return a.weight > b.weight end return a.label < b.label end)
  return out
end

-- "+4.1 DPS  -20 Agi  +5 Str" with gains green and losses red
function M.DiffText(diff, max)
  local parts = {}
  for i, d in ipairs(diff) do
    if max and i > max then break end
    local fmt = (d.stat == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" or math.floor(d.delta) ~= d.delta) and "%+.1f %s" or "%+d %s"
    local txt = string.format(fmt, d.delta, d.label)
    parts[#parts + 1] = (d.delta > 0 and "|cff7fff7f" or "|cffff6060") .. txt .. "|r"
  end
  return table.concat(parts, "  ")
end

function M:Verdict(link)
  local r = self:Compare(link)
  if not r then return nil end
  local role = (ns.StatWeights[ns.PlayerClass()] or {}).role or ""
  if r.why == "can't wear" then return "can't wear this armor type", "muted" end
  if r.why == "two-hander" then return "not with your two-hander", "muted" end
  if r.why == "hunter thrown" then return "no Auto Shot with a thrown weapon", "muted" end
  if type(r.why) == "string" and r.why:find("^learn ") then
    local pct = math.floor(r.pct + 0.5)
    return string.format("%s at a weapon master first%s", r.why, pct > 0 and string.format(" (+%d%%)", pct) or ""), "warn"
  end
  local pct = math.floor(r.pct + 0.5)
  -- "fills an empty slot (Ranged (levelling))" on a belt read like the slot was Ranged (Gary's log, 2026-11-11)
  if not r.why and r.empty and r.new > 0 then
    local name = M.SLOT_NAMES[r.slot]
    return name and ("fills your empty " .. name .. " slot") or "fills an empty slot", "good"
  end
  if r.why then
    if pct > 0 then return string.format("usable at %d (+%d%%)", r.future or 0, pct), "warn" end
    return nil
  end
  if r.capped then return string.format("big upgrade (%s)", role), "good" end
  if pct >= 1 then return string.format("+%d%% upgrade (%s)", pct, role), "good" end
  if pct <= -1 then return string.format("downgrade %d%%", pct), "muted" end
  return "about the same as yours", "muted"
end

-- Tooltip verdict through the shared ordered block (P7-05)
ns.TooltipLines:Add("item", "verdict", M, function(tip)
  if not tip.GetItem then return nil end
  local _, link = tip:GetItem()
  local text, color = M:Verdict(link)
  return text and { { text, color } } or nil
end)

-- P9-01: the weights the verdicts use
function M:Snapshot()
  local w, out = self:Weights(), {}
  for k, v in pairs(w) do if type(v) == "number" then out[k] = v end end
  return { role = w.role, weights = out }
end

-- At login: which weapon skills the client says this character knows.
function M:OnEnable()
  self:On("PLAYER_ENTERING_WORLD", function(mod)
    if mod.loggedSkills then return end
    mod.loggedSkills = true
    M.skillsReadable = nil
    local known = M.KnownWeapons()
    mod:Info("weapon skills known: %s", #known > 0 and table.concat(known, ", ") or "none readable (weapon type check off)")
  end)
end

function M:Activity()
  local w = ns.StatWeights[ns.PlayerClass()] or {}
  return "item tooltips compare with your gear (" .. tostring(w.role or "?") .. " weights)"
end

ns.AddCommand("weights", "show the stat weights used for this character", function()
  local w = M:Weights()
  local keys = {}
  for k, v in pairs(w) do if type(v) == "number" then keys[#keys + 1] = k end end
  table.sort(keys, function(a, b) return w[a] > w[b] end)
  ns.Print("%s weights (%s):", tostring(w.role), tostring(w.source))
  for _, k in ipairs(keys) do ns.Print("  %s = %.2f", (k:gsub("ITEM_MOD_", ""):gsub("_SHORT", "")), w[k]) end
end)

ns.AddCommand("score", "<item link>  compare an item with what you wear", function(arg)
  local link = arg and arg:match("|H(item:[^|]+)|h") and arg or nil
  if not link then ns.Print("usage: /ride score [shift-click an item]") return end
  local r = M:Compare(link)
  if not r then ns.Print("not gear") return end
  ns.Print("%s: score %.1f vs %.1f worn (%s)", link, r.new, r.old, tostring(M:Verdict(link)))
end)

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
local RANGED = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }
-- armor subclass: 1 cloth, 2 leather, 3 mail, 4 plate; best each class wears (by level)
local ARMOR = { PRIEST = 1, MAGE = 1, WARLOCK = 1, ROGUE = 2, DRUID = 2 }
local ARMOR40 = { HUNTER = { 2, 3 }, SHAMAN = { 2, 3 }, WARRIOR = { 3, 4 }, PALADIN = { 3, 4 } }
local SHIELD_CLASSES = { WARRIOR = true, PALADIN = true, SHAMAN = true }
local OFFHAND = { INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true }

function M:Weights()
  local base = ns.StatWeights[ns.PlayerClass()] or ns.StatWeights.WARRIOR
  local out = {}
  for k, v in pairs(base) do out[k] = v end
  for k, v in pairs(self:Settings().weights) do out[k] = v end
  return out
end

function M.Stats(link)
  local get = C.Resolve("C_Item.GetItemStats") or rawget(_G, "GetItemStats")
  if type(get) ~= "function" or not link then return {} end
  local ok, stats = pcall(get, link)
  return ok and type(stats) == "table" and stats or {}
end

function M:Score(link, equipLoc)
  local w = self:Weights()
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
  if equipLoc == "INVTYPE_2HWEAPON" then
    local mh, oh = C.Call("GetInventoryItemLink", "player", 16), C.Call("GetInventoryItemLink", "player", 17)
    old = (mh and self:Score(mh, "INVTYPE_WEAPON") or 0) + (oh and self:Score(oh, "INVTYPE_WEAPONOFFHAND") or 0)
    empty = not mh and not oh
  else
    for _, slot in ipairs(slots) do
      local worn = C.Call("GetInventoryItemLink", "player", slot)
      local s = worn and self:Score(worn, equipLoc) or 0
      if worn then empty = false end
      if worn and linkID(worn) == linkID(link) then s = new end
      if not old or s < old then old = s end -- compare with the weaker ring/trinket
    end
  end
  old = old or 0
  local pct
  if old > 0 then pct = (new - old) / old * 100 elseif new > 0 then pct = 100 else pct = 0 end
  local why, futureLevel = self:Usable(link, info)
  return { pct = pct, new = new, old = old, slot = slots[1], why = why, future = futureLevel, empty = empty }
end

function M:Verdict(link)
  local r = self:Compare(link)
  if not r then return nil end
  local role = (ns.StatWeights[ns.PlayerClass()] or {}).role or ""
  if r.why == "can't wear" then return "can't wear this armor type", "muted" end
  if r.why == "two-hander" then return "not with your two-hander", "muted" end
  local pct = math.floor(r.pct + 0.5)
  if not r.why and r.empty and r.new > 0 then return "fills an empty slot (" .. role .. ")", "good" end
  if r.why then
    if pct > 0 then return string.format("usable at %d (+%d%%)", r.future or 0, pct), "warn" end
    return nil
  end
  if pct >= 1 then return string.format("+%d%% upgrade (%s)", pct, role), "good" end
  if pct <= -1 then return string.format("downgrade %d%%", pct), "muted" end
  return "about the same as yours", "muted"
end

function M:OnEnable()
  if self.hooked then return end
  self.hooked = true
  local add, enum = C.Resolve("TooltipDataProcessor.AddTooltipPostCall"), C.Resolve("Enum.TooltipDataType.Item")
  if type(add) ~= "function" or not enum then return end
  add(enum, function(tip)
    if not M.enabled or tip ~= GameTooltip or not tip.GetItem then return end
    ns.Safe("GearScore:tooltip", function()
      local _, link = tip:GetItem()
      local text, color = M:Verdict(link)
      if text then tip:AddLine(text, ns.Theme:Color(color)) end
    end)
  end)
end

-- P9-01: the weights the verdicts use
function M:Snapshot()
  local w, out = self:Weights(), {}
  for k, v in pairs(w) do if type(v) == "number" then out[k] = v end end
  return { role = w.role, weights = out }
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

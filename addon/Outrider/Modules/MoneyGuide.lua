-- Modules/MoneyGuide.lua
-- The best ways to earn gold at your level and with your professions (Gary,
-- 2026-11-14). Two halves:
--   * Guide: Data/Money.lua (cited Forever gold guides, unverified), filtered
--     by level, professions and faction.
--   * Your own numbers: every loot window is booked to a kind of earning
--     (LootLog's OTR_LOOT: skin, herb, ore, fish, mob; cloth is split out of
--     mob loot) at auction price less 5% when Outrider knows one, else the
--     vendor price. Time counts the gaps between loots of that kind, at most
--     5 minutes each, so a break doesn't count as farming. After 15 minutes of
--     one kind, its measured gold per hour replaces the guide's number.
-- ns.db.global.moneyLog[kind] = { value, secs, last, items = { [itemID] = { n, value, name } } }
-- Read only: it never sells or buys anything.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("MoneyGuide", {
  title = "Money guide (best earnings for your level)",
  phase = "P5",
  order = 79,
  defaults = {},
})
ns.MoneyGuide = M

M.MIN_SECS, M.GAP = 15 * 60, 5 * 60
M.KIND_LABEL = { skin = "Skinning", herb = "Herbs", ore = "Mining", fish = "Fishing", cloth = "Cloth", mob = "Mob loot", craft = "Crafting" }

function M:OnInitialize()
  local g = ns.db.global
  g.moneyLog = type(g.moneyLog) == "table" and g.moneyLog or {}
end

function M:OnEnable()
  self:On("OTR_LOOT", self.OnLoot)
end

-- What one item is worth to Gary: auction price less a 5% cut when known, else vendor.
function M.Worth(itemID)
  if not ns.Prices then return 0 end
  local ah, _, vendor = ns.Prices:Get(itemID)
  if ah then return math.floor(ah * 0.95) end
  return vendor or 0
end

local function isCloth(itemID)
  local info = C.ItemInfo(itemID)
  return info and info.subclass == "Cloth" or false
end

function M:Book(kind, item, now)
  local log = ns.db.global.moneyLog
  local k = log[kind] or { value = 0, secs = 0, items = {} }
  log[kind] = k
  if k.last ~= now then
    k.secs = k.secs + (k.last and math.min(now - k.last, M.GAP) or 60)
    k.last = now
  end
  local each = M.Worth(item.id)
  local v = each * (item.count or 1)
  k.value = k.value + v
  local it = k.items[item.id] or { n = 0, value = 0 }
  it.n, it.value, it.name = it.n + (item.count or 1), it.value + v, item.name or it.name
  k.items[item.id] = it
end

function M:OnLoot(_, kind, items)
  if type(items) ~= "table" then return end
  local now = time()
  for _, item in ipairs(items) do
    local k = kind
    if kind == "mob" and isCloth(item.id) then k = "cloth" end
    self:Book(k, item, now)
  end
end

-- Measured copper per hour for one kind of earning, or nil before 15 minutes.
function M:Rate(kind)
  local k = ns.db.global.moneyLog[kind]
  if not k or (k.secs or 0) < M.MIN_SECS then return nil end
  return math.floor(k.value / k.secs * 3600)
end

local function list(v) return type(v) == "table" and v or (v and { v } or {}) end

-- Owned professions as a set (Crafter's record, with fishing and skinning)
function M:Owned()
  return ns.Crafter and ns.Crafter:Owned() or {}
end

-- Does a guide entry fit this character? (pure given its inputs)
function M.Fits(e, level, owned, faction)
  if level < (e.minLevel or 1) - 2 or level > (e.maxLevel or 60) + 3 then return false end
  if e.faction and faction and e.faction ~= faction then return false end
  local profs = list(e.profession)
  if #profs == 0 then return true end
  for _, p in ipairs(profs) do if owned[p] then return true end end
  return false
end

-- Best measured rate among an entry's kinds, and which kind.
function M:Measured(e)
  local best, bestKind
  for _, kind in ipairs(list(e.category)) do
    local r = self:Rate(kind)
    if r and (not best or r > best) then best, bestKind = r, kind end
  end
  return best, bestKind
end

-- Ranked entries for this character: { {entry, rate, measured = bool} }
function M:Rank(level, owned, faction)
  level = level or C.Call("UnitLevel", "player") or 1
  owned = owned or self:Owned()
  faction = faction or C.Readable(C.Call("UnitFactionGroup", "player"))
  local out = {}
  for _, e in ipairs(ns.Data:All("money")) do
    if M.Fits(e, level, owned, faction) then
      local mine = self:Measured(e)
      local guide = e.gph and math.floor((e.gph[1] + e.gph[2]) / 2) or nil
      out[#out + 1] = { entry = e, rate = mine or guide, measured = mine ~= nil, guide = guide }
    end
  end
  table.sort(out, function(a, b)
    if (a.rate ~= nil) ~= (b.rate ~= nil) then return a.rate ~= nil end
    if a.rate and b.rate and a.rate ~= b.rate then return a.rate > b.rate end
    return a.entry.title < b.entry.title
  end)
  return out
end

-- "about 2g 0s an hour (your own loot)" / "(guide, unverified)" / "no figure yet"
function M.RateText(r)
  if not r.rate then return "no gold-per-hour figure yet" end
  return string.format("about %s an hour (%s)", ns.Prices.Money(r.rate), r.measured and "your own loot" or "guide, unverified")
end

-- One line per kind of earning Gary has done: "Herbs: 1g 20s an hour over 34 min; best: Silverleaf 3s"
function M:YourLines()
  local out = {}
  for kind, k in pairs(ns.db.global.moneyLog) do
    if (k.value or 0) > 0 then
      local best, bv
      for _, it in pairs(k.items or {}) do if not bv or it.value > bv then best, bv = it, it.value end end
      local r = self:Rate(kind)
      out[#out + 1] = string.format("%s: %s over %d min%s", M.KIND_LABEL[kind] or kind,
        r and (ns.Prices.Money(r) .. " an hour") or (ns.Prices.Money(k.value) .. " so far"),
        math.floor((k.secs or 0) / 60), best and string.format("; best seller %s (%s)", tostring(best.name), ns.Prices.Money(bv)) or "")
    end
  end
  table.sort(out)
  return out
end

function M:Activity()
  local r = self:Rank()
  local top = r[1]
  return top and ("best now: " .. top.entry.title .. ", " .. M.RateText(top)) or "no money tips for this level yet"
end

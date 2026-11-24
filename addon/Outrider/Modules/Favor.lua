-- Modules/Favor.lua  (P5-06 Merchant's Favor planner)
-- Forever adds Waylaid Crates: fill one with one bundle from its list, turn
-- it in at Durotar Supply and Logistics (Horde) or the Azeroth Commerce
-- Authority (Alliance) for Merchant's Favor (a currency) and reputation.
-- Guides (method.gg, mobalytics.gg, read 2026-11-15) say that much; how it
-- shows in the API is unknown, so this module captures first (hard rule 7):
--   * Favor: any currency whose name has "Favor" (id, amount), per character
--   * standing with the two depot factions
--   * crates in bags: item id, name and tooltip lines, parsed into bundles
--   * the quartermaster's list: what it sells and the currency cost
-- Everything goes to ns.db.global.favor and the log (once per kind of thing);
-- the Money page shows the balance and, per crate, which bundle you can fill
-- now from bags, bank and alts, or what it would cost to buy.
-- Read-only: nothing is bought, used, filled or turned in.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Favor", {
  title = "Merchant's Favor and Waylaid Crates",
  phase = "P5",
  order = 72,
  defaults = {},
})
ns.Favor = M

M.FACTIONS = { "Durotar Supply and Logistics", "Azeroth Commerce Authority" }

function M:OnInitialize()
  local g = ns.db.global
  g.favor = ns.KeepTable(g.favor, "Favor:g.favor") or {}
  local f = g.favor
  f.balance = ns.KeepTable(f.balance, "Favor:f.balance") or {}   -- [charKey] = { amount, currencyID, name, at }
  f.standing = ns.KeepTable(f.standing, "Favor:f.standing") or {} -- [charKey] = { name, reaction, value, at }
  f.crates = ns.KeepTable(f.crates, "Favor:f.crates") or {}       -- [itemID] = { name, lines, bundles, firstSeen, verified }
  f.vendor = ns.KeepTable(f.vendor, "Favor:f.vendor") or {}       -- [npcName] = { items = { {name, itemID, costs} }, at }
  self.db = f
  self.logged = {}
end

local function once(self, key, fmt, ...)
  if self.logged[key] then return end
  self.logged[key] = true
  self:Info(fmt, ...)
end

-- --------------------------------------------------------------- currency
function M:ReadCurrency()
  local n = C.Call("C_CurrencyInfo.GetCurrencyListSize")
  if type(n) ~= "number" then return nil end
  for i = 1, n do
    local info = C.Call("C_CurrencyInfo.GetCurrencyListInfo", i)
    if type(info) == "table" and not info.isHeader and type(info.name) == "string" and info.name:find("Favor") then
      local link = C.Call("C_CurrencyInfo.GetCurrencyListLink", i)
      local id = tonumber(tostring(link or ""):match("currency:(%d+)"))
      return { name = info.name, amount = tonumber(info.quantity) or 0, currencyID = id, at = time() }
    end
  end
  return nil
end

function M:ScanCurrency()
  local cur = self:ReadCurrency()
  if not cur then return nil end
  local old = self.db.balance[ns.db.key]
  self.db.balance[ns.db.key] = cur
  if not old or old.amount ~= cur.amount then
    self:Info("favor: %s %d (currency %s)", cur.name, cur.amount, tostring(cur.currencyID))
  end
  return cur
end

-- ------------------------------------------------------------- reputation
local function factionAt(i)
  local d = C.Call("C_Reputation.GetFactionDataByIndex", i)
  if type(d) == "table" then return d.name, d.reaction, d.currentStanding end
  local name, _, standing, _, _, value = C.Call("GetFactionInfo", i)
  return name, standing, value
end

function M:ScanStanding()
  local n = C.Call("C_Reputation.GetNumFactions") or C.Call("GetNumFactions")
  if type(n) ~= "number" then return nil end
  for i = 1, n do
    local name, reaction, value = factionAt(i)
    for _, want in ipairs(self.FACTIONS) do
      if name == want then
        local s = { name = name, reaction = reaction, value = value, at = time() }
        self.db.standing[ns.db.key] = s
        once(self, "rep", "favor: standing with %s: reaction %s, %s", name, tostring(reaction), tostring(value))
        return s
      end
    end
  end
  return nil
end

-- ------------------------------------------------------------------ crates
-- Bundle lines as a tooltip might word them: "20 Linen Cloth", "Linen Cloth x20",
-- "Linen Cloth (0/20)", "Linen Cloth: 0/20". Anything else is kept as text only.
function M.ParseBundle(line)
  if type(line) ~= "string" then return nil end
  line = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s*[%-%*]?%s*", ""):gsub("%s+$", "")
  local n, name = line:match("^(%d+)%s*x?%s+(%a[%a%s'%-:,]+)$")
  if not n then name, n = line:match("^(%a[%a%s'%-,]-)%s*x%s*(%d+)$") end
  if not n then name, n = line:match("^(%a[%a%s'%-,]-)%s*:?%s*%(?%d+%s*/%s*(%d+)%)?$") end
  n = tonumber(n)
  if not n or n < 1 or n > 1000 or not name then return nil end
  name = name:gsub("%s+$", "")
  if #name < 3 then return nil end
  return { name = name, count = n }
end

function M.IsCrate(name)
  return type(name) == "string" and (name:find("Waylaid") ~= nil or name:find("Crate") ~= nil)
end

function M:LearnCrate(itemID, name, lines)
  local e = self.db.crates[itemID]
  if not e then
    e = { name = name, firstSeen = time(), verified = false, source = "tooltip capture" }
    self.db.crates[itemID] = e
  end
  e.name = name or e.name
  if type(lines) == "table" and #lines > 0 then
    e.lines, e.bundles = {}, {}
    for i = 2, math.min(#lines, 30) do
      local t = lines[i]
      e.lines[#e.lines + 1] = t
      local b = M.ParseBundle(t)
      if b then e.bundles[#e.bundles + 1] = b end
    end
  end
  once(self, "crate:" .. itemID, "favor: crate %d '%s' with %d tooltip lines, %d bundles read",
    itemID, tostring(name), e.lines and #e.lines or 0, e.bundles and #e.bundles or 0)
  return e
end

local function tooltipLines(bag, slot)
  local data = C.Call("C_TooltipInfo.GetBagItem", bag, slot)
  if type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
  local out = {}
  for _, l in ipairs(data.lines) do
    local t = C.Readable and C.Readable(l.leftText) or l.leftText
    if type(t) == "string" and t ~= "" then out[#out + 1] = t end
  end
  return out
end

function M:ScanCrates()
  local found = 0
  for bag = 0, (rawget(_G, "NUM_BAG_SLOTS") or 4) do
    for slot = 1, C.NumSlots(bag) do
      local _, id = C.ItemCountAt(bag, slot)
      if id then
        local info = C.ItemInfo(id)
        local name = info and info.name
        if M.IsCrate(name) then
          found = found + 1
          local known = self.db.crates[id]
          if not known or not known.lines then self:LearnCrate(id, name, tooltipLines(bag, slot)) end
        end
      end
    end
  end
  return found
end

-- -------------------------------------------------------------- vendor
function M:ScanVendor()
  local n = C.Call("GetMerchantNumItems")
  if type(n) ~= "number" or n == 0 then return nil end
  local npc = C.Call("UnitName", "npc") or "?"
  local items, favorItems = {}, 0
  for i = 1, math.min(n, 200) do
    local costs = {}
    local cn = C.Call("GetMerchantItemCostInfo", i)
    for c = 1, (type(cn) == "number" and cn or 0) do
      local _, value, link, curName = C.Call("GetMerchantItemCostItem", i, c)
      costs[#costs + 1] = { value = value, name = curName, link = link and tostring(link):match("(%a+:%d+)") }
      if type(curName) == "string" and curName:find("Favor") then favorItems = favorItems + 1 end
    end
    local id = C.Call("GetMerchantItemID", i)
    local info = id and C.ItemInfo(id)
    items[#items + 1] = { itemID = id, name = info and info.name, costs = costs }
  end
  if favorItems == 0 then return nil end   -- an ordinary vendor
  self.db.vendor[npc] = { items = items, at = time(), verified = true, source = "merchant window" }
  once(self, "vendor:" .. npc, "favor: quartermaster %s sells %d items, %d for Favor", npc, #items, favorItems)
  return items
end

-- ----------------------------------------------------------------- plan
-- itemID for a bundle's name, from what any character owns (names come
-- from the item cache, so an item never seen this session may be missing).
function M:FindItem(name)
  local inv = ns.Inventory and ns.Inventory.db
  if not inv then return nil end
  for _, char in pairs(inv) do
    for _, place in ipairs({ "bags", "bank", "mail" }) do
      for id in pairs(char[place] or {}) do
        local info = C.ItemInfo(id)
        if info and info.name == name then return id end
      end
    end
  end
  return nil
end

-- Per crate: each bundle with have, need, and (if short) the cost to buy the rest.
function M:Plan(itemID)
  local crate = self.db.crates[itemID]
  if not crate then return nil end
  local out = {}
  for _, b in ipairs(crate.bundles or {}) do
    local id = self:FindItem(b.name)
    local have, per = 0, {}
    if id and ns.Inventory then have, per = ns.Inventory:Count(id) end
    local short = math.max(0, b.count - have)
    local price = id and ns.Prices and ns.Prices:Get(id)
    out[#out + 1] = { name = b.name, count = b.count, itemID = id, have = have, per = per, short = short,
      cost = (short > 0 and price) and price * short or nil, ready = short == 0 }
  end
  table.sort(out, function(a, b)
    if a.ready ~= b.ready then return a.ready end
    return (a.cost or math.huge) < (b.cost or math.huge)
  end)
  return out
end

function M:Lines()
  local lines = {}
  local bal = self.db.balance[ns.db.key]
  lines[#lines + 1] = bal and string.format("|cffffd100%s:|r %d", bal.name, bal.amount)
    or "Merchant's Favor: not seen yet (Outrider reads it once you have some)."
  local st = self.db.standing[ns.db.key]
  if st then lines[#lines + 1] = string.format("Standing with %s: %s", st.name, tostring(st.reaction)) end
  local any = false
  for id, crate in pairs(self.db.crates) do
    any = true
    local plan = self:Plan(id)
    if not plan or #plan == 0 then
      lines[#lines + 1] = string.format("|cffffd100%s|r: contents not read yet (hover it in your bags).", crate.name or ("crate " .. id))
    else
      local best = plan[1]
      local what
      if best.ready then
        what = string.format("ready: you have %d %s", best.have, best.name)
      elseif best.cost then
        what = string.format("closest: %s, %d short (about %s to buy)", best.name, best.short, ns.Prices.Money(best.cost))
      else
        what = string.format("closest: %s, %d short (no price seen)", best.name, best.short)
      end
      lines[#lines + 1] = string.format("|cffffd100%s|r: %s  |cff8f96a6(unchecked)|r", crate.name or ("crate " .. id), what)
    end
  end
  if not any then lines[#lines + 1] = "No Waylaid Crate seen yet. When you loot one, Outrider reads what it asks for." end
  return lines
end

function M:OnEnable()
  self:On("PLAYER_ENTERING_WORLD", function(mod) mod:ScanCurrency() mod:ScanStanding() mod:ScanCrates() end)
  self:On("CURRENCY_DISPLAY_UPDATE", function(mod) ns.Throttle("favor:cur", 2, function() mod:ScanCurrency() end) end)
  self:On("BAG_UPDATE_DELAYED", function(mod) ns.Throttle("favor:bags", 2, function() mod:ScanCrates() end) end)
  self:On("MERCHANT_SHOW", function(mod) mod:ScanVendor() mod:ScanCurrency() mod:ScanStanding() end)
  self:On("UPDATE_FACTION", function(mod) ns.Throttle("favor:rep", 5, function() mod:ScanStanding() end) end)
end

function M:OnDisable() ns.ThrottleCancel("favor:cur") ns.ThrottleCancel("favor:bags") ns.ThrottleCancel("favor:rep") end

function M:Activity() return "loot a Waylaid Crate or visit your faction's supply depot" end

ns.AddCommand("favor", "Merchant's Favor balance and what your crates need", function()
  for _, l in ipairs(M:Lines()) do ns.Print(l) end
end)

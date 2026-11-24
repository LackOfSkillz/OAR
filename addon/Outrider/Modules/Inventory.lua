-- Modules/Inventory.lua  (P5-01)
-- What every character owns, account-wide in ns.db.global.inventory[charKey]:
--   { bags = {[itemID]=count}, bank = {...}, mail = {...}, worn = {...}, money, at }
-- Bags on BAG_UPDATE_DELAYED (throttled), bank while the bank window is open,
-- mail when the inbox updates, worn gear at login. Item tooltips get one line:
-- "You have 12 (Torrant 8, Lumen 4)"; Shift shows where (bags/bank/mail).
-- Counts only; nothing is moved or used.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Inventory", {
  title = "Items across characters",
  phase = "P5",
  order = 70,
  defaults = {},
})
ns.Inventory = M

M.BANK_BAGS = { -1, 5, 6, 7, 8, 9, 10, 11 }

function M:OnInitialize()
  local g = ns.db.global
  g.inventory = ns.KeepTable(g.inventory, "Inventory:g.inventory") or {}
  self.db = g.inventory
end

function M:Mine()
  local key = ns.db.key
  local me = self.db[key]
  if type(me) ~= "table" then ns.KeepBad(me, "Inventory:me") me = { bags = {}, bank = {}, mail = {}, worn = {} } self.db[key] = me end
  return me
end

local function countBags(list)
  local out = {}
  for _, bag in ipairs(list) do
    for slot = 1, C.NumSlots(bag) do
      local n, id = C.ItemCountAt(bag, slot)
      if id and n and n > 0 then out[id] = (out[id] or 0) + n end
    end
  end
  return out
end

function M:ScanBags()
  local bags = {}
  for b = 0, (rawget(_G, "NUM_BAG_SLOTS") or 4) do bags[#bags + 1] = b end
  local me = self:Mine()
  me.bags = countBags(bags)
  me.money = C.Call("GetMoney") or me.money
  me.at = time()
end

function M:ScanBank()
  local me = self:Mine()
  me.bank = countBags(self.BANK_BAGS)
  me.bankAt = time()
  self:Info("bank scanned: %d kinds of item", self.Kinds(me.bank))
end

function M:ScanMail()
  local n = C.Call("GetInboxNumItems") or 0
  local mail = {}
  for i = 1, n do
    for a = 1, (rawget(_G, "ATTACHMENTS_MAX_RECEIVE") or 16) do
      local link = C.Call("GetInboxItemLink", i, a)
      if link then
        local id = tonumber(link:match("item:(%d+)"))
        local _, _, _, count = C.Call("GetInboxItem", i, a)
        if id then mail[id] = (mail[id] or 0) + (count or 1) end
      end
    end
  end
  self:Mine().mail = mail
end

function M:ScanWorn()
  local worn = {}
  for slot = 1, 19 do
    local link = C.Call("GetInventoryItemLink", "player", slot)
    local id = link and tonumber(link:match("item:(%d+)"))
    if id then worn[id] = (worn[id] or 0) + 1 end
  end
  self:Mine().worn = worn
end

function M.Kinds(t)
  local n = 0
  for _ in pairs(t or {}) do n = n + 1 end
  return n
end

-- { total, { {char, count, where = {bags=, bank=, mail=, worn=}} ... } } for one item
function M:Count(itemID)
  local total, per = 0, {}
  for key, inv in pairs(self.db) do
    local where, sum = {}, 0
    for _, place in ipairs({ "bags", "bank", "mail", "worn" }) do
      local n = inv[place] and inv[place][itemID]
      if n and n > 0 then where[place] = n sum = sum + n end
    end
    if sum > 0 then per[#per + 1] = { char = key, count = sum, where = where } total = total + sum end
  end
  table.sort(per, function(a, b) return a.count > b.count end)
  return total, per
end

function M:TooltipLines(itemID, shift)
  local total, per = self:Count(itemID)
  if total == 0 then return {} end
  local parts = {}
  for _, p in ipairs(per) do
    local name = p.char:match("^([^-]+)") or p.char
    if shift then
      local w = {}
      for _, place in ipairs({ "bags", "bank", "mail", "worn" }) do
        if p.where[place] then w[#w + 1] = place .. " " .. p.where[place] end
      end
      parts[#parts + 1] = name .. ": " .. table.concat(w, ", ")
    else
      parts[#parts + 1] = name .. " " .. p.count
    end
  end
  if shift then
    local out = { "You have " .. total }
    for _, s in ipairs(parts) do out[#out + 1] = "  " .. s end
    return out
  end
  return { string.format("You have %d (%s)", total, table.concat(parts, ", ")) }
end

function M:OnEnable()
  self:On("BAG_UPDATE_DELAYED", function(mod) ns.Throttle("inventory:bags", 1, function() mod:ScanBags() end) end)
  self:On("PLAYER_ENTERING_WORLD", function(mod) mod:ScanBags() mod:ScanWorn() end)
  self:On("PLAYER_EQUIPMENT_CHANGED", function(mod) mod:ScanWorn() end)
  self:On("BANKFRAME_OPENED", function(mod) mod.bankOpen = true mod:ScanBank() end)
  self:On("BANKFRAME_CLOSED", function(mod) mod.bankOpen = false end)
  self:On("PLAYERBANKSLOTS_CHANGED", function(mod) if mod.bankOpen then mod:ScanBank() end end)
  self:On("MAIL_INBOX_UPDATE", function(mod) ns.Throttle("inventory:mail", 1, function() mod:ScanMail() end) end)
end

-- Counts across characters through the shared ordered block (P7-05)
ns.TooltipLines:Add("item", "owned", M, function(tip, data) return M:OnTooltip(tip, data) end)

function M:OnDisable() ns.ThrottleCancel("inventory:bags") ns.ThrottleCancel("inventory:mail") end

function M:OnTooltip(tip, data)
  local id = data and C.Readable(data.id)
  if type(id) ~= "number" then return end
  local shift = C.Call("IsShiftKeyDown") and true or false
  return self:TooltipLines(id, shift)
end

function M:Activity()
  local chars, me = 0, self.db[ns.db.key]
  for _ in pairs(self.db) do chars = chars + 1 end
  return string.format("%d characters tracked; you: %d kinds in bags, %d in bank", chars,
    self.Kinds(me and me.bags), self.Kinds(me and me.bank))
end

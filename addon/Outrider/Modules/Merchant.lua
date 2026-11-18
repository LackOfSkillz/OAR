-- Modules/Merchant.lua  (P5-09)
-- At a vendor, a small panel beside the merchant window:
--   Sell junk (n, value): sells grey items, at most 12 per click so every
--     one stays in the vendor's buyback list; click again for the rest.
--   Repair (cost): repairs everything (guild bank if the guild allows it).
-- Only on Gary's click, never on opening the window. Non-grey items are
-- never sold here.

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local M = ns:NewModule("Merchant", {
  title = "Merchant helper (sell junk, repair)",
  phase = "P5",
  order = 74,
  defaults = { useGuildRepair = true, alwaysSell = {}, sellOnce = {}, neverSell = {} },
})
ns.Merchant = M

M.PER_CLICK = 12
local POOR = 0

-- Explicit, protected vendor candidates. No non-grey item is sold unless
-- its ID was added by the player. Quest items and locked items are excluded.
function M:Protected(bag, slot, id, quality)
  local opts = self:Settings()
  if opts.neverSell and opts.neverSell[id] then return true, "never-sell" end
  local item = C.Call("C_Container.GetContainerItemInfo", bag, slot)
  if type(item) == "table" and C.Readable(item.isLocked) then return true, "locked" end
  local quest = C.Call("C_Container.GetContainerItemQuestInfo", bag, slot)
  if type(quest) == "table" then
    if C.Readable(quest.isQuestItem) or C.Readable(quest.questID) then return true, "quest item" end
  elseif quality ~= POOR then
    return true, "quest API unavailable"
  end
  return false
end

function M:Junk()
  local out = {}
  local opts = self:Settings()
  for bag = 0, (rawget(_G, "NUM_BAG_SLOTS") or 4) do
    for slot = 1, C.NumSlots(bag) do
      local count, id = C.ItemCountAt(bag, slot)
      if id then
        local info = C.ItemInfo(id)
        local allow = opts.alwaysSell and opts.alwaysSell[id]
        local once = opts.sellOnce and opts.sellOnce[id] and not allow
        if info and (info.quality == POOR or allow or once) and (info.sellPrice or 0) > 0 then
          if not self:Protected(bag, slot, id, info.quality) then
            out[#out + 1] = { bag = bag, slot = slot, id = id,
              value = info.sellPrice * (count or 1), once = once and true or false }
          end
        end
      end
    end
  end
  return out
end

function M:SellJunk()
  if C.InCombat() then return 0 end
  local use = C.Resolve("C_Container.UseContainerItem") or rawget(_G, "UseContainerItem")
  if type(use) ~= "function" then return 0 end
  local sold, value, onceUsed = 0, 0, {}
  for _, j in ipairs(self:Junk()) do
    if sold >= self.PER_CLICK then break end
    if not (j.once and onceUsed[j.id]) then
      if pcall(use, j.bag, j.slot) then
        sold, value = sold + 1, value + j.value
        if j.once then
          onceUsed[j.id] = true
          self:Settings().sellOnce[j.id] = nil
        end
      end
    end
  end
  if sold > 0 then self:Info("sold %d junk items for %s", sold, ns.Prices.Money(value)) end
  return sold, value
end

function M:RepairCost()
  local cost, can = C.Call("GetRepairAllCost")
  return cost or 0, can
end

function M:Repair()
  if C.InCombat() then return false end
  local cost, can = self:RepairCost()
  if not can or cost == 0 then return false end
  local guild = self:Settings().useGuildRepair and C.Call("CanGuildBankRepair")
  local ok = pcall(RepairAllItems, guild and true or nil)
  if ok then self:Info("repaired for %s%s", ns.Prices.Money(cost), guild and " (guild bank)" or "") end
  return ok
end

function M:Build()
  if self.frame then return self.frame end
  local anchor = rawget(_G, "MerchantFrame") or UIParent
  local f = CreateFrame("Frame", "Outrider_MerchantPanel", anchor, ns.Theme:BackdropTemplate())
  ns.Theme:ApplyPanel(f, "panel")
  f:SetSize(180, 74)
  f:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 6, 0)
  f.title = UI.Text(f, "normal", "accent")
  f.title:SetPoint("TOPLEFT", 8, -6)
  f.title:SetText("Outrider")
  f.sell = UI:Button(f, "Sell junk", 164, function() M:SellJunk() ns.Timer.After(0.3, function() M:Refresh() end, "merchant:refresh") end)
  f.sell:SetPoint("TOPLEFT", 8, -22)
  f.repair = UI:Button(f, "Repair", 164, function() M:Repair() ns.Timer.After(0.3, function() M:Refresh() end, "merchant:refresh") end)
  f.repair:SetPoint("TOPLEFT", 8, -48)
  f:Hide()
  self.frame = f
  return f
end

function M:Refresh()
  local f = self.frame
  if not f or not f:IsShown() then return end
  local junk, total = self:Junk(), 0
  for _, j in ipairs(junk) do total = total + j.value end
  f.sell.label:SetText(#junk > 0 and string.format("Sell approved (%d, %s)", #junk, ns.Prices.Money(total)) or "Nothing approved")
  local cost, can = self:RepairCost()
  f.repair.label:SetText((can and cost > 0) and ("Repair (" .. ns.Prices.Money(cost) .. ")") or "Nothing to repair")
end

function M:OnEnable()
  self:On("MERCHANT_SHOW", function(mod) mod:Build():Show() mod:Refresh() end)
  self:On("MERCHANT_CLOSED", function(mod) if mod.frame then mod.frame:Hide() end end)
  self:On("BAG_UPDATE_DELAYED", function(mod) mod:Refresh() end)
end

function M:OnDisable() if self.frame then self.frame:Hide() end end

function M:Activity() return "Sell junk and Repair buttons appear beside vendors" end

-- Lists affect only the next explicit Sell click. Nothing acts on vendor open.
ns.AddCommand("sell", "sell always|once|keep|unmark <item ID> | list", function(arg)
  local action, raw = tostring(arg or ""):match("^(%S+)%s*(.-)%s*$")
  action = action and action:lower() or "list"
  local opts = M:Settings()
  if action == "list" then
    local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
    ns.Print("vendor lists: %d always, %d once, %d never", count(opts.alwaysSell), count(opts.sellOnce), count(opts.neverSell))
    return
  end
  local id = tonumber(raw:match("item:(%d+)") or raw)
  if not id or id < 1 or id ~= math.floor(id) then
    ns.Print("usage: /ride sell always|once|keep|unmark <item ID>")
    return
  end
  opts.alwaysSell = opts.alwaysSell or {}
  opts.sellOnce = opts.sellOnce or {}
  opts.neverSell = opts.neverSell or {}
  if action == "always" then
    if opts.neverSell[id] then ns.Print("remove item %d from keep first", id) return end
    opts.alwaysSell[id], opts.sellOnce[id] = true, nil
  elseif action == "once" then
    if opts.neverSell[id] then ns.Print("item %d is protected by keep", id) return end
    opts.sellOnce[id], opts.alwaysSell[id] = true, nil
  elseif action == "keep" then
    opts.neverSell[id], opts.alwaysSell[id], opts.sellOnce[id] = true, nil, nil
  elseif action == "unmark" then
    opts.alwaysSell[id], opts.sellOnce[id], opts.neverSell[id] = nil, nil, nil
  else
    ns.Print("usage: /ride sell always|once|keep|unmark <item ID> | list")
    return
  end
  ns.Print("vendor list: %s item %d", action, id)
  M:Refresh()
end)

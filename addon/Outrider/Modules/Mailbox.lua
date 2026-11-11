-- Modules/Mailbox.lua  (P5-10)
-- A "Collect" button beside the mailbox. Each click takes ONE thing (the
-- money, else the first item) from the first mail that has something, so the
-- client's own throttling is respected and nothing is taken without a click.
-- Cash-on-delivery (COD) mail is never touched. The ledger (P5-08) books the
-- money as "mail".

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local M = ns:NewModule("Mailbox", {
  title = "Mailbox collect",
  phase = "P5",
  order = 77,
  defaults = {},
})
ns.Mailbox = M

-- Mails with money or items and no COD: { {index, money, items} }
function M:Collectable()
  local out = {}
  for i = 1, (C.Call("GetInboxNumItems") or 0) do
    -- 8 return values; C.Call passes only 5, so call directly
    local ok, _, _, _, _, money, cod, _, items = pcall(GetInboxHeaderInfo, i)
    if not ok then money, cod, items = 0, 0, 0 end
    money, cod, items = money or 0, cod or 0, items or 0
    if cod == 0 and (money > 0 or items > 0) then out[#out + 1] = { index = i, money = money, items = items } end
  end
  return out
end

function M:CollectOne()
  if C.InCombat() then return nil end
  local mail = self:Collectable()[1]
  if not mail then return nil end
  if mail.money > 0 then
    if pcall(TakeInboxMoney, mail.index) then
      self:Debug("took %s from mail %d", ns.Prices.Money(mail.money), mail.index)
      return "money"
    end
    return nil
  end
  for a = 1, (rawget(_G, "ATTACHMENTS_MAX_RECEIVE") or 16) do
    if C.Call("GetInboxItemLink", mail.index, a) then
      if pcall(TakeInboxItem, mail.index, a) then return "item" end
      return nil
    end
  end
end

function M:Build()
  if self.button then return self.button end
  local anchor = rawget(_G, "MailFrame") or UIParent
  local b = UI:Button(anchor, "Collect", 150, function()
    local got = M:CollectOne()
    if got then M.taken = (M.taken or 0) + 1 end
    ns.Timer.After(0.4, function() M:Refresh() end, "mail:refresh")
  end)
  b:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 6, -30)
  b:Hide()
  self.button = b
  return b
end

function M:Refresh()
  local b = self.button
  if not b or not b:IsShown() then return end
  local n = #self:Collectable()
  b.label:SetText(n > 0 and ("Collect (" .. n .. " mail)") or "Nothing to collect")
end

function M:OnEnable()
  self:On("MAIL_SHOW", function(mod) mod.taken = 0 mod:Build():Show() mod:Refresh() end)
  self:On("MAIL_INBOX_UPDATE", function(mod) mod:Refresh() end)
  self:On("MAIL_CLOSED", function(mod)
    if mod.button then mod.button:Hide() end
    if (mod.taken or 0) > 0 then mod:Info("collected %d things from mail", mod.taken) mod.taken = 0 end
  end)
end

function M:OnDisable() if self.button then self.button:Hide() end end

function M:Activity() return "Collect button at the mailbox (one thing per click, COD skipped)" end

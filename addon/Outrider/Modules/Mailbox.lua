-- Modules/Mailbox.lua  (P5-10)
-- A "Collect" button beside the mailbox. Each click takes ONE thing (the
-- money, else the first item) from the first mail that has something, so the
-- client's own throttling is respected and nothing is taken without a click.
-- Cash-on-delivery (COD) mail is never touched. The ledger (P5-08) books the
-- money as "mail".
-- Gap analysis 2026-11-17 (Postal style), still one thing per click:
--   * the button says what's waiting in total (gold and items)
--   * "Send to" buttons: your characters on this realm and faction and the
--     last people you mailed; a click fills the To: box (you still send)
--   * expiring mail: each character's soonest-expiring mail with gold or
--     items is remembered; at login one line names any expiring within 3
--     days, on any of your characters.

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local M = ns:NewModule("Mailbox", {
  title = "Mailbox collect",
  phase = "P5",
  order = 77,
  defaults = { filter = "all", keepFree = 0 },
})
ns.Mailbox = M

M.WARN_DAYS = 3
M.RECENT = 8
M.FILTERS = { "all", "sold", "won", "expired" }

function M:OnInitialize()
  local g = ns.db.global
  g.mailExpiry = type(g.mailExpiry) == "table" and g.mailExpiry or {}
  g.mailRecent = type(g.mailRecent) == "table" and g.mailRecent or {}
  self.expiry, self.recent = g.mailExpiry, g.mailRecent
end

function M.MailKind(sender, subject)
  if type(sender) ~= "string" or type(subject) ~= "string" then return "other" end
  -- Conservative English subject classification; uncertain/localized messages
  -- stay in "all", never silently classified as auction sales.
  local from, title = sender:lower(), subject:lower()
  if not (from:find("auction", 1, true) or title:find("auction", 1, true)) then return "other" end
  if title:find("sold", 1, true) or title:find("successful", 1, true) then return "sold" end
  if title:find("won", 1, true) then return "won" end
  if title:find("expired", 1, true) or title:find("outbid", 1, true) then return "expired" end
  return "other"
end

function M:BagSpaceOK()
  local keep = tonumber(self:Settings().keepFree) or 0
  if keep <= 0 then return true end
  local free = ns.InfoBar and ns.InfoBar.Bags and ns.InfoBar.Bags()
  return type(free) == "number" and free > keep
end

-- Mails with money or items and no COD: { {index, money, items, days, kind} }
function M:Collectable()
  local out = {}
  for i = 1, (C.Call("GetInboxNumItems") or 0) do
    -- 8 return values; C.Call passes only 5, so call directly
    local ok, _, _, sender, subject, money, cod, days, items = pcall(GetInboxHeaderInfo, i)
    if not ok then money, cod, items = 0, 0, 0 end
    money, cod, items = tonumber(C.Readable(money)) or 0, tonumber(C.Readable(cod)) or 0, tonumber(C.Readable(items)) or 0
    local kind = M.MailKind(C.Readable(sender), C.Readable(subject))
    local filter = self:Settings().filter or "all"
    if cod == 0 and (money > 0 or items > 0) and (filter == "all" or filter == kind) then
      out[#out + 1] = { index = i, money = money, items = items, days = tonumber(C.Readable(days)), kind = kind }
    end
  end
  return out
end

-- totals for the button: mails, copper, items
function M:Totals()
  local list, money, items = self:Collectable(), 0, 0
  for _, m in ipairs(list) do money, items = money + m.money, items + m.items end
  return #list, money, items
end

-- remember this character's soonest-expiring mail with something in it
function M:NoteExpiry()
  local soonest, n = nil, 0
  for _, m in ipairs(self:Collectable()) do
    n = n + 1
    if m.days and (not soonest or m.days < soonest) then soonest = m.days end
  end
  self.expiry[ns.db.key] = n > 0 and soonest and { at = time() + soonest * 86400, n = n, t = time() } or nil
end

-- { {char, days} } for every character with mail expiring within WARN_DAYS
function M:Expiring(now)
  now = now or time()
  local out = {}
  for key, e in pairs(self.expiry) do
    local days = (e.at - now) / 86400
    if days <= M.WARN_DAYS then out[#out + 1] = { char = key, days = math.max(0, days), n = e.n } end
  end
  table.sort(out, function(a, b) return a.days < b.days end)
  return out
end

function M:WarnExpiring()
  local list = self:Expiring()
  if #list == 0 then return end
  local parts = {}
  for i, x in ipairs(list) do
    if i > 3 then break end
    parts[#parts + 1] = string.format("%s (%s)", x.char:match("^[^-]+") or x.char,
      x.days < 1 and "today" or (math.floor(x.days + 0.5) .. " days"))
  end
  ns.Print("mail with gold or items expires soon: %s. Collect it or it goes back.", table.concat(parts, ", "))
end

-- ------------------------------------------------------------------ send to
-- your characters on this realm and faction, then recent recipients
function M:Contacts()
  local me = ns.db.key
  local realm = me:match("%-(.+)$")
  local faction = C.Call("UnitFactionGroup", "player")
  local out, seen = {}, { [me:match("^[^-]+")] = true }
  local alts = ns.db.global.alts or {}
  for key in pairs(ns.db.raw.chars or {}) do
    local name, r = key:match("^([^-]+)%-(.+)$")
    local a = alts[key]
    if name and r == realm and not seen[name] and (not a or not a.faction or a.faction == faction) then
      seen[name] = true
      out[#out + 1] = { name = name, alt = true }
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  for _, name in ipairs(self.recent) do
    if not seen[name] then seen[name] = true out[#out + 1] = { name = name } end
  end
  return out
end

function M:Remember(name)
  if type(name) ~= "string" or name == "" then return end
  for i = #self.recent, 1, -1 do if self.recent[i] == name then table.remove(self.recent, i) end end
  table.insert(self.recent, 1, name)
  for i = M.RECENT + 1, #self.recent do self.recent[i] = nil end
end

function M:FillTo(name)
  local box = rawget(_G, "SendMailNameEditBox")
  if not box then return false end
  local frame = rawget(_G, "SendMailFrame")
  if frame and not frame:IsShown() then
    local tab = rawget(_G, "MailFrameTab_OnClick")
    if type(tab) == "function" then pcall(tab, nil, 2) end
  end
  box:SetText(name)
  if box.SetFocus then pcall(box.SetFocus, box) end
  return true
end

function M:BuildSendTo()
  if self.sendTo then return self.sendTo end
  local anchor = self.button or self:Build()
  local f = CreateFrame("Frame", nil, anchor:GetParent())
  f:SetSize(150, 10)
  f:SetPoint("TOPLEFT", self.filterButton or anchor, "BOTTOMLEFT", 0, -10)
  f.head = UI.Text(f, "small", "muted")
  f.head:SetPoint("TOPLEFT", 0, 0)
  f.head:SetText("Send to")
  f.buttons = {}
  self.sendTo = f
  return f
end

function M:RefreshSendTo()
  local f = self:BuildSendTo()
  local list = self:Contacts()
  for i, c in ipairs(list) do
    if i > 12 then break end
    local b = f.buttons[i]
    if not b then
      b = UI:Button(f, "", 150, function(self) M:FillTo(self.who) end)
      b:SetHeight(20)
      f.buttons[i] = b
    end
    b.who = c.name
    b.label:SetText(c.name .. (c.alt and "" or "  |cff888888(recent)|r"))
    UI.Tip(b, c.name, "Puts " .. c.name .. " in the To: box. You add what to send and press Send.")
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -14 - (i - 1) * 22)
    b:Show()
  end
  for i = math.min(#list, 12) + 1, #f.buttons do f.buttons[i]:Hide() end
  f:SetShown(#list > 0)
end

function M:CollectOne(preferItem)
  if C.InCombat() then return nil end
  local mail = self:Collectable()[1]
  if not mail then return nil end
  if preferItem and mail.items > 0 and self:BagSpaceOK() then
    for a = 1, (rawget(_G, "ATTACHMENTS_MAX_RECEIVE") or 16) do
      if C.Call("GetInboxItemLink", mail.index, a) then
        if pcall(TakeInboxItem, mail.index, a) then return "item" end
        return nil
      end
    end
  end
  if mail.money > 0 then
    if pcall(TakeInboxMoney, mail.index) then
      self:Debug("took %s from mail %d", ns.Prices.Money(mail.money), mail.index)
      return "money"
    end
    return nil
  end
  if not self:BagSpaceOK() then return nil end
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
    local got = M:CollectOne(C.Call("IsShiftKeyDown"))
    if got then M.taken = (M.taken or 0) + 1 end
    ns.Timer.After(0.4, function() M:Refresh() end, "mail:refresh")
  end)
  b:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 6, -30)
  b:Hide()
  self.button = b
  local filter = UI:Button(anchor, "All mail", 150, function()
    local s = M:Settings()
    local pos = 1
    for i, value in ipairs(M.FILTERS) do if value == s.filter then pos = i break end end
    s.filter = M.FILTERS[pos % #M.FILTERS + 1]
    M:Refresh()
  end)
  filter:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -4)
  filter:Hide()
  self.filterButton = filter
  return b
end

function M:Refresh()
  local b = self.button
  if not b or not b:IsShown() then return end
  local n, money, items = self:Totals()
  local what = {}
  if money > 0 then what[#what + 1] = ns.Prices.Money(money) end
  if items > 0 then what[#what + 1] = items .. (items == 1 and " item" or " items") end
  b.label:SetText(n > 0 and ("Collect (" .. n .. " mail: " .. table.concat(what, ", ") .. ")") or "Nothing to collect")
  UI.Tip(b, "Collect", "Each click takes one thing: the gold, else one item, from the first mail. Waiting: " ..
    (n > 0 and table.concat(what, " and ") or "nothing") .. ". Cash-on-delivery mail is never touched.")
  if self.filterButton then
    self.filterButton.label:SetText("Mail: " .. (self:Settings().filter or "all"))
  end
  self:NoteExpiry()
end

function M:OnEnable()
  self:On("MAIL_SHOW", function(mod) mod.taken = 0 mod:Build():Show() if mod.filterButton then mod.filterButton:Show() end mod:Refresh() mod:RefreshSendTo() end)
  self:On("PLAYER_ENTERING_WORLD", function(mod, _, isLogin) if isLogin then mod:WarnExpiring() end end)
  if not self.sendHooked and type(rawget(_G, "SendMail")) == "function" then
    hooksecurefunc("SendMail", function(to) if M.enabled then ns.Safe("mail:remember", M.Remember, M, to) end end)
    self.sendHooked = true
  end
  self:On("MAIL_INBOX_UPDATE", function(mod) mod:Refresh() end)
  self:On("MAIL_CLOSED", function(mod)
    if mod.button then mod.button:Hide() end
    if mod.filterButton then mod.filterButton:Hide() end
    if mod.sendTo then mod.sendTo:Hide() end
    if (mod.taken or 0) > 0 then mod:Info("collected %d things from mail", mod.taken) mod.taken = 0 end
  end)
end

function M:OnDisable()
  if self.button then self.button:Hide() end
  if self.filterButton then self.filterButton:Hide() end
  if self.sendTo then self.sendTo:Hide() end
end

function M:Activity() return "Collect button at the mailbox (one thing per click, COD skipped)" end

ns.AddCommand("mail", "mail all|sold|won|expired | free <slots>", function(arg)
  local s = M:Settings()
  arg = tostring(arg or "")
  local n = tonumber(arg:match("^free%s+(%d+)$"))
  if n and n >= 0 and n <= 100 then
    s.keepFree = math.floor(n)
    ns.Print("mail: reserve %d free bag slots before taking attachments", s.keepFree)
  else
    local valid
    for _, v in ipairs(M.FILTERS) do if arg == v then valid = true break end end
    if valid then s.filter = arg
    else ns.Print("usage: /ride mail all|sold|won|expired | free <slots>") return end
    ns.Print("mail filter: %s", s.filter)
  end
  M:Refresh()
end)

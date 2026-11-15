-- UI/Widgets.lua
-- Small widget kit so every Outrider window looks and behaves the same.
-- Non-secure only: secure action buttons (cast/target/use) live with the
-- module that needs them and are created out of combat via Module:Secure.

local _, ns = ...
local UI = { name = "ui" }
ns.UI = UI
local Theme = ns.Theme

local function text(parent, size, colorName, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  Theme:StyleText(fs, size, colorName)
  return fs
end
UI.Text = text

-- Movable window with title bar and close button. pos = table to persist
-- { point, x, y } (usually a per-character settings table).
function UI:Window(globalName, title, width, height, pos)
  local f = CreateFrame("Frame", globalName, UIParent, Theme:BackdropTemplate())
  f:SetSize(width, height)
  if Theme.uiScale and Theme.uiScale ~= 1 then f:SetScale(Theme.uiScale) end
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  Theme:ApplyPanel(f, "bg")

  local bar = CreateFrame("Frame", nil, f, Theme:BackdropTemplate())
  bar:SetPoint("TOPLEFT", 1, -1)
  bar:SetPoint("TOPRIGHT", -1, -1)
  bar:SetHeight(26)
  Theme:ApplyPanel(bar, "panel")
  f.bar = bar

  f.title = text(bar, "large", "text")
  f.title:SetPoint("LEFT", 10, 0)
  f.title:SetText(title)

  local close = CreateFrame("Button", nil, bar)
  close:SetSize(22, 22)
  close:SetPoint("RIGHT", -3, 0)
  close.label = text(close, "large", "muted")
  close.label:SetPoint("CENTER")
  close.label:SetText("x")
  close:SetScript("OnClick", function() f:Hide() end)
  close:SetScript("OnEnter", function() close.label:SetTextColor(Theme:Color("bad")) end)
  close:SetScript("OnLeave", function() close.label:SetTextColor(Theme:Color("muted")) end)
  f.close = close

  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if pos then
      local point, _, _, x, y = self:GetPoint(1)
      pos.point, pos.x, pos.y = point, math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5)
    end
  end)
  f:ClearAllPoints()
  if pos and pos.point then f:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
  else f:SetPoint("CENTER") end

  -- Escape closes it (only works for named frames)
  if globalName and type(rawget(_G, "UISpecialFrames")) == "table" then
    table.insert(UISpecialFrames, globalName)
  end

  f.content = CreateFrame("Frame", nil, f)
  f.content:SetPoint("TOPLEFT", 10, -36)
  f.content:SetPoint("BOTTOMRIGHT", -10, 10)
  f:Hide()
  return f
end

function UI:Button(parent, label, width, onClick)
  local b = CreateFrame("Button", nil, parent, Theme:BackdropTemplate())
  b:SetSize(width or 110, 24)
  Theme:ApplyPanel(b, "raised", "strong")
  b.label = text(b, "normal", "text")
  b.label:SetPoint("CENTER")
  b.label:SetText(label)
  b.rest = "strong"
  b:SetScript("OnEnter", function(self) if self.SetBackdropBorderColor then self:SetBackdropBorderColor(Theme:Color("accent")) end end)
  b:SetScript("OnLeave", function(self) if self.SetBackdropBorderColor then self:SetBackdropBorderColor(Theme:Color(self.rest or "strong")) end end)
  b:SetScript("OnClick", function(self, button) if onClick then ns.Safe("button:" .. label, onClick, self, button) end end)
  return b
end

-- The one main action on a page: gold fill, dark label.
function UI:PrimaryButton(parent, label, width, onClick)
  local b = self:Button(parent, label, width, onClick)
  UI.SetPrimary(b, true)
  return b
end

function UI.SetPrimary(b, on)
  b.rest = on and "gold" or "strong"
  Theme:ApplyPanel(b, on and "gold" or "raised", b.rest)
  b.label:SetTextColor(Theme:Color(on and "onGold" or "text"))
end

-- A card: raised panel with a hairline border; edge = true adds a 3px gold
-- strip on the left (the top step on a page).
function UI:Card(parent, edge)
  local c = CreateFrame("Frame", nil, parent, Theme:BackdropTemplate())
  Theme:ApplyPanel(c, "raised", "border")
  c.edge = c:CreateTexture(nil, "ARTWORK")
  c.edge:SetPoint("TOPLEFT", 0, 0)
  c.edge:SetPoint("BOTTOMLEFT", 0, 0)
  c.edge:SetWidth(3)
  c.edge:SetColorTexture(Theme:Color("gold"))
  c.edge:SetShown(edge and true or false)
  function c:SetEdge(on) self.edge:SetShown(on and true or false) end
  return c
end

-- A chip: small rounded-looking toggle (goal pickers, filters). SetOn(bool)
-- shows it selected (gold border, soft gold fill).
function UI:Chip(parent, label, onClick)
  local b = CreateFrame("Button", nil, parent, Theme:BackdropTemplate())
  b.label = text(b, "small", "body")
  b.label:SetPoint("CENTER")
  b.label:SetText(label)
  b:SetSize(math.max(54, (b.label:GetStringWidth() or (#label * 6)) + 22), 22)
  function b:SetOn(on)
    self.on = on and true or false
    Theme:ApplyPanel(self, self.on and "goldSoft" or "bg", self.on and "gold" or "strong")
    self.label:SetTextColor(Theme:Color(self.on and "goldText" or "body"))
  end
  b:SetScript("OnEnter", function(self) if not self.on and self.SetBackdropBorderColor then self:SetBackdropBorderColor(Theme:Color("muted")) end end)
  b:SetScript("OnLeave", function(self) self:SetOn(self.on) end)
  b:SetScript("OnClick", function(self, button) if onClick then ns.Safe("chip:" .. label, onClick, self, button) end end)
  b:SetOn(false)
  return b
end

-- A small tag ("unchecked", "guess"): amber text in an amber hairline box.
function UI:Tag(parent, label)
  local t = CreateFrame("Frame", nil, parent, Theme:BackdropTemplate())
  Theme:ApplyPanel(t, "goldSoft", "warn")
  t.label = text(t, "small", "warn")
  t.label:SetPoint("CENTER")
  function t:SetLabel(s)
    self.label:SetText(s)
    self:SetSize(math.max(30, (self.label:GetStringWidth() or (#s * 6)) + 10), 16)
  end
  t:SetLabel(label or "")
  return t
end

-- Checkbox row: get() returns bool, set(bool) saves it.
function UI:Check(parent, label, get, set)
  local row = CreateFrame("Button", nil, parent)
  row:SetSize(300, 22)
  local box = CreateFrame("Frame", nil, row, Theme:BackdropTemplate())
  row.box = box
  box:SetSize(14, 14)
  box:SetPoint("LEFT", 2, 0)
  Theme:ApplyPanel(box, "raised")
  local mark = box:CreateTexture(nil, "OVERLAY")
  mark:SetPoint("TOPLEFT", 3, -3)
  mark:SetPoint("BOTTOMRIGHT", -3, 3)
  mark:SetColorTexture(Theme:Color("accent"))
  row.label = text(row, "normal", "text")
  row.label:SetPoint("LEFT", box, "RIGHT", 8, 0)
  row.label:SetText(label)
  row.note = text(row, "small", "muted")
  row.note:SetPoint("LEFT", row.label, "RIGHT", 8, 0)
  function row:Refresh() mark:SetShown(get() and true or false) end
  row:SetScript("OnClick", function()
    ns.Safe("check:" .. label, set, not get())
    row:Refresh()
  end)
  row:Refresh()
  return row
end

-- Dialog with a multi-line edit box. mode "copy" selects the text for Ctrl+C,
-- mode "paste" shows an Accept button that calls onAccept(text).
function UI:TextDialog(title, body, mode, onAccept)
  local d = self.dialog
  if not d then
    d = self:Window("Outrider_TextDialog", title, 520, 300)
    local scroll = CreateFrame("ScrollFrame", nil, d.content, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -24, 34)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(true)
    edit:SetFontObject("ChatFontNormal")
    edit:SetWidth(470)
    edit:SetScript("OnEscapePressed", function() d:Hide() end)
    scroll:SetScrollChild(edit)
    d.edit = edit
    d.accept = self:Button(d.content, "Accept", 110)
    d.accept:SetPoint("BOTTOMRIGHT", 0, 0)
    d.hint = text(d.content, "small", "muted")
    d.hint:SetPoint("BOTTOMLEFT", 0, 6)
    self.dialog = d
  end
  d.title:SetText(title)
  d.edit:SetText(body or "")
  if mode == "copy" then
    d.hint:SetText("Press Ctrl+C to copy, Esc to close.")
    d.accept:Hide()
    d.edit:HighlightText()
  else
    d.hint:SetText("Paste with Ctrl+V, then Accept.")
    d.accept:Show()
    d.accept:SetScript("OnClick", function()
      local ran, ok, err = ns.Safe("dialog:" .. title, onAccept, d.edit:GetText())
      if ran and ok then d:Hide() else d.hint:SetText("|cffff6060" .. tostring(err or "failed") .. "|r") end
    end)
  end
  d:Show()
  return d
end

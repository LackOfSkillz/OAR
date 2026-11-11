-- UI/Toast.lua
-- Small notification cards: ns.Toast:Show({ title, text, icon, color, sound,
-- duration, button = { label, macro } }). Up to 3 stacked under one anchor
-- (top-center by default); a 4th pushes out the oldest. Dragging any toast
-- moves the anchor, saved per character.
-- The optional button is a pooled secure button (UI/SecureButtons). It is
-- parented to UIParent, not to the toast: an insecure frame with a secure
-- child becomes protected in combat and could no longer be hidden.

local _, ns = ...
local Toast = { name = "toast", visible = {}, pool = {}, MAX = 3, W = 290, H = 56, GAP = 6 }
ns.Toast = Toast

local L = {
  testTitle = "Outrider test toast",
  testText = "Drag me to move all toasts. /reload keeps the spot.",
  combatNote = "(button works after combat)",
}

local function settings()
  local c = ns.db.char
  c.toast = type(c.toast) == "table" and c.toast or {}
  ns.ApplyDefaults(c.toast, { point = "TOP", x = 0, y = -140 })
  return c.toast
end

function Toast:Anchor()
  local a = self.anchor
  if a then return a end
  a = CreateFrame("Frame", "Outrider_ToastAnchor", UIParent)
  a:SetSize(self.W, self.H)
  a:SetMovable(true)
  a:SetClampedToScreen(true)
  local s = settings()
  a:SetPoint(s.point, UIParent, s.point, s.x, s.y)
  self.anchor = a
  return a
end

function Toast:SaveAnchor()
  local point, _, _, x, y = self.anchor:GetPoint(1)
  local s = settings()
  s.point, s.x, s.y = point or "TOP", math.floor((x or 0) + 0.5), math.floor((y or -140) + 0.5)
  ns.Log:Info("toast", "anchor saved %s %d %d", s.point, s.x, s.y)
end

local function build(self)
  local Theme = ns.Theme
  local f = CreateFrame("Button", nil, UIParent, Theme:BackdropTemplate())
  f:SetSize(self.W, self.H)
  f:SetFrameStrata("HIGH")
  Theme:ApplyPanel(f, "panel")
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(40, 40)
  f.icon:SetPoint("LEFT", 8, 0)
  f.title = ns.UI.Text(f, "large", "text")
  f.title:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 8, -2)
  f.title:SetPoint("RIGHT", -8, 0)
  f.title:SetJustifyH("LEFT")
  f.text = ns.UI.Text(f, "small", "muted")
  f.text:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
  f.text:SetPoint("RIGHT", -8, 0)
  f.text:SetJustifyH("LEFT")
  f:SetScript("OnDragStart", function() Toast:Anchor():StartMoving() end)
  f:SetScript("OnDragStop", function()
    Toast:Anchor():StopMovingOrSizing()
    Toast:SaveAnchor()
  end)
  f:SetScript("OnClick", function(_, button) if button == "RightButton" then Toast:Dismiss(f) end end)
  f:RegisterForClicks("AnyUp")
  f:Hide()
  return f
end

function Toast:Layout()
  local a = self:Anchor()
  for i, f in ipairs(self.visible) do
    f:ClearAllPoints()
    f:SetPoint("TOP", a, "TOP", 0, -(i - 1) * (self.H + self.GAP))
    if f.secure then
      ns.SecureButtons:Place(f.secure, "RIGHT", f, "RIGHT", -8, 0)
    end
  end
end

local function playSound(id)
  if not id then return end
  ns.Compat.Call("PlaySound", id, "Master")
end

function Toast:SoundID(name)
  local kit = rawget(_G, "SOUNDKIT")
  if type(kit) == "table" and kit[name] then return kit[name] end
  -- Fallbacks are the client's own SOUNDKIT constants, used if the table is missing.
  local known = { RAID_WARNING = 8959, READY_CHECK = 8960 }
  return known[name]
end

function Toast:Show(opts)
  opts = opts or {}
  while #self.visible >= self.MAX do self:Dismiss(self.visible[1]) end
  local f = table.remove(self.pool) or build(self)
  f.title:SetText(opts.title or "")
  local body = opts.text or ""
  f.icon:SetTexture(opts.icon or "Interface\\Icons\\INV_Misc_Map_01")
  if opts.color and f.SetBackdropBorderColor then
    f:SetBackdropBorderColor(ns.Theme:Color(opts.color))
  elseif f.SetBackdropBorderColor then
    f:SetBackdropBorderColor(ns.Theme:Color("border"))
  end
  f:SetAlpha(1)
  f.opts = opts
  if opts.button and opts.button.macro then
    local b = ns.SecureButtons:Acquire("toast")
    if b then
      f.secure = b
      ns.SecureButtons:SetMacro(b, opts.button.macro)
      ns.SecureButtons:SetLabel(b, opts.button.label or "Go")
      ns.SecureButtons:SetShown(b, true)
      if ns.Compat.InCombat() then body = body .. " " .. L.combatNote end
    end
  end
  f.text:SetText(body)
  self.visible[#self.visible + 1] = f
  self:Layout()
  f:Show()
  playSound(opts.sound)
  f.timer = ns.Timer.After(opts.duration or 8, function() Toast:Fade(f) end, "toast:expire")
  ns.Log:Debug("toast", "show %s", tostring(opts.title))
  return f
end

-- Half-second fade, then dismiss. Hovering the toast stops the fade.
function Toast:Fade(f)
  if f:IsMouseOver() then
    f.timer = ns.Timer.After(2, function() Toast:Fade(f) end, "toast:expire")
    return
  end
  local alpha = 1
  f.timer = ns.Timer.Ticker(0.05, function(h)
    alpha = alpha - 0.1
    if alpha <= 0 then h:Cancel() Toast:Dismiss(f) else f:SetAlpha(alpha) end
  end, "toast:fade")
end

function Toast:Dismiss(f)
  for i, v in ipairs(self.visible) do
    if v == f then table.remove(self.visible, i) break end
  end
  if f.timer then f.timer:Cancel() f.timer = nil end
  if f.secure then ns.SecureButtons:Release(f.secure) f.secure = nil end
  f:Hide()
  f.opts = nil
  self.pool[#self.pool + 1] = f
  self:Layout()
end

function Toast:Count() return #self.visible end

function Toast:SelfTest()
  self:Show({
    title = L.testTitle, text = L.testText, sound = self:SoundID("RAID_WARNING"), duration = 15,
    button = { label = "Wave", macro = "/wave" },
  })
  ns.Log:Info("selftest", "toast shown")
end

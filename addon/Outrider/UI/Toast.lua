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
  Theme:ApplyPanel(f, "raised")
  -- Expedition look: a 3px edge in the toast's colour on the left
  f.edge = f:CreateTexture(nil, "ARTWORK")
  f.edge:SetPoint("TOPLEFT", 0, 0)
  f.edge:SetPoint("BOTTOMLEFT", 0, 0)
  f.edge:SetWidth(3)
  f.edge:SetColorTexture(Theme:Color("gold"))
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(40, 40)
  f.icon:SetPoint("LEFT", 8, 0)
  -- the creature itself, as a small 3D portrait, when the toast is about one
  -- (gallery idea from RareScanner, 2026-11-18). Fails soft to the icon.
  local okModel, model = pcall(CreateFrame, "PlayerModel", nil, f)
  if okModel and model then
    model:SetSize(44, 44)
    model:SetPoint("CENTER", f.icon, "CENTER", 0, 0)
    model:Hide()
    f.model = model
  end
  f.title = ns.UI.Display(f, "side", "text")
  f.title:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 8, -2)
  f.title:SetPoint("RIGHT", -8, 0)
  f.title:SetJustifyH("LEFT")
  f.text = ns.UI.Text(f, "small", "muted")
  f.text:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
  f.text:SetPoint("RIGHT", -8, 0)
  f.text:SetJustifyH("LEFT")
  f:SetScript("OnDragStart", function()
    if ns.Compat.InCombat() and Toast:HasSecure() then return end
    Toast:HideButtons()
    Toast:Anchor():StartMoving()
  end)
  f:SetScript("OnDragStop", function()
    Toast:Anchor():StopMovingOrSizing()
    Toast:SaveAnchor()
    Toast:Layout()
  end)
  f:SetScript("OnClick", function(_, button) if button == "RightButton" then Toast:Dismiss(f) end end)
  f:RegisterForClicks("AnyUp")
  f:Hide()
  return f
end

-- Secure buttons are NEVER anchored to a toast. A frame that a secure frame
-- is anchored to counts as protected, and moving it (dragging the toasts)
-- made Blizzard block Outrider on 2026-11-11. Buttons are placed against
-- UIParent at the toast's screen position, out of combat, after each layout.
function Toast:HideButtons()
  for _, f in ipairs(self.visible) do
    if f.secure then ns.SecureButtons:SetShown(f.secure, false) end
  end
end

function Toast:PlaceButton(f)
  local cx, cy = f:GetCenter()
  if not cx then
    -- not drawn yet: try again next frame
    ns.Timer.After(0, function() if f.secure then Toast:PlaceButton(f) end end, "toast:place")
    return
  end
  local right = cx + (f:GetWidth() or self.W) / 2 - 8
  ns.SecureButtons:Place(f.secure, "RIGHT", UIParent, "BOTTOMLEFT", right, cy)
  ns.SecureButtons:SetShown(f.secure, true)
end

-- Moving toasts that carry buttons waits until combat ends (their buttons
-- can't follow during combat).
function Toast:HasSecure()
  for _, f in ipairs(self.visible) do if f.secure then return true end end
  return false
end

function Toast:Layout()
  if ns.Compat.InCombat() and self:HasSecure() then
    ns.Combat:Run("toast:layout", function() Toast:Layout() end, "toast:layout")
    return
  end
  local a = self:Anchor()
  for i, f in ipairs(self.visible) do
    f:ClearAllPoints()
    f:SetPoint("TOP", a, "TOP", 0, -(i - 1) * (self.H + self.GAP))
    if f.secure then self:PlaceButton(f) end
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
  if ns.Events and not opts.noFeed then ns.Events:Fire("OTR_TOAST", opts) end
  while #self.visible >= self.MAX do self:Dismiss(self.visible[1]) end
  local f = table.remove(self.pool) or build(self)
  f.title:SetText(opts.title or "")
  local body = opts.text or ""
  f.icon:SetTexture(opts.icon or "Interface\\Icons\\INV_Misc_Map_01")
  f.icon:Show()
  if f.model then
    f.model:Hide()
    local shown = false
    if opts.creature and f.model.SetCreature then
      shown = pcall(f.model.SetCreature, f.model, opts.creature)
    elseif opts.unit and f.model.SetUnit then
      shown = pcall(f.model.SetUnit, f.model, opts.unit)
    end
    if shown then
      if f.model.SetPortraitZoom then pcall(f.model.SetPortraitZoom, f.model, 0.85) end
      f.model:Show()
      f.icon:Hide()
    end
  end
  if opts.color and f.SetBackdropBorderColor then
    f:SetBackdropBorderColor(ns.Theme:Color(opts.color))
  elseif f.SetBackdropBorderColor then
    f:SetBackdropBorderColor(ns.Theme:Color("border"))
  end
  if f.edge then f.edge:SetColorTexture(ns.Theme:Color(opts.color or "gold")) end
  f:SetAlpha(1)
  if ns.Theme.uiScale and ns.Theme.uiScale ~= 1 then f:SetScale(ns.Theme.uiScale) end
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
  -- A plain (insecure) button that runs Lua on Gary's click, e.g. "Fix".
  -- It is a child of the toast; only secure buttons must stay detached.
  if not f.action then
    f.action = ns.UI:Button(f, "", 70)
    f.action:SetHeight(20)
    f.action:SetPoint("BOTTOMRIGHT", -8, 6)
  end
  if opts.action and opts.action.fn then
    f.action.label:SetText(opts.action.label or "OK")
    f.action:SetScript("OnClick", function()
      ns.Safe("toast:action", opts.action.fn)
      Toast:Dismiss(f)
    end)
    f.action:Show()
  else
    f.action:Hide()
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
  if ns.Theme.reducedMotion then Toast:Dismiss(f) return end
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

-- ------------------------------------------------------------ unlock mode
-- (FojjiCore idea, 2026-11-23) /ride unlock shows every Outrider piece that
-- can be moved, hidden or not, with a gold "drag me" outline: the pop-up
-- spot (a sample pop-up), the fishing panel, the info bar, the quest tracker
-- and the heal bars. Drag them where you want; /ride lock puts back what was
-- hidden. Out of combat only (the heal bars and fishing button are secure).
ns.Unlock = { FRAMES = { "Outrider_FishingHUD", "Outrider_InfoBar", "Outrider_QuestTracker", "Outrider_HealPanel" }, on = false, was = {} }
local U = ns.Unlock

local function mark(f, label, on)
  if not f.otrUnlock then
    local o = f:CreateTexture(nil, "OVERLAY")
    o:SetAllPoints()
    o:SetColorTexture(1, 0.82, 0.25, 0.22)
    local t = f:CreateFontString(nil, "OVERLAY")
    t:SetFont(ns.Theme.font.path, 12, "OUTLINE")
    t:SetPoint("CENTER")
    t:SetTextColor(1, 0.85, 0.3)
    f.otrUnlock = { o, t }
  end
  f.otrUnlock[2]:SetText(label .. ": drag me")
  for _, r in ipairs(f.otrUnlock) do r:SetShown(on) end
end

function U:Set(on)
  if ns.Compat.InCombat() then ns.Print("unlock: not in combat") return false end
  if on == self.on then return true end
  self.on = on
  local n = 0
  for _, name in ipairs(self.FRAMES) do
    local f = rawget(_G, name)
    if f then
      if on then
        self.was[name] = f:IsShown()
        f:Show()
        if f.SetMovable then f:SetMovable(true) end
        mark(f, (name:gsub("^Outrider_", "")), true)
        n = n + 1
      else
        mark(f, "", false)
        if self.was[name] == false then f:Hide() end
      end
    end
  end
  if on then
    self.sample = Toast:Show({ title = "Outrider pop-ups show here", text = "Drag this pop-up to move them all. /ride lock when done.", duration = 600 })
  elseif self.sample then
    Toast:Fade(self.sample)
    self.sample = nil
  end
  ns.Print(on and "unlocked: %d pieces and the pop-up spot show; drag them, then /ride lock" or "locked", n)
  return true
end

ns.AddCommand("unlock", "show every Outrider piece you can move, to drag it", function() U:Set(true) end)
ns.AddCommand("lock", "hide the move outlines again", function() U:Set(false) end)

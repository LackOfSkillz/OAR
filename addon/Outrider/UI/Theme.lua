-- UI/Theme.lua
-- Design tokens for every Outrider window: flat dark panels, 1px borders, one
-- accent color. Change the look here, never per window. Phase 7 extends this
-- into skins for Blizzard frames.

local _, ns = ...
local Theme = { name = "theme" }
ns.Theme = Theme

Theme.colors = {
  bg      = { 0.06, 0.07, 0.09, 0.94 },
  panel   = { 0.10, 0.11, 0.14, 0.96 },
  raised  = { 0.14, 0.15, 0.19, 1.00 },
  border  = { 0.22, 0.24, 0.30, 1.00 },
  text    = { 0.92, 0.93, 0.95, 1.00 },
  muted   = { 0.62, 0.65, 0.72, 1.00 },
  accent  = { 0.56, 0.82, 1.00, 1.00 },
  good    = { 0.40, 0.85, 0.50, 1.00 },
  warn    = { 1.00, 0.78, 0.30, 1.00 },
  bad     = { 1.00, 0.38, 0.38, 1.00 },
}

Theme.font = {
  path = "Fonts\\FRIZQT__.TTF",
  small = 11, normal = 12, large = 14, title = 16,
}

Theme.space = { xs = 4, sm = 8, md = 12, lg = 16 }

Theme.BACKDROP = {
  bgFile = "Interface\\Buttons\\WHITE8x8",
  edgeFile = "Interface\\Buttons\\WHITE8x8",
  edgeSize = 1,
  insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

function Theme:Color(name)
  local c = self.colors[name] or self.colors.text
  return c[1], c[2], c[3], c[4]
end

function Theme:Hex(name)
  local r, g, b = self:Color(name)
  return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

-- Use the player's class color as accent when the setting is on.
function Theme:UseClassAccent()
  local colors = rawget(_G, "RAID_CLASS_COLORS")
  local c = colors and colors[ns.PlayerClass()]
  if c then self.colors.accent = { c.r, c.g, c.b, 1 } end
end

-- Template name for frames that need a backdrop on modern clients.
function Theme:BackdropTemplate()
  return rawget(_G, "BackdropTemplateMixin") and "BackdropTemplate" or nil
end

function Theme:ApplyPanel(frame, colorName)
  if not frame.SetBackdrop then return end
  frame:SetBackdrop(self.BACKDROP)
  frame:SetBackdropColor(self:Color(colorName or "panel"))
  frame:SetBackdropBorderColor(self:Color("border"))
end

function Theme:StyleText(fs, size, colorName)
  if not fs then return end
  fs:SetFont(self.font.path, self.font[size or "normal"] or self.font.normal, "")
  fs:SetTextColor(self:Color(colorName or "text"))
end

-- LibSharedMedia (D15): when another addon has loaded it, offer Outrider's
-- flat bar and 1px border so other addons can pick the same look. Nothing
-- happens without it. Called from Boot.
function Theme:RegisterMedia()
  if self.mediaRegistered then return true end
  local LibStub = rawget(_G, "LibStub")
  if type(LibStub) ~= "table" and type(LibStub) ~= "function" then return false end
  local ok, LSM = pcall(LibStub, "LibSharedMedia-3.0", true)
  if not ok or type(LSM) ~= "table" or type(LSM.Register) ~= "function" then return false end
  pcall(LSM.Register, LSM, "statusbar", "Outrider Flat", "Interface\Buttons\WHITE8x8")
  pcall(LSM.Register, LSM, "border", "Outrider 1px", "Interface\Buttons\WHITE8x8")
  self.mediaRegistered = true
  return true
end

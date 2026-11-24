-- UI/Theme.lua
-- Design tokens for every Outrider window: flat dark panels, 1px borders, one
-- accent color. Change the look here, never per window. Phase 7 extends this
-- into skins for Blizzard frames.

local _, ns = ...
local Theme = { name = "theme" }
ns.Theme = Theme

-- Expedition look (mockup chosen 2026-11-15): near-black window, a
-- darker sidebar, cards one step up, hairline borders. `accent` is the class
-- colour when that setting is on (owner request 2026-11-13); `gold` marks what is
-- selected or the main action on a page, whatever the class.
Theme.colors = {
  bg      = { 0.059, 0.067, 0.086, 1.00 },  -- solid: nothing behind shows through
  panel   = { 0.043, 0.051, 0.067, 0.98 },  -- sidebar, title bar
  raised  = { 0.086, 0.102, 0.133, 1.00 },  -- cards, buttons
  hover   = { 0.110, 0.137, 0.188, 1.00 },  -- selected sidebar row, hovered card
  border  = { 0.149, 0.169, 0.212, 1.00 },
  strong  = { 0.227, 0.255, 0.314, 1.00 },  -- button borders
  text    = { 0.910, 0.918, 0.937, 1.00 },
  body    = { 0.765, 0.784, 0.824, 1.00 },  -- card body text
  muted   = { 0.561, 0.588, 0.651, 1.00 },
  accent  = { 0.56, 0.82, 1.00, 1.00 },
  gold    = { 0.831, 0.659, 0.290, 1.00 },
  goldSoft = { 0.165, 0.141, 0.078, 1.00 },
  goldText = { 0.945, 0.835, 0.557, 1.00 },
  onGold  = { 0.110, 0.078, 0.020, 1.00 },
  good    = { 0.40, 0.85, 0.50, 1.00 },
  warn    = { 1.00, 0.78, 0.30, 1.00 },
  bad     = { 1.00, 0.38, 0.38, 1.00 },
}

Theme.font = {
  path = "Fonts\\FRIZQT__.TTF",
  small = 11, normal = 12, large = 14, title = 16, heading = 18,
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

function Theme:ApplyPanel(frame, colorName, borderName)
  if not frame.SetBackdrop then return end
  frame:SetBackdrop(self.BACKDROP)
  frame:SetBackdropColor(self:Color(colorName or "panel"))
  frame:SetBackdropBorderColor(self:Color(borderName or "border"))
end

-- Display type for page and card titles: the game's own fantasy serif
-- (Morpheus). If the client lacks it, SetFont fails and the normal font stays.
Theme.display = { path = "Fonts\\MORPHEUS.TTF", page = 26, card = 17, brand = 20, side = 15 }
-- Premium plan S2 (2026-11-18): Morpheus only for the big page and brand
-- titles; its lowercase reads poorly at card size, so card titles use the
-- clean font, a step larger, with a hair of letter weight.
Theme.cardTitle = 15
function Theme:StyleDisplay(fs, size, colorName)
  if not fs then return end
  if (size or "card") == "card" then
    fs:SetFont(self.font.path, self.cardTitle, "")
    fs:SetTextColor(self:Color(colorName or "text"))
    if fs.SetShadowOffset then fs:SetShadowOffset(1, -1) end
    return
  end
  local px = self.display[size or "card"] or size or self.display.card
  local ok = fs:SetFont(self.display.path, px, "")
  if ok == false then
    fs:SetFont(self.font.path, math.max(self.font.large, px - 4), "")
  end
  fs:SetTextColor(self:Color(colorName or "text"))
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
  pcall(LSM.Register, LSM, "statusbar", "Outrider Flat", "Interface\\Buttons\\WHITE8x8")
  pcall(LSM.Register, LSM, "border", "Outrider 1px", "Interface\\Buttons\\WHITE8x8")
  self.mediaRegistered = true
  return true
end

-- P7-12 accessibility (per character, ns.db.char.access; applied at login):
--   fontScale     0.8 .. 1.5  multiplies every Outrider font size
--   uiScale       0.7 .. 1.5  scale of Outrider windows and toasts
--   colorblind    good/bad become blue/orange instead of green/red
--   highContrast  opaque panels, bright borders and text
--   reducedMotion toasts disappear without fading
Theme.ACCESS_DEFAULTS = { fontScale = 1, uiScale = 1, colorblind = false, highContrast = false, reducedMotion = false }

function Theme:Access()
  local c = ns.db and ns.db.char
  if not c then return self.ACCESS_DEFAULTS end
  c.access = type(c.access) == "table" and c.access or {}
  for k, v in pairs(self.ACCESS_DEFAULTS) do if c.access[k] == nil then c.access[k] = v end end
  return c.access
end

function Theme:ApplyAccessibility()
  local a = self:Access()
  self.baseFont = self.baseFont or { small = self.font.small, normal = self.font.normal, large = self.font.large, title = self.font.title }
  local fs = math.max(0.8, math.min(1.5, tonumber(a.fontScale) or 1))
  for k, v in pairs(self.baseFont) do self.font[k] = math.floor(v * fs + 0.5) end
  self.uiScale = math.max(0.7, math.min(1.5, tonumber(a.uiScale) or 1))
  if a.colorblind then
    self.colors.good = { 0.35, 0.65, 1.00, 1 }
    self.colors.bad = { 1.00, 0.60, 0.15, 1 }
    self.colors.warn = { 1.00, 0.90, 0.40, 1 }
  end
  if a.highContrast then
    self.colors.bg = { 0, 0, 0, 1 }
    self.colors.panel = { 0.05, 0.05, 0.06, 1 }
    self.colors.border = { 0.75, 0.78, 0.85, 1 }
    self.colors.text = { 1, 1, 1, 1 }
    self.colors.muted = { 0.86, 0.88, 0.92, 1 }
  end
  self.reducedMotion = a.reducedMotion and true or false
  return a
end

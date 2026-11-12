-- Modules/Setup.lua  (P7-12 first-run setup and accessibility)
-- Shown once for a character Outrider has never seen (at login, out of
-- combat), and any time with /ride setup. Choices:
--   * rare alert sound on/off
--   * which feature groups to start with (modules are turned on/off;
--     Sharing is always off until switched on on purpose)
--   * accessibility: larger text, larger windows, colorblind-safe colors,
--     high contrast, no fading (Theme, applied after /reload)
-- Layouts per situation are set with /ride layout (P7-09).
-- /ride access font|scale <number> | colorblind|contrast|motion on|off

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local M = ns:NewModule("Setup", {
  title = "First-run setup and accessibility",
  phase = "P7",
  order = 105,
  defaults = { done = false },
})
ns.Setup = M

M.GROUPS = {
  { label = "Rares and hunter tools", modules = { "RareScan", "RareAlerts", "Sightings", "RarePlates", "TameHelper", "PetStatus", "Ammo", "BeastInfo" } },
  { label = "Maps, pins and waypoints", modules = { "MapPins", "MinimapPins", "Nearest", "Waypoints", "Coords" } },
  { label = "Professions, prices and gold", modules = { "Professions", "CraftQueue", "SkillUp", "Prices", "AuctionHelper", "Ledger", "Merchant", "Mailbox" } },
  { label = "Gear advisor", modules = { "GearScore", "QuestRewards", "Nearby", "Handoffs" } },
  { label = "Interface look (Clean dark skins)", modules = { "Skin", "Tooltips", "UnitLook" } },
  { label = "Chat helpers and spell check", modules = { "Chat", "SpellCheck" } },
}

function M:GroupOn(g)
  for _, name in ipairs(g.modules) do
    local mod = ns.Modules:Get(name)
    if mod and mod.enabled then return true end
  end
  return false
end

function M:SetGroup(g, on)
  for _, name in ipairs(g.modules) do
    if ns.Modules:Get(name) then pcall(ns.Modules.SetEnabled, ns.Modules, name, on) end
  end
  self:Info("setup: %s %s", g.label, on and "on" or "off")
end

local function alerts() return ns.Modules:Get("RareAlerts") end

function M:Build()
  if self.frame then return self.frame end
  local f = UI:Window("Outrider_Setup", "Welcome to Outrider", 420, 470)
  f:SetPoint("CENTER")
  local c = f.content
  local intro = UI.Text(c, "small", "muted")
  intro:SetPoint("TOPLEFT", 0, 0)
  intro:SetWidth(396) intro:SetJustifyH("LEFT")
  intro:SetText("Pick what this character starts with. Everything can be changed later in the hub's Modules tab or with /ride setup.")
  local y = -40
  local function check(label, get, set)
    local row = UI:Check(c, label, get, set)
    row:SetPoint("TOPLEFT", 0, y)
    y = y - 24
    return row
  end
  check("Sound with rare alerts", function() local a = alerts() return a and a:Settings().sound end,
    function(v) local a = alerts() if a then a:Settings().sound = v and true or false end end)
  y = y - 8
  for _, g in ipairs(self.GROUPS) do check(g.label, function() return M:GroupOn(g) end, function(v) M:SetGroup(g, v) end) end
  y = y - 8
  local acc = UI.Text(c, "normal", "accent")
  acc:SetPoint("TOPLEFT", 0, y) acc:SetText("Accessibility (after /reload)")
  y = y - 22
  local a = ns.Theme:Access()
  check("Larger text", function() return (a.fontScale or 1) > 1 end, function(v) a.fontScale = v and 1.2 or 1 end)
  check("Larger windows", function() return (a.uiScale or 1) > 1 end, function(v) a.uiScale = v and 1.15 or 1 end)
  check("Colorblind-safe colors (blue / orange)", function() return a.colorblind end, function(v) a.colorblind = v and true or false end)
  check("High contrast", function() return a.highContrast end, function(v) a.highContrast = v and true or false end)
  check("No fading", function() return a.reducedMotion end, function(v) a.reducedMotion = v and true or false end)
  local done = UI:Button(c, "Done", 110, function()
    M:Settings().done = true
    M:Info("setup done")
    f:Hide()
  end)
  done:SetPoint("BOTTOMRIGHT", 0, 0)
  self.frame = f
  return f
end

function M:Open()
  if C.InCombat() then ns.Print("not in combat") return false end
  self:Build():Show()
  return true
end

function M:OnEnable()
  self:On("PLAYER_ENTERING_WORLD", function(mod, _, isLogin)
    if isLogin and ns.DB.freshChar and not mod:Settings().done then
      if not C.InCombat() then mod:Open() end
    end
  end)
end

function M:Activity()
  local a = ns.Theme:Access()
  local parts = {}
  if (a.fontScale or 1) ~= 1 then parts[#parts + 1] = "text x" .. a.fontScale end
  if (a.uiScale or 1) ~= 1 then parts[#parts + 1] = "windows x" .. a.uiScale end
  if a.colorblind then parts[#parts + 1] = "colorblind colors" end
  if a.highContrast then parts[#parts + 1] = "high contrast" end
  if a.reducedMotion then parts[#parts + 1] = "no fading" end
  return #parts > 0 and ("accessibility: " .. table.concat(parts, ", ")) or "default look (/ride setup to change)"
end

ns.AddCommand("setup", "open the first-run setup (features and accessibility)", function() M:Open() end)

ns.AddCommand("access", "font|scale <n> | colorblind|contrast|motion on|off  (applies after /reload)", function(arg)
  local a = ns.Theme:Access()
  local key, val = (arg or ""):match("^(%a+)%s+(%S+)$")
  local n = tonumber(val)
  if key == "font" and n then a.fontScale = math.max(0.8, math.min(1.5, n))
  elseif key == "scale" and n then a.uiScale = math.max(0.7, math.min(1.5, n))
  elseif key == "colorblind" and (val == "on" or val == "off") then a.colorblind = val == "on"
  elseif key == "contrast" and (val == "on" or val == "off") then a.highContrast = val == "on"
  elseif key == "motion" and (val == "on" or val == "off") then a.reducedMotion = val == "off"
  else ns.Print("usage: /ride access font 1.2 | scale 1.1 | colorblind on | contrast on | motion off") return end
  ns.Print("%s. Type /reload to apply.", M:Activity())
end)

-- UI/Settings.lua
-- Registers an "OAR" page under Esc > Options > AddOns. The page is a short
-- description plus a button that opens the hub, where the real settings live.
-- Supports the modern Settings API and the old InterfaceOptions API.

local _, ns = ...
local Settings_ = { name = "settings" }
ns.Settings = Settings_
local UI = ns.UI

function Settings_:Init()
  if self.ready then return end
  self.ready = true
  local panel = CreateFrame("Frame")
  panel.name = "OAR"
  local title = UI.Text(panel, "title", "text")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("OAR")
  local body = UI.Text(panel, "normal", "muted")
  body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  body:SetWidth(560)
  body:SetJustifyH("LEFT")
  body:SetText("Settings are per character. Open the hub to switch modules on or off, export or import a setup, or copy settings from another character.")
  local open = UI:Button(panel, "Open OAR hub", 140, function()
    if HideUIPanel and SettingsPanel then HideUIPanel(SettingsPanel) end
    ns.Hub:Toggle()
  end)
  open:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -12)
  local mini = UI:Check(panel, "Show minimap button",
    function() return not ns.db.global.minimap.hide end,
    function(on) ns.MinimapButton:SetHidden(not on) end)
  mini:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -12)
  self.panel = panel

  local S = rawget(_G, "Settings")
  if S and S.RegisterCanvasLayoutCategory and S.RegisterAddOnCategory then
    local ok, category = pcall(S.RegisterCanvasLayoutCategory, panel, "OAR")
    if ok and category then
      pcall(S.RegisterAddOnCategory, category)
      self.category = category
      return
    end
  end
  if rawget(_G, "InterfaceOptions_AddCategory") then
    pcall(InterfaceOptions_AddCategory, panel)
  end
end

function Settings_:Open()
  local S = rawget(_G, "Settings")
  if self.category and S and S.OpenToCategory then
    local id = self.category.GetID and self.category:GetID() or self.category.ID
    if pcall(S.OpenToCategory, id) then return end
  end
  if rawget(_G, "InterfaceOptionsFrame_OpenToCategory") then
    pcall(InterfaceOptionsFrame_OpenToCategory, self.panel)
    return
  end
  ns.Hub:Toggle()
end

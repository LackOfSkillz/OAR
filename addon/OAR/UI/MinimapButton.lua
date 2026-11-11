-- UI/MinimapButton.lua
-- Exactly one minimap button. Uses LibDBIcon when another addon has loaded it
-- (so minimap-button bags can collect it); otherwise draws its own.
-- Left click: hub. Right click: Blizzard settings page. Drag: move.

local _, ns = ...
local MB = { name = "minimap" }
ns.MinimapButton = MB

local ICON = "Interface\\Icons\\INV_Misc_Map_01"

local function onClick(_, button)
  if button == "RightButton" then ns.Settings:Open() else ns.Hub:Toggle() end
end

local function onTooltip(tt)
  tt:AddLine("OAR")
  tt:AddLine(ns.db.key, 0.7, 0.7, 0.7)
  local _, loads = ns.DB:SavedVariablesStatus()
  tt:AddLine(string.format("v%s  build %s  loads %d", ns.version, ns.build, loads), 0.7, 0.7, 0.7)
  if #ns.Errors.list > 0 then tt:AddLine(#ns.Errors.list .. " error(s): /oar errors", 1, 0.4, 0.4) end
  tt:AddLine("Left click: open   Right click: settings   Drag: move", 0.56, 0.82, 1)
end

function MB:TryLibDBIcon()
  local LibStub = rawget(_G, "LibStub")
  if not LibStub then return false end
  local LDB = LibStub("LibDataBroker-1.1", true)
  local Icon = LibStub("LibDBIcon-1.0", true)
  if not (LDB and Icon) then return false end
  local obj = LDB:NewDataObject("OAR", {
    type = "launcher", icon = ICON, label = "OAR",
    OnClick = onClick,
    OnTooltipShow = onTooltip,
  })
  Icon:Register("OAR", obj, ns.db.global.minimap)
  self.lib = Icon
  return true
end

function MB:Position(b)
  local angle = math.rad(ns.db.global.minimap.angle or 200)
  local radius = (Minimap:GetWidth() / 2) + 10
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function MB:BuildOwn()
  local b = CreateFrame("Button", "OAR_MinimapButton", Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("AnyUp")
  b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER", 0, 1)
  icon:SetTexture(ICON)
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  b:SetScript("OnClick", onClick)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    onTooltip(GameTooltip)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      cx, cy = cx / scale, cy / scale
      ns.db.global.minimap.angle = math.deg(math.atan2(cy - my, cx - mx)) % 360
      MB:Position(self)
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  self.button = b
  self:Position(b)
  b:SetShown(not ns.db.global.minimap.hide)
end

function MB:Init()
  if self.ready then return end
  self.ready = true
  if not self:TryLibDBIcon() then self:BuildOwn() end
end

function MB:SetHidden(hide)
  ns.db.global.minimap.hide = hide and true or false
  if self.lib then
    if hide then self.lib:Hide("OAR") else self.lib:Show("OAR") end
  elseif self.button then
    self.button:SetShown(not hide)
  end
end

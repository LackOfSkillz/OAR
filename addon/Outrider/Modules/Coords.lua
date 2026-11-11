-- Modules/Coords.lua  (P3-10)
-- Player coordinates under the minimap (setting, on by default), refreshed
-- twice a second only while the player is moving (no cost standing still); /ride coords prints and logs mapID and
-- x, y with two decimals so Gary can report a spot and Claude can read it.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Coords", {
  title = "Coordinates",
  phase = "P3",
  order = 55,
  defaults = { minimap = true },
})

function M.Format(mapID, x, y)
  if not mapID then return "no position here" end
  if not x then return string.format("map %d", mapID) end
  return string.format("%.2f, %.2f", x * 100, y * 100)
end

function M:OnEnable()
  if not self:Settings().minimap or not Minimap then return end
  if not self.text then
    self.text = Minimap:CreateFontString(nil, "OVERLAY")
    ns.Theme:StyleText(self.text, "small", "text")
    self.text:SetPoint("TOP", Minimap, "BOTTOM", 0, -4)
  end
  self.text:Show()
  self:On("PLAYER_STARTED_MOVING", function(mod)
    if not mod.ticker then mod.ticker = ns.Timer.Ticker(0.5, function() M:Update() end, "coords") end
  end)
  self:On("PLAYER_STOPPED_MOVING", function(mod)
    if mod.ticker then mod.ticker:Cancel() mod.ticker = nil end
    mod:Update()
  end)
  self:On("ZONE_CHANGED_NEW_AREA", self.Update)
  self:On("PLAYER_ENTERING_WORLD", self.Update)
  self:Update()
end

function M:OnDisable()
  if self.ticker then self.ticker:Cancel() self.ticker = nil end
  if self.text then self.text:Hide() end
end

function M:Update()
  if self.text then self.text:SetText(M.Format(C.PlayerPosition("player"))) end
end

ns.AddCommand("coords", "print map id and your coordinates", function()
  local mapID, x, y = C.PlayerPosition("player")
  local info = mapID and C.Call("C_Map.GetMapInfo", mapID)
  local zone = info and info.name or "?"
  ns.Print("%s (map %s): %s", zone, tostring(mapID), M.Format(mapID, x, y))
  ns.Log:Info("coords", "%s map=%s %s", zone, tostring(mapID), M.Format(mapID, x, y))
end)

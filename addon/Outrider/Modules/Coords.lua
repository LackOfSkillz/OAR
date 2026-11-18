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
  defaults = { minimap = true, mapCursor = true },
})

function M.Format(mapID, x, y)
  if not mapID then return "no position here" end
  if not x then return string.format("map %d", mapID) end
  return string.format("%.2f, %.2f", x * 100, y * 100)
end

function M:OnEnable()
  self:BuildCursor()
  if not self:Settings().minimap or not Minimap then return end
  if not self.text then
    self.text = Minimap:CreateFontString(nil, "OVERLAY")
    ns.Theme:StyleText(self.text, "small", "text")
    -- below the zone/clock line other UI puts right under the minimap
    self.text:SetPoint("TOP", Minimap, "BOTTOM", 0, -22)
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
  if self.cursorText then self.cursorText:Hide() end
  if self.cursorFrame then self.cursorFrame:SetScript("OnUpdate", nil) end
end

function M:Canvas()
  local map = rawget(_G, "WorldMapFrame")
  if not map then return nil end
  if type(map.GetCanvas) == "function" then
    local ok, child = pcall(map.GetCanvas, map)
    if ok and child then return child end
  end
  return map.ScrollContainer and map.ScrollContainer.Child or nil
end

-- Read the visible map canvas; don't infer cursor coords from player position.
-- Unknown or unprojectable maps display "--" instead of incorrect values.
function M:CursorPosition()
  local map = rawget(_G, "WorldMapFrame")
  local canvas = self:Canvas()
  if not (map and canvas and map.IsShown and map:IsShown()) then return nil end
  local mapID = map.GetMapID and C.Readable(map:GetMapID())
  local get = C.Resolve("GetCursorPosition")
  if not (mapID and type(get) == "function") then return nil end
  local px, py = C.Call("GetCursorPosition")
  local scale = C.Readable(canvas:GetEffectiveScale())
  local left, top = C.Readable(canvas:GetLeft()), C.Readable(canvas:GetTop())
  local width, height = C.Readable(canvas:GetWidth()), C.Readable(canvas:GetHeight())
  if not (type(px) == "number" and type(py) == "number"
    and type(scale) == "number" and scale > 0
    and type(left) == "number" and type(top) == "number"
    and type(width) == "number" and width > 0
    and type(height) == "number" and height > 0) then return nil end
  local x, y = ((px / scale) - left) / width, (top - (py / scale)) / height
  if x < 0 or x > 1 or y < 0 or y > 1 then return nil end
  return mapID, x, y
end

function M:BuildCursor()
  local map = rawget(_G, "WorldMapFrame")
  if not (map and self:Settings().mapCursor) or self.cursorFrame then return end
  local frame = CreateFrame("Frame", nil, map)
  frame:SetSize(180, 22)
  frame:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", -18, 12)
  local label = frame:CreateFontString(nil, "OVERLAY")
  ns.Theme:StyleText(label, "small", "text")
  label:SetPoint("CENTER")
  self.cursorFrame, self.cursorText = frame, label
  self.cursorElapsed = 0
  frame:SetScript("OnUpdate", function(_, elapsed)
    M.cursorElapsed = M.cursorElapsed + (elapsed or 0)
    if M.cursorElapsed >= 0.15 then M.cursorElapsed = 0 M:UpdateCursor() end
  end)
  self:UpdateCursor()
end

function M:UpdateCursor()
  if not self.cursorText then return end
  local mapID, x, y = self:CursorPosition()
  if mapID then self.lastHovered = { mapID = mapID, x = x, y = y } end
  self.cursorText:SetText(mapID and ("Cursor: " .. M.Format(mapID, x, y)) or "Cursor: --")
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

function M:Activity() return "under the minimap: " .. M.Format(C.PlayerPosition("player")) end

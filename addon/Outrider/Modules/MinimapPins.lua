-- Modules/MinimapPins.lua  (P3-04)
-- Known places and rares as dots on the minimap while they are within its
-- view radius; they appear as Gary approaches and vanish as he leaves.
-- Math (pure, M.Offset): world (north, west) yards -> minimap pixels, using
-- C_Minimap.GetViewRadius (zoom/indoor aware) and, when the minimap rotates
-- (CVar rotateMinimap), the player's facing. Updates 5x per second only
-- while moving, plus on zoom change and new places. Dots are plain textures.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("MinimapPins", {
  title = "Minimap pins",
  phase = "P3",
  order = 54,
  defaults = {},
})

-- Set true to log the numbers behind the nearest dot once a second (used to
-- fix the drifting dots on 2026-11-11; off once verified in game).
M.DIAG = false

-- dNorth/dWest in yards from the player; returns x, y pixels from the
-- minimap centre (x right, y up), or nil when outside the radius.
function M.Offset(dNorth, dWest, radius, halfSize, facing)
  local east, north = -dWest, dNorth
  if facing then
    local c, s = math.cos(facing), math.sin(facing)
    east, north = east * c + north * s, -east * s + north * c
  end
  local dist = math.sqrt(east * east + north * north)
  if not radius or radius <= 0 or dist > radius then return nil end
  local k = halfSize / radius
  return east * k, north * k, dist
end

function M:OnEnable()
  if not Minimap then return end
  self.dots, self.used = self.dots or {}, {}
  self:On("PLAYER_STARTED_MOVING", function(mod)
    if not mod.ticker then mod.ticker = ns.Timer.Ticker(0.2, function() M:Update() end, "minimappins") end
  end)
  self:On("PLAYER_STOPPED_MOVING", function(mod)
    if mod.ticker then mod.ticker:Cancel() mod.ticker = nil end
    mod:Update()
  end)
  self:On("MINIMAP_UPDATE_ZOOM", self.Update)
  self:On("ZONE_CHANGED_NEW_AREA", self.Update)
  self:On("PLAYER_ENTERING_WORLD", self.Update)
  self:On("OTR_POI_ADDED", self.Update)
  self:On("OTR_SIGHTING_ADDED", self.Update)
end

function M:OnDisable()
  if self.ticker then self.ticker:Cancel() self.ticker = nil end
  for _, d in ipairs(self.used or {}) do d:Hide() end
  self.used = {}
end

-- Each dot is a small button: hover shows name, kind and distance; click
-- opens the same card as the world map pin (Gary asked, 2026-11-11).
function M:Dot(i)
  local d = self.dots[i]
  if not d then
    d = CreateFrame("Button", nil, Minimap)
    d:SetSize(8, 8)
    d:SetFrameLevel((Minimap.GetFrameLevel and Minimap:GetFrameLevel() or 1) + 5)
    d.tex = d:CreateTexture(nil, "OVERLAY")
    d.tex:SetAllPoints()
    d:SetScript("OnEnter", function(self)
      local p = self.pin
      if not p then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(p.name or "?")
      local first, second = ns.POI.Describe(p.poi or p, ns.MapPins.LABELS[p.kind] or p.kind)
      GameTooltip:AddLine(string.format("%s, %d yards", first, math.floor((self.dist or 0) + 0.5)), ns.Theme:Color("muted"))
      if second then GameTooltip:AddLine(second, ns.Theme:Color("text")) end
      GameTooltip:Show()
    end)
    d:SetScript("OnLeave", function() GameTooltip:Hide() end)
    d:SetScript("OnClick", function(self) if self.pin then ns.MapPins:ShowCard(self.pin) end end)
    self.dots[i] = d
  end
  return d
end

function M:Update()
  if not Minimap or not ns.MapPins then return end
  local W = ns.Waypoints
  -- Offsets come from map coordinates (x grows east, y grows south on every
  -- map) times the map's size in yards; no world-axis guessing.
  local mapID, px, py = C.PlayerPosition("player")
  local mapW, mapH
  if mapID then mapW, mapH = W.MapSize(mapID) end
  for _, d in ipairs(self.used) do d:Hide() end
  self.used = {}
  if not (mapID and px and mapW and mapH) then return end
  local radius = C.Call("C_Minimap.GetViewRadius")
  local half = (Minimap:GetWidth() or 140) / 2
  local facing
  local rotate = C.Call("C_CVar.GetCVar", "rotateMinimap")
  if tostring(rotate) == "1" then facing = C.Call("GetPlayerFacing") end
  local n = 0
  local nearest
  for _, pin in ipairs(ns.MapPins:PinsFor(mapID)) do
    do
      local dEast, dSouth = (pin.x - px) * mapW, (pin.y - py) * mapH
      local x, y, dist = M.Offset(-dSouth, -dEast, radius, half, facing)
      if x then
        n = n + 1
        local d = self:Dot(n)
        d.pin, d.dist = pin, dist
        if not nearest or dist < nearest.dist then
          nearest = { name = pin.name, dist = dist, dN = -dSouth, dW = -dEast, x = x, y = y }
        end
        d.tex:SetColorTexture(ns.Theme:Color(pin.kind == "rare" and "warn" or "accent"))
        d:ClearAllPoints()
        d:SetPoint("CENTER", Minimap, "CENTER", x, y)
        d:Show()
        self.used[n] = d
      end
    end
  end
  -- Diagnostics for the "dots drift the wrong way" report (2026-11-11):
  -- once a second, the numbers behind the nearest dot, plus our raw position
  -- sources, so Claude can see which axis or sign is off.
  local now = GetTime and GetTime() or 0
  if M.DIAG and nearest and now - (self.lastDiag or 0) >= 1 then
    self.lastDiag = now
    local _, mx, my = C.PlayerPosition("player")
    local uy, ux = C.Call("UnitPosition", "player")
    self:Info("diag %s dist=%.0f dN=%.0f dW=%.0f dot=%.0f,%.0f map=%.4f,%.4f unitpos=%.1f,%.1f facing=%s rotate=%s radius=%.0f half=%.0f mapsize=%.0fx%.0f",
      tostring(nearest.name), nearest.dist, nearest.dN, nearest.dW, nearest.x, nearest.y, mx or -1, my or -1,
      uy or -1, ux or -1, tostring(facing and string.format("%.2f", facing)), tostring(rotate), radius or -1, half, mapW, mapH)
  end
  if n ~= self.lastCount then
    self.lastCount = n
    self:Debug("minimap pins: %d (radius %s)", n, tostring(radius))
  end
end

function M:Activity()
  return string.format("%d places on the minimap right now", #(self.used or {}))
end

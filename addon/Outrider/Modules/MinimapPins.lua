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

function M:Dot(i)
  local d = self.dots[i]
  if not d then
    d = Minimap:CreateTexture(nil, "OVERLAY")
    d:SetSize(6, 6)
    self.dots[i] = d
  end
  return d
end

function M:Update()
  if not Minimap or not ns.MapPins then return end
  local W = ns.Waypoints
  local mapID = C.PlayerPosition("player")
  local _, pN, pW = W.PlayerWorldPos()
  for _, d in ipairs(self.used) do d:Hide() end
  self.used = {}
  if not (mapID and pN) then return end
  local radius = C.Call("C_Minimap.GetViewRadius")
  local half = (Minimap:GetWidth() or 140) / 2
  local facing
  local rotate = C.Call("C_CVar.GetCVar", "rotateMinimap")
  if tostring(rotate) == "1" then facing = C.Call("GetPlayerFacing") end
  local n = 0
  for _, pin in ipairs(ns.MapPins:PinsFor(mapID)) do
    local _, wN, wW = W.WorldPos(mapID, pin.x, pin.y)
    if wN then
      local x, y = M.Offset(wN - pN, wW - pW, radius, half, facing)
      if x then
        n = n + 1
        local d = self:Dot(n)
        d:SetColorTexture(ns.Theme:Color(pin.kind == "rare" and "warn" or "accent"))
        d:ClearAllPoints()
        d:SetPoint("CENTER", Minimap, "CENTER", x, y)
        d:Show()
        self.used[n] = d
      end
    end
  end
  if n ~= self.lastCount then
    self.lastCount = n
    self:Debug("minimap pins: %d (radius %s)", n, tostring(radius))
  end
end

function M:Activity()
  return string.format("%d places on the minimap right now", #(self.used or {}))
end

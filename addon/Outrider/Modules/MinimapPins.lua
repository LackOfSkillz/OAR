-- Modules/MinimapPins.lua  (P3-04)
-- Known places and rares as dots on the minimap while they are within its
-- view radius; they appear as Gary approaches and vanish as he leaves.
-- Math (pure, M.Offset): world (north, west) yards -> minimap pixels, using
-- C_Minimap.GetViewRadius (zoom/indoor aware) and, when the minimap rotates
-- (CVar rotateMinimap), the player's facing. Updates 5x per second only
-- while moving, plus on zoom change and new places. Dots are plain textures.
-- Kept readable (Gary: "the minimap is so busy I can't see which direction
-- I'm facing", Thunder Bluff, 2026-11-11): only the `max` nearest places
-- (12), nothing within CLEAR pixels of the player arrow, smaller dots, and
-- quest givers left to the world map unless switched on
-- (/ride minipins <n> | quests on|off).

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("MinimapPins", {
  title = "Minimap pins",
  phase = "P3",
  order = 54,
  defaults = { max = 12, quests = false },
})
M.CLEAR, M.SIZE = 11, 10

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
    ns.MapPins.Decorate(d, M.SIZE)
    d:SetFrameLevel((Minimap.GetFrameLevel and Minimap:GetFrameLevel() or 1) + 5)
    d:SetScript("OnEnter", function(self)
      local p = self.pin
      if not p then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(p.name or "?")
      local first, second = ns.POI.Describe(p.poi or p, ns.MapPins.LABELS[p.kind] or p.kind)
      GameTooltip:AddLine(string.format("%s, %d yards", first, math.floor((self.dist or 0) + 0.5)), ns.Theme:Color("muted"))
      if second then GameTooltip:AddLine(second, ns.Theme:Color("text")) end
      for _, l in ipairs(ns.MapPins.QuestLines(p)) do GameTooltip:AddLine(l) end
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
  local s = self:Settings()
  local shown = {}
  for _, pin in ipairs(ns.MapPins:PinsFor(mapID)) do
    if s.quests or pin.kind ~= "quest_giver" then
      local dEast, dSouth = (pin.x - px) * mapW, (pin.y - py) * mapH
      local x, y, dist = M.Offset(-dSouth, -dEast, radius, half, facing)
      if x and (x * x + y * y) >= M.CLEAR * M.CLEAR then
        shown[#shown + 1] = { pin = pin, x = x, y = y, dist = dist, dSouth = dSouth, dEast = dEast }
      end
    end
  end
  table.sort(shown, function(a, b) return a.dist < b.dist end)
  for i = 1, math.min(#shown, s.max or 12) do
    local e = shown[i]
    local pin, x, y, dist, dSouth, dEast = e.pin, e.x, e.y, e.dist, e.dSouth, e.dEast
    do
      if x then
        n = n + 1
        local d = self:Dot(n)
        d.pin, d.dist = pin, dist
        if M.DIAG and (not nearest or dist < nearest.dist) then
          nearest = { name = pin.name, dist = dist, dN = -dSouth, dW = -dEast, x = x, y = y }
        end
        ns.MapPins.Paint(d, pin)
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

ns.AddCommand("minipins", "<number> | quests on|off  how many places the minimap shows", function(arg)
  local s = M:Settings()
  local n = tonumber(arg or "")
  local q = (arg or ""):match("^quests%s+(%a+)$")
  if n then s.max = math.max(0, math.min(40, math.floor(n)))
  elseif q == "on" or q == "off" then s.quests = q == "on"
  else ns.Print("usage: /ride minipins 12 | quests on|off") end
  ns.Print("minimap shows the %d nearest places%s", s.max, s.quests and ", quest givers included" or ", no quest givers")
  M:Update()
end)

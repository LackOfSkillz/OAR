-- Modules/MapReveal.lua
-- Reveal unexplored map areas (Gary, 2026-11-17, Leatrix Maps style), from
-- official data only. The client tells each character which map areas it has
-- explored, with the exact textures (C_MapExplorationInfo.GetExploredMapTextures).
-- Outrider records those for every zone, from every character on the account
-- (and later from shared data), and on the world map draws the areas this
-- character hasn't explored yet, tinted so they stand out. Areas none of your
-- characters has explored stay dark: we never ship or invent map data.
-- Drawing mirrors Blizzard's own exploration overlay (tiles from
-- C_Map.GetMapArtLayers), on our own frame on the map canvas, under the pins.
-- Steps aside for Leatrix Maps / Mapster, which reveal from their own data.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("MapReveal", {
  title = "Reveal unexplored map",
  phase = "P3",
  order = 34,
  defaults = { on = true, tint = 0.55 },
  yieldsTo = { "Leatrix_Maps", "Mapster", "MapsterEnhanced" },
})
ns.MapReveal = M

local function readable(v) return v ~= nil and C.Readable(v) and v or nil end

function M:OnInitialize()
  local g = ns.db.global
  g.mapReveal = type(g.mapReveal) == "table" and g.mapReveal or {}
  self.store = g.mapReveal -- [mapID] = { [key] = { w, h, x, y, ids = {...} } }
  self.pool, self.used = {}, {}
end

-- ------------------------------------------------------------------ recording
function M.Key(t) return table.concat(t.ids or {}, ",") .. "@" .. tostring(t.x) .. ":" .. tostring(t.y) end

-- the explored overlays this character has on mapID, as plain tables
function M.Explored(mapID)
  local list = C.Call("C_MapExplorationInfo.GetExploredMapTextures", mapID)
  local out = {}
  if type(list) ~= "table" then return out end
  for _, e in ipairs(list) do
    local ids = {}
    for i, id in ipairs(e.fileDataIDs or {}) do ids[i] = readable(id) end
    if #ids > 0 then
      out[#out + 1] = { w = readable(e.textureWidth), h = readable(e.textureHeight), x = readable(e.offsetX) or 0,
        y = readable(e.offsetY) or 0, ids = ids }
    end
  end
  return out
end

function M:Record(mapID)
  if type(mapID) ~= "number" then return 0 end
  local n = 0
  local slot = self.store[mapID]
  for _, e in ipairs(M.Explored(mapID)) do
    if e.w and e.h then
      slot = slot or {}
      local k = M.Key(e)
      if not slot[k] then n = n + 1 end
      slot[k] = e
    end
  end
  if slot then self.store[mapID] = slot end
  return n
end

-- every map the client knows under this character's world
function M:RecordAll()
  local zones = {}
  local here = C.PlayerPosition("player")
  -- the top of this character's map chain, then every map under it
  local top, guard = here, 0
  while top and guard < 10 do
    local info = C.Call("C_Map.GetMapInfo", top)
    local parent = type(info) == "table" and readable(info.parentMapID)
    if not parent or parent == 0 then break end
    top, guard = parent, guard + 1
  end
  local all = top and C.Call("C_Map.GetMapChildrenInfo", top, nil, true)
  for _, m in ipairs(type(all) == "table" and all or {}) do
    if readable(m.mapID) then zones[#zones + 1] = m.mapID end
  end
  if here then zones[#zones + 1] = here end
  -- one pass (a few hundred cheap calls at most), no timers left running
  local added = 0
  for i = 1, math.min(#zones, 400) do added = added + self:Record(zones[i]) end
  self:Info("map reveal: %d maps read, %d new explored areas", #zones, added)
end

-- areas known from any character that this character hasn't explored
function M:Missing(mapID)
  local slot = self.store[mapID]
  if not slot then return {} end
  local mine = {}
  for _, e in ipairs(M.Explored(mapID)) do mine[M.Key(e)] = true end
  local out = {}
  for k, e in pairs(slot) do if not mine[k] then out[#out + 1] = e end end
  table.sort(out, function(a, b) return M.Key(a) < M.Key(b) end)
  return out
end

-- ------------------------------------------------------------------ drawing
-- tiles of one overlay, like Blizzard's MapExplorationPin: { {id, x, y, w, h, u, v} }
function M.Tiles(e, tileW, tileH)
  local out = {}
  local wide, tall = math.ceil(e.w / tileW), math.ceil(e.h / tileH)
  local function size(total, tile, last)
    if not last then return tile, tile end
    local px = total % tile
    if px == 0 then px = tile end
    local file = 16
    while file < px do file = file * 2 end
    return px, file
  end
  for j = 1, tall do
    local ph, fh = size(e.h, tileH, j == tall)
    for k = 1, wide do
      local pw, fw = size(e.w, tileW, k == wide)
      local id = e.ids[(j - 1) * wide + k]
      if id then
        out[#out + 1] = { id = id, x = e.x + tileW * (k - 1), y = e.y + tileH * (j - 1), w = pw, h = ph, u = pw / fw, v = ph / fh }
      end
    end
  end
  return out
end

function M:Release()
  for _, t in ipairs(self.used) do t:Hide() self.pool[#self.pool + 1] = t end
  self.used = {}
end

function M:Layer()
  if self.layer then return self.layer end
  local canvas = self.map:GetCanvas()
  local f = CreateFrame("Frame", nil, canvas)
  f:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, 0)
  f:SetFrameLevel(canvas.GetFrameLevel and canvas:GetFrameLevel() or 1)
  self.layer = f
  return f
end

function M:Refresh()
  self:Release()
  if not (self.map and self:Settings().on) then return end
  local mapID = self.map.GetMapID and self.map:GetMapID()
  if not mapID then return end
  self:Record(mapID)
  local missing = self:Missing(mapID)
  if #missing == 0 then return end
  local layers = C.Call("C_Map.GetMapArtLayers", mapID)
  local art = type(layers) == "table" and layers[1]
  if not art then return end
  local tileW, tileH = readable(art.tileWidth) or 256, readable(art.tileHeight) or 256
  local layerW, layerH = readable(art.layerWidth), readable(art.layerHeight)
  if not (layerW and layerH) then return end
  local canvas = self.map:GetCanvas()
  local f = self:Layer()
  f:SetSize(layerW, layerH)
  f:SetScale(math.max(0.01, (canvas:GetWidth() or layerW) / layerW))
  local tint = self:Settings().tint or 0.55
  for _, e in ipairs(missing) do
    for _, t in ipairs(M.Tiles(e, tileW, tileH)) do
      local tex = table.remove(self.pool) or f:CreateTexture(nil, "ARTWORK")
      tex:ClearAllPoints()
      tex:SetSize(t.w, t.h)
      tex:SetTexCoord(0, t.u, 0, t.v)
      tex:SetPoint("TOPLEFT", f, "TOPLEFT", t.x, -t.y)
      tex:SetTexture(t.id)
      tex:SetVertexColor(tint, tint, tint + 0.1, 1)
      tex:Show()
      self.used[#self.used + 1] = tex
    end
  end
  f:Show()
end

-- ------------------------------------------------------------------ module
function M:OnEnable()
  local map = rawget(_G, "WorldMapFrame")
  if not (map and map.GetCanvas) then self:Warn("no world map canvas: map reveal off") return end
  self.map = map
  if not self.hooked then
    self.hooked = true
    map:HookScript("OnShow", function() if M.enabled then ns.Safe("mapreveal:refresh", M.Refresh, M) end end)
    if type(map.OnMapChanged) == "function" then
      hooksecurefunc(map, "OnMapChanged", function() if M.enabled then ns.Safe("mapreveal:refresh", M.Refresh, M) end end)
    end
  end
  self:On("PLAYER_ENTERING_WORLD", function(mod, _, isLogin) if isLogin then mod:RecordAll() end end)
  self:On("ZONE_CHANGED_NEW_AREA", function(mod) mod:Record(C.PlayerPosition("player")) end)
  self:On("MAP_EXPLORATION_UPDATED", function(mod) mod:Record(C.PlayerPosition("player")) end)
end

function M:OnDisable()
  self:Release()
end

function M:Activity()
  local maps, areas = 0, 0
  for _, slot in pairs(self.store) do
    maps = maps + 1
    for _ in pairs(slot) do areas = areas + 1 end
  end
  return string.format("%d explored areas known on %d maps (from all your characters)", areas, maps)
end

-- Modules/MapReveal.lua
-- Reveal unexplored map areas (Gary, 2026-11-17, Leatrix Maps style), from
-- official data only. The client tells each character which map areas it has
-- explored, with the exact textures (C_MapExplorationInfo.GetExploredMapTextures).
-- Outrider records those for every zone, from every character on the account
-- and on the world map draws the areas this character hasn't explored yet,
-- tinted so they stand out. Gary OK'd fetching the game's full overlay list
-- (2026-11-17): Data/MapOverlays.lua holds every explorable area of every
-- Forever zone from the client's own tables for build 1.60.1.70938 (via
-- wago.tools, tools/import_map_overlays.py), so the whole map shows; the
-- recorded areas still cover any map the data file misses.
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
-- an area is the same area when it sits at the same place with the same size
function M.Key(t) return string.format("%s:%s:%s:%s", tostring(t.x), tostring(t.y), tostring(t.w), tostring(t.h)) end

-- every area of mapID from the data file, as { w, h, x, y, ids }
function M.Known(mapID)
  local pack = ns.MapOverlays and ns.MapOverlays.maps and ns.MapOverlays.maps[mapID]
  local out = {}
  for _, e in ipairs(pack or {}) do out[#out + 1] = { w = e[1], h = e[2], x = e[3], y = e[4], ids = e[5] } end
  return out
end

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
  local all = {}
  for k, e in pairs(self.store[mapID] or {}) do all[M.Key(e)] = e end
  for _, e in ipairs(M.Known(mapID)) do all[M.Key(e)] = all[M.Key(e)] or e end
  local mine = {}
  for _, e in ipairs(M.Explored(mapID)) do mine[M.Key(e)] = true end
  local out = {}
  for k, e in pairs(all) do if not mine[k] then out[#out + 1] = e end end
  table.sort(out, function(a, b) return M.Key(a) < M.Key(b) end)
  return out
end

-- Map extras: count and enumerate missing exploration overlays. The client
-- overlay data has no textual area names, so report coordinates, not fake names.
function M:MissingSummary(mapID)
  local missing, known = self:Missing(mapID), M.Known(mapID)
  local out = {}
  for _, e in ipairs(missing) do
    out[#out + 1] = { x = e.x, y = e.y, key = M.Key(e) }
  end
  return { mapID = mapID, missing = #out, totalKnown = #known, locations = out,
    source = #known > 0 and "client overlays" or "account observations only" }
end

function M:FishingAdvice(mapID)
  local info = C.Call("C_Map.GetMapInfo", mapID)
  local name = info and readable(info.name)
  if not name then return nil end
  for _, tier in ipairs(ns.FishingData and ns.FishingData.tiers or {}) do
    for _, z in ipairs(tier.zones) do
      if z == name then
        return { zone = name, from = tier.lo, to = tier.hi, verified = false }
      end
    end
  end
end

-- Calendar dates from Wowhead's Forever guide, Nov 2026 (verify realm hours
-- in the client calendar; schedule may change). No speculative future dates.
M.FAIRES = {
  { year = 2026, month = 11, day = 9, closeDay = 16, zone = "Elwynn Forest", mapID = 1429, x = 0.42, y = 0.70 },
  { year = 2026, month = 12, day = 7, closeDay = 14, zone = "Mulgore", mapID = 1412, x = 0.37, y = 0.38 },
  { year = 2027, month = 1, day = 4, closeDay = 11, zone = "Elwynn Forest", mapID = 1429, x = 0.42, y = 0.70 },
  { year = 2027, month = 2, day = 8, closeDay = 15, zone = "Mulgore", mapID = 1412, x = 0.37, y = 0.38 },
  { year = 2027, month = 3, day = 8, closeDay = 15, zone = "Elwynn Forest", mapID = 1429, x = 0.42, y = 0.70 },
}
function M:NextFaire(now)
  now = now or time()
  for _, e in ipairs(M.FAIRES) do
    local starts = time({ year = e.year, month = e.month, day = e.day, hour = 0 })
    local ends = time({ year = e.year, month = e.month, day = e.closeDay, hour = 0 })
    if now < ends then
      return { zone = e.zone, mapID = e.mapID, x = e.x, y = e.y,
        opens = starts, closes = ends, active = now >= starts, verified = false,
        note = "Reported Forever calendar dates; verify exact realm time in-game." }
    end
  end
end

ns.AddCommand("mapextras", "mapextras missing|fishing|faire", function(arg)
  local cmd = tostring(arg or "missing"):lower()
  if cmd == "" then cmd = "missing" end
  local mapID = C.PlayerPosition("player")
  if cmd == "missing" then
    if not mapID then ns.Print("no map position available") return end
    local data = M:MissingSummary(mapID)
    ns.Print("exploration map %d: %d areas not explored (%d in full data pack, %s)",
      mapID, data.missing, data.totalKnown, data.source)
    for i = 1, math.min(10, #data.locations) do
      local p = data.locations[i]
      ns.Print("  missing tile %d near overlay pixel %d, %d", i, p.x, p.y)
    end
  elseif cmd == "fishing" then
    local info = mapID and M:FishingAdvice(mapID)
    if info then ns.Print("%s: suggested Fishing %d-%d (guide data, not verified in-game)", info.zone, info.from, info.to)
    else ns.Print("no verified fishing skill advice for this zone") end
  elseif cmd == "faire" then
    local f = M:NextFaire()
    if not f then ns.Print("no dated Faire entries remaining; check in-game calendar") return end
    ns.Print("Darkmoon Faire: %s from %s to %s, approx %.0f, %.0f on map %d (%s)",
      f.zone, date("%d %b %Y", f.opens), date("%d %b %Y", f.closes),
      f.x * 100, f.y * 100, f.mapID, f.note)
  else ns.Print("usage: /ride mapextras missing|fishing|faire") end
end)

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
  -- at Blizzard's own explored-area level, so it sits on the map art but under every pin
  local lvl = canvas.GetFrameLevel and canvas:GetFrameLevel() or 1
  local mgr = self.map.GetPinFrameLevelsManager and select(2, pcall(self.map.GetPinFrameLevelsManager, self.map))
  if type(mgr) == "table" and mgr.GetValidFrameLevel then
    local ok, l = pcall(mgr.GetValidFrameLevel, mgr, "PIN_FRAME_LEVEL_MAP_EXPLORATION")
    if ok and type(l) == "number" then lvl = l end
  end
  f:SetFrameLevel(lvl)
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
  local pack = ns.MapOverlays and ns.MapOverlays.maps
  local n = 0
  for _ in pairs(pack or {}) do n = n + 1 end
  return string.format("full map data for %d zones (build %s); %d areas recorded from your characters",
    n, ns.MapOverlays and ns.MapOverlays.build or "?", areas)
end

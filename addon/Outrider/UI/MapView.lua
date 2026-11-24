-- UI/MapView.lua
-- A live map inside Outrider's own windows (requirement 2026-11-24, after FojjiCore's
-- dungeon journal map). It draws the game's own map art for any map (zone,
-- city, continent, dungeon level) from C_Map.GetMapArtLayers +
-- C_Map.GetMapArtLayerTextures, every explorable area on top (the same data
-- Map reveal uses), Outrider's pins (places, rares, quest givers, bosses),
-- your routes and the player arrow. Wheel zooms around the cursor, right-drag
-- (or left-drag in Move mode) pans, a click on a zone opens it, a right-click
-- goes up one map. With drawing on, the toolbar draws lines, drops raid-icon
-- markers and text labels, erases and undoes, into a route (Modules/Routes).
-- Plain textures and lines only: nothing protected.
--
--   local v = UI:MapView(parent, { draw = true, kinds = { rare = true }, onMap = fn })
--   v:SetMap(mapID)  v:SetRoute(routeID)  v:Refresh()

local _, ns = ...
local C, UI, Theme = ns.Compat, ns.UI, ns.Theme

local MV = {}
UI.MapViewLib = MV
MV.MAX_ZOOM = 8
MV.PIN = 14
MV.HEAD = 28   -- header strip (map name, zoom buttons)
MV.TOOLS = 28  -- drawing toolbar
MV.FOOT = 16
MV.ERASE = 0.025

local function readable(v) return v ~= nil and C.Readable(v) and v or nil end

-- ------------------------------------------------------------------ view math (pure)
-- state: { vw, vh, lw, lh, zoom, cx, cy }  (cx, cy: the map point at the centre, 0..1)
function MV.Base(st)
  if not (st.lw and st.lh and st.lw > 0 and st.lh > 0) then return 1 end
  return math.min(st.vw / st.lw, st.vh / st.lh)
end

function MV.Size(st)
  local s = MV.Base(st) * (st.zoom or 1)
  return st.lw * s, st.lh * s, s
end

-- keep the map covering the view where it can; centred where it is smaller
function MV.Clamp(st)
  local W, H = MV.Size(st)
  st.zoom = math.max(1, math.min(MV.MAX_ZOOM, st.zoom or 1))
  W, H = MV.Size(st)
  if W <= st.vw then st.cx = 0.5 else
    local half = st.vw / 2 / W
    st.cx = math.max(half, math.min(1 - half, st.cx or 0.5))
  end
  if H <= st.vh then st.cy = 0.5 else
    local half = st.vh / 2 / H
    st.cy = math.max(half, math.min(1 - half, st.cy or 0.5))
  end
  return st
end

-- top-left of the map art inside the view, in pixels
function MV.Origin(st)
  local W, H = MV.Size(st)
  return st.vw / 2 - (st.cx or 0.5) * W, st.vh / 2 - (st.cy or 0.5) * H
end

function MV.ToView(st, x, y)
  local W, H = MV.Size(st)
  local ox, oy = MV.Origin(st)
  return ox + x * W, oy + y * H
end

function MV.FromView(st, px, py)
  local W, H = MV.Size(st)
  local ox, oy = MV.Origin(st)
  if W <= 0 or H <= 0 then return nil end
  return (px - ox) / W, (py - oy) / H
end

-- zoom by factor keeping the map point under (px, py) where it is
function MV.ZoomAt(st, factor, px, py)
  local mx, my = MV.FromView(st, px, py)
  st.zoom = math.max(1, math.min(MV.MAX_ZOOM, (st.zoom or 1) * factor))
  local W, H = MV.Size(st)
  if mx then
    st.cx = mx - (px - st.vw / 2) / W
    st.cy = my - (py - st.vh / 2) / H
  end
  return MV.Clamp(st)
end

function MV.Pan(st, dx, dy)
  local W, H = MV.Size(st)
  if W > 0 then st.cx = (st.cx or 0.5) - dx / W end
  if H > 0 then st.cy = (st.cy or 0.5) - dy / H end
  return MV.Clamp(st)
end

-- ------------------------------------------------------------------ map art
-- { lw, lh, tiles = { {id, x, y, w, h, u, v}, ... } } in layer pixels, or nil
function MV.Art(mapID)
  local layers = C.Call("C_Map.GetMapArtLayers", mapID)
  local art = type(layers) == "table" and layers[1]
  if not art then return nil, "no map art" end
  local tw, th = readable(art.tileWidth) or 256, readable(art.tileHeight) or 256
  local lw, lh = readable(art.layerWidth), readable(art.layerHeight)
  if not (lw and lh) then return nil, "no map size" end
  local ids = C.Call("C_Map.GetMapArtLayerTextures", mapID, 1)
  if type(ids) ~= "table" or #ids == 0 then return nil, "no map textures" end
  local R = ns.MapReveal
  local tiles = {}
  if R and R.Tiles then
    for _, t in ipairs(R.Tiles({ w = lw, h = lh, x = 0, y = 0, ids = ids }, tw, th)) do tiles[#tiles + 1] = t end
    -- every explorable area on top, so the map reads like an explored one
    local known = R.Known and R.Known(mapID) or {}
    if #known == 0 and R.Explored then known = R.Explored(mapID) end
    for _, e in ipairs(known) do
      if e.w and e.h and e.ids then
        for _, t in ipairs(R.Tiles(e, tw, th)) do t.overlay = true tiles[#tiles + 1] = t end
      end
    end
  end
  return { lw = lw, lh = lh, tiles = tiles }
end

local function mapInfo(mapID)
  local info = C.Call("C_Map.GetMapInfo", mapID)
  return type(info) == "table" and info or {}
end

-- ------------------------------------------------------------------ the widget
function UI:MapView(parent, opts)
  opts = opts or {}
  local v = CreateFrame("Frame", nil, parent, Theme:BackdropTemplate())
  Theme:ApplyPanel(v, "bg", "border")
  v.opts = opts
  v.st = { vw = 400, vh = 300, zoom = 1, cx = 0.5, cy = 0.5 }
  v.mode = "move"
  v.color, v.icon = 2, 1

  -- header: map name, up, zoom, world map
  local head = CreateFrame("Frame", nil, v)
  head:SetPoint("TOPLEFT", 6, -4)
  head:SetPoint("TOPRIGHT", -6, -4)
  head:SetHeight(MV.HEAD - 6)
  v.title = UI.Display and UI.Display(head, "side", "goldText") or UI.Text(head, "normal", "goldText")
  v.title:SetPoint("LEFT", 2, 0)
  local function small(label, w, fn, tip)
    local b = UI:Button(head, label, w, fn)
    b:SetHeight(20)
    if tip then UI.Tip(b, label, tip) end
    return b
  end
  v.worldBtn = small("World map", 84, function() v:OpenWorldMap() end, "Open the game's world map on this map.")
  v.worldBtn:SetPoint("RIGHT", 0, 0)
  v.fitBtn = small("Fit", 36, function() v.st.zoom = 1 MV.Clamp(v.st) v:Layout() end, "Show the whole map.")
  v.fitBtn:SetPoint("RIGHT", v.worldBtn, "LEFT", -4, 0)
  v.outBtn = small("-", 24, function() MV.ZoomAt(v.st, 1 / 1.5, v.st.vw / 2, v.st.vh / 2) v:Layout() end, "Zoom out.")
  v.outBtn:SetPoint("RIGHT", v.fitBtn, "LEFT", -4, 0)
  v.inBtn = small("+", 24, function() MV.ZoomAt(v.st, 1.5, v.st.vw / 2, v.st.vh / 2) v:Layout() end, "Zoom in.")
  v.inBtn:SetPoint("RIGHT", v.outBtn, "LEFT", -4, 0)
  v.upBtn = small("Up", 36, function() v:GoUp() end, "Go up one map (zone to continent).")
  v.upBtn:SetPoint("RIGHT", v.inBtn, "LEFT", -8, 0)
  v.hereBtn = small("Here", 44, function() v:GoHere() end, "The map you are on.")
  v.hereBtn:SetPoint("RIGHT", v.upBtn, "LEFT", -4, 0)

  -- drawing toolbar
  local top = MV.HEAD
  if opts.draw then
    local tb = CreateFrame("Frame", nil, v)
    tb:SetPoint("TOPLEFT", 6, -MV.HEAD)
    tb:SetPoint("TOPRIGHT", -6, -MV.HEAD)
    tb:SetHeight(MV.TOOLS - 4)
    v.tools = tb
    v.modeBtns = {}
    local prev
    local MODES = {
      { "move", "Move", "Drag to move the map, click a zone to open it." },
      { "line", "Draw", "Hold the left button and drag to draw a line." },
      { "mark", "Marker", "Click to drop the marker icon shown on the right." },
      { "text", "Text", "Click where the label goes, then type it." },
      { "erase", "Erase", "Click a line or marker to remove it." },
    }
    for _, m in ipairs(MODES) do
      local b = UI:Button(tb, m[2], 58, function() v:SetMode(m[1]) end)
      b:SetHeight(20)
      UI.Tip(b, m[2], m[3])
      if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("LEFT", 0, 0) end
      prev = b
      v.modeBtns[m[1]] = b
    end
    -- color: a swatch that steps through the colors
    v.swatch = CreateFrame("Button", nil, tb, Theme:BackdropTemplate())
    v.swatch:SetSize(20, 20)
    v.swatch:SetPoint("LEFT", prev, "RIGHT", 10, 0)
    Theme:ApplyPanel(v.swatch, "raised", "strong")
    v.swatch.fill = v.swatch:CreateTexture(nil, "ARTWORK")
    v.swatch.fill:SetPoint("TOPLEFT", 3, -3)
    v.swatch.fill:SetPoint("BOTTOMRIGHT", -3, 3)
    v.swatch:SetScript("OnClick", function() v.color = v.color % #ns.Routes.COLORS + 1 v:PaintTools() end)
    UI.Tip(v.swatch, "Color", "Click to change the color of new lines, markers and labels.")
    -- marker icon: steps through the eight raid icons
    v.iconBtn = CreateFrame("Button", nil, tb)
    v.iconBtn:SetSize(20, 20)
    v.iconBtn:SetPoint("LEFT", v.swatch, "RIGHT", 4, 0)
    v.iconBtn.tex = v.iconBtn:CreateTexture(nil, "ARTWORK")
    v.iconBtn.tex:SetAllPoints()
    v.iconBtn:SetScript("OnClick", function() v.icon = v.icon % 8 + 1 v:PaintTools() end)
    UI.Tip(v.iconBtn, "Marker icon", "Click to pick the marker: star, circle, diamond, triangle, moon, square, cross or skull.")
    v.undoBtn = UI:Button(tb, "Undo", 52, function()
      if v.route and ns.Routes:Undo(v.route) then v:Refresh() end
    end)
    v.undoBtn:SetHeight(20)
    v.undoBtn:SetPoint("LEFT", v.iconBtn, "RIGHT", 10, 0)
    UI.Tip(v.undoBtn, "Undo", "Take back the last line or marker.")
    v.routeLabel = UI.Text(tb, "small", "muted")
    v.routeLabel:SetPoint("LEFT", v.undoBtn, "RIGHT", 10, 0)
    v.routeLabel:SetPoint("RIGHT", 0, 0)
    if v.routeLabel.SetJustifyH then v.routeLabel:SetJustifyH("RIGHT") end
    if v.routeLabel.SetWordWrap then v.routeLabel:SetWordWrap(false) end
    top = MV.HEAD + MV.TOOLS
  end

  -- the clipped map area
  local host = CreateFrame("Frame", nil, v)
  host:SetPoint("TOPLEFT", 4, -top)
  host:SetPoint("BOTTOMRIGHT", -4, MV.FOOT + 2)
  if host.SetClipsChildren then host:SetClipsChildren(true) end
  host.bg = host:CreateTexture(nil, "BACKGROUND")
  host.bg:SetAllPoints()
  host.bg:SetColorTexture(0.04, 0.035, 0.03, 1)
  v.host = host
  local art = CreateFrame("Frame", nil, host)
  art:SetAllPoints()
  v.art = art
  local draw = CreateFrame("Frame", nil, host)
  draw:SetAllPoints()
  draw:SetFrameLevel((art.GetFrameLevel and art:GetFrameLevel() or 1) + 2)
  v.draw = draw
  local pins = CreateFrame("Frame", nil, host)
  pins:SetAllPoints()
  pins:SetFrameLevel((art.GetFrameLevel and art:GetFrameLevel() or 1) + 6)
  v.pinLayer = pins
  v.tilePool, v.tileUsed, v.pinPool, v.pinUsed = {}, {}, {}, {}
  v.empty = UI.Text(host, "normal", "muted")
  v.empty:SetPoint("CENTER")
  v.empty:Hide()
  v.player = pins:CreateTexture(nil, "OVERLAY")
  v.player:SetSize(24, 24)
  v.player:SetTexture("Interface\\WorldMap\\WorldMapArrow")
  v.player:Hide()
  -- live line while drawing
  v.ink = CreateFrame("Frame", nil, host)
  v.ink:SetAllPoints()
  v.ink:SetFrameLevel((art.GetFrameLevel and art:GetFrameLevel() or 1) + 4)

  v.foot = UI.Text(v, "small", "muted")
  v.foot:SetPoint("BOTTOMLEFT", 8, 3)
  v.foot:SetPoint("BOTTOMRIGHT", -8, 3)
  if v.foot.SetJustifyH then v.foot:SetJustifyH("CENTER") end

  -- -------------------------------------------------------------- methods
  -- cursor in view pixels (top-left origin)
  function v:Cursor()
    local cx, cy = GetCursorPosition()
    local s = self.host:GetEffectiveScale() or 1
    local l, t = self.host:GetLeft(), self.host:GetTop()
    if not (cx and l and t) then return nil end
    return cx / s - l, t - cy / s
  end

  function v:SetMap(mapID)
    mapID = tonumber(mapID)
    if not mapID then return end
    if mapID ~= self.mapID then
      self.mapID = mapID
      self.st.zoom, self.st.cx, self.st.cy = 1, 0.5, 0.5
      local a, why = MV.Art(mapID)
      self.artData = a
      self.why = why
      if not self.loggedArt then
        self.loggedArt = true
        ns.Log:Info("mapview", "map panel: map %d %s (%s tiles)", mapID, a and "drawn" or ("not drawn: " .. tostring(why)),
          a and #a.tiles or 0)
      end
      if opts.onMap then ns.Safe("mapview:onmap", opts.onMap, mapID) end
    end
    self:Layout()
  end

  function v:SetRoute(id)
    self.route = id
    self:PaintTools()
    self:Refresh()
  end

  function v:SetMode(m)
    self.mode = m
    self:PaintTools()
  end

  function v:PaintTools()
    local R = ns.Routes
    if self.modeBtns then
      for id, b in pairs(self.modeBtns) do
        local on = id == self.mode
        b.rest = on and "gold" or "strong"
        Theme:ApplyPanel(b, on and "goldSoft" or "raised", b.rest)
      end
      local c = R.COLORS[self.color] or R.COLORS[1]
      self.swatch.fill:SetColorTexture(c[1], c[2], c[3], 1)
      self.iconBtn.tex:SetTexture(R.IconPath(self.icon))
      local r = self.route and R:Get(self.route)
      self.routeLabel:SetText(r and ("Drawing into: |cffffd27f" .. r.name .. "|r") or "Pick or make a route to draw")
    end
    local hint = self.mode == "line" and "Hold left button and drag to draw" or self.mode == "mark" and "Click to drop a marker"
      or self.mode == "text" and "Click where the label goes" or self.mode == "erase" and "Click a line or marker to remove it"
      or "Wheel: zoom   Right-drag: move   Click a zone: open it   Right-click: up one map"
    self.foot:SetText(hint)
  end

  function v:OpenWorldMap()
    if C.Call("InCombatLockdown") then ns.Print("the world map can't be opened by Outrider in combat") return end
    local open = rawget(_G, "OpenWorldMap")
    local wm = rawget(_G, "WorldMapFrame")
    if type(open) == "function" then pcall(open, self.mapID)
    elseif wm and wm.SetMapID then pcall(ShowUIPanel, wm) pcall(wm.SetMapID, wm, self.mapID) end
  end

  function v:GoUp()
    local p = readable(mapInfo(self.mapID).parentMapID)
    if p and p > 0 then self:SetMap(p) end
  end

  function v:GoHere()
    local m = C.PlayerPosition("player")
    if m then self:SetMap(m) end
  end

  -- place art tiles for the current view
  function v:Layout()
    local w, h = self.host:GetWidth(), self.host:GetHeight()
    if not (w and h and w > 10 and h > 10) then return end
    local st = self.st
    st.vw, st.vh = w, h
    local a = self.artData
    for _, t in ipairs(self.tileUsed) do t:Hide() self.tilePool[#self.tilePool + 1] = t end
    self.tileUsed = {}
    local info = mapInfo(self.mapID)
    self.title:SetText(readable(info.name) or "Map")
    if self.upBtn then self.upBtn:SetEnabled((readable(info.parentMapID) or 0) > 0) end
    if not a then
      self.empty:SetText(self.mapID and ("This map has no picture to draw (" .. tostring(self.why) .. ").") or "No map yet.")
      self.empty:Show()
      self:Refresh()
      return
    end
    self.empty:Hide()
    st.lw, st.lh = a.lw, a.lh
    MV.Clamp(st)
    local _, _, s = MV.Size(st)
    local ox, oy = MV.Origin(st)
    for _, t in ipairs(a.tiles) do
      -- only tiles that show
      local x, y, tw, th = ox + t.x * s, oy + t.y * s, t.w * s, t.h * s
      if x + tw >= 0 and y + th >= 0 and x <= w and y <= h then
        local tex = table.remove(self.tilePool) or self.art:CreateTexture(nil, t.overlay and "ARTWORK" or "BACKGROUND")
        if tex.SetDrawLayer then tex:SetDrawLayer(t.overlay and "ARTWORK" or "BACKGROUND", 1) end
        tex:ClearAllPoints()
        tex:SetSize(tw, th)
        tex:SetPoint("TOPLEFT", self.art, "TOPLEFT", x, -y)
        tex:SetTexture(t.id)
        tex:SetTexCoord(0, t.u, 0, t.v)
        tex:Show()
        self.tileUsed[#self.tileUsed + 1] = tex
      end
    end
    self:Refresh()
  end

  -- the pins to show: Outrider's pins for this map, filtered by kinds
  function v:PinList()
    local out = {}
    if not self.mapID then return out end
    local MP = ns.MapPins
    if MP and MP.enabled and MP.PinsFor then
      local list = MP:PinsFor(self.mapID)
      if MP.Declutter then list = MP.Declutter(list) end
      for _, d in ipairs(list) do
        if not opts.kinds or opts.kinds[d.kind] then out[#out + 1] = d end
      end
    end
    if opts.extraPins then
      local ok, extra = ns.Safe("mapview:extra", opts.extraPins, self.mapID)
      if ok and type(extra) == "table" then for _, d in ipairs(extra) do out[#out + 1] = d end end
    end
    return out
  end

  local function pinEnter(self)
    local d = self.data
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(d.name or "?")
    if ns.POI and ns.POI.Describe and ns.MapPins then
      local first, second = ns.POI.Describe(d.poi or d, ns.MapPins.LABELS and ns.MapPins.LABELS[d.kind] or d.kind)
      if first then GameTooltip:AddLine(first, Theme:Color("muted")) end
      if second then GameTooltip:AddLine(second, Theme:Color("text")) end
    end
    if d.poi and d.poi.note then GameTooltip:AddLine(d.poi.note, 1, 1, 1, true) end
    GameTooltip:AddLine("Click for details", Theme:Color("muted"))
    GameTooltip:Show()
  end

  function v:Refresh()
    for _, p in ipairs(self.pinUsed) do p:Hide() self.pinPool[#self.pinPool + 1] = p end
    self.pinUsed = {}
    self.player:Hide()
    if not (self.mapID and self.artData) then
      if ns.Routes then ns.Routes.Draw(self.draw, {}, 1, 1) end
      return
    end
    local st = self.st
    local W, H = MV.Size(st)
    local ox, oy = MV.Origin(st)
    -- routes: the one being drawn plus every shown route on this map
    if ns.Routes and ns.Routes.enabled then
      local list, seen = {}, {}
      local cur = self.route and ns.Routes:Get(self.route)
      if cur and cur.mapID == self.mapID then list[1] = cur seen[cur.id] = true end
      for _, r in ipairs(ns.Routes:For(self.mapID)) do if not seen[r.id] then list[#list + 1] = r end end
      ns.Routes.Draw(self.draw, list, W, H, ox, oy, 3, 16)
    end
    -- pins
    for _, d in ipairs(self:PinList()) do
      local px, py = ox + d.x * W, oy + d.y * H
      if px >= -8 and py >= -8 and px <= st.vw + 8 and py <= st.vh + 8 then
        local b = table.remove(self.pinPool)
        if not b then
          b = CreateFrame("Button", nil, self.pinLayer)
          if ns.MapPins and ns.MapPins.Decorate then ns.MapPins.Decorate(b, MV.PIN) else b:SetSize(MV.PIN, MV.PIN) end
          b:SetScript("OnEnter", pinEnter)
          b:SetScript("OnLeave", function() GameTooltip:Hide() end)
          b:SetScript("OnClick", function(self) if ns.MapPins and ns.MapPins.ShowCard then ns.MapPins:ShowCard(self.data) end end)
        end
        b.data = d
        local big = d.kind == "rare" or d.kind == "boss"
        b:SetSize(big and MV.PIN + 6 or MV.PIN, big and MV.PIN + 6 or MV.PIN)
        if ns.MapPins and ns.MapPins.Paint and b.ring then ns.Safe("mapview:paint", ns.MapPins.Paint, b, d) end
        b:ClearAllPoints()
        b:SetPoint("CENTER", self.pinLayer, "TOPLEFT", px, -py)
        b:Show()
        self.pinUsed[#self.pinUsed + 1] = b
      end
    end
    self:UpdatePlayer()
  end

  function v:UpdatePlayer()
    local m, x, y = C.PlayerPosition("player")
    if not (self.artData and m == self.mapID and x and y) then self.player:Hide() return end
    local px, py = MV.ToView(self.st, x, y)
    self.player:ClearAllPoints()
    self.player:SetPoint("CENTER", self.pinLayer, "TOPLEFT", px, -py)
    local facing = C.Call("GetPlayerFacing")
    if facing and self.player.SetRotation then self.player:SetRotation(facing) end
    self.player:Show()
  end

  -- -------------------------------------------------------------- mouse
  host:EnableMouse(true)
  if host.EnableMouseWheel then host:EnableMouseWheel(true) end
  host:SetScript("OnMouseWheel", function(_, delta)
    local px, py = v:Cursor()
    if not px then return end
    MV.ZoomAt(v.st, delta > 0 and 1.25 or 0.8, px, py)
    v:Layout()
  end)
  local function inkClear()
    if ns.Routes then ns.Routes.Draw(v.ink, {}, 1, 1) end
  end
  host:SetScript("OnMouseDown", function(_, button)
    local px, py = v:Cursor()
    if not px then return end
    v.down = { button = button, x = px, y = py, lx = px, ly = py, moved = false }
    if button == "LeftButton" and v.mode == "line" and v.route then
      local mx, my = MV.FromView(v.st, px, py)
      v.stroke = { mx, my }
    end
  end)
  host:SetScript("OnMouseUp", function(_, button)
    local d = v.down
    v.down = nil
    if not d then return end
    local px, py = v:Cursor()
    px, py = px or d.lx, py or d.ly
    local mx, my = MV.FromView(v.st, px, py)
    if v.stroke then
      local pts = v.stroke
      v.stroke = nil
      inkClear()
      if #pts >= 4 then
        local ok, why = ns.Routes:AddLine(v.route, v.color, pts)
        if not ok and why ~= "too short" then ns.Print("line not added: %s", tostring(why)) end
      end
      v:Refresh()
      return
    end
    if d.moved then return end
    if button == "RightButton" then v:GoUp() return end
    if not (mx and my and mx >= 0 and mx <= 1 and my >= 0 and my <= 1) then return end
    if v.mode == "mark" and v.route then
      ns.Routes:AddMark(v.route, mx, my, v.icon, nil, v.color)
      v:Refresh()
    elseif v.mode == "text" and v.route then
      local route, color = v.route, v.color
      UI:TextDialog("Map label", "", "paste", function(text)
        local ok, why = ns.Routes:AddMark(route, mx, my, 0, text, color)
        v:Refresh()
        if not ok then return false, "label not added: " .. tostring(why) end
        return true
      end)
      if UI.dialog and UI.dialog.hint then UI.dialog.hint:SetText("Type the label, then Accept.") end
    elseif v.mode == "erase" and v.route then
      if ns.Routes:EraseNear(v.route, mx, my, MV.ERASE / (v.st.zoom or 1)) then v:Refresh() end
    elseif v.mode == "move" or not v.route then
      -- open the zone under the cursor
      local info = C.Call("C_Map.GetMapInfoAtPosition", v.mapID, mx, my)
      local child = type(info) == "table" and readable(info.mapID)
      if child and child ~= v.mapID then v:SetMap(child) end
    end
  end)
  local tick = 0
  host:SetScript("OnUpdate", function(_, elapsed)
    tick = tick + (elapsed or 0)
    local d = v.down
    if d then
      local px, py = v:Cursor()
      if px then
        if math.abs(px - d.x) + math.abs(py - d.y) > 4 then d.moved = true end
        if v.stroke then
          local mx, my = MV.FromView(v.st, px, py)
          local n = #v.stroke
          local lx, ly = MV.ToView(v.st, v.stroke[n - 1], v.stroke[n])
          if (px - lx) ^ 2 + (py - ly) ^ 2 >= 9 then
            v.stroke[n + 1], v.stroke[n + 2] = mx, my
            -- the live line, drawn as a temporary route
            local ints = {}
            for i, val in ipairs(v.stroke) do ints[i] = math.floor(val * 1000 + 0.5) end
            local W, H = MV.Size(v.st)
            local ox, oy = MV.Origin(v.st)
            ns.Routes.Draw(v.ink, { { lines = { { c = v.color, p = ints } }, marks = {} } }, W, H, ox, oy, 3, 16)
          end
        elseif d.moved and (d.button == "RightButton" or v.mode == "move" or not v.route) then
          MV.Pan(v.st, px - d.lx, py - d.ly)
          v:Layout()
        end
        d.lx, d.ly = px, py
      end
    end
    if tick >= 0.2 then
      tick = 0
      if not d then v:UpdatePlayer() end
    end
  end)
  host:SetScript("OnSizeChanged", function() v:Layout() end)
  v:SetScript("OnShow", function() v:Layout() end)
  v:PaintTools()
  return v
end

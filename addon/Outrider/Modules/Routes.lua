-- Modules/Routes.lua
-- Routes you draw on a map (Gary, 2026-11-24: "this level of map integration",
-- FojjiCore ideas). A route belongs to one map (a zone, a city or a dungeon
-- level) and holds freehand lines in a few colors, raid-icon markers and text
-- labels. Routes are account-wide (every character sees them), drawn on
-- Outrider's own map panel, on the world map and as dots on the minimap.
-- Sharing is a button press: a route goes to your party or guild over the
-- addon channel (hard rule 10), or as an export string. Received routes are
-- kept with the sender's name and start hidden until you switch them on.
-- Nothing here touches anything protected: lines are plain textures.
--
-- Stored in ns.db.global.routes = { next = n, list = { [id] = route } }
--   route = { id, name, mapID, author, made, shown, from?,
--             lines = { { c = color, s = seq, p = { x1, y1, x2, y2, ... } } },
--             marks = { { x, y, k = icon (0 = text only, 1-8 raid icons), t = text?, c = color, s = seq } } }
-- Positions are whole numbers 0..1000 across the map (a zone map: a few yards).

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Routes", {
  title = "Map routes you draw",
  phase = "P3",
  order = 37,
  defaults = { receive = true, minimap = true },
})
ns.Routes = M

M.COLORS = {
  { 1.00, 1.00, 1.00 }, -- white
  { 1.00, 0.35, 0.55 }, -- pink
  { 0.35, 0.65, 1.00 }, -- blue
  { 0.40, 0.95, 0.45 }, -- green
  { 1.00, 0.85, 0.25 }, -- yellow
  { 1.00, 0.50, 0.15 }, -- orange
  { 0.75, 0.45, 1.00 }, -- purple
}
M.COLOR_NAMES = { "white", "pink", "blue", "green", "yellow", "orange", "purple" }
M.ICONS = { "star", "circle", "diamond", "triangle", "moon", "square", "cross", "skull" }
M.MAX_ROUTES = 200
M.MAX_LINES = 60
M.MAX_POINTS = 300   -- per line
M.MAX_MARKS = 60
M.MAX_TEXT = 40
M.MAX_NAME = 40
M.MIN_STEP = 4       -- points closer than this (of 1000) are dropped while drawing
M.DOT_STEP = 25      -- minimap dots: one every 2.5% of the map along a line
M.EXPORT_TAG = "OTRROUTE:"

function M.IconPath(k)
  k = tonumber(k) or 0
  if k < 1 or k > 8 then return nil end
  return "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. k
end

function M:Store()
  local g = ns.db.global
  g.routes = type(g.routes) == "table" and g.routes or {}
  local s = g.routes
  s.list = type(s.list) == "table" and s.list or {}
  s.next = tonumber(s.next) or 0
  return s
end

function M:Get(id) return self:Store().list[tonumber(id) or id] end

-- every route, newest first; optional mapID filter
function M:List(mapID)
  local out = {}
  for _, r in pairs(self:Store().list) do
    if not mapID or r.mapID == mapID then out[#out + 1] = r end
  end
  table.sort(out, function(a, b) return (a.id or 0) > (b.id or 0) end)
  return out
end

-- routes switched on for a map
function M:For(mapID)
  local out = {}
  if not (self.enabled and mapID) then return out end
  for _, r in ipairs(self:List(mapID)) do if r.shown then out[#out + 1] = r end end
  return out
end

local function clampInt(v)
  v = tonumber(v)
  if not v or v ~= v then return nil end
  v = math.floor(v + 0.5)
  if v < 0 or v > 1000 then return nil end
  return v
end
M.ClampInt = clampInt

local function cleanText(t, max)
  if type(t) ~= "string" then return nil end
  t = t:gsub("|", ""):gsub("[%c]", " "):match("^%s*(.-)%s*$")
  if t == "" then return nil end
  return t:sub(1, max)
end
M.CleanText = cleanText

local function mapName(mapID)
  local info = C.Call("C_Map.GetMapInfo", mapID)
  return type(info) == "table" and C.Readable(info.name) and info.name or ("map " .. tostring(mapID))
end

function M:Changed(id)
  ns.Events:Fire("OTR_ROUTES_CHANGED", id)
end

function M:New(mapID, name)
  mapID = tonumber(mapID)
  if not mapID then return nil, "no map" end
  local s = self:Store()
  local n = 0
  for _ in pairs(s.list) do n = n + 1 end
  if n >= M.MAX_ROUTES then return nil, "too many routes" end
  s.next = s.next + 1
  local me = ns.db.key and ns.db.key:match("^([^%-]+)") or "you"
  local r = { id = s.next, mapID = mapID, name = cleanText(name, M.MAX_NAME) or (mapName(mapID) .. " by " .. me),
    author = me, made = time(), shown = true, lines = {}, marks = {}, seq = 0 }
  s.list[r.id] = r
  self:Info("route %d made on map %d (%s)", r.id, mapID, r.name)
  self:Changed(r.id)
  return r
end

local function nextSeq(r)
  r.seq = (tonumber(r.seq) or 0) + 1
  return r.seq
end

-- Drop points that sit within MIN_STEP of the last kept one (the mouse
-- reports many while drawing); the last point is always kept.
function M.Simplify(pts, step)
  step = step or M.MIN_STEP
  local out = {}
  local n = math.floor(#pts / 2)
  local lx, ly
  for i = 1, n do
    local x, y = clampInt(pts[i * 2 - 1]), clampInt(pts[i * 2])
    if x and y then
      local far = not lx or (x - lx) ^ 2 + (y - ly) ^ 2 >= step * step
      if far or i == n then
        if lx and x == lx and y == ly then
          -- same spot again: skip
        else
          out[#out + 1] = x out[#out + 1] = y
          lx, ly = x, y
        end
      end
    end
    if #out >= M.MAX_POINTS * 2 then break end
  end
  return out
end

-- pts: flat list of 0..1 map positions { x1, y1, x2, y2, ... }
function M:AddLine(id, color, pts)
  local r = self:Get(id)
  if not r then return nil, "no route" end
  if #r.lines >= M.MAX_LINES then return nil, "too many lines" end
  local ints = {}
  for i, v in ipairs(pts or {}) do ints[i] = (tonumber(v) or -1) * 1000 end
  local p = M.Simplify(ints)
  if #p < 4 then return nil, "too short" end
  local line = { c = math.max(1, math.min(#M.COLORS, tonumber(color) or 1)), s = nextSeq(r), p = p }
  r.lines[#r.lines + 1] = line
  self:Changed(r.id)
  return line
end

function M:AddMark(id, x, y, icon, text, color)
  local r = self:Get(id)
  if not r then return nil, "no route" end
  if #r.marks >= M.MAX_MARKS then return nil, "too many markers" end
  local ix, iy = clampInt((tonumber(x) or -1) * 1000), clampInt((tonumber(y) or -1) * 1000)
  if not (ix and iy) then return nil, "off the map" end
  local k = math.max(0, math.min(8, math.floor(tonumber(icon) or 1)))
  local t = cleanText(text, M.MAX_TEXT)
  if k == 0 and not t then return nil, "empty label" end
  local mark = { ix, iy, k = k, t = t, c = math.max(1, math.min(#M.COLORS, tonumber(color) or 1)), s = nextSeq(r) }
  r.marks[#r.marks + 1] = mark
  self:Changed(r.id)
  return mark
end

-- take back the last line or marker
function M:Undo(id)
  local r = self:Get(id)
  if not r then return false end
  local best, list, at
  for _, kind in ipairs({ "lines", "marks" }) do
    for i, e in ipairs(r[kind]) do
      if not best or (e.s or 0) > (best.s or 0) then best, list, at = e, r[kind], i end
    end
  end
  if not best then return false end
  table.remove(list, at)
  self:Changed(r.id)
  return true
end

-- squared distance from point p to the segment a-b (all 0..1000)
function M.SegDist2(px, py, ax, ay, bx, by)
  local dx, dy = bx - ax, by - ay
  local len = dx * dx + dy * dy
  local t = len > 0 and math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / len)) or 0
  local cx, cy = ax + t * dx, ay + t * dy
  return (px - cx) ^ 2 + (py - cy) ^ 2
end

-- remove the line or marker nearest to (x, y) (0..1) within radius (0..1)
function M:EraseNear(id, x, y, radius)
  local r = self:Get(id)
  if not r then return false end
  local px, py, rad = x * 1000, y * 1000, (radius or 0.02) * 1000
  local best, list, at = rad * rad, nil, nil
  for i, mk in ipairs(r.marks) do
    local d = (mk[1] - px) ^ 2 + (mk[2] - py) ^ 2
    if d <= best then best, list, at = d, r.marks, i end
  end
  for i, ln in ipairs(r.lines) do
    local p = ln.p
    for j = 1, #p / 2 - 1 do
      local d = M.SegDist2(px, py, p[j * 2 - 1], p[j * 2], p[j * 2 + 1], p[j * 2 + 2])
      if d < best then best, list, at = d, r.lines, i end
    end
  end
  if not list then return false end
  table.remove(list, at)
  self:Changed(r.id)
  return true
end

function M:Rename(id, name)
  local r = self:Get(id)
  name = cleanText(name, M.MAX_NAME)
  if not (r and name) then return false end
  r.name = name
  self:Changed(r.id)
  return true
end

function M:Delete(id)
  local s = self:Store()
  local r = s.list[tonumber(id) or id]
  if not r then return false end
  s.list[r.id] = nil
  self:Info("route %d deleted", r.id)
  self:Changed(r.id)
  return true
end

function M:SetShown(id, on)
  local r = self:Get(id)
  if not r then return false end
  r.shown = on and true or false
  self:Changed(r.id)
  return true
end

-- ------------------------------------------------------------------ sharing
-- what travels: no ids, sequence numbers or flags of ours
function M.Pack(r)
  local lines, marks = {}, {}
  for i, l in ipairs(r.lines or {}) do lines[i] = { l.c, l.p } end
  for i, m in ipairs(r.marks or {}) do marks[i] = { m[1], m[2], m.k, m.t, m.c } end
  return { n = r.name, m = r.mapID, a = r.author, l = lines, k = marks }
end

-- A route from someone else (or a pasted string): every field checked,
-- anything odd dropped. Returns a clean route table without an id, or nil.
function M.Unpack(t)
  if type(t) ~= "table" then return nil, "not a route" end
  local mapID = tonumber(t.m)
  if not mapID or mapID < 1 or mapID > 100000 or mapID % 1 ~= 0 then return nil, "bad map" end
  local r = { mapID = mapID, name = cleanText(t.n, M.MAX_NAME) or ("route on map " .. mapID),
    author = cleanText(t.a, 24) or "?", lines = {}, marks = {}, seq = 0 }
  for _, l in ipairs(type(t.l) == "table" and t.l or {}) do
    if #r.lines >= M.MAX_LINES then break end
    if type(l) == "table" and type(l[2]) == "table" then
      local raw = {}
      for i = 1, math.min(#l[2], M.MAX_POINTS * 2) do raw[i] = l[2][i] end
      local p = M.Simplify(raw, 1)
      if #p >= 4 then
        r.seq = r.seq + 1
        r.lines[#r.lines + 1] = { c = math.max(1, math.min(#M.COLORS, math.floor(tonumber(l[1]) or 1))), s = r.seq, p = p }
      end
    end
  end
  for _, m in ipairs(type(t.k) == "table" and t.k or {}) do
    if #r.marks >= M.MAX_MARKS then break end
    if type(m) == "table" then
      local x, y = clampInt(m[1]), clampInt(m[2])
      local k = math.max(0, math.min(8, math.floor(tonumber(m[3]) or 1)))
      local text = cleanText(m[4], M.MAX_TEXT)
      if x and y and (k > 0 or text) then
        r.seq = r.seq + 1
        r.marks[#r.marks + 1] = { x, y, k = k, t = text, c = math.max(1, math.min(#M.COLORS, math.floor(tonumber(m[5]) or 1))), s = r.seq }
      end
    end
  end
  if #r.lines == 0 and #r.marks == 0 then return nil, "empty route" end
  return r
end

function M:Add(clean, from)
  local s = self:Store()
  local n = 0
  for _ in pairs(s.list) do n = n + 1 end
  if n >= M.MAX_ROUTES then return nil, "too many routes" end
  -- the same route from the same person replaces the old copy
  for _, old in pairs(s.list) do
    if from and old.from == from and old.name == clean.name and old.mapID == clean.mapID then
      clean.id, clean.shown, clean.made, clean.from = old.id, old.shown, time(), from
      s.list[old.id] = clean
      self:Changed(old.id)
      return clean
    end
  end
  s.next = s.next + 1
  clean.id, clean.made, clean.from = s.next, time(), from
  clean.shown = not from      -- imported by you: on; received: off until you switch it on
  s.list[clean.id] = clean
  self:Changed(clean.id)
  return clean
end

function M:Export(id)
  local r = self:Get(id)
  if not r then return nil end
  return M.EXPORT_TAG .. ns.Serialize.Base64Encode(ns.Serialize.Encode(M.Pack(r)))
end

function M:Import(text)
  if type(text) ~= "string" then return nil, "nothing pasted" end
  local body = text:gsub("%s", ""):match("^" .. M.EXPORT_TAG:gsub("%p", "%%%0") .. "(.+)$")
  if not body then return nil, "not an Outrider route" end
  local ok, raw = pcall(ns.Serialize.Base64Decode, body)
  if not ok or type(raw) ~= "string" then return nil, "damaged text" end
  local ok2, t = pcall(ns.Serialize.Decode, raw)
  if not ok2 then return nil, "damaged text" end
  local clean, why = M.Unpack(t)
  if not clean then return nil, why end
  local r, why2 = self:Add(clean, nil)
  if r then self:Info("route imported: %s (map %d)", r.name, r.mapID) end
  return r, why2
end

-- channel: PARTY, RAID or GUILD (a button press; never automatic)
function M:Share(id, channel)
  local r = self:Get(id)
  if not r then return false, "no route" end
  if not (ns.Comm and ns.Comm.enabled) then return false, "sharing module is off" end
  local ok, why = ns.Comm:Send("ROUTE", M.Pack(r), channel)
  self:Info("route %d shared on %s: %s", r.id, tostring(channel), ok and "sent" or tostring(why))
  return ok, why
end

function M:OnReceive(data, sender)
  if not self:Settings().receive then return end
  local clean = M.Unpack(data)
  if not clean then return end
  local r = self:Add(clean, sender)
  if r and not self.toldReceive then
    self.toldReceive = true
    ns.Print("%s shared a map route: %s (Map and places > Map and routes)", tostring(sender), r.name)
  end
end

-- ------------------------------------------------------------------ dots and drawing helpers
-- Dots along the shown routes of a map, for the minimap: { kind = "route", x, y, color }
function M.Sample(p, step)
  local out = {}
  step = step or M.DOT_STEP
  local carry = 0
  for j = 1, #p / 2 - 1 do
    local ax, ay, bx, by = p[j * 2 - 1], p[j * 2], p[j * 2 + 1], p[j * 2 + 2]
    local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
    local d = carry
    while d <= len do
      local t = len > 0 and d / len or 0
      out[#out + 1] = { ax + (bx - ax) * t, ay + (by - ay) * t }
      d = d + step
    end
    carry = d - len
  end
  return out
end

M.pinCache = {}
function M:Pins(mapID)
  if not (self.enabled and mapID) then return {} end
  local hit = self.pinCache[mapID]
  if hit then return hit end
  local out = {}
  for _, r in ipairs(self:For(mapID)) do
    for _, l in ipairs(r.lines) do
      local c = M.COLORS[l.c] or M.COLORS[1]
      for _, pt in ipairs(M.Sample(l.p)) do
        out[#out + 1] = { kind = "route", mapID = mapID, x = pt[1] / 1000, y = pt[2] / 1000, color = c, name = r.name }
      end
    end
    for _, mk in ipairs(r.marks) do
      out[#out + 1] = { kind = "routemark", mapID = mapID, x = mk[1] / 1000, y = mk[2] / 1000, icon = M.IconPath(mk.k),
        color = M.COLORS[mk.c] or M.COLORS[1], name = mk.t or r.name, text = mk.t }
    end
  end
  self.pinCache[mapID] = out
  return out
end

-- Draw a route's lines and marks onto a frame of size w x h (0..1 map ->
-- pixels with ox, oy offsets). Pools live on the frame. Used by the map
-- panel and the world map layer. Returns lines, marks drawn.
local warnedLine
function M.Draw(frame, routes, w, h, ox, oy, thick, markSize)
  frame.rLines, frame.rMarks = frame.rLines or {}, frame.rMarks or {}
  frame.rUsedL, frame.rUsedM = frame.rUsedL or {}, frame.rUsedM or {}
  for _, l in ipairs(frame.rUsedL) do l:Hide() frame.rLines[#frame.rLines + 1] = l end
  for _, m in ipairs(frame.rUsedM) do m:Hide() frame.rMarks[#frame.rMarks + 1] = m end
  frame.rUsedL, frame.rUsedM = {}, {}
  ox, oy = ox or 0, oy or 0
  local canLine = type(frame.CreateLine) == "function"
  if not canLine and not warnedLine then
    warnedLine = true
    M:Warn("this client has no line drawing (CreateLine): routes show as markers only")
  end
  local nl, nm = 0, 0
  for _, r in ipairs(routes) do
    if canLine then
      for _, ln in ipairs(r.lines) do
        local c = M.COLORS[ln.c] or M.COLORS[1]
        local p = ln.p
        for j = 1, #p / 2 - 1 do
          local seg = table.remove(frame.rLines) or frame:CreateLine(nil, "OVERLAY")
          if seg then
            seg:SetThickness(thick or 3)
            seg:SetColorTexture(c[1], c[2], c[3], 0.95)
            seg:SetStartPoint("TOPLEFT", frame, ox + p[j * 2 - 1] / 1000 * w, -(oy + p[j * 2] / 1000 * h))
            seg:SetEndPoint("TOPLEFT", frame, ox + p[j * 2 + 1] / 1000 * w, -(oy + p[j * 2 + 2] / 1000 * h))
            seg:Show()
            frame.rUsedL[#frame.rUsedL + 1] = seg
            nl = nl + 1
          end
        end
      end
    end
    for _, mk in ipairs(r.marks) do
      local f = table.remove(frame.rMarks)
      if not f then
        f = CreateFrame("Frame", nil, frame)
        f.icon = f:CreateTexture(nil, "OVERLAY")
        f.icon:SetAllPoints()
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.text:SetPoint("CENTER")
        if f.text.SetShadowOffset then f.text:SetShadowOffset(1, -1) end
      end
      local size = markSize or 16
      f:SetSize(size, size)
      f:SetFrameLevel((frame.GetFrameLevel and frame:GetFrameLevel() or 1) + 3)
      local c = M.COLORS[mk.c] or M.COLORS[1]
      local path = M.IconPath(mk.k)
      if path then
        f.icon:SetTexture(path) f.icon:Show()
        f.text:ClearAllPoints() f.text:SetPoint("LEFT", f, "RIGHT", 2, 0)
      else
        f.icon:Hide()
        f.text:ClearAllPoints() f.text:SetPoint("CENTER")
      end
      f.text:SetText(mk.t or "")
      f.text:SetTextColor(c[1], c[2], c[3], 1)
      f:ClearAllPoints()
      f:SetPoint("CENTER", frame, "TOPLEFT", ox + mk[1] / 1000 * w, -(oy + mk[2] / 1000 * h))
      f:Show()
      frame.rUsedM[#frame.rUsedM + 1] = f
      nm = nm + 1
    end
  end
  return nl, nm
end

-- ------------------------------------------------------------------ world map layer
-- Shown routes drawn on the world map canvas, under Outrider's pins.
function M:WorldLayer()
  if self.layer then return self.layer end
  local canvas = self.map:GetCanvas()
  local f = CreateFrame("Frame", nil, canvas)
  f:SetPoint("TOPLEFT")
  f:SetFrameLevel((canvas.GetFrameLevel and canvas:GetFrameLevel() or 1) + 2)
  self.layer = f
  return f
end

function M:RefreshWorld()
  if not (self.map and self.enabled) then return end
  local mapID = self.map.GetMapID and self.map:GetMapID()
  local routes = self:For(mapID)
  if #routes == 0 and not self.layer then return end
  local canvas = self.map:GetCanvas()
  local f = self:WorldLayer()
  local w, h = canvas:GetWidth(), canvas:GetHeight()
  f:SetSize(w, h)
  local scale = canvas.GetScale and canvas:GetScale() or 1
  local thick = 3 / (scale > 0 and scale or 1)
  local nl, nm = M.Draw(f, routes, w, h, 0, 0, math.max(1.5, thick), 16 / (scale > 0 and scale or 1))
  f:SetShown(#routes > 0)
  if #routes > 0 and not (self.loggedWorld or {})[mapID] then
    self.loggedWorld = self.loggedWorld or {}
    self.loggedWorld[mapID] = true
    self:Info("world map %s: %d routes drawn (%d line pieces, %d markers)", tostring(mapID), #routes, nl, nm)
  end
end

-- ------------------------------------------------------------------ module
function M:OnEnable()
  self:Store()
  if ns.Comm then ns.Comm.KNOWN_TYPES.ROUTE = true end
  self:On("OTR_ROUTES_CHANGED", function(mod)
    mod.pinCache = {}
    if mod.map and mod.map:IsShown() then ns.Safe("routes:world", mod.RefreshWorld, mod) end
    if ns.Hub and ns.Hub.Refresh then ns.Hub:Refresh() end
  end)
  self:On("OTR_COMM", function(mod, _, kind, data, sender)
    if kind == "ROUTE" then mod:OnReceive(data, sender) end
  end)
  local map = rawget(_G, "WorldMapFrame")
  if map and map.GetCanvas then
    self.map = map
    if not self.hooked then
      self.hooked = true
      map:HookScript("OnShow", function() if M.enabled then ns.Safe("routes:world", M.RefreshWorld, M) end end)
      if type(map.OnMapChanged) == "function" then
        hooksecurefunc(map, "OnMapChanged", function() if M.enabled then ns.Safe("routes:world", M.RefreshWorld, M) end end)
      end
      local canvas = map:GetCanvas()
      if canvas and canvas.HookScript then
        canvas:HookScript("OnSizeChanged", function() if M.enabled and map:IsShown() then ns.Safe("routes:world", M.RefreshWorld, M) end end)
      end
    end
  end
end

function M:OnDisable()
  if self.layer then self.layer:Hide() end
  self.pinCache = {}
end

function M:Activity()
  local n, shown, recv = 0, 0, 0
  for _, r in pairs(self:Store().list) do
    n = n + 1
    if r.shown then shown = shown + 1 end
    if r.from then recv = recv + 1 end
  end
  return string.format("%d routes (%d shown, %d from other players)", n, shown, recv)
end

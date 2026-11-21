-- Modules/ZoneLevels.lua  (Gary, 2026-11-16: "a world map overlay that tells
-- me what level the area is, so I can tell: I'm level 15, I want to go to
-- this area to level up")
-- On a continent map every zone gets its level range over it ("Westfall
-- 10-20"), coloured for this character: green = your level, yellow = a few
-- levels up, red = too high, grey = too low for XP. On a zone map the
-- zone's own range shows at the top.
-- Where the numbers come from (never typed in by hand, hard rule 7):
--   seen      hostile creatures Outrider met in that zone (Discovery), when
--             there are at least SEEN of them: what Forever really has
--   classic   the creature pack (Classic data, QuestieDB), when not enough
--             were seen yet; Forever may differ, the tooltip says so
-- The range comes from the busiest WINDOW of creature levels (most of a
-- zone's creatures sit within a dozen levels), then its 10th to 90th
-- percentile: city guards at 55, a stray dragon or level 1 pets don't
-- stretch it (Gary's first look, 2026-11-16: Elwynn read 3-30). Rares and
-- bosses are left out; capital cities get no label.
-- On a zone map the zone is cut into a GRID x GRID grid and every part with
-- enough creatures gets its own small range where they spawn ("5-7"), so
-- the areas inside a zone show too (Gary asked the same day). Labels are our own font strings on the map canvas,
-- drawn above Blizzard's pins (the art of an explored area is a pin and hid
-- the numbers; Gary, 2026-11-16: "once an area is discovered, the numbers go
-- away"); nothing of Blizzard's is changed. Data only.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("ZoneLevels", {
  title = "Zone levels on the world map",
  phase = "P3",
  order = 55,
  defaults = { show = true },
})
ns.ZoneLevels = M

M.LEVEL = 1000        -- frame levels above the map canvas: over explored-area art and pins
M.SEEN = 8            -- creatures seen in a zone before their levels win over the pack
M.WINDOW = 12         -- levels: the busiest window of this width is the zone's
M.GRID = 4            -- zone map: areas per side
M.AREA_MIN = 3        -- creatures in an area before it gets a label
M.CITIES = { ["Stormwind City"] = true, Ironforge = true, Darnassus = true, Orgrimmar = true, ["Thunder Bluff"] = true,
  Undercity = true, Dalaran = true }
M.TYPE_CONTINENT, M.TYPE_ZONE = 2, 3

function M:OnInitialize() self.cache, self.labels, self.used = {}, {}, {} end

local function percentile(sorted, p)
  if #sorted == 0 then return nil end
  local i = math.max(1, math.min(#sorted, math.floor(p * (#sorted - 1) + 1.5)))
  return sorted[i]
end

-- lo, hi from a list of levels: the busiest window, then 10th-90th percentile (pure).
function M.Trim(levels, window)
  local t = {}
  for _, v in ipairs(levels) do if type(v) == "number" and v > 1 then t[#t + 1] = v end end
  if #t == 0 then return nil end
  table.sort(t)
  window = window or M.WINDOW
  local bestI, bestJ, j = 1, 1, 1
  for i = 1, #t do
    if j < i then j = i end
    while j < #t and t[j + 1] - t[i] <= window do j = j + 1 end
    if j - i > bestJ - bestI then bestI, bestJ = i, j end
  end
  local w = {}
  for k = bestI, bestJ do w[#w + 1] = t[k] end
  return percentile(w, 0.1), percentile(w, 0.9)
end

local function isMob(e)
  local cls = e.classification
  return tonumber(e.level) and e.creatureType and e.creatureType ~= "Critter" and not e.title
    and not (e.roles and next(e.roles)) and cls ~= "rare" and cls ~= "rareelite" and cls ~= "worldboss"
end

-- Level range for one zone: lo, hi, source ("seen" | "guide" | "classic"), count.
-- "guide": the leveling knowledge base (Data/Leveling.lua, Wowhead's Forever
-- guides) beats Classic data, so new zones like Riverglades get a range.
function M:Range(mapID)
  local c = self.cache[mapID]
  if c then return c.lo, c.hi, c.source, c.n end
  local seen = {}
  local d = ns.db.global.discovered
  for _, e in pairs(type(d) == "table" and type(d.npcs) == "table" and d.npcs or {}) do
    if e.mapID == mapID and isMob(e) then seen[#seen + 1] = tonumber(e.level) end
  end
  local lo, hi, source, n
  if #seen >= M.SEEN then
    lo, hi = M.Trim(seen)
    source, n = "seen", #seen
  end
  local guide = not lo and ns.Travel and ns.Data:Get("zoneguide", tostring(ns.Travel.ZoneName(mapID) or ""))
  if guide and guide.lo and guide.hi then
    lo, hi, source, n = guide.lo, guide.hi, "guide", 0
  elseif not lo then
    local mobs = ns.Finder and ns.Finder:Mobs()
    local rows = mobs and mobs[mapID]
    local levels = {}
    for _, r in ipairs(rows or {}) do
      local rlo, rhi, rank = r[3], r[4], r[5]
      if type(rlo) == "number" and type(rhi) == "number" and rank ~= 2 and rank ~= 3 and rank ~= 4 then
        levels[#levels + 1] = rlo
        levels[#levels + 1] = rhi
      end
    end
    if #levels >= 6 then
      lo, hi = M.Trim(levels)
      source, n = "classic", #levels / 2
    end
  end
  if lo and hi and lo > hi then lo, hi = hi, lo end
  self.cache[mapID] = { lo = lo, hi = hi, source = source, n = n }
  return lo, hi, source, n
end

-- Areas inside one zone: { x, y, lo, hi, source } where creatures spawn.
function M:Areas(mapID)
  local key = "areas-" .. mapID
  if self.cache[key] then return self.cache[key].list end
  local G = M.GRID
  local cells = {}
  local function cell(x, y)
    if type(x) ~= "number" or type(y) ~= "number" or x <= 0 or y <= 0 or x >= 1 or y >= 1 then return nil end
    local k = math.floor(x * G) * G + math.floor(y * G)
    local c = cells[k]
    if not c then c = { seen = {}, pack = {}, sx = 0, sy = 0, n = 0 } cells[k] = c end
    c.sx, c.sy, c.n = c.sx + x, c.sy + y, c.n + 1
    return c
  end
  local d = ns.db.global.discovered
  for _, e in pairs(type(d) == "table" and type(d.npcs) == "table" and d.npcs or {}) do
    if e.mapID == mapID and isMob(e) then
      local c = cell(e.x, e.y)
      if c then c.seen[#c.seen + 1] = tonumber(e.level) end
    end
  end
  local mobs = ns.Finder and ns.Finder:Mobs()
  for _, r in ipairs(mobs and mobs[mapID] or {}) do
    local rlo, rhi, rank, pts = r[3], r[4], r[5], r[6]
    if type(rlo) == "number" and type(rhi) == "number" and rank ~= 2 and rank ~= 3 and rank ~= 4 and type(pts) == "table" then
      local done = {}
      for i = 1, #pts - 1, 2 do
        local c = cell(pts[i], pts[i + 1])
        if c and not done[c] then
          done[c] = true
          c.pack[#c.pack + 1] = rlo
          c.pack[#c.pack + 1] = rhi
        end
      end
    end
  end
  local list = {}
  for _, c in pairs(cells) do
    local levels, source = c.seen, "seen"
    if #levels < M.AREA_MIN then levels, source = c.pack, "classic" end
    local enough = (source == "seen" and #levels >= M.AREA_MIN) or #levels >= M.AREA_MIN * 2
    if enough then
      local lo, hi = M.Trim(levels, 8)
      if lo then list[#list + 1] = { x = c.sx / c.n, y = c.sy / c.n, lo = lo, hi = hi, source = source } end
    end
  end
  table.sort(list, function(a, b) if a.y ~= b.y then return a.y < b.y end return a.x < b.x end)
  self.cache[key] = { list = list }
  return list
end

-- Colour name for a range at this level (pure).
function M.Color(lo, hi, level)
  if hi < level - 5 then return "muted" end      -- grey: little XP left there
  if lo > level + 4 then return "bad" end        -- red: too high
  if lo > level + 1 then return "warn" end       -- yellow: a stretch
  return "good"                                   -- green: your level
end

M.WORDS = { muted = "too low for good XP", bad = "too high for you", warn = "a few levels above you", good = "right for your level" }

-- Labels for the map on show: { mapID, name, lo, hi, source, x, y, color } (pure but for the client calls).
function M:Labels(mapID)
  local info = C.Call("C_Map.GetMapInfo", mapID)
  if type(info) ~= "table" then return {} end
  local level = C.Call("UnitLevel", "player") or 1
  local out = {}
  local function add(id, name, x, y)
    local lo, hi, source = self:Range(id)
    if lo then
      out[#out + 1] = { mapID = id, name = name, lo = lo, hi = hi, source = source, x = x, y = y, color = M.Color(lo, hi, level) }
    end
  end
  if info.mapType == M.TYPE_ZONE then
    add(mapID, info.name, 0.5, 0.06)
    for _, a in ipairs(self:Areas(mapID)) do
      out[#out + 1] = { mapID = mapID, area = true, name = info.name, lo = a.lo, hi = a.hi, source = a.source, x = a.x, y = a.y,
        color = M.Color(a.lo, a.hi, level) }
    end
  elseif info.mapType == M.TYPE_CONTINENT then
    for _, kid in ipairs(C.Call("C_Map.GetMapChildrenInfo", mapID) or {}) do
      local k = C.Call("C_Map.GetMapInfo", kid.mapID)
      if type(k) == "table" and k.mapType == M.TYPE_ZONE and (k.parentMapID == mapID or k.parentMapID == nil)
        and not M.CITIES[k.name or kid.name or ""] then
        local x1, x2, y1, y2 = C.Call("C_Map.GetMapRectOnMap", kid.mapID, mapID)
        if type(x1) == "number" and type(y1) == "number" and x2 and y2 and x2 > x1 then
          add(kid.mapID, k.name or kid.name, (x1 + x2) / 2, (y1 + y2) / 2)
        end
      end
    end
  end
  return out
end

function M:Text(l)
  local range = l.lo == l.hi and tostring(l.lo) or string.format("%d-%d", l.lo, l.hi)
  if l.area then return range end
  return string.format("%s\n%s", tostring(l.name), range)
end

local function label(self, canvas, i)
  local f = self.labels[i]
  if not f then
    f = CreateFrame("Frame", nil, canvas)
    f:SetSize(240, 34)   -- wide: long names ("Western Plaguelands") are never cut to "..."
    f.text = f:CreateFontString(nil, "OVERLAY")
    f.text:SetAllPoints()
    if f.text.SetWordWrap then f.text:SetWordWrap(false) end
    if f.text.SetShadowOffset then f.text:SetShadowOffset(1, -1) end
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(fr)
      local l = fr.data
      if not l then return end
      GameTooltip:SetOwner(fr, "ANCHOR_RIGHT")
      GameTooltip:AddLine(string.format("%s%s: levels %d-%d", tostring(l.name), l.area and " (this area)" or "", l.lo, l.hi))
      GameTooltip:AddLine(M.WORDS[l.color] or "", ns.Theme:Color(l.color))
      GameTooltip:AddLine(l.source == "seen" and "From the creatures you met there."
        or l.source == "guide" and "From the WoW Forever leveling guides: checked once you meet the creatures there."
        or "From Classic creature data: Forever may differ until you've been there.", ns.Theme:Color("muted"))
      GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.labels[i] = f
  end
  f:SetParent(canvas)
  f:SetFrameLevel((canvas.GetFrameLevel and canvas:GetFrameLevel() or 1) + M.LEVEL)
  return f
end

function M:Hide()
  for _, f in ipairs(self.used) do f:Hide() end
  self.used = {}
end

function M:Refresh()
  self:Hide()
  local map = rawget(_G, "WorldMapFrame")
  if not (map and map.GetCanvas and map.GetMapID and self:Settings().show) then return end
  local mapID = map:GetMapID()
  if not mapID then return end
  local canvas = map:GetCanvas()
  local w, h = canvas:GetWidth(), canvas:GetHeight()
  local scale = canvas.GetScale and canvas:GetScale() or 1
  if scale <= 0 then scale = 1 end
  for i, l in ipairs(self:Labels(mapID)) do
    local f = label(self, canvas, i)
    f.data = l
    -- a size up (Gary, 2026-11-16: "slightly bigger, easier to see")
    if f.text.SetFontObject then f.text:SetFontObject(l.area and "GameFontNormal" or "GameFontNormalLarge") end
    f:SetSize(l.area and 70 or 260, l.area and 20 or 40)
    f.text:SetText(self:Text(l))
    f.text:SetTextColor(ns.Theme:Color(l.color))
    f:SetScale(1 / scale)
    f:ClearAllPoints()
    f:SetPoint("CENTER", canvas, "TOPLEFT", l.x * w * scale, -l.y * h * scale)
    f:Show()
    self.used[#self.used + 1] = f
  end
  if #self.used > 0 and not self.logged then
    self.logged = true
    self:Info("zone levels on map %d: %d zones", mapID, #self.used)
  end
end

function M:OnEnable()
  local map = rawget(_G, "WorldMapFrame")
  if not (map and map.HookScript) then return end
  if not M.hooked then
    M.hooked = true
    map:HookScript("OnShow", function() if M.enabled then ns.Safe("zonelevels", M.Refresh, M) end end)
    if type(map.OnMapChanged) == "function" then
      hooksecurefunc(map, "OnMapChanged", function() if M.enabled then ns.Safe("zonelevels", M.Refresh, M) end end)
    end
  end
  -- new creatures seen or a level up change the numbers and colours
  self:On("PLAYER_LEVEL_UP", function(mod) mod.cache = {} end)
  self:On("ZONE_CHANGED_NEW_AREA", function(mod) mod.cache = {} end)
end

function M:OnDisable() self:Hide() end

function M:Activity()
  return "level ranges over each zone on the world map (green = your level)"
end

ns.AddCommand("zonelevels", "[on|off]  level ranges over zones on the world map", function(arg)
  arg = (arg or ""):lower()
  local s = M:Settings()
  if arg == "on" or arg == "off" then s.show = arg == "on" end
  ns.Print("zone levels on the world map: %s", s.show and "on" or "off")
  M:Refresh()
end)

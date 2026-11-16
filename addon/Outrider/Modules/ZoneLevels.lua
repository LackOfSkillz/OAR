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
-- The range is the 10th to 90th percentile of creature levels, so a stray
-- elite or a level 1 critter does not stretch it. Rares and bosses are left
-- out. Labels are our own font strings on the map canvas, under Blizzard's
-- pins; nothing of Blizzard's is changed. Data only.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("ZoneLevels", {
  title = "Zone levels on the world map",
  phase = "P3",
  order = 55,
  defaults = { show = true },
})
ns.ZoneLevels = M

M.SEEN = 8            -- creatures seen in a zone before their levels win over the pack
M.TYPE_CONTINENT, M.TYPE_ZONE = 2, 3

function M:OnInitialize() self.cache, self.labels, self.used = {}, {}, {} end

local function percentile(sorted, p)
  if #sorted == 0 then return nil end
  local i = math.max(1, math.min(#sorted, math.floor(p * (#sorted - 1) + 1.5)))
  return sorted[i]
end

-- Level range for one zone: lo, hi, source ("seen" | "classic"), count.
function M:Range(mapID)
  local c = self.cache[mapID]
  if c then return c.lo, c.hi, c.source, c.n end
  local seen = {}
  local d = ns.db.global.discovered
  for _, e in pairs(type(d) == "table" and type(d.npcs) == "table" and d.npcs or {}) do
    local lvl = tonumber(e.level)
    local cls = e.classification
    if e.mapID == mapID and lvl and lvl > 1 and e.creatureType and e.creatureType ~= "Critter" and not e.title
      and not (e.roles and next(e.roles)) and cls ~= "rare" and cls ~= "rareelite" and cls ~= "worldboss" then
      seen[#seen + 1] = lvl
    end
  end
  local lo, hi, source, n
  if #seen >= M.SEEN then
    table.sort(seen)
    lo, hi, source, n = percentile(seen, 0.1), percentile(seen, 0.9), "seen", #seen
  else
    local mobs = ns.Finder and ns.Finder:Mobs()
    local rows = mobs and mobs[mapID]
    local los, his = {}, {}
    for _, r in ipairs(rows or {}) do
      local rlo, rhi, rank = r[3], r[4], r[5]
      if type(rlo) == "number" and type(rhi) == "number" and rhi > 1 and rank ~= 2 and rank ~= 3 and rank ~= 4 then
        los[#los + 1], his[#his + 1] = rlo, rhi
      end
    end
    if #los >= 3 then
      table.sort(los) table.sort(his)
      lo, hi, source, n = percentile(los, 0.1), percentile(his, 0.9), "classic", #los
    end
  end
  if lo and hi and lo > hi then lo, hi = hi, lo end
  self.cache[mapID] = { lo = lo, hi = hi, source = source, n = n }
  return lo, hi, source, n
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
  elseif info.mapType == M.TYPE_CONTINENT then
    for _, kid in ipairs(C.Call("C_Map.GetMapChildrenInfo", mapID) or {}) do
      local k = C.Call("C_Map.GetMapInfo", kid.mapID)
      if type(k) == "table" and k.mapType == M.TYPE_ZONE and (k.parentMapID == mapID or k.parentMapID == nil) then
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
  return string.format("%s\n%d-%d", tostring(l.name), l.lo, l.hi)
end

local function label(self, canvas, i)
  local f = self.labels[i]
  if not f then
    f = CreateFrame("Frame", nil, canvas)
    f:SetSize(130, 34)
    f.text = f:CreateFontString(nil, "OVERLAY")
    f.text:SetAllPoints()
    if f.text.SetFontObject then f.text:SetFontObject("GameFontNormalLarge") end
    if f.text.SetShadowOffset then f.text:SetShadowOffset(1, -1) end
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(fr)
      local l = fr.data
      if not l then return end
      GameTooltip:SetOwner(fr, "ANCHOR_RIGHT")
      GameTooltip:AddLine(string.format("%s: levels %d-%d", tostring(l.name), l.lo, l.hi))
      GameTooltip:AddLine(M.WORDS[l.color] or "", ns.Theme:Color(l.color))
      GameTooltip:AddLine(l.source == "seen" and "From the creatures you met there."
        or "From Classic creature data: Forever may differ until you've been there.", ns.Theme:Color("muted"))
      GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.labels[i] = f
  end
  f:SetParent(canvas)
  f:SetFrameLevel((canvas.GetFrameLevel and canvas:GetFrameLevel() or 1) + 1)
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

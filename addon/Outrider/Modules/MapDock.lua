-- Modules/MapDock.lua
-- An Outrider panel on the side of the world map (requirement 2026-11-24, FojjiCore
-- idea). It follows the map you're looking at: the dungeons in that zone
-- (click: its own map), the bosses on a dungeon map with what they drop, the
-- rares there, and the routes drawn on that map with an on/off click each,
-- plus "Draw on this map". Our own frame next to the world map, not inside it
-- (one owner per frame): it shows and hides with the map and never moves or
-- changes Blizzard's frame.

local _, ns = ...
local C, UI, Theme = ns.Compat, ns.UI, ns.Theme
local M = ns:NewModule("MapDock", {
  title = "Panel beside the world map",
  phase = "P3",
  order = 38,
  defaults = { on = true },
  yieldsTo = {},
})
ns.MapDock = M

M.W = 250
M.ROWS = 22

local function readable(v) return v ~= nil and C.Readable(v) and v or nil end

-- The rows for a map (pure apart from the data modules): { text, kind, go? }
function M:Rows(mapID)
  local out = {}
  local function add(text, kind, go, tip) out[#out + 1] = { text = text, kind = kind, go = go, tip = tip } end
  if not mapID then return out end
  local info = C.Call("C_Map.GetMapInfo", mapID)
  local name = type(info) == "table" and readable(info.name) or ("map " .. mapID)
  local ZL = ns.ZoneLevels
  local lo, hi
  if ZL and ZL.enabled and ZL.Range then lo, hi = ZL:Range(mapID) end
  local lv = lo and hi and (lo == hi and tostring(lo) or string.format("%d-%d", lo, hi))
  add(name .. (lv and ("  |cff888888levels " .. lv .. "|r") or ""), "title")
  -- dungeons whose entrance is on this map
  local D = ns.DungeonGuide
  if D and D.enabled and D.ByName then
    local here = {}
    for dname, d in pairs(D:ByName()) do if d.map == mapID then here[#here + 1] = dname end end
    table.sort(here)
    if #here > 0 then
      add("Dungeons here", "head")
      for _, dname in ipairs(here) do
        local meta = ns.Data:Get("dungeon", dname)
        local lvl = meta and meta.min and string.format("  |cff888888%d-%d|r", meta.min, meta.max or meta.min) or ""
        add("  " .. dname .. lvl, "dungeon", function()
          ns.MapPages.Open("dungeonmap", function()
            local p = ns.Hub.byId.dungeonmap and ns.Hub.byId.dungeonmap.panel
            if p then ns.MapPages.ShowDungeon(p, dname) end
          end)
        end, "Open this dungeon's own map, with its bosses.")
      end
    end
  end
  -- bosses on a dungeon map
  local DJ = ns.DungeonJournal
  if DJ and DJ.enabled and DJ.BossPins then
    local bosses = DJ:BossPins(mapID)
    if #bosses > 0 then
      add("Bosses on this map", "head")
      for _, b in ipairs(bosses) do
        add("  " .. tostring(b.name), "boss", nil, b.poi and b.poi.note)
      end
    end
  end
  -- rares
  local MP = ns.MapPins
  if MP and MP.enabled and MP.PinsFor then
    local seen, rares = {}, {}
    for _, pin in ipairs(MP:PinsFor(mapID)) do
      if pin.kind == "rare" then
        local n = tostring(pin.name or ""):match("^([^%(,]+)") or "?"
        n = n:match("^%s*(.-)%s*$")
        if not seen[n] then seen[n] = true rares[#rares + 1] = { n = n, state = pin.stateLine } end
      end
    end
    table.sort(rares, function(a, b) return a.n < b.n end)
    if #rares > 0 then
      add("Rares here", "head")
      for i = 1, math.min(#rares, 8) do
        add("  " .. rares[i].n .. (rares[i].state and ("  |cff888888" .. rares[i].state .. "|r") or ""), "rare")
      end
      if #rares > 8 then add(string.format("  and %d more", #rares - 8), "rare") end
    end
  end
  -- routes on this map
  local R = ns.Routes
  if R and R.enabled then
    local list = R:List(mapID)
    add("Routes on this map", "head")
    for _, r in ipairs(list) do
      add("  " .. (r.shown and "|cff66d980on|r  " or "|cff888888off|r  ") .. r.name, "route",
        function() R:SetShown(r.id, not r.shown) end, "Click to show or hide this route.")
    end
    add("  + Draw on this map", "draw", function() ns.MapPages.DrawOn(mapID) end,
      "Opens Map and routes on this map to draw a route.")
  end
  return out
end

function M:Build()
  if self.frame then return self.frame end
  local f = CreateFrame("Frame", "Outrider_MapDock", UIParent, Theme:BackdropTemplate())
  Theme:ApplyPanel(f, "bg", "border")
  f:SetWidth(M.W)
  f:Hide()
  f.head = UI.Display and UI.Display(f, "side", "goldText") or UI.Text(f, "normal", "goldText")
  f.head:SetPoint("TOPLEFT", 10, -8)
  f.head:SetText("Outrider")
  f.close = UI:Button(f, "x", 22, function() M:Settings().on = false f:Hide() ns.Print("map panel hidden: /ride mapdock to bring it back") end)
  f.close:SetHeight(20)
  f.close:SetPoint("TOPRIGHT", -6, -6)
  UI.Tip(f.close, "Hide the panel", "Hide this panel. /ride mapdock brings it back.")
  f.rows = {}
  for i = 1, M.ROWS do
    local b = CreateFrame("Button", nil, f)
    b:SetHeight(18)
    b:SetPoint("TOPLEFT", 8, -30 - (i - 1) * 19)
    b:SetPoint("RIGHT", -8, 0)
    b.text = UI.Text(b, "small", "text")
    b.text:SetAllPoints()
    if b.text.SetJustifyH then b.text:SetJustifyH("LEFT") end
    if b.text.SetWordWrap then b.text:SetWordWrap(false) end
    b:SetScript("OnClick", function(self) if self.row and self.row.go then ns.Safe("mapdock:go", self.row.go) M:Refresh() end end)
    b:SetScript("OnEnter", function(self)
      if self.row and (self.row.tip or self.row.go) then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine((self.row.text:gsub("^%s+", "")))
        if self.row.tip then GameTooltip:AddLine(self.row.tip, 1, 1, 1, true) end
        GameTooltip:Show()
      end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.rows[i] = b
  end
  self.frame = f
  return f
end

function M:Place()
  local f, map = self.frame, self.map
  if not (f and map) then return end
  f:ClearAllPoints()
  local max = map.IsMaximized and select(2, pcall(map.IsMaximized, map))
  if max then
    f:SetPoint("TOPRIGHT", map, "TOPRIGHT", -12, -70)
  else
    f:SetPoint("TOPLEFT", map, "TOPRIGHT", 2, 0)
  end
  f:SetHeight(30 + M.ROWS * 19 + 8)
  f:SetFrameStrata(map.GetFrameStrata and map:GetFrameStrata() or "HIGH")
  f:SetFrameLevel((map.GetFrameLevel and map:GetFrameLevel() or 1) + 20)
end

function M:Refresh()
  if not (self.map and self.map:IsShown() and self:Settings().on) then
    if self.frame then self.frame:Hide() end
    return
  end
  local f = self:Build()
  self:Place()
  local mapID = self.map.GetMapID and self.map:GetMapID()
  local rows = self:Rows(mapID)
  for i, b in ipairs(f.rows) do
    local r = rows[i]
    b.row = r
    if r then
      local color = r.kind == "head" and "goldText" or r.kind == "title" and "text" or r.go and "text" or "muted"
      b.text:SetText(r.text)
      b.text:SetTextColor(Theme:Color(color))
      b:Show()
    else
      b:Hide()
    end
  end
  f:Show()
  if mapID and not (self.logged or {})[mapID] then
    self.logged = self.logged or {}
    self.logged[mapID] = true
    self:Debug("map panel on map %d: %d rows", mapID, #rows)
  end
end

function M:OnEnable()
  local map = rawget(_G, "WorldMapFrame")
  if not (map and map.GetMapID) then self:Warn("no world map: map panel off") return end
  self.map = map
  if not self.hooked then
    self.hooked = true
    map:HookScript("OnShow", function() if M.enabled then ns.Safe("mapdock:refresh", M.Refresh, M) end end)
    map:HookScript("OnHide", function() if M.frame then M.frame:Hide() end end)
    if type(map.OnMapChanged) == "function" then
      hooksecurefunc(map, "OnMapChanged", function() if M.enabled then ns.Safe("mapdock:refresh", M.Refresh, M) end end)
    end
    if type(map.SynchronizeDisplayState) == "function" then
      hooksecurefunc(map, "SynchronizeDisplayState", function() if M.enabled then ns.Safe("mapdock:refresh", M.Refresh, M) end end)
    end
  end
  self:On("OTR_ROUTES_CHANGED", function(mod) if mod.frame and mod.frame:IsShown() then mod:Refresh() end end)
end

function M:OnDisable()
  if self.frame then self.frame:Hide() end
end

function M:Activity() return self:Settings().on and "beside the world map" or "hidden (/ride mapdock)" end

ns.AddCommand("mapdock", "mapdock  show or hide the Outrider panel beside the world map", function()
  local s = M:Settings()
  s.on = not s.on
  ns.Print("map panel %s", s.on and "on" or "off")
  M:Refresh()
end)

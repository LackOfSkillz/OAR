-- Modules/MapPins.lua  (P3-03 world map pins, P3-05 pin cards)
-- Pins for known places (POICapture) and rares (packs, sightings, discovery)
-- on the world map. Drawn as our own small frames on the map canvas
-- (WorldMapFrame:GetCanvas()), placed at x * width, y * height, redrawn when
-- the map opens or changes (post-hooks only, nothing Blizzard's replaced).
-- Click a pin: a card with what we know and a Waypoint button (a normal
-- frame, no secure actions, so it works in combat too).
-- Filters per character: which kinds show.

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local M = ns:NewModule("MapPins", {
  title = "World map pins",
  phase = "P3",
  order = 53,
  defaults = { hidden = {} },
})
ns.MapPins = M

local COLORS = {
  rare = "warn", spirit_healer = "accent", flight_master = "good", vendor = "text", repair = "text",
  trainer = "accent", bank = "good", auction = "good", stable_master = "good", mailbox = "muted",
}
local LABELS = {
  rare = "Rare", spirit_healer = "Spirit healer", flight_master = "Flight master", vendor = "Vendor",
  repair = "Repair", trainer = "Trainer", bank = "Bank", auction = "Auction house",
  stable_master = "Stable master", mailbox = "Mailbox",
}
M.LABELS = LABELS

-- Pins for one map: { id, kind, x, y, name, npcID?, poi?, rare? } (pure).
function M:PinsFor(mapID)
  local out, hidden = {}, self:Settings().hidden
  local faction = C.Call("UnitFactionGroup", "player")
  for id, p in pairs(ns.db.global.pois or {}) do
    if p.mapID == mapID and not hidden[p.kind] and (p.faction == nil or p.faction == faction) then
      out[#out + 1] = { id = id, kind = p.kind, mapID = mapID, x = p.x, y = p.y, name = p.name or LABELS[p.kind], npcID = p.npcID, poi = p }
    end
  end
  if not hidden.rare then
    local seen = {}
    local function addRare(npcID, name, x, y)
      if seen[npcID] or not x or not y then return end
      seen[npcID] = true
      out[#out + 1] = { id = "rare-" .. npcID, kind = "rare", mapID = mapID, x = x, y = y, name = name, npcID = npcID, rare = true }
    end
    for npcID, list in pairs(ns.db.global.sightings or {}) do
      for i = #list, 1, -1 do
        local s = list[i]
        if s.mapID == mapID then
          local d = ns.db.global.discovered and ns.db.global.discovered.npcs[npcID]
          local pack = ns.Data:Get("rare", npcID)
          addRare(npcID, (pack and pack.name) or (d and d.name) or ("NPC " .. npcID), s.x, s.y)
          break
        end
      end
    end
    for _, e in ipairs(ns.Data:All("rare")) do
      if e.mapID == mapID and e.spawns and e.spawns[1] then addRare(e.npcID, e.name, e.spawns[1].x, e.spawns[1].y) end
    end
  end
  table.sort(out, function(a, b) return a.id < b.id end)
  return out
end

function M:OnEnable()
  local map = rawget(_G, "WorldMapFrame")
  if not map or not map.GetCanvas then self:Warn("no world map canvas: pins off") return end
  self.map = map
  if not self.hooked then
    self.hooked = true
    map:HookScript("OnShow", function() if M.enabled then M:Refresh() end end)
    if type(map.OnMapChanged) == "function" then
      hooksecurefunc(map, "OnMapChanged", function() if M.enabled then M:Refresh() end end)
    end
  end
  self:On("OTR_POI_ADDED", function(mod) if mod.map:IsShown() then mod:Refresh() end end)
  self:On("OTR_SIGHTING_ADDED", function(mod) if mod.map:IsShown() then mod:Refresh() end end)
  self.pool, self.used = self.pool or {}, {}
end

function M:OnDisable()
  self:ReleaseAll()
  if self.card then self.card:Hide() end
end

function M:ReleaseAll()
  for _, pin in ipairs(self.used or {}) do pin:Hide() self.pool[#self.pool + 1] = pin end
  self.used = {}
end

function M:AcquirePin(canvas)
  local pin = table.remove(self.pool)
  if not pin then
    pin = CreateFrame("Button", nil, canvas)
    pin:SetSize(14, 14)
    pin.dot = pin:CreateTexture(nil, "OVERLAY")
    pin.dot:SetAllPoints()
    pin:SetScript("OnClick", function(self) M:ShowCard(self.data) end)
    pin:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.data.name or "?")
      local first, second = ns.POI.Describe(self.data.poi or self.data, LABELS[self.data.kind] or self.data.kind)
      GameTooltip:AddLine(first, ns.Theme:Color("muted"))
      if second then GameTooltip:AddLine(second, ns.Theme:Color("text")) end
      GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  pin:SetParent(canvas)
  pin:SetFrameLevel((canvas.GetFrameLevel and canvas:GetFrameLevel() or 1) + 20)
  self.used[#self.used + 1] = pin
  return pin
end

function M:Refresh()
  if not self.map then return end
  self:ReleaseAll()
  local mapID = self.map.GetMapID and self.map:GetMapID()
  if not mapID then return end
  local canvas = self.map:GetCanvas()
  local w, h = canvas:GetWidth(), canvas:GetHeight()
  local scale = (canvas.GetScale and canvas:GetScale() or 1)
  for _, data in ipairs(self:PinsFor(mapID)) do
    local pin = self:AcquirePin(canvas)
    pin.data = data
    -- keep pins the same size on screen when the map canvas is zoomed
    pin:SetScale(1 / (scale > 0 and scale or 1))
    pin.dot:SetColorTexture(ns.Theme:Color(COLORS[data.kind] or "text"))
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", canvas, "TOPLEFT", data.x * w * scale, -data.y * h * scale)
    pin:Show()
  end
  self.shown = #self.used
  if not self.logged then self.logged = true self:Info("map %d opened: %d pins", mapID, self.shown)
  else self:Debug("map %d: %d pins", mapID, self.shown) end
end

-- ------------------------------------------------------------- pin card
function M:ShowCard(data)
  local card = self.card
  if not card then
    card = UI:Window("Outrider_PinCard", "", 280, 170, ns.db.char.pinCard)
    card:SetFrameStrata("TOOLTIP")
    local c = card.content
    card.kind = UI.Text(c, "small", "muted") card.kind:SetPoint("TOPLEFT", 0, 0)
    card.body = UI.Text(c, "normal", "text") card.body:SetPoint("TOPLEFT", 0, -18)
    card.body:SetWidth(256) card.body:SetJustifyH("LEFT")
    card.way = UI:Button(c, "Waypoint", 90, function()
      local d = card.data
      ns.Waypoints:Set(d.mapID, d.x, d.y, d.name)
    end)
    card.way:SetPoint("BOTTOMLEFT", 0, 0)
    card.watch = UI:Button(c, "Watch", 90, function()
      local scan = ns.Modules:Get("RareScan")
      local d = card.data
      if scan and d.npcID then scan:Watch(d.npcID, not scan:IsWatched(d.npcID, d.name)) end
      M:ShowCard(d)
    end)
    card.watch:SetPoint("LEFT", card.way, "RIGHT", 6, 0)
    ns.db.char.pinCard = ns.db.char.pinCard or {}
    self.card = card
  end
  card.data = data
  card.title:SetText(data.name or "?")
  card.kind:SetText(string.format("%s  |  %.1f, %.1f", LABELS[data.kind] or data.kind, data.x * 100, data.y * 100))
  card.body:SetText(self:CardText(data))
  local scan = ns.Modules:Get("RareScan")
  card.watch:SetShown(data.npcID ~= nil and scan ~= nil)
  if scan and data.npcID then card.watch.label:SetText(scan:IsWatched(data.npcID, data.name) and "Watching" or "Watch") end
  card:Show()
  self:Info("pin card %s (%s)", tostring(data.name), data.kind)
end

function M:CardText(data)
  local lines = {}
  if data.rare then
    lines[#lines + 1] = ns.Sightings:Describe(data.npcID, ns.Layers and ns.Layers.current)
    local pack = ns.Data:Get("rare", data.npcID)
    if pack and pack.notes then lines[#lines + 1] = pack.notes end
    if pack and pack.beast and pack.beast.family then
      lines[#lines + 1] = pack.beast.family .. (pack.verified and "" or " (unverified)")
    end
  elseif data.poi then
    local p = data.poi
    local first, second = ns.POI.Describe(p, LABELS[p.kind] or p.kind)
    lines[#lines + 1] = first
    if second then lines[#lines + 1] = second end
    lines[#lines + 1] = string.format("Visited %d time%s, last %s", p.n or 1, (p.n or 1) == 1 and "" or "s",
      p.lastSeen and date("%Y-%m-%d", p.lastSeen) or "?")
    if p.faction then lines[#lines + 1] = p.faction end
  end
  return table.concat(lines, "\n")
end

function M:Activity()
  local n = 0
  for _ in pairs(ns.db.global.pois or {}) do n = n + 1 end
  return string.format("%d places can show on the map%s", n, self.shown and (", " .. self.shown .. " on the open map") or "")
end

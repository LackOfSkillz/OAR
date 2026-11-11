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
  innkeeper = "good", guild_master = "muted", tabard = "muted",
}
local LABELS = {
  rare = "Rare", spirit_healer = "Spirit healer", flight_master = "Flight master", vendor = "Vendor",
  repair = "Repair", trainer = "Trainer", bank = "Bank", auction = "Auction house",
  stable_master = "Stable master", mailbox = "Mailbox", innkeeper = "Innkeeper", guild_master = "Guild master",
  tabard = "Tabard vendor", quest_giver = "Quest giver", herb = "Herb", ore = "Ore", fish = "Fishing spot",
}
M.LABELS = LABELS

-- Markers (Gary, 2026-11-11: "less 8 bit", colour by group, different
-- symbols): the client's own minimap tracking icons as the symbol, a soft
-- ring in the group colour behind it. Groups: merchant, trainer, service, rare.
local TRACK = "Interface\\Minimap\\Tracking\\"
local GROUP = {
  vendor = "merchant", repair = "merchant",
  trainer = "trainer",
  innkeeper = "service", bank = "service", auction = "service", flight_master = "service", stable_master = "service",
  mailbox = "service", guild_master = "service", tabard = "service", spirit_healer = "service",
  rare = "rare", quest_giver = "quest", herb = "gather", ore = "gather", fish = "gather",
}
M.GROUP_COLOR = {
  merchant = { 1.00, 0.80, 0.25 }, trainer = { 0.35, 0.65, 1.00 }, service = { 0.40, 0.85, 0.45 }, rare = { 1.00, 0.30, 0.30 },
  quest = { 0.75, 0.45, 1.00 }, gather = { 0.80, 0.60, 0.35 },
}
M.GROUP_LABEL = { merchant = "Merchants", trainer = "Trainers", service = "Services", rare = "Rares", quest = "Quest givers", gather = "Herbs, ore & fish" }
local ICON = {
  innkeeper = TRACK .. "Innkeeper", bank = TRACK .. "Banker", auction = TRACK .. "Auctioneer",
  flight_master = TRACK .. "FlightMaster", stable_master = TRACK .. "StableMaster", mailbox = TRACK .. "Mailbox",
  repair = TRACK .. "Repair", spirit_healer = "Interface\\Icons\\Spell_Holy_Resurrection",
  guild_master = "Interface\\Icons\\INV_Misc_Note_02", tabard = "Interface\\Icons\\INV_Shirt_GuildTabard_01",
  rare = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull",
  quest_giver = "Interface\\GossipFrame\\AvailableQuestIcon",
  herb = "Interface\\Icons\\INV_Misc_Flower_02", ore = "Interface\\Icons\\INV_Ore_Copper_01", fish = "Interface\\Icons\\INV_Misc_Fish_02",
}
-- class names that make a trainer a class trainer (else profession)
local CLASSES = { "Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Shaman", "Mage", "Warlock", "Druid", "Pet" }

function M.Group(kind) return GROUP[kind] or "service" end

-- Texture path for a pin (pure: by kind, then title / goods for vendors and trainers).
function M.IconFor(pin)
  local kind, p = pin.kind, pin.poi or pin
  if kind == "trainer" then
    local title = p and p.title or ""
    for _, c in ipairs(CLASSES) do if title:find(c, 1, true) then return TRACK .. "Class" end end
    return TRACK .. "Profession"
  end
  if kind == "vendor" then
    local goods = p and p.goods and table.concat(p.goods, ",") or ""
    local title = (p and p.title or ""):lower()
    if goods:find("ammo") or title:find("bowyer") or title:find("gunsmith") or title:find("ammo") then return TRACK .. "Ammunition" end
    if goods:find("food") or title:find("food") or title:find("cook") or title:find("innkeeper") then return TRACK .. "Food" end
    if goods:find("reagent") or title:find("reagent") then return TRACK .. "Reagents" end
    if title:find("poison") then return TRACK .. "Poisons" end
    return TRACK .. "Repair"
  end
  return ICON[kind] or (TRACK .. "None")
end

-- Fill a marker: frame has .ring and .icon textures.
function M.Paint(frame, pin)
  local c = M.GROUP_COLOR[M.Group(pin.kind)] or { 1, 1, 1 }
  frame.ring:SetColorTexture(c[1], c[2], c[3], 0.55)
  local ok = frame.icon:SetTexture(M.IconFor(pin))
  if ok == false then
    frame.icon:SetColorTexture(c[1], c[2], c[3], 1) -- missing file: plain round dot
  else
    frame.icon:SetVertexColor(1, 1, 1, 1)
  end
end

-- Round ring + icon on a marker frame of the given size.
function M.Decorate(frame, size)
  frame:SetSize(size, size)
  frame.ring = frame:CreateTexture(nil, "BACKGROUND")
  frame.ring:SetAllPoints()
  local mask = frame.CreateMaskTexture and frame:CreateMaskTexture()
  if mask then
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints()
    frame.ring:AddMaskTexture(mask)
  end
  frame.icon = frame:CreateTexture(nil, "ARTWORK")
  frame.icon:SetPoint("TOPLEFT", 2, -2)
  frame.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  if mask and frame.icon.AddMaskTexture then frame.icon:AddMaskTexture(mask) end
end

-- Pins for one map: { id, kind, x, y, name, npcID?, poi?, rare? } (pure).
-- PinsFor is called 5x a second by the minimap while moving; building new
-- tables each time made memory read 3 MB (2026-11-11). Results are cached
-- per map and dropped when a place, sighting, filter or rare pack changes.
M.cache = {}
function M:Invalidate() self.cache = {} end

ns.Events:On("OTR_POI_ADDED", M, function() M:Invalidate() end)
ns.Events:On("OTR_SIGHTING_ADDED", M, function() M:Invalidate() end)
ns.Events:On("OTR_DATA_CHANGED", M, function() M:Invalidate() end)

function M:PinsFor(mapID)
  -- also rebuild if places were added or removed without an event
  local n = 0
  for _ in pairs(ns.db.global.pois or {}) do n = n + 1 end
  local cached = self.cache[mapID]
  if cached and cached.poiCount == n then return cached.pins end
  local out = self:BuildPins(mapID)
  self.cache[mapID] = { pins = out, poiCount = n }
  return out
end

function M:BuildPins(mapID)
  local out, hidden = {}, self:Settings().hidden
  local faction = C.Call("UnitFactionGroup", "player")
  local own = {}
  for id, p in pairs(ns.db.global.pois or {}) do
    if p.npcID then own[p.npcID] = true end
    if p.mapID == mapID and not hidden[p.kind] and (p.faction == nil or p.faction == faction) then
      out[#out + 1] = { id = id, kind = p.kind, mapID = mapID, x = p.x, y = p.y, name = p.name or LABELS[p.kind], npcID = p.npcID, poi = p }
    end
  end
  -- Optional private NPC pack (D10); NPCs Gary visited himself win.
  if ns.NPCPack then
    for _, p in ipairs(ns.NPCPack:PlacesFor(mapID)) do
      if not own[p.npcID] and not hidden[p.kind] and (p.faction == nil or p.faction == faction) then
        out[#out + 1] = { id = p.id, kind = p.kind, mapID = mapID, x = p.x, y = p.y, name = p.name, npcID = p.npcID, poi = p }
      end
    end
  end
  -- Gathering nodes Gary found (LootLog)
  if ns.LootLog and ns.LootLog.enabled then
    for i, n in ipairs(ns.LootLog:NodesFor(mapID)) do
      if not hidden[n.kind] then
        out[#out + 1] = { id = "node-" .. n.kind .. "-" .. i, kind = n.kind, mapID = mapID, x = n.x, y = n.y,
          name = (n.name or n.kind) .. " (x" .. (n.count or 1) .. ")" ..
            (n.sharedBy and (", from " .. (tostring(n.sharedBy):match("^[^-]+") or "guild")) or "") }
      end
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
    M.Decorate(pin, 18)
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
    M.Paint(pin, data)
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

-- Modules/POICapture.lua  (P3-06)
-- Turns NPC windows into points of interest, account-wide in
-- ns.db.global.pois[id] (DATA_SCHEMAS.md "poi"):
--   MERCHANT_SHOW vendor (+ repair if CanMerchantRepair), TRAINER_SHOW trainer,
--   TAXIMAP_OPENED flight_master, BANKFRAME_OPENED bank, AUCTION_HOUSE_SHOW
--   auction, PET_STABLE_SHOW stable_master, CONFIRM_XP_LOSS spirit_healer,
--   MAIL_SHOW mailbox (an object: id from map + rounded position).
-- Position = player position while the window is open (a few yards off);
-- repeat visits average it. Faction = the capturing character's faction
-- (the NPC served them). Everything stays verified = false, source "discovery".

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("POICapture", {
  title = "Places (vendors, trainers, flight masters...)",
  phase = "P3",
  order = 51,
  defaults = {},
})
ns.POI = M

local EVENTS = {
  MERCHANT_SHOW = "vendor", TRAINER_SHOW = "trainer", TAXIMAP_OPENED = "flight_master",
  BANKFRAME_OPENED = "bank", AUCTION_HOUSE_SHOW = "auction", PET_STABLE_SHOW = "stable_master",
  CONFIRM_XP_LOSS = "spirit_healer", MAIL_SHOW = "mailbox",
  GUILD_REGISTRAR_SHOW = "guild_master", PETITION_VENDOR_SHOW = "guild_master",
  TABARD_FRAME_OPENED = "tabard", CONFIRM_BINDER = "innkeeper",
}

-- Innkeepers, guild masters and others mostly open a plain chat (gossip)
-- window, so on GOSSIP_SHOW the NPC's title decides (decided 2026-11-11).
-- English titles; anything not matched is left to Discovery.
local TITLE_KINDS = {
  { "innkeeper", "innkeeper" }, { "guild master", "guild_master" }, { "guild registrar", "guild_master" },
  { "tabard", "tabard" }, { "stable master", "stable_master" }, { "flight master", "flight_master" },
  { "wind rider master", "flight_master" }, { "gryphon master", "flight_master" }, { "hippogryph master", "flight_master" },
  { "bat handler", "flight_master" }, { "banker", "bank" }, { "auctioneer", "auction" }, { "trainer", "trainer" },
  { "spirit healer", "spirit_healer" },
}
M.TITLE_KINDS = TITLE_KINDS

function M.KindFromTitle(title)
  if type(title) ~= "string" then return nil end
  local t = title:lower()
  for _, pair in ipairs(TITLE_KINDS) do
    if t:find(pair[1], 1, true) then return pair[2] end
  end
end

function M:OnGossip()
  local title = C.UnitTitle("npc")
  local kind = M.KindFromTitle(title)
  -- spirit healers often have no title but are named so
  if not kind then
    local name = C.Readable(C.Call("UnitName", "npc"))
    if name == "Spirit Healer" then kind = "spirit_healer" end
  end
  if kind then return self:CaptureWindow(kind) end
end

function M:OnInitialize()
  local g = ns.db.global
  g.pois = ns.KeepTable(g.pois, "POICapture:g.pois") or {}
  self.db = g.pois
end

-- Discovery tagged NPC windows before places existed (and still does);
-- turn those roles into places so earlier visits show on the map too.
local ROLE_KIND = { vendor = "vendor", banker = "bank", stablemaster = "stable_master", trainer = "trainer",
  flightmaster = "flight_master", innkeeper = "innkeeper", guild_master = "guild_master", tabard = "tabard",
  bank = "bank", auction = "auction", stable_master = "stable_master", flight_master = "flight_master",
  spirit_healer = "spirit_healer" }

function M:Backfill()
  local npcs = ns.db.global.discovered and ns.db.global.discovered.npcs or {}
  local faction = C.Call("UnitFactionGroup", "player")
  local added = 0
  for npcID, e in pairs(npcs) do
    if e.quality == "interact" and e.mapID and e.x then
      local roles = {}
      for _, r in ipairs(e.roles or {}) do roles[#roles + 1] = r end
      local byTitle = M.KindFromTitle(e.title)
      if byTitle then roles[#roles + 1] = byTitle end
      for _, role in ipairs(roles) do
        local kind = ROLE_KIND[role]
        local id = kind and ("npc-" .. npcID .. "-" .. kind)
        if id and self.db[id] and e.title and not self.db[id].title then self.db[id].title = e.title end
        if id and not self.db[id] then
          self.db[id] = { id = id, kind = kind, mapID = e.mapID, x = e.x, y = e.y, n = e.posN or 1, npcID = npcID,
            name = e.name, title = e.title, verified = false, source = "discovery", faction = faction, firstSeen = e.firstSeen,
            lastSeen = e.lastSeen }
          added = added + 1
        end
      end
    end
  end
  if added > 0 then
    self:Info("backfilled %d places from earlier NPC visits", added)
    -- map pins count places only now and then: tell them (MapPins.COUNT_S)
    ns.Events:Fire("OTR_POI_ADDED", nil)
  end
  return added
end

-- Flight points straight from the client (owner's choice, 2026-11-11): the
-- game knows every node on a map with its position, discovered or not, so
-- these need no discovery. Faction: Enum.FlightPathFaction 0 neutral,
-- 1 Horde, 2 Alliance. Stored as "taxi-<nodeID>", source "client".
local TAXI_FACTION = { [1] = "Horde", [2] = "Alliance" }

function M:LoadTaxi(mapID)
  if not mapID or self.taxiDone[mapID] then return 0 end
  local get = C.Resolve("C_TaxiMap.GetTaxiNodesForMap") or C.Resolve("C_TaxiMap.GetAllTaxiNodes")
  if type(get) ~= "function" then return 0 end
  local ok, nodes = pcall(get, mapID)
  if not ok or type(nodes) ~= "table" then return 0 end
  self.taxiDone[mapID] = true
  local added = 0
  for _, n in ipairs(nodes) do
    local x, y
    if n.position and n.position.GetXY then x, y = n.position:GetXY()
    elseif n.position then x, y = n.position.x, n.position.y end
    if n.nodeID and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
      local id = "taxi-" .. n.nodeID
      if not self.db[id] then added = added + 1 end
      local name = C.Readable(n.name)
      self.db[id] = { id = id, kind = "flight_master", mapID = mapID, x = x, y = y, n = 1, name = name,
        title = name, faction = TAXI_FACTION[n.faction], verified = true, source = "client", lastSeen = time() }
    end
  end
  if added > 0 then
    self:Info("loaded %d flight points from the client for map %d", added, mapID)
    ns.Events:Fire("OTR_POI_ADDED", nil)
  end
  return added
end

function M:OnEnable()
  self.taxiDone = {}
  self:Backfill()
  self:On("PLAYER_ENTERING_WORLD", function(mod) mod:LoadTaxi(C.PlayerPosition("player")) end)
  self:On("ZONE_CHANGED_NEW_AREA", function(mod) mod:LoadTaxi(C.PlayerPosition("player")) end)
  for event, kind in pairs(EVENTS) do
    self:On(event, function(mod) mod:CaptureWindow(kind) end)
  end
  self:On("GOSSIP_SHOW", self.OnGossip)
  self:On("OTR_NPC_PLACED", self.OnNpcPlaced)
end

-- An NPC seen up close (Discovery): its places move to where it stands, and
-- a service NPC whose title says what it does (Fishing Trainer, Innkeeper)
-- becomes a place, so your sighting beats the data pack on the map and in
-- "nearest" (requirement 2026-11-20: Outrider adjusts the POI itself).
function M:OnNpcPlaced(_, npcID, e)
  if type(npcID) ~= "number" or type(e) ~= "table" or not (e.mapID and e.x and e.y) then return end
  local prefix, found = "npc-" .. npcID .. "-", false
  for id, p in pairs(self.db) do
    if id:sub(1, #prefix) == prefix then
      found = true
      if p.mapID ~= e.mapID or p.x ~= e.x or p.y ~= e.y then
        if p.mapID ~= e.mapID then ns.Events:Fire("OTR_POI_ADDED", { mapID = p.mapID }) end
        p.mapID, p.x, p.y, p.n, p.lastSeen = e.mapID, e.x, e.y, 1, time()
        self:Info("poi moved %s %s to map=%d %.1f,%.1f", p.kind, tostring(p.name), e.mapID, e.x * 100, e.y * 100)
        ns.Events:Fire("OTR_POI_ADDED", p)
      end
    end
  end
  if found then return end
  local kind = M.KindFromTitle(e.title)
  if not kind then return end
  local id = prefix .. kind
  local p = { id = id, kind = kind, mapID = e.mapID, x = e.x, y = e.y, n = 1, npcID = npcID, name = e.name, title = e.title,
    verified = false, source = "discovery", faction = e.faction ~= "Neutral" and e.faction or nil, firstSeen = time(), lastSeen = time() }
  self.db[id] = p
  self:Info("poi seen %s %s map=%d %.1f,%.1f", kind, tostring(e.name), e.mapID, e.x * 100, e.y * 100)
  ns.Events:Fire("OTR_POI_ADDED", p)
end

function M:CaptureWindow(kind)
  if kind == "mailbox" then return self:CaptureObject(kind) end
  local npcID, g = C.UnitNpcID("npc")
  if not npcID or not g or g.kind ~= "Creature" then return nil end
  local name = C.Readable(C.Call("UnitName", "npc"))
  local poi = self:Add("npc-" .. npcID .. "-" .. kind, kind, { npcID = npcID, name = name, title = C.UnitTitle("npc") })
  if kind == "vendor" and poi then
    -- merchant items arrive a moment after the window opens
    ns.Timer.After(0.5, function() M:ScanGoods(poi) end, "poi:goods")
  end
  if kind == "vendor" and C.Call("CanMerchantRepair") then
    self:Add("npc-" .. npcID .. "-repair", "repair", { npcID = npcID, name = name })
  end
  return poi
end

-- What a vendor sells, by item class: { "ammo", "food & drink", ... }.
local CLASS = { [0] = "food & potions", [1] = "bags", [2] = "weapons", [4] = "armor", [5] = "reagents",
  [6] = "ammo", [7] = "trade goods", [9] = "recipes", [11] = "quivers", [15] = "misc" }
M.CLASS = CLASS

function M:ScanGoods(p)
  local n = C.Call("GetMerchantNumItems") or 0
  if n == 0 then return end
  local seen, kinds = {}, {}
  for i = 1, n do
    local id = C.Call("GetMerchantItemID", i)
    if id then
      -- classID is the 6th return; C.Call only passes 5 back, so call directly
      local get = C.Resolve("C_Item.GetItemInfoInstant") or rawget(_G, "GetItemInfoInstant")
      local classID
      if type(get) == "function" then
        local ok, _, _, _, _, _, cls = pcall(get, id)
        if ok then classID = cls end
      end
      local k = CLASS[classID or -1]
      if k and not seen[k] then seen[k] = true kinds[#kinds + 1] = k end
    end
  end
  table.sort(kinds)
  if #kinds > 0 then
    p.goods = kinds
    self:Info("vendor %s sells: %s", tostring(p.name), table.concat(kinds, ", "))
  end
end

-- One line for tooltips and cards: "Vendor (Bowyer)" + "Sells: ammo, weapons".
function M.Describe(p, label)
  local first = label or p.kind
  if p.title and p.title ~= p.name then first = first .. " (" .. p.title .. ")" end
  local second = p.goods and #p.goods > 0 and ("Sells: " .. table.concat(p.goods, ", ")) or nil
  if p.source == "questie" then second = (second and (second .. " | ") or "") .. "community data, unverified" end
  if p.source == "guide" then second = (second and (second .. " | ") or "") .. (p.note and (p.note .. " | ") or "") .. "from the leveling guides, unverified" end
  return first, second
end

function M:CaptureObject(kind)
  local mapID, x, y = C.PlayerPosition("player")
  if not (mapID and x) then return nil end
  -- objects have no id: one per ~1% of the map, so revisits land on the same key
  local id = string.format("%s-%d-%d-%d", kind, mapID, math.floor(x * 100 + 0.5), math.floor(y * 100 + 0.5))
  return self:Add(id, kind, { name = "Mailbox" })
end

function M:Add(id, kind, extra)
  local mapID, x, y = C.PlayerPosition("player")
  if not (mapID and x and y) then return nil end
  local p = self.db[id]
  if not p then
    p = { id = id, kind = kind, mapID = mapID, x = x, y = y, n = 1, verified = false, source = "discovery",
          faction = C.Call("UnitFactionGroup", "player"), firstSeen = time() }
    self.db[id] = p
    self:Info("poi new %s %s map=%d %.1f,%.1f", kind, tostring(extra.name), mapID, x * 100, y * 100)
  elseif p.mapID ~= mapID or math.abs(p.x - x) > 0.03 or math.abs(p.y - y) > 0.03 then
    -- talking to it far from the stored spot: it moved, or the spot was wrong
    -- (the map it left redraws too: map pins clear per map)
    if p.mapID ~= mapID then ns.Events:Fire("OTR_POI_ADDED", { mapID = p.mapID }) end
    p.mapID, p.x, p.y, p.n = mapID, x, y, 1
    self:Info("poi moved %s %s to map=%d %.1f,%.1f", kind, tostring(extra.name), mapID, x * 100, y * 100)
  else
    p.x = (p.x * p.n + x) / (p.n + 1)
    p.y = (p.y * p.n + y) / (p.n + 1)
    p.n = p.n + 1
  end
  for k, v in pairs(extra) do p[k] = v end
  p.lastSeen = time()
  ns.Events:Fire("OTR_POI_ADDED", p)
  return p
end

function M:Count(kind)
  local n = 0
  for _, p in pairs(self.db) do if not kind or p.kind == kind then n = n + 1 end end
  return n
end

function M:Activity()
  local kinds = {}
  for _, p in pairs(self.db) do kinds[p.kind] = (kinds[p.kind] or 0) + 1 end
  local parts = {}
  for k, n in pairs(kinds) do parts[#parts + 1] = n .. " " .. k:gsub("_", " ") end
  table.sort(parts)
  return #parts > 0 and table.concat(parts, ", ") or "talk to vendors, trainers, flight masters to record them"
end

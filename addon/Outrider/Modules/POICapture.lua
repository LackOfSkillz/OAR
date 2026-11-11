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
}

function M:OnInitialize()
  local g = ns.db.global
  g.pois = type(g.pois) == "table" and g.pois or {}
  self.db = g.pois
end

-- Discovery tagged NPC windows before places existed (and still does);
-- turn those roles into places so earlier visits show on the map too.
local ROLE_KIND = { vendor = "vendor", banker = "bank", stablemaster = "stable_master", trainer = "trainer",
  flightmaster = "flight_master" }

function M:Backfill()
  local npcs = ns.db.global.discovered and ns.db.global.discovered.npcs or {}
  local faction = C.Call("UnitFactionGroup", "player")
  local added = 0
  for npcID, e in pairs(npcs) do
    if e.quality == "interact" and e.mapID and e.x then
      for _, role in ipairs(e.roles or {}) do
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
  if added > 0 then self:Info("backfilled %d places from earlier NPC visits", added) end
  return added
end

function M:OnEnable()
  self:Backfill()
  for event, kind in pairs(EVENTS) do
    self:On(event, function(mod) mod:CaptureWindow(kind) end)
  end
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
  elseif p.mapID == mapID then
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

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

function M:OnEnable()
  for event, kind in pairs(EVENTS) do
    self:On(event, function(mod) mod:CaptureWindow(kind) end)
  end
end

function M:CaptureWindow(kind)
  if kind == "mailbox" then return self:CaptureObject(kind) end
  local npcID, g = C.UnitNpcID("npc")
  if not npcID or not g or g.kind ~= "Creature" then return nil end
  local name = C.Readable(C.Call("UnitName", "npc"))
  local poi = self:Add("npc-" .. npcID .. "-" .. kind, kind, { npcID = npcID, name = name })
  if kind == "vendor" and C.Call("CanMerchantRepair") then
    self:Add("npc-" .. npcID .. "-repair", "repair", { npcID = npcID, name = name })
  end
  return poi
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

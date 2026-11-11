-- Modules/LootLog.lua  (P5-12 catch log, P5-13 gathering map)
-- Reads loot windows (read only):
--   Fishing loot (IsFishingLoot) -> ns.db.global.fishing[mapID][itemID] = count,
--     plus this session's tally and its value (Prices).
--   Herb / ore loot (the last cast was Herb Gathering or Mining, or the loot
--     source GUID is a GameObject) -> a node in ns.db.global.nodes, merged
--     with one within ~0.6% of the map, shown as map and minimap pins.
-- Node and catch names come from the looted items; positions are the
-- player's (you stand at the node). Everything verified = false.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("LootLog", {
  title = "Fishing catches and gathering nodes",
  phase = "P5",
  order = 76,
  defaults = {},
})
ns.LootLog = M

local GATHER = { ["Herb Gathering"] = "herb", ["Mining"] = "ore", ["Herbalism"] = "herb" }
M.MERGE = 0.006

function M:OnInitialize()
  local g = ns.db.global
  g.fishing = type(g.fishing) == "table" and g.fishing or {}
  g.nodes = type(g.nodes) == "table" and g.nodes or {}
  self.session = {}
end

function M:OnEnable()
  self:On("LOOT_OPENED", self.OnLoot)
  self:On("UNIT_SPELLCAST_SUCCEEDED", function(mod, _, unit, _, spellID)
    if unit ~= "player" then return end
    local info = C.Call("C_Spell.GetSpellInfo", spellID)
    local name = C.Readable(type(info) == "table" and info.name or nil)
    mod.lastGather = GATHER[name or ""] and { kind = GATHER[name], t = GetTime and GetTime() or 0 } or mod.lastGather
  end)
end

-- { {itemID, count, name} } in the open loot window
function M:Items()
  local out = {}
  for slot = 1, (C.Call("GetNumLootItems") or 0) do
    local link = C.Call("GetLootSlotLink", slot)
    local id = link and tonumber(link:match("item:(%d+)"))
    if id then
      local _, name, count = C.Call("GetLootSlotInfo", slot)
      out[#out + 1] = { id = id, count = count or 1, name = C.Readable(name) or (link:match("%[(.-)%]")) }
    end
  end
  return out
end

function M:OnLoot()
  local items = self:Items()
  if #items == 0 then return end
  if C.Call("IsFishingLoot") then return self:Catch(items) end
  local now = GetTime and GetTime() or 0
  if self.lastGather and now - self.lastGather.t < 10 then
    local kind = self.lastGather.kind
    self.lastGather = nil
    return self:Node(kind, items)
  end
end

function M:Catch(items)
  local mapID = C.PlayerPosition("player") or 0
  local zone = ns.db.global.fishing[mapID] or {}
  ns.db.global.fishing[mapID] = zone
  local value = 0
  for _, it in ipairs(items) do
    zone[it.id] = (zone[it.id] or 0) + it.count
    self.session[it.id] = (self.session[it.id] or 0) + it.count
    local ah, _, vendor = ns.Prices:Get(it.id)
    value = value + (ah or vendor or 0) * it.count
    self:Info("caught %s x%d (map %d)", tostring(it.name), it.count, mapID)
  end
  self.sessionValue = (self.sessionValue or 0) + value
end

function M:Node(kind, items)
  local mapID, x, y = C.PlayerPosition("player")
  if not (mapID and x) then return end
  local name = items[1].name
  for _, n in ipairs(ns.db.global.nodes) do
    if n.mapID == mapID and n.kind == kind and math.abs(n.x - x) < self.MERGE and math.abs(n.y - y) < self.MERGE then
      n.count, n.lastSeen = (n.count or 1) + 1, time()
      n.name = name or n.name
      ns.Events:Fire("OTR_POI_ADDED", nil)
      return n
    end
  end
  local n = { kind = kind, mapID = mapID, x = x, y = y, name = name, count = 1, firstSeen = time(), lastSeen = time(), verified = false }
  table.insert(ns.db.global.nodes, n)
  self:Info("new %s node %s at map %d %.1f,%.1f", kind, tostring(name), mapID, x * 100, y * 100)
  ns.Events:Fire("OTR_POI_ADDED", nil)
  return n
end

function M:NodesFor(mapID)
  local out = {}
  for _, n in ipairs(ns.db.global.nodes) do if n.mapID == mapID then out[#out + 1] = n end end
  return out
end

function M:Activity()
  local caught = 0
  for _, c in pairs(self.session) do caught = caught + c end
  return string.format("%d gathering nodes known; %d fish this session (%s)", #ns.db.global.nodes, caught,
    ns.Prices.Money(self.sessionValue or 0))
end

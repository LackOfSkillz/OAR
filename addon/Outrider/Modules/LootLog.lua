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

local GATHER = { ["Herb Gathering"] = "herb", ["Mining"] = "ore", ["Herbalism"] = "herb", ["Skinning"] = "skin" }
M.MERGE = 0.006

function M:OnInitialize()
  local g = ns.db.global
  g.fishing = ns.KeepTable(g.fishing, "LootLog:g.fishing") or {}
  g.nodes = ns.KeepTable(g.nodes, "LootLog:g.nodes") or {}
  g.nodeState = ns.KeepTable(g.nodeState, "LootLog:g.nodeState") or {}
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
  -- OTR_LOOT(category, items): what kind of earning this loot was (MoneyGuide)
  if C.Call("IsFishingLoot") then
    ns.Events:Fire("OTR_LOOT", "fish", items)
    return self:Catch(items)
  end
  local now = GetTime and GetTime() or 0
  if self.lastGather and now - self.lastGather.t < 10 then
    local kind = self.lastGather.kind
    self.lastGather = nil
    ns.Events:Fire("OTR_LOOT", kind, items)
    if kind == "skin" then return end -- skinning has no node
    return self:Node(kind, items)
  end
  ns.Events:Fire("OTR_LOOT", "mob", items)
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
  -- fishing spot: where Gary stands (the water is up to ~20 yards away)
  local _, x, y = C.PlayerPosition("player")
  if mapID ~= 0 and x and items[1] then self:AddNode("fish", mapID, x, y, items[1].name) end
end

function M:Node(kind, items)
  local mapID, x, y = C.PlayerPosition("player")
  if not (mapID and x) then return end
  self:MarkNode(kind, mapID, x, y, "picked")
  return self:AddNode(kind, mapID, x, y, items[1] and items[1].name)
end

-- What Outrider last knew about a node spot (requirement 2026-11-14: avoid trips
-- to nodes another player already took). An addon can't see live nodes
-- from a distance (Find Herbs' yellow dots can't be read), so this remembers
-- only what the player saw: "up" when its tooltip showed under the mouse,
-- "picked" when he gathered it. Picked spots stay dimmed PICKED_FOR seconds;
-- "up" is trusted for UP_FOR. Positions are where Gary stood, so a match is
-- anything within NEAR of the spot.
M.PICKED_FOR, M.UP_FOR, M.NEAR, M.STATE_MAX = 15 * 60, 5 * 60, 0.008, 200

function M:MarkNode(kind, mapID, x, y, state)
  local list = ns.db.global.nodeState
  local now = time()
  for _, e in ipairs(list) do
    if e.mapID == mapID and e.kind == kind and math.abs(e.x - x) < M.NEAR and math.abs(e.y - y) < M.NEAR then
      local quiet = e.state == state and now - e.t < 30 -- tooltips repeat while hovering
      e.state, e.t = state, now
      if not quiet then ns.Events:Fire("OTR_POI_ADDED", nil) end
      return e
    end
  end
  local e = { kind = kind, mapID = mapID, x = x, y = y, state = state, t = now }
  list[#list + 1] = e
  while #list > M.STATE_MAX and ns.Archive:Shift("nodeState", list, { path = "global.nodeState" }) do end
  ns.Events:Fire("OTR_POI_ADDED", nil)
  return e
end

-- "picked" / "up" / nil, and seconds since, for a node pin.
function M:NodeState(mapID, x, y, now)
  if not (mapID and x and y) then return nil end
  now = now or time()
  local best
  for _, e in ipairs(ns.db.global.nodeState) do
    if e.mapID == mapID and math.abs(e.x - x) < M.NEAR and math.abs(e.y - y) < M.NEAR and (not best or e.t > best.t) then best = e end
  end
  if not best then return nil end
  local age = now - best.t
  if best.state == "picked" and age < M.PICKED_FOR then return "picked", age end
  if best.state == "up" and age < M.UP_FOR then return "up", age end
  return nil
end

-- Tooltip line for a node pin, or nil.
function M:StateLine(pin, now)
  local st, age = self:NodeState(pin.mapID, pin.x, pin.y, now)
  if not st then return nil end
  local mins = math.floor(age / 60)
  if st == "picked" then return string.format("You picked this %s (about %d min ago): probably empty", date("%H:%M", (now or time()) - age), mins), "muted" end
  return string.format("Seen here %s: probably still up", mins < 1 and "just now" or (mins .. " min ago")), "good"
end

-- Adds or merges a node. `by` = guildmate who shared it (nil = Gary).
-- Fires OTR_NODE_FOUND(node) for a node Gary found himself that is new.
function M:AddNode(kind, mapID, x, y, name, by)
  for _, n in ipairs(ns.db.global.nodes) do
    if n.mapID == mapID and n.kind == kind and math.abs(n.x - x) < self.MERGE and math.abs(n.y - y) < self.MERGE then
      if not by then
        n.count, n.lastSeen = (n.count or 1) + 1, time()
        n.name = name or n.name
        n.sharedBy = nil
      end
      ns.Events:Fire("OTR_POI_ADDED", nil)
      return n, false
    end
  end
  local n = { kind = kind, mapID = mapID, x = x, y = y, name = name, count = 1, firstSeen = time(), lastSeen = time(),
    verified = false, sharedBy = by }
  table.insert(ns.db.global.nodes, n)
  self:Info("new %s node %s at map %d %.1f,%.1f%s", kind, tostring(name), mapID, x * 100, y * 100,
    by and (" (shared by " .. tostring(by) .. ")") or "")
  ns.Events:Fire("OTR_POI_ADDED", nil)
  if not by then ns.Events:Fire("OTR_NODE_FOUND", n) end
  return n, true
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

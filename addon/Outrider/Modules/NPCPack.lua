-- Modules/NPCPack.lua
-- Optional private data addon Outrider_Data_NPC (decision D10): service NPCs
-- copied from QuestieDB by tools/import_questie.py. Outrider never requires
-- it: if the addon is missing, everything works from discovery and the
-- client's flight points. When present, its places show as pins and minimap
-- dots and count for /ride near, marked as unverified community data.
-- Kept in memory only (never written to SavedVariables). An NPC Gary has
-- visited himself (a place in ns.db.global.pois) wins over the pack.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("NPCPack", {
  title = "NPC data pack (private, optional)",
  phase = "P3",
  order = 50,
  defaults = {},
})
ns.NPCPack = M

M.ADDON = "Outrider_Data_NPC"
-- one pin per NPC: the most useful role wins
M.PRIORITY = { "innkeeper", "stable_master", "bank", "auction", "trainer", "guild_master", "tabard",
  "spirit_healer", "vendor", "repair" }

function M:OnInitialize()
  self.maps, self.count = {}, 0
end

function M:OnEnable()
  if not rawget(_G, "Outrider_DataNPC") then C.LoadAddOn(self.ADDON) end
  local data = rawget(_G, "Outrider_DataNPC")
  if type(data) ~= "table" or type(data.maps) ~= "table" then
    self:Info("no %s installed: using discovery and client data only", self.ADDON)
    return
  end
  self.source = data.source
  self:Build(data.maps)
  self:Info("loaded %d places on %d maps from %s", self.count, self.mapCount, tostring(data.source))
  ns.Events:Fire("OTR_DATA_CHANGED", "npcpack")
end

function M:Build(maps)
  local rank = {}
  for i, k in ipairs(self.PRIORITY) do rank[k] = i end
  self.maps, self.count, self.mapCount = {}, 0, 0
  for mapID, rows in pairs(maps) do
    local byNpc = {}
    for _, r in ipairs(rows) do
      local npcID, kind = r[1], r[2]
      local cur = byNpc[npcID]
      if not cur then
        cur = { id = "q-" .. npcID, npcID = npcID, mapID = mapID, x = r[3], y = r[4], name = r[5], title = r[6],
          faction = r[7], kinds = {}, verified = false, source = "questie" }
        byNpc[npcID] = cur
      end
      cur.kinds[#cur.kinds + 1] = kind
      if not cur.kind or (rank[kind] or 99) < (rank[cur.kind] or 99) then cur.kind = kind end
    end
    local list = {}
    for _, p in pairs(byNpc) do list[#list + 1] = p self.count = self.count + 1 end
    self.maps[mapID] = list
    self.mapCount = self.mapCount + 1
  end
end

function M:PlacesFor(mapID) return self.maps[mapID] or {} end

-- Places of one kind on any map (for /ride near).
function M:OfKind(kind)
  local out = {}
  for _, list in pairs(self.maps) do
    for _, p in ipairs(list) do
      for _, k in ipairs(p.kinds) do if k == kind then out[#out + 1] = p break end end
    end
  end
  return out
end

function M:Activity()
  if self.count == 0 then return "not installed (optional)" end
  return string.format("%d places on %d maps (unverified, private copy)", self.count, self.mapCount)
end

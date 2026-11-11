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
  defaults = { grey = false },
})
ns.NPCPack = M

M.ADDON = "Outrider_Data_NPC"
-- one pin per NPC: the most useful role wins
M.PRIORITY = { "innkeeper", "stable_master", "bank", "auction", "trainer", "guild_master", "tabard",
  "spirit_healer", "vendor", "repair", "quest_giver" }

function M:OnInitialize()
  self.maps, self.count = {}, 0
end

function M:OnEnable()
  -- quest pins change when quests are taken, finished or a level is gained
  for _, e in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "PLAYER_LEVEL_UP" }) do
    self:On(e, function() ns.Events:Fire("OTR_DATA_CHANGED", "quests") end)
  end
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

-- Places are built per map the first time that map is needed (building all
-- 52 maps at login cost 2.8 MB, 2026-11-11 perf "over budget: memory").
-- Build only counts; the pack's own rows stay in the data addon.
function M:Build(maps)
  self.raw, self.maps, self.byNpc = maps, {}, {}
  self.count, self.mapCount = 0, 0
  for _, rows in pairs(maps) do
    local seen = {}
    for _, r in ipairs(rows) do
      if not seen[r[1]] then seen[r[1]] = true self.count = self.count + 1 end
    end
    self.mapCount = self.mapCount + 1
  end
end

local RANK
function M:BuildMap(mapID)
  local rows = self.raw and self.raw[mapID]
  if not rows then return {} end
  if not RANK then
    RANK = {}
    for i, k in ipairs(self.PRIORITY) do RANK[k] = i end
  end
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
    if r[8] then cur.quests = r[8] self.byNpc[npcID] = cur end
    if not cur.kind or (RANK[kind] or 99) < (RANK[cur.kind] or 99) then cur.kind = kind end
  end
  local list = {}
  for _, p in pairs(byNpc) do list[#list + 1] = p end
  return list
end

function M:PlacesFor(mapID)
  local list = self.maps[mapID]
  if not list then
    list = self:BuildMap(mapID)
    self.maps[mapID] = list
  end
  return list
end

-- ---------------------------------------------------------------- quest levels
-- Quest givers carry the quests they start (Gary, 2026-11-11: "hard to tell
-- if quests on the map are right for my level"). Colors follow the game's
-- quest log: red 5+ levels above you, orange 3-4, yellow within 2, green
-- below that down to the grey level, grey after (no XP; hidden unless
-- /ride questpins grey on). The grey level uses the Classic formula
-- (approximate on Forever). Quests already done, in the quest log, for
-- the other faction or another class, needing a higher level, or whose
-- earlier quest is not done yet are left out; a giver with none left is
-- not drawn at all.
M.DIFF_ORDER = { "yellow", "orange", "green", "red", "grey" }
M.DIFF_COLOR = { red = { 1, 0.13, 0.13 }, orange = { 1, 0.5, 0.25 }, yellow = { 1, 0.82, 0 },
  green = { 0.25, 0.75, 0.25 }, grey = { 0.55, 0.55, 0.55 } }

function M.GreyLevel(level)
  if level <= 5 then return 0 end
  if level <= 39 then return level - math.floor(level / 10) - 5 end
  if level <= 59 then return level - math.floor(level / 5) - 1 end
  return level - 9
end

function M.Difficulty(questLevel, level)
  local d = questLevel - level
  if d >= 5 then return "red" end
  if d >= 3 then return "orange" end
  if d >= -2 then return "yellow" end
  if questLevel > M.GreyLevel(level) then return "green" end
  return "grey"
end

local function hasBit(mask, bitNo) return math.floor(mask / 2 ^ (bitNo - 1)) % 2 == 1 end

local function done(qid) return C.Call("C_QuestLog.IsQuestFlaggedCompleted", qid) == true end

-- { {id, name, level, diff} } quests this giver offers you now, best first
function M:QuestsFor(p)
  local out = {}
  if type(p.quests) ~= "table" then return out end
  local level = C.Call("UnitLevel", "player") or 1
  local faction = C.Call("UnitFactionGroup", "player")
  local _, _, classID = C.Call("UnitClass", "player")
  local showGrey = self:Settings().grey
  for _, q in ipairs(p.quests) do
    local qid, name, req, qlvl, qfac, cls, preAny, preAll = q[1], q[2], q[3], q[4], q[5], q[6], q[7], q[8]
    local ok = req <= level and (qfac == nil or qfac == faction)
      and (not cls or cls == 0 or not classID or hasBit(cls, classID))
      and not done(qid) and C.Call("C_QuestLog.IsOnQuest", qid) ~= true
    if ok and preAny and #preAny > 0 then
      local any = false
      for _, pq in ipairs(preAny) do if done(pq) then any = true break end end
      ok = any
    end
    if ok and preAll then
      for _, pq in ipairs(preAll) do if not done(pq) then ok = false break end end
    end
    if ok then
      local diff = M.Difficulty(qlvl, level)
      if diff ~= "grey" or showGrey then out[#out + 1] = { id = qid, name = name, level = qlvl, diff = diff } end
    end
  end
  local rank = {}
  for i, d in ipairs(M.DIFF_ORDER) do rank[d] = i end
  table.sort(out, function(a, b) if a.diff ~= b.diff then return rank[a.diff] < rank[b.diff] end return a.level < b.level end)
  return out
end

-- Quest pack entry for an NPC (for givers Gary discovered himself).
function M:Npc(npcID, mapID)
  if mapID then self:PlacesFor(mapID) end
  return self.byNpc and self.byNpc[npcID]
end

function M.QuestLine(q)
  local c = M.DIFF_COLOR[q.diff] or { 1, 1, 1 }
  return string.format("|cff%02x%02x%02x[%d] %s|r", c[1] * 255, c[2] * 255, c[3] * 255, q.level, tostring(q.name))
end

-- Places of one kind on any map (for /ride near).
-- Reads the pack rows directly so a search does not build every map.
function M:OfKind(kind)
  local out = {}
  for mapID, rows in pairs(self.raw or {}) do
    for _, r in ipairs(rows) do
      if r[2] == kind then
        out[#out + 1] = { npcID = r[1], kind = kind, mapID = mapID, x = r[3], y = r[4], name = r[5], title = r[6], faction = r[7] }
      end
    end
  end
  return out
end

function M:Activity()
  if self.count == 0 then return "not installed (optional)" end
  return string.format("%d places on %d maps (unverified, private copy)", self.count, self.mapCount)
end

ns.AddCommand("questpins", "grey on|off  show quests too low to give XP", function(arg)
  local v = (arg or ""):match("^grey%s+(%a+)$")
  if v == "on" or v == "off" then
    M:Settings().grey = v == "on"
    ns.Events:Fire("OTR_DATA_CHANGED", "quests")
    ns.Print("grey quests %s on the map", v == "on" and "shown" or "hidden")
  else
    ns.Print("usage: /ride questpins grey on|off (quest givers are colored by your level: red, orange, yellow, green)")
  end
end)

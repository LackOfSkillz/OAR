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
  self:On("PLAYER_ENTERING_WORLD", function(mod)
    -- older saves kept full reports: shrink them, for every character (all
    -- of them sit in memory, not only the one playing)
    if not mod.compacted then
      mod.compacted = true
      local db = rawget(_G, "Outrider_DB")
      for _, ch in pairs(type(db) == "table" and type(db.chars) == "table" and db.chars or {}) do
        local zq = type(ch) == "table" and ch.zoneQuests
        if type(zq) == "table" then
          for k, v in pairs(zq) do zq[k] = M.Compact(v) end
          M.Prune(zq)
        end
      end
    end
    if not mod.raceLogged then
      mod.raceLogged = true
      local name, file, raceID = C.Call("UnitRace", "player")
      mod:Info("race %s (%s) id %s, faction %s", tostring(C.Readable(name)), tostring(C.Readable(file)),
        tostring(C.Readable(raceID)), tostring(C.Call("UnitFactionGroup", "player")))
    end
    mod:LogZoneReport("login")
  end)
  self:On("QUEST_TURNED_IN", function(mod) ns.Throttle("npcpack:zone", 3, function() mod:LogZoneReport("turned in") end) end)
  -- an NPC seen up close: rebuild the places with its real spot
  self:On("OTR_NPC_PLACED", function(mod) for mapID in pairs(mod.maps or {}) do mod.maps[mapID] = nil end end)
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

-- Where you saw the NPC yourself, up close (Discovery, interact or near):
-- that beats the pack's spot (requirement 2026-11-20). mapID, x, y or nil.
function M.Seen(npcID)
  local d = ns.db.global.discovered
  local e = type(d) == "table" and type(d.npcs) == "table" and d.npcs[npcID]
  if type(e) == "table" and (e.qualityRank or 0) >= 3 and e.mapID and e.x and e.y then return e.mapID, e.x, e.y end
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
      local sm, sx, sy = M.Seen(npcID)
      if sm == mapID then cur.x, cur.y, cur.source, cur.seen = sx, sy, "discovery", true end
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
-- Quest givers carry the quests they start (requirement 2026-11-11: show
-- whether quests on the map suit the character's level). Colors follow the game's
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

-- Race-only quests (the pack's 9th field, Questie's race mask; bit = raceID).
-- No mask, or a race the client doesn't name: allowed (faction still applies).
-- A mask that names every original race of your faction means "the whole
-- faction": new races (Skyborne on Forever) are missing from those old masks,
-- and failed every such quest until this check (2026-11-13: 70 done showed as 54).
M.FACTION_RACES = { Alliance = { 1, 3, 4, 7 }, Horde = { 2, 5, 6, 8 } } -- raceIDs: human dwarf nelf gnome / orc undead tauren troll
function M.RaceOK(mask)
  if not mask or mask == 0 then return true end
  local _, _, raceID = C.Call("UnitRace", "player")
  raceID = C.Readable(raceID)
  if type(raceID) ~= "number" or raceID < 1 then return true end
  if hasBit(mask, raceID) then return true end
  local all = M.FACTION_RACES[C.Call("UnitFactionGroup", "player") or ""]
  if not all then return false end
  for _, r in ipairs(all) do if not hasBit(mask, r) then return false end end
  return true -- open to the whole faction
end

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
      and M.RaceOK(q[9]) and not done(qid) and C.Call("C_QuestLog.IsOnQuest", qid) ~= true
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
        local sm, sx, sy = M.Seen(r[1])
        out[#out + 1] = { npcID = r[1], kind = kind, mapID = sm or mapID, x = sm and sx or r[3], y = sm and sy or r[4],
          name = r[5], title = r[6], faction = r[7] }
      end
    end
  end
  return out
end

-- ---------------------------------------------------------------- zone report
-- Which quests in this zone are still not done (requirement 2026-11-13). Every quest
-- the pack's givers on this map start, sorted into done / in your log /
-- available now / locked (level or earlier quest), skipping the other
-- faction's and other classes' quests. Saved in ns.db.char.zoneQuests[mapID]
-- so Claude can read it, refreshed at login and when a quest is turned in.
function M:ZoneReport(mapID, nosave)
  local rows = self.raw and self.raw[mapID]
  if not rows then return nil end
  local level = C.Call("UnitLevel", "player") or 1
  local faction = C.Call("UnitFactionGroup", "player")
  local _, _, classID = C.Call("UnitClass", "player")
  local names, seen = {}, {}
  for _, r in ipairs(rows) do
    for _, q in ipairs(type(r[8]) == "table" and r[8] or {}) do names[q[1]] = q[2] end
  end
  local rep = { t = time(), level = level, done = 0, active = {}, available = {}, locked = {} }
  for _, r in ipairs(rows) do
    for _, q in ipairs(type(r[8]) == "table" and r[8] or {}) do
      local qid, name, req, qlvl, qfac, cls, preAny, preAll = q[1], q[2], q[3], q[4], q[5], q[6], q[7], q[8]
      local mine = (qfac == nil or qfac == faction) and (not cls or cls == 0 or not classID or hasBit(cls, classID))
        and M.RaceOK(q[9])
      if mine and not seen[qid] then
        seen[qid] = true
        -- faction and prerequisites ride along for the Nexus graph (OI02-R02)
        local entry = { id = qid, name = name, level = qlvl, giver = r[5], x = r[3], y = r[4],
          faction = qfac, preAll = preAll, preAny = preAny }
        if done(qid) then
          rep.done = rep.done + 1
        elseif C.Call("C_QuestLog.IsOnQuest", qid) == true then
          rep.active[#rep.active + 1] = entry
        else
          local why
          if req > level then why = "level " .. req end
          if not why and preAny and #preAny > 0 then
            local any = false
            for _, pq in ipairs(preAny) do if done(pq) then any = true break end end
            if not any then why = "after " .. tostring(names[preAny[1]] or preAny[1]) end
          end
          if not why and preAll then
            for _, pq in ipairs(preAll) do
              if not done(pq) then why = "after " .. tostring(names[pq] or pq) break end
            end
          end
          entry.diff = M.Difficulty(qlvl, level)
          if why then entry.why = why rep.locked[#rep.locked + 1] = entry
          else rep.available[#rep.available + 1] = entry end
        end
      end
    end
  end
  table.sort(rep.available, function(a, b) return a.level < b.level end)
  if nosave then return rep end
  ns.db.char.zoneQuests = ns.KeepTable(ns.db.char.zoneQuests, "NPCPack:ns.db.char.zoneQuests") or {}
  ns.db.char.zoneQuests[mapID] = M.Compact(rep)
  M.Prune(ns.db.char.zoneQuests)
  return rep
end

-- What gets saved: counts and up to 20 available quest names. The full report
-- (every locked quest with its reason) took 124 KB for a level 1 in one zone,
-- 2026-11-15; the log line at login still lists what is available.
M.KEEP_ZONES, M.KEEP_NAMES = 8, 20
function M.Compact(rep)
  if type(rep) ~= "table" then return rep end
  if type(rep.locked) == "number" then return rep end -- already compact
  local names = {}
  for i, q in ipairs(rep.available or {}) do
    if i > M.KEEP_NAMES then break end
    names[#names + 1] = string.format("%s [%d]", tostring(q.name), tonumber(q.level) or 0)
  end
  return { t = rep.t, level = rep.level, done = rep.done, active = #(rep.active or {}),
    availableCount = #(rep.available or {}), available = names, locked = #(rep.locked or {}) }
end

-- Keep the newest KEEP_ZONES zones.
function M.Prune(zones)
  local keys = {}
  for k, v in pairs(zones) do keys[#keys + 1] = { k, type(v) == "table" and tonumber(v.t) or 0 } end
  table.sort(keys, function(a, b) return a[2] > b[2] end)
  for i = M.KEEP_ZONES + 1, #keys do zones[keys[i][1]] = nil end
end

-- Every quest you could pick up now, anywhere the pack knows: { {id, name, level, giver, mapID, x, y, diff} }
function M:AvailableEverywhere()
  local out = {}
  for mapID in pairs(self.raw or {}) do
    local rep = self:ZoneReport(mapID, true)
    for _, q in ipairs(rep and rep.available or {}) do q.mapID = mapID out[#out + 1] = q end
  end
  return out
end

function M:LogZoneReport(why)
  local mapID = C.PlayerPosition("player")
  local rep = mapID and self:ZoneReport(mapID)
  if not rep then return end
  local avail = {}
  for _, q in ipairs(rep.available) do avail[#avail + 1] = string.format("%s [%d] (%s)", q.name, q.level, tostring(q.giver)) end
  self:Info("zone %d quests (%s): %d done, %d in log, %d available: %s; %d locked", mapID, why, rep.done, #rep.active,
    #rep.available, #avail > 0 and table.concat(avail, ", ") or "none", #rep.locked)
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

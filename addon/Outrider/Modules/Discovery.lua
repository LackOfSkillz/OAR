-- Modules/Discovery.lua
-- Builds a Forever-native NPC database from what Gary actually meets:
-- target, mouseover, nameplates, and NPC windows (merchant, trainer, ...).
-- Stored account-wide in ns.db.global.discovered.npcs[npcID] (DATA_SCHEMAS.md).
-- Position is the PLAYER's position at capture time, tagged with how close
-- that is likely to be: interact (talking to it, a few yards) beats
-- target/mouseover, which beat nameplate (up to ~40 yards off).
-- Secret values (Midnight-era restriction, C6) are skipped, never stored.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Discovery", {
  title = "Discovery (record NPCs you meet)",
  phase = "P2",
  order = 20,
  defaults = { skipCritters = true },
})

-- "near": seen within ~10 yards (CheckInteractDistance), as good as talking
-- to it (requirement 2026-11-20: standing right next to the NPC).
local QUALITY = { nameplate = 1, mouseover = 2, target = 2, near = 3, interact = 3 }
M.QUALITY = QUALITY
-- A sure sighting this far (map share) from the stored spot means the NPC
-- moved or the old spot was wrong: start over instead of averaging.
M.MOVED = 0.03
local RECENT_MAX = 300 -- enough history to read respawn timings back (50 lasted 40 minutes, 2026-11-13)

-- NPC windows: event -> role tag. The unit is "npc" while the window is open.
local ROLE_EVENTS = {
  MERCHANT_SHOW = "vendor", GOSSIP_SHOW = "gossip", TRAINER_SHOW = "trainer",
  TAXIMAP_OPENED = "flightmaster", BANKFRAME_OPENED = "banker",
  PET_STABLE_SHOW = "stablemaster", MAIL_SHOW = "mailbox",
}

function M:OnInitialize()
  local g = ns.db.global
  g.discovered = ns.KeepTable(g.discovered, "Discovery:g.discovered") or {}
  local d = g.discovered
  d.npcs = ns.KeepTable(d.npcs, "Discovery:d.npcs") or {}
  d.recent = ns.KeepTable(d.recent, "Discovery:d.recent") or {}
  self.db = d
  self.pendingPlates = {}
end

function M:OnEnable()
  self:On("PLAYER_TARGET_CHANGED", function(mod) mod:Capture("target", "target") end)
  self:On("UPDATE_MOUSEOVER_UNIT", function(mod) mod:Capture("mouseover", "mouseover") end)
  self:On("NAME_PLATE_UNIT_ADDED", self.OnPlateAdded)
  for event, role in pairs(ROLE_EVENTS) do
    self:On(event, function(mod) mod:Capture("npc", "interact", role) end)
  end
end

function M:OnDisable()
  ns.ThrottleCancel("discovery:plates")
  self.pendingPlates = {}
end

-- Nameplates arrive in bursts (entering a camp): collect, process 4x/s max.
function M:OnPlateAdded(_, unit)
  if type(unit) ~= "string" then return end
  self.pendingPlates[unit] = true
  ns.Throttle("discovery:plates", 0.25, function() M:FlushPlates() end)
end

function M:FlushPlates()
  local units = self.pendingPlates
  self.pendingPlates = {}
  for unit in pairs(units) do
    if C.Call("UnitExists", unit) then self:Capture(unit, "nameplate") end
  end
end

local function inInstance()
  local inside = C.Call("IsInInstance")
  return inside and true or false
end

-- Returns the stored entry, or nil and a reason it was skipped.
function M:Capture(unit, how, role)
  if not C.Call("UnitExists", unit) then return nil, "no unit" end
  if C.Call("UnitIsPlayer", unit) then return nil, "player" end
  local npcID, g = C.UnitNpcID(unit)
  if not npcID or not g or g.kind ~= "Creature" then return nil, "not a creature" end
  local name = C.Readable(C.Call("UnitName", unit))
  if type(name) ~= "string" then return nil, "secret or no name" end
  local ctype = C.Readable(C.Call("UnitCreatureType", unit))
  if self:Settings().skipCritters and ctype == "Critter" and not role then return nil, "critter" end

  local now = time()
  local e = self.db.npcs[npcID]
  local isNew = e == nil
  if isNew then
    e = { name = name, firstSeen = now, seen = 0, roles = {} }
    self.db.npcs[npcID] = e
  end
  e.name = name
  e.seen = (e.seen or 0) + 1
  e.lastSeen = now
  local level = C.Readable(C.Call("UnitLevel", unit))
  if type(level) == "number" then e.level = level end
  e.classification = C.Readable(C.Call("UnitClassification", unit)) or e.classification
  e.family = C.Readable(C.Call("UnitCreatureFamily", unit)) or e.family
  e.creatureType = ctype or e.creatureType
  e.title = C.UnitTitle(unit) or e.title
  -- the NPC's own faction, so suggestions never send an Alliance character to a Horde NPC (2026-11-13)
  local fac = C.Readable(C.Call("UnitFactionGroup", unit))
  if fac == "Alliance" or fac == "Horde" then e.faction = fac elseif fac then e.faction = "Neutral" end
  if C.LayerOf(g) and not inInstance() then e.layer = C.LayerOf(g) end

  -- close enough to touch: a sure position, out of combat only (the range
  -- check is restricted in combat on the modern client)
  if how ~= "interact" and not C.InCombat() and C.Call("CheckInteractDistance", unit, 3) then how = "near" end
  local before = e.qualityRank == 3 and e.mapID and { e.mapID, e.x, e.y } or nil
  local upgraded, moved = self:UpdatePosition(e, how)
  local newRole = false
  if role then
    e.roles = type(e.roles) == "table" and e.roles or {}
    local has = false
    for _, r in ipairs(e.roles) do if r == role then has = true end end
    if not has then e.roles[#e.roles + 1] = role newRole = true end
  end

  local recent = self.db.recent
  recent[#recent + 1] = { npcID = npcID, name = name, how = how, role = role, mapID = e.mapID, x = e.x, y = e.y, t = now }
  while #recent > RECENT_MAX and ns.Archive:Shift("discoveredRecent", recent, { path = "global.discovered.recent" }) do end

  if isNew or upgraded or newRole then
    self:Info("captured npcID=%d %s how=%s q=%s map=%s %s%s", npcID, name, how, tostring(e.quality),
      tostring(e.mapID), e.x and string.format("%.3f,%.3f", e.x, e.y) or "nopos", role and (" role=" .. role) or "")
  else
    self:Debug("seen npcID=%d %s how=%s", npcID, name, how)
  end
  -- a sure spot that is new or moved: places and the NPC pack follow it
  if e.qualityRank == 3 and (not before or moved or before[1] ~= e.mapID) then
    ns.Events:Fire("OTR_NPC_PLACED", npcID, e)
  end
  return e
end

-- Best quality wins. Repeated interact captures are averaged (they are all
-- within a few yards of the NPC, so the mean is closer to the real spot).
function M:UpdatePosition(e, how)
  local mapID, x, y = C.PlayerPosition("player")
  if not mapID or not x or not y then return false end
  local q = QUALITY[how] or 1
  local old = e.qualityRank or 0
  if q > old or (q == old and e.mapID ~= mapID and q < 3) then
    e.mapID, e.x, e.y, e.quality, e.qualityRank, e.posN = mapID, x, y, how, q, 1
    return q > old
  end
  -- a sure sighting on another map, or far from the stored spot: it moved
  -- (or the old spot was wrong), so the new spot replaces it
  if q == 3 and old == 3 and (e.mapID ~= mapID or math.abs(e.x - x) > M.MOVED or math.abs(e.y - y) > M.MOVED) then
    self:Info("npc %s moved: map %s %.1f,%.1f -> map %s %.1f,%.1f", tostring(e.name), tostring(e.mapID), e.x * 100, e.y * 100,
      tostring(mapID), x * 100, y * 100)
    e.mapID, e.x, e.y, e.quality, e.posN = mapID, x, y, how, 1
    return false, true
  end
  if q == old and q == 3 and e.mapID == mapID then
    local n = (e.posN or 1)
    e.x = (e.x * n + x) / (n + 1)
    e.y = (e.y * n + y) / (n + 1)
    e.posN = n + 1
  end
  return false
end

function M:Recent(n)
  local out, r = {}, self.db.recent
  for i = math.max(1, #r - (n or 10) + 1), #r do out[#out + 1] = r[i] end
  return out
end

function M:Count()
  local n = 0
  for _ in pairs(self.db.npcs) do n = n + 1 end
  return n
end

function M:Snapshot()
  return { known = self:Count() }
end

ns.AddCommand("discovered", "[n]  last n NPCs Outrider recorded (default 10)", function(arg)
  if not M.db then ns.Print("discovery is off for this character") return end
  local list = M:Recent(tonumber(arg) or 10)
  ns.Print("%d NPCs known. Last %d:", M:Count(), #list)
  for _, r in ipairs(list) do
    ns.Print("%s (%d) %s%s map %s %s", r.name, r.npcID, r.how, r.role and ("/" .. r.role) or "",
      tostring(r.mapID), r.x and string.format("%.1f,%.1f", r.x * 100, r.y * 100) or "")
  end
end)

function M:Activity()
  local today, start = 0, time() - 86400
  for _, e in pairs(self.db.npcs) do if (e.firstSeen or 0) >= start then today = today + 1 end end
  local last = self.db.recent[#self.db.recent]
  return string.format("%d NPCs known, %d new today%s", self:Count(), today, last and (", last: " .. last.name) or "")
end

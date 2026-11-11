-- Modules/Sightings.lua
-- Remembers every rare sighting (OTR_RARE_SEEN) account-wide in
-- ns.db.global.sightings[npcID] (DATA_SCHEMAS.md), newest last, 50 per NPC,
-- and works out respawn windows per layer:
--   * pack data (respawn.min/max) gives a window after a dead/tamed sighting;
--   * otherwise we learn: dead on layer L, later alive on layer L = one
--     observed respawn gap. Observed ranges are shown only after 3+ gaps
--     (never present a guess as fact, hard rule 7).
-- Taming a rare (it becomes Gary's pet, same npcID) records state "tamed".

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Sightings", {
  title = "Rare sightings and respawn windows",
  phase = "P2",
  order = 28,
  defaults = {},
})
ns.Sightings = M

M.CAP, M.OBS_CAP, M.MIN_OBS = 50, 20, 3

function M:OnInitialize()
  local g = ns.db.global
  g.sightings = type(g.sightings) == "table" and g.sightings or {}
  g.respawnObs = type(g.respawnObs) == "table" and g.respawnObs or {}
  self.db, self.obs = g.sightings, g.respawnObs
end

function M:OnEnable()
  self:On("OTR_RARE_SEEN", self.OnRareSeen)
  self:On("UNIT_PET", self.OnPet)
  self:On("UNIT_SPELLCAST_CHANNEL_START", self.OnChannel)
end

function M:Record(npcID, s)
  local list = self.db[npcID]
  if not list then list = {} self.db[npcID] = list end
  -- learn a respawn gap: the last death on this layer, then alive again
  if s.state == "alive" then
    for i = #list, 1, -1 do
      local p = list[i]
      if p.layer == s.layer then
        if p.state == "alive" then break end
        if p.state == "dead" or p.state == "tamed" then
          self:Learn(npcID, s.t - p.t, s.layer)
          break
        end
      end
    end
  end
  list[#list + 1] = s
  while #list > self.CAP do table.remove(list, 1) end
  self:Info("sighting npcID=%d %s layer=%s map=%s how=%s", npcID, s.state, tostring(s.layer), tostring(s.mapID), tostring(s.how))
  ns.Events:Fire("OTR_SIGHTING_ADDED", npcID, s)
  return s
end

function M:Learn(npcID, gap, layer)
  if gap <= 0 then return end
  local o = self.obs[npcID]
  if not o then o = {} self.obs[npcID] = o end
  o[#o + 1] = gap
  while #o > self.OBS_CAP do table.remove(o, 1) end
  self:Info("respawn observed npcID=%d gap=%ds layer=%s (%d observations)", npcID, gap, tostring(layer), #o)
end

function M:OnRareSeen(_, info)
  self:Record(info.npcID, {
    t = info.t or time(), layer = info.layer, mapID = info.mapID, x = info.x, y = info.y,
    how = info.how, by = ns.db.key, state = info.dead and "dead" or "alive",
  })
end

-- A freshly tamed pet keeps the beast's npcID in its GUID.
-- On Forever every hunter pet has the same generic npcID (165189, seen when
-- Gary tamed Mystmane, 2026-11-11), so the beast is remembered when the Tame
-- Beast channel starts, and the new pet within 30 s is that beast.
function M:OnChannel(_, unit, _, spellID)
  if unit ~= "player" then return end
  local info = C.Call("C_Spell.GetSpellInfo", spellID)
  local name = type(info) == "table" and C.Readable(info.name) or C.Readable((C.Call("GetSpellInfo", spellID)))
  if name ~= "Tame Beast" then return end
  local npcID = C.UnitNpcID("target")
  if npcID then self.taming = { npcID = npcID, t = GetTime and GetTime() or 0 } end
end

function M:OnPet(_, unit)
  if unit ~= "player" then return end
  local id
  local now = GetTime and GetTime() or 0
  if self.taming and now - self.taming.t <= 30 and C.Call("UnitExists", "pet") then
    id = self.taming.npcID
    self.taming = nil
  else
    id = C.UnitNpcID("pet")
  end
  if not id or id == self.lastPetID then return end
  self.lastPetID = id
  if not ns.Data:Get("rare", id) and not self.db[id] then return end
  local mapID, x, y = C.PlayerPosition("player")
  local layer = ns.Layers and ns.Layers.current or nil
  self:Record(id, { t = time(), layer = layer, mapID = mapID, x = x, y = y, how = "tame", by = ns.db.key, state = "tamed" })
end

-- Respawn range { min, max, source } from the pack, else from 3+ observations.
function M:Range(npcID)
  local pack = ns.Data:Get("rare", npcID)
  if pack and pack.respawn and pack.respawn.min and pack.respawn.max then
    return pack.respawn.min, pack.respawn.max, pack.verified and "pack" or "pack (unverified)"
  end
  local o = self.obs[npcID]
  if o and #o >= self.MIN_OBS then
    local lo, hi = math.huge, 0
    for _, g in ipairs(o) do if g < lo then lo = g end if g > hi then hi = g end end
    return lo, hi, string.format("observed x%d", #o)
  end
end

function M:Last(npcID, layer)
  local list = self.db[npcID]
  if not list then return nil end
  for i = #list, 1, -1 do
    if layer == nil or list[i].layer == layer then return list[i] end
  end
end

-- { state = "unknown"|"alive"|"waiting"|"open"|"overdue"|"dead", last, opensIn, closesIn, source }
function M:Window(npcID, layer, now)
  now = now or time()
  local last = self:Last(npcID, layer)
  if not last then return { state = "unknown" } end
  if last.state == "alive" then return { state = "alive", last = last } end
  local lo, hi, source = self:Range(npcID)
  if not lo then return { state = "dead", last = last } end
  local opens, closes = last.t + lo, last.t + hi
  if now < opens then return { state = "waiting", last = last, opensIn = opens - now, source = source } end
  if now <= closes then return { state = "open", last = last, closesIn = closes - now, source = source } end
  return { state = "overdue", last = last, source = source }
end

local function mins(sec) return math.floor(sec / 60 + 0.5) end

function M:Describe(npcID, layer, now)
  now = now or time()
  local w = self:Window(npcID, layer, now)
  if w.state == "unknown" then return "never seen" end
  local ago = mins(now - w.last.t)
  if w.state == "alive" then return string.format("alive, seen %d min ago", ago) end
  if w.state == "dead" then return string.format("%s %d min ago, no respawn data yet", w.last.state, ago) end
  if w.state == "waiting" then return string.format("window opens in %d min (%s)", mins(w.opensIn), w.source) end
  if w.state == "open" then return string.format("window open now, %d min left (%s)", mins(w.closesIn), w.source) end
  return string.format("window passed, %s %d min ago (%s)", w.last.state, ago, w.source)
end

function M:Activity()
  local n, total = 0, 0
  for _, list in pairs(self.db) do n = n + 1 total = total + #list end
  return string.format("%d sightings of %d rares saved", total, n)
end

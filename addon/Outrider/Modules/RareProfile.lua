-- Modules/RareProfile.lua
-- What a rare is like in a fight (requirement 2026-11-13: collect fight data,
-- starting with Mystmane), built by itself whenever a rare is on screen, no
-- typing, no combat log (hard rule 4):
--   * when RareScan sees it (target, mouseover, nameplate): level, max health,
--     attack speed, family, classification;
--   * every spell it starts or finishes casting (UNIT_SPELLCAST_START /
--     _SUCCEEDED for the unit we see it on): how many times and the gap
--     between casts in one encounter. Ravage, the knockdown that breaks Tame
--     Beast, is the one that matters for taming.
-- Account-wide in ns.db.global.rareProfiles[npcID]. Logged once at logout
-- for rares on the watch list; shown on the rare's tooltip.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("RareProfile", {
  title = "Rare profiles (fight data for watched rares)",
  phase = "P2",
  order = 34,
  defaults = {},
})
ns.RareProfile = M

M.MAX_GAPS = 10

function M:OnInitialize()
  local g = ns.db.global
  g.rareProfiles = type(g.rareProfiles) == "table" and g.rareProfiles or {}
  self.units = {}   -- unit token -> npcID currently known to be that rare
end

function M:Profile(npcID, name)
  local all = ns.db.global.rareProfiles
  local p = all[npcID]
  if not p then p = { name = name, spells = {}, seen = 0 } all[npcID] = p end
  if name then p.name = name end
  return p
end

-- RareScan saw it: read its stats from the unit it was seen on.
function M:OnSeen(_, info)
  if type(info) ~= "table" or not info.npcID or not info.unit then return end
  local unit = info.unit
  self.units[unit] = info.npcID
  local p = self:Profile(info.npcID, info.name)
  p.seen = (p.seen or 0) + 1
  p.lastSeen = time()
  p.level = info.level or p.level
  p.family = info.family or p.family
  p.classification = info.classification or p.classification
  local hp = C.Readable(C.Call("UnitHealthMax", unit))
  if type(hp) == "number" and hp > 0 then p.hpMax = hp end
  local speed = C.Readable(C.Call("UnitAttackSpeed", unit))
  if type(speed) == "number" and speed > 0 then p.attackSpeed = speed end
end

-- Which rare is this unit token right now? (the token can be reused)
function M:RareOn(unit)
  if type(unit) ~= "string" or unit == "player" or unit == "pet" then return nil end
  local npcID = C.UnitNpcID(unit)
  if npcID and ns.db.global.rareProfiles[npcID] then return npcID end
  return nil
end

function M:OnSpell(event, unit, _, spellID)
  -- In combat the spell can be a secret value: never use it as a table key or
  -- compare it (hard rule 4; the Tools tab in Settings logged this 83 times, B3).
  if C.IsSecret(unit) or C.IsSecret(spellID) then return end
  local npcID = self:RareOn(unit)
  if not npcID or C.IsSecret(npcID) then return end
  local name = C.SpellName(spellID)
  if type(name) ~= "string" or C.IsSecret(name) then return end
  local p = self:Profile(npcID)
  local s = p.spells[name] or { n = 0, gaps = {} }
  p.spells[name] = s
  local now = C.Call("GetTime") or 0
  -- a start and its success are one cast: count the start, or the success if no start came
  if event == "UNIT_SPELLCAST_SUCCEEDED" and s.started and now - s.started < 5 then s.started = nil return end
  if event == "UNIT_SPELLCAST_START" then s.started = now end
  s.n = s.n + 1
  if s.lastT and now - s.lastT < 120 then -- same encounter
    s.gaps[#s.gaps + 1] = now - s.lastT
    while #s.gaps > M.MAX_GAPS do ns.Archive:Shift("rareCastGaps", s.gaps) end
  end
  s.lastT = now
  self:Debug("%s casts %s", tostring(p.name), name)
end

-- "Ravage x3 (about every 14s)"
function M.SpellLine(name, s)
  local avg
  if s.gaps and #s.gaps > 0 then
    local sum = 0
    for _, g in ipairs(s.gaps) do sum = sum + g end
    avg = sum / #s.gaps
  end
  return string.format("%s x%d%s", name, s.n or 0, avg and string.format(" (about every %ds)", math.floor(avg + 0.5)) or "")
end

function M:Summary(npcID)
  local p = ns.db.global.rareProfiles[npcID]
  if not p then return nil end
  local parts = {}
  if p.level then parts[#parts + 1] = "level " .. p.level end
  if p.family then parts[#parts + 1] = tostring(p.family):lower() end
  if p.hpMax then parts[#parts + 1] = "health " .. p.hpMax end
  if p.attackSpeed then parts[#parts + 1] = string.format("attacks every %.1fs", p.attackSpeed) end
  local spells = {}
  for name, s in pairs(p.spells or {}) do spells[#spells + 1] = M.SpellLine(name, s) end
  table.sort(spells)
  if #spells > 0 then parts[#parts + 1] = "casts " .. table.concat(spells, ", ") end
  return string.format("%s: %s (seen %d times)", tostring(p.name), table.concat(parts, ", "), p.seen or 0)
end

function M:OnLogout()
  local scan = ns.Modules:Get("RareScan")
  for npcID, p in pairs(ns.db.global.rareProfiles) do
    if scan and scan:IsWatched(npcID, p.name) then self:Info("rare profile %s", self:Summary(npcID)) end
  end
end

function M:OnEnable()
  self:On("OTR_RARE_SEEN", self.OnSeen)
  self:On("UNIT_SPELLCAST_START", self.OnSpell)
  self:On("UNIT_SPELLCAST_SUCCEEDED", self.OnSpell)
  self:On("PLAYER_LOGOUT", self.OnLogout)
end

-- Tooltip line for a rare with a profile (spells it casts).
ns.TooltipLines:Add("unit", "rarefight", M, function(tip)
  if not tip.GetUnit then return nil end
  local _, unit = tip:GetUnit()
  local npcID = unit and C.UnitNpcID(unit)
  local p = npcID and ns.db.global.rareProfiles[npcID]
  if not p or not next(p.spells or {}) then return nil end
  local spells = {}
  for name, s in pairs(p.spells) do spells[#spells + 1] = M.SpellLine(name, s) end
  table.sort(spells)
  return { { "Casts: " .. table.concat(spells, ", "), "warn" } }
end)

function M:Activity()
  local n = 0
  for _ in pairs(ns.db.global.rareProfiles) do n = n + 1 end
  return string.format("%d rares profiled", n)
end

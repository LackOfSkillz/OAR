-- Modules/BeastInfo.lua  (P2-10)
-- Extra lines on beast tooltips: family, level vs yours, "tameable" for
-- hunters, and for known rares the last sighting / respawn window. Shift
-- shows pack details (attack speed, abilities), marked unverified when so.
-- Hook: TooltipDataProcessor.AddTooltipPostCall (present on Forever, probe
-- 2026-11-11), falling back to GameTooltip OnTooltipSetUnit. Post-hooks only;
-- nothing of Blizzard's is replaced. Secret values are skipped (C6).

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("BeastInfo", {
  title = "Beast tooltips",
  phase = "P2",
  order = 38,
  defaults = {},
})

-- Beast lines through the shared ordered block (P7-05)
ns.TooltipLines:Add("unit", "beast", M, function(tip) return M:OnTooltip(tip) end)

-- Lines to add for a unit (pure, testable). Returns a list of strings.
function M:Lines(unit, shift)
  if not C.Call("UnitExists", unit) or C.Call("UnitIsPlayer", unit) then return {} end
  local family = C.Readable(C.Call("UnitCreatureFamily", unit))
  local npcID, g = C.UnitNpcID(unit)
  -- someone's pet. Warlock demons carry their own creature id; every hunter
  -- pet on Forever carries the same placeholder id (captured 2026-11-15: a
  -- bear, a wolf and Khreos's tamed Ghostfang all read 165189, while the
  -- stable list showed Ghostfang's real creatureID 276111), so a hunter
  -- pet's GUID says nothing about what it was tamed from.
  local petOf = g and g.kind == "Pet" and npcID or nil
  if petOf == M.HUNTER_PET_ID then petOf = false end
  local isPet = petOf ~= nil
  if not petOf then petOf = nil end
  local pack = npcID and not isPet and ns.Data:Get("rare", npcID)
  local known = npcID and not isPet and ns.Sightings and ns.Sightings.db and ns.Sightings.db[npcID]
  if not family and not pack and not known then return {} end
  local lines = {}
  if petOf then lines[#lines + 1] = "Tamed from: " .. M.TamedFrom(petOf) end
  local level = C.Readable(C.Call("UnitLevel", unit))
  local mine = C.Call("UnitLevel", "player")
  if family then
    local parts = { family }
    if type(level) == "number" and level > 0 then parts[#parts + 1] = string.format("level %d (you %d)", level, mine or 0) end
    if ns.PlayerClass() == "HUNTER" then
      local classification = C.Readable(C.Call("UnitClassification", unit))
      if classification == "worldboss" then
        parts[#parts + 1] = "not tameable"
      elseif type(level) == "number" and mine and level > mine then
        parts[#parts + 1] = "tameable at " .. level
      else
        parts[#parts + 1] = "tameable"
      end
    end
    lines[#lines + 1] = table.concat(parts, " · ")
    -- How fast it hits, read live from the game (Gary, 2026-11-13: "which pet
    -- has the best DPS?"). Lower is faster; remembered for the Finder.
    if ns.PlayerClass() == "HUNTER" then
      local speed = C.Readable(C.Call("UnitAttackSpeed", unit))
      if type(speed) == "number" and speed > 0 then
        local feel = speed <= 1.3 and "fast" or speed >= 2.2 and "slow" or "average"
        lines[#lines + 1] = string.format("Attacks every %.1fs (%s)", speed, feel)
        local d = npcID and ns.db.global.discovered and ns.db.global.discovered.npcs[npcID]
        if d then d.attackSpeed = speed end
        -- another hunter's pet (Gary, 2026-11-15: "Ice Ember, level 12, 1.1 s,
        -- where do I get that?"): pets carry their owner's name for them, so
        -- keep what identifies the beast (family, level, speed, model), never
        -- the owner's or the pet's name, once per pet per session
        if isPet and not C.Call("UnitIsUnit", unit, "pet") then self:NotePet(unit, family, level, speed, petOf) end
      end
    end
  end
  if pack or known then
    lines[#lines + 1] = "Rare: " .. ns.Sightings:Describe(npcID, ns.Layers and ns.Layers.current)
  end
  if shift and pack and pack.beast then
    local b = pack.beast
    local tag = pack.verified and "" or " (unverified)"
    if b.attackSpeed then lines[#lines + 1] = string.format("Attack speed %.2f%s", b.attackSpeed, tag) end
    if b.abilities then lines[#lines + 1] = "Abilities: " .. table.concat(b.abilities, ", ") .. tag end
  end
  return lines
end

-- Fast pets other hunters have: ns.db.global.petsSeen (newest 50), so Claude
-- can match family + speed to a rare. The model id (display) tells beasts of
-- one family apart; the client exposes it only through the model frame, so
-- it is left out unless C_PlayerInfo/UnitCreatureDisplayID exists.
M.HUNTER_PET_ID = 165189   -- the id in every hunter pet's GUID (see Lines)

-- "The Rake (rare, Mulgore)" / "Plainstrider (npc 2955)" / "npc 12345"
function M.TamedFrom(npcID)
  local pack = ns.Data:Get("rare", npcID)
  if pack then return string.format("%s (rare, %s)", pack.name, ns.Travel and ns.Travel.ZoneName(pack.mapID) or "?") end
  local d = ns.db.global.discovered and ns.db.global.discovered.npcs and ns.db.global.discovered.npcs[npcID]
  if d and d.name then
    local rare = d.classification == "rare" or d.classification == "rareelite"
    return string.format("%s (%s%s)", d.name, rare and "rare, " or "", d.mapID and ns.Travel and ns.Travel.ZoneName(d.mapID) or ("npc " .. npcID))
  end
  return "npc " .. npcID
end

function M:NotePet(unit, family, level, speed, npcID)
  local guid = C.Call("UnitGUID", unit)
  self.petNoted = self.petNoted or {}
  if not guid or self.petNoted[guid] then return end
  self.petNoted[guid] = true
  local g = ns.db.global
  g.petsSeen = type(g.petsSeen) == "table" and g.petsSeen or {}
  local mapID = C.PlayerPosition("player")
  local display = C.Readable(C.Call("UnitCreatureDisplayID", unit))
  local e = { npcID = npcID, from = npcID and M.TamedFrom(npcID) or "unknown (hunter pet)", family = family, level = type(level) == "number" and level or nil, speed = speed, mapID = mapID,
    display = type(display) == "number" and display or nil, t = time() }
  table.insert(g.petsSeen, e)
  while #g.petsSeen > 50 do table.remove(g.petsSeen, 1) end
  self:Info("hunter pet seen: tamed from %s, %s level %s, attacks every %.2fs%s (map %s)", tostring(e.from), tostring(family), tostring(e.level), speed,
    e.display and (", model " .. e.display) or "", tostring(mapID))
end

function M:OnTooltip(tip)
  if tip ~= GameTooltip or not tip.GetUnit then return end
  local _, unit = tip:GetUnit()
  if not unit then return end
  local shift = C.Call("IsShiftKeyDown") and true or false
  return self:Lines(unit, shift)
end

function M:Activity() return "adds family, level and tameable lines to beast tooltips" end

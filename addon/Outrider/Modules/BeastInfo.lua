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
  local npcID = C.UnitNpcID(unit)
  local pack = npcID and ns.Data:Get("rare", npcID)
  local known = npcID and ns.Sightings and ns.Sightings.db and ns.Sightings.db[npcID]
  if not family and not pack and not known then return {} end
  local lines = {}
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

function M:OnTooltip(tip)
  if tip ~= GameTooltip or not tip.GetUnit then return end
  local _, unit = tip:GetUnit()
  if not unit then return end
  local shift = C.Call("IsShiftKeyDown") and true or false
  return self:Lines(unit, shift)
end

function M:Activity() return "adds family, level and tameable lines to beast tooltips" end

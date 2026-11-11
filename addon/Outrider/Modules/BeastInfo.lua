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

local hooked = false

function M:OnEnable()
  if hooked then return end
  hooked = true
  local add = C.Resolve("TooltipDataProcessor.AddTooltipPostCall")
  local enum = C.Resolve("Enum.TooltipDataType.Unit")
  if type(add) == "function" and enum then
    add(enum, function(tip) if M.enabled then ns.Safe("BeastInfo:tooltip", M.OnTooltip, M, tip) end end)
  elseif GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnTooltipSetUnit", function(tip) if M.enabled then ns.Safe("BeastInfo:tooltip", M.OnTooltip, M, tip) end end)
  else
    self:Warn("no tooltip hook available")
  end
end

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
  local r, g, b = ns.Theme:Color("accent")
  for _, line in ipairs(self:Lines(unit, shift)) do tip:AddLine(line, r, g, b) end
end

function M:Activity() return "adds family, level and tameable lines to beast tooltips" end

-- Modules/Tooltips.lua  (P7-05 tooltip style, Clean dark D14)
-- Flat Clean dark tooltip (GameTooltip's NineSlice recolored, never moved),
-- a class-colored border for players, a thin flat health bar, and a
-- "Target: <name>" line on unit tooltips (through the ordered TooltipLines
-- block). Colors are reset for non-player tooltips so a class border never
-- sticks. Secret values in combat are treated as unknown (no target line).
-- Steps aside for tooltip addons (TipTac, ElvUI).

local _, ns = ...
local C = ns.Compat
local Theme = ns.Theme
local M = ns:NewModule("Tooltips", {
  title = "Tooltip style and target line",
  phase = "P7",
  order = 102,
  defaults = { target = true, hideInCombat = true, questLeft = true },
  yieldsTo = { "TipTac", "ElvUI", "TinyTooltip" },
})
ns.Tooltips = M

local function nineSlice(tip)
  local n = tip and tip.NineSlice
  return type(n) == "table" and n or nil
end

function M:Style(tip, border)
  local ns9 = nineSlice(tip)
  if not ns9 then return false end
  local br, bg = border or { Theme:Color("border") }, { Theme:Color("bg") }
  if ns9.SetCenterColor then pcall(ns9.SetCenterColor, ns9, bg[1], bg[2], bg[3], 0.94) end
  if ns9.SetBorderColor then pcall(ns9.SetBorderColor, ns9, br[1], br[2], br[3], 1) end
  local bar = rawget(_G, "GameTooltipStatusBar")
  if bar and bar.SetStatusBarTexture and not self.barStyled then
    self.barStyled = true
    pcall(bar.SetStatusBarTexture, bar, "Interface\\Buttons\\WHITE8x8")
    pcall(bar.SetHeight, bar, 4)
  end
  return true
end

-- Border color for the unit on the tooltip: class color for players.
function M.BorderFor(unit)
  if not unit or not C.Readable(C.Call("UnitIsPlayer", unit)) then return nil end
  local _, class = C.Call("UnitClass", unit)
  class = C.Readable(class)
  local cc = class and (rawget(_G, "RAID_CLASS_COLORS") or {})[class]
  return cc and { cc.r, cc.g, cc.b } or nil
end

function M:ShouldHide()
  return self:Settings().hideInCombat and C.InCombat() and
    not C.Call("IsShiftKeyDown")
end

function M:EnforceVisibility(tip)
  if tip == rawget(_G, "GameTooltip") and self.enabled and self:ShouldHide() then
    tip:Hide()
    return true
  end
  return false
end

-- The typed quest objective tooltip lines are already supplied by the client.
-- Report only incomplete counters and never guess quest progress in combat.
function M:QuestProgress(unit)
  if not unit or not self:Settings().questLeft then return {} end
  local data = C.Call("C_TooltipInfo.GetUnit", unit)
  if type(data) ~= "table" or type(data.lines) ~= "table" then return {} end
  local out = {}
  for _, line in ipairs(data.lines) do
    local val = type(line) == "table" and C.Readable(line.leftText)
    if line and line.type == 8 and type(val) == "string" then
      local have, need = val:match("(%d+)%s*/%s*(%d+)")
      have, need = tonumber(have), tonumber(need)
      if have and need and need > have and need <= 10000 then
        local desc = val:gsub("^[%s%-]+", ""):gsub(":%s*%d+%s*/%s*%d+.*$", "")
        out[#out + 1] = string.format("Quest: %s (%d left)", desc, need - have)
        if #out >= 4 then break end
      end
    end
  end
  return out
end

function M:OnEnable()
  local tooltip = rawget(_G, "GameTooltip")
  if tooltip and tooltip.HookScript and not self.visibilityHooked then
    self.visibilityHooked = true
    tooltip:HookScript("OnShow", function(tip) M:EnforceVisibility(tip) end)
  end
  self:On("PLAYER_REGEN_DISABLED", function(mod)
    local tip = rawget(_G, "GameTooltip")
    if tip then mod:EnforceVisibility(tip) end
  end)
  if self.hooked then return end
  self.hooked = true
  local add = C.Resolve("TooltipDataProcessor.AddTooltipPostCall")
  local all = C.Resolve("TooltipDataProcessor.AllTypes")
  local unitEnum = C.Resolve("Enum.TooltipDataType.Unit")
  if type(add) ~= "function" then return end
  -- every tooltip: Clean dark; unit tooltips: class border for players
  add(all or unitEnum, function(tip)
    if not M.enabled or tip ~= rawget(_G, "GameTooltip") then return end
    if M:EnforceVisibility(tip) then return end
    local unit
    if tip.GetUnit then local ok, _, u = pcall(tip.GetUnit, tip) unit = ok and u or nil end
    ns.Safe("Tooltips:style", M.Style, M, tip, M.BorderFor(unit))
  end)
end

-- "Target: name" through the ordered block (P7-05)
ns.TooltipLines:Add("unit", "target", M, function(tip)
  if not M:Settings().target or not tip.GetUnit then return nil end
  local _, unit = tip:GetUnit()
  if not unit then return nil end
  local tunit = unit .. "target"
  if not C.Call("UnitExists", tunit) then return nil end
  local name = C.Readable(C.Call("UnitName", tunit))
  if type(name) ~= "string" then return nil end
  if C.Call("UnitIsUnit", tunit, "player") then name = ">> YOU <<" end
  return { { "Target: " .. name, "warn" } }
end)

function M:Activity() return "Clean dark tooltips, class borders for players, target line" end

-- Objective progress available in NPC tooltip data, not the combat log.
ns.TooltipLines:Add("unit", "questleft", M, function(tip)
  if not tip.GetUnit or M:ShouldHide() then return nil end
  local _, unit = tip:GetUnit()
  local lines = M:QuestProgress(unit)
  local out = {}
  for _, v in ipairs(lines) do out[#out + 1] = { v, "good" } end
  return out
end)

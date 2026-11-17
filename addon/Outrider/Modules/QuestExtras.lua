-- Modules/QuestExtras.lua
-- Quest extras (gap analysis 2026-11-17):
--   * Quest marks on nameplates: a mob or object your quests need gets a
--     small quest mark beside its nameplate with what's left ("Wolves 3/8").
--     The client says which units belong to an active quest
--     (C_QuestLog.UnitIsRelatedToActiveQuest) and the objective line comes
--     from the unit's own tooltip data (C_TooltipInfo.GetUnit). Our own frame
--     anchored to the plate, never a child of it; forbidden plates skipped.
--   * Quest XP: what the quests in your log are worth (GetQuestLogRewardXP),
--     shown on the info bar's XP part.
-- Steps aside for nameplate addons that already mark quests.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("QuestExtras", {
  title = "Quest marks and quest XP",
  phase = "P7",
  order = 49,
  defaults = { plates = true },
  yieldsTo = { "Plater", "TidyPlates_ThreatPlates", "Kui_Nameplates", "Questie_NameplateObjectives" },
})
ns.QuestExtras = M

M.ICON = "Interface\\GossipFrame\\AvailableQuestIcon"
M.SIZE = 18

local function readable(v) return v ~= nil and C.Readable(v) and v or nil end

function M:OnInitialize() self.pool, self.active = {}, {} end

-- ------------------------------------------------------------------ quest XP
function M:LogXP()
  local n = tonumber(readable(C.Call("C_QuestLog.GetNumQuestLogEntries"))) or 0
  local getInfo = C.Resolve("C_QuestLog.GetInfo")
  local xpOf = C.Resolve("GetQuestLogRewardXP")
  if type(getInfo) ~= "function" or type(xpOf) ~= "function" then return 0 end
  local total = 0
  for i = 1, math.min(n, 50) do
    local ok, q = pcall(getInfo, i)
    if ok and type(q) == "table" and not q.isHeader and q.questID then
      local ok2, xp = pcall(xpOf, q.questID)
      xp = ok2 and tonumber(readable(xp)) or 0
      total = total + xp
    end
  end
  return total
end

-- ------------------------------------------------------------------ plates
-- The objective lines a unit's tooltip shows for your quests ("Wolves slain: 3/8").
function M.ObjectiveText(unit)
  local get = C.Resolve("C_TooltipInfo.GetUnit")
  if type(get) ~= "function" then return nil end
  local ok, data = pcall(get, unit)
  if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
  local kinds = rawget(_G, "Enum") and Enum.TooltipDataLineType or {}
  local objective = kinds.QuestObjective or 8
  local out = {}
  for _, line in ipairs(data.lines) do
    local text = readable(line.leftText)
    if type(text) == "string" and (line.type == objective or text:find("%d+/%d+")) then
      text = text:gsub("^%s*%-?%s*", "")
      local done = line.completed or (function()
        local a, b = text:match("(%d+)/(%d+)")
        return a and b and tonumber(a) >= tonumber(b)
      end)()
      if not done then out[#out + 1] = text end
    end
  end
  return #out > 0 and table.concat(out, "\n") or nil
end

function M.IsQuestUnit(unit)
  if readable(C.Call("UnitIsPlayer", unit)) then return false end
  local related = C.Resolve("C_QuestLog.UnitIsRelatedToActiveQuest")
  if type(related) == "function" then
    local ok, yes = pcall(related, unit)
    if ok and readable(yes) == false then return false end
    if ok and readable(yes) then return true end
  end
  return M.ObjectiveText(unit) ~= nil
end

local function plateFor(unit)
  local get = C.Resolve("C_NamePlate.GetNamePlateForUnit")
  if type(get) ~= "function" then return nil end
  local ok, plate = pcall(get, unit)
  if not ok or not plate then return nil end
  if plate.IsForbidden and plate:IsForbidden() then return nil end
  return plate
end

function M:Marker()
  local m = table.remove(self.pool)
  if m then return m end
  m = CreateFrame("Frame", nil, UIParent)
  m:SetSize(M.SIZE, M.SIZE)
  m:SetFrameStrata("HIGH")
  m.icon = m:CreateTexture(nil, "OVERLAY")
  m.icon:SetAllPoints()
  m.icon:SetTexture(M.ICON)
  m.text = ns.UI.Text(m, "small", "text")
  m.text:SetPoint("LEFT", m, "RIGHT", 2, 0)
  m.text:SetJustifyH("LEFT")
  return m
end

function M:Mark(unit)
  if type(unit) ~= "string" or not self:Settings().plates then return end
  if not M.IsQuestUnit(unit) then self:Unmark(unit) return end
  local plate = plateFor(unit)
  if not plate then return end
  local m = self.active[unit] or self:Marker()
  local text = M.ObjectiveText(unit)
  m.text:SetText(text and (text:match("^[^\n]+") or text) or "")
  m:ClearAllPoints()
  m:SetPoint("RIGHT", plate, "LEFT", -2, 0)
  m:Show()
  self.active[unit] = m
end

function M:Unmark(unit)
  local m = self.active[unit]
  if not m then return end
  m:Hide()
  self.active[unit] = nil
  self.pool[#self.pool + 1] = m
end

function M:RefreshAll()
  for unit in pairs(self.active) do self:Mark(unit) end
  for i = 1, 40 do
    local unit = "nameplate" .. i
    if not self.active[unit] and readable(C.Call("UnitExists", unit)) then self:Mark(unit) end
  end
end

function M:OnEnable()
  self:On("NAME_PLATE_UNIT_ADDED", function(mod, _, unit) mod:Mark(unit) end)
  self:On("NAME_PLATE_UNIT_REMOVED", function(mod, _, unit) mod:Unmark(unit) end)
  self:On("QUEST_LOG_UPDATE", function(mod) ns.Throttle("questextras:refresh", 1, function() mod:RefreshAll() end) end)
  self:On("UNIT_QUEST_LOG_CHANGED", function(mod) ns.Throttle("questextras:refresh", 1, function() mod:RefreshAll() end) end)
end

function M:OnDisable()
  for unit in pairs(self.active) do self:Unmark(unit) end
end

function M:Activity()
  local n = 0
  for _ in pairs(self.active) do n = n + 1 end
  return string.format("quest marks on %d nameplates; quests in your log worth %d XP", n, self:LogXP())
end

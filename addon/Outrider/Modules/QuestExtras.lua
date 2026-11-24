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

function M:OnInitialize()
  self.pool, self.active = {}, {}
end

-- XP pace is session-only. Reload/login starts a new sample; it never guesses
-- XP earned while offline. Two earned-XP events separated by at least 60 s
-- of observed activity are required before displaying a rate.
function M:ResetPace()
  self.pace = {
    level = tonumber(readable(C.Call("UnitLevel", "player"))),
    xp = tonumber(readable(C.Call("UnitXP", "player"))),
    need = tonumber(readable(C.Call("UnitXPMax", "player"))),
    gained = 0, ratedXP = 0, activeSeconds = 0, lastGain = nil,
  }
end

function M:OnXP()
  if not self.pace then self:ResetPace() return end
  local p = self.pace
  local level = tonumber(readable(C.Call("UnitLevel", "player")))
  local xp = tonumber(readable(C.Call("UnitXP", "player")))
  local need = tonumber(readable(C.Call("UnitXPMax", "player")))
  if not (level and xp and need and need > 0) then return end
  if not (p.xp and p.need and p.level) then
    p.xp, p.need, p.level = xp, need, level
    return
  end
  local delta = 0
  if level == p.level then
    delta = math.max(0, xp - p.xp)
  elseif level == p.level + 1 then
    delta = math.max(0, p.need - p.xp) + xp
  end
  p.xp, p.need, p.level = xp, need, level
  if delta <= 0 then return end
  local now = C.Call("GetTime") or 0
  if p.lastGain then
    local elapsed = now - p.lastGain
    if elapsed >= 1 and elapsed <= 600 then
      p.activeSeconds = p.activeSeconds + elapsed
      p.ratedXP = p.ratedXP + delta
    elseif elapsed > 600 then
      -- Ignore AFK time and start a fresh active-pace window.
      p.activeSeconds, p.ratedXP = 0, 0
    end
  end
  p.lastGain = now
  p.gained = p.gained + delta
end

function M:Pace()
  local p = self.pace
  if not p then return { gained = 0 } end
  local perHour = p.activeSeconds >= 60 and p.ratedXP > 0 and p.ratedXP * 3600 / p.activeSeconds or nil
  local xp = tonumber(readable(C.Call("UnitXP", "player")))
  local need = tonumber(readable(C.Call("UnitXPMax", "player")))
  return {
    gained = p.gained, activeSeconds = p.activeSeconds, perHour = perHour,
    secondsToLevel = perHour and xp and need and need > xp and (need - xp) * 3600 / perHour or nil,
  }
end

-- ------------------------------------------------------------------ quest XP
function M:QuestXP()
  local n = tonumber(readable(C.Call("C_QuestLog.GetNumQuestLogEntries"))) or 0
  local getInfo = C.Resolve("C_QuestLog.GetInfo")
  local xpOf = C.Resolve("GetQuestLogRewardXP")
  if type(getInfo) ~= "function" or type(xpOf) ~= "function" then return 0, 0, {} end
  local total, ready, items = 0, 0, {}
  for i = 1, math.min(n, 80) do
    local ok, q = pcall(getInfo, i)
    if ok and type(q) == "table" and not q.isHeader and q.questID then
      local ok2, val = pcall(xpOf, q.questID)
      local xp = ok2 and tonumber(readable(val)) or 0
      if xp >= 0 then
        total = total + xp
        local done = readable(q.isComplete) or readable(q.complete)
        if done == nil then done = readable(C.Call("C_QuestLog.IsComplete", q.questID)) end
        if done then ready = ready + xp end
        items[#items + 1] = { id = q.questID, title = readable(q.title) or ("Quest " .. q.questID),
          xp = xp, ready = done and true or false }
      end
    end
  end
  return total, ready, items
end

function M:LogXP()
  return self:QuestXP()
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
  m.icon:SetSize(M.SIZE, M.SIZE)
  m.icon:SetPoint("LEFT", m, "LEFT", 0, 0)
  m.icon:SetTexture(M.ICON)
  m.text = ns.UI.Text(m, "small", "text")
  m.text:SetPoint("LEFT", m.icon, "RIGHT", 2, 0)
  m.text:SetJustifyH("LEFT")
  return m
end

-- The words on the plate. The game already prints the creature's name, so
-- "5/7 Mangy Nightsaber slain" on a Mangy Nightsaber is just "5/7" (requirement
-- 2026-11-22: less cluttered plates); an item to collect keeps a short name ("Pelt 3/8").
function M.Short(text, name)
  if type(text) ~= "string" then return "" end
  text = text:match("^[^\n]+") or text
  local count = text:match("(%d+/%d+)")
  if not count then return text end
  if type(name) == "string" and name ~= "" and text:lower():find(name:lower(), 1, true) then return count end
  local words = text:gsub("%d+/%d+", ""):gsub("%s*[:%-]%s*", " "):gsub("%s+slain", ""):match("^%s*(.-)%s*$")
  if #words > 14 then words = words:sub(1, 13) .. "…" end
  return words ~= "" and (words .. " " .. count) or count
end

function M:Mark(unit)
  if type(unit) ~= "string" or not self:Settings().plates then return end
  if not M.IsQuestUnit(unit) then self:Unmark(unit) return end
  local plate = plateFor(unit)
  if not plate then return end
  local m = self.active[unit] or self:Marker()
  local text = M.ObjectiveText(unit)
  m.text:SetText(M.Short(text, readable(C.Call("UnitName", unit))))
  -- above the plate, centred, so it never runs across the game's own name
  local w = m.text.GetStringWidth and tonumber((m.text:GetStringWidth())) or 0
  m:SetSize(M.SIZE + (w > 0 and (w + 2) or 0), M.SIZE)
  m:ClearAllPoints()
  m:SetPoint("BOTTOM", plate, "TOP", 0, 2)
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
  self:ResetPace()
  self:On("PLAYER_XP_UPDATE", self.OnXP)
  self:On("PLAYER_LEVEL_UP", self.OnXP)
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

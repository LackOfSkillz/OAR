-- Modules/QuestTracker.lua
-- Outrider's quest tracker, like Questie's (Gary, 2026-11-17: "add all of
-- that"): your quests grouped by zone, nearest first (or by level), each
-- objective with your party's progress under it ("Oni 6/10").
--   click a quest        the arrow goes to its nearest objective or turn-in
--   right-click a quest  fold it; click a zone to fold the zone
--   hover a quest        chain, breadcrumb, reputation and category
--   drag the title       move it (saved per character)
-- The game's own tracker stays unless "Hide the game's tracker" is on (out of
-- combat only; one owner per frame, hard rule 8). Yields to Questie, whose
-- tracker does the same.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("QuestTracker", {
  title = "Quest tracker",
  phase = "P4",
  order = 48,
  defaults = { show = true, sort = "distance", folded = {}, foldedZones = {}, hideBlizzard = false, scrollOffset = 0, focus = nil },
  yieldsTo = { "Questie" },
})
ns.QuestTracker = M

M.WIDTH, M.ROW, M.MAX_ROWS = 270, 15, 20 -- visible viewport; full log is scrollable
local function readable(v) return C.Readable(v) end

-- { { zone, quests = { {questID, title, level, complete, objectives} } } } from the log
function M.Read()
  local zones, cur = {}, nil
  local n = tonumber(readable(C.Call("C_QuestLog.GetNumQuestLogEntries"))) or 0
  local info = C.Resolve("C_QuestLog.GetInfo")
  if type(info) ~= "function" then return zones end
  for i = 1, math.min(n, 80) do
    local ok, q = pcall(info, i)
    if ok and type(q) == "table" then
      if q.isHeader then
        cur = { zone = readable(q.title) or "?", quests = {} }
        zones[#zones + 1] = cur
      elseif q.questID then
        if not cur then cur = { zone = "Quests", quests = {} } zones[#zones + 1] = cur end
        local QO = ns.QuestObjectives
        local list = QO and QO.Objectives(q.questID) or {}
        local complete
        if QO then complete = QO.IsDone(q.questID, q, list) else complete = readable(q.isComplete) == true end
        cur.quests[#cur.quests + 1] = { questID = q.questID, title = readable(q.title) or "?", level = readable(q.level) or 0,
          complete = complete, objectives = list }
      end
    end
  end
  for i = #zones, 1, -1 do if #zones[i].quests == 0 then table.remove(zones, i) end end
  return zones
end

function M:Distance(questID)
  local spot = ns.QuestObjectives and ns.QuestObjectives:Nearest(questID)
  if not spot then return 99 end
  local here, px, py = C.PlayerPosition("player")
  if spot.mapID ~= here or not px then return 50 end
  return math.sqrt((spot.x - px) ^ 2 + (spot.y - py) ^ 2)
end

-- the lines to draw: { text, color, questID?, zone?, indent }
function M:Lines()
  local s = self:Settings()
  local zones = M.Read()
  local mine = tonumber(readable(C.Call("UnitLevel", "player"))) or 1
  local out = {}
  for _, z in ipairs(zones) do
    for _, q in ipairs(z.quests) do
      q.dist = s.sort == "distance" and self:Distance(q.questID) or 0
    end
    table.sort(z.quests, function(a, b)
      if s.sort == "distance" and a.dist ~= b.dist then return a.dist < b.dist end
      if a.level ~= b.level then return a.level < b.level end
      return a.title < b.title
    end)
    z.best = z.quests[1] and z.quests[1].dist or 99
  end
  if s.sort == "distance" then table.sort(zones, function(a, b) return a.best < b.best end) end
  for _, z in ipairs(zones) do
    local zf = s.foldedZones[z.zone]
    out[#out + 1] = { text = (zf and "+ " or "- ") .. z.zone .. " (" .. #z.quests .. ")", color = "goldText", zone = z.zone }
    if not zf then
      for _, q in ipairs(z.quests) do
        local diff = ns.NPCPack and ns.NPCPack.Difficulty and ns.NPCPack.Difficulty(q.level, mine) or "yellow"
        local c = ns.NPCPack and ns.NPCPack.DIFF_COLOR and ns.NPCPack.DIFF_COLOR[diff] or { 1, 0.82, 0 }
        local hex = string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
        local title = string.format("%s[%d] %s|r%s", hex, q.level, q.title, q.complete and " |cff7fff7f(ready)|r" or "")
        out[#out + 1] = { text = title, questID = q.questID, indent = 6 }
        if not s.folded[q.questID] then
          for _, o in ipairs(q.objectives) do
            out[#out + 1] = { text = (o.finished and "|cff7fff7f" or "|cffd0d0d0") .. "  " .. o.text .. "|r", indent = 12, questID = q.questID }
            if ns.PartyQuests and ns.PartyQuests.enabled then
              local party = ns.PartyQuests:ObjectiveLines(q.questID, o.text)
              if #party > 0 then out[#out + 1] = { text = "|cff8fb4ff    " .. table.concat(party, ", ") .. "|r", indent = 18, questID = q.questID } end
            end
          end
          if q.complete and #q.objectives == 0 then
            out[#out + 1] = { text = "|cff7fff7f  Ready to hand in|r", indent = 12, questID = q.questID }
          end
        end
      end
    end
  end
  return out
end

-- ------------------------------------------------------------------ frame
function M:Build()
  if self.frame then return self.frame end
  local f = CreateFrame("Frame", "Outrider_QuestTracker", UIParent, ns.Theme:BackdropTemplate())
  ns.Theme:ApplyPanel(f, "bg", "border")
  f:SetAlpha(0.92)
  f:SetSize(M.WIDTH, 60)
  f:SetFrameStrata("MEDIUM")
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  local head = CreateFrame("Button", nil, f)
  head:SetPoint("TOPLEFT", 6, -4)
  head:SetPoint("TOPRIGHT", -70, -4)
  head:SetHeight(18)
  head:RegisterForDrag("LeftButton")
  head:SetScript("OnDragStart", function() f:StartMoving() end)
  head:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    local point, _, rel, x, y = f:GetPoint()
    M:Settings().point = { point, rel, x, y }
  end)
  f.title = ns.UI.Text(head, "normal", "goldText")
  f.title:SetPoint("LEFT")
  f.sort = ns.UI:Button(f, "Nearest", 62, function()
    local s = M:Settings()
    s.sort = s.sort == "distance" and "level" or "distance"
    M:Refresh()
  end)
  f.sort:SetHeight(18)
  f.sort:SetPoint("TOPRIGHT", -4, -4)
  f.rows = {}
  f:EnableMouseWheel(true)
  f:SetScript("OnMouseWheel", function(_, delta) M:Scroll(-delta * 3) end)
  self.frame = f
  self:Place()
  return f
end

function M:Place()
  local f, p = self.frame, self:Settings().point
  if not f then return end
  f:ClearAllPoints()
  if type(p) == "table" and p[1] then
    f:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
  else
    f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -90, -260)
  end
end

function M:Row(i)
  local f = self.frame
  local r = f.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, f)
  r:SetHeight(M.ROW)
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  r.text = ns.UI.Text(r, "small", "text")
  r.text:SetPoint("LEFT")
  r.text:SetPoint("RIGHT")
  r.text:SetJustifyH("LEFT")
  r.text:SetWordWrap(false)
  r:SetScript("OnClick", function(self, button) ns.Safe("tracker:click", M.Click, M, self.line, button) end)
  r:SetScript("OnEnter", function(self) ns.Safe("tracker:hover", M.Hover, M, self) end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.rows[i] = r
  return r
end

function M:Scroll(delta)
  local s = self:Settings()
  local total = #(self:Lines())
  s.scrollOffset = math.max(0, math.min(math.max(0, total - M.MAX_ROWS), (s.scrollOffset or 0) + delta))
  self:Refresh()
end

function M:Focus(questID)
  local s = self:Settings()
  if questID and not self:QuestExists(questID) then return false end
  if s.focus == questID then s.focus = nil else s.focus = questID end
  if ns.MapPins then ns.MapPins:Invalidate() ns.MapPins:Refresh() end
  local mm = ns.Modules:Get("MinimapPins")
  if mm and mm.Update then mm:Update() end
  self:Refresh()
  return true
end

function M:QuestExists(questID)
  for _, z in ipairs(M.Read()) do
    for _, q in ipairs(z.quests) do if q.questID == questID then return true end end
  end
  return false
end

function M:Click(line, button)
  if not line then return end
  local s = self:Settings()
  if line.zone then
    s.foldedZones[line.zone] = not s.foldedZones[line.zone] or nil
  elseif line.questID and (button == "MiddleButton" or (button == "LeftButton" and C.Call("IsShiftKeyDown"))) then
    self:Focus(line.questID)
    return
  elseif line.questID and button == "RightButton" then
    s.folded[line.questID] = not s.folded[line.questID] or nil
  elseif line.questID and ns.QuestObjectives then
    if not ns.QuestObjectives:Guide(line.questID) then ns.Print("no location known for that quest") end
    return
  end
  self:Refresh()
end

function M:Hover(row)
  local line = row.line
  if not (line and line.questID) then return end
  GameTooltip:SetOwner(row, "ANCHOR_LEFT")
  GameTooltip:AddLine(row.text:GetText() or "")
  if ns.QuestInfo and ns.QuestInfo.enabled then
    for _, l in ipairs(ns.QuestInfo:Lines(line.questID)) do GameTooltip:AddLine(l, ns.Theme:Color("accent")) end
  end
  if ns.PartyQuests and ns.PartyQuests.enabled then
    for _, who in ipairs(ns.PartyQuests:ProgressFor(line.questID)) do
      GameTooltip:AddLine(who.name .. (who.done and ": done" or ": " .. table.concat(who.lines, "; ")), ns.Theme:Color("muted"))
    end
  end
  GameTooltip:AddLine("Click: arrow. Right-click: fold. Shift-click: focus/dim other quest pins.", ns.Theme:Color("muted"))
  GameTooltip:Show()
end

function M:Refresh()
  if not self.enabled then return end
  local s = self:Settings()
  if not s.show then if self.frame then self.frame:Hide() end return end
  local f = self:Build()
  local lines = self:Lines()
  local n = 0
  for _, l in ipairs(lines) do if l.questID and l.indent == 6 then n = n + 1 end end
  local maxOffset = math.max(0, #lines - M.MAX_ROWS)
  s.scrollOffset = math.min(math.max(0, s.scrollOffset or 0), maxOffset)
  if s.focus and not self:QuestExists(s.focus) then s.focus = nil end
  f.title:SetText(string.format("Quests (%d) %d-%d/%d%s", n,
    #lines > 0 and s.scrollOffset + 1 or 0, math.min(#lines, s.scrollOffset + M.MAX_ROWS), #lines,
    s.focus and " [focused]" or ""))
  f.sort.label:SetText(s.sort == "distance" and "Nearest" or "Level")
  local shown = math.min(math.max(0, #lines - s.scrollOffset), M.MAX_ROWS)
  for i = 1, shown do
    local r = self:Row(i)
    local l = lines[i + s.scrollOffset]
    r.line = l
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", f, "TOPLEFT", 8 + (l.indent or 0), -24 - (i - 1) * M.ROW)
    r:SetPoint("RIGHT", f, "RIGHT", -6, 0)
    r.text:SetText(l.text)
    r:SetAlpha(s.focus and l.questID and l.questID ~= s.focus and 0.45 or 1)
    if l.color then r.text:SetTextColor(ns.Theme:Color(l.color)) else r.text:SetTextColor(1, 1, 1) end
    r:Show()
  end
  for i = shown + 1, #f.rows do f.rows[i]:Hide() f.rows[i].line = nil end
  f:SetHeight(30 + shown * M.ROW)
  f:SetShown(#lines > 0)
  self:Blizzard()
end

-- The game's tracker: hidden only when asked, and only out of combat.
function M:Blizzard()
  local want = self:Settings().hideBlizzard and self.enabled and self:Settings().show
  if want == self.blizzHidden then return end
  if C.InCombat() then return end
  for _, name in ipairs({ "ObjectiveTrackerFrame", "QuestWatchFrame", "WatchFrame" }) do
    local fr = rawget(_G, name)
    if fr and fr.SetAlpha then
      pcall(fr.SetAlpha, fr, want and 0 or 1)
      if fr.EnableMouse then pcall(fr.EnableMouse, fr, not want) end
    end
  end
  self.blizzHidden = want
end

function M:OnEnable()
  local function later() ns.Throttle("questtracker:refresh", 0.5, function() M:Refresh() end) end
  for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED" }) do
    self:On(e, later)
  end
  self:On("OTR_COMM", function(_, _, kind) if kind == "QSTAT" then later() end end)
  self:On("CHAT_MSG_PARTY", later)
  self:On("CHAT_MSG_PARTY_LEADER", later)
  self:On("PLAYER_ENTERING_WORLD", function(mod) mod:Refresh() end)
end

function M:OnDisable()
  if self.frame then self.frame:Hide() end
  self:Blizzard()
end

ns.AddCommand("tracker", "Outrider quest tracker: on|off|reset|level|nearest|up|down|focus <questID>|unfocus", function(arg)
  arg = tostring(arg or ""):lower()
  local s = M:Settings()
  if arg == "on" or arg == "off" then s.show = arg == "on"
  elseif arg == "reset" then s.point = nil M:Place()
  elseif arg == "level" then s.sort = "level"
  elseif arg == "nearest" then s.sort = "distance"
  elseif arg == "up" then M:Scroll(-M.MAX_ROWS) return
  elseif arg == "down" then M:Scroll(M.MAX_ROWS) return
  elseif arg == "unfocus" then M:Focus(nil) return
  elseif arg:match("^focus%s+%d+$") then
    local qid = tonumber(arg:match("%d+"))
    if not M:Focus(qid) then ns.Print("quest not in active log: %d", qid) end
    return
  else s.show = not s.show end
  M:Refresh()
  ns.Print("quest tracker %s, sorted by %s", s.show and "on" or "off", s.sort == "distance" and "nearest" or "level")
end)

function M:Activity()
  return string.format("quest tracker %s", self:Settings().show and "on" or "off")
end

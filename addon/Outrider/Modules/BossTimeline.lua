-- Modules/BossTimeline.lua (DEEP-38)
-- Forever's C_EncounterTimeline.GetEventList exists but return shape was
-- not captured. All unknown/secret payload fields fail closed: no fabricated
-- cooldown timers, no combat-log API and no protected frame modifications.
local _, ns = ...
local C, UI = ns.Compat, ns.UI
local M = ns:NewModule("BossTimeline", {
  title = "Encounter timeline and boss notes",
  phase = "P6", order = 87,
  defaults = { notes = {}, enabled = true, showUnknown = false },
})
ns.BossTimeline = M
M.MAX_NOTES, M.MAX_EVENTS = 60, 30

function M:Notes()
  local s = self:Settings()
  s.notes = type(s.notes) == "table" and s.notes or {}
  return s.notes
end

function M:NoteFor(boss)
  return self:Notes()[tostring(boss or ""):lower()]
end

function M:SetNote(boss, text)
  if type(boss) ~= "string" or boss == "" or #boss > 80 then return false end
  if text ~= nil and (type(text) ~= "string" or #text > 1500) then return false end
  local count = 0
  for _ in pairs(self:Notes()) do count = count + 1 end
  if count >= M.MAX_NOTES and not self:NoteFor(boss) then return false end
  self:Notes()[boss:lower()] = text and { text = text, at = time() } or nil
  return true
end

-- A read-only summary from the live client. No assumptions about timer
-- origin or expiry. Only explicit, readable timeRemaining becomes a timer.
function M:Events()
  local getter = C.Resolve("C_EncounterTimeline.GetEventList")
  if type(getter) ~= "function" then return {}, "timeline API unavailable" end
  local ok, list = pcall(getter)
  if not ok or type(list) ~= "table" then return {}, "timeline list unavailable" end
  local out = {}
  for _, raw in ipairs(list) do
    if #out >= M.MAX_EVENTS then break end
    if type(raw) == "table" then
      local id = C.Readable(raw.eventID) or C.Readable(raw.spellID)
      local name = C.Readable(raw.name) or C.Readable(raw.title)
      local sec = tonumber(C.Readable(raw.timeRemaining))
      local status = C.Readable(raw.status)
      if type(name) == "string" and name ~= "" then
        out[#out + 1] = { id = id, name = name,
          remaining = sec and sec >= 0 and sec <= 3600 and sec or nil,
          status = type(status) == "string" and status or nil,
          source = "client encounter timeline" }
      elseif type(id) == "number" and self:Settings().showUnknown then
        out[#out + 1] = { id = id, name = "Unknown event " .. id,
          remaining = sec and sec >= 0 and sec <= 3600 and sec or nil,
          source = "client timeline; event not identified" }
      end
    end
  end
  return out, #out > 0 and "client event list" or "no readable named events"
end

function M:Rows()
  local out, note = {}, self.currentBoss and self:NoteFor(self.currentBoss)
  if note then out[#out + 1] = { text = "Notes for " .. self.currentBoss .. ": " .. note.text, kind = "note" } end
  local events, status = self:Events()
  out[#out + 1] = { text = "Encounter timeline: " .. status, kind = "status" }
  for _, event in ipairs(events) do
    out[#out + 1] = { kind = "timeline", text = string.format("%s%s",
      event.name, event.remaining and string.format(" (%.1fs remaining)", event.remaining) or " (time unknown)") }
  end
  return out
end

function M:Build()
  if self.window then return self.window end
  local f = UI:Window("Outrider_BossTimeline", "Boss notes and timeline", 510, 340,
    ns.db.char.bossTimelineWindow or {})
  self.window = f
  local tip = UI.Text(f.content, "small", "muted")
  tip:SetPoint("TOPLEFT", 4, -3)
  tip:SetWidth(480)
  tip:SetText("Only readable client timeline events are shown. Unknown timers stay unknown.")
  f.list = UI:ScrollList(f.content, {
    rows = 10, rowHeight = 25,
    render = function(row, e) row.text:SetText(e.text) end,
  })
  f.list:SetPoint("TOPLEFT", 3, -26)
  f.list:SetPoint("RIGHT", -3, 0)
  f:Hide()
  return f
end

function M:Refresh()
  if not (self.window and self.window:IsShown()) then return end
  self.window.list:SetItems(self:Rows())
end

function M:OnEnable()
  self:On("ENCOUNTER_TIMELINE_EVENT_ADDED", function(mod) mod:Refresh() end)
  self:On("ENCOUNTER_START", function(mod, _, id, name)
    local readable = C.Readable(name)
    if type(readable) == "string" then mod.currentBoss = readable end
    mod:Refresh()
  end)
  self:On("ENCOUNTER_END", function(mod) mod:Refresh() end)
end

function M:OnDisable() if self.window then self.window:Hide() end end
function M:Activity()
  local events = self:Events()
  return #events .. " readable encounter events"
end

ns.AddCommand("bossnotes", "bossnotes list|show <name>|set <name> :: <notes>|clear <name>|timeline", function(arg)
  arg = tostring(arg or "")
  if arg == "list" then
    local keys = {}
    for k in pairs(M:Notes()) do keys[#keys + 1] = k end
    table.sort(keys)
    ns.Print("boss notes: %s", #keys > 0 and table.concat(keys, ", ") or "none saved")
    return
  end
  local boss, note = arg:match("^set%s+(.+)%s+::%s+(.+)$")
  if boss then
    ns.Print(M:SetNote(boss, note) and "boss note saved" or "invalid note")
    return
  end
  boss = arg:match("^clear%s+(.+)$")
  if boss then ns.Print(M:SetNote(boss, nil) and "note removed" or "unknown boss") return end
  boss = arg:match("^show%s+(.+)$")
  if boss then
    M.currentBoss = boss
    local saved = M:NoteFor(boss)
    ns.Print("%s: %s", boss, saved and saved.text or "no note saved")
    return
  end
  local f = M:Build()
  M:Refresh()
  f:SetShown(not f:IsShown())
  if f:IsShown() then M:Refresh() end
end)

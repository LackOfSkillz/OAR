-- Modules/PartyQuests.lua
-- Quest announcements to the party, like Questie's (requirement 2026-11-17:
-- Questie announces progress to the party, including when all members have
-- completed a quest; Outrider does the same).
--   your progress   "Outrider: Shadowhide Pendant: 10/10 for [Solomon's Law]!"
--                   when an objective is done, "Quest ready to hand in" when
--                   all are, "Quest completed" when you hand it in (each once)
--   everyone done   when every party member on a quest you share has finished
--                   it: "Outrider: everyone is done with [Quest], go hand it in!"
-- Who is done comes from three places:
--   * Outrider users in the party: a QSTAT addon message (PARTY only) with the
--     quests they've finished, sent when it changes;
--   * Questie users: their own party announcements ("Questie: <objective> for
--     [quest]!" and "Quest Completed: [quest]") read from party chat;
--   * whether a member has the quest at all: C_QuestLog.IsUnitOnQuest.
-- A member with neither addon never reports, so "everyone done" never fires
-- for a quest they share (we can't see their progress).
-- Messages go to PARTY only (hard rule 10), at most one a second, and our own
-- announcements step aside when Questie is installed (it already sends them).

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("PartyQuests", {
  title = "Party quest announcements",
  phase = "P8",
  order = 92,
  defaults = { announce = true, everyone = true },
})
ns.PartyQuests = M

M.GAP = 1.0
local function readable(v) return C.Readable(v) end

function M:OnInitialize()
  self.prev = nil         -- questID -> { complete, objectives = { [i] = finished } }
  self.members = {}       -- short name -> { done = { [questID] = true }, obj = { [questID] = { [text] = true } } }
  self.said = {}          -- message key -> true (each once a session)
  self.queue, self.last = {}, 0
end

-- "Name-Realm" / "Name" -> "name"
function M.Short(name)
  if type(name) ~= "string" then return nil end
  return (name:match("^([^%-]+)") or name):lower()
end

function M.QuestLink(questID, title)
  local link = readable(C.Call("GetQuestLink", questID))
  if type(link) == "string" and link ~= "" then return link end
  return "[" .. tostring(title or ("quest " .. questID)) .. "]"
end

-- objective text without its counter: "Shadowhide Pendant: 10/10" -> "shadowhide pendant"
function M.Key(text)
  if type(text) ~= "string" then return "" end
  text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  text = text:gsub("%s*:?%s*%d+%s*/%s*%d+%s*", " "):gsub("%(.-%)", ""):gsub("[%p]", " ")
  return (text:lower():gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

-- ------------------------------------------------------------------ group
function M:InParty()
  return readable(C.Call("IsInGroup")) and not readable(C.Call("IsInRaid"))
end

function M:Party()
  local out = {}
  for i = 1, 4 do
    local unit = "party" .. i
    if readable(C.Call("UnitExists", unit)) then
      local name = readable(C.Call("UnitName", unit))
      if name then out[#out + 1] = { unit = unit, name = M.Short(name) } end
    end
  end
  return out
end

function M:Member(short)
  local m = self.members[short]
  if not m then m = { done = {}, obj = {} } self.members[short] = m end
  return m
end

-- ------------------------------------------------------------------ sending
function M:Say(key, text)
  if self.said[key] then return end
  self.said[key] = true
  self.queue[#self.queue + 1] = text
  self:Pump()
end

function M:Pump()
  if #self.queue == 0 or not self:InParty() then self.queue = {} return end
  local now = GetTime and GetTime() or time()
  if now - (self.last or 0) < M.GAP then
    if not self.pumping then
      self.pumping = true
      ns.Timer.After(M.GAP, function() M.pumping = false M:Pump() end, "partyquests:pump")
    end
    return
  end
  local text = table.remove(self.queue, 1)
  local send = C.Resolve("C_ChatInfo.SendChatMessage") or rawget(_G, "SendChatMessage")
  if type(send) == "function" then
    local ok = pcall(send, text, "PARTY")
    if ok then self.last = now self:Debug("party: %s", text) end
  end
  if #self.queue > 0 then self:Pump() end
end

-- Questie on this client already announces your progress; don't double it.
function M:OwnAnnounces()
  if not self:Settings().announce then return false end
  local loaded = C.Resolve("C_AddOns.IsAddOnLoaded") or rawget(_G, "IsAddOnLoaded")
  if type(loaded) == "function" then
    local ok, on = pcall(loaded, "Questie")
    if ok and on then return false end
  end
  return true
end

-- ------------------------------------------------------------------ your quests
function M:Scan()
  local log = ns.QuestObjectives and ns.QuestObjectives.Log() or {}
  local now, changed, sig = {}, false, {}
  for _, q in ipairs(log) do
    local objs = {}
    for i, o in ipairs(q.objectives) do objs[i] = o.finished end
    now[q.questID] = { complete = q.complete, objectives = objs, title = q.title, list = q.objectives }
    local before = self.prev and self.prev[q.questID]
    local announce = before and self:InParty() and self:OwnAnnounces()
    if before then
      for i, o in ipairs(q.objectives) do
        if o.finished and not before.objectives[i] then
          ns.Events:Fire("OTR_QUEST_OBJECTIVE", q.questID, i, o.text)
          if announce then
            self:Say("obj:" .. q.questID .. ":" .. i, string.format("Outrider: %s for %s!", o.text, M.QuestLink(q.questID, q.title)))
          end
        end
      end
      if q.complete and not before.complete then
        ns.Events:Fire("OTR_QUEST_READY", q.questID)
        if announce then
          self:Say("ready:" .. q.questID, string.format("Outrider: Quest ready to hand in: %s", M.QuestLink(q.questID, q.title)))
        end
      end
    end
    for _, o in ipairs(q.objectives) do sig[#sig + 1] = o.text end
    if q.complete ~= (before and before.complete) then changed = true end
  end
  self.prev = now
  local signature = table.concat(sig, "|")
  if signature ~= self.signature then self.signature, changed = signature, true end
  if changed then self:Share() end
  self:CheckEveryone()
end

function M:OnTurnedIn(_, questID)
  questID = tonumber(readable(questID))
  if not questID then return end
  local q = self.prev and self.prev[questID]
  if self:InParty() and self:OwnAnnounces() then
    self:Say("done:" .. questID, string.format("Outrider: Quest completed: %s", M.QuestLink(questID, q and q.title)))
  end
  self.handedIn = self.handedIn or {}
  self.handedIn[questID] = true
  self:Share()
end

function M:MyDone()
  local out = {}
  for id, q in pairs(self.prev or {}) do if q.complete then out[#out + 1] = id end end
  for id in pairs(self.handedIn or {}) do out[#out + 1] = id end
  table.sort(out)
  return out
end

-- your objective texts per quest ("Shadowhide Pendant: 6/10"), for the party
function M:MyProgress()
  local out, n = {}, 0
  for id, q in pairs(self.prev or {}) do
    local texts = {}
    for _, o in ipairs(q.list or {}) do texts[#texts + 1] = o.text end
    if #texts > 0 and n < 25 then out[id] = texts n = n + 1 end
  end
  return out
end

-- Party members' progress on a quest: { { name, lines = { "text", ... }, done } }
function M:ProgressFor(questID)
  local out = {}
  for _, p in ipairs(self:InParty() and self:Party() or {}) do
    local m = self.members[p.name]
    local lines = {}
    if m and m.prog and type(m.prog[questID]) == "table" then
      for _, t in ipairs(m.prog[questID]) do if type(t) == "string" then lines[#lines + 1] = t end end
    elseif m and m.obj[questID] then
      for k in pairs(m.obj[questID]) do lines[#lines + 1] = k .. ": done" end
    end
    local done = m and self:MemberDone(m, questID, self.prev and self.prev[questID])
    if #lines > 0 or done then
      local name = readable(C.Call("UnitName", p.unit)) or p.name
      out[#out + 1] = { name = name, lines = lines, done = done }
    end
  end
  return out
end

-- Party lines for one objective of yours ("Oni 6/10"), matched by its text.
function M:ObjectiveLines(questID, text)
  local key, out = M.Key(text), {}
  for _, who in ipairs(self:ProgressFor(questID)) do
    for _, l in ipairs(who.lines) do
      if M.Key(l) == key or M.Key(l:gsub(": done$", "")) == key then
        local count = l:match("(%d+%s*/%s*%d+)") or (l:find(": done$") and "done") or l
        out[#out + 1] = who.name .. " " .. count
      end
    end
  end
  return out
end

-- ------------------------------------------------------------------ others
function M:Share()
  if not self:InParty() or not ns.Comm or not ns.Comm.enabled then return end
  ns.Throttle("partyquests:share", 2, function()
    ns.Comm:Send("QSTAT", { done = M:MyDone(), prog = M:MyProgress() }, "PARTY")
  end)
end

function M:OnComm(_, kind, data, sender, channel)
  if kind ~= "QSTAT" or channel ~= "PARTY" or type(data) ~= "table" then return end
  local m = self:Member(M.Short(sender))
  m.done, m.outrider = {}, true
  m.prog = type(data.prog) == "table" and data.prog or nil
  for _, id in ipairs(type(data.done) == "table" and data.done or {}) do
    if type(id) == "number" then m.done[id] = true end
  end
  self:CheckEveryone()
end

-- Questie's party lines: "{rt1} Questie: <objective> for |Hquest:ID...|h[..]|h!"
-- and "{rt1} Questie: Quest Completed: [..]".
function M.ParseQuestie(msg)
  if type(msg) ~= "string" or not msg:find("Questie", 1, true) then return nil end
  local id = tonumber(msg:match("|Hquest:(%d+)"))
  if not id then return nil end
  local body = msg:gsub("^.-Questie%s?:%s*", "")
  if body:find("^Quest Completed") then return id, "done" end
  if body:find("^Quest Accepted") or body:find("^Quest Abandoned") or body:find("^Picked up") then return nil end
  local objective = body:match("^(.-) for |c") or body:match("^(.-) for |H")
  if objective then return id, "objective", objective end
  return nil
end

function M:OnPartyChat(_, msg, author)
  msg, author = readable(msg), readable(author)
  local id, what, objective = M.ParseQuestie(msg)
  if not id then return end
  local m = self:Member(M.Short(author))
  m.questie = true
  if what == "done" then
    m.done[id] = true
  else
    m.obj[id] = m.obj[id] or {}
    m.obj[id][M.Key(objective)] = true
  end
  self:CheckEveryone()
end

-- Has this member finished quest q (with our own objective list to compare)?
function M:MemberDone(m, questID, q)
  if m.done[questID] then return true end
  local got = m.obj[questID]
  if not got or not q or not q.list or #q.list == 0 then return false end
  for _, o in ipairs(q.list) do
    if not got[M.Key(o.text)] then return false end
  end
  return true
end

function M:CheckEveryone()
  if not self:Settings().everyone or not self:InParty() then return end
  local party = self:Party()
  if #party == 0 then return end
  for questID, q in pairs(self.prev or {}) do
    if q.complete and not self.said["all:" .. questID] then
      local sharing, all = 0, true
      for _, p in ipairs(party) do
        local on = readable(C.Call("C_QuestLog.IsUnitOnQuest", p.unit, questID))
        local m = self.members[p.name]
        local done = m and self:MemberDone(m, questID, q)
        if on or done then
          sharing = sharing + 1
          if not done then all = false end
        end
      end
      if sharing > 0 and all and self:Speaker() then
        self:Say("all:" .. questID, string.format("Outrider: Everyone is done with %s, go hand it in!", M.QuestLink(questID, q.title)))
        self:Info("everyone in the party is done with %s", tostring(q.title))
      end
    end
  end
end

-- Only one Outrider user in the party says "everyone is done": the first by name.
function M:Speaker()
  local me = M.Short(readable(C.Call("UnitName", "player")))
  for name, m in pairs(self.members) do
    if m.outrider and name < (me or "") then
      for _, p in ipairs(self:Party()) do if p.name == name then return false end end
    end
  end
  return true
end

function M:OnRoster()
  if not self:InParty() then self.members, self.said = {}, {} return end
  self:Share()
end

function M:OnEnable()
  if ns.Comm then ns.Comm.KNOWN_TYPES.QSTAT = true end
  self:On("QUEST_LOG_UPDATE", function(mod) ns.Throttle("partyquests:scan", 0.5, function() mod:Scan() end) end)
  self:On("QUEST_TURNED_IN", self.OnTurnedIn)
  self:On("OTR_COMM", self.OnComm)
  self:On("CHAT_MSG_PARTY", self.OnPartyChat)
  self:On("CHAT_MSG_PARTY_LEADER", self.OnPartyChat)
  self:On("GROUP_ROSTER_UPDATE", function(mod) ns.Throttle("partyquests:roster", 2, function() mod:OnRoster() end) end)
end

function M:Activity()
  local n = 0
  for _ in pairs(self.members or {}) do n = n + 1 end
  return string.format("party quests: %d party members' progress known", n)
end

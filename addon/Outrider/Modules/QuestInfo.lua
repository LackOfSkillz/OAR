-- Modules/QuestInfo.lua
-- What Questie knows about a quest beyond its objectives (Gary, 2026-11-17:
-- "add all of that"), from the quest pack (QuestieDB, GPLv3, unverified):
--   chains        "Part 2 of 4 · next: Dry Times" (nextQuestInChain)
--   breadcrumbs   "Leads to: X"; a warning when you take a quest whose
--                 breadcrumb you skipped (you'd lose its XP)
--   reputation    "+250 Darnassus" (faction names from the game)
--   categories    Darkmoon Faire, seasonal, profession, class, PvP...;
--                 repeatable and daily markers
--   filters       quest-giver pins hide event quests and profession quests
--                 for professions you don't have (both switchable)
--   sounds        a short sound when an objective is done and when a quest is
--                 ready to hand in (the game's own SOUNDKIT sounds)
--   chat links    quest links in chat show their level: [[15] Dry Times]
--   history       every quest you take, hand in or abandon, with the date,
--                 your level and the zone, per character
--   paths         escort and patrol NPCs of your quests walk a line on the map
-- Category names: Questie's lookupQuestCategories.lua (zoneOrSort < 0).

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("QuestInfo", {
  title = "Quest details (chains, reputation, history)",
  phase = "P4",
  order = 47,
  defaults = { sounds = true, links = true, warnBreadcrumb = true, showEvent = false, showOtherProf = false, showRepeatable = true, paths = true },
})
ns.QuestInfo = M

M.HISTORY_CAP = 600
M.SORTS = {
  [-1] = "Epic", [-21] = "Hallow's End", [-22] = "Seasonal", [-24] = "Herbalism", [-25] = "Battlegrounds",
  [-41] = "Day of the Dead", [-61] = "Warlock", [-81] = "Warrior", [-82] = "Shaman", [-101] = "Fishing",
  [-121] = "Blacksmithing", [-141] = "Paladin", [-161] = "Mage", [-162] = "Rogue", [-181] = "Alchemy",
  [-182] = "Leatherworking", [-201] = "Engineering", [-221] = "Treasure Map", [-261] = "Hunter", [-262] = "Priest",
  [-263] = "Druid", [-264] = "Tailoring", [-284] = "Special", [-304] = "Cooking", [-324] = "First Aid",
  [-344] = "Legendary", [-364] = "Darkmoon Faire", [-365] = "Ahn'Qiraj War", [-366] = "Lunar Festival",
  [-367] = "Reputation", [-368] = "Invasion", [-369] = "Midsummer", [-370] = "Brewfest", [-374] = "Noblegarden",
  [-376] = "Love is in the Air", [-378] = "Children's Week", [-666] = "Camping", [-676] = "Night Elf", [-1000] = "Special",
}
M.EVENTS = { [-21] = true, [-22] = true, [-41] = true, [-364] = true, [-366] = true, [-369] = true, [-370] = true,
  [-374] = true, [-376] = true, [-378] = true }
M.PROFS = { [-24] = "Herbalism", [-101] = "Fishing", [-121] = "Blacksmithing", [-181] = "Alchemy", [-182] = "Leatherworking",
  [-201] = "Engineering", [-264] = "Tailoring", [-304] = "Cooking", [-324] = "First Aid" }

local function readable(v) return C.Readable(v) end

function M:OnInitialize()
  local g = ns.db.global
  g.questHistory = type(g.questHistory) == "table" and g.questHistory or {}
  self.warned, self.turnedIn = {}, {}
end

function M:Pack() return ns.QuestObjectives and ns.QuestObjectives:Pack() end

function M:Get(questID)
  local p = self:Pack()
  return p and p.info and p.info[questID], p
end

function M:Name(questID)
  local p = self:Pack()
  local q = p and p.quests[questID]
  return q and q[1] or ("quest " .. tostring(questID))
end

-- ------------------------------------------------------------------ chains
function M:Prev()
  if self.prevMap then return self.prevMap end
  local map = {}
  local p = self:Pack()
  for id, e in pairs(p and p.info or {}) do if e.n then map[e.n] = id end end
  self.prevMap = map
  return map
end

-- part, length, next questID (nil when not in a chain)
function M:Chain(questID)
  local e = self:Get(questID)
  local prev = self:Prev()
  if not (e and e.n) and not prev[questID] then return nil end
  local first, guard = questID, 0
  while prev[first] and guard < 30 do first, guard = prev[first], guard + 1 end
  local part, len, cur, seen = 0, 0, first, {}
  while cur and not seen[cur] and len < 30 do
    seen[cur] = true
    len = len + 1
    if cur == questID then part = len end
    local ce = self:Get(cur)
    cur = ce and ce.n
  end
  if len < 2 then return nil end
  return part, len, e and e.n
end

function M:FactionName(id)
  local name = readable(C.Call("GetFactionInfoByID", id))
  if type(name) ~= "string" or name == "" then
    local data = readable(C.Call("C_Reputation.GetFactionDataByID", id))
    name = type(data) == "table" and readable(data.name) or nil
  end
  return name
end

function M:Category(questID)
  local e = self:Get(questID)
  return e and e.s and M.SORTS[e.s]
end

-- Short lines about a quest for tooltips, the tracker and pins.
function M:Lines(questID)
  local e = self:Get(questID)
  local out = {}
  if not e then return out end
  local part, len, nxt = self:Chain(questID)
  if part then
    out[#out + 1] = string.format("Part %d of %d%s", part, len, nxt and (" · next: " .. self:Name(nxt)) or " (last)")
  end
  if e.bf then out[#out + 1] = "Leads to: " .. self:Name(e.bf) end
  if e.rep then
    local r = {}
    -- a faction the game has no name for (a hidden one, e.g. 2779 on Zephras
    -- Isle) is left out: "+50 faction 2779" meant nothing (tour 2026-11-19)
    for i = 1, #e.rep - 1, 2 do
      local name = self:FactionName(e.rep[i])
      if name then r[#r + 1] = string.format("%+d %s", e.rep[i + 1], name) end
    end
    if #r > 0 then out[#out + 1] = "Reputation: " .. table.concat(r, ", ") end
  end
  local tags = {}
  local cat = self:Category(questID)
  if cat then tags[#tags + 1] = cat end
  if e.d then tags[#tags + 1] = "daily" end
  if e.r then tags[#tags + 1] = "repeatable" end
  if #tags > 0 then out[#out + 1] = table.concat(tags, ", ") end
  return out
end

-- ------------------------------------------------------------------ filters
function M:HasProf(name)
  local profs = ns.db.char.professions
  return type(profs) == "table" and profs[name] ~= nil
end

-- keep this quest giver's quest? (and a short tag for the pin)
function M:Keep(questID)
  local e = self:Get(questID)
  if not e then return true end
  local s = self:Settings()
  if e.s and M.EVENTS[e.s] and not s.showEvent then return false end
  if e.s and M.PROFS[e.s] and not s.showOtherProf and not self:HasProf(M.PROFS[e.s]) then return false end
  if e.r and not s.showRepeatable then return false end
  return true
end

function M:Tag(questID)
  local e = self:Get(questID)
  if not e then return nil end
  local cat = e.s and M.SORTS[e.s]
  if e.d then return cat and (cat .. ", daily") or "daily" end
  if e.r then return cat and (cat .. ", repeatable") or "repeatable" end
  return cat
end

function M:HookGivers()
  local P = ns.NPCPack
  if not P or P.questInfoHooked then return end
  P.questInfoHooked = true
  local quests, line = P.QuestsFor, P.QuestLine
  P.QuestsFor = function(pack, p)
    local out = quests(pack, p)
    if not M.enabled or not M:Pack() then return out end
    local kept = {}
    for _, q in ipairs(out) do
      if M:Keep(q.id) then q.tag = M:Tag(q.id) kept[#kept + 1] = q end
    end
    return kept
  end
  P.QuestLine = function(q)
    local s = line(q)
    if q.tag then s = s .. " |cff9d9d9d(" .. q.tag .. ")|r" end
    return s
  end
end

-- ------------------------------------------------------------------ breadcrumbs
function M:OnAccepted(_, a, b)
  local questID = tonumber(readable(b)) or tonumber(readable(a))
  if not questID or questID <= 0 then return end
  self:Record(questID, "took")
  local e = self:Get(questID)
  if not (e and e.bc and self:Settings().warnBreadcrumb) or self.warned[questID] then return end
  for _, b in ipairs(e.bc) do
    if readable(C.Call("C_QuestLog.IsQuestFlaggedCompleted", b)) or readable(C.Call("C_QuestLog.IsOnQuest", b)) then return end
  end
  self.warned[questID] = true
  ns.Print("you took %s without its breadcrumb quest %s (its XP is lost once you hand this one in)", self:Name(questID), self:Name(e.bc[1]))
end

-- ------------------------------------------------------------------ history
function M:History()
  local h = ns.db.global.questHistory
  local key = ns.db.key
  h[key] = type(h[key]) == "table" and h[key] or {}
  return h[key]
end

function M:Record(questID, what)
  local list = self:History()
  list[#list + 1] = { t = time(), id = questID, what = what, lvl = readable(C.Call("UnitLevel", "player")),
    zone = readable(C.Call("GetZoneText")), name = self:Name(questID) }
  while #list > M.HISTORY_CAP do table.remove(list, 1) end
end

function M:OnTurnedIn(_, questID)
  questID = tonumber(readable(questID))
  if not questID then return end
  self.turnedIn[questID] = time()
  self:Record(questID, "handed in")
end

function M:OnRemoved(_, questID)
  questID = tonumber(readable(questID))
  if not questID then return end
  if self.turnedIn[questID] and time() - self.turnedIn[questID] < 10 then return end
  self:Record(questID, "abandoned")
end

function M:HistoryLines(n)
  local list, out = self:History(), {}
  for i = #list, math.max(1, #list - (n or 15) + 1), -1 do
    local e = list[i]
    out[#out + 1] = string.format("%s  %s %s (level %s%s)", date("%b %d %H:%M", e.t), e.what, tostring(e.name),
      tostring(e.lvl or "?"), e.zone and (", " .. e.zone) or "")
  end
  return out
end

-- ------------------------------------------------------------------ sounds
local function sound(name)
  local kit = rawget(_G, "SOUNDKIT")
  local id = type(kit) == "table" and kit[name]
  if id then C.Call("PlaySound", id, "Master") return true end
  return false
end
M.Sound = sound

function M:OnObjective()
  if self:Settings().sounds then sound("IG_QUEST_LIST_SELECT") end
end

function M:OnReady()
  if self:Settings().sounds then sound("IG_QUEST_LIST_COMPLETE") end
end

-- ------------------------------------------------------------------ chat links
-- "|Hquest:123:15|h[Dry Times]|h" -> "|Hquest:123:15|h[[15] Dry Times]|h"
function M.LevelLinks(msg)
  if type(msg) ~= "string" or not msg:find("|Hquest:", 1, true) then return msg end
  return (msg:gsub("(|Hquest:%d+:(%-?%d+)[^|]*|h)%[([^%]]*)%]", function(head, lvl, title)
    lvl = tonumber(lvl)
    if not lvl or lvl <= 0 or title:find("^%[") then return head .. "[" .. title .. "]" end
    return head .. "[[" .. lvl .. "] " .. title .. "]"
  end))
end

M.CHAT_EVENTS = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
  "CHAT_MSG_RAID_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
  "CHAT_MSG_CHANNEL", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER" }

local function linkFilter(_, _, msg, ...)
  if not (M.enabled and M:Settings().links) then return false end
  if type(msg) ~= "string" or C.IsSecret and C.IsSecret(msg) then return false end
  local new = M.LevelLinks(msg)
  if new ~= msg then return false, new, ... end
  return false
end

-- ------------------------------------------------------------------ paths
function M:PathPins(mapID)
  if not self:Settings().paths then return {} end
  local p = self:Pack()
  if not (p and p.paths) then return {} end
  local npcs = {}
  for _, q in ipairs(ns.QuestObjectives.Log()) do
    local e = p.quests[q.questID]
    for _, o in ipairs(e and e[3] or {}) do if o[1] == "npc" then npcs[o[2]] = q.title end end
    for _, n in ipairs(e and e.fin or {}) do npcs[n] = q.title end
  end
  local out = {}
  for npcID, title in pairs(npcs) do
    local pts = p.paths[npcID] and p.paths[npcID][mapID]
    if pts then
      local who = p.npcs[npcID] and p.npcs[npcID][1] or ("NPC " .. npcID)
      for i = 1, #pts - 1, 2 do
        out[#out + 1] = { kind = "qpath", id = "qpath-" .. npcID .. "-" .. i, mapID = mapID, x = pts[i], y = pts[i + 1],
          name = who .. " walks here (" .. title .. ")", small = true }
      end
    end
  end
  return out
end

-- ------------------------------------------------------------------ module
function M:OnEnable()
  self:HookGivers()
  self:On("QUEST_ACCEPTED", self.OnAccepted)
  self:On("QUEST_TURNED_IN", self.OnTurnedIn)
  self:On("QUEST_REMOVED", self.OnRemoved)
  self:On("OTR_QUEST_OBJECTIVE", self.OnObjective)
  self:On("OTR_QUEST_READY", self.OnReady)
  if not self.chatHooked then
    local add = C.Resolve("ChatFrameUtil.AddMessageEventFilter") or rawget(_G, "ChatFrame_AddMessageEventFilter")
    if type(add) == "function" then
      self.chatHooked = true
      for _, e in ipairs(M.CHAT_EVENTS) do pcall(add, e, linkFilter) end
    end
  end
end

function M:Activity()
  return string.format("quest details: %d quests in this character's history", #self:History())
end

-- ------------------------------------------------------------------ journal
-- Gallery idea from Questie's Journey (2026-11-18): your quest history as a
-- dated list on the left and the picked entry in detail on the right, with a
-- stat strip on top. Read-only; history is recorded per character (above).
M.WHAT_COLOR = { took = "accent", ["handed in"] = "good", abandoned = "bad" }

function M:JournalStats(now)
  now = now or time()
  local list = self:History()
  local today, week, total, dropped = 0, 0, 0, 0
  for _, e in ipairs(list) do
    if e.what == "handed in" then
      total = total + 1
      if now - (e.t or 0) < 86400 then today = today + 1 end
      if now - (e.t or 0) < 7 * 86400 then week = week + 1 end
    elseif e.what == "abandoned" then dropped = dropped + 1 end
  end
  return { today = today, week = week, total = total, abandoned = dropped, entries = #list }
end

function M:JournalDetail(e)
  if not e then return "Pick an entry on the left." end
  local lines = {
    string.format("|cfff1d58e%s|r", tostring(e.name or ("Quest " .. tostring(e.id)))),
    string.format("%s %s", ns.TitleCase(tostring(e.what or "")), date("%A %b %d, %H:%M", e.t or 0)),
    string.format("Level %s%s", tostring(e.lvl or "?"), e.zone and (" in " .. e.zone) or ""),
  }
  local ok, more = pcall(self.Lines, self, e.id)
  if ok and type(more) == "table" and #more > 0 then
    lines[#lines + 1] = ""
    for _, l in ipairs(more) do lines[#lines + 1] = "|cff8fb4ff" .. l .. "|r" end
  end
  return table.concat(lines, "\n")
end

ns.Hub:AddTab("journal", "Journal", function(p)
  local UI, Theme = ns.UI, ns.Theme
  p.stats = UI:StatStrip(p)
  p.stats:SetPoint("TOPLEFT", 0, 0)
  p.stats:SetPoint("RIGHT", p, "RIGHT", -4, 0)
  -- filters (Gary, 2026-11-20: clear at a glance)
  p.filter = "all"
  p.chips = {}
  local FILTERS = { { "all", "All" }, { "handed in", "Finished" }, { "took", "Took" }, { "abandoned", "Gave up" } }
  local x = 0
  for _, fl in ipairs(FILTERS) do
    local c = UI:Chip(p, fl[2], function() p.filter = fl[1] p.picked = nil p:Refresh() end)
    c:SetPoint("TOPLEFT", p.stats, "BOTTOMLEFT", x, -12)
    x = x + (c:GetWidth() or 70) + 6
    c.key = fl[1]
    p.chips[#p.chips + 1] = c
  end
  p.list = UI:ScrollList(p, {
    rows = 20, rowHeight = 22,
    render = function(row, e)
      local col = Theme:Hex(M.WHAT_COLOR[e.what] or "body")
      row.text:SetText(string.format("|cff8f96a6%s|r  %s%s|r  %s", date("%b %d %H:%M", e.t or 0),
        col, ns.TitleCase(tostring(e.what or "")), tostring(e.name or "?")))
    end,
    onClick = function(e) p.picked = e p:ShowEntry(e) end,
  })
  p.list:SetPoint("TOPLEFT", p.chips[1], "BOTTOMLEFT", 0, -8)
  p.list:SetWidth(460)
  p.card = UI:Card(p, true)
  p.card:SetPoint("TOPLEFT", p.list, "TOPRIGHT", 12, 0)
  p.card:SetPoint("RIGHT", p, "RIGHT", -4, 0)
  p.card:SetHeight(20 * 22 + 4)
  p.pic = p.card:CreateTexture(nil, "ARTWORK")
  p.pic:SetSize(64, 64)
  p.pic:SetPoint("TOPLEFT", 18, -16)
  p.title = UI.Display(p.card, "side", "goldText")
  p.title:SetPoint("TOPLEFT", p.pic, "TOPRIGHT", 14, -6)
  p.title:SetPoint("RIGHT", p.card, "RIGHT", -18, 0)
  p.title:SetJustifyH("LEFT")
  p.what = UI.Text(p.card, "normal", "text")
  p.what:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 0, -6)
  p.detail = UI.Text(p.card, "normal", "body")
  p.detail:SetPoint("TOPLEFT", p.pic, "BOTTOMLEFT", 0, -14)
  p.detail:SetPoint("RIGHT", p.card, "RIGHT", -18, 0)
  p.detail:SetJustifyH("LEFT")
  if p.detail.SetSpacing then p.detail:SetSpacing(3) end
  p.again = UI:Button(p.card, "Take it again", 150, function() if p.giver and ns.Journey then ns.Journey:Go(p.giver) end end)
  p.again:SetHeight(30)
  p.again:SetPoint("BOTTOMLEFT", 18, 16)
  UI.SetPrimary(p.again, true)
  UI.Tip(p.again, "Take it again", "Points the gold arrow at the quest giver, so you can pick it up again.")
  p.again:Hide()
  if not (ns.Art and ns.Art:Set(p.pic, "kind_quest", "Interface\\Icons\\INV_Misc_Note_01")) then p.pic:SetTexture("Interface\\Icons\\INV_Misc_Note_01") end

  -- One entry, explained: what happened, when, where; a way back to a quest you gave up.
  function p:ShowEntry(e)
    self.giver = nil
    self.again:Hide()
    if not e then
      self.title:SetText("Your quest diary")
      self.what:SetText("")
      self.detail:SetText("Quests you take, finish or give up show on the left as you play, newest first. Click one to see when and where.")
      return
    end
    self.title:SetText(tostring(e.name or ("Quest " .. tostring(e.id))))
    local col = Theme:Hex(M.WHAT_COLOR[e.what] or "body")
    local word = e.what == "handed in" and "Finished" or e.what == "abandoned" and "Gave up" or ns.TitleCase(tostring(e.what or ""))
    self.what:SetText(col .. word .. "|r  |cff8f96a6" .. date("%A %b %d, %H:%M", e.t or 0) .. "|r")
    local lines = { string.format("You were level %s%s.", tostring(e.lvl or "?"), e.zone and (", in " .. e.zone) or "") }
    local ok, more = pcall(self.Lines or M.Lines, M, e.id)
    if ok and type(more) == "table" and #more > 0 then
      lines[#lines + 1] = ""
      for _, l in ipairs(more) do lines[#lines + 1] = "|cff8fb4ff" .. l .. "|r" end
    end
    -- gave it up: where to pick it up again, when Outrider knows the giver
    if e.what == "abandoned" and ns.Finder then
      local list = ns.Finder:Find({ kind = "quest", text = tostring(e.name or "") })
      for _, q in ipairs(list) do
        if q.name == e.name and q.target then self.giver = q break end
      end
      if self.giver then
        lines[#lines + 1] = ""
        lines[#lines + 1] = string.format("You can take it again from %s (%s away).", tostring(self.giver.sub or "its giver"):gsub("^from ", ""),
          ns.Travel.Minutes(self.giver.seconds))
        self.again:Show()
      end
    end
    self.detail:SetText(table.concat(lines, "\n"))
  end
  function p:Refresh()
    local st = M:JournalStats()
    self.stats:SetItems({
      { cap = "Handed in today", value = tostring(st.today), color = st.today > 0 and "good" or nil },
      { cap = "This week", value = tostring(st.week) },
      { cap = "All time", value = tostring(st.total), color = "gold", note = st.entries .. " entries" },
      { cap = "Abandoned", value = tostring(st.abandoned), color = st.abandoned > 0 and "bad" or nil },
    })
    local list, out = M:History(), {}
    for i = #list, 1, -1 do
      local e = list[i]
      if self.filter == "all" or e.what == self.filter then out[#out + 1] = e end
    end
    for _, c in ipairs(self.chips) do c:SetOn(c.key == self.filter) end
    self.list:SetItems(out)
    if not self.picked then self.picked = out[1] end
    self:ShowEntry(self.picked)
  end
end)

-- Modules/Chat.lua  (P7-08 chat, first part of P8-07 triage)
-- Uses only Blizzard's chat message filters (ChatFrame_AddMessageEventFilter
-- or ChatFrameUtil.AddMessageEventFilter); no chat frame is replaced.
--   * Keyword highlight: Gary's character name, watched rares, shopping list
--     items, plus his own words (/ride chat word add|remove <text>).
--     Matching lines get the keyword colored; one feed entry per keyword
--     per 5 minutes so nothing is missed (never a toast).
--   * Spam mute: the same text from the same sender within 60 s is hidden
--     (channels, say, yell only).
--   * URLs become a link; clicking it opens a copy box (never a browser).
--   * /ride copychat: the last 100 lines of the main chat window to copy.
--   * Timestamps: /ride chat time on|off sets Blizzard's own showTimestamps.
-- Secret message text (Midnight restricted chat) is left untouched.
-- P8-07 triage (option "own chat tab" chosen 2026-11-11): once, out of combat,
-- a chat tab named LFG is opened (or reused); Trade/LookingForGroup channel
-- lines and LFG/LFM lines from any channel show only there. Lines asking
-- for this character's role ("LF dps", "LF hunter") are marked [for you]
-- and go to the Feed. /ride chat lfgtab on|off switches the routing.
-- The game runs filters once per chat window, so each line is decided once
-- (by its line ID) and the decision reused for every window.
-- Not done here: short channel names (would need to replace AddMessage).

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Chat", {
  title = "Chat highlights and spam filter",
  phase = "P7",
  order = 96,
  defaults = { words = {}, spam = true, highlight = true, urls = true, lfgTab = true, whisperHistory = true, chatArchive = true, colorNames = true },
})
ns.Chat = M

M.EVENTS = { "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_PARTY",
  "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_WHISPER", "CHAT_MSG_OFFICER" }
M.SPAM_WINDOW = 60
local SPAM_EVENTS = { CHAT_MSG_CHANNEL = true, CHAT_MSG_SAY = true, CHAT_MSG_YELL = true }
local URL = "(https?://[%w%-%._~:/%?#@!%$&%*%+,;=%%]+)"

M.ARCHIVE_MAX, M.PER_PERSON_MAX = 600, 100
function M:OnInitialize()
  self.recent, self.fed, self.decided, self.decidedN, self.subscribed = {}, {}, {}, 0, {}
  local g = ns.db.global
  g.chatArchive = type(g.chatArchive) == "table" and g.chatArchive or {}
  g.whisperArchive = type(g.whisperArchive) == "table" and g.whisperArchive or {}
  self.archive, self.whispers = g.chatArchive, g.whisperArchive
end

-- A bounded and opt-in SavedVariables archive. The text is unmodified chat
-- content, never used to rewrite Blizzard-owned chat frames on login.
function M:RememberLine(event, msg, author)
  if not (type(msg) == "string" and not C.IsSecret(msg)) then return end
  if not (type(author) == "string" and not C.IsSecret(author)) then author = "?" end
  local s = self:Settings()
  local item = { t = time(), event = event, author = author, text = msg }
  if s.chatArchive then
    self.archive[#self.archive + 1] = item
    while #self.archive > M.ARCHIVE_MAX do ns.Archive:Shift("chat", self.archive) end
  end
  if s.whisperHistory and (event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_WHISPER_INFORM") then
    local who = author:lower()
    local by = self.whispers[who] or {}
    by[#by + 1] = item
    while #by > M.PER_PERSON_MAX do ns.Archive:Shift("chatByPerson", by) end
    self.whispers[who] = by
    local count = 0
    for _ in pairs(self.whispers) do count = count + 1 end
    if count > 30 then
      local oldest, when
      for name, records in pairs(self.whispers) do
        local t = records[#records] and records[#records].t or 0
        if not when or t < when then oldest, when = name, t end
      end
      if oldest then self.whispers[oldest] = nil end
    end
  end
end

function M:History(name, limit)
  local entries
  if name then entries = self.whispers[tostring(name):lower()] else entries = self.archive end
  local out = {}
  for i = #(entries or {}), 1, -1 do
    if #out >= (limit or 40) then break end
    out[#out + 1] = entries[i]
  end
  return out
end

-- Looking-for-group wording: lfg, lfm, lf, lf1m, lf2m...
function M.IsLFG(lower)
  return lower:find("%f[%w]lf[gm]?%f[%W]") or lower:find("%f[%w]lf%d+m%f[%W]") or lower:find("%f[%w]lfg$")
    or lower:find("%f[%w]lf[gm]?$") or false
end

local ROLE_WORDS = {
  WARRIOR = { "tank", "dps", "warrior", "warr" }, PALADIN = { "heal", "tank", "dps", "paladin", "pally" },
  HUNTER = { "dps", "hunter", "hunt", "ranged" }, ROGUE = { "dps", "rogue" }, PRIEST = { "heal", "priest" },
  SHAMAN = { "heal", "dps", "shaman", "shammy" }, MAGE = { "dps", "mage" }, WARLOCK = { "dps", "warlock", "lock" },
  DRUID = { "heal", "tank", "dps", "druid" },
}
M.ROLE_WORDS = ROLE_WORDS

function M.ForMe(lower)
  if not M.IsLFG(lower) then return false end
  for _, w in ipairs(ROLE_WORDS[ns.PlayerClass()] or {}) do
    if lower:find("%f[%w]" .. w) then return true end
  end
  return false
end

-- Does this channel line belong in the LFG tab?
function M.Routed(event, msg, base)
  if event ~= "CHAT_MSG_CHANNEL" or type(msg) ~= "string" then return false end
  local b = type(base) == "string" and base:lower() or ""
  if b:find("^trade") or b:find("lookingforgroup") or b:find("^lfg") then return true end
  return M.IsLFG(msg:lower()) and true or false
end

-- lowercase keyword -> label
function M:Keywords()
  local out = {}
  local name = C.Call("UnitName", "player")
  if name then out[name:lower()] = "your name" end
  local scan = ns.Modules:Get("RareScan")
  for k in pairs(scan and scan:Settings().watch or {}) do
    if type(k) == "string" and not k:match("^%d+$") and #k >= 4 then out[k:lower()] = "rare" end
  end
  if ns.CraftQueue then
    for _, r in ipairs(ns.CraftQueue:Shopping()) do
      local info = r.missing > 0 and C.ItemInfo(r.itemID)
      if info and info.name then out[info.name:lower()] = "shopping list" end
    end
  end
  for w in pairs(self:Settings().words) do out[w] = "keyword" end
  return out
end

-- Class colors only with an explicit, readable character GUID. Unknown
-- classes, NPCs and clickable player hyperlinks are unchanged.
-- Class colours on names (bug 2026-11-23: a General line showed
-- "|Hplayer:Mia Starleaf:407:CHANNEL:1[Mia Starleaf]" as raw text). The old
-- way handed Blizzard a coloured author, and Blizzard builds the clickable
-- player link from the author, so the colour codes broke the link. Now the
-- name is never touched: the game's own "colour names by class" chat option
-- is switched on for each chat type, once per session, while colorNames is on.
M.CLASS_COLOR_TYPES = { "SAY", "YELL", "EMOTE", "WHISPER", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER",
  "RAID_WARNING", "GUILD", "OFFICER", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER" }
function M:ApplyClassColors()
  if not self:Settings().colorNames then return 0 end
  local set = C.Resolve("SetChatColorNameByClass")
  if type(set) ~= "function" then return 0 end
  local n = 0
  local types = {}
  for _, t in ipairs(M.CLASS_COLOR_TYPES) do types[#types + 1] = t end
  for i = 1, 20 do types[#types + 1] = "CHANNEL" .. i end
  for _, t in ipairs(types) do
    if pcall(set, t, true) then n = n + 1 end
  end
  return n
end

-- Returns hide, newText (nil when unchanged), matched keyword
function M:Process(event, msg, author)
  if type(msg) ~= "string" or C.IsSecret(msg) or C.IsSecret(author) then return false end
  local s = self:Settings()
  local now = time()
  if s.spam and SPAM_EVENTS[event] and author then
    local key = tostring(author) .. "\0" .. msg
    local last = self.recent[key]
    self.recent[key] = now
    if last and now - last < self.SPAM_WINDOW then return true end
    self.pruned = self.pruned or now
    if now - self.pruned > 300 then
      for k, t in pairs(self.recent) do if now - t > self.SPAM_WINDOW then self.recent[k] = nil end end
      self.pruned = now
    end
  end
  local out, hit = msg, nil
  local lowerMsg = msg:lower()
  if s.highlight and M.ForMe(lowerMsg) then
    out = "|cff66d980[for you]|r " .. out
    hit = "lfg"
    if not self.fed["lfg:" .. tostring(author)] or now - self.fed["lfg:" .. tostring(author)] > 300 then
      self.fed["lfg:" .. tostring(author)] = now
      if ns.Feed then ns.Feed:Add(nil, { title = "Group wants you", text = tostring(author) .. ": " .. msg }) end
    end
  end
  if s.highlight and not hit and not msg:find("|H", 1, true) then
    local lower = msg:lower()
    for word, label in pairs(self:Keywords()) do
      local i = lower:find(word, 1, true)
      if i then
        hit = word
        out = out:sub(1, i - 1) .. "|cffffc84d" .. out:sub(i, i + #word - 1) .. "|r" .. out:sub(i + #word)
        if not self.fed[word] or now - self.fed[word] > 300 then
          self.fed[word] = now
          if ns.Feed then ns.Feed:Add(nil, { title = "Chat: " .. label, text = tostring(author) .. ": " .. msg }) end
        end
        break
      end
    end
  end
  if s.urls then
    out = out:gsub(URL, function(u) return "|cff8fd1ff|Haddon:Outrider:url:" .. u .. "|h[" .. u .. "]|h|r" end)
  end
  if out == msg then return false end
  return false, out, hit
end

local function filter(frame, event, ...)
  if not M.enabled then return false end
  local msg, author = ...
  local base, lineID = select(9, ...), select(11, ...)
  local d = lineID and M.decided[lineID]
  if not d then
    local ok, hide, text = pcall(M.Process, M, event, msg, author)
    if not ok then hide, text = false, nil end
    d = { hide = hide, text = text, route = M.Routed(event, msg, base) }
    if type(msg) == "string" and not C.IsSecret(msg) then M:RememberLine(event, msg, author) end
    if lineID then
      M.decided[lineID] = d
      M.decidedN = M.decidedN + 1
      if M.decidedN > 300 then M.decided, M.decidedN = {}, 0 end
    end
  end
  if d.hide then return true end
  local lfg = M.lfgFrame
  if lfg and event == "CHAT_MSG_CHANNEL" and M:Settings().lfgTab then
    if frame == lfg then
      if not d.route then return true end
    elseif d.route then
      return true
    end
  end
  -- A filter that changes a line must hand back EVERY argument: Blizzard
  -- replaces all of them with what we return. Returning only text and author
  -- left channelIndex and the rest nil, and Blizzard's chat code errored on
  -- every channel line (369 errors and the "large number of errors" pop-up,
  -- 2026-11-19).
  -- the author is handed back unchanged: Blizzard makes the player link from it
  if d.text then return false, d.text, author, select(3, ...) end
  return false
end

M.TestFilter = filter -- for the specs

-- Opens (or finds) the LFG chat tab once, out of combat.
function M:EnsureTab()
  if self.lfgFrame or not self:Settings().lfgTab or C.InCombat() then return self.lfgFrame end
  for i = 1, (rawget(_G, "NUM_CHAT_WINDOWS") or 10) do
    local ok, name = pcall(GetChatWindowInfo, i)
    if ok and name == "LFG" then self.lfgFrame = rawget(_G, "ChatFrame" .. i) break end
  end
  if not self.lfgFrame then
    local open = rawget(_G, "FCF_OpenNewWindow")
    if type(open) ~= "function" then self:Info("can't open a chat tab on this client: LFG lines stay in main chat") return end
    local ok, frame = pcall(open, "LFG", true) -- true: no default say/yell/guild groups, only routed channels
    if not ok or not frame then self:Info("LFG chat tab not created (%s)", tostring(frame)) return end
    self.lfgFrame = frame
    self:Info("LFG chat tab created")
  end
  return self.lfgFrame
end

-- Make sure the LFG tab receives a channel we route (it may not be joined there).
function M:OnChannel(_, _, _, _, _, _, _, _, _, base)
  local lfg = self.lfgFrame
  if not lfg or type(base) ~= "string" or self.subscribed[base] then return end
  self.subscribed[base] = true
  local add = rawget(_G, "ChatFrame_AddChannel")
  if type(add) == "function" then pcall(add, lfg, base) end
end

function M:OnEnable()
  if self.hooked then return end
  local add = C.Resolve("ChatFrameUtil.AddMessageEventFilter") or rawget(_G, "ChatFrame_AddMessageEventFilter")
  if type(add) ~= "function" then self:Warn("chat filters not available on this client") return end
  self.hooked = true
  for _, e in ipairs(self.EVENTS) do pcall(add, e, filter) end
  self:On("PLAYER_ENTERING_WORLD", function(mod) mod:EnsureTab() end)
  self:On("PLAYER_ENTERING_WORLD", function(mod)
    if not mod.colored then mod.colored = true mod:Debug("class colours on names for %d chat types", mod:ApplyClassColors()) end
  end)
  self:On("PLAYER_REGEN_ENABLED", function(mod) if not mod.lfgFrame then mod:EnsureTab() end end)
  self:On("CHAT_MSG_CHANNEL", self.OnChannel)
  if type(rawget(_G, "SetItemRef")) == "function" then
    hooksecurefunc("SetItemRef", function(link)
      local url = type(link) == "string" and link:match("^addon:Outrider:url:(.+)$")
      if url then ns.UI:TextDialog("Copy link", url, "copy") end
    end)
  end
end

local function plain(text)
  return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"))
end
M.Plain = plain

function M:CopyText(n)
  local f = rawget(_G, "ChatFrame1")
  if not (f and f.GetNumMessages and f.GetMessageInfo) then return nil end
  local total = f:GetNumMessages()
  local lines = {}
  for i = math.max(1, total - (n or 100) + 1), total do
    local ok, text = pcall(f.GetMessageInfo, f, i)
    if ok and type(text) == "string" and not C.IsSecret(text) then lines[#lines + 1] = plain(text) end
  end
  return table.concat(lines, "\n")
end

function M:Activity()
  local n = 0
  for _ in pairs(self:Keywords()) do n = n + 1 end
  return string.format("%d keywords highlighted; repeated spam %s", n, self:Settings().spam and "hidden" or "shown")
end

ns.AddCommand("history", "history [player] [count]  show stored chat or whisper messages", function(arg)
  local who, n = tostring(arg or ""):match("^(%S*)%s*(%d*)$")
  local max = math.min(100, math.max(1, tonumber(n) or 40))
  if who == "" or who == "all" then who = nil end
  local lines = {}
  for _, entry in ipairs(M:History(who, max)) do
    lines[#lines + 1] = string.format("%s [%s] %s: %s",
      date("%m-%d %H:%M", entry.t), tostring(entry.event), tostring(entry.author), tostring(entry.text))
  end
  ns.UI:TextDialog(who and ("Whispers: " .. who) or "Chat history", table.concat(lines, "\n"), "copy")
end)

ns.AddCommand("copychat", "copy the last 100 lines of the main chat window", function()
  local text = M:CopyText(100)
  if not text then ns.Print("can't read the chat window on this client") return end
  ns.UI:TextDialog("Chat", text, "copy")
end)

ns.AddCommand("chat", "word add|remove <text> | spam on|off | lfgtab on|off | time on|off  chat options", function(arg)
  local s = M:Settings()
  local cmd, rest = (arg or ""):match("^(%S+)%s*(.*)$")
  if cmd == "word" then
    local op, w = rest:match("^(%S+)%s+(.+)$")
    if op == "add" and w then s.words[w:lower()] = true ns.Print("highlighting '%s'", w)
    elseif op == "remove" and w then s.words[w:lower()] = nil ns.Print("no longer highlighting '%s'", w)
    else ns.Print("usage: /ride chat word add|remove <text>") end
  elseif cmd == "spam" and (rest == "on" or rest == "off") then
    s.spam = rest == "on"
    ns.Print("repeated spam %s", s.spam and "hidden" or "shown")
  elseif cmd == "lfgtab" and (rest == "on" or rest == "off") then
    s.lfgTab = rest == "on"
    if s.lfgTab then M:EnsureTab() end
    ns.Print("LFG and Trade lines %s", s.lfgTab and "go to the LFG tab" or "stay in your main chat")
  elseif cmd == "time" and (rest == "on" or rest == "off") then
    C.Call("C_CVar.SetCVar", "showTimestamps", rest == "on" and "%H:%M " or "none")
    ns.Print("timestamps %s", rest)
  else
    ns.Print(M:Activity())
  end
end)

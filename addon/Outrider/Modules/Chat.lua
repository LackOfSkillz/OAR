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
-- Not done here: short channel names (would need to replace AddMessage)
-- and a separate LFG/Trade tab (changes Gary's chat layout; ask first).

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Chat", {
  title = "Chat highlights and spam filter",
  phase = "P7",
  order = 96,
  defaults = { words = {}, spam = true, highlight = true, urls = true },
})
ns.Chat = M

M.EVENTS = { "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_PARTY",
  "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_WHISPER", "CHAT_MSG_OFFICER" }
M.SPAM_WINDOW = 60
local SPAM_EVENTS = { CHAT_MSG_CHANNEL = true, CHAT_MSG_SAY = true, CHAT_MSG_YELL = true }
local URL = "(https?://[%w%-%._~:/%?#@!%$&%*%+,;=%%]+)"

function M:OnInitialize() self.recent, self.fed = {}, {} end

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
  if s.highlight and not msg:find("|H", 1, true) then
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

local function filter(_, event, msg, author, ...)
  if not M.enabled then return false end
  local ok, hide, text = pcall(M.Process, M, event, msg, author)
  if not ok then return false end
  if hide then return true end
  if text then return false, text, author, ... end
  return false
end

function M:OnEnable()
  if self.hooked then return end
  local add = C.Resolve("ChatFrameUtil.AddMessageEventFilter") or rawget(_G, "ChatFrame_AddMessageEventFilter")
  if type(add) ~= "function" then self:Warn("chat filters not available on this client") return end
  self.hooked = true
  for _, e in ipairs(self.EVENTS) do pcall(add, e, filter) end
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

ns.AddCommand("copychat", "copy the last 100 lines of the main chat window", function()
  local text = M:CopyText(100)
  if not text then ns.Print("can't read the chat window on this client") return end
  ns.UI:TextDialog("Chat", text, "copy")
end)

ns.AddCommand("chat", "word add|remove <text> | spam on|off | time on|off  chat options", function(arg)
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
  elseif cmd == "time" and (rest == "on" or rest == "off") then
    C.Call("C_CVar.SetCVar", "showTimestamps", rest == "on" and "%H:%M " or "none")
    ns.Print("timestamps %s", rest)
  else
    ns.Print(M:Activity())
  end
end)

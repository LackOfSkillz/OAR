-- Modules/SpellCheck.lua  (chat spell check, Gary's request 2026-11-11)
-- While Gary types in a chat box, finished words are checked against the
-- English word list addon Outrider_Data_Words (SCOWL size 60, US + GB,
-- loaded on demand the first time a chat box opens; D12). A small strip
-- above the chat box shows the first unknown word with up to 3 suggestions
-- and Add. Clicking a suggestion swaps the word in the box; nothing is ever
-- sent: Enter stays Gary's.
-- Not checked: slash commands (lines starting with "/"), links, words under
-- 3 letters, ALL-CAPS (LFG, WTS), words with digits, and the word still
-- being typed (it is checked once Gary pauses for a second). Capitalized
-- words are checked too (Gary reported "Hello Wolrd" was missed); names of
-- people in chat are known, and Add teaches any other name.
-- Known extras: Gary's own words (/ride spell add <word>, or Add), common
-- game chat slang, the names of people talking in chat, and any word seen
-- in other people's chat 3 times (learned per session).
-- Without the word list the module does nothing.

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local M = ns:NewModule("SpellCheck", {
  title = "Chat spell check",
  phase = "P7",
  order = 97,
  defaults = { words = {} },
})
ns.SpellCheck = M

M.ADDON = "Outrider_Data_Words"
M.SLANG = {}
for w in ([[lol lmao rofl omg brb afk lfg lfm wts wtb wtt pst dps aoe heals healer tank tanking nerf buff
  debuff mob mobs aggro respawn respawns noob gratz grats gz ty thx np pls plz ok okay ya yea yep nope
  idk imo btw irl gg wp inv invite pug pugs raid raids dungeon dungeons quest quests questing loot looted
  ninja ninjaed boe bop afaik ftw ffs hp mana leveling levelling lvl lvls alt alts guildie guildies
  gank ganked ganking oom kek pvp pve dkp mats ench enchant enchants enchanter cooldown cooldowns
  addon addons ui macro macros keybind keybinds hearth hearthstone respec spec specs]]):gmatch("%S+") do
  M.SLANG[w] = true
end
M.LEARN_AFTER = 3

function M:OnInitialize() self.seen, self.names = {}, {} end

function M:Load()
  if self.dict ~= nil then return self.dict end
  if not rawget(_G, "Outrider_DataWords") then C.LoadAddOn(self.ADDON) end
  local data = rawget(_G, "Outrider_DataWords")
  if type(data) == "table" and type(data.chunks) == "table" then
    self.dict = data.chunks
    self:Info("word list loaded: %s, %s words", tostring(data.source), tostring(data.count))
  else
    self.dict = false
    self:Info("no %s installed: spell check is off", self.ADDON)
  end
  return self.dict
end

local function norm(word)
  local w = word:lower():gsub("'s$", ""):gsub("^'+", ""):gsub("'+$", "")
  return w
end

function M:Known(word)
  local w = norm(word)
  if #w < 3 then return true end
  if M.SLANG[w] or self:Settings().words[w] or self.names[w] then return true end
  if (self.seen[w] or 0) >= self.LEARN_AFTER then return true end
  local dict = self.dict
  if not dict then return true end
  local chunk = dict[w:sub(1, 2)]
  if chunk and chunk:find("\n" .. w .. "\n", 1, true) then return true end
  -- hyphenated: every part must be known
  if w:find("-", 1, true) then
    for part in w:gmatch("[^%-]+") do if not self:Known(part) then return false end end
    return true
  end
  return false
end

-- { {word, s, e} } unknown words in text; the last word only when
-- includeLast (Gary paused typing) or it is followed by a space/punctuation.
function M:Check(text, includeLast)
  local out = {}
  if type(text) ~= "string" or text == "" or text:sub(1, 1) == "/" or C.IsSecret(text) then return out end
  if not self:Load() then return out end
  -- blank out links and color codes so positions stay the same
  local clean = text:gsub("|H.-|h.-|h", function(s) return string.rep(" ", #s) end)
  clean = clean:gsub("|c%x%x%x%x%x%x%x%x", function(s) return string.rep(" ", #s) end):gsub("|r", "  ")
  for s, word, e in clean:gmatch("()([%a][%a'%-]*)()") do
    local finished = includeLast or e <= #clean
    local skip = #word < 3 or word:match("%u%u") or not finished or clean:sub(e, e):match("%d")
    if not skip and not self:Known(word) then out[#out + 1] = { word = word, s = s, e = e - 1 } end
  end
  return out
end

local LETTERS = "abcdefghijklmnopqrstuvwxyz"

-- up to n known words one edit away, swaps and replacements first
function M:Suggest(word, n)
  n = n or 3
  local w = norm(word)
  local out, seen = {}, {}
  local function try(c)
    if #out < n and not seen[c] and #c >= 2 and c ~= w then
      seen[c] = true
      local chunk = self.dict and self.dict[c:sub(1, 2)]
      if chunk and chunk:find("\n" .. c .. "\n", 1, true) then out[#out + 1] = c end
    end
  end
  for i = 1, #w - 1 do try(w:sub(1, i - 1) .. w:sub(i + 1, i + 1) .. w:sub(i, i) .. w:sub(i + 2)) end
  for i = 1, #w do try(w:sub(1, i - 1) .. w:sub(i + 1)) end
  for i = 1, #w do
    for j = 1, 26 do try(w:sub(1, i - 1) .. LETTERS:sub(j, j) .. w:sub(i + 1)) end
  end
  for i = 1, #w + 1 do
    for j = 1, 26 do try(w:sub(1, i - 1) .. LETTERS:sub(j, j) .. w:sub(i)) end
  end
  -- keep the capital if the typed word had one
  if word:match("^%u") then
    for i, c in ipairs(out) do out[i] = c:sub(1, 1):upper() .. c:sub(2) end
  end
  return out
end

function M:Replace(edit, miss, with)
  local text = edit:GetText()
  if type(text) ~= "string" or text:sub(miss.s, miss.e) ~= miss.word then return false end
  local new = text:sub(1, miss.s - 1) .. with .. text:sub(miss.e + 1)
  edit:SetText(new)
  if edit.SetCursorPosition then edit:SetCursorPosition(miss.s - 1 + #with) end
  return true
end

function M:Strip()
  if self.strip then return self.strip end
  local f = CreateFrame("Frame", "Outrider_SpellStrip", UIParent, ns.Theme:BackdropTemplate())
  ns.Theme:ApplyPanel(f, "panel")
  f:SetSize(360, 24)
  f:SetFrameStrata("DIALOG")
  f.label = UI.Text(f, "small", "warn")
  f.label:SetPoint("LEFT", 6, 0)
  f.buttons = {}
  for i = 1, 4 do
    local b = UI:Button(f, "", 70)
    b:SetHeight(18)
    if i == 1 then b:SetPoint("LEFT", f.label, "RIGHT", 8, 0) else b:SetPoint("LEFT", f.buttons[i - 1], "RIGHT", 4, 0) end
    f.buttons[i] = b
  end
  f:Hide()
  self.strip = f
  return f
end

function M:Update(edit, includeLast)
  local misses = self:Check(edit:GetText(), includeLast)
  local f = self:Strip()
  local miss = misses[1]
  if not miss then f:Hide() return misses end
  f:ClearAllPoints()
  f:SetPoint("BOTTOMLEFT", edit, "TOPLEFT", 0, 2)
  f.label:SetText(miss.word .. (#misses > 1 and string.format(" (+%d)", #misses - 1) or "") .. "?")
  local sugg = self:Suggest(miss.word)
  for i = 1, 3 do
    local b, s = f.buttons[i], sugg[i]
    b:SetShown(s ~= nil)
    if s then
      b:SetText(s)
      b:SetScript("OnClick", function() M:Replace(edit, miss, s) end)
    end
  end
  local add = f.buttons[4]
  add:SetText("Add")
  add:Show()
  add:SetScript("OnClick", function()
    M:Settings().words[norm(miss.word)] = true
    M:Info("spell check: added '%s'", norm(miss.word))
    M:Update(edit, true)
  end)
  f:Show()
  return misses
end

-- Learn from what other people write: their names, and words seen often.
function M:Learn(_, msg, author)
  if type(msg) ~= "string" or C.IsSecret(msg) then return end
  if type(author) == "string" and not C.IsSecret(author) then
    local n = author:match("^[^-]+")
    if n then self.names[n:lower()] = true end
  end
  for word in msg:gsub("|H.-|h.-|h", " "):gmatch("[%a][%a']+") do
    local w = norm(word)
    if #w >= 3 then self.seen[w] = (self.seen[w] or 0) + 1 end
  end
end

function M:OnEnable()
  for _, e in ipairs({ "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_GUILD", "CHAT_MSG_PARTY", "CHAT_MSG_WHISPER" }) do
    self:On(e, self.Learn)
  end
  if self.hooked then return end
  self.hooked = true
  for i = 1, (rawget(_G, "NUM_CHAT_WINDOWS") or 10) do
    local edit = rawget(_G, "ChatFrame" .. i .. "EditBox")
    if edit and edit.HookScript then
      edit:HookScript("OnTextChanged", function(box, user)
        if not M.enabled or user == false then return end
        ns.Throttle("spellcheck", 0.3, function() ns.Safe("SpellCheck:update", M.Update, M, box) end)
        -- after a 1 s pause, check the last word too
        if M.pause then M.pause:Cancel() end
        M.pause = ns.Timer.After(1, function() M.pause = nil ns.Safe("SpellCheck:pause", M.Update, M, box, true) end, "spellcheck:pause")
      end)
      edit:HookScript("OnEditFocusLost", function()
        if M.pause then M.pause:Cancel() M.pause = nil end
        if M.strip then M.strip:Hide() end
      end)
      edit:HookScript("OnHide", function() if M.strip then M.strip:Hide() end end)
    end
  end
end

function M:OnDisable() if self.strip then self.strip:Hide() end end

function M:Activity()
  if self.dict == false then return "off: word list addon " .. self.ADDON .. " not installed" end
  local n = 0
  for _ in pairs(self:Settings().words) do n = n + 1 end
  return string.format("checks chat as you type; %d words of your own", n)
end

ns.AddCommand("spell", "add|remove <word>  your own spell check words", function(arg)
  local op, w = (arg or ""):match("^(%S+)%s+(%S+)$")
  local words = M:Settings().words
  if op == "add" then words[norm(w)] = true ns.Print("'%s' is now a known word", w)
  elseif op == "remove" then words[norm(w)] = nil ns.Print("removed '%s'", w)
  else ns.Print("usage: /ride spell add|remove <word>  (%s)", M:Activity()) end
end)

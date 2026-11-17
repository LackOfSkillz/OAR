-- Modules/Census.lua
-- Who's playing on this realm (Gary, 2026-11-17): the most common level,
-- class, race and profession, and the highest level seen so far.
-- Sources, all official and read-only:
--   * /who results (WHO_LIST_UPDATE): level, class, race, guild, zone. The
--     server returns at most 50 players a search, so a full count splits by
--     level and class. Each search is one press of Gary's (a button or
--     /ride census who); nothing is sent on a timer (hard rule 1).
--   * players around you: mouseover, target, nameplates, party/raid, guild
--     roster (level, class, race, guild, faction).
--   * professions: the game shows nobody's professions, so the only source is
--     profession links people post in chat (|Htrade: links).
-- Stored only on this PC in ns.db.global.census[realm], one line per player,
-- kept 30 days; nothing is shared. Secret values are skipped.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Census", {
  title = "Census: who's playing",
  phase = "P8",
  order = 60,
  defaults = { passive = true, chat = true },
  yieldsTo = { "CensusPlus" },
})
ns.Census = M

M.KEEP_DAYS = 30
M.CAP = 50 -- most players one /who search returns
M.WAIT = 5 -- seconds before another search goes out
M.PROF = { -- names as profession links show them
  Alchemy = true, Blacksmithing = true, Enchanting = true, Engineering = true, Herbalism = true,
  Leatherworking = true, Mining = true, Skinning = true, Tailoring = true, Cooking = true,
  ["First Aid"] = true, Fishing = true, Jewelcrafting = true, Inscription = true,
}

local function readable(v) return v ~= nil and C.Readable(v) and v or nil end

function M:OnInitialize()
  local g = ns.db.global
  g.census = type(g.census) == "table" and g.census or {}
  self.store = g.census
end

function M.RealmKey()
  return tostring(C.Call("GetRealmName") or "?")
end

function M:Realm()
  local k = M.RealmKey()
  local r = self.store[k]
  if type(r) ~= "table" then r = { players = {}, profs = {} } self.store[k] = r end
  r.players = r.players or {}
  r.profs = r.profs or {}
  return r
end

-- "Name" -> "Name-Realm" so a player counts once wherever we saw them.
function M.FullName(name, realm)
  if type(name) ~= "string" or name == "" then return nil end
  if name:find("-", 1, true) then return name end
  realm = (type(realm) == "string" and realm ~= "") and realm or M.RealmKey()
  return name .. "-" .. realm:gsub("%s", "")
end

function M:IsMe(full)
  local me = M.FullName(C.Call("UnitName", "player"))
  return full == me
end

-- Record one player. rec = { l, c (class file), r (race), g (guild), z (zone), f (faction) }
function M:Add(full, rec, src)
  if not full or self:IsMe(full) then return end
  local lvl = tonumber(rec.l)
  if not lvl or lvl <= 0 then return end
  local p = self:Realm().players
  local old = p[full] or {}
  p[full] = {
    l = math.max(lvl, tonumber(old.l) or 0), -- levels only go up
    c = rec.c or old.c, r = rec.r or old.r, g = rec.g or old.g, z = rec.z or old.z,
    f = rec.f or old.f, t = time(), s = src or old.s,
  }
  self.added = (self.added or 0) + 1
end

-- ------------------------------------------------------------------ units
function M:FromUnit(unit, src)
  if not self:Settings().passive then return end
  if not readable(C.Call("UnitExists", unit)) or not readable(C.Call("UnitIsPlayer", unit)) then return end
  local name, realm = C.Call("UnitName", unit)
  name, realm = readable(name), readable(realm)
  if not name then return end
  local _, classFile = C.Call("UnitClass", unit)
  local race = C.Call("UnitRace", unit)
  self:Add(M.FullName(name, realm), {
    l = readable(C.Call("UnitLevel", unit)), c = readable(classFile), r = readable(race),
    g = readable(C.Call("GetGuildInfo", unit)), z = readable(C.Call("GetZoneText")),
    f = readable(C.Call("UnitFactionGroup", unit)),
  }, src)
end

function M:FromGroup()
  local raid = readable(C.Call("IsInRaid"))
  local n = raid and 40 or 4
  for i = 1, n do self:FromUnit((raid and "raid" or "party") .. i, "group") end
end

function M:FromGuild()
  if not self:Settings().passive then return end
  local n = readable(C.Call("GetNumGuildMembers")) or 0
  local guild = readable(C.Call("GetGuildInfo", "player"))
  local faction = readable(C.Call("UnitFactionGroup", "player"))
  local info = C.Resolve("GetGuildRosterInfo")
  if type(info) ~= "function" then return end
  for i = 1, math.min(n, 1000) do
    local ok, name, _, _, level, _, zone, _, _, _, _, classFile = pcall(info, i)
    if ok and readable(name) then
      self:Add(M.FullName(name), { l = readable(level), c = readable(classFile), g = guild, z = readable(zone), f = faction }, "guild")
    end
  end
end

-- ------------------------------------------------------------------ chat
-- Profession links: |Htrade:<owner GUID>:...|h[Alchemy]|h
function M.ParseTrade(msg)
  local out = {}
  if type(msg) ~= "string" then return out end
  for guid, text in msg:gmatch("|Htrade:([^:|]+):[^|]*|h%[([^%]]+)%]|h") do
    local prof = text:match("'s%s+(.+)$") or text
    if M.PROF[prof] then out[#out + 1] = { guid = guid, prof = prof } end
  end
  return out
end

function M:OnChat(_, msg, author, ...)
  if not self:Settings().chat then return end
  msg, author = readable(msg), readable(author)
  if not msg or not msg:find("|Htrade:", 1, true) then return end
  local senderGUID = readable((select(10, ...)))
  local profs = self:Realm().profs
  for _, link in ipairs(M.ParseTrade(msg)) do
    local who
    if link.guid == senderGUID and author then
      who = M.FullName(author)
    else
      local _, _, _, _, _, name, realm = C.Call("GetPlayerInfoByGUID", link.guid)
      who = readable(name) and M.FullName(name, readable(realm))
    end
    if who and not self:IsMe(who) then
      profs[who] = profs[who] or {}
      profs[who][link.prof] = time()
    end
  end
end

-- ------------------------------------------------------------------ /who
local function bandFilter(b)
  local f = b.lo == b.hi and tostring(b.lo) or (b.lo .. "-" .. b.hi)
  if b.class then f = f .. ' c-"' .. b.class .. '"' end
  return f
end
M.Filter = bandFilter

function M.MaxLevel()
  local m = readable(C.Call("GetMaxPlayerLevel"))
  return (type(m) == "number" and m > 1) and m or 60
end

function M:Classes()
  local out = {}
  for id = 1, 13 do
    local name = readable((C.Call("GetClassInfo", id)))
    if name then out[#out + 1] = name end
  end
  return out
end

-- A new count: one search per 10 levels; full ones split later.
function M:NewSweep()
  local q, top = {}, M.MaxLevel()
  for lo = 1, top, 10 do q[#q + 1] = { lo = lo, hi = math.min(top, lo + 9) } end
  self.sweep = { queue = q, done = 0, capped = 0, found = 0, started = time() }
  return self.sweep
end

function M:Left()
  return self.sweep and #self.sweep.queue or 0
end

-- One press = one /who search. Returns what was sent, or nil and why.
function M:SearchNext()
  if not self.sweep or #self.sweep.queue == 0 then self:NewSweep() end
  if self.pending and (time() - self.pending.t) < M.WAIT then return nil, "waiting for the last search" end
  local b = table.remove(self.sweep.queue, 1)
  local send = C.Resolve("C_FriendList.SendWho")
  if type(send) ~= "function" then return nil, "this client has no /who for addons" end
  self.pending = { band = b, t = time() }
  local ok, err = pcall(send, bandFilter(b))
  if not ok then
    table.insert(self.sweep.queue, 1, b)
    self.pending = nil
    self:Warn("who search failed: %s", tostring(err))
    return nil, "the game refused the search"
  end
  self:Debug("who search sent: %s (%d left)", bandFilter(b), #self.sweep.queue)
  return bandFilter(b)
end

function M:OnWho()
  local num, total = C.Call("C_FriendList.GetNumWhoResults")
  num, total = readable(num) or 0, readable(total) or 0
  local get = C.Resolve("C_FriendList.GetWhoInfo")
  local faction = readable(C.Call("UnitFactionGroup", "player"))
  local counted = 0
  if type(get) == "function" then
    for i = 1, num do
      local ok, w = pcall(get, i)
      if ok and type(w) == "table" and readable(w.fullName) then
        self:Add(M.FullName(w.fullName), { l = readable(w.level), c = readable(w.filename), r = readable(w.raceStr),
          g = readable(w.fullGuildName) ~= "" and readable(w.fullGuildName) or nil, z = readable(w.area), f = faction }, "who")
        counted = counted + 1
      end
    end
  end
  local p = self.pending
  self.pending = nil
  if not (p and self.sweep) then return end
  local s, b = self.sweep, p.band
  s.done, s.found = s.done + 1, s.found + counted
  if num >= M.CAP or total > num then
    -- full: split it so the next presses see everyone
    if b.lo < b.hi then
      local mid = math.floor((b.lo + b.hi) / 2)
      table.insert(s.queue, 1, { lo = mid + 1, hi = b.hi, class = b.class })
      table.insert(s.queue, 1, { lo = b.lo, hi = mid, class = b.class })
    elseif not b.class then
      for i, cls in ipairs(self:Classes()) do table.insert(s.queue, i, { lo = b.lo, hi = b.hi, class = cls }) end
    else
      s.capped = s.capped + 1 -- one level and one class still over 50: some go uncounted
    end
  end
  if #s.queue == 0 then
    local r = self:Realm()
    r.lastSweep = { t = time(), searches = s.done, found = s.found, capped = s.capped }
    self:Info("census count done: %d searches, %d players, %d full", s.done, s.found, s.capped)
    ns.Print("census done: %d players counted in %d searches", s.found, s.done)
  end
end

-- ------------------------------------------------------------------ stats
function M:Prune()
  local cut = time() - 86400 * M.KEEP_DAYS
  local r, n = self:Realm(), 0
  for k, p in pairs(r.players) do if (p.t or 0) < cut then r.players[k] = nil n = n + 1 end end
  for k, t in pairs(r.profs) do
    local any = false
    for prof, when in pairs(t) do if when < cut then t[prof] = nil else any = true end end
    if not any then r.profs[k] = nil end
  end
  return n
end

local function ranked(counts, total)
  local out = {}
  for k, n in pairs(counts) do out[#out + 1] = { key = k, n = n, pct = total > 0 and n / total or 0 } end
  table.sort(out, function(a, b) if a.n ~= b.n then return a.n > b.n end return tostring(a.key) < tostring(b.key) end)
  return out
end

-- faction: nil = everyone, else "Horde"/"Alliance"
function M:Stats(faction)
  local r = self:Realm()
  local lv, bands, cls, race, total, sum, fromWho = {}, {}, {}, {}, 0, 0, 0
  local top = {}
  for name, p in pairs(r.players) do
    if not faction or p.f == faction then
      total, sum = total + 1, sum + p.l
      lv[p.l] = (lv[p.l] or 0) + 1
      local b = p.l >= M.MaxLevel() and tostring(p.l) or (math.floor(p.l / 10) * 10 .. "-" .. math.floor(p.l / 10) * 10 + 9)
      if p.l < 10 then b = "1-9" end
      bands[b] = (bands[b] or 0) + 1
      if p.c then cls[p.c] = (cls[p.c] or 0) + 1 end
      if p.r then race[p.r] = (race[p.r] or 0) + 1 end
      if p.s == "who" then fromWho = fromWho + 1 end
      top[#top + 1] = { name = name, l = p.l, c = p.c, r = p.r, g = p.g, z = p.z, t = p.t }
    end
  end
  table.sort(top, function(a, b) if a.l ~= b.l then return a.l > b.l end return (a.t or 0) > (b.t or 0) end)
  local prof, withProf = {}, 0
  for name, t in pairs(r.profs) do
    local p = r.players[name]
    if not faction or not p or p.f == faction then
      withProf = withProf + 1
      for k in pairs(t) do prof[k] = (prof[k] or 0) + 1 end
    end
  end
  local bandList = ranked(bands, total)
  table.sort(bandList, function(a, b) return (tonumber(a.key:match("^%d+")) or 0) < (tonumber(b.key:match("^%d+")) or 0) end)
  return {
    total = total, fromWho = fromWho, avg = total > 0 and sum / total or 0,
    levels = ranked(lv, total), bands = bandList, classes = ranked(cls, total), races = ranked(race, total),
    profs = ranked(prof, withProf), withProf = withProf, top = top, lastSweep = r.lastSweep,
  }
end

function M.ClassName(file)
  local t = rawget(_G, "LOCALIZED_CLASS_NAMES_MALE")
  return (type(t) == "table" and t[file]) or (type(file) == "string" and (file:sub(1, 1) .. file:sub(2):lower())) or "?"
end

function M:Summary()
  local s = self:Stats()
  if s.total == 0 then return "no players counted yet" end
  local function first(list, fn) return list[1] and ((fn and fn(list[1].key) or list[1].key) .. " (" .. math.floor(list[1].pct * 100 + 0.5) .. "%)") or "?" end
  return string.format("%d players: most common level %s, class %s, race %s; highest %s at %d",
    s.total, first(s.levels), first(s.classes, M.ClassName), first(s.races), s.top[1] and s.top[1].name or "?", s.top[1] and s.top[1].l or 0)
end

-- ------------------------------------------------------------------ module
function M:OnEnable()
  self:On("UPDATE_MOUSEOVER_UNIT", function(mod) mod:FromUnit("mouseover", "seen") end)
  self:On("PLAYER_TARGET_CHANGED", function(mod) mod:FromUnit("target", "seen") end)
  self:On("NAME_PLATE_UNIT_ADDED", function(mod, _, unit) mod:FromUnit(unit, "seen") end)
  self:On("GROUP_ROSTER_UPDATE", self.FromGroup)
  self:On("GUILD_ROSTER_UPDATE", self.FromGuild)
  self:On("WHO_LIST_UPDATE", self.OnWho)
  for _, e in ipairs({ "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_WHISPER" }) do
    self:On(e, self.OnChat)
  end
  self:On("PLAYER_ENTERING_WORLD", function(mod, _, isLogin)
    if not isLogin then return end
    local n = mod:Prune()
    local s = mod:Stats()
    mod:Info("census at login: %d players on %s (%d from /who), %d with a profession; %d older than %d days dropped",
      s.total, M.RealmKey(), s.fromWho, s.withProf, n, M.KEEP_DAYS)
  end)
end

function M:Snapshot()
  -- counts only, never names
  local s = self:Stats()
  local function top(list, n)
    local out = {}
    for i = 1, math.min(n, #list) do out[i] = { list[i].key, list[i].n } end
    return out
  end
  return { players = s.total, avgLevel = math.floor(s.avg + 0.5), highest = s.top[1] and s.top[1].l or nil,
    levels = top(s.bands, 10), classes = top(s.classes, 12), races = top(s.races, 12), professions = top(s.profs, 14) }
end

function M:Activity()
  return string.format("%d players counted on %s", self:Stats().total, M.RealmKey())
end

-- ------------------------------------------------------------------ page
local function bars(list, label, color)
  local out = {}
  local max = list[1] and list[1].n or 1
  for i, x in ipairs(list) do
    if i > 12 then break end
    out[#out + 1] = { label = label and label(x.key) or tostring(x.key), value = x.n, fill = x.n / max,
      text = string.format("%d  (%d%%)", x.n, math.floor(x.pct * 100 + 0.5)), color = color and color(x.key) or nil }
  end
  return out
end

local function classColor(file)
  local cc = (rawget(_G, "RAID_CLASS_COLORS") or {})[file]
  return cc and { cc.r, cc.g, cc.b } or nil
end

local function ago(t)
  local d = time() - (t or 0)
  if d < 3600 then return math.max(1, math.floor(d / 60)) .. " min ago" end
  if d < 86400 then return math.floor(d / 3600) .. " h ago" end
  return math.floor(d / 86400) .. " days ago"
end

ns.Hub:AddTab("census", "Census", function(p)
  local UI = ns.UI
  local function st() return M:Stats() end
  UI:FormPage(p, {
    { "header", "Census" },
    { "header", "Who's playing", icon = "INV_Misc_GroupLooking" },
    { "note", function()
      local s = st()
      if s.total == 0 then return "Nobody counted yet. Press Search the next group below, or just play: players you mouse over, target or group with are counted." end
      return string.format("%d players on %s in the last %d days (%d from /who, the rest seen around you). Average level %.1f; most common level %s.",
        s.total, M.RealmKey(), M.KEEP_DAYS, s.fromWho, s.avg, s.levels[1] and s.levels[1].key or "?")
    end },
    { "header", "Count everyone with /who", icon = "INV_Misc_Spyglass_02" },
    { "note", function()
      local last = M:Realm().lastSweep
      local left = M:Left()
      local head = "Each press sends one /who search (Blizzard allows 50 players a search). Full searches split into smaller ones, so a whole count takes a few dozen presses. Only your faction shows in /who."
      if M.sweep and left > 0 then head = head .. string.format("\nThis count: %d searches done, %d players, %d to go.", M.sweep.done, M.sweep.found, left) end
      if last then head = head .. string.format("\nLast full count %s: %d players in %d searches.", ago(last.t), last.found, last.searches) end
      return head
    end },
    { "buttons", { { "Search the next group", function()
      local sent, why = M:SearchNext()
      if not sent then ns.Print("census: %s", tostring(why)) end
      p:Refresh()
    end, 190 }, { "Start a new count", function() M:NewSweep() p:Refresh() end, 150 } } },
    { "header", "Highest level seen", icon = "Achievement_General" },
    { "cards", function()
      local out = {}
      for i, x in ipairs(st().top) do
        if i > 3 then break end
        local tags = { { "Level " .. x.l, "gold" }, { M.ClassName(x.c), "plain" } }
        if x.r then tags[#tags + 1] = { x.r, "plain" } end
        out[#out + 1] = { art = x.c and ("class_" .. x.c:lower()) or nil, pic = "Interface\\Icons\\INV_Misc_QuestionMark",
          title = x.name:match("^[^-]+") or x.name, tags = tags, highlight = i == 1,
          line = (x.g and ("<" .. x.g .. ">  ") or "") .. (x.z or "") .. "  |cff888888seen " .. ago(x.t) .. "|r" }
      end
      return out
    end },
    { "header", "Levels", icon = "Spell_Holy_SurgeOfLight" },
    { "bars", function() return bars(st().bands) end },
    { "header", "Classes", icon = "INV_Sword_04" },
    { "bars", function() return bars(st().classes, M.ClassName, classColor) end },
    { "header", "Races", icon = "INV_Misc_Head_Human_01" },
    { "bars", function() return bars(st().races) end },
    { "header", "Professions", icon = "Trade_Alchemy" },
    { "note", function()
      local s = st()
      return string.format("The game shows nobody's professions, so these come only from profession links people post in chat (%d players so far).", s.withProf)
    end },
    { "bars", function() return bars(st().profs) end },
    { "header", "What's counted", icon = "INV_Misc_Note_01" },
    { "check", "Count players I see", function() return M:Settings().passive end, function(on) M:Settings().passive = on end },
    { "check", "Count professions from chat links", function() return M:Settings().chat end, function(on) M:Settings().chat = on end },
    { "note", "Kept on this PC only, 30 days, never shared." },
  })
end)

ns.AddCommand("census", "who's playing: most common level, class, race, profession (/ride census who searches the next group, reset clears)", function(arg)
  arg = tostring(arg or ""):lower()
  if arg == "who" then
    local sent, why = M:SearchNext()
    ns.Print(sent and ("census search: " .. sent .. " (" .. M:Left() .. " to go)") or ("census: " .. tostring(why)))
  elseif arg == "reset" then
    M.store[M.RealmKey()] = nil
    M.sweep = nil
    ns.Print("census cleared for %s", M.RealmKey())
  else
    ns.Print("census: %s", M:Summary())
  end
end)

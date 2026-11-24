-- Modules/Census.lua
-- Who's playing on this realm (requirement 2026-11-17): the most common level,
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
M.WAIT = 3 -- seconds to wait for an answer before a press sends the search again
M.PROF = { -- names as profession links show them
  Alchemy = true, Blacksmithing = true, Enchanting = true, Engineering = true, Herbalism = true,
  Leatherworking = true, Mining = true, Skinning = true, Tailoring = true, Cooking = true,
  ["First Aid"] = true, Fishing = true, Jewelcrafting = true, Inscription = true,
}

local function readable(v) return v ~= nil and C.Readable(v) and v or nil end

function M:OnInitialize()
  local g = ns.db.global
  g.census = ns.KeepTable(g.census, "Census:g.census") or {}
  self.store = g.census
end

function M.RealmKey()
  return tostring(C.Call("GetRealmName") or "?")
end

function M:Realm()
  local k = M.RealmKey()
  local r = self.store[k]
  if type(r) ~= "table" then ns.KeepBad(r, "Census:r") r = { players = {}, profs = {} } self.store[k] = r end
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
      local _, _, _, _, _, name, realm = C.CallAll("GetPlayerInfoByGUID", link.guid)
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

-- A new count (bug 2026-11-17: results were dominated by low-level
-- players). Top level first, in bands that get narrower as levels get
-- busier, so the first ~13 presses cover every level once. Bands that come
-- back full (50+) are split, but those refinements wait at the END of the
-- queue: the overview always finishes first, extra presses only add detail.
function M.Bands(top)
  top = top or M.MaxLevel()
  local q = { { lo = top, hi = top } }
  local hi = top - 1
  while hi >= 1 do
    local lo = math.max(1, hi - 4)
    if hi <= 9 then lo = hi >= 6 and 6 or 1 end
    q[#q + 1] = { lo = lo, hi = hi }
    hi = lo - 1
  end
  return q
end

function M:NewSweep()
  self.sweep = { queue = M.Bands(), done = 0, capped = 0, found = 0, started = time(), overview = #M.Bands() }
  self.pending = nil
  return self.sweep
end

function M:Left()
  return self.sweep and #self.sweep.queue or 0
end

-- Results always to the Who list (WHO_LIST_UPDATE); with it off, small
-- answers print in chat and never reach us (4 of Gary's 18 searches).
local function toList()
  local set = C.Resolve("C_FriendList.SetWhoToUi") or rawget(_G, "SetWhoToUI")
  if type(set) == "function" then pcall(set, true) end
end

-- One press = one /who search. Returns what was sent, or nil and why.
function M:SearchNext()
  if not self.sweep or #self.sweep.queue == 0 then self:NewSweep() end
  local s = self.sweep
  if self.pending then
    if (time() - self.pending.t) < M.WAIT then return nil, "the server is still answering, press again in a moment" end
    -- no answer came (the server ignores searches sent too fast): ask again
    self.lost = (self.lost or 0) + 1
    table.insert(s.queue, 1, self.pending.band)
    self:Debug("no answer for %s, sending it again", bandFilter(self.pending.band))
    self.pending = nil
  end
  local b = table.remove(s.queue, 1)
  local send = C.Resolve("C_FriendList.SendWho")
  if type(send) ~= "function" then table.insert(s.queue, 1, b) return nil, "this client has no /who for addons" end
  toList()
  self.pending = { band = b, t = time() }
  local ok, err = pcall(send, bandFilter(b))
  if not ok then
    table.insert(s.queue, 1, b)
    self.pending = nil
    self:Warn("who search failed: %s", tostring(err))
    return nil, "the game refused the search"
  end
  self:Debug("who search sent: %s (%d left)", bandFilter(b), #s.queue)
  return bandFilter(b)
end

-- What each band answered: r.bands[filter] = { n, total, full, t } (the
-- level chart says "50+" for full ones).
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
  if p and p.filter then
    self.status = nil
    self.lastSearch = { filter = p.filter, n = num, total = total, t = time() }
    self:Debug("who answer: %s -> %d shown, %d total", p.filter, num, total)
    if ns.Hub and ns.Hub.current == "people" then ns.Safe("census:refresh", ns.Hub.Refresh, ns.Hub) end
    return
  end
  if not (p and p.band and self.sweep) then return end
  local s, b = self.sweep, p.band
  local full = num >= M.CAP or total > num
  s.done, s.found = s.done + 1, s.found + counted
  local r = self:Realm()
  r.bands = r.bands or {}
  r.bands[bandFilter(b)] = { lo = b.lo, hi = b.hi, class = b.class, n = num, total = total, full = full, t = time() }
  self:Debug("who answer: %s -> %d shown, %d total%s (%.1fs)", bandFilter(b), num, total, full and ", full" or "", time() - p.t)
  if full then
    -- split it, after everything not yet looked at
    if b.lo < b.hi then
      local mid = math.floor((b.lo + b.hi) / 2)
      s.queue[#s.queue + 1] = { lo = mid + 1, hi = b.hi, class = b.class, detail = true }
      s.queue[#s.queue + 1] = { lo = b.lo, hi = mid, class = b.class, detail = true }
    elseif not b.class then
      for _, cls in ipairs(self:Classes()) do s.queue[#s.queue + 1] = { lo = b.lo, hi = b.hi, class = cls, detail = true } end
    else
      s.capped = s.capped + 1 -- one level and one class still over 50: some go uncounted
    end
  end
  if #s.queue == 0 then
    r.lastSweep = { t = time(), searches = s.done, found = s.found, capped = s.capped }
    self:Info("census count done: %d searches, %d players, %d full, %d resent", s.done, s.found, s.capped, self.lost or 0)
    ns.Print("census done: %d players counted in %d searches", s.found, s.done)
  end
  self.status = nil
  if ns.Hub and ns.Hub.current == "census" then ns.Safe("census:refresh", ns.Hub.Refresh, ns.Hub) end
  if #s.queue == 0 then
  elseif s.done == s.overview then
    self:Info("census overview done: %d players; %d more searches would add detail", s.found, #s.queue)
  end
end

-- ------------------------------------------------------------------ people
-- People page (requirement 2026-11-17): find a player, whisper them,
-- invite them to your group or guild; a catalog of guilds; /who for a guild
-- or a zone. Every action is Gary's click; whispers only open the chat box
-- (he types and sends).

-- One /who for a typed filter (g-"Guild", z-"Zone", a name). One press, one search.
function M:SearchFor(filter)
  if type(filter) ~= "string" or filter == "" then return nil, "nothing to search for" end
  if self.pending and (time() - self.pending.t) < M.WAIT then return nil, "the server is still answering, press again in a moment" end
  local send = C.Resolve("C_FriendList.SendWho")
  if type(send) ~= "function" then return nil, "this client has no /who for addons" end
  local set = C.Resolve("C_FriendList.SetWhoToUi") or rawget(_G, "SetWhoToUI")
  if type(set) == "function" then pcall(set, true) end
  if self.pending and self.pending.band and self.sweep then table.insert(self.sweep.queue, 1, self.pending.band) end
  self.pending = { filter = filter, t = time() }
  local ok = pcall(send, filter)
  if not ok then self.pending = nil return nil, "the game refused the search" end
  self:Debug("who search sent: %s", filter)
  return filter
end

local function quoted(kind, text) return kind .. '-"' .. tostring(text):gsub('"', "") .. '"' end
function M:SearchGuild(guild) return self:SearchFor(quoted("g", guild)) end
function M:SearchZone(zone)
  zone = zone or readable(C.Call("GetZoneText"))
  if not zone or zone == "" then return nil, "no zone known" end
  return self:SearchFor(quoted("z", zone))
end

-- The name chat and invites want: "Name" on your realm, "Name-Realm" elsewhere.
function M.TargetName(full)
  if type(full) ~= "string" then return nil end
  local name, realm = full:match("^([^-]+)-(.+)$")
  if not name then return full end
  local mine = tostring(C.Call("GetRealmName") or ""):gsub("%s", "")
  return realm == mine and name or full
end

-- Players matching words (name, guild, zone, class, race, all must match), highest level first.
function M:Find(text, limit)
  local words = {}
  for w in tostring(text or ""):lower():gmatch("%S+") do words[#words + 1] = w end
  local out = {}
  for full, pl in pairs(self:Realm().players) do
    local hay = (full .. " " .. (pl.g or "") .. " " .. (pl.z or "") .. " " .. M.ClassName(pl.c) .. " " .. (pl.r or "") .. " " .. pl.l):lower()
    local ok = true
    for _, w in ipairs(words) do if not hay:find(w, 1, true) then ok = false break end end
    if ok then out[#out + 1] = { name = full, l = pl.l, c = pl.c, r = pl.r, g = pl.g, z = pl.z, t = pl.t, f = pl.f } end
  end
  table.sort(out, function(a, b) if a.l ~= b.l then return a.l > b.l end return a.name < b.name end)
  for i = (limit or 200) + 1, #out do out[i] = nil end
  return out
end

-- Every guild seen: members counted, levels, most common zone and class.
function M:Guilds(text)
  local g = {}
  for _, pl in pairs(self:Realm().players) do
    if pl.g and pl.g ~= "" then
      local e = g[pl.g]
      if not e then e = { name = pl.g, n = 0, sum = 0, max = 0, zones = {}, classes = {}, t = 0 } g[pl.g] = e end
      e.n, e.sum, e.max = e.n + 1, e.sum + pl.l, math.max(e.max, pl.l)
      if pl.z then e.zones[pl.z] = (e.zones[pl.z] or 0) + 1 end
      if pl.c then e.classes[pl.c] = (e.classes[pl.c] or 0) + 1 end
      e.t = math.max(e.t, pl.t or 0)
    end
  end
  local out, q = {}, tostring(text or ""):lower()
  for _, e in pairs(g) do
    if q == "" or e.name:lower():find(q, 1, true) then
      local function top(t) local best, n = nil, 0 for k, c in pairs(t) do if c > n then best, n = k, c end end return best end
      e.avg, e.zone, e.class = e.sum / e.n, top(e.zones), top(e.classes)
      out[#out + 1] = e
    end
  end
  table.sort(out, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.name < b.name end)
  return out
end

-- Open the chat box with "/w Name " ready; Gary types and sends.
function M:Whisper(full)
  local name = M.TargetName(full)
  if not name then return false end
  local tell = C.Resolve("ChatFrameUtil.SendTell") or C.Resolve("ChatFrame_SendTell")
  if type(tell) == "function" then
    local ok = pcall(tell, name)
    if ok then return true end
  end
  local open = C.Resolve("ChatFrame_OpenChat") or C.Resolve("ChatFrameUtil.OpenChat")
  if type(open) == "function" then return (pcall(open, "/w " .. name .. " ")) end
  return false
end

function M:Invite(full)
  local name = M.TargetName(full)
  local inv = C.Resolve("C_PartyInfo.InviteUnit") or C.Resolve("InviteUnit")
  if not name or type(inv) ~= "function" then return false, "group invites aren't available" end
  local ok = pcall(inv, name)
  self:Info("group invite sent to %s", tostring(name))
  return ok, ok and nil or "the game refused the invite"
end

function M.CanGuildInvite()
  return readable(C.Call("IsInGuild")) and readable(C.Call("CanGuildInvite")) and true or false
end

function M:GuildInvite(full)
  local name = M.TargetName(full)
  if not M.CanGuildInvite() then return false, "you can't invite to a guild (not in one, or your rank can't)" end
  local inv = C.Resolve("C_GuildInfo.Invite") or C.Resolve("GuildInvite")
  if not name or type(inv) ~= "function" then return false, "guild invites aren't available" end
  local ok = pcall(inv, name)
  self:Info("guild invite sent to %s", tostring(name))
  return ok, ok and nil or "the game refused the invite"
end

-- Players counted at levels lo..hi (all sources).
function M:CountLevels(lo, hi)
  local n = 0
  for _, p in pairs(self:Realm().players) do if p.l >= lo and p.l <= hi then n = n + 1 end end
  return n
end

-- A press of the button or the key binding: one search, the page shows how
-- it went (no chat lines, rule 6).
function M:Press()
  local sent, why = self:SearchNext()
  self.status = not sent and why or nil
  if ns.Hub and ns.Hub.current == "census" then ns.Safe("census:refresh", ns.Hub.Refresh, ns.Hub) end
  return sent, why
end

-- Where the count is, in words, for the page.
function M:Progress()
  local s = self.sweep
  if not s then return nil end
  local left = #s.queue
  if left == 0 then return string.format("Count finished: %d players in %d searches.", s.found, s.done) end
  local nxt = s.queue[1]
  local stage = nxt.detail and "Every level is covered; the rest adds detail to the busiest levels" or
    string.format("Overview: %d of %d level groups searched", math.min(s.done, s.overview), s.overview)
  return string.format("%s. %d players so far, %d searches to go. Next: level %s.", stage, s.found, left, bandFilter(nxt):gsub(' c%-"', " ("):gsub('"$', ")"))
end

-- Level groups as /who saw them, highest first; full ones are "50+".
function M:BandRows()
  local r, out = self:Realm(), {}
  for _, b in ipairs(M.Bands()) do
    local got = r.bands and r.bands[bandFilter(b)]
    if got then out[#out + 1] = { b = b, n = got.n, full = got.full } end
  end
  return out
end

-- ------------------------------------------------------------------ stats
function M:Prune()
  local cut = time() - 86400 * M.KEEP_DAYS
  local r, n = self:Realm(), 0
  local realm = M.RealmKey()
  -- aged-out players and profession sightings move to the archive, keyed by realm and name
  for k, p in pairs(r.players) do
    if (p.t or 0) < cut and ns.Archive:Put("censusPlayers", p, { path = "global.census[realm].players[name]", keys = { realm = realm, name = k } }) then
      r.players[k] = nil n = n + 1
    end
  end
  for k, t in pairs(r.profs) do
    local any = false
    for prof, when in pairs(t) do
      if when < cut and ns.Archive:Put("censusProfs", when, { path = "global.census[realm].profs[name][prof]", keys = { realm = realm, name = k, prof = prof } }) then
        t[prof] = nil
      else any = true end
    end
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

local function ago(t) return ns.Ago(time() - (t or 0)) end

ns.Hub:AddTab("census", "Census", function(p)
  local UI = ns.UI
  local function st() return M:Stats() end
  UI:FormPage(p, {
    { "header", "Census" },
    { "stats", function()
      local s = st()
      local topClass = s.classes and s.classes[1]
      return {
        { cap = "Players counted", value = tostring(s.total or 0), note = (s.fromWho or 0) .. " from /who" },
        { cap = "Average level", value = string.format("%.0f", s.avg or 0) },
        { cap = "Most played class", value = topClass and (M.ClassName(topClass.key) or ns.TitleCase(tostring(topClass.key):lower())) or "—",
          note = topClass and (topClass.n or 0) .. " players" or nil },
        { cap = "Highest level seen", value = s.top and s.top[1] and tostring(s.top[1].l) or "—",
          note = s.top and s.top[1] and s.top[1].name or nil },
      }
    end },
    { "header", "Who's playing", icon = "INV_Misc_GroupLooking" },
    { "note", function()
      local s = st()
      if s.total == 0 then return "Nobody counted yet. Press Search the next group below, or just play: players you mouse over, target or group with are counted." end
      return string.format("%d players on %s in the last %d days (%d from /who, the rest seen around you). Average level %.1f; most common level %s.",
        s.total, M.RealmKey(), M.KEEP_DAYS, s.fromWho, s.avg, s.levels[1] and s.levels[1].key or "?")
    end },
    { "header", "Count everyone with /who", icon = "INV_Misc_Spyglass_02" },
    { "note", function()
      local head = "Each press sends one /who search; Blizzard shows at most 50 players a search and wants a press for each. "
        .. "The count starts at the top level and works down, so the first 13 presses cover every level; after that, presses add detail to the busiest levels. "
        .. "Tip: bind a key to Outrider: Census search (Key Bindings, AddOns) and tap it. Only your faction shows in /who."
      local prog = M:Progress()
      if prog then head = head .. "\n|cffffd100" .. prog .. "|r" end
      if M.status then head = head .. "\n|cffff7f7f" .. M.status .. "|r" end
      local last = M:Realm().lastSweep
      if last then head = head .. string.format("\nLast full count %s: %d players in %d searches.", ago(last.t), last.found, last.searches) end
      return head
    end },
    { "buttons", { { "Search the next group", function() M:Press() end, 190 },
      { "Start a new count", function() M:NewSweep() M.status = nil p:Refresh() end, 150 } } },
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
    { "note", function()
      return #M:BandRows() > 0 and "From /who, highest first. 50+ means more players than one search shows; detail presses count them." or ""
    end },
    { "bars", function()
      local rows = M:BandRows()
      if #rows == 0 then return bars(st().bands) end
      local max = 1
      for _, x in ipairs(rows) do if x.n > max then max = x.n end end
      local out = {}
      for _, x in ipairs(rows) do
        local seen = M:CountLevels(x.b.lo, x.b.hi)
        out[#out + 1] = { label = "Level " .. (x.b.lo == x.b.hi and x.b.lo or (x.b.lo .. "-" .. x.b.hi)), fill = math.max(x.n, seen) / math.max(max, seen),
          text = x.full and (math.max(seen, x.n) .. "+") or tostring(x.n) }
      end
      return out
    end },
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

-- ------------------------------------------------------------------ page: players & guilds
local function seenText(x)
  return (x.z and (x.z .. ", ") or "") .. "seen " .. ago(x.t)
end

ns.Hub:AddTab("people", "Players & guilds", function(p)
  local UI = ns.UI
  local function pick() return M.selected and M:Realm().players[M.selected] and M.selected end
  local function act(fn)
    return function()
      local ok, why = fn()
      M.status = (ok == false or ok == nil) and why or nil
      p:Refresh()
    end
  end
  UI:FormPage(p, {
    { "header", "Players & guilds" },
    { "header", "Find a player", icon = "INV_Misc_GroupLooking" },
    { "input", "Find", "name, guild, zone, class or level", "Find", function(t) M.filter = t M.selected = nil end, true },
    { "note", function()
      local n = #M:Find(M.filter)
      local head = M.filter and M.filter ~= "" and string.format("%d players match '%s'. Click one to whisper or invite them.", n, M.filter)
        or string.format("%d players counted, highest level first. Click one to whisper or invite them.", n)
      if M.status then head = head .. "\n|cffff7f7f" .. M.status .. "|r" end
      return head
    end },
    { "buttons", { { "In my zone", function() M.filter = readable(C.Call("GetZoneText")) or "" M.selected = nil end, 120 },
      { "Show everyone", function() M.filter = nil M.selected = nil end, 130 } },
      active = function(i)
        local zone = readable(C.Call("GetZoneText")) or ""
        local f = M.filter or ""
        if i == 1 then return f ~= "" and f == zone end
        return f == ""
      end },
    -- a sortable table (2026-11-18 premium rebuild): click a column to sort
    { "table", 10, {
      { key = "name", label = "Name", width = 0, sort = function(x) return x.name end,
        text = function(x)
          local cc = (rawget(_G, "RAID_CLASS_COLORS") or {})[x.c]
          local hex = cc and string.format("|cff%02x%02x%02x", cc.r * 255, cc.g * 255, cc.b * 255) or "|cffffffff"
          return hex .. (x.name:match("^[^-]+") or x.name) .. "|r"
        end },
      { key = "l", label = "Lvl", width = 50, align = "RIGHT", sort = function(x) return x.l or 0 end, text = function(x) return x.l end },
      { key = "c", label = "Class", width = 100, sort = function(x) return M.ClassName(x.c) or "" end, text = function(x) return M.ClassName(x.c) end },
      { key = "g", label = "Guild", width = 0, sort = function(x) return x.g or "" end, text = function(x) return x.g and ("|cfff1d58e<" .. x.g .. ">|r") or "" end },
      { key = "z", label = "Zone", width = 0, sort = function(x) return x.z or "" end, text = function(x) return x.z or "" end },
      { key = "t", label = "Seen", width = 120, align = "RIGHT", sort = function(x) return x.t or 0 end,
        text = function(x) return "|cff8f96a6" .. ago(x.t) .. "|r" end },
    }, function() return M:Find(M.filter) end, function(x) M.selected = x.name p:Refresh() end, sortKey = "l", desc = true },
    { "cards", function()
      local full = pick()
      if not full then return {} end
      local x = M:Realm().players[full]
      local tags = { { "Level " .. x.l, "gold" }, { M.ClassName(x.c), "plain" } }
      if x.r then tags[#tags + 1] = { x.r, "plain" } end
      local actions = {
        { "Whisper", act(function() return M:Whisper(full), "chat isn't available" end), "Opens the chat box with a whisper to them; you type and send." },
        { "Invite to group", act(function() return M:Invite(full) end), "Sends them a group invite." },
      }
      if M.CanGuildInvite() then
        actions[#actions + 1] = { "Invite to my guild", act(function() return M:GuildInvite(full) end), "Sends them an invite to your guild." }
      end
      return { { art = x.c and ("class_" .. x.c:lower()) or nil, pic = "Interface\\Icons\\INV_Misc_QuestionMark",
        title = full:match("^[^-]+") or full, tags = tags, highlight = true, actions = actions,
        line = (x.g and ("<" .. x.g .. ">  ") or "") .. seenText({ z = x.z, t = x.t }) } }
    end },
    { "header", "Search with /who", icon = "INV_Misc_Spyglass_02" },
    { "note", function()
      local l = M.lastSearch
      local base = "One press, one search: everyone in a guild or a zone right now (your faction, 50 at most). Results join the census."
      if l then base = base .. string.format("\n|cffffd100Last search %s: %d found%s.|r", l.filter, l.n, l.total > l.n and (" of " .. l.total) or "") end
      return base
    end },
    { "input", "Search a guild", "Guild name", "Search", function(t) local ok, why = M:SearchGuild(t) M.status = not ok and why or nil M.filter = t end, true },
    { "buttons", { { "Search my zone", act(function() return M:SearchZone() end), 140 } } },
    { "header", "Guilds", icon = "INV_Shirt_GuildTabard_01" },
    { "note", function()
      local g = M:Guilds()
      return #g == 0 and "No guilds seen yet. Every guild tag from /who and players around you lands here."
        or string.format("%d guilds seen, most members first. Click one to list its members.", #g)
    end },
    { "table", 8, {
      { key = "name", label = "Guild", width = 0, sort = function(e) return e.name end, text = function(e) return "|cfff1d58e" .. e.name .. "|r" end },
      { key = "n", label = "Seen", width = 60, align = "RIGHT", sort = function(e) return e.n end, text = function(e) return e.n end },
      { key = "avg", label = "Avg lvl", width = 70, align = "RIGHT", sort = function(e) return e.avg end, text = function(e) return string.format("%.0f", e.avg) end },
      { key = "max", label = "Top", width = 50, align = "RIGHT", sort = function(e) return e.max end, text = function(e) return e.max end },
      { key = "class", label = "Most played", width = 110, sort = function(e) return e.class or "" end, text = function(e) return e.class and M.ClassName(e.class) or "" end },
      { key = "zone", label = "Mostly in", width = 0, sort = function(e) return e.zone or "" end, text = function(e) return "|cff8f96a6" .. (e.zone or "") .. "|r" end },
    }, function()
      -- guilds of only level-1 characters are noise (bank alts, name holders)
      local out = {}
      for _, e in ipairs(M:Guilds()) do if (e.max or 0) > 1 then out[#out + 1] = e end end
      return out
    end, function(e) M.filter = e.name M.selected = nil M.guildPick = e.name p:Refresh() end, sortKey = "n", desc = true },
    { "buttons", { { "Search this guild", act(function()
      if not M.guildPick then return nil, "click a guild in the list first" end
      return M:SearchGuild(M.guildPick)
    end), 160 } } },
    { "note", "Whispers open the chat box; you write and send them. Invites go out only when you click." },
  })
end)

ns.AddCommand("census", "who's playing: most common level, class, race, profession (/ride census who searches the next group, reset clears)", function(arg)
  arg = tostring(arg or ""):lower()
  if arg == "who" then
    local sent, why = M:Press()
    ns.Print(sent and ("census search: " .. sent .. " (" .. M:Left() .. " to go)") or ("census: " .. tostring(why)))
  elseif arg == "reset" then
    local realm = M.RealmKey()
    if M.store[realm] ~= nil and not ns.Archive:Put("censusCleared", M.store[realm], { path = "global.census[realm]", keys = { realm = realm } }) then
      ns.Print("census: could not archive, nothing cleared") return
    end
    M.store[realm] = nil
    M.sweep = nil
    ns.Print("census cleared for %s", M.RealmKey())
  else
    ns.Print("census: %s", M:Summary())
  end
end)

_G.BINDING_NAME_OUTRIDER_CENSUS = "Census search (one /who per press)"

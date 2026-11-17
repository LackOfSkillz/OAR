-- Modules/Alts.lua
-- Alt overview, dungeon lockouts and run stats (gap analysis 2026-11-17,
-- Nova Instance Tracker style).
--   * Every character's card: level, gold, rested XP (estimated while
--     offline), free bag slots, durability, ammo, professions, where and when
--     last seen. Saved in ns.db.global.alts[key] at login, on changes and at
--     logout.
--   * Instance lockouts (account-wide): Classic allows 5 new instances an
--     hour and 30 a day. Each entry into a dungeon or raid that isn't the
--     same one you just left counts; a "has been reset" system message makes
--     the next entry new. An estimate: the server keeps the real count.
--   * Run stats: time inside, XP gained (kills counted from the XP lines in
--     chat), gold made, per run; the last 30 runs.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Alts", {
  title = "Alt overview and dungeon runs",
  phase = "P6",
  order = 58,
  defaults = {},
})
ns.Alts = M

M.HOUR_LIMIT, M.DAY_LIMIT = 5, 30
M.KEEP_RUNS = 30
M.SAME_RUN = 30 * 60 -- re-entering the same dungeon within 30 min is the same instance

local function readable(v) return v ~= nil and C.Readable(v) and v or nil end

function M:OnInitialize()
  local g = ns.db.global
  g.alts = type(g.alts) == "table" and g.alts or {}
  g.runs = type(g.runs) == "table" and g.runs or {}
  g.instances = type(g.instances) == "table" and g.instances or {} -- { {t, map, name, char} }
  self.alts, self.runs, self.inst = g.alts, g.runs, g.instances
end

-- ------------------------------------------------------------------ alts
function M:Record(why)
  local key = ns.db.key
  local level = tonumber(C.Call("UnitLevel", "player")) or 1
  local _, class = C.Call("UnitClass", "player")
  local xp, need = tonumber(readable(C.Call("UnitXP", "player"))), tonumber(readable(C.Call("UnitXPMax", "player")))
  local rested = tonumber(readable(C.Call("GetXPExhaustion"))) or 0
  local IB = ns.InfoBar
  local free, total = 0, 0
  if IB then free, total = IB.Bags() end
  local dura, low
  if IB then dura, low = IB.Durability() end
  local profs = {}
  for name, p in pairs(ns.db.char.professions or {}) do
    if type(p) == "table" and p.skill then profs[name] = { p.skill, p.max } end
  end
  local a = self.alts[key] or {}
  a.level, a.class, a.faction = level, class, readable(C.Call("UnitFactionGroup", "player"))
  a.money = tonumber(C.Call("GetMoney")) or a.money
  a.xpPct = (xp and need and need > 0) and (xp / need * 100) or a.xpPct
  a.restedPct = (need and need > 0) and (rested / need * 100) or 0
  a.resting = readable(C.Call("IsResting")) and true or false
  a.freeBags, a.bagSlots = free, total
  a.dura, a.duraLow = dura and math.floor(dura + 0.5), low and math.floor(low + 0.5)
  a.ammo = IB and IB.Ammo() or nil
  a.profs = profs
  a.zone = readable(C.Call("GetZoneText")) or a.zone
  a.t = time()
  self.alts[key] = a
  self:Debug("alt recorded (%s)", tostring(why))
  return a
end

-- Rested XP grows offline: 5% of a level per 8 hours in an inn or city,
-- a quarter of that elsewhere, up to 150% (Classic rule, an estimate).
function M.RestedNow(a, now)
  if not a then return 0 end
  local pct = tonumber(a.restedPct) or 0
  if (a.level or 1) >= 60 then return 0 end
  local hours = math.max(0, ((now or time()) - (a.t or 0)) / 3600)
  local rate = a.resting and 5 / 8 or 1.25 / 8
  return math.min(150, pct + hours * rate)
end

function M:List()
  local out = {}
  for key, a in pairs(self.alts) do
    out[#out + 1] = { key = key, a = a, current = key == ns.db.key }
  end
  table.sort(out, function(x, y)
    if x.current ~= y.current then return x.current end
    if (x.a.level or 0) ~= (y.a.level or 0) then return (x.a.level or 0) > (y.a.level or 0) end
    return x.key < y.key
  end)
  return out
end

function M:TotalGold()
  local n = 0
  for _, a in pairs(self.alts) do n = n + (tonumber(a.money) or 0) end
  return n
end

-- ------------------------------------------------------------------ lockouts
function M:Prune()
  local cut, keep = time() - 86400, {}
  for _, e in ipairs(self.inst) do if e.t >= cut then keep[#keep + 1] = e end end
  for i = #self.inst, 1, -1 do self.inst[i] = nil end
  for i, e in ipairs(keep) do self.inst[i] = e end
end

-- instances started in the last hour and day, and when the next hour slot frees
function M:Lockouts(now)
  now = now or time()
  self:Prune()
  local hour, day, oldest = 0, 0, nil
  for _, e in ipairs(self.inst) do
    if now - e.t < 3600 then
      hour = hour + 1
      if not oldest or e.t < oldest then oldest = e.t end
    end
    if now - e.t < 86400 then day = day + 1 end
  end
  return { hour = hour, day = day, freeAt = (hour >= M.HOUR_LIMIT and oldest) and (oldest + 3600) or nil }
end

function M:OnZone()
  local inside, kind = C.Call("IsInInstance")
  inside, kind = readable(inside), readable(kind)
  local now = time()
  if inside and (kind == "party" or kind == "raid") then
    local info = C.Resolve("GetInstanceInfo")
    local _, name, _, _, _, _, _, _, map = pcall(type(info) == "function" and info or error)
    map = map or name -- C.Call keeps only five values; called directly here
    name, map = readable(name), readable(map)
    if self.run and self.run.map == map then return end -- a loading screen inside
    local last = self.lastLeft
    local same = last and last.map == map and not self.resetSince and (now - last.t) < M.SAME_RUN
    if not same then
      self.inst[#self.inst + 1] = { t = now, map = map, name = name, char = ns.db.key }
      local lk = self:Lockouts(now)
      self:Info("new instance %s: %d this hour, %d today", tostring(name), lk.hour, lk.day)
      if lk.hour >= M.HOUR_LIMIT - 1 then
        ns.Print("%d of %d instances this hour", lk.hour, M.HOUR_LIMIT)
      end
    end
    self.resetSince = nil
    self.run = { map = map, name = name, start = now, money = tonumber(C.Call("GetMoney")) or 0, xp = 0, kills = 0,
      char = ns.db.key, level = tonumber(C.Call("UnitLevel", "player")) or 1, continued = same or nil }
    self.lastXP, self.lastMax = tonumber(readable(C.Call("UnitXP", "player"))), tonumber(readable(C.Call("UnitXPMax", "player")))
  elseif self.run then
    self:EndRun(now)
  end
end

function M:EndRun(now)
  local r = self.run
  self.run = nil
  if not r then return end
  r.stop = now or time()
  r.gold = (tonumber(C.Call("GetMoney")) or r.money) - r.money
  r.money = nil
  self.lastLeft = { map = r.map, t = r.stop }
  if r.stop - r.start < 60 then return end -- a peek inside, not a run
  table.insert(self.runs, 1, r)
  for i = M.KEEP_RUNS + 1, #self.runs do self.runs[i] = nil end
  self:Info("run done: %s %d min, %d xp, %d kills, %d copper", tostring(r.name), math.floor((r.stop - r.start) / 60), r.xp, r.kills, r.gold)
end

function M:OnXP()
  if not self.run then return end
  local xp, max = tonumber(readable(C.Call("UnitXP", "player"))), tonumber(readable(C.Call("UnitXPMax", "player")))
  if not (xp and self.lastXP) then self.lastXP, self.lastMax = xp, max return end
  local d = xp - self.lastXP
  if d < 0 then d = (self.lastMax or 0) - self.lastXP + xp end -- levelled up
  if d > 0 then self.run.xp = self.run.xp + d end
  self.lastXP, self.lastMax = xp, max
end

function M:OnXPLine(_, msg)
  msg = readable(msg)
  if self.run and type(msg) == "string" and msg:find("dies", 1, true) then self.run.kills = self.run.kills + 1 end
end

function M:OnSystem(_, msg)
  msg = readable(msg)
  if type(msg) ~= "string" then return end
  local fmt = rawget(_G, "INSTANCE_RESET_SUCCESS") or "%s has been reset."
  local pat = "^" .. fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%s", ".+") .. "$"
  if msg:find(pat) then self.resetSince = true self:Info("instances reset") end
end

function M.RunLine(r)
  local mins = math.max(1, math.floor(((r.stop or time()) - r.start) / 60))
  local perHour = r.xp > 0 and math.floor(r.xp / mins * 60) or 0
  local gold = ns.InfoBar and ns.InfoBar.GoldText(math.max(0, r.gold or 0)) or tostring(r.gold)
  return string.format("%d min, %d XP (%d an hour), %d kills, %s%s", mins, r.xp, perHour, r.kills, (r.gold or 0) < 0 and "-" or "", gold)
end

-- ------------------------------------------------------------------ module
function M:OnEnable()
  self:On("PLAYER_ENTERING_WORLD", function(mod, _, isLogin) mod:Record(isLogin and "login" or "zone") mod:OnZone() end)
  self:On("PLAYER_LOGOUT", function(mod) if mod.run then mod:EndRun() end mod:Record("logout") end)
  self:On("PLAYER_LEVEL_UP", function(mod) mod:Record("level") end)
  self:On("PLAYER_MONEY", function(mod) ns.Throttle("alts:money", 5, function() mod:Record("money") end) end)
  self:On("PLAYER_UPDATE_RESTING", function(mod) mod:Record("resting") end)
  self:On("PLAYER_XP_UPDATE", self.OnXP)
  self:On("CHAT_MSG_COMBAT_XP_GAIN", self.OnXPLine)
  self:On("CHAT_MSG_SYSTEM", self.OnSystem)
end

function M:Snapshot()
  local lk = self:Lockouts()
  return { characters = #self:List(), instancesThisHour = lk.hour, instancesToday = lk.day }
end

function M:Activity()
  local lk = self:Lockouts()
  return string.format("%d characters, %d/%d instances this hour", #self:List(), lk.hour, M.HOUR_LIMIT)
end

-- ------------------------------------------------------------------ page
local function ago(t)
  local d = time() - (t or 0)
  if d < 3600 then return math.max(1, math.floor(d / 60)) .. " min ago" end
  if d < 86400 then return math.floor(d / 3600) .. " h ago" end
  return math.floor(d / 86400) .. " days ago"
end

ns.Hub:AddTab("alts", "My characters", function(p)
  local UI = ns.UI
  local gold = function(c) return ns.InfoBar and ns.InfoBar.GoldText(c) or tostring(c) end
  UI:FormPage(p, {
    { "header", "My characters" },
    { "header", "Every character", icon = "INV_Misc_Head_Human_01" },
    { "note", function()
      return string.format("%d characters, %s in all. Rested XP keeps growing while you're offline (estimated: faster in an inn or city).",
        #M:List(), gold(M:TotalGold()))
    end },
    { "cards", function()
      local out = {}
      for _, x in ipairs(M:List()) do
        local a = x.a
        local tags = { { "Level " .. tostring(a.level or "?"), "gold" }, { gold(a.money or 0), "plain" } }
        local rest = M.RestedNow(a)
        if rest >= 1 then tags[#tags + 1] = { string.format("%d%% rested", math.floor(rest)), "plain" } end
        local bits = {}
        if a.bagSlots and a.bagSlots > 0 then bits[#bits + 1] = string.format("bags %d free", a.freeBags or 0) end
        if a.dura then bits[#bits + 1] = string.format("durability %d%%", a.dura) end
        if a.ammo then bits[#bits + 1] = "ammo " .. a.ammo end
        local pl = {}
        for name, s in pairs(a.profs or {}) do pl[#pl + 1] = string.format("%s %d/%d", name, s[1] or 0, s[2] or 0) end
        table.sort(pl)
        if #pl > 0 then bits[#bits + 1] = table.concat(pl, ", ") end
        bits[#bits + 1] = (a.zone and (a.zone .. ", ") or "") .. (x.current and "playing now" or ("seen " .. ago(a.t)))
        out[#out + 1] = { art = a.class and ("class_" .. a.class:lower()) or nil, pic = "Interface\\Icons\\INV_Misc_QuestionMark",
          title = x.key:match("^[^-]+") or x.key, tags = tags, line = table.concat(bits, "  |  "), highlight = x.current }
      end
      return out
    end },
    { "header", "Dungeon lockouts", icon = "INV_Misc_Key_14" },
    { "tiles", function()
      local lk = M:Lockouts()
      local free = lk.freeAt and (" (next at " .. date("%H:%M", lk.freeAt) .. ")") or ""
      return {
        { ok = lk.hour < M.HOUR_LIMIT, icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
          text = string.format("This hour: %d of %d instances%s", lk.hour, M.HOUR_LIMIT, free) },
        { ok = lk.day < M.DAY_LIMIT, icon = "Interface\\Icons\\INV_Misc_PocketWatch_02",
          text = string.format("Today: %d of %d instances", lk.day, M.DAY_LIMIT) },
      }
    end },
    { "note", "Counted for the whole account from the dungeons and raids you enter; re-entering the one you just left doesn't count, and a reset makes the next one new. An estimate: the server keeps the real count." },
    { "header", "Recent runs", icon = "Spell_Holy_SurgeOfLight" },
    { "cards", function()
      local out = {}
      for i, r in ipairs(M.runs) do
        if i > 8 then break end
        out[#out + 1] = { art = r.name and ("dungeon_" .. r.name:lower():gsub("[^%w]", "")) or nil, pic = "Interface\\Icons\\INV_Misc_Key_14",
          title = tostring(r.name or "?"), tags = { { (r.char or ""):match("^[^-]+") or "", "plain" }, { date("%b %d %H:%M", r.start), "plain" } },
          line = M.RunLine(r) }
      end
      return out
    end },
    { "note", function() return #M.runs == 0 and "No runs yet. Every dungeon you enter is timed with the XP and gold it gave." or "" end },
  })
end)

ns.AddCommand("runs", "dungeon lockouts this hour and today, and your last runs", function()
  local lk = M:Lockouts()
  ns.Print("instances: %d/%d this hour, %d/%d today", lk.hour, M.HOUR_LIMIT, lk.day, M.DAY_LIMIT)
  for i, r in ipairs(M.runs) do
    if i > 3 then break end
    ns.Print("%s: %s", tostring(r.name), M.RunLine(r))
  end
end)

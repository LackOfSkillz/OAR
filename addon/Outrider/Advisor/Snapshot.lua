-- Advisor/Snapshot.lua
-- Phase 9 groundwork, safe to ship now: "/ride snap" writes a plain-data
-- picture of the current character into Outrider_Snapshots, which WoW saves to
-- disk on the next /reload or logout. The future companion app (an MCP
-- server on Gary's PC) reads that file and nothing else. No network, no
-- input, no automation. Modules contribute by defining :Snapshot().

local _, ns = ...
local Snap = { name = "snapshot", SCHEMA = 1 }
ns.Snapshot = Snap

local function where()
  local mapID, x, y = ns.Compat.PlayerPosition()
  if not mapID then return nil end
  local info = ns.Compat.Call("C_Map.GetMapInfo", mapID)
  return { mapID = mapID, x = x, y = y, zone = info and info.name }
end

local function gear()
  local out = {}
  if not GetInventoryItemLink then return out end
  for slot = 1, 19 do
    local link = GetInventoryItemLink("player", slot)
    if link then out[slot] = tonumber(link:match("item:(%d+)")) end
  end
  return out
end

-- Quest log titles, IDs and levels (headers skipped), for the advisor.
local function quests()
  local out = {}
  local n = ns.Compat.Call("C_QuestLog.GetNumQuestLogEntries") or 0
  for i = 1, n do
    local info = ns.Compat.Call("C_QuestLog.GetInfo", i)
    if type(info) == "table" and not info.isHeader and info.questID then
      out[#out + 1] = { id = info.questID, title = ns.Compat.Readable(info.title), level = info.level,
        complete = ns.Compat.Call("C_QuestLog.IsComplete", info.questID) == true }
    end
  end
  return out
end

-- Plain data only: no functions, frames or userdata; strings cut to 200 chars.
local function plain(v, depth)
  local t = type(v)
  if t == "string" then return #v > 200 and v:sub(1, 200) or v end
  if t == "number" or t == "boolean" then return v end
  if t ~= "table" or depth > 6 or getmetatable(v) ~= nil then return nil end
  local out = {}
  for k, x in pairs(v) do
    if type(k) == "string" or type(k) == "number" then out[k] = plain(x, depth + 1) end
  end
  return out
end
Snap.Plain = plain
Snap.MAX_BYTES = 50 * 1024

-- Modules opt in by implementing Module:Snapshot() returning plain data.
local function fromModules()
  local out = {}
  for _, mod in ipairs(ns.Modules.list) do
    if mod.enabled and mod.Snapshot then
      local ok, data = ns.Safe(mod.name .. ":Snapshot", mod.Snapshot, mod)
      if ok and data ~= nil then out[mod.name] = data end
    end
  end
  return out
end

-- asked = true for /ride ask and /ride snap. askedAt marks the question the
-- advice answers; the automatic logout snapshot refreshes the data but keeps
-- askedAt, so advice stays valid across /reload until the next /ride ask.
function Snap:Collect(asked)
  Outrider_Snapshots = type(Outrider_Snapshots) == "table" and Outrider_Snapshots or {}
  local meta = ns.db.char.meta
  local prev = Outrider_Snapshots[ns.db.key]
  local now = time()
  local s = {
    schema = self.SCHEMA,
    takenAt = now,
    askedAt = asked and now or (type(prev) == "table" and (prev.askedAt or prev.takenAt)) or now,
    addon = ns.version, build = ns.build,
    -- Outrider Intelligence (AI01-01/03): an id for this snapshot and the
    -- client build, so answers can be bound to the snapshot they answer
    snapshotId = string.format("%s-%d", tostring(meta.class or "char"):lower(), now),
    gameBuild = GetBuildInfo and select(1, GetBuildInfo()) or nil,
    level = UnitLevel and UnitLevel("player"),
    class = meta.class, race = meta.race, faction = meta.faction,
    money = GetMoney and GetMoney(),
    where = where(),
    gear = gear(),
  }
  -- At logout the game no longer reports position, gear links or gold
  -- (every logout snapshot had map nil, Khreos's no gear and 0 money; audit
  -- 2026-11-15): fall back to what was last seen while playing.
  local live = self.live or {}
  if not s.where then s.where = live.where end
  if not next(s.gear) and live.gear then s.gear = live.gear end
  if (not s.money or s.money == 0) and live.money then s.money = live.money end
  if (not s.level or s.level == 0) and live.level then s.level = live.level end
  -- the question typed in the Advisor tab and the time you have (AI03)
  if asked then
    local q = ns.db.char.askQuestion
    s.question = type(q) == "string" and q ~= "" and q:sub(1, 200) or nil
    s.timeBudget = tonumber(ns.db.char.askMinutes)
  end
  s.quests = quests()
  self.asking = asked and true or false   -- modules may add more for a question (WhatNow candidates)
  s.modules = plain(fromModules(), 0)
  self.asking = false
  -- a refresh (logout) keeps the steps of the last /ride ask, which the
  -- companion's answers are checked against
  if not asked and type(prev) == "table" and type(prev.modules) == "table" and prev.modules.WhatNow
    and not s.modules.WhatNow then
    s.modules.WhatNow = prev.modules.WhatNow
  end
  -- keep the saved file small: drop the largest module parts until it fits
  local size = #ns.Serialize.Encode(s)
  while size > self.MAX_BYTES do
    local biggest, bytes
    for name, data in pairs(s.modules) do
      local b = #ns.Serialize.Encode(data)
      if not bytes or b > bytes then biggest, bytes = name, b end
    end
    if not biggest then break end
    s.modules[biggest] = nil
    ns.Log:Info("snapshot", "dropped module %s (%d bytes) to stay under %d KB", biggest, bytes, self.MAX_BYTES / 1024)
    size = #ns.Serialize.Encode(s)
  end
  s.bytes = size
  Outrider_Snapshots[ns.db.key] = s
  ns.Log:Info("snapshot", "snapshot taken for %s", ns.db.key)
  return s
end

-- Phase 9 entry point (not bound to anything yet). Typing a slash command is
-- a key press, so ReloadUI from here is allowed.
-- The snapshot as a copyable code (no reload needed).
function Snap:Code()
  local s = Outrider_Snapshots and Outrider_Snapshots[ns.db.key]
  if not s then return nil end
  return ns.Serialize.Export({ kind = "snapshot", character = ns.db.key, snapshot = s })
end

-- /ride ask: fresh snapshot shown as a code to copy (Ctrl+C), no reload.
-- /ride ask reload: the older way, written to disk by a reload.
function Snap:AskAdvisor(mode)
  if ns.Compat.InCombat() then ns.Print("not in combat") return end
  self:Collect(true)
  self.askedThisSession = time()
  if mode == "reload" then
    ns.db.char.askPending = time()
    ReloadUI()
    return
  end
  local code = self:Code()
  ns.UI:TextDialog("Copy for your advisor", code, "copy")
  local d = ns.UI.dialog
  if d and d.hint then d.hint:SetText("Ctrl+C. Ask Outrider answers by itself; then your Paste key and Ctrl+V.") end
  ns.Log:Info("snapshot", "ask: snapshot code shown (%d characters)", #code)
end

-- At logout: keep the /ride ask snapshot if it was taken in the last 10
-- minutes (data read during logout is often empty: no position, quest levels
-- 0, Gary's report 2026-11-11), else refresh it.
function Snap:OnLogout()
  if self.askedThisSession and time() - self.askedThisSession < 600 then return false end
  self:Collect()
  return true
end

-- One line after the reload that /ride ask causes, so Gary knows what next.
function Snap:AfterLogin()
  local t = ns.db.char.askPending
  if not t then return end
  ns.db.char.askPending = nil
  if time() - t < 300 then
    ns.Print("snapshot saved for your advisor. Ask Claude for advice, then /reload and open the Advisor tab (/ride hub).")
  end
end

-- What was last seen while playing (used when logout reads come back empty).
function Snap:Remember()
  local live = self.live or {}
  local w = where()
  if w then live.where = w end
  local g = gear()
  if next(g) then live.gear = g end
  local m = GetMoney and GetMoney()
  if m and m > 0 then live.money = m end
  local l = UnitLevel and UnitLevel("player")
  if l and l > 0 then live.level = l end
  self.live = live
end

if ns.Events then
  for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_MONEY", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP" }) do
    ns.Events:On(e, Snap, function() Snap:Remember() end)
  end
end

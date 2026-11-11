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

function Snap:Collect()
  Outrider_Snapshots = type(Outrider_Snapshots) == "table" and Outrider_Snapshots or {}
  local meta = ns.db.char.meta
  local s = {
    schema = self.SCHEMA,
    takenAt = time(),
    addon = ns.version, build = ns.build,
    level = UnitLevel and UnitLevel("player"),
    class = meta.class, race = meta.race, faction = meta.faction,
    money = GetMoney and GetMoney(),
    where = where(),
    gear = gear(),
    quests = quests(),
    modules = plain(fromModules(), 0),
  }
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
function Snap:AskAdvisor()
  if ns.Compat.InCombat() then ns.Print("not in combat") return end
  self:Collect()
  ReloadUI()
end

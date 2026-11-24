-- Core/Init.lua
-- First file loaded. Creates the shared namespace every other file receives
-- as the second vararg ("ns"). Nothing here may call game APIs that can be
-- missing on WoW Forever without a guard.

local ADDON, ns = ...

ns.ADDON = ADDON
ns.PREFIX = "Outrider"       -- addon message prefix
ns.SCHEMA = 1                -- Outrider_DB schema version, bump with a migration in DB.lua
ns.build = "dev"             -- overwritten by Core/Build.lua (stamped by tools/deploy.ps1)
ns.session = nil             -- set in Boot.lua, a short id that ties log lines to one load

-- One global handle so Gary/Claude can /dump Outrider.version etc. in game.
-- Other addons must not depend on it until we publish a real API.
_G.Outrider = ns

local function meta(field)
  local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
  if not get then return nil end
  local ok, v = pcall(get, ADDON, field)
  if ok then return v end
end

ns.version = meta("Version") or "0.0.0"

-- Safe call used everywhere: runs fn, records any error, never re-throws.
-- Returns ok, ...results
-- (Closure form because stock Lua 5.1 xpcall takes no extra args; the test
-- runner uses stock 5.1.)
local function onError(where)
  return function(err)
    local trace = debugstack and debugstack(2, 12, 0) or ""
    if ns.Errors then ns.Errors:Record(where, err, trace) end
    return err
  end
end

function ns.Safe(where, fn, ...)
  local n, args = select("#", ...), { ... }
  local results = { xpcall(function() return fn(unpack(args, 1, n)) end, onError(where)) }
  return unpack(results, 1, table.maxn(results))
end

-- Modules load before Core/Slash.lua, so they queue their /ride commands here.
ns.moduleCommands = {}
function ns.AddCommand(name, usage, fn)
  ns.moduleCommands[#ns.moduleCommands + 1] = { name = name, usage = usage, fn = fn }
end

-- Tiny helpers shared by all files

-- "mystmane" -> "Mystmane", "ghost howl" -> "Ghost Howl" (display of typed names).
function ns.TitleCase(s)
  return (tostring(s):gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end))
end
-- How long, in words (premium plan S5): "45 sec", "12 min", "3 h 20 min",
-- "1 day 17 h", "3 days". Never "2459 min" or "1 days".
function ns.Duration(sec)
  sec = math.max(0, math.floor(tonumber(sec) or 0))
  if sec < 60 then return sec .. " sec" end
  local m = math.floor(sec / 60 + 0.5)
  if m < 60 then return m .. " min" end
  local h, rm = math.floor(m / 60), m % 60
  if h < 24 then return rm > 0 and (h .. " h " .. rm .. " min") or (h .. " h") end
  local d, rh = math.floor(h / 24), h % 24
  local days = d == 1 and "1 day" or (d .. " days")
  if d < 7 and rh > 0 then return days .. " " .. rh .. " h" end
  return days
end
-- "just now", "12 min ago", "1 day 17 h ago"
function ns.Ago(sec)
  sec = tonumber(sec) or 0
  if sec < 60 then return "just now" end
  return ns.Duration(sec) .. " ago"
end

function ns.Print(msg, ...)
  if select("#", ...) > 0 then msg = string.format(msg, ...) end
  local line = "|cff8fd1ffOutrider|r " .. tostring(msg)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(line) else print(line) end
end

function ns.CopyTable(src, seen)
  if type(src) ~= "table" then return src end
  seen = seen or {}
  if seen[src] then return seen[src] end
  local out = {}
  seen[src] = out
  for k, v in pairs(src) do out[ns.CopyTable(k, seen)] = ns.CopyTable(v, seen) end
  return out
end

-- Saved values of the wrong type are kept, never just overwritten (owner data
-- preservation override; review OI01-R04). KeepBad(value, path) hands a
-- non-nil value to ns.Archive:KeepDamaged; before the saved data is ready the
-- value waits in ns.damagedPending and Boot flushes it after DB:Init.
-- KeepTable(value, path) returns value when it is a table, else keeps it and
-- returns nil, so `x = type(x) == "table" and x or {}` starts fresh safely.
ns.damagedPending = {}
function ns.KeepBad(value, path)
  if value == nil then return end
  if ns.Archive and ns.db and type(ns.db.global) == "table" then
    ns.Archive:KeepDamaged(path, value)
  else
    ns.damagedPending[#ns.damagedPending + 1] = { path = path, value = value }
  end
end
function ns.KeepTable(value, path)
  if type(value) == "table" then return value end
  ns.KeepBad(value, path)
  return nil
end

-- Fill missing keys in dst from defaults (recursive). Never overwrites.
function ns.ApplyDefaults(dst, defaults)
  if type(defaults) ~= "table" then return dst end
  for k, v in pairs(defaults) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then ns.KeepBad(dst[k], "defaults:" .. tostring(k)) dst[k] = {} end
      ns.ApplyDefaults(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
  return dst
end

function ns.CharKey()
  local name, realm
  if UnitFullName then name, realm = UnitFullName("player") end
  name = name or (UnitName and UnitName("player")) or "Unknown"
  if not realm or realm == "" then realm = (GetRealmName and GetRealmName()) or "Realm" end
  realm = realm:gsub("%s+", "")
  return name .. "-" .. realm
end

function ns.PlayerClass()
  if not UnitClass then return "UNKNOWN" end
  local _, class = UnitClass("player")
  return class or "UNKNOWN"
end

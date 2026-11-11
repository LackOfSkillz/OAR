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

-- Fill missing keys in dst from defaults (recursive). Never overwrites.
function ns.ApplyDefaults(dst, defaults)
  if type(defaults) ~= "table" then return dst end
  for k, v in pairs(defaults) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
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

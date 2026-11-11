-- Core/Compat.lua
-- Every API that differs between Classic-era names and modern C_ namespaces,
-- or may be missing/restricted on WoW Forever, goes through here. A missing
-- API returns nil so the calling feature can switch itself off.
-- Phase 0 task P0-08 (API probe) confirms what really exists; record results
-- in docs/PROBE_RESULTS.md and simplify these shims afterwards.

local _, ns = ...
local C = {}
ns.Compat = C

-- Resolve "C_Map.GetBestMapForUnit" style paths to a function or nil.
function C.Resolve(path)
  local node = _G
  for part in string.gmatch(path, "[^%.]+") do
    if type(node) ~= "table" then return nil end
    node = node[part]
  end
  return node
end

function C.Has(path) return C.Resolve(path) ~= nil end

-- Call an API by path, returning nil on missing function or error.
function C.Call(path, ...)
  local fn = C.Resolve(path)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d, e = pcall(fn, ...)
  if ok then return a, b, c, d, e end
end

-- Secret values (Midnight-era clients): displayable, not computable, in some
-- restricted contexts. Treat a secret as "unknown" in our logic.
function C.IsSecret(v)
  local f = _G.issecretvalue
  if type(f) ~= "function" then return false end
  local ok, res = pcall(f, v)
  return ok and res == true
end

function C.Readable(v)
  if v == nil or C.IsSecret(v) then return nil end
  return v
end

-- Add-on metadata / loaded state
function C.IsAddOnLoaded(name)
  if C_AddOns and C_AddOns.IsAddOnLoaded then
    local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
    return ok and loaded and true or false
  end
  if _G.IsAddOnLoaded then return _G.IsAddOnLoaded(name) and true or false end
  return false
end

function C.LoadAddOn(name)
  local f = (C_AddOns and C_AddOns.LoadAddOn) or _G.LoadAddOn
  if not f then return false end
  local ok, loaded = pcall(f, name)
  return ok and loaded and true or false
end

-- Position: returns mapID, x, y (0..1) or nil. Exact positions are only
-- available for the player and party/raid members.
function C.PlayerPosition(unit)
  unit = unit or "player"
  local mapID = C.Call("C_Map.GetBestMapForUnit", unit)
  if not mapID then return nil end
  local pos = C.Call("C_Map.GetPlayerMapPosition", mapID, unit)
  if not pos then return mapID end
  local ok, x, y = pcall(pos.GetXY, pos)
  if not ok then return mapID end
  return mapID, C.Readable(x), C.Readable(y)
end

-- Bags: modern C_Container first, Classic globals second.
function C.NumSlots(bag)
  return C.Call("C_Container.GetContainerNumSlots", bag) or C.Call("GetContainerNumSlots", bag) or 0
end

function C.ItemLinkAt(bag, slot)
  return C.Call("C_Container.GetContainerItemLink", bag, slot) or C.Call("GetContainerItemLink", bag, slot)
end

function C.ItemCountAt(bag, slot)
  local info = C.Call("C_Container.GetContainerItemInfo", bag, slot)
  if type(info) == "table" then return info.stackCount or 0, info.itemID end
  local _, count = C.Call("GetContainerItemInfo", bag, slot)
  return count or 0
end

function C.ItemInfo(item)
  local get = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
  if not get then return nil end
  local ok, name, link, quality, ilvl, reqLevel, class, subclass, maxStack, equipLoc, icon, sellPrice =
    pcall(get, item)
  if not ok or not name then return nil end
  return {
    name = name, link = link, quality = quality, ilvl = ilvl, reqLevel = reqLevel,
    class = class, subclass = subclass, maxStack = maxStack, equipLoc = equipLoc,
    icon = icon, sellPrice = sellPrice,
  }
end

-- Spells: modern C_Spell returns a table, Classic returns values.
function C.SpellName(spell)
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C.Call("C_Spell.GetSpellInfo", spell)
    if type(info) == "table" then return info.name end
  end
  return (C.Call("GetSpellInfo", spell))
end

-- NPC id from a GUID: "Creature-0-<server>-<instance>-<zoneUID>-<npcID>-<spawnUID>"
-- zoneUID is what LayerTracker-style layer detection uses.
function C.ParseGUID(guid)
  if type(guid) ~= "string" or C.IsSecret(guid) then return nil end
  local kind, _, server, instance, zoneUID, npcID, spawnUID = strsplit("-", guid)
  if kind ~= "Creature" and kind ~= "Vehicle" and kind ~= "Pet" and kind ~= "GameObject" then
    return { kind = kind }
  end
  return {
    kind = kind, server = tonumber(server), instance = tonumber(instance),
    zoneUID = tonumber(zoneUID), id = tonumber(npcID), spawnUID = spawnUID,
  }
end

function C.UnitNpcID(unit)
  local guid = C.Call("UnitGUID", unit)
  local g = C.ParseGUID(guid)
  return g and g.id, g
end

function C.ServerTime()
  return C.Call("GetServerTime") or time()
end

function C.InCombat()
  return _G.InCombatLockdown and InCombatLockdown() or false
end

-- Core/Archive.lua
-- Where collected data goes instead of being deleted (owner retention decision
-- 2026-11-24, docs/blueprint/OWNER_DIRECTIVE_DATA_PRESERVATION.md). Stores that
-- keep a working size (prices, sightings, trails, the quest diary, fishing
-- sessions and others) move their oldest rows here; nothing collected on
-- purpose is thrown away. Logs and debug lists keep their own caps.
--   ns.Archive:Put(key, row)        keep one row
--   ns.Archive:Shift(key, list)     move list[1] here, return it
--   ns.Archive:Rows(key)            the archived rows for this character's key
-- Rows land in ns.db.global.archive["<key>@<character>"], oldest first, unchanged.

local _, ns = ...
local Archive = {}
ns.Archive = Archive

function Archive:Key(key)
  return tostring(key) .. "@" .. tostring(ns.db and ns.db.key or "?")
end

function Archive:Store(key)
  local g = ns.db and ns.db.global
  if not g then return nil end
  if type(g.archive) ~= "table" then g.archive = {} end
  local k = self:Key(key)
  local list = g.archive[k]
  if type(list) ~= "table" then list = {} g.archive[k] = list end
  return list
end

function Archive:Put(key, row)
  if row == nil then return end
  local list = self:Store(key)
  if list then list[#list + 1] = row end
end

function Archive:Shift(key, list)
  local row = table.remove(list, 1)
  self:Put(key, row)
  return row
end

function Archive:Rows(key)
  local g = ns.db and ns.db.global
  return g and type(g.archive) == "table" and g.archive[self:Key(key)] or {}
end

-- total archived rows, for the perf report
function Archive:Count()
  local n = 0
  local g = ns.db and ns.db.global
  for _, list in pairs(g and type(g.archive) == "table" and g.archive or {}) do n = n + #list end
  return n
end

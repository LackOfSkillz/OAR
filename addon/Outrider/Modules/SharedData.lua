-- Modules/SharedData.lua
-- Family installs start with what the owner's Outrider already learned
-- (requirement 2026-11-14: family copies get all the database info
-- transferred). When the Outrider_Data_Shared addon is installed (made by
-- tools/export_shared.lua, packed by tools/family.ps1), its world knowledge
-- is merged into this account's ns.db.global once per export version:
--   * anything this account doesn't have yet is copied in;
--   * nothing it already has is ever overwritten (its own data wins);
--   * lists (nodes, sighting lists, spawn logs) are only copied when this
--     account's own list is still empty, so nothing is doubled.
-- Only world knowledge is in the export: no characters, gold, bags or logs.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("SharedData", {
  title = "Shared knowledge (family installs)",
  phase = "P8",
  order = 2,
  defaults = {},
})
ns.SharedData = M

M.ADDON = "Outrider_Data_Shared"

local function isList(t)
  if type(t) ~= "table" then return false end
  local n = #t
  if n == 0 then return next(t) == nil end
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count == n
end

local function copy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, x in pairs(v) do out[k] = copy(x) end
  return out
end

-- Fill `own` from `shared`; returns how many values were added.
function M.Merge(own, shared)
  local added = 0
  for k, v in pairs(shared) do
    local mine = own[k]
    if mine == nil then
      own[k] = copy(v)
      added = added + 1
    elseif type(mine) == "table" and type(v) == "table" then
      if isList(v) or isList(mine) then
        if next(mine) == nil and next(v) ~= nil then
          own[k] = copy(v)
          added = added + 1
        end
      else
        added = added + M.Merge(mine, v)
      end
    end
  end
  return added
end

function M:Import()
  local data = rawget(_G, "Outrider_DataShared")
  if not data then
    if not C.LoadAddOn(M.ADDON) then return nil end
    data = rawget(_G, "Outrider_DataShared")
  end
  if type(data) ~= "table" or type(data.data) ~= "table" then return nil end
  local g = ns.db.global
  if g.sharedImported == data.version then return 0 end
  local added = 0
  for key, v in pairs(data.data) do
    if type(v) == "table" then
      if type(g[key]) ~= "table" then ns.KeepBad(g[key], "SharedData:g[key]") g[key] = {} end
      added = added + M.Merge(g[key], v)
    end
  end
  g.sharedImported = data.version
  self:Info("shared knowledge %s merged: %d entries added", tostring(data.version), added)
  if added > 0 then ns.Print("loaded the shared Outrider knowledge (%d entries)", added) end
  ns.Events:Fire("OTR_POI_ADDED", nil)
  return added
end

function M:OnInitialize()
  ns.Safe("SharedData:import", self.Import, self)
end

function M:Activity()
  local v = ns.db.global.sharedImported
  return v and ("shared knowledge loaded (" .. tostring(v) .. ")") or "no shared knowledge installed"
end

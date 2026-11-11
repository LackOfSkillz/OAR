-- Modules/GearSets.lua  (P6-09, also the P5-12 fishing outfit)
-- /ride gear save <name>   remember what is worn now (per character)
-- /ride gear <name>        put it back on (out of combat; a typed command is
--                          Gary's key press), item by item with EquipItemByName
-- /ride gear list | delete <name>
-- Items that are no longer in the bags are reported, not hunted down.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("GearSets", {
  title = "Gear sets",
  phase = "P6",
  order = 82,
  defaults = { sets = {} },
})
ns.GearSets = M

function M:Save(name)
  local set = {}
  for slot = 1, 19 do
    local link = C.Call("GetInventoryItemLink", "player", slot)
    if link then set[slot] = link end
  end
  self:Settings().sets[name:lower()] = { name = name, items = set, t = time() }
  self:Info("gear set %s saved", name)
  return set
end

function M:Equip(name)
  if C.InCombat() then return false, "not in combat" end
  local set = self:Settings().sets[name:lower()]
  if not set then return false, "no set called " .. name end
  local equip = C.Resolve("C_Item.EquipItemByName") or rawget(_G, "EquipItemByName")
  if type(equip) ~= "function" then return false, "this client can't equip by name" end
  local changed, missing = 0, {}
  for slot, link in pairs(set.items) do
    local worn = C.Call("GetInventoryItemLink", "player", slot)
    local want = tonumber(link:match("item:(%d+)"))
    if not worn or tonumber(worn:match("item:(%d+)")) ~= want then
      if pcall(equip, link, slot) then changed = changed + 1 else missing[#missing + 1] = link end
    end
  end
  self:Info("gear set %s: %d items changed, %d missing", set.name, changed, #missing)
  return true, changed, missing
end

function M:Activity()
  local names = {}
  for _, s in pairs(self:Settings().sets) do names[#names + 1] = s.name end
  table.sort(names)
  return #names > 0 and ("sets: " .. table.concat(names, ", ")) or "/ride gear save <name> to remember what you wear"
end

ns.AddCommand("gear", "save <name> | <name> | list | delete <name>  gear sets", function(arg)
  arg = arg or "list"
  local cmd, name = arg:match("^(%S+)%s*(.*)$")
  if cmd == "save" and name ~= "" then
    M:Save(name)
    ns.Print("saved gear set '%s'", name)
  elseif cmd == "delete" and name ~= "" then
    M:Settings().sets[name:lower()] = nil
    ns.Print("deleted gear set '%s'", name)
  elseif cmd == "list" then
    ns.Print(M:Activity())
  else
    local ok, changed, missing = M:Equip(arg)
    if not ok then ns.Print(tostring(changed)) return end
    ns.Print("equipped '%s': %d changed%s", arg, changed, #missing > 0 and (", " .. #missing .. " not found") or "")
  end
end)

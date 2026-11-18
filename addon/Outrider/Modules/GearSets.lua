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

-- DEEP-31: visual inventory report; never equips items without a click.
function M:Missing(name)
  local set = self:Settings().sets[tostring(name or ""):lower()]
  if not set then return nil end
  local found, absent = {}, {}
  for slot, link in pairs(set.items) do
    local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
    if id then
      local worn = C.Call("GetInventoryItemLink", "player", slot)
      local equippedID = type(worn) == "string" and tonumber(worn:match("item:(%d+)"))
      local bags = 0
      for b = 0, (rawget(_G, "NUM_BAG_SLOTS") or 4) do
        for k = 1, C.NumSlots(b) do
          local n, bagID = C.ItemCountAt(b, k)
          if bagID == id then bags = bags + (n or 0) end
        end
      end
      local row = { slot = slot, id = id, link = link, equipped = equippedID == id,
        inBags = bags > 0 }
      if row.equipped or row.inBags then found[#found + 1] = row
      else absent[#absent + 1] = row end
    end
  end
  table.sort(found, function(a,b) return a.slot < b.slot end)
  table.sort(absent, function(a,b) return a.slot < b.slot end)
  return { found = found, missing = absent, name = set.name }
end
function M:BuildWindow()
  if self.window then return self.window end
  local f = ns.UI:Window("Outrider_GearSets", "Equipment sets", 530, 385, ns.db.char.gearWindow or {})
  self.window = f
  f.list = ns.UI:ScrollList(f.content, {
    rows = 11, rowHeight = 26,
    render = function(row, set)
      local report = M:Missing(set.name)
      row.text:SetText(string.format("%s  |cffbbbbbb%d items, %d missing|r",
        set.name, report and #report.found + #report.missing or 0,
        report and #report.missing or 0))
    end,
    onClick = function(set)
      local report = M:Missing(set.name)
      if not report then return end
      M.selected = set.name
      local missing = {}
      for _, row in ipairs(report.missing) do missing[#missing + 1] = tostring(row.slot) .. ": item " .. row.id end
      ns.Print("set %s: %d missing: %s", set.name, #missing,
        #missing > 0 and table.concat(missing, ", ") or "none")
    end,
  })
  f.list:SetPoint("TOPLEFT", 4, -10)
  f.list:SetPoint("RIGHT", -4, 0)
  local equip = ns.UI:Button(f.content, "Equip selected", 140, function()
    if not M.selected then return end
    local ok, changed, missing = M:Equip(M.selected)
    ns.Print(ok and string.format("%d item(s) equipped; %d missing", changed, #missing) or tostring(changed))
  end)
  equip:SetPoint("BOTTOMLEFT", 4, 4)
  ns.UI.Tip(equip, "Equip selected set", "Equip only on click, outside combat. Missing items are reported.")
  f:Hide()
  return f
end
function M:RefreshWindow()
  if not self.window then return end
  local sets = {}
  for _, v in pairs(self:Settings().sets) do sets[#sets + 1] = v end
  table.sort(sets, function(a,b) return a.name < b.name end)
  self.window.list:SetItems(sets)
end
ns.AddCommand("gearwindow", "gearwindow  display equipment sets with missing-item report", function()
  local win = M:BuildWindow()
  M:RefreshWindow()
  win:SetShown(not win:IsShown())
end)

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

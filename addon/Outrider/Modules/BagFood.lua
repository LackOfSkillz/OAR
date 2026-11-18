-- Modules/BagFood.lua  (P4-05)
-- Best food and drink in the bags, for the {FOOD} and {DRINK} macro
-- placeholders. An item counts as food or drink by the spell it casts when
-- used ("Food", "Drink", or "Refreshment" for both); among usable ones the
-- highest required level wins, conjured items first (they are free).
-- When an installed library macro's filled text would change (you ate your
-- last stack), it is updated out of combat, at most once every 10 s.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("BagFood", {
  title = "Food and drink in macros",
  phase = "P4",
  order = 63,
  defaults = { autoUpdate = true, prefer = {}, never = {}, fedReminder = true },
})
ns.BagFood = M

local function itemSpell(id)
  local name = C.Call("C_Item.GetItemSpell", id)
  if name == nil then name = C.Call("GetItemSpell", id) end
  return C.Readable(name)
end

-- returns { food = name, drink = name }
function M:Scan()
  local myLevel = C.Call("UnitLevel", "player") or 1
  local best = {}
  local function consider(kind, info)
    local b = best[kind]
    local score = (info.conjured and 1000 or 0) + (info.reqLevel or 0)
    local prefs = self:Settings()
    if prefs.never[info.name:lower()] then return end
    local priority = tonumber(prefs.prefer[info.name:lower()])
    if priority then score = score + 10000 + priority end
    if not b or score > b.score then best[kind] = { name = info.name, score = score } end
  end
  for bag = 0, (rawget(_G, "NUM_BAG_SLOTS") or 4) do
    for slot = 1, C.NumSlots(bag) do
      local _, id = C.ItemCountAt(bag, slot)
      if id then
        local spell = itemSpell(id)
        if spell == "Food" or spell == "Drink" or spell == "Refreshment" then
          local info = C.ItemInfo(id)
          if info and info.name and (info.reqLevel or 0) <= myLevel then
            info.conjured = info.name:find("Conjured", 1, true) ~= nil
            if spell ~= "Drink" then consider("food", info) end
            if spell ~= "Food" then consider("drink", info) end
          end
        end
      end
    end
  end
  self.food = best.food and best.food.name
  self.drink = best.drink and best.drink.name
  return self.food, self.drink
end

function M:OnEnable()
  self:On("BAG_UPDATE_DELAYED", function(mod) mod:Changed() end)
  self:On("PLAYER_ENTERING_WORLD", function(mod) mod:Scan() end)
  self:On("PLAYER_REGEN_ENABLED", function(mod) mod:CheckWellFed() end)
  self:On("UNIT_AURA", function(mod, _, unit)
    if unit == "player" then ns.Throttle("bagfood:fed", 2, function() mod:CheckWellFed() end) end
  end)
  self:On("PLAYER_REGEN_ENABLED", function(mod)
    if mod.pending then ns.Throttle("bagfood", 10, function() M:UpdateMacros() end) end
  end)
end

function M:OnDisable() ns.ThrottleCancel("bagfood") end

function M:Changed()
  local oldFood, oldDrink = self.food, self.drink
  self:Scan()
  if oldFood == self.food and oldDrink == self.drink then return end
  self:Info("best food %s, drink %s", tostring(self.food), tostring(self.drink))
  if not self:Settings().autoUpdate then return end
  if C.InCombat() then self.pending = true return end
  ns.Throttle("bagfood", 10, function() M:UpdateMacros() end)
end

-- Re-install library macros whose filled text changed (only ones Outrider made).
function M:UpdateMacros()
  if C.InCombat() then self.pending = true return end
  self.pending = false
  local L = ns.MacroLibrary
  if not L then return end
  for _, e in ipairs(L:Entries()) do
    if e.body:find("{FOOD}", 1, true) or e.body:find("{DRINK}", 1, true) then
      if L:State(e) == "changed" then
        local ok = L:Install(e)
        self:Info("macro %s %s", e.name, ok and "updated to the new food" or "not updated")
      end
    end
  end
end

-- Never remove or use items automatically: player must press the Blizzard
-- Use/Delete button. Show obsolete consumables as candidates only.
function M:OldFood()
  local entries = {}
  local current = tonumber(C.Readable(C.Call("UnitLevel", "player"))) or 1
  for bag = 0, (rawget(_G, "NUM_BAG_SLOTS") or 4) do
    for slot = 1, C.NumSlots(bag) do
      local _, id = C.ItemCountAt(bag, slot)
      if id then
        local spell = itemSpell(id)
        local info = (spell == "Food" or spell == "Drink" or spell == "Refreshment") and C.ItemInfo(id)
        if info and type(info.reqLevel) == "number" and info.reqLevel <= current - 15 then
          entries[#entries + 1] = { bag = bag, slot = slot, id = id, name = info.name, level = info.reqLevel }
        end
      end
    end
  end
  return entries
end

function M:CheckWellFed()
  if not self:Settings().fedReminder then return end
  local aura = C.Resolve("C_UnitAuras.GetAuraDataByIndex")
  if type(aura) ~= "function" then return end
  local fed = false
  for i = 1, 40 do
    local ok, data = pcall(aura, "player", i, "HELPFUL")
    if not ok or type(data) ~= "table" then break end
    if C.Readable(data.name) == "Well Fed" then fed = true break end
  end
  if fed then self.warnedFed = nil return end
  if not self.warnedFed and self.food and not C.InCombat() then
    self.warnedFed = true
    ns.Print("food reminder: no readable Well Fed aura; eat if your food grants a buff (not all food does).")
  end
end

ns.AddCommand("foodrules", "foodrules prefer|never|allow <food name> | old | list", function(arg)
  arg = tostring(arg or "list")
  local action, name = arg:match("^(%S+)%s*(.*)$")
  local prefs = M:Settings()
  if (action == "prefer" or action == "never" or action == "allow") and name ~= "" then
    local k = name:lower()
    if action == "prefer" then prefs.prefer[k] = 100 prefs.never[k] = nil
    elseif action == "never" then prefs.never[k] = true prefs.prefer[k] = nil
    else prefs.never[k], prefs.prefer[k] = nil, nil end
    M:Changed()
    ns.Print("food rule: %s %s", action, name)
    return
  end
  if action == "old" then
    local list = M:OldFood()
    ns.Print("%d old food stacks (review and delete manually in your bags)", #list)
    for i = 1, math.min(15, #list) do ns.Print("bag %d slot %d: %s", list[i].bag, list[i].slot, list[i].name) end
    return
  end
  local lines = {}
  for k in pairs(prefs.prefer) do lines[#lines + 1] = "prefer: " .. k end
  for k in pairs(prefs.never) do lines[#lines + 1] = "never: " .. k end
  table.sort(lines)
  ns.Print("food rules (%d): %s", #lines, #lines > 0 and table.concat(lines, ", ") or "none")
end)

function M:Activity()
  return string.format("food: %s, drink: %s", tostring(self.food or "none"), tostring(self.drink or "none"))
end

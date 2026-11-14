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
  defaults = { autoUpdate = true },
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

function M:Activity()
  return string.format("food: %s, drink: %s", tostring(self.food or "none"), tostring(self.drink or "none"))
end

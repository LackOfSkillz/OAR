-- Modules/BagSwap.lua  (Gary, 2026-11-20: "when I buy a new bag ... adjust
-- everything around to free up a single bag so I can remove one of the smaller
-- ones and replace it with the bigger one ... one click")
-- One press (/ride bagswap, or the Bag Swap key on the Macros page):
--   1. picks the biggest bag in your bags that beats one you wear;
--   2. picks where it goes: an empty bag slot, else your smallest bag;
--   3. moves that bag's items into free slots of your other bags, one at a
--      time, as the game allows (bag-sort addons and Blizzard's Clean Up move
--      items the same way; moving items isn't a protected action);
--   4. puts the new bag in; the old one lands where the new one was.
-- Out of combat only; it stops if a fight starts. Never sells, deletes or
-- drops anything. If your other bags lack room, it says how much is missing.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("BagSwap", {
  title = "Bag swap: a bigger bag in with one press",
  phase = "P4",
  order = 66,
  defaults = {},
})
ns.BagSwap = M

M.CONTAINER, M.GENERAL = 1, 0
M.STEP, M.MAX_STEPS = 0.2, 60

local function slots(bag) return C.NumSlots(bag) or 0 end
local function itemAt(bag, slot)
  local info = C.Call("C_Container.GetContainerItemInfo", bag, slot)
  if type(info) == "table" then return C.Readable(info.itemID), C.Readable(info.isLocked) end
  local link = C.ItemLinkAt(bag, slot)
  return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil, false
end
local function family(bag)
  if bag == 0 then return 0 end
  local _, fam = C.Call("C_Container.GetContainerNumFreeSlots", bag)
  return tonumber(C.Readable(fam)) or 0
end
local function inv(bag)
  return C.Call("C_Container.ContainerIDToInventoryID", bag) or (19 + bag)
end

-- Is this item a general bag, and how many slots? (profession bags and quivers stay out)
function M.BagSize(itemID)
  local get = C.Resolve("C_Item.GetItemInfoInstant") or rawget(_G, "GetItemInfoInstant")
  if type(get) ~= "function" then return nil end
  local ok, _, _, _, _, _, class, sub = pcall(get, itemID)
  if not ok or class ~= M.CONTAINER or (sub or 0) ~= M.GENERAL then return nil end
  return ns.GearShop and ns.GearShop.BagSlotsOf(itemID) or nil
end

-- What to do now: { newBag = {bag, slot, itemID, size, name}, target = bagID, targetSize, items = n, free = n } or nil, why
function M:Plan()
  local best
  for bag = 0, 4 do
    for slot = 1, slots(bag) do
      local id = itemAt(bag, slot)
      local size = id and M.BagSize(id)
      if size and (not best or size > best.size) then
        local info = C.ItemInfo(id)
        best = { bag = bag, slot = slot, itemID = id, size = size, name = info and info.name or ("bag " .. id) }
      end
    end
  end
  if not best then return nil, "no spare bag in your bags" end
  -- where it goes: an empty bag slot first, else the smallest bag that holds anything
  local target, tsize
  for bag = 1, 4 do
    local n = slots(bag)
    if n == 0 then target, tsize = bag, 0 break end
    if family(bag) == 0 and n < best.size and (not tsize or n < tsize) then target, tsize = bag, n end
  end
  if not target then return nil, string.format("%s (%d slots) isn't bigger than any bag you wear", best.name, best.size) end
  local items, free = 0, 0
  for slot = 1, slots(target) do if itemAt(target, slot) then items = items + 1 end end
  for bag = 0, 4 do
    if bag ~= target and slots(bag) > 0 and family(bag) == 0 then
      for slot = 1, slots(bag) do if not itemAt(bag, slot) then free = free + 1 end end
    end
  end
  return { newBag = best, target = target, targetSize = tsize, items = items, free = free }
end

-- One press.
function M:Run()
  if self.job then ns.Print("bag swap: already on it") return false end
  if C.InCombat() then ns.Print("bag swap: not in a fight") return false end
  local plan, why = self:Plan()
  if not plan then ns.Print("bag swap: %s", why) return false end
  -- the new bag sitting in the bag being emptied moves too, and needs a slot itself
  if plan.items > plan.free then
    ns.Print("bag swap: your other bags need %d more free slot%s first (the Vendor key sells grey junk)",
      plan.items - plan.free, plan.items - plan.free == 1 and "" or "s")
    return false
  end
  self.job = { plan = plan, steps = 0, itemID = plan.newBag.itemID }
  self:Info("bag swap: %s (%d) into bag %d (%d slots, %d items to move, %d free elsewhere)", plan.newBag.name,
    plan.newBag.size, plan.target, plan.targetSize, plan.items, plan.free)
  self:Step()
  return true
end

local function stop(self, msg, ...)
  self.job = nil
  if C.Call("CursorHasItem") then pcall(ClearCursor) end
  if msg then ns.Print("bag swap: " .. msg, ...) end
end

-- One move at a time; the state is read fresh each step, so a slow or
-- refused move just gets tried again.
function M:Step()
  local job = self.job
  if not job then return end
  if C.InCombat() then return stop(self, "stopped: a fight started") end
  job.steps = job.steps + 1
  if job.steps > M.MAX_STEPS then return stop(self, "stopped: the game didn't let the items move") end
  local target = job.plan.target
  local again = function() ns.Timer.After(M.STEP, function() M:Step() end, "bagswap:step") end
  if C.Call("CursorHasItem") then pcall(ClearCursor) return again() end
  -- next item still in the bag being emptied
  local from
  for slot = 1, slots(target) do
    local id, locked = itemAt(target, slot)
    if id then
      if locked then return again() end
      from = slot
      break
    end
  end
  if from then
    local to
    for bag = 0, 4 do
      if bag ~= target and slots(bag) > 0 and family(bag) == 0 then
        for slot = 1, slots(bag) do if not itemAt(bag, slot) then to = { bag, slot } break end end
      end
      if to then break end
    end
    if not to then return stop(self, "stopped: no free slot left in your other bags") end
    C.Call("C_Container.PickupContainerItem", target, from)
    C.Call("C_Container.PickupContainerItem", to[1], to[2])
    return again()
  end
  -- empty: put the new bag in (the old one swaps to where the new one was)
  local nb
  for bag = 0, 4 do
    if bag ~= target then
      for slot = 1, slots(bag) do
        local id, locked = itemAt(bag, slot)
        if id == job.itemID then nb = { bag, slot, locked } break end
      end
    end
    if nb then break end
  end
  if not nb then return stop(self, "stopped: the new bag isn't in your bags any more") end
  if nb[3] then return again() end
  C.Call("C_Container.PickupContainerItem", nb[1], nb[2])
  C.Call("PutItemInBag", inv(target))
  local plan = job.plan
  self.job = nil
  ns.Timer.After(0.5, function()
    if slots(target) == plan.newBag.size then
      M:Info("bag swap done: %s in bag %d", plan.newBag.name, target)
      ns.Print("bag swap: %s (%d slots) is in%s", plan.newBag.name, plan.newBag.size,
        plan.targetSize > 0 and string.format("; your %d-slot bag is in your bags now", plan.targetSize) or "")
    else
      if C.Call("CursorHasItem") then pcall(ClearCursor) end
      M:Warn("bag swap: the bag didn't go in (bag %d still %d slots)", target, slots(target))
      ns.Print("bag swap: the game didn't take the bag; press again")
    end
  end, "bagswap:check")
end

-- Once a session, when a bigger bag shows up in your bags.
function M:Check()
  if self.told or self.job then return end
  local plan = self:Plan()
  if plan then
    self.told = true
    ns.Print("%s (%d slots) beats a bag you wear: press the Bag Swap key or type /ride bagswap and Outrider moves things and puts it in",
      plan.newBag.name, plan.newBag.size)
  end
end

function M:OnEnable()
  self:On("BAG_UPDATE_DELAYED", function(mod)
    if not C.InCombat() then ns.Throttle("bagswap:check", 2, function() M:Check() end) end
  end)
  self:On("PLAYER_REGEN_DISABLED", function(mod) if mod.job then stop(mod, "stopped: a fight started") end end)
end

function M:OnDisable() self.job = nil end

function M:Activity()
  local plan = self:Plan()
  return plan and string.format("%s (%d slots) could go in bag %d", plan.newBag.name, plan.newBag.size, plan.target)
    or "no bigger bag waiting"
end

ns.AddCommand("bagswap", "put the biggest spare bag in your bags in place of your smallest (moves the items for you)", function()
  M:Run()
end)

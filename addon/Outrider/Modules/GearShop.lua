-- Modules/GearShop.lua
-- Gear upgrades from the auction house (requirement 2026-11-14: search weapons
-- and armor for the best piece in each category, within the gold on hand,
-- character aware (no mail for a priest, no cloth for a hunter), bought with
-- the player's click).
-- With the auction house open:
--   * Search weapons: weapons this class can use, required level from
--     (level - 10) to its level; the top 10 upgrades you can afford.
--   * Search armor: every armor slot, only this class's own armor type
--     (cloaks, rings, necks and trinkets are open to all); the best upgrade
--     per slot you can afford.
-- Scores are the gear advisor's (GearScore:Compare, class stat weights, the
-- verdict the tooltips show) against what is worn. Items costing more than
-- the gold carried are left out. Each line has a Buy button: AHBuy looks up
-- the cheapest listing and its confirm bar buys it on Gary's click.
-- Random-suffix items ("of the Monkey") are scored on their base item.
--   * Search bags (requirement 2026-11-16: scan for bags too): bags bigger
--     than the smallest one you carry, ranked by slots gained; hunters also
--     get quivers or ammo pouches for the weapon they shoot; profession bags
--     only for a profession you have. Slots come from the item tooltip
--     ("16 Slot Bag"); your bags from the container API (an empty bag slot
--     counts as 0).

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local M = ns:NewModule("GearShop", {
  title = "Gear upgrades at the auction house",
  phase = "P6",
  order = 82,
  defaults = {},
})
ns.GearShop = M

M.ARMOR, M.WEAPON = 4, 2
-- Enum.InventoryType values for the armor slots searched one by one
M.INVTYPES = { { 1, "Head" }, { 2, "Neck" }, { 3, "Shoulder" }, { 16, "Back" }, { 5, "Chest" }, { 20, "Chest (robe)" },
  { 9, "Wrist" }, { 10, "Hands" }, { 6, "Waist" }, { 7, "Legs" }, { 8, "Feet" }, { 11, "Ring" }, { 12, "Trinket" },
  { 14, "Shield" }, { 23, "Off-hand" } }
-- slots any class wears whatever their material (cloaks are cloth for everyone)
M.ANY_MATERIAL = { INVTYPE_CLOAK = true, INVTYPE_NECK = true, INVTYPE_FINGER = true, INVTYPE_TRINKET = true,
  INVTYPE_HOLDABLE = true, INVTYPE_SHIELD = true }
M.LEVELS_BACK, M.WAIT, M.TOP = 10, 4, 10
M.CONTAINER, M.QUIVER = 1, 11 -- item classes (Enum.ItemClass)
-- container subclasses (Enum.ItemContainerSubclass / Enum.ItemQuiverSubclass):
-- who may use them and what they are called
M.BAG_KINDS = {
  [M.CONTAINER] = { [0] = { name = "Bag" }, [1] = { name = "Soul bag", class = "WARLOCK" },
    [2] = { name = "Herb bag", prof = "Herbalism" }, [3] = { name = "Enchanting bag", prof = "Enchanting" },
    [4] = { name = "Engineering bag", prof = "Engineering" }, [6] = { name = "Mining bag", prof = "Mining" },
    [7] = { name = "Leatherworking bag", prof = "Leatherworking" } },
  [M.QUIVER] = { [2] = { name = "Quiver", class = "HUNTER", ammo = "arrows" },
    [3] = { name = "Ammo pouch", class = "HUNTER", ammo = "bullets" } },
}

function M:Queries(mode)
  local level = C.Call("UnitLevel", "player") or 1
  local lo = math.max(1, level - M.LEVELS_BACK)
  local q = {}
  if mode == "bags" then
    q[1] = { text = "Bags", filters = { { classID = M.CONTAINER } } }
    if M.PlayerClass() == "HUNTER" then q[2] = { text = "Quivers", filters = { { classID = M.QUIVER } } } end
    return q
  end
  if mode == "weapons" then
    q[1] = { text = "Weapons", minLevel = lo, maxLevel = level, filters = { { classID = M.WEAPON } } }
  else
    for _, t in ipairs(M.INVTYPES) do
      q[#q + 1] = { text = t[2], minLevel = lo, maxLevel = level, filters = { { classID = M.ARMOR, inventoryType = t[1] } } }
    end
  end
  return q
end

-- ------------------------------------------------------------ searching
function M:Start(mode)
  if not self.open then ns.Print("open the auction house first") return end
  self.mode = mode
  self.queue, self.pos, self.found = self:Queries(mode), 0, {}
  self.manual = false
  self:Info("gear search %s: %d searches", mode, #self.queue)
  self:Next()
end

function M:Next()
  if not self.queue then return end
  self.pos = self.pos + 1
  local e = self.queue[self.pos]
  if not e then self.waiting = nil self:Done() return end
  local query = { searchString = "", sorts = { { sortOrder = 0, reverseSort = false } }, filters = {},
    itemClassFilters = e.filters, minLevel = e.minLevel, maxLevel = e.maxLevel }
  local ok = pcall(C_AuctionHouse.SendBrowseQuery, query)
  self.waiting = e
  self:Debug("gear search %s (%s)", e.text, ok and "sent" or "failed")
  ns.Timer.After(M.WAIT, function()
    if M.waiting == e then
      M.waiting, M.manual = nil, true
      M:Info("gear search %s got no answer: one search per click from here", e.text)
      M:Refresh()
    end
  end, "gearshop:wait")
  self:Refresh()
end

function M:OnResults()
  if not self.waiting then return end
  local results = C.Call("C_AuctionHouse.GetBrowseResults")
  if type(results) ~= "table" then return end
  self.waiting = nil
  for _, r in ipairs(results) do
    local key = r.itemKey
    local price = C.Readable(r.minPrice)
    if key and key.itemID and type(price) == "number" and not self.found[key.itemID] then
      self.found[key.itemID] = { itemKey = key, price = price }
      if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, key.itemID) end
    end
  end
  if self.manual then self:Refresh() else self:Next() end
end

function M:Done()
  self.queue = nil
  local n = 0
  for _ in pairs(self.found) do n = n + 1 end
  local list, skipped = self:Results()
  self:Info("gear search %s done: %d items, %d to show, %d over your gold", tostring(self.mode), n, #list, skipped)
  self:Refresh()
end

-- ------------------------------------------------------------ ranking

-- Files: GearShop.lua (module, auction queries, lifecycle), GearShopRank.lua (ranking),
-- GearShopView.lua (window, cart and rendering).

function M:OnEnable()
  self:On("AUCTION_HOUSE_SHOW", function(mod) mod.open = true mod:Refresh() end)
  self:On("AUCTION_HOUSE_CLOSED", function(mod)
    mod.open, mod.queue, mod.waiting = false, nil, nil
    if mod.frame then mod.frame:Hide() end
  end)
  self:On("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", self.OnResults)
  self:On("PLAYER_MONEY", function(mod) if mod.open then mod:Refresh() end end)
  self:On("OTR_PRICES_SCAN", function(mod) if mod.open then mod:Refresh() end end)
  self:On("GET_ITEM_INFO_RECEIVED", function(mod)
    if mod.open and mod.found and not mod.queue then ns.Throttle("gearshop:refresh", 1, function() M:Refresh() end) end
  end)
end

function M:OnDisable() if self.frame then self.frame:Hide() end end

function M:Activity()
  return "open the auction house: Weapons / Armor / Bags"
end

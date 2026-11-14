-- Modules/GearShop.lua
-- Gear upgrades from the auction house (Gary, 2026-11-14: "search for armor
-- and weapons, compare against what I have, recommend the best piece for each
-- slot ... check a box for the ones I want and click buy").
-- With the auction house open, one click on "Find gear upgrades":
--   * searches each gear slot (armor by slot, then weapons) for items this
--     character can use, required level from (level - 10) to its level;
--   * scores every result with the gear advisor (GearScore:Compare, the same
--     verdict the tooltips show) against what is worn;
--   * keeps the best upgrade per slot, with its price.
-- Buying: tick the ones you want, then "Buy checked". Blizzard allows one
-- purchase per click, so the button steps through them: one click looks up
-- the cheapest listing, the next shows "Confirm: buy <item> for <price>" and
-- buys it. Every purchase is Gary's click with the price on the button.
-- Random-suffix items ("of the Monkey") are scored on their base item.

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
M.LEVELS_BACK = 10
M.WAIT = 4

function M:Queries()
  local level = C.Call("UnitLevel", "player") or 1
  local lo = math.max(1, level - M.LEVELS_BACK)
  local q = {}
  for _, t in ipairs(M.INVTYPES) do
    q[#q + 1] = { text = t[2], minLevel = lo, maxLevel = level,
      filters = { { classID = M.ARMOR, inventoryType = t[1] } } }
  end
  q[#q + 1] = { text = "Weapons", minLevel = lo, maxLevel = level, filters = { { classID = M.WEAPON } } }
  return q
end

-- ------------------------------------------------------------ searching
function M:Start()
  if not self.open then ns.Print("open the auction house first") return end
  self.queue, self.pos, self.found, self.picked = self:Queries(), 0, {}, {}
  self.manual = false
  self:Info("gear search: %d slots", #self.queue)
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
  local best = self:Best()
  self:Info("gear search done: %d items found, upgrades for %d slots", n, #best)
  self:Refresh()
end

-- ------------------------------------------------------------ ranking
-- Best upgrade per slot: { {slot, slotName, itemID, itemKey, price, pct, text} }, slot order
function M:Best()
  local G = ns.GearScore
  if not G then return {} end
  local per = {}
  for itemID, f in pairs(self.found or {}) do
    local link = "item:" .. itemID
    local r = G:Compare(link)
    if r and not r.why and (r.pct >= 1 or (r.empty and r.new > 0)) then
      local cur = per[r.slot]
      local better = not cur or r.pct > cur.pct or (r.pct == cur.pct and f.price < cur.price)
      if better then
        local info = C.ItemInfo(link)
        per[r.slot] = { slot = r.slot, slotName = G.SLOT_NAMES[r.slot] or tostring(r.slot), itemID = itemID,
          itemKey = f.itemKey, price = f.price, pct = r.pct, empty = r.empty, capped = r.capped,
          name = info and info.name or ("item " .. itemID) }
      end
    end
  end
  local out = {}
  for _, b in pairs(per) do out[#out + 1] = b end
  table.sort(out, function(a, b) return a.slot < b.slot end)
  return out
end

function M.Gain(b)
  if b.empty then return "empty slot" end
  if b.capped then return "big upgrade" end
  return string.format("+%d%%", math.floor(b.pct + 0.5))
end

-- ------------------------------------------------------------ buying
function M:Picked()
  local out, total = {}, 0
  for _, b in ipairs(self:Best()) do
    if self.picked and self.picked[b.itemID] then out[#out + 1] = b total = total + b.price end
  end
  return out, total
end

-- One step per click: look up the cheapest listing, then confirm-and-buy it.
function M:BuyClick()
  if not self.open then return end
  local b = self.buying
  if not b then
    local list = self:Picked()
    if #list == 0 then ns.Print("tick the upgrades you want first") return end
    self.buying = { list = list, i = 1 }
    b = self.buying
  end
  local item = b.list[b.i]
  if not item then self.buying = nil self:Refresh() return end
  if b.auction then
    local a = b.auction
    local ok, err = pcall(C_AuctionHouse.PlaceBid, a.auctionID, a.price)
    self:Info("buy %s for %s: %s", item.name, ns.Prices.Money(a.price), ok and "sent" or tostring(err))
    if ok then self.picked[item.itemID] = nil end
    b.auction = nil
    b.i = b.i + 1
    if not b.list[b.i] then self.buying = nil end
    self:Refresh()
    return
  end
  b.looking = item
  pcall(C_AuctionHouse.SendSearchQuery, item.itemKey, { { sortOrder = 0, reverseSort = false } }, false)
  self:Refresh()
end

-- The listings for the item being bought: take the cheapest buyout.
function M:OnItemResults()
  local b = self.buying
  local item = b and b.looking
  if not item then return end
  local n = C.Call("C_AuctionHouse.GetNumItemSearchResults", item.itemKey) or 0
  local best
  for i = 1, n do
    local r = C.Call("C_AuctionHouse.GetItemSearchResultInfo", item.itemKey, i)
    local price = type(r) == "table" and C.Readable(r.buyoutAmount)
    if type(price) == "number" and not r.containsOwnerItem and (not best or price < best.price) then
      best = { auctionID = r.auctionID, price = price }
    end
  end
  b.looking = nil
  if best then
    b.auction = best
  else
    ns.Print("%s: no buyout listing left, skipped", item.name)
    b.i = b.i + 1
    if not b.list[b.i] then self.buying = nil end
  end
  self:Refresh()
end

-- ------------------------------------------------------------ panel
M.ROWS = 16
function M:Build()
  if self.frame then return self.frame end
  local anchor = rawget(_G, "AuctionHouseFrame") or UIParent
  local f = CreateFrame("Frame", "Outrider_GearShop", anchor, ns.Theme:BackdropTemplate())
  ns.Theme:ApplyPanel(f, "panel")
  f:SetSize(440, 120)
  f:SetFrameStrata("HIGH")
  f:SetClampedToScreen(true)
  local pt = self:Settings().point
  if type(pt) == "table" then f:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4])
  else f:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -6, 0) end
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(fr) fr:StartMoving() end)
  f:SetScript("OnDragStop", function(fr)
    fr:StopMovingOrSizing()
    local a, _, b, x, y = fr:GetPoint()
    M:Settings().point = { a, b, x, y }
  end)
  f.title = UI.Text(f, "normal", "accent")
  f.title:SetPoint("TOPLEFT", 8, -8)
  f.title:SetText("Gear upgrades  |cff888888(drag to move)|r")
  f.find = UI:Button(f, "Find gear upgrades", 160, function()
    if M.queue and M.manual then M:Next() else M:Start() end
  end)
  f.find:SetPoint("TOPRIGHT", -8, -6)
  f.status = UI.Text(f, "small", "muted")
  f.status:SetPoint("TOPLEFT", 8, -34)
  f.status:SetWidth(424)
  f.status:SetJustifyH("LEFT")
  f.rows = {}
  for i = 1, M.ROWS do
    local row = UI:Check(f, "", function() local r = f.rows[i] local b = r and r.item return b and M.picked and M.picked[b.itemID] or false end,
      function(on)
        local b = f.rows[i] and f.rows[i].item
        if b then M.picked = M.picked or {} M.picked[b.itemID] = on or nil end
        M:Refresh()
      end)
    row:SetWidth(424)
    row:SetPoint("TOPLEFT", 8, -52 - (i - 1) * 22)
    row:Hide()
    f.rows[i] = row
  end
  f.buy = UI:Button(f, "Buy checked", 260, function() M:BuyClick() end)
  f.buy:Hide()
  f:Hide()
  self.frame = f
  return f
end

function M:Refresh()
  if not self.open then return end
  local f = self:Build()
  local best = (self.found and not self.queue) and self:Best() or {}
  for i = 1, M.ROWS do
    local row, b = f.rows[i], best[i]
    row.item = b
    if b then
      row.label:SetText(string.format("%s: %s  %s  |cffffd100%s|r", ns.TitleCase(b.slotName), b.name, M.Gain(b), ns.Prices.Money(b.price)))
      row:Refresh()
      row:Show()
    else
      row:Hide()
    end
  end
  local h = 56 + #best * 22
  if self.queue then
    local e = self.queue[self.pos]
    f.find.label:SetText(self.manual and string.format("Search next (%d/%d)", self.pos, #self.queue) or "Searching...")
    f.status:SetText(string.format("Searching: %s (%d of %d)", e and e.text or "...", self.pos, #self.queue))
  elseif self.found then
    f.find.label:SetText("Search again")
    f.status:SetText(#best > 0 and "Best upgrade per slot (tick the ones you want):" or "No upgrades for sale in your level range right now.")
  else
    f.find.label:SetText("Find gear upgrades")
    f.status:SetText("Searches every slot for gear you can use and finds the best upgrade for each. Buying is your click, one item at a time.")
  end
  local list, total = self:Picked()
  local b = self.buying
  if b and b.list[b.i] then
    local item = b.list[b.i]
    if b.auction then
      f.buy.label:SetText(string.format("Confirm: buy %s for %s", item.name, ns.Prices.Money(b.auction.price)))
    elseif b.looking then
      f.buy.label:SetText("Looking up " .. item.name .. "...")
    else
      f.buy.label:SetText(string.format("Buy next (%d of %d): %s", b.i, #b.list, item.name))
    end
    f.buy:Show()
  elseif #list > 0 then
    f.buy.label:SetText(string.format("Buy checked (%d, about %s)", #list, ns.Prices.Money(total)))
    f.buy:Show()
  else
    f.buy:Hide()
  end
  if f.buy:IsShown() then
    f.buy:ClearAllPoints()
    f.buy:SetPoint("TOPLEFT", 8, -h)
    h = h + 30
  end
  f:SetHeight(h + 8)
  f:Show()
end

function M:OnEnable()
  self:On("AUCTION_HOUSE_SHOW", function(mod) mod.open = true mod:Refresh() end)
  self:On("AUCTION_HOUSE_CLOSED", function(mod)
    mod.open, mod.queue, mod.waiting, mod.buying = false, nil, nil, nil
    if mod.frame then mod.frame:Hide() end
  end)
  self:On("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", self.OnResults)
  self:On("ITEM_SEARCH_RESULTS_UPDATED", self.OnItemResults)
  self:On("GET_ITEM_INFO_RECEIVED", function(mod)
    if mod.open and mod.found and not mod.queue then ns.Throttle("gearshop:refresh", 1, function() M:Refresh() end) end
  end)
end

function M:OnDisable() if self.frame then self.frame:Hide() end end

function M:Activity()
  return "open the auction house: Find gear upgrades"
end

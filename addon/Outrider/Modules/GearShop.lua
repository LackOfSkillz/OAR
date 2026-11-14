-- Modules/GearShop.lua
-- Gear upgrades from the auction house (Gary, 2026-11-14: "search for weapons
-- ... search for armor, the best piece in each category ... aware of how much
-- coin I have ... character aware: no mail for a priest, no cloth for a
-- hunter ... I click buy").
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

function M:Queries(mode)
  local level = C.Call("UnitLevel", "player") or 1
  local lo = math.max(1, level - M.LEVELS_BACK)
  local q = {}
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
local function instant(itemID)
  local get = C.Resolve("C_Item.GetItemInfoInstant") or rawget(_G, "GetItemInfoInstant")
  if type(get) ~= "function" then return nil end
  local ok, _, _, _, equipLoc, _, class, subclass = pcall(get, itemID)
  if ok then return equipLoc, class, subclass end
end

-- Is this item for this character at all (beyond GearScore's own checks)?
function M:Fits(itemID)
  local equipLoc, class, subclass = instant(itemID)
  if class == M.WEAPON and subclass == 20 then return false end -- fishing poles are not weapons
  if class == M.ARMOR and subclass and subclass >= 1 and subclass <= 4 and not M.ANY_MATERIAL[equipLoc or ""] then
    local want = ns.GearScore and ns.GearScore.ArmorType()
    if want and subclass ~= want then return false end
  end
  return true
end

-- Upgrades you can afford: weapons the top 10 by gain; armor the best per slot.
-- Returns list, skippedForGold.
function M:Results()
  local G = ns.GearScore
  if not G or not self.found then return {}, 0 end
  local money = ns.AHBuy and ns.AHBuy.Money() or 0
  local all, skipped = {}, 0
  for itemID, f in pairs(self.found) do
    local link = "item:" .. itemID
    local r = self:Fits(itemID) and G:Compare(link)
    local learn = r and type(r.why) == "string" and r.why:find("^learn ") and r.why or nil
    if r and (not r.why or learn) and (r.pct >= 1 or (r.empty and r.new > 0)) then
      if f.price > money then skipped = skipped + 1
      else
        local info = C.ItemInfo(link)
        all[#all + 1] = { slot = r.slot, slotName = G.SLOT_NAMES[r.slot] or tostring(r.slot), itemID = itemID,
          itemKey = f.itemKey, price = f.price, pct = r.empty and 999 or r.pct, empty = r.empty, capped = r.capped,
          name = info and info.name or ("item " .. itemID), learn = learn }
      end
    end
  end
  -- weapons you can use now first, then ones needing a weapon skill you haven't learned
  table.sort(all, function(a, b)
    if (a.learn == nil) ~= (b.learn == nil) then return a.learn == nil end
    if a.pct ~= b.pct then return a.pct > b.pct end
    return a.price < b.price
  end)
  if self.mode == "weapons" then
    local out = {}
    for i = 1, math.min(M.TOP, #all) do out[i] = all[i] end
    return out, skipped
  end
  local per, out = {}, {}
  for _, b in ipairs(all) do if not per[b.slot] then per[b.slot] = b out[#out + 1] = b end end
  table.sort(out, function(a, b) return a.slot < b.slot end)
  return out, skipped
end

function M.Gain(b)
  if b.learn then return string.format("|cffffc84d%s first|r", b.learn) end
  if b.empty then return "empty slot" end
  if b.capped then return "big upgrade" end
  return string.format("+%d%%", math.floor(b.pct + 0.5))
end

-- ------------------------------------------------------------ panel
M.ROWS = 15
function M:Build()
  if self.frame then return self.frame end
  local anchor = rawget(_G, "AuctionHouseFrame") or UIParent
  local f = CreateFrame("Frame", "Outrider_GearShop", anchor, ns.Theme:BackdropTemplate())
  ns.Theme:ApplyPanel(f, "panel")
  f:SetSize(460, 120)
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
  -- one shopping panel (Gary, 2026-11-14: "these should be one panel, not 2"):
  -- Training (TrainShop's list, drawn inside this panel), Weapons, Armor
  f.title:SetText("Outrider shopping  |cff888888(drag)|r")
  f.training = UI:Button(f, "Training", 96, function()
    M.mode = "training"
    if ns.TrainShop then
      local T = ns.TrainShop
      if T.queue and T.manual then T:Next() else T:Start() end
    end
    M:Refresh()
  end)
  f.training:SetPoint("TOPRIGHT", -216, -6)
  f.weapons = UI:Button(f, "Weapons", 96, function()
    if M.queue and M.manual then M:Next() else M:Start("weapons") end
  end)
  f.weapons:SetPoint("TOPRIGHT", -112, -6)
  f.armor = UI:Button(f, "Armor", 96, function()
    if M.queue and M.manual then M:Next() else M:Start("armor") end
  end)
  f.armor:SetPoint("TOPRIGHT", -8, -6)
  f.status = UI.Text(f, "small", "muted")
  f.status:SetPoint("TOPLEFT", 8, -36)
  f.status:SetWidth(444)
  f.status:SetJustifyH("LEFT")
  f.rows = {}
  for i = 1, M.ROWS do
    local row = CreateFrame("Frame", nil, f)
    row:SetSize(444, 22)
    row:SetPoint("TOPLEFT", 8, -54 - (i - 1) * 24)
    row.text = UI.Text(row, "normal", "text")
    row.text:SetPoint("LEFT", 0, 0)
    row.text:SetWidth(380)
    row.text:SetJustifyH("LEFT")
    row.buy = UI:Button(row, "Buy", 56, function()
      local b = row.item
      if b and ns.AHBuy then ns.AHBuy:Add({ name = b.name, itemKey = b.itemKey }) end
    end)
    row.buy:SetPoint("RIGHT", 0, 0)
    row:Hide()
    f.rows[i] = row
  end
  f:Hide()
  self.frame = f
  return f
end

-- Height for the training view (its list lives in TrainShop's frame inside this one).
function M:Resize()
  local f = self.frame
  if not f then return end
  local t = ns.TrainShop and ns.TrainShop.frame
  if self.mode == "training" and t then f:SetHeight(40 + (t:GetHeight() or 100)) end
end

function M:Refresh()
  if not self.open then return end
  local f = self:Build()
  local training = self.mode == "training" or not self.mode
  local t = ns.TrainShop and ns.TrainShop.frame
  if t then t:SetShown(training) end
  f.status:SetShown(not training)
  if training then
    for _, row in ipairs(f.rows) do row:Hide() end
    f.weapons.label:SetText("Weapons")
    f.armor.label:SetText("Armor")
    f:Show()
    self:Resize()
    return
  end
  local list = (self.found and not self.queue) and (self:Results()) or {}
  local _, skipped = self:Results()
  for i = 1, M.ROWS do
    local row, b = f.rows[i], list[i]
    row.item = b
    if b then
      local label = self.mode == "weapons" and (i .. ". ") or (ns.TitleCase(b.slotName) .. ": ")
      row.text:SetText(string.format("%s%s  |cff7fff7f%s|r  |cffffd100%s|r", label, b.name, M.Gain(b), ns.Prices.Money(b.price)))
      row:Show()
    else
      row:Hide()
    end
  end
  local gold = ns.Prices.Money(ns.AHBuy and ns.AHBuy.Money() or 0)
  if self.queue then
    local e = self.queue[self.pos]
    local label = self.manual and string.format("Search next (%d/%d)", self.pos, #self.queue) or "Searching..."
    f.weapons.label:SetText(self.mode == "weapons" and label or "Weapons")
    f.armor.label:SetText(self.mode == "armor" and label or "Armor")
    f.status:SetText(string.format("Searching: %s (%d of %d)", e and e.text or "...", self.pos, #self.queue))
  else
    f.weapons.label:SetText("Weapons")
    f.armor.label:SetText("Armor")
    if self.found then
      local head = self.mode == "weapons" and "Top weapons you can afford" or "Best armor per slot you can afford"
      f.status:SetText(string.format("%s (you have %s)%s:", head, gold,
        skipped > 0 and string.format("; %d better ones cost more", skipped) or "")
        .. (#list == 0 and "\nNothing better for sale in your level range right now." or ""))
    else
      f.status:SetText("Finds upgrades your class can use, in your level range, that your gold covers (" .. gold .. "). Buy is your click.")
    end
  end
  f:SetHeight(62 + #list * 24 + (#list == 0 and 14 or 0))
  f:Show()
end

function M:OnEnable()
  self:On("AUCTION_HOUSE_SHOW", function(mod) mod.open = true mod:Refresh() end)
  self:On("AUCTION_HOUSE_CLOSED", function(mod)
    mod.open, mod.queue, mod.waiting = false, nil, nil
    if mod.frame then mod.frame:Hide() end
  end)
  self:On("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", self.OnResults)
  self:On("PLAYER_MONEY", function(mod) if mod.open then mod:Refresh() end end)
  self:On("GET_ITEM_INFO_RECEIVED", function(mod)
    if mod.open and mod.found and not mod.queue then ns.Throttle("gearshop:refresh", 1, function() M:Refresh() end) end
  end)
end

function M:OnDisable() if self.frame then self.frame:Hide() end end

function M:Activity()
  return "open the auction house: Search weapons / Search armor"
end

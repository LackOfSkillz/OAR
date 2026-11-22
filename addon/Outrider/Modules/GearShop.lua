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
--   * Search bags (Gary, 2026-11-16: "scan for bags as well"): bags bigger
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

function M.PlayerClass()
  local _, token = C.Call("UnitClass", "player")
  return token
end

-- Slots a bag has, from its tooltip ("16 Slot Bag"); nil until the item is loaded.
function M.BagSlotsOf(itemID)
  local tip = C.Call("C_TooltipInfo.GetItemByID", itemID)
  for _, line in ipairs(type(tip) == "table" and tip.lines or {}) do
    local t = C.Readable(line.leftText)
    local n = type(t) == "string" and t:match("(%d+) Slot")
    if n then return tonumber(n) end
  end
end

-- The bags you carry: smallest general bag (0 for an empty bag slot) and the
-- quiver or pouch, if any. A bag's family comes from GetContainerNumFreeSlots
-- (0 = holds anything; 1 arrows, 2 bullets).
function M:WornBags()
  local general, quiver = {}, nil
  for bag = 1, 4 do
    local slots = C.NumSlots(bag) or 0
    local _, family = C.Call("C_Container.GetContainerNumFreeSlots", bag)
    if family == nil then _, family = C.Call("GetContainerNumFreeSlots", bag) end
    family = tonumber(C.Readable(family)) or 0
    if slots == 0 or family == 0 then general[#general + 1] = slots
    elseif family == 1 or family == 2 then quiver = math.max(quiver or 0, slots) end
  end
  table.sort(general)
  return { smallest = general[1], general = general, quiver = quiver }
end

-- Which ammo the worn ranged weapon shoots: "arrows" (bow, crossbow), "bullets" (gun) or nil.
function M.AmmoKind()
  local link = C.Call("GetInventoryItemLink", "player", 18)
  local id = link and tonumber(tostring(link):match("item:(%d+)"))
  local _, class, sub = instant(id or 0)
  if class ~= M.WEAPON then return nil end
  if sub == 2 or sub == 18 then return "arrows" end
  if sub == 3 then return "bullets" end
end

local function hasProf(name)
  local p = ns.db.char.professions
  return type(p) == "table" and p[name] ~= nil
end

-- Bags worth buying: { kind, name, slots, gain, replaces, price, perSlot }.
-- General bags first (most slots gained, then cheapest), then quivers, then
-- profession bags. Returns list, skippedForGold.
function M:BagResults()
  local money = ns.AHBuy and ns.AHBuy.Money() or 0
  local level = C.Call("UnitLevel", "player") or 1
  local cls, ammo, worn = M.PlayerClass(), M.AmmoKind(), self:WornBags()
  local all, skipped = {}, 0
  for itemID, f in pairs(self.found or {}) do
    local _, class, sub = instant(itemID)
    local kind = M.BAG_KINDS[class or -1] and M.BAG_KINDS[class][sub or -1]
    local slots = kind and M.BagSlotsOf(itemID)
    local info = C.ItemInfo("item:" .. itemID)
    local ok = kind and slots and (not kind.class or kind.class == cls) and (not kind.prof or hasProf(kind.prof))
      and (not kind.ammo or not ammo or kind.ammo == ammo)
      and not (info and type(info.reqLevel) == "number" and info.reqLevel > level)
    if ok then
      local replaces, order
      if class == M.QUIVER then replaces, order = worn.quiver or 0, 2
      elseif sub == 0 then replaces, order = worn.smallest or (#worn.general < 4 and 0) or slots, 1
      else replaces, order = 0, 3 end
      local gain = slots - replaces
      if gain > 0 then
        if f.price > money then skipped = skipped + 1
        else
          all[#all + 1] = { mode = "bags", kind = kind.name, order = order, itemID = itemID, itemKey = f.itemKey,
            price = f.price, slots = slots, gain = gain, replaces = replaces,
            name = info and info.name or ("item " .. itemID), perSlot = math.floor(f.price / gain) }
        end
      end
    end
  end
  table.sort(all, function(a, b)
    if a.order ~= b.order then return a.order < b.order end
    if a.gain ~= b.gain then return a.gain > b.gain end
    return a.price < b.price
  end)
  local out = {}
  for i = 1, math.min(M.TOP, #all) do out[i] = all[i] end
  return out, skipped
end

-- Second line for a bag: what it replaces and the price per new slot.
function M.BagLine(b)
  local what
  if b.order == 3 then what = string.format("%d slots (%s only)", b.slots, b.kind:gsub(" bag$", ""):lower())
  elseif b.replaces == 0 then what = string.format("%d slots in an empty %s slot", b.slots, b.order == 2 and "quiver" or "bag")
  else what = string.format("%d slots, replaces your %d-slot %s", b.slots, b.replaces, b.order == 2 and "quiver" or "bag") end
  return string.format("%s   |cffcccccc%s per new slot|r", what, ns.Prices.Money(b.perSlot))
end

-- Upgrades you can afford: weapons the top 10 by gain; armor the best per slot.
-- Returns list, skippedForGold.
function M:Results()
  if self.mode == "bags" then return self:BagResults() end
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
          name = info and info.name or ("item " .. itemID), learn = learn, against = r.against, new = r.new, old = r.old }
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

-- The net of every gain and loss, each stat weighed by what this class needs
-- (GearScore's score): "= overall +12% (score 24.0 -> 27.0)" (Gary, 2026-11-14:
-- "lose a little spirit but gain agility: the overall improvement?").
function M.Overall(b)
  if b.empty then return "|cff7fff7f= fills an empty slot|r" end
  local pct = math.floor(b.pct + 0.5)
  local color = pct > 0 and "|cff7fff7f" or (pct < 0 and "|cffff6060" or "|cffcccccc")
  local score = (b.new and b.old) and string.format(" (score %.1f -> %.1f)", b.old, b.new) or ""
  return string.format("%s= overall %s%d%%%s|r", color, pct > 0 and "+" or "", pct, score)
end

function M.Gain(b)
  if b.mode == "bags" then return string.format("+%d slots", b.gain) end
  if b.learn then return string.format("|cffffc84d%s first|r", b.learn) end
  if b.empty then return "empty slot" end
  if b.capped then return "big upgrade" end
  return string.format("+%d%%", math.floor(b.pct + 0.5))
end

-- ------------------------------------------------------------ panel
-- The shopping window beside the auction house (Gary, 2026-11-20: "make the
-- auction UI a show piece that would make a hero image"). A painted header
-- with your gold, a side menu (Training: Skill-ups, Recipes, Shopping list;
-- Gear: Weapons, Armor, Bags) and item cards: icon in its quality colour,
-- name, what it does for you, the price in coins and a Buy button. Every Buy
-- goes through the confirm bar (AHBuy): one click from Gary per purchase.
M.W, M.NAV, M.HEAD = 740, 168, 96
M.CARD_H, M.PAGE = 50, 8
M.ROWS = M.PAGE

M.NAV_ITEMS = {
  { head = "Training" },
  { id = "training", label = "Skill-ups", icon = "Trade_BlackSmithing", tip = "The cheapest way to your next skill points: what each recipe needs and what that costs per point." },
  { id = "recipes", label = "Recipes", icon = "INV_Scroll_03", tip = "Recipes for sale that you don't know yet, usable now or within 25 points." },
  { id = "list", label = "Shopping list", icon = "INV_Misc_Bag_10", tip = "Every ingredient the skill-ups need, added up, with one Buy all." },
  { head = "Gear" },
  { id = "weapons", label = "Weapons", icon = "INV_Sword_04", tip = "Weapons your class can use, in your level range, that your gold covers: the top upgrades." },
  { id = "armor", label = "Armor", icon = "INV_Chest_Chain_05", tip = "The best upgrade per slot in your armor type that your gold covers." },
  { id = "bags", label = "Bags", icon = "INV_Misc_Bag_08", tip = "Bags bigger than your smallest one; hunters also get a quiver or ammo pouch." },
  { head = "Profit" },
  { id = "flips", label = "Vendor flips", icon = "INV_Misc_Coin_01", tip = "Listings under what a vendor pays: buy them, sell them at any vendor. From Scan all prices." },
  { id = "resale", label = "Resale", icon = "INV_Misc_Coin_17", tip = "Listings well under their usual auction price, after the 5% cut and deposit. Not sure: it has to sell again." },
  { head = "Sell" },
  { id = "sell", label = "Sell bags", icon = "INV_Misc_Bag_07", tip = "What in your bags can go on the auction house, priced just under the lowest now. One click on Post puts it up." },
  { id = "auctions", label = "My auctions", icon = "INV_Misc_Note_01", tip = "Your auctions and whether someone undercut them. One click on Cancel takes one down." },
  { head = "Search" },
  { id = "search", label = "Search", icon = "INV_Misc_Spyglass_02", tip = "Search for anything, with extras like lvl 10-20, under 5g or green+. Your recent searches are kept." },
  { id = "lists", label = "Shopping lists", icon = "INV_Scroll_05", tip = "Your saved searches in named lists: search a whole list at once, import and export (Auctionator and TSM lists too)." },
}
-- views another module fills: cards, status, searching, pos, total from
-- module:View(id); a toolbar row from module:Toolbar(frame, id)
M.PROVIDERS = { sell = "AuctionSell", auctions = "AuctionSell", search = "AuctionSearch", lists = "AuctionSearch" }
function M.Provider(id)
  local name = M.PROVIDERS[id]
  local mod = name and ns[name]
  if mod and mod.enabled ~= false then return mod end
end
M.PROFIT_VIEWS = { flips = true, resale = true }
M.TRAINING_VIEWS = { training = true, recipes = true, list = true }

M.QUALITY = { [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 },
  [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 } }

function M.Icon(itemID)
  local tex = C.Call("C_Item.GetItemIconByID", itemID) or C.Call("GetItemIcon", itemID)
  if not tex then local info = C.ItemInfo(itemID) tex = info and info.icon end
  return tex or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function M.Quality(itemID)
  local info = C.ItemInfo(itemID)
  return M.QUALITY[info and info.quality or 1] or M.QUALITY[1]
end

-- One item card: icon with a quality border, a title, a line under it, small
-- reagent icons, the price and a Buy button. Shared with TrainShop.
function M.NewCard(parent, width)
  local Theme = ns.Theme
  local card = CreateFrame("Frame", nil, parent, Theme:BackdropTemplate())
  Theme:ApplyPanel(card, "raised", "border")
  card:SetSize(width, M.CARD_H)
  card.frame = card:CreateTexture(nil, "ARTWORK")
  card.frame:SetSize(40, 40)
  card.frame:SetPoint("LEFT", 8, 0)
  card.icon = card:CreateTexture(nil, "OVERLAY")
  card.icon:SetPoint("TOPLEFT", card.frame, "TOPLEFT", 2, -2)
  card.icon:SetPoint("BOTTOMRIGHT", card.frame, "BOTTOMRIGHT", -2, 2)
  card.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  card.text = UI.Text(card, "normal", "text")
  card.text:SetPoint("TOPLEFT", card.frame, "TOPRIGHT", 10, -3)
  card.text:SetWidth(width - 230)
  card.text:SetJustifyH("LEFT")
  if card.text.SetWordWrap then card.text:SetWordWrap(false) end
  card.stats = UI.Text(card, "small", "muted")
  card.stats:SetPoint("TOPLEFT", card.text, "BOTTOMLEFT", 0, -5)
  card.stats:SetWidth(width - 230)
  card.stats:SetJustifyH("LEFT")
  if card.stats.SetWordWrap then card.stats:SetWordWrap(false) end
  card.pill = UI.Text(card, "small", "goldText")
  card.pill:SetPoint("TOPRIGHT", card, "TOPRIGHT", -84, -9)
  card.pill:SetJustifyH("RIGHT")
  card.price = UI.Text(card, "normal", "text")
  card.price:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -84, 9)
  card.price:SetJustifyH("RIGHT")
  -- one button, two clicks on the same spot (Gary, 2026-11-20: "I don't like
  -- how I have to chase the buy button"): Add puts it in the cart; once its
  -- price is in, the same button says Buy and that click buys it.
  card.buy = UI:Button(card, "Buy", 64, function() M.CardClick(card) end)
  -- stackable goods: the price quote comes while the mouse rests here, so the click buys
  card.buy:HookScript("OnEnter", function()
    local a = card.action
    if a and #a == 1 and a[1].commodity and ns.AHBuy then ns.AHBuy:Prequote(a[1]) end
  end)
  card.buy:SetHeight(26)
  card.buy:SetPoint("RIGHT", -10, 0)
  UI.SetPrimary(card.buy, true)
  card.reagents = {}
  card:EnableMouse(true)
  card:SetScript("OnEnter", function(c)
    Theme:ApplyPanel(c, "hover", "strong")
    local id = c.item and c.item.itemID
    if not id then return end
    GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(id)
    -- what this view knows about it: prices now, the usual price, your posts
    for _, l in ipairs(c.tipLines or {}) do GameTooltip:AddLine(l, Theme:Color("accent")) end
    GameTooltip:Show()
  end)
  card:SetScript("OnLeave", function(c)
    Theme:ApplyPanel(c, c.selected and "goldSoft" or "raised", c.selected and "gold" or "border")
    GameTooltip:Hide()
  end)
  -- right-click: the view's "hide" or "remove"; left-click: select it
  card:SetScript("OnMouseUp", function(c, button)
    if button == "RightButton" and c.onRight then ns.Safe("card:right", c.onRight)
    elseif button == "LeftButton" and c.onSelect then ns.Safe("card:select", c.onSelect) end
  end)
  card:Hide()
  return card
end

-- Fill a card. d = { itemID, title, sub, pill, price (copper), reagents = { {itemID, n, short} }, action, item, dim }
-- What the cart is doing with a card's purchase: nil (not in it), "queued",
-- "finding", "quote" (ready: Buy), "buying" or "bought".
function M.CartState(action)
  local A, e = ns.AHBuy, action and action[1]
  if not (A and e) then return nil end
  return A:StateOf(e)
end

-- One click buys when the listing or quote is already in (AHBuy:BuyNow);
-- a card with several things to buy (a skill-up's ingredients) goes to the cart.
function M.CardClick(card)
  if card.custom then
    ns.Safe("card:" .. tostring(card.custom.label), card.custom.click, card)
    if M.open then M:Refresh() end
    return
  end
  local A = ns.AHBuy
  if not (A and card.action) then return end
  local st = M.CartState(card.action)
  if #card.action == 1 and (st == nil or st == "bought" or (st == "quote")) then
    if st == "quote" and not (A.current and A.current.hover) then A:Confirm() else A:BuyNow(card.action[1]) end
  elseif st == "quote" then A:Confirm()
  elseif st == nil or st == "bought" then
    for _, e in ipairs(card.action) do A:Add(e) end
  end
  M:UpdateButtons()
end

-- Labels for every card's button and the cart bar, without redrawing the page.
M.BUTTON = { queued = "In cart", finding = "...", quote = "Buy", buying = "Buying", bought = "Bought" }
function M:UpdateButtons()
  local f = self.frame
  if not f then return end
  for _, card in ipairs(f.rows or {}) do
    if card:IsShown() and card.action and not card.custom then
      local st = M.CartState(card.action)
      local single = #card.action == 1
      card.buy.label:SetText(M.BUTTON[st or ""] or (single and "Buy" or "Add"))
      UI.SetPrimary(card.buy, st == nil or st == "quote")
      -- the price the click will pay: the quote or the listing looked up ahead
      local A = ns.AHBuy
      if st == "quote" and A.quote then card.price:SetText(ns.Prices.Coins(A.quote.price))
      elseif single and A.Known then
        local kn = A:Known(card.action[1])
        if kn then card.price:SetText(ns.Prices.Coins(kn.price)) end
      end
    end
  end
  self:CartBar()
end

-- The cart bar, fixed at the bottom of the window: what's next and one Buy.
function M:CartBar()
  local f, A = self.frame, ns.AHBuy
  if not (f and f.cart and A) then return end
  local e, q, p = A.current, A.quote, A.pending
  if e and e.hover then e, q = nil, nil end -- a hover quote isn't in the cart
  local n = #(A.queue or {}) + (e and 1 or 0) + (p and 1 or 0)
  if n == 0 then
    f.cart.text:SetText("|cff8f96a6Cart empty: Add puts an item here; Buy here or on its card.|r")
    f.cart.buy:Hide()
    return
  end
  local shown = e or (p and p.e)
  local what = tostring(shown.name) .. (shown.qty and (" x" .. shown.qty) or "")
  local status
  if p then status = "buying " .. what .. "..."
  elseif q then status = what .. "  " .. ns.Prices.Coins(q.price)
  else status = "finding the cheapest " .. what .. "..." end
  f.cart.text:SetText(string.format("|cffd4a84aCart %d|r   %s", n, status))
  f.cart.buy.label:SetText(q and not p and "Buy" or "...")
  UI.SetPrimary(f.cart.buy, q and not p and true or false)
  f.cart.buy:Show()
end

function M.FillCard(card, d)
  card.item, card.action = d.item, d.action
  card.custom, card.onRight, card.onSelect, card.tipLines, card.selected = d.button, d.onRight, d.onSelect, d.tip, d.selected
  ns.Theme:ApplyPanel(card, d.selected and "goldSoft" or "raised", d.selected and "gold" or "border")
  card.icon:SetTexture(d.icon or (d.itemID and M.Icon(d.itemID)) or "Interface\\Icons\\INV_Misc_QuestionMark")
  local q = d.quality or (d.itemID and M.Quality(d.itemID)) or M.QUALITY[1]
  card.frame:SetColorTexture(q[1], q[2], q[3], 0.9)
  card.text:SetText(d.title or "")
  card.text:SetTextColor(q[1] * 0.9 + 0.1, q[2] * 0.9 + 0.1, q[3] * 0.9 + 0.1)
  card.pill:SetText(d.pill or "")
  card.price:SetText(d.price and ns.Prices.Coins(d.price) or (d.priceText or ""))
  card.buy:SetShown(d.action ~= nil or d.button ~= nil)
  if d.button then
    card.buy.label:SetText(d.button.label or "OK")
    UI.SetPrimary(card.buy, d.button.primary and true or false)
  end
  card:SetAlpha(d.dim and 0.6 or 1)
  -- reagents: small icons with a count, after the line under the title
  local list = d.reagents or {}
  for i, r in ipairs(list) do
    local ic = card.reagents[i]
    if not ic then
      ic = card:CreateTexture(nil, "OVERLAY")
      ic:SetSize(16, 16)
      ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
      ic.count = UI.Text(card, "small", "body")
      ic.count:SetPoint("LEFT", ic, "RIGHT", 2, 0)
      card.reagents[i] = ic
    end
    ic:SetTexture(M.Icon(r.itemID))
    ic:ClearAllPoints()
    ic:SetPoint("BOTTOMLEFT", card.frame, "BOTTOMRIGHT", 10 + (i - 1) * 54, 3)
    ic.count:SetText((r.short and "|cffffc84d" or "") .. "x" .. tostring(r.n) .. (r.short and "|r" or ""))
    ic:Show() ic.count:Show()
  end
  for i = #list + 1, #card.reagents do card.reagents[i]:Hide() card.reagents[i].count:Hide() end
  card.stats:SetShown(#list == 0)
  card.stats:SetText(d.sub or "")
  card:Show()
end

function M:Build()
  if self.frame then return self.frame end
  local Theme = ns.Theme
  local anchor = rawget(_G, "AuctionHouseFrame") or UIParent
  local f = CreateFrame("Frame", "Outrider_GearShop", anchor, Theme:BackdropTemplate())
  Theme:ApplyPanel(f, "bg", "gold")
  f:SetSize(M.W, 520)
  f:SetFrameStrata("HIGH")
  f:SetClampedToScreen(true)
  local pt = self:Settings().point
  if type(pt) == "table" then f:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4])
  else f:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -8, 0) end
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(fr) fr:StartMoving() end)
  f:SetScript("OnDragStop", function(fr)
    fr:StopMovingOrSizing()
    local a, _, b, x, y = fr:GetPoint()
    M:Settings().point = { a, b, x, y }
  end)
  -- header: the painted town scene, darkened at the bottom, emblem and title
  local art = ns.Art and (ns.Art:Path("header_auction") or ns.Art:Path("header_town") or ns.Art:Path("header"))
  f.scene = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  f.scene:SetPoint("TOPLEFT", 1, -1)
  f.scene:SetPoint("TOPRIGHT", -1, -1)
  f.scene:SetHeight(M.HEAD)
  if art then f.scene:SetTexture(art) f.scene:SetTexCoord(0, 1, 0.2, 0.8) f.scene:SetAlpha(0.75)
  else f.scene:SetColorTexture(Theme:Color("raised")) end
  f.shade = f:CreateTexture(nil, "BACKGROUND", nil, 2)
  f.shade:SetPoint("TOPLEFT", f.scene, "TOPLEFT")
  f.shade:SetPoint("BOTTOMRIGHT", f.scene, "BOTTOMRIGHT")
  f.shade:SetColorTexture(0, 0, 0, 0.45)
  f.rule = f:CreateTexture(nil, "ARTWORK")
  f.rule:SetPoint("TOPLEFT", 1, -M.HEAD)
  f.rule:SetPoint("TOPRIGHT", -1, -M.HEAD)
  f.rule:SetHeight(2)
  f.rule:SetColorTexture(Theme:Color("gold"))
  f.emblem = f:CreateTexture(nil, "ARTWORK")
  f.emblem:SetSize(52, 52)
  f.emblem:SetPoint("LEFT", f, "TOPLEFT", 16, -M.HEAD / 2)
  f.emblem:SetTexture((ns.Art and ns.Art:Path("pin_auction")) or "Interface\\Icons\\INV_Misc_Coin_02")
  f.title = UI.Display(f, "page", "goldText")
  f.title:SetPoint("TOPLEFT", f.emblem, "TOPRIGHT", 12, -4)
  f.title:SetText("Shopping")
  f.sub = UI.Text(f, "small", "body")
  f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 1, -6)
  f.sub:SetText("Outrider at the auction house: only what helps you, only what your gold covers")
  -- right of the header: your gold, large, and the price scan
  f.goldLabel = UI.Text(f, "small", "muted")
  f.goldLabel:SetPoint("TOPRIGHT", -16, -16)
  f.goldLabel:SetText("YOUR GOLD")
  f.gold = UI.Text(f, "large", "text")
  f.gold:SetPoint("TOPRIGHT", f.goldLabel, "BOTTOMRIGHT", 0, -4)
  f.scan = UI:Button(f, "Scan all prices", 118, function()
    if ns.Prices then ns.Prices:FullScan() end
    M:Refresh()
  end)
  f.scan:SetHeight(22)
  f.scan:SetPoint("TOPRIGHT", f.gold, "BOTTOMRIGHT", 0, -8)
  -- side menu
  f.navBg = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  f.navBg:SetPoint("TOPLEFT", 1, -M.HEAD - 2)
  f.navBg:SetPoint("BOTTOMLEFT", 1, 1)
  f.navBg:SetWidth(M.NAV)
  f.navBg:SetColorTexture(Theme:Color("panel"))
  f.navLine = f:CreateTexture(nil, "ARTWORK")
  f.navLine:SetPoint("TOPLEFT", f.navBg, "TOPRIGHT")
  f.navLine:SetPoint("BOTTOMLEFT", f.navBg, "BOTTOMRIGHT")
  f.navLine:SetWidth(1)
  f.navLine:SetColorTexture(Theme:Color("border"))
  f.nav = {}
  local y = -M.HEAD - 14
  for _, n in ipairs(M.NAV_ITEMS) do
    if n.head then
      local h = UI.Text(f, "small", "gold")
      h:SetPoint("TOPLEFT", 16, y)
      h:SetText(n.head:upper())
      y = y - 20
    else
      local b = CreateFrame("Button", nil, f, Theme:BackdropTemplate())
      b:SetSize(M.NAV - 16, 30)
      b:SetPoint("TOPLEFT", 8, y)
      b.bar = b:CreateTexture(nil, "ARTWORK")
      b.bar:SetPoint("TOPLEFT") b.bar:SetPoint("BOTTOMLEFT") b.bar:SetWidth(3)
      b.bar:SetColorTexture(Theme:Color("gold"))
      b.icon = b:CreateTexture(nil, "ARTWORK")
      b.icon:SetSize(20, 20)
      b.icon:SetPoint("LEFT", 10, 0)
      b.icon:SetTexture("Interface\\Icons\\" .. n.icon)
      b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
      b.label = UI.Text(b, "normal", "body")
      b.label:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
      b.label:SetText(n.label)
      b.count = UI.Text(b, "small", "muted")
      b.count:SetPoint("RIGHT", -8, 0)
      b.id = n.id
      b:SetScript("OnClick", function() M:Pick(n.id) end)
      UI.Tip(b, n.label, n.tip)
      f.nav[n.id] = b
      y = y - 34
    end
  end
  M.NAV_H = -y + 16
  -- the old names the tests and other modules use
  f.training, f.weapons, f.armor, f.bags = f.nav.training, f.nav.weapons, f.nav.armor, f.nav.bags
  -- content
  local cx = M.NAV + 16
  local cw = M.W - cx - 16
  f.content = CreateFrame("Frame", nil, f)
  f.content:SetPoint("TOPLEFT", cx, -M.HEAD - 12)
  f.content:SetSize(cw, 400)
  f.heading = UI.Display(f, "side", "text")
  f.heading:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, 0)
  f.status = UI.Text(f, "small", "muted")
  f.status:SetPoint("TOPLEFT", f.heading, "BOTTOMLEFT", 0, -6)
  f.status:SetWidth(cw)
  f.status:SetJustifyH("LEFT")
  -- search progress
  f.bar = CreateFrame("Frame", nil, f, Theme:BackdropTemplate())
  Theme:ApplyPanel(f.bar, "panel", "border")
  f.bar:SetSize(cw, 8)
  f.bar.fill = f.bar:CreateTexture(nil, "ARTWORK")
  f.bar.fill:SetPoint("TOPLEFT", 1, -1) f.bar.fill:SetPoint("BOTTOMLEFT", 1, 1)
  f.bar.fill:SetColorTexture(Theme:Color("gold"))
  f.bar:Hide()
  -- empty state picture
  f.empty = f:CreateTexture(nil, "ARTWORK")
  f.empty:SetSize(256, 128)
  f.empty:Hide()
  f.rows = {}
  for i = 1, M.PAGE do f.rows[i] = M.NewCard(f, cw) end
  -- footer: total and Buy all, pager
  f.total = UI.Text(f, "normal", "text")
  f.buyAll = UI:Button(f, "Add all", 96, function() M:BuyAll() end)
  f.buyAll:SetHeight(26)
  UI.SetPrimary(f.buyAll, true)
  UI.Tip(f.buyAll, "Add all", "Puts every line here in the cart. Then press Buy in the cart bar at the bottom, once per purchase, without moving the mouse.")
  -- the cart bar: always in the same place at the bottom
  f.cart = CreateFrame("Frame", nil, f, Theme:BackdropTemplate())
  Theme:ApplyPanel(f.cart, "panel", "gold")
  f.cart:SetHeight(40)
  f.cart:SetPoint("BOTTOMLEFT", M.NAV + 12, 10)
  f.cart:SetPoint("BOTTOMRIGHT", -12, 10)
  f.cart.icon = f.cart:CreateTexture(nil, "ARTWORK")
  f.cart.icon:SetSize(22, 22)
  f.cart.icon:SetPoint("LEFT", 10, 0)
  f.cart.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
  f.cart.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  f.cart.text = UI.Text(f.cart, "normal", "text")
  f.cart.text:SetPoint("LEFT", f.cart.icon, "RIGHT", 8, 0)
  f.cart.text:SetPoint("RIGHT", f.cart, "RIGHT", -180, 0)
  f.cart.text:SetJustifyH("LEFT")
  if f.cart.text.SetWordWrap then f.cart.text:SetWordWrap(false) end
  f.cart.clear = UI:Button(f.cart, "Clear", 64, function() if ns.AHBuy then ns.AHBuy:Cancel() end M:UpdateButtons() end)
  f.cart.clear:SetHeight(26)
  f.cart.clear:SetPoint("RIGHT", -8, 0)
  UI.Tip(f.cart.clear, "Clear cart", "Empties the cart. Nothing is bought.")
  f.cart.buy = UI:Button(f.cart, "Buy", 96, function() if ns.AHBuy then ns.AHBuy:Confirm() end M:UpdateButtons() end)
  f.cart.buy:SetHeight(28)
  f.cart.buy:SetPoint("RIGHT", f.cart.clear, "LEFT", -6, 0)
  UI.Tip(f.cart.buy, "Buy", "Buys the next item in the cart at the price shown. Press again for the next one.")
  f.prev = UI:Button(f, "<", 28, function() M.page = math.max(1, (M.page or 1) - 1) M:Refresh() end)
  f.next = UI:Button(f, ">", 28, function() M.page = (M.page or 1) + 1 M:Refresh() end)
  f.pageText = UI.Text(f, "small", "muted")
  UI.Tip(f.prev, "Previous page", "The previous page of results.")
  UI.Tip(f.next, "Next page", "The next page of results.")
  f:Hide()
  self.frame = f
  return f
end

-- A menu click: training views share one search; gear views each search.
function M:Pick(id)
  self.page = 1
  local prov = M.Provider(id)
  if prov then
    self.mode = id
    if prov.OnPick then prov:OnPick(id) end
    self:Refresh()
    return
  end
  if M.PROFIT_VIEWS[id] then
    self.mode = id
  elseif M.TRAINING_VIEWS[id] then
    self.mode = id
    local T = ns.TrainShop
    if T and not T.prices and not T.queue then T:Start()
    elseif T and T.queue and T.manual then T:Next() end
  elseif self.mode == id and self.queue and self.manual then
    self:Next()
  else
    self:Start(id)
    return
  end
  self:Refresh()
end

function M:BuyAll()
  local list = self.allActions or {}
  local n = 0
  for _, a in ipairs(list) do for _, e in ipairs(a) do if ns.AHBuy then ns.AHBuy:Add(e) n = n + 1 end end end
  self:Info("buy all: %d queued (%s)", n, tostring(self.mode))
  self:UpdateButtons()
end

function M:Resize() end

-- Menu: the active item lit gold, counts on the right.
function M:StyleTabs()
  local f, Theme = self.frame, ns.Theme
  if not f then return end
  local active = self.mode or "training"
  for id, b in pairs(f.nav) do
    local on = id == active
    Theme:ApplyPanel(b, on and "goldSoft" or "panel", on and "gold" or "panel")
    b.bar:SetShown(on)
    b.label:SetTextColor(Theme:Color(on and "goldText" or "body"))
  end
  f.gold:SetText(ns.Prices.Coins(ns.AHBuy and ns.AHBuy.Money() or 0))
  local P = ns.Prices
  if P and P.scanning then f.scan.label:SetText("Scanning...")
  elseif P and P:ScanWait() > 0 then f.scan.label:SetText(string.format("Scan in %dm", math.ceil(P:ScanWait() / 60)))
  else f.scan.label:SetText("Scan all prices") end
end

-- Cards for a gear view: { item, itemID, title, sub, pill, price, action }
function M:GearCards()
  local list = (self.found and not self.queue) and (self:Results()) or {}
  local out = {}
  for i, b in ipairs(list) do
    local label = self.mode == "weapons" and (i .. ". ") or (b.mode == "bags" and (b.kind .. ": ")) or (ns.TitleCase(b.slotName) .. ": ")
    local sub
    if b.mode == "bags" then sub = M.BagLine(b)
    else
      local diff = ns.GearScore:Diff("item:" .. b.itemID, b.against)
      sub = (#diff > 0 and ns.GearScore.DiffText(diff, 6) or "no stat changes listed") .. "   " .. M.Overall(b)
    end
    out[#out + 1] = { item = b, itemID = b.itemID, title = label .. b.name, sub = sub, pill = M.Gain(b), price = b.price,
      action = { { name = b.name, itemKey = b.itemKey } } }
  end
  return out
end

M.HEADINGS = { sell = "Sell from your bags", auctions = "My auctions", search = "Search the auction house", lists = "Shopping lists", flips = "Vendor flips", resale = "Resale", training = "Skill-ups", recipes = "Recipes for sale", list = "Shopping list", weapons = "Weapons", armor = "Armor", bags = "Bags" }

function M:Refresh()
  if not self.open then return end
  local f = self:Build()
  self.mode = self.mode or "training"
  self:StyleTabs()
  local training = M.TRAINING_VIEWS[self.mode]
  local T = ns.TrainShop
  local t = T and T.frame
  if t then t:SetShown(training) end
  f.heading:SetText(M.HEADINGS[self.mode] or "")
  local gold = ns.Prices.Money(ns.AHBuy and ns.AHBuy.Money() or 0)
  local cards, searching, pos, total, statusText = {}, false, 0, 0, ""
  local _, skipped = 0, 0
  local prov = M.Provider(self.mode)
  if prov then
    cards, statusText, searching, pos, total = prov:View(self.mode)
    statusText = statusText or ""
    searching, pos, total = searching or false, pos or 0, total or 0
  elseif M.PROFIT_VIEWS[self.mode] then
    if ns.Deals and ns.Deals.enabled then cards, statusText = ns.Deals:View(self.mode) end
    statusText = statusText or "Deals are switched off (Modules tab in Settings)."
  elseif training then
    if T then cards, statusText, searching, pos, total = T:View(self.mode) end
    statusText = statusText or ""
  else
    cards = self:GearCards()
    skipped = select(2, self:Results())
    if self.queue then
      searching, pos, total = true, self.pos, #self.queue
      local e = self.queue[self.pos]
      statusText = self.manual and string.format("The server wants a click per search: press %s again (%d of %d).", M.HEADINGS[self.mode], self.pos, #self.queue)
        or string.format("Searching %s (%d of %d)...", e and e.text or "...", self.pos, #self.queue)
    elseif self.found then
      local head = (self.mode == "weapons" and "Top weapons you can afford")
        or (self.mode == "bags" and "Bigger bags you can afford") or "The best armor per slot you can afford"
      statusText = string.format("%s (you have %s)%s.", head, gold, skipped > 0 and string.format("; %d better ones cost more", skipped) or "")
      if #cards == 0 then statusText = statusText .. (self.mode == "bags" and " No bag bigger than yours for sale right now." or " Nothing better for sale in your level range right now.") end
    else
      statusText = "Finds upgrades your class can use, in your level range, that your gold covers. Buy is your click."
    end
  end
  f.status:SetText(statusText)
  -- progress bar while searching
  local y = -M.HEAD - 12 - 26 - ((f.status.GetStringHeight and f.status:GetStringHeight()) or 14) - 10
  if searching and total > 0 then
    f.bar:ClearAllPoints()
    f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", M.NAV + 16, y)
    f.bar.fill:SetWidth(math.max(1, (f.bar:GetWidth() - 2) * math.min(1, pos / total)))
    f.bar:Show()
    y = y - 18
  else
    f.bar:Hide()
  end
  -- training's profession chips sit above the cards
  if training and t then
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", f, "TOPLEFT", M.NAV + 16, y)
    y = y - 36
  end
  -- a view's own row (search box, list chips, price box) above its cards
  local bar = prov and prov.Toolbar and prov:Toolbar(f, self.mode)
  if self.toolbar and self.toolbar ~= bar then self.toolbar:Hide() end
  self.toolbar = bar
  if bar then
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", M.NAV + 16, y)
    bar:Show()
    y = y - 36
  end
  -- page of cards
  local pages = math.max(1, math.ceil(#cards / M.PAGE))
  self.page = math.min(self.page or 1, pages)
  local first = (self.page - 1) * M.PAGE
  local actions, sum = {}, 0
  for _, c in ipairs(cards) do
    if c.action then actions[#actions + 1] = c.action sum = sum + (c.price or 0) end
  end
  self.allActions = actions
  for i = 1, M.PAGE do
    local row, d = f.rows[i], cards[first + i]
    if d then
      M.FillCard(row, d)
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", f, "TOPLEFT", M.NAV + 16, y)
      y = y - M.CARD_H - 6
    else
      row.item, row.action = nil, nil
      row:Hide()
    end
  end
  -- empty state
  if #cards == 0 and not searching then
    local pic = ns.Art and ns.Art:Path((statusText:find("^Finds") or statusText:find("^Press Scan")) and "empty_search" or "empty_nodata")
    if pic then
      f.empty:SetTexture(pic)
      f.empty:ClearAllPoints()
      f.empty:SetPoint("TOP", f, "TOPLEFT", M.NAV + 16 + (M.W - M.NAV - 32) / 2, y - 10)
      f.empty:Show()
      y = y - 148
    else f.empty:Hide() end
  else
    f.empty:Hide()
  end
  -- footer: total and Buy all on training lists, pager when needed
  local footer = (#actions > 1 and ((M.TRAINING_VIEWS[self.mode] and self.mode ~= "recipes") or self.mode == "flips" or self.mode == "lists"))
  y = y - 6
  f.total:ClearAllPoints()
  f.total:SetPoint("TOPLEFT", f, "TOPLEFT", M.NAV + 16, y - 6)
  f.total:SetText(footer and ("Total  " .. ns.Prices.Coins(sum) .. string.format("  |cff8f96a6for %d purchases|r", #actions)) or "")
  f.buyAll:ClearAllPoints()
  f.buyAll:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, y)
  f.buyAll:SetShown(footer and true or false)
  f.prev:ClearAllPoints()
  f.next:ClearAllPoints()
  f.pageText:ClearAllPoints()
  f.next:SetPoint("TOPRIGHT", f, "TOPRIGHT", footer and -120 or -16, y)
  f.pageText:SetPoint("RIGHT", f.next, "LEFT", -6, 0)
  f.prev:SetPoint("RIGHT", f.pageText, "LEFT", -6, 0)
  f.pageText:SetText(string.format("%d / %d", self.page, pages))
  local paged = pages > 1
  f.prev:SetShown(paged) f.next:SetShown(paged) f.pageText:SetShown(paged)
  if footer or paged then y = y - 34 end
  -- menu counts
  if T then
    local n = T.prices and #(T:Rank()) or 0
    f.nav.training.count:SetText(T.prices and tostring(math.min(n, T.SHOW)) or "")
    f.nav.recipes.count:SetText(T.prices and tostring(#(T:UsefulRecipes())) or "")
  end
  local S = ns.AuctionSell
  if S and S.enabled ~= false and f.nav.auctions then
    local n = #S:Undercuts()
    f.nav.auctions.count:SetText(n > 0 and ("|cffff6060" .. n .. "|r") or "")
  end
  local D = ns.Deals
  if D and D.enabled and D:Scan() then
    f.nav.flips.count:SetText(tostring(#(D:VendorFlips())))
    f.nav.resale.count:SetText(tostring(#D:Resale()))
  end
  f:SetHeight(math.max(M.NAV_H or 560, -y + 14 + 50))
  -- look up the single items on screen now, so one click buys them
  local ahead = {}
  for _, card in ipairs(f.rows) do
    local a = card:IsShown() and card.action
    if a and #a == 1 and not a[1].commodity then ahead[#ahead + 1] = a[1] end
  end
  if ns.AHBuy and ns.AHBuy.Prefetch then ns.AHBuy:Prefetch(ahead) end
  self:UpdateButtons()
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
  self:On("OTR_PRICES_SCAN", function(mod) if mod.open then mod:Refresh() end end)
  self:On("GET_ITEM_INFO_RECEIVED", function(mod)
    if mod.open and mod.found and not mod.queue then ns.Throttle("gearshop:refresh", 1, function() M:Refresh() end) end
  end)
end

function M:OnDisable() if self.frame then self.frame:Hide() end end

function M:Activity()
  return "open the auction house: Weapons / Armor / Bags"
end

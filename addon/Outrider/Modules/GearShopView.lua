-- Modules/GearShopView.lua
-- Gear shop window: cards, cart and buy confirmation, rendering and refresh. Split from Modules/GearShop.lua (OI01-10); behaviour unchanged.

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local M = ns.GearShop

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
  -- one button, two clicks on the same spot (requirement 2026-11-20: the buy
  -- button must not move between clicks): Add puts it in the cart; once its
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
  local list, skipped = {}, 0
  if self.found and not self.queue then list, skipped = self:Results() end
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
  return out, skipped or 0
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
    cards, skipped = self:GearCards()
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
    -- the chips follow the page (Recipes shows only professions with recipes)
    if T.Chips then T:Chips(t) end
    y = y - (t.chipRows or 1) * 30 - 6
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


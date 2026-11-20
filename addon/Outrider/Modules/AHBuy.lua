-- Modules/AHBuy.lua
-- Buying from Outrider's auction panels (Gary, 2026-11-14: "one click buy ...
-- I click on it"). Blizzard needs a click for every purchase, so a Buy
-- click queues the item, Outrider looks up the cheapest listing by itself,
-- and a confirm bar beside the auction window shows "Buy <item> for <price>":
-- that click buys it, then the next queued item is looked up.
--   * gear and recipes (one of a kind): item search -> cheapest buyout ->
--     PlaceBid on the confirm click
--   * stackable goods (herbs, meat, leather): commodity price quote for the
--     quantity -> ConfirmCommoditiesPurchase on the confirm click
-- Never spends more than the gold carried; each price is on the button
-- before any gold moves. The game's own errors are logged.

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local M = ns:NewModule("AHBuy", {
  title = "Auction buying (confirm bar)",
  phase = "P5",
  order = 72,
  defaults = {},
})
ns.AHBuy = M

M.WAIT = 4

function M:OnInitialize() self.queue = {} end

function M.Money() return tonumber(C.Readable(C.Call("GetMoney"))) or 0 end

-- e = { name, itemKey = {...} } for one item, or { name, itemID, qty, commodity = true }
function M:Add(e)
  if not self.open then ns.Print("open the auction house first") return end
  self:DropHover()
  self.queue[#self.queue + 1] = e
  self:Info("buy queued: %s%s", tostring(e.name), e.qty and (" x" .. e.qty) or "")
  if not self.current and not self.pending then self:Next() else self:Refresh() end
end

function M:Next()
  self.current, self.quote = nil, nil
  local e = table.remove(self.queue, 1)
  if not e then self:Refresh() self:Pump() return end
  self.current = e
  self.fetching = nil -- a lookup ahead gives way: the next answer is this one
  if e.commodity then
    pcall(C_AuctionHouse.StartCommoditiesPurchase, e.itemID, e.qty)
  else
    pcall(C_AuctionHouse.SendSearchQuery, e.itemKey, { { sortOrder = 0, reverseSort = false } }, false)
  end
  ns.Timer.After(M.WAIT, function()
    if M.current == e and not M.quote then
      ns.Print("%s: no price came back, skipped", tostring(e.name))
      M:Info("buy %s: no quote", tostring(e.name))
      M:Next()
    end
  end, "ahbuy:wait")
  self:Refresh()
end

-- The cheapest listing someone else posted for an item: { auctionID, price, n } or nil.
function M.Cheapest(itemKey)
  local n = C.Call("C_AuctionHouse.GetNumItemSearchResults", itemKey) or 0
  local best
  for i = 1, n do
    local r = C.Call("C_AuctionHouse.GetItemSearchResultInfo", itemKey, i)
    local price = type(r) == "table" and C.Readable(r.buyoutAmount)
    if type(price) == "number" and not r.containsOwnerItem and (not best or price < best.price) then
      best = { auctionID = r.auctionID, price = price, n = tonumber(C.Readable(r.quantity)) or 1 }
    end
  end
  return best
end

-- ------------------------------------------------------------ one click
-- (Gary, 2026-11-20: "I push the buy button once, and it actually buys it.")
-- The game buys only from a fresh click, and it needs the listing first. So
-- the listing is looked up before the click: single items for the cards on
-- screen, one search at a time (looking is free, only buying needs a click);
-- stackable goods while the mouse rests on that card's Buy (the server keeps
-- one price quote at a time). The click then buys at the price on the card.
-- If the lookup isn't back yet, the click falls back to the cart (two clicks).
M.FRESH, M.FETCH_WAIT = 90, 3

function M:Prefetch(list)
  self.known = self.known or {}
  self.toFetch = {}
  local now = time()
  for _, e in ipairs(list or {}) do
    local k = M.KeyOf(e)
    local kn = k and self.known[k]
    if k and not e.commodity and e.itemKey and not (kn and now - kn.at < M.FRESH) then self.toFetch[#self.toFetch + 1] = e end
  end
  self:Pump()
end

function M:Pump()
  if self.fetching or self.current or self.pending or not self.open then return end
  local e = table.remove(self.toFetch or {}, 1)
  if not e then return end
  self.fetching = e
  pcall(C_AuctionHouse.SendSearchQuery, e.itemKey, { { sortOrder = 0, reverseSort = false } }, false)
  ns.Timer.After(M.FETCH_WAIT, function()
    if M.fetching == e then M.fetching = nil M:Pump() end
  end, "ahbuy:fetch")
end

function M:OnFetched()
  local e = self.fetching
  self.fetching = nil
  local best = M.Cheapest(e.itemKey)
  self.known = self.known or {}
  local k = M.KeyOf(e)
  if k then self.known[k] = { auctionID = best and best.auctionID, price = best and best.price, n = best and best.n, at = time() } end
  local G = ns.GearShop
  if G and G.frame and G.UpdateButtons then G:UpdateButtons() end
  ns.Timer.After(0.2, function() M:Pump() end, "ahbuy:pump")
end

-- The listing looked up ahead for this item, while it's fresh.
function M:Known(e)
  local kn = self.known and self.known[M.KeyOf(e) or ""]
  if kn and kn.auctionID and time() - kn.at < M.FRESH then return kn end
end

-- A price quote for stackable goods while the mouse rests on its Buy.
function M:Prequote(e)
  if not (self.open and e and e.commodity) or self.pending or C.InCombat() then return end
  local k = M.KeyOf(e)
  if self.current and M.KeyOf(self.current) == k then return end
  if self.current and not self.current.hover then return end -- a cart lookup is running
  if #(self.queue or {}) > 0 then return end
  self:DropHover()
  local h = {}
  for key, v in pairs(e) do h[key] = v end
  h.hover = true
  self.current, self.quote = h, nil
  pcall(C_AuctionHouse.StartCommoditiesPurchase, e.itemID, e.qty)
  ns.Timer.After(M.WAIT, function()
    if M.current == h and not M.quote then M.current = nil end
  end, "ahbuy:hover")
end

function M:DropHover()
  if self.current and self.current.hover then
    pcall(C_AuctionHouse.CancelCommoditiesPurchase)
    self.current, self.quote = nil, nil
  end
end

-- A card's Buy: "bought" when the click could buy at once, else "queued".
function M:BuyNow(e)
  if not self.open then ns.Print("open the auction house first") return nil end
  if self.pending then return "busy" end
  local k = M.KeyOf(e)
  if e.commodity then
    if self.current and M.KeyOf(self.current) == k and self.quote then
      self.current.hover = nil
      self:Confirm()
      return "bought"
    end
  else
    local kn = self:Known(e)
    if kn and (not self.current or self.current.hover) then
      if e.maxUnit and kn.price / math.max(1, kn.n or 1) > e.maxUnit then
        ns.Print("%s: the cheap listing is gone, skipped", tostring(e.name))
        return "skipped"
      end
      self:DropHover()
      self.known[k] = nil -- that listing is being bought
      self.current, self.quote = e, { auctionID = kn.auctionID, price = kn.price, n = kn.n }
      self:Confirm()
      return "bought"
    end
  end
  self:Add(e)
  return "queued"
end

function M:OnItemResults()
  if self.fetching then return self:OnFetched() end
  local e = self.current
  if not e or e.commodity or self.quote then return end
  local best = M.Cheapest(e.itemKey)
  if not best then ns.Print("%s: no buyout left, skipped", tostring(e.name)) return self:Next() end
  -- a deal's price cap (Deals): the cheap listing may be gone
  if e.maxUnit and best.price / math.max(1, best.n) > e.maxUnit then
    self:Info("buy %s: cheapest now %s, over the deal's %s: skipped", tostring(e.name), ns.Prices.Money(best.price), ns.Prices.Money(e.maxUnit))
    ns.Print("%s: the cheap listing is gone, skipped", tostring(e.name))
    return self:Next()
  end
  self.quote = best
  self:Refresh()
end

function M:OnCommodityPrice(_, unitPrice, totalPrice)
  local e = self.current
  if not e or not e.commodity or self.quote then return end
  local total = C.Readable(totalPrice)
  if type(total) ~= "number" then return end
  if e.maxUnit and total > e.maxUnit * (e.qty or 1) then
    pcall(C_AuctionHouse.CancelCommoditiesPurchase)
    self:Info("buy %s: %s now, over the deal's %s: skipped", tostring(e.name), ns.Prices.Money(total), ns.Prices.Money(e.maxUnit * (e.qty or 1)))
    ns.Print("%s: the cheap listings are gone, skipped", tostring(e.name))
    return self:Next()
  end
  self.quote = { price = total, unit = C.Readable(unitPrice) }
  self:Refresh()
end

-- A purchase's key, the same for the card that asked for it and the cart.
function M.KeyOf(e)
  local id = e and (e.itemID or (e.itemKey and e.itemKey.itemID))
  return id and (tostring(id) .. ":" .. tostring(e.qty or 1)) or nil
end

-- Where a purchase stands: nil, "queued", "finding", "quote", "buying" or "bought".
function M:StateOf(e)
  local k = M.KeyOf(e)
  if not k then return nil end
  if self.pending and M.KeyOf(self.pending.e) == k then return "buying" end
  if self.current and M.KeyOf(self.current) == k then return self.quote and "quote" or "finding" end
  for _, q in ipairs(self.queue or {}) do if M.KeyOf(q) == k then return "queued" end end
  if self.bought and self.bought[k] then return "bought" end
  return nil
end

-- The confirm click. The purchase goes out, then Outrider waits for the
-- game's answer (bought, or why not) before it looks up the next item:
-- sending the next search while a purchase was still in flight could make
-- the auction house refuse one of them (Gary, 2026-11-20: "auction house
-- errors after I purchased something"). Every answer goes to the log.
M.DONE_WAIT = 5
function M:Confirm()
  local e, q = self.current, self.quote
  if not (e and q) or self.pending then return end
  if q.price > M.Money() then
    ns.Print("%s costs %s, more than you carry", tostring(e.name), ns.Prices.Money(q.price))
    return self:Next()
  end
  local ok, err
  if e.commodity then ok, err = pcall(C_AuctionHouse.ConfirmCommoditiesPurchase, e.itemID, e.qty)
  else ok, err = pcall(C_AuctionHouse.PlaceBid, q.auctionID, q.price) end
  self:Info("buying %s%s for %s: %s", tostring(e.name), e.qty and (" x" .. e.qty) or "", ns.Prices.Money(q.price), ok and "sent" or tostring(err))
  self.current, self.quote = nil, nil
  if not ok then
    self.pending = { e = e, q = q }
    self:Finish(false, tostring(err))
    return
  end
  local p = { e = e, q = q, money = M.Money() }
  self.pending = p
  ns.Timer.After(M.DONE_WAIT, function()
    if M.pending ~= p then return end
    -- no "completed" event: the gold decides (2026-11-20: the game showed
    -- "Internal auction error" for a Heavy Shortbow that was bought all the same)
    if M.Paid(p) then M:Finish(true) else M:Finish(false, p.error or "no answer from the auction house") end
  end, "ahbuy:done")
  self:Refresh()
end

-- Was the price taken from your gold since the click?
function M.Paid(p)
  return p and p.money and (p.money - M.Money()) >= (p.q.price or 0) * 0.99 and true or false
end

-- The game's name for an auction house error code ("DatabaseError"), when it has one.
function M.ErrorName(code)
  local enum = C.Resolve("Enum.AuctionHouseError")
  if type(enum) == "table" then
    for k, v in pairs(enum) do if v == code then return k end end
  end
  return "error " .. tostring(code)
end

-- The game's answer to a purchase: ok true (bought), false (refused, with why) or nil (no answer).
function M:Finish(ok, why)
  local p = self.pending
  self.pending = nil
  local e = p and p.e
  local what = e and (tostring(e.name) .. (e.qty and (" x" .. e.qty) or "")) or "?"
  self.results = self.results or { bought = 0, failed = 0 }
  if ok then
    self.results.bought = self.results.bought + 1
    self.bought = self.bought or {}
    if e then self.bought[M.KeyOf(e) or "?"] = true end
    self:Info("bought %s%s", what, p and p.error and (" (the game also showed " .. p.error .. "; the gold was taken, so it went through)") or "")
  else
    self.results.failed = self.results.failed + 1
    self:Warn("purchase %s: %s", what, tostring(why or "refused"))
    if ok == false and not self.toldFail then
      self.toldFail = true
      ns.Print("%s wasn't bought: %s", what, tostring(why or "the auction house refused it"))
    end
  end
  self.lastResult = { ok = ok, why = why, what = what }
  self:Next()
end

function M:OnPurchaseDone() if self.pending then self:Finish(true) end end
function M:OnCommodityFailed() if self.pending then self:Finish(false, "the price changed or the goods sold out") end end
-- An error while our purchase is out doesn't settle it: the purchase can go
-- through all the same, so the gold (or a completed event) decides.
function M:OnShowError(_, code)
  local msg = "auction house " .. M.ErrorName(C.Readable(code))
  if self.pending then
    self.pending.error = msg
    self:Info("%s while buying %s; waiting to see whether the gold is taken", msg, tostring(self.pending.e.name))
  else
    self:Info("%s (nothing of ours was buying)", msg)
  end
end
-- The red text in the middle of the screen while a purchase or lookup is ours.
function M:OnUIError(_, _, text)
  if not (self.pending or self.current) then return end
  self:Info("game said while buying: %s", tostring(C.Readable(text)))
end

function M:Cancel()
  if self.current and self.current.commodity then pcall(C_AuctionHouse.CancelCommoditiesPurchase) end
  self.queue, self.current, self.quote = {}, nil, nil
  self:Refresh()
end

-- ------------------------------------------------------------ the bar
-- The confirm bar above the auction window, in the shopping window's look:
-- the item's icon, its name, the price in coins, gold Buy and Cancel.
function M:Build()
  if self.frame then return self.frame end
  local Theme = ns.Theme
  local anchor = rawget(_G, "AuctionHouseFrame") or UIParent
  local f = CreateFrame("Frame", "Outrider_AHBuy", anchor, Theme:BackdropTemplate())
  Theme:ApplyPanel(f, "bg", "gold")
  f:SetSize(520, 46)
  f:SetFrameStrata("DIALOG")
  f:SetPoint("BOTTOM", anchor, "TOP", 0, 8)
  f.edge = f:CreateTexture(nil, "ARTWORK")
  f.edge:SetPoint("TOPLEFT", 1, -1)
  f.edge:SetPoint("BOTTOMLEFT", 1, 1)
  f.edge:SetWidth(3)
  f.edge:SetColorTexture(Theme:Color("gold"))
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(32, 32)
  f.icon:SetPoint("LEFT", 12, 0)
  f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  f.text = UI.Text(f, "normal", "text")
  f.text:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 10, -1)
  f.text:SetWidth(270)
  f.text:SetJustifyH("LEFT")
  if f.text.SetWordWrap then f.text:SetWordWrap(false) end
  f.sub = UI.Text(f, "small", "muted")
  f.sub:SetPoint("BOTTOMLEFT", f.icon, "BOTTOMRIGHT", 10, 1)
  f.sub:SetWidth(270)
  f.sub:SetJustifyH("LEFT")
  f.buy = UI:Button(f, "Buy", 96, function() M:Confirm() end)
  f.buy:SetHeight(28)
  f.buy:SetPoint("RIGHT", -96, 0)
  UI.SetPrimary(f.buy, true)
  f.cancel = UI:Button(f, "Cancel", 80, function() M:Cancel() end)
  f.cancel:SetHeight(28)
  f.cancel:SetPoint("RIGHT", -10, 0)
  f:Hide()
  self.frame = f
  return f
end

function M:Refresh()
  if not self.open then return end
  -- the shopping window's buttons and cart bar follow the cart
  local G = ns.GearShop
  if G and G.frame and G.UpdateButtons then G:UpdateButtons() end
  local f = self:Build()
  local e, q, p = self.current, self.quote, self.pending
  if (not e and not p) or (e and e.hover and not p) then f:Hide() return end
  local more = #self.queue > 0 and string.format("%d more after this", #self.queue) or ""
  local shown = e or p.e
  local id = shown.itemID or (shown.itemKey and shown.itemKey.itemID)
  local G = ns.GearShop
  f.icon:SetTexture((id and G and G.Icon and G.Icon(id)) or "Interface\\Icons\\INV_Misc_Coin_02")
  local what = tostring(shown.name) .. (shown.qty and (" x" .. shown.qty) or "")
  if p then
    f.text:SetText(what .. ": " .. ns.Prices.Money(p.q.price))
    f.sub:SetText("Buying... waiting for the auction house" .. (more ~= "" and ("  ·  " .. more) or ""))
    f.buy.label:SetText("...")
  elseif q then
    local short = q.price > M.Money()
    f.text:SetText(string.format("%s: %s%s", what, ns.Prices.Money(q.price), short and " |cffff5050(not enough gold)|r" or ""))
    f.sub:SetText((short and "Skip moves on to the next" or "Cheapest listing: Buy to confirm") .. (more ~= "" and ("  ·  " .. more) or ""))
    f.buy.label:SetText(short and "Skip" or "Buy")
  else
    f.text:SetText("Finding the cheapest " .. what .. "...")
    f.sub:SetText(more)
    f.buy.label:SetText("...")
  end
  f:Show()
end

function M:OnEnable()
  self:On("AUCTION_HOUSE_SHOW", function(mod) mod.open = true end)
  self:On("AUCTION_HOUSE_CLOSED", function(mod)
    mod.open = false
    if mod.pending then mod:Info("auction house closed while buying %s", tostring(mod.pending.e.name)) end
    mod.queue, mod.current, mod.quote, mod.pending, mod.bought = {}, nil, nil, nil, nil
    mod.known, mod.toFetch, mod.fetching = nil, nil, nil
    if mod.frame then mod.frame:Hide() end
  end)
  self:On("ITEM_SEARCH_RESULTS_UPDATED", self.OnItemResults)
  self:On("COMMODITY_PRICE_UPDATED", self.OnCommodityPrice)
  self:On("AUCTION_HOUSE_PURCHASE_COMPLETED", self.OnPurchaseDone)
  self:On("COMMODITY_PURCHASE_SUCCEEDED", self.OnPurchaseDone)
  self:On("COMMODITY_PURCHASE_FAILED", self.OnCommodityFailed)
  self:On("AUCTION_HOUSE_SHOW_ERROR", self.OnShowError)
  self:On("UI_ERROR_MESSAGE", self.OnUIError)
  self:On("PLAYER_MONEY", function(mod)
    if mod.pending and M.Paid(mod.pending) then mod:Finish(true) return end
    if mod.current or mod.pending then mod:Refresh() end
  end)
end

function M:Activity()
  local r = self.results or { bought = 0, failed = 0 }
  local now = self.current and ("buying " .. tostring(self.current.name)) or "nothing queued"
  return string.format("%s; this session %d bought, %d not bought", now, r.bought, r.failed)
end

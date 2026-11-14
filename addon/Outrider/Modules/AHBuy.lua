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
  self.queue[#self.queue + 1] = e
  self:Info("buy queued: %s%s", tostring(e.name), e.qty and (" x" .. e.qty) or "")
  if not self.current then self:Next() else self:Refresh() end
end

function M:Next()
  self.current, self.quote = nil, nil
  local e = table.remove(self.queue, 1)
  if not e then self:Refresh() return end
  self.current = e
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

function M:OnItemResults()
  local e = self.current
  if not e or e.commodity or self.quote then return end
  local n = C.Call("C_AuctionHouse.GetNumItemSearchResults", e.itemKey) or 0
  local best
  for i = 1, n do
    local r = C.Call("C_AuctionHouse.GetItemSearchResultInfo", e.itemKey, i)
    local price = type(r) == "table" and C.Readable(r.buyoutAmount)
    if type(price) == "number" and not r.containsOwnerItem and (not best or price < best.price) then
      best = { auctionID = r.auctionID, price = price }
    end
  end
  if not best then ns.Print("%s: no buyout left, skipped", tostring(e.name)) return self:Next() end
  self.quote = best
  self:Refresh()
end

function M:OnCommodityPrice(_, unitPrice, totalPrice)
  local e = self.current
  if not e or not e.commodity or self.quote then return end
  local total = C.Readable(totalPrice)
  if type(total) ~= "number" then return end
  self.quote = { price = total, unit = C.Readable(unitPrice) }
  self:Refresh()
end

-- The confirm click.
function M:Confirm()
  local e, q = self.current, self.quote
  if not (e and q) then return end
  if q.price > M.Money() then
    ns.Print("%s costs %s, more than you carry", tostring(e.name), ns.Prices.Money(q.price))
    return self:Next()
  end
  local ok, err
  if e.commodity then ok, err = pcall(C_AuctionHouse.ConfirmCommoditiesPurchase, e.itemID, e.qty)
  else ok, err = pcall(C_AuctionHouse.PlaceBid, q.auctionID, q.price) end
  self:Info("bought %s%s for %s: %s", tostring(e.name), e.qty and (" x" .. e.qty) or "", ns.Prices.Money(q.price), ok and "sent" or tostring(err))
  self:Next()
end

function M:Cancel()
  if self.current and self.current.commodity then pcall(C_AuctionHouse.CancelCommoditiesPurchase) end
  self.queue, self.current, self.quote = {}, nil, nil
  self:Refresh()
end

-- ------------------------------------------------------------ the bar
function M:Build()
  if self.frame then return self.frame end
  local anchor = rawget(_G, "AuctionHouseFrame") or UIParent
  local f = CreateFrame("Frame", "Outrider_AHBuy", anchor, ns.Theme:BackdropTemplate())
  ns.Theme:ApplyPanel(f, "raised")
  f:SetSize(460, 34)
  f:SetFrameStrata("DIALOG")
  f:SetPoint("BOTTOM", anchor, "TOP", 0, 6)
  f.text = UI.Text(f, "normal", "text")
  f.text:SetPoint("LEFT", 10, 0)
  f.text:SetWidth(250)
  f.text:SetJustifyH("LEFT")
  f.buy = UI:Button(f, "Buy", 90, function() M:Confirm() end)
  f.buy:SetPoint("RIGHT", -96, 0)
  f.cancel = UI:Button(f, "Cancel", 80, function() M:Cancel() end)
  f.cancel:SetPoint("RIGHT", -8, 0)
  f:Hide()
  self.frame = f
  return f
end

function M:Refresh()
  if not self.open then return end
  local f = self:Build()
  local e, q = self.current, self.quote
  if not e then f:Hide() return end
  local more = #self.queue > 0 and string.format("  |cff888888(+%d more)|r", #self.queue) or ""
  local what = tostring(e.name) .. (e.qty and (" x" .. e.qty) or "")
  if q then
    local short = q.price > M.Money()
    f.text:SetText(string.format("%s: %s%s%s", what, ns.Prices.Money(q.price), short and " |cffff5050(not enough gold)|r" or "", more))
    f.buy.label:SetText(short and "Skip" or "Buy")
  else
    f.text:SetText("Finding the cheapest " .. what .. "..." .. more)
    f.buy.label:SetText("...")
  end
  f:Show()
end

function M:OnEnable()
  self:On("AUCTION_HOUSE_SHOW", function(mod) mod.open = true end)
  self:On("AUCTION_HOUSE_CLOSED", function(mod)
    mod.open = false
    mod.queue, mod.current, mod.quote = {}, nil, nil
    if mod.frame then mod.frame:Hide() end
  end)
  self:On("ITEM_SEARCH_RESULTS_UPDATED", self.OnItemResults)
  self:On("COMMODITY_PRICE_UPDATED", self.OnCommodityPrice)
  self:On("PLAYER_MONEY", function(mod) if mod.current then mod:Refresh() end end)
end

function M:Activity()
  return self.current and ("buying " .. tostring(self.current.name)) or "nothing queued"
end

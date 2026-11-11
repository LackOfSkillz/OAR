-- Modules/AuctionHelper.lua  (P5-07 auction helper)
-- Our own small panel beside the auction house window (we never touch
-- Blizzard's, Auctionator's or TSM's frames). Gary posts with their buttons.
--   * Suggest(itemID, qty): market price (Prices) minus the undercut rule
--     (/ride undercut 2% | 50c, set once), never under the floor:
--     floor = max(vendor price, craft cost) + 5% AH cut + deposit per item.
--     Warns when the suggestion is under vendor value or the deposit eats
--     the profit.
--   * Undercut list: when the client reports Gary's own auctions
--     (OWNED_AUCTIONS_UPDATED, which Blizzard's own tab triggers), lists the
--     ones priced above the lowest price seen today. Reposting stays Gary's.
-- The item being sold is read from the Blizzard sell frames with pcall;
-- if those change, the panel just shows the undercut list.
-- Not yet: crate-sized stacks (needs Merchant's Favor crate data, P5-06).

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local M = ns:NewModule("AuctionHelper", {
  title = "Auction helper",
  phase = "P5",
  order = 73,
  defaults = { undercutPct = 2, undercutCopper = nil },
})
ns.AuctionHelper = M

M.CUT = 0.05
local DURATION = 1 -- 12 h

function M:CraftCost(itemID)
  local info = C.ItemInfo(itemID)
  if not (info and ns.CraftQueue) then return nil end
  for _, r in ipairs(ns.CraftQueue:Recipes()) do
    if r.name == info.name then
      local total = 0
      for reagent, n in pairs(r.reagents) do
        local ah, _, vendor = ns.Prices:Get(reagent)
        local p = ah or vendor
        if not p then return nil end
        total = total + p * n
      end
      return total
    end
  end
end

function M:Deposit(itemID, qty)
  local f = C.Resolve("C_AuctionHouse.CalculateCommodityDeposit")
  if type(f) ~= "function" then return nil end
  local ok, d = pcall(f, itemID, DURATION, qty or 1)
  d = ok and C.Readable(d) or nil
  return type(d) == "number" and d or nil
end

-- { price, floor, market, source, warnings = {...} } per item, copper
function M:Suggest(itemID, qty)
  qty = qty or 1
  local market, source, vendor = ns.Prices:Get(itemID)
  local s = self:Settings()
  local deposit = self:Deposit(itemID, qty)
  local per = deposit and deposit / qty or 0
  local base = math.max(vendor or 0, self:CraftCost(itemID) or 0)
  local floor = math.ceil((base + per) / (1 - self.CUT))
  local price
  if market then
    if s.undercutCopper then price = market - s.undercutCopper
    else price = math.floor(market * (1 - (s.undercutPct or 0) / 100)) end
  end
  local warnings = {}
  if price and price < floor then
    price = floor
    warnings[#warnings + 1] = "market is below your floor; suggesting the floor"
  end
  if not price then warnings[#warnings + 1] = "no AH price known yet: browse for it first" end
  if price and vendor and vendor > 0 and price * (1 - self.CUT) < vendor then
    warnings[#warnings + 1] = "you get more selling to a vendor"
  end
  -- profit after cut, costs and deposit; risky when the deposit you lose on
  -- an unsold auction is bigger than what a sale would earn
  if price and deposit and deposit > 0 and per > price * (1 - self.CUT) - base - per then
    warnings[#warnings + 1] = "the deposit is more than the likely profit"
  end
  return { price = price, floor = floor, market = market, source = source, deposit = deposit, warnings = warnings }
end

-- Gary's own auctions priced above the lowest seen today.
function M:Undercut()
  local out = {}
  local list = C.Call("C_AuctionHouse.GetOwnedAuctions")
  if type(list) ~= "table" then return out end
  for _, a in ipairs(list) do
    local id = a.itemKey and a.itemKey.itemID
    local mine = C.Readable(a.buyoutAmount)
    local low = id and ns.Prices:History(id)
    if type(mine) == "number" and low and low < mine and (a.status == nil or a.status == 0) then
      local info = C.ItemInfo(id)
      out[#out + 1] = { itemID = id, name = info and info.name or ("item " .. id), mine = mine, low = low }
    end
  end
  return out
end

local function sellItem()
  local ah = rawget(_G, "AuctionHouseFrame")
  if not ah then return nil end
  for _, key in ipairs({ "CommoditiesSellFrame", "ItemSellFrame" }) do
    local f = ah[key]
    if f and f.IsShown and f:IsShown() and f.GetItem then
      local ok, loc = pcall(f.GetItem, f)
      if ok and loc then
        local ok2, id = pcall(C_Item.GetItemID, loc)
        if ok2 and id then return id end
      end
    end
  end
end

function M:Build()
  if self.frame then return self.frame end
  local anchor = rawget(_G, "AuctionHouseFrame") or UIParent
  local f = CreateFrame("Frame", "Outrider_AuctionHelper", anchor, ns.Theme:BackdropTemplate())
  ns.Theme:ApplyPanel(f, "panel")
  f:SetSize(240, 170)
  f:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 6, 0)
  f.text = UI.Text(f, "small", "text")
  f.text:SetPoint("TOPLEFT", 8, -8)
  f.text:SetWidth(224) f.text:SetJustifyH("LEFT")
  self.frame = f
  return f
end

function M:Refresh()
  if not self.open then return end
  local f = self:Build()
  local lines = { "|cff8fd1ffOutrider|r" }
  local id = sellItem()
  if id then
    local r = self:Suggest(id, 1)
    lines[#lines + 1] = "Suggested: " .. ns.Prices.Money(r.price) .. (r.market and ("  (market " .. ns.Prices.Money(r.market) .. ")") or "")
    lines[#lines + 1] = "Floor: " .. ns.Prices.Money(r.floor)
    for _, w in ipairs(r.warnings) do lines[#lines + 1] = "|cffffc84d" .. w .. "|r" end
  end
  local under = self:Undercut()
  if #under > 0 then
    lines[#lines + 1] = "Undercut:"
    for i = 1, math.min(5, #under) do
      local u = under[i]
      lines[#lines + 1] = string.format("  %s %s < yours %s", u.name, ns.Prices.Money(u.low), ns.Prices.Money(u.mine))
    end
  end
  f.text:SetText(table.concat(lines, "\n"))
  f:SetShown(#lines > 1)
end

function M:OnEnable()
  self:On("AUCTION_HOUSE_SHOW", function(mod) mod.open = true mod:Refresh() end)
  self:On("AUCTION_HOUSE_CLOSED", function(mod) mod.open = false if mod.frame then mod.frame:Hide() end end)
  self:On("OWNED_AUCTIONS_UPDATED", function(mod)
    local n = #mod:Undercut()
    if n > 0 then mod:Info("undercut: %d of your auctions", n) end
    mod:Refresh()
  end)
  for _, e in ipairs({ "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_UPDATED", "BAG_UPDATE_DELAYED" }) do
    self:On(e, function(mod) if mod.open then mod:Refresh() end end)
  end
end

function M:OnDisable() if self.frame then self.frame:Hide() end end

function M:Activity()
  local s = self:Settings()
  return "posting suggestions beside the auction house; undercut " ..
    (s.undercutCopper and ns.Prices.Money(s.undercutCopper) or (tostring(s.undercutPct) .. "%"))
end

ns.AddCommand("undercut", "<N%> | <copper>c  how much under the market to suggest", function(arg)
  local s = M:Settings()
  local pct = arg and tonumber(arg:match("^(%d+%.?%d*)%%$"))
  local cop = arg and tonumber(arg:match("^(%d+)c$"))
  if pct then s.undercutPct, s.undercutCopper = pct, nil
  elseif cop then s.undercutCopper = cop
  else ns.Print("usage: /ride undercut 2%% or /ride undercut 50c (now: %s)", M:Activity()) return end
  ns.Print(M:Activity())
end)

-- Modules/AuctionSell.lua
-- Selling at the auction house (requirement 2026-11-22: feature parity with
-- Auctionator's selling). Two views in the shopping window:
--   * Sell bags: every stack in the bags that can go on the auction house,
--     one card per item. Outrider looks up the lowest price someone else
--     asks right now (one search at a time, only while the buy cart is idle),
--     undercuts it by the /ride undercut rule and puts the price on the card.
--     One click on Post puts it up (the game needs that click). Stackable
--     goods post the whole amount (Ctrl-click: one stack); gear posts one.
--     A price under the floor (vendor price + cut + deposit) or under half
--     the usual price asks for a second click. Click a card to type your own
--     price (kept for that item); right-click hides it from the list.
--   * My auctions: your auctions with what is cheapest now; undercut ones are
--     marked, and Cancel (one click each) takes one down.
-- Keys (Bindings.xml): post the top item, cancel the next undercut auction.
-- Every post and cancel is the player's own click or key press.

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local M = ns:NewModule("AuctionSell", {
  title = "Selling at the auction house",
  phase = "P5",
  order = 74,
  defaults = { duration = 2, autoScan = false },
})
ns.AuctionSell = M

M.DURATIONS = { { 1, "12 h" }, { 2, "24 h" }, { 3, "48 h" } }
M.FRESH, M.WAIT, M.ARM = 120, 3, 6
M.LOW_SHARE = 0.5 -- under half the usual price: ask for a second click
M.KEEP_POSTS = 20

function M:OnInitialize()
  local g = ns.db.global
  g.postHistory = type(g.postHistory) == "table" and g.postHistory or {}
  g.sellPrices = type(g.sellPrices) == "table" and g.sellPrices or {}
  g.sellHidden = type(g.sellHidden) == "table" and g.sellHidden or {}
  self.live = {}
end

local function money(c) return ns.Prices.Money(c) end

-- ------------------------------------------------------------ prices typed in
-- "12g 50s", "3s20c", "75c", "1.5g", "2" (a bare number is gold) -> copper
function M.ParseMoney(text)
  text = tostring(text or ""):lower():gsub("%s+", "")
  if text == "" then return nil end
  local bare = tonumber(text)
  if bare then return bare > 0 and math.floor(bare * 10000 + 0.5) or nil end
  local total, rest = 0, text
  for amount, unit in text:gmatch("(%d+%.?%d*)([gsc])") do
    local n = tonumber(amount)
    total = total + n * (unit == "g" and 10000 or unit == "s" and 100 or 1)
  end
  rest = rest:gsub("%d+%.?%d*[gsc]", "")
  if rest ~= "" or total <= 0 then return nil end
  return math.floor(total + 0.5)
end

-- ------------------------------------------------------------ bags
function M.Location(bag, slot)
  local IL = C.Resolve("ItemLocation")
  if type(IL) == "table" and type(IL.CreateFromBagAndSlot) == "function" then
    local ok, loc = pcall(IL.CreateFromBagAndSlot, IL, bag, slot)
    if ok and loc then return loc end
  end
end

function M.IsCommodityAt(loc, itemID)
  if loc then
    local st = C.Call("C_AuctionHouse.GetItemCommodityStatus", loc)
    local enum = C.Resolve("Enum.ItemCommodityStatus")
    if type(st) == "number" and st > 0 then
      return st == ((type(enum) == "table" and enum.Commodity) or 2)
    end
  end
  return ns.Deals and ns.Deals.IsCommodity(itemID) or false
end

-- Can this stack go on the auction house? Bound, quest, grey and locked
-- (being moved or posted) items can't.
function M.Sellable(bag, slot, ci, loc)
  if type(ci) ~= "table" or not ci.itemID then return false end
  if C.Readable(ci.isBound) == true or C.Readable(ci.isLocked) == true then return false end
  local q = C.Call("C_Container.GetContainerItemQuestInfo", bag, slot)
  if type(q) == "table" and (q.isQuestItem or q.questID) then return false end
  local info = C.ItemInfo(ci.itemID)
  if not info or (info.quality or 0) < 1 then return false end
  local bound = loc and C.Call("C_Item.IsBound", loc)
  if bound == true then return false end
  if bound == nil and C.Readable(ci.isBound) == nil and info.bindType == 1 then return false end
  return true
end

function M:Hidden() return ns.db.global.sellHidden end

-- { {itemID, name, count, stacks = {{bag, slot, n}}, commodity, itemKey} }, hiddenCount
function M:Stacks()
  local groups, list, hiddenN = {}, {}, 0
  local hidden = self:Hidden()
  for bag = 0, (rawget(_G, "NUM_BAG_SLOTS") or 4) do
    for slot = 1, C.NumSlots(bag) do
      local ci = C.Call("C_Container.GetContainerItemInfo", bag, slot)
      local loc = type(ci) == "table" and ci.itemID and M.Location(bag, slot)
      if M.Sellable(bag, slot, ci, loc) then
        local id = ci.itemID
        local n = tonumber(C.Readable(ci.stackCount)) or 1
        if hidden[id] then
          if not groups[id] then hiddenN = hiddenN + 1 groups[id] = false end
        else
          local g = groups[id]
          if not g then
            local info = C.ItemInfo(id)
            local key = loc and C.Call("C_AuctionHouse.GetItemKeyFromItem", loc)
            if type(key) ~= "table" then key = ns.Deals and ns.Deals.ItemKey(id) or { itemID = id } end
            g = { itemID = id, name = info and info.name or ("item " .. id), count = 0, stacks = {},
              commodity = M.IsCommodityAt(loc, id), itemKey = key }
            groups[id] = g
            list[#list + 1] = g
          end
          g.count = g.count + n
          g.stacks[#g.stacks + 1] = { bag = bag, slot = slot, n = n }
        end
      end
    end
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  return list, hiddenN
end

-- ------------------------------------------------------------ live prices
-- One search at a time, only while the buy cart is idle (they share the
-- game's search results). live[itemID] = { low, lowOwner, mine, count, at }
function M:Live(itemID)
  local l = self.live[itemID]
  if l and time() - l.at < M.FRESH then return l end
end

function M:Busy()
  local A = ns.AHBuy
  return A and (A.current or A.fetching or A.pending) and true or false
end

function M:Look(list)
  self.toLook = {}
  for _, g in ipairs(list or {}) do
    if g.itemKey and not self:Live(g.itemID) then self.toLook[#self.toLook + 1] = g end
  end
  self:Pump()
end

function M:Pump()
  if self.looking or not self.open or self:Busy() then return end
  local g = table.remove(self.toLook or {}, 1)
  if not g then
    if ns.AHBuy and ns.AHBuy.Pump then ns.AHBuy:Pump() end
    return
  end
  self.looking = g
  g.askedMore = nil
  pcall(C_AuctionHouse.SendSearchQuery, g.itemKey, { { sortOrder = 0, reverseSort = false } }, true)
  ns.Timer.After(M.WAIT, function()
    if M.looking == g then
      M.looking = nil
      M.live[g.itemID] = M.live[g.itemID] or { none = true, unknown = true, at = time() - M.FRESH + 30 }
      M:Pump()
    end
  end, "sell:look")
end

local function ownersText(r)
  local o = type(r) == "table" and C.Readable(r.owners)
  if type(o) == "table" and o[1] then return tostring(o[1]) end
end

-- Stackable goods: { low (cheapest someone else asks a unit), mine, count, lowOwner }
function M.CommodityPrices(itemID)
  local n = C.Call("C_AuctionHouse.GetNumCommoditySearchResults", itemID)
  if type(n) ~= "number" then n = C.Call("C_AuctionHouse.GetCommoditySearchResultInfo", itemID, 1) and 1 or 0 end
  local out = { count = 0 }
  for i = 1, n do
    local r = C.Call("C_AuctionHouse.GetCommoditySearchResultInfo", itemID, i)
    local p = type(r) == "table" and tonumber(C.Readable(r.unitPrice))
    if p then
      local q = tonumber(C.Readable(r.quantity)) or 0
      local own = tonumber(C.Readable(r.numOwnerItems)) or 0
      if own == 0 and C.Readable(r.containsOwnerItem) == true then own = q end
      out.count = out.count + q
      if own > 0 and (not out.mine or p < out.mine) then out.mine = p end
      if (q == 0 or q > own) and (not out.low or p < out.low) then out.low, out.lowOwner = p, ownersText(r) end
    end
  end
  return out
end

-- Gear and other single items: price per item, yours apart.
function M.ItemPrices(itemKey)
  local n = C.Call("C_AuctionHouse.GetNumItemSearchResults", itemKey) or 0
  local out = { count = 0 }
  for i = 1, n do
    local r = C.Call("C_AuctionHouse.GetItemSearchResultInfo", itemKey, i)
    local price = type(r) == "table" and tonumber(C.Readable(r.buyoutAmount))
    if price and price > 0 then
      local q = math.max(1, tonumber(C.Readable(r.quantity)) or 1)
      local per = math.floor(price / q)
      out.count = out.count + q
      if C.Readable(r.containsOwnerItem) == true then
        if not out.mine or per < out.mine then out.mine = per end
      elseif not out.low or per < out.low then
        out.low, out.lowOwner = per, ownersText(r)
      end
    end
  end
  return out
end

function M:Store(itemID, p)
  p.at = time()
  p.none = p.low == nil
  self.live[itemID] = p
  -- the log is the in-game check: the first lookups of a session in full
  self.logged = (self.logged or 0) + 1
  if self.logged <= 12 then
    self:Info("lowest now for item %d: %s (yours %s, %d for sale)", itemID, p.low and money(p.low) or "none", p.mine and money(p.mine) or "none", p.count or 0)
  end
  -- selling it: track its price history and best time to list
  local PH = ns.PriceHistory
  if PH and PH.enabled and PH.store then PH:Watch(itemID, "sell") end
  if p.low and ns.Prices then ns.Prices:Record(itemID, p.low, p.count) end
  self:Changed()
end

function M:OnCommodityResults(_, itemID)
  local g = self.looking
  if not (g and g.commodity and g.itemID == C.Readable(itemID)) then return end
  self.looking = nil
  self:Store(g.itemID, M.CommodityPrices(g.itemID))
  ns.Timer.After(0.2, function() M:Pump() end, "sell:pump")
end

function M:OnItemResults(_, itemKey)
  local g = self.looking
  if not g or g.commodity then return end
  local id = type(itemKey) == "table" and C.Readable(itemKey.itemID)
  if id and id ~= g.itemID then return end
  if ns.AHBuy and ns.AHBuy.NeedMore and ns.AHBuy.NeedMore(g) then return end
  self.looking = nil
  self:Store(g.itemID, M.ItemPrices(g.itemKey))
  ns.Timer.After(0.2, function() M:Pump() end, "sell:pump")
end

function M:Changed()
  local G = ns.GearShop
  if G and G.open and (G.mode == "sell" or G.mode == "auctions") then
    ns.Throttle("sell:refresh", 0.3, function() G:Refresh() end)
  end
end

-- ------------------------------------------------------------ the price
function M.Undercut(low, s)
  s = s or {}
  local p
  if s.undercutCopper then p = low - s.undercutCopper
  else p = math.floor(low * (1 - (s.undercutPct or 0) / 100)) end
  return math.max(1, p)
end

-- { price (a unit), why, floor, risky (reason or nil), live, usual }
function M:Price(g)
  local id = g.itemID
  local live = self:Live(id)
  local s = ns.AuctionHelper and ns.AuctionHelper:Settings() or {}
  local stats = ns.Prices:Statistics(id)
  local market, source = ns.Prices:Get(id)
  local qty = g.commodity and g.count or 1
  local sug = ns.AuctionHelper and ns.AuctionHelper:Suggest(id, qty) or {}
  local out = { floor = sug.floor, live = live, usual = stats and stats.median or market }
  local saved = ns.db.global.sellPrices[id]
  if saved then
    out.price, out.why = saved, "your price"
  elseif live and live.mine and (not live.low or live.mine <= live.low) then
    out.price, out.why = live.mine, "you're already the lowest: same price"
  elseif live and live.low then
    out.price, out.why = M.Undercut(live.low, s), "just under the lowest now"
  elseif market then
    out.price, out.why = M.Undercut(market, s), (live and live.none and not live.unknown) and "nobody else is selling: under the usual price" or ("under the usual price (" .. tostring(source) .. ")")
  end
  if out.price then
    if out.floor and out.price < out.floor then
      out.risky = string.format("under your floor %s (vendor value, cut and deposit)", money(out.floor))
    elseif out.usual and out.price < out.usual * M.LOW_SHARE then
      out.risky = string.format("under half the usual %s", money(out.usual))
    end
  end
  return out
end

-- ------------------------------------------------------------ posting
function M:PostHistory(itemID)
  local h = ns.db.global.postHistory
  h[itemID] = type(h[itemID]) == "table" and h[itemID] or {}
  return h[itemID]
end

function M:SetPrice(itemID, copper)
  if not itemID then return end
  ns.db.global.sellPrices[itemID] = copper
  self:Info("sell price for item %d: %s", itemID, copper and money(copper) or "cleared")
end

-- The player's click (or bound key). opts.one = one stack only;
-- opts.confirmed = the second click on a risky price.
-- Returns true | false, why | "confirm", why
function M:Post(g, opts)
  opts = opts or {}
  if not self.open then return false, "open the auction house first" end
  if C.InCombat() then return false, "not in combat" end
  local p = self:Price(g)
  if not p.price then return false, "no price yet: click the card and type one" end
  if p.risky and not opts.confirmed then
    self.armed = { itemID = g.itemID, at = time() }
    return "confirm", p.risky
  end
  if C.Call("C_AuctionHouse.IsThrottledMessageSystemReady") == false then
    return false, "the auction house is busy: press again in a moment"
  end
  local st = g.stacks[1]
  local loc = st and M.Location(st.bag, st.slot)
  if not loc then return false, "this client can't post from Outrider: use the game's Sell tab" end
  local dur = self:Settings().duration or 2
  local qty = g.commodity and (opts.one and st.n or g.count) or 1
  local ok, err
  if g.commodity then
    ok, err = pcall(C_AuctionHouse.PostCommodity, loc, dur, qty, p.price)
  else
    ok, err = pcall(C_AuctionHouse.PostItem, loc, dur, qty, nil, p.price)
  end
  self.armed = nil
  if not ok then
    self:Warn("post %s failed: %s", g.name, tostring(err))
    return false, "the game refused the post"
  end
  self.lastPost = { g = g, loc = loc, dur = dur, qty = qty, price = p.price, at = time() }
  local h = self:PostHistory(g.itemID)
  h[#h + 1] = { t = time(), unit = p.price, qty = qty }
  while #h > M.KEEP_POSTS do ns.Archive:Shift("auctionPosts", h) end
  local l = self.live[g.itemID]
  if l then l.mine = math.min(l.mine or p.price, p.price) end
  self:Info("posted %s x%d at %s each (%s, %s)", g.name, qty, money(p.price), p.why or "?", M.DURATIONS[dur] and M.DURATIONS[dur][2] or "?")
  return true
end

-- The game asks again for some prices (AUCTION_HOUSE_POST_WARNING): the
-- next click on the same card confirms through the game's own call.
function M:OnPostWarning()
  if self.lastPost and time() - self.lastPost.at < 30 then
    self.warned = self.lastPost
    self:Info("the game asks to confirm the post of %s", self.lastPost.g.name)
    self:Changed()
  end
end

function M:ConfirmWarned()
  local w = self.warned
  self.warned = nil
  if not w then return false end
  local f = w.g.commodity and C.Resolve("C_AuctionHouse.ConfirmPostCommodity") or C.Resolve("C_AuctionHouse.ConfirmPostItem")
  if type(f) ~= "function" then return false end
  local ok
  if w.g.commodity then ok = pcall(f, w.loc, w.dur, w.qty, w.price)
  else ok = pcall(f, w.loc, w.dur, w.qty, nil, w.price) end
  self:Info("post confirmed: %s (%s)", w.g.name, ok and "sent" or "refused")
  return ok
end

-- A Post click on a card: what happened, for the chat line and the card.
function M:Click(g, ctrl)
  if self.warned and self.warned.g.itemID == g.itemID then self:ConfirmWarned() return end
  local armed = self.armed and self.armed.itemID == g.itemID and time() - self.armed.at <= M.ARM
  local r, why = self:Post(g, { one = ctrl, confirmed = armed })
  if r == "confirm" then ns.Print("%s: %s. Click Post again to post anyway.", g.name, why)
  elseif not r then ns.Print("%s: %s", g.name, why) end
  self:Changed()
end

-- The bound key: post the top item of the list (or confirm the one waiting).
function M:PostNext()
  if not self.open then return end
  if self.warned then self:ConfirmWarned() return end
  local list = self:Stacks()
  local g
  if self.armed then
    for _, x in ipairs(list) do if x.itemID == self.armed.itemID then g = x break end end
  end
  g = g or list[1]
  if g then self:Click(g, false) end
end

-- ------------------------------------------------------------ my auctions
function M:QueryOwned()
  if not self.open then return end
  pcall(C_AuctionHouse.QueryOwnedAuctions, {})
end

function M.IsCommodityKey(itemKey, itemID)
  local info = itemKey and C.Call("C_AuctionHouse.GetItemKeyInfo", itemKey)
  if type(info) == "table" and C.Readable(info.isCommodity) ~= nil then return C.Readable(info.isCommodity) == true end
  return ns.Deals and ns.Deals.IsCommodity(itemID) or false
end

-- { auctionID, itemID, itemKey, name, qty, per, status, commodity, timeLeft, state }
-- state: "sold" | "undercut" | "lowest" | "checking"
function M:Owned()
  local list = C.Call("C_AuctionHouse.GetOwnedAuctions")
  local out = {}
  for _, a in ipairs(type(list) == "table" and list or {}) do
    local key = a.itemKey
    local id = key and C.Readable(key.itemID)
    local buyout = tonumber(C.Readable(a.buyoutAmount))
    if type(id) == "number" and buyout then
      local qty = math.max(1, tonumber(C.Readable(a.quantity)) or 1)
      local commodity = M.IsCommodityKey(key, id)
      local info = C.ItemInfo(id)
      local e = { auctionID = tonumber(C.Readable(a.auctionID)), itemID = id, itemKey = key,
        name = info and info.name or ("item " .. id), qty = qty, commodity = commodity,
        per = commodity and buyout or math.floor(buyout / qty), status = C.Readable(a.status),
        timeLeft = tonumber(C.Readable(a.timeLeftSeconds)) }
      local live = self:Live(id)
      if e.status == 1 then e.state = "sold"
      elseif not live then e.state = "checking"
      elseif live.low and live.low < e.per then e.state, e.low = "undercut", live.low
      else e.state = "lowest" end
      out[#out + 1] = e
    end
  end
  local rank = { undercut = 1, checking = 2, lowest = 3, sold = 4 }
  table.sort(out, function(a, b)
    if rank[a.state] ~= rank[b.state] then return rank[a.state] < rank[b.state] end
    return a.name < b.name
  end)
  return out
end

function M:Undercuts()
  local out = {}
  for _, a in ipairs(self:Owned()) do if a.state == "undercut" and a.auctionID then out[#out + 1] = a end end
  return out
end

function M:CheckOwned()
  local seen, list = {}, {}
  for _, a in ipairs(self:Owned()) do
    if a.state ~= "sold" and not seen[a.itemID] then
      seen[a.itemID] = true
      list[#list + 1] = { itemID = a.itemID, itemKey = a.itemKey, commodity = a.commodity, name = a.name }
    end
  end
  self:Look(list)
end

function M:Cancel(a)
  if not (a and a.auctionID) then return false, "this auction can't be cancelled from here" end
  if not ns.AuctionHelper then return false, "the auction helper is off" end
  local ok, why = ns.AuctionHelper:CancelAuction(a.auctionID)
  self:Info("cancel %s (auction %s): %s", a.name, tostring(a.auctionID), tostring(why))
  if ok then self.live[a.itemID] = nil end
  return ok, why
end

-- The bound key: cancel the next undercut auction.
function M:CancelNext()
  if not self.open then return end
  local a = self:Undercuts()[1]
  if not a then ns.Print("none of your auctions is undercut") return end
  local ok, why = self:Cancel(a)
  if not ok then ns.Print("%s: %s", a.name, tostring(why)) end
end

-- ------------------------------------------------------------ the views
function M.TimeLeft(sec)
  if not sec then return "" end
  if sec >= 3600 then return string.format("%dh left", math.floor(sec / 3600)) end
  return string.format("%dm left", math.max(1, math.floor(sec / 60)))
end

-- Lines for a card's tooltip: what's for sale now, the usual price, your posts.
function M:TipLines(itemID, live)
  local out = {}
  if live and live.low then
    out[#out + 1] = string.format("Lowest now: %s%s", money(live.low), live.lowOwner and (" by " .. live.lowOwner) or "")
  elseif live and live.none and not live.unknown then out[#out + 1] = "Nobody else is selling it right now" end
  if live and live.mine then out[#out + 1] = "Your lowest listing: " .. money(live.mine) end
  local stats = ns.Prices:Statistics(itemID)
  if stats then
    out[#out + 1] = string.format("Usual price %s (lowest each day, %d days: %s to %s)", money(stats.median), stats.count, money(stats.low), money(stats.high))
  end
  local h = ns.db.global.postHistory[itemID]
  if type(h) == "table" and #h > 0 then
    local parts = {}
    for i = #h, math.max(1, #h - 4), -1 do parts[#parts + 1] = money(h[i].unit) end
    out[#out + 1] = "You posted at: " .. table.concat(parts, ", ")
  end
  return out
end

function M:SellCards()
  local list, hiddenN = self:Stacks()
  local cards, armed = {}, self.armed
  for _, g in ipairs(list) do
    local p = self:Price(g)
    local isArmed = armed and armed.itemID == g.itemID and time() - armed.at <= M.ARM
    local warned = self.warned and self.warned.g.itemID == g.itemID
    local label = warned and "Confirm" or isArmed and "Post?" or "Post"
    local sub
    if p.price then
      sub = (g.commodity and string.format("%d at %s each = %s", g.count, money(p.price), money(p.price * g.count))
        or string.format("%s each", money(p.price))) .. "  |cff8f96a6" .. (p.why or "") .. "|r"
      if p.risky then sub = sub .. "  |cffffc84d" .. p.risky .. "|r" end
    elseif self.looking and self.looking.itemID == g.itemID then
      sub = "looking up the lowest price..."
    else
      sub = "no price known yet: click the card and type one"
    end
    cards[#cards + 1] = {
      itemID = g.itemID, item = { itemID = g.itemID }, title = g.name .. (g.count > 1 and (" x" .. g.count) or ""),
      sub = sub, price = p.price and (g.commodity and p.price * g.count or p.price) or nil,
      priceText = p.price and nil or "?",
      pill = p.live and p.live.low and ("lowest " .. money(p.live.low)) or nil,
      selected = self.selected == g.itemID,
      tip = self:TipLines(g.itemID, p.live),
      button = { label = label, primary = not p.risky or isArmed or warned,
        click = function() M:Click(g, C.Call("IsControlKeyDown") == true) end },
      onSelect = function() M.selected = (M.selected ~= g.itemID) and g.itemID or nil M:Changed() M:FocusPrice() end,
      onRight = function() M:Hidden()[g.itemID] = true ns.Print("%s hidden from Sell bags (/ride ahsell unhide)", g.name) M:Changed() end,
      group = g,
    }
  end
  self.visible = list
  local status
  if #cards == 0 then
    status = "Nothing in your bags can go on the auction house (bound, quest and grey items can't)."
  else
    status = string.format("Post puts it up at the price shown (%s). Click a card to type your own price; right-click hides it.",
      M.DURATIONS[self:Settings().duration or 2][2])
  end
  if hiddenN > 0 then status = status .. string.format("  |cff8f96a6%d hidden (/ride ahsell unhide).|r", hiddenN) end
  return cards, status
end

function M:AuctionCards()
  local cards = {}
  local owned = self:Owned()
  for _, a in ipairs(owned) do
    local pill, sub
    if a.state == "undercut" then
      pill = "|cffff6060undercut|r"
      sub = string.format("Yours %s, someone asks %s. Cancel, then post again from Sell bags.", money(a.per), money(a.low))
    elseif a.state == "lowest" then
      pill = "|cff7fff7flowest|r"
      sub = string.format("Yours %s each is the lowest. %s", money(a.per), M.TimeLeft(a.timeLeft))
    elseif a.state == "sold" then
      pill = "|cffffd100sold|r"
      sub = "Sold: the gold comes by mail."
    else
      sub = string.format("Yours %s each. Checking the lowest price...", money(a.per))
    end
    cards[#cards + 1] = {
      itemID = a.itemID, item = { itemID = a.itemID }, title = a.name .. (a.qty > 1 and (" x" .. a.qty) or ""),
      sub = sub, pill = pill, price = a.commodity and a.per * a.qty or a.per,
      tip = self:TipLines(a.itemID, self:Live(a.itemID)),
      button = a.state ~= "sold" and a.auctionID and { label = "Cancel", primary = a.state == "undercut",
        click = function()
          local ok, why = M:Cancel(a)
          if not ok then ns.Print("%s: %s", a.name, tostring(why)) end
        end } or nil,
    }
  end
  local n = #self:Undercuts()
  local status
  if #owned == 0 then status = "You have no auctions up. Post from Sell bags."
  elseif n > 0 then status = string.format("%d undercut. Cancel takes one down (it comes back by mail, the deposit is kept by the game).", n)
  else status = "None of your auctions is undercut right now." end
  return cards, status
end

-- GearShop asks: cards, status, searching, pos, total
function M:View(mode)
  if mode == "auctions" then return self:AuctionCards() end
  local cards, status = self:SellCards()
  -- look up the prices of the cards on screen
  local G = ns.GearShop
  local first = ((G and G.page or 1) - 1) * (G and G.PAGE or 8)
  local look = {}
  for i = first + 1, math.min(#cards, first + (G and G.PAGE or 8)) do look[#look + 1] = cards[i].group end
  self:Look(look)
  return cards, status
end

function M:OnPick(mode)
  if mode == "auctions" then self:QueryOwned() end
end

-- ------------------------------------------------------------ toolbar
function M:Toolbar(parent, mode)
  self.bars = self.bars or {}
  local bar = self.bars[mode]
  if not bar then
    bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(540, 28)
    if mode == "sell" then
      bar.chips = {}
      local x = 0
      for _, d in ipairs(M.DURATIONS) do
        local chip = UI:Chip(bar, d[2], function() M:Settings().duration = d[1] M:Changed() end)
        chip:SetPoint("LEFT", x, 0)
        x = x + chip:GetWidth() + 4
        UI.Tip(chip, "How long it stays up", "Longer costs a bigger deposit.")
        bar.chips[d[1]] = chip
      end
      bar.label = UI.Text(bar, "small", "muted")
      bar.label:SetPoint("LEFT", x + 10, 0)
      bar.price = UI:SearchBox(bar, 110, "price, like 1g 50s")
      bar.price:SetPoint("LEFT", bar.label, "RIGHT", 6, 0)
      bar.price:SetScript("OnEnterPressed", function(box)
        local id = M.selected
        if id then
          local t = box:GetText() or ""
          local c = M.ParseMoney(t)
          if t ~= "" and not c then ns.Print("type a price like 1g 50s, 30s or 75c") return end
          M:SetPrice(id, c)
        end
        box:ClearFocus()
        M:Changed()
      end)
      UI.Tip(bar.price, "Your price", "A price each for the selected item, kept for next time. Empty it and press Enter to go back to Outrider's price.")
    else
      bar.check = UI:Button(bar, "Check prices", 110, function() M.live = {} M:QueryOwned() M:CheckOwned() M:Changed() end)
      bar.check:SetPoint("LEFT", 0, 0)
      UI.Tip(bar.check, "Check prices", "Looks up the lowest price of each item you have up.")
      bar.cancel = UI:Button(bar, "Cancel next undercut", 160, function() M:CancelNext() end)
      bar.cancel:SetPoint("LEFT", bar.check, "RIGHT", 6, 0)
      UI.Tip(bar.cancel, "Cancel next undercut", "Takes down the next auction someone undercut. One click each. You can bind a key to this (Key Bindings, AddOns, Outrider).")
    end
    self.bars[mode] = bar
  end
  if mode == "sell" then
    local dur = self:Settings().duration or 2
    for k, chip in pairs(bar.chips) do chip:SetOn(k == dur) end
    local id = self.selected
    local info = id and C.ItemInfo(id)
    bar.label:SetText(id and ("Price each for " .. (info and info.name or "it") .. ":") or "Click a card to set its price")
    bar.price:SetShown(id ~= nil)
    if id and not (bar.price.HasFocus and bar.price:HasFocus()) then
      local saved = ns.db.global.sellPrices[id]
      bar.price:SetText(saved and (money(saved):gsub(" ", "")) or "")
    end
  else
    UI.SetPrimary(bar.cancel, #self:Undercuts() > 0)
  end
  return bar
end

function M:FocusPrice()
  local bar = self.bars and self.bars.sell
  if bar and bar.price and self.selected and bar.price.SetFocus then bar.price:SetFocus() end
end

-- ------------------------------------------------------------ events
function M:OnEnable()
  self:On("AUCTION_HOUSE_SHOW", function(mod)
    mod.open = true
    if mod:Settings().autoScan and ns.Prices and ns.Prices:ScanWait() == 0 then
      ns.Timer.After(1, function() if M.open then ns.Prices:FullScan() end end, "sell:autoscan")
    end
  end)
  self:On("AUCTION_HOUSE_CLOSED", function(mod) mod.open, mod.looking, mod.toLook, mod.armed, mod.warned = false, nil, nil, nil, nil end)
  self:On("COMMODITY_SEARCH_RESULTS_UPDATED", self.OnCommodityResults)
  self:On("ITEM_SEARCH_RESULTS_UPDATED", self.OnItemResults)
  self:On("AUCTION_HOUSE_POST_WARNING", self.OnPostWarning)
  self:On("AUCTION_HOUSE_AUCTION_CREATED", function(mod, _, id) mod:Info("auction created: %s", tostring(id)) mod:Changed() end)
  self:On("AUCTION_CANCELED", function(mod, _, id) mod:Info("auction cancelled: %s", tostring(id)) mod:QueryOwned() mod:Changed() end)
  self:On("OWNED_AUCTIONS_UPDATED", function(mod)
    -- once a session: the raw shape of one auction (is a stack's buyout per unit?)
    if not mod.ownedLogged then
      local list = C.Call("C_AuctionHouse.GetOwnedAuctions")
      local a = type(list) == "table" and list[1]
      if type(a) == "table" then
        mod.ownedLogged = true
        local key = a.itemKey
        mod:Info("owned auctions: %d; first item %s qty %s buyout %s status %s commodity %s", #list,
          tostring(key and C.Readable(key.itemID)), tostring(C.Readable(a.quantity)), tostring(C.Readable(a.buyoutAmount)),
          tostring(C.Readable(a.status)), tostring(key and M.IsCommodityKey(key, C.Readable(key.itemID))))
      end
    end
    local G = ns.GearShop
    if G and G.mode == "auctions" then mod:CheckOwned() end
    mod:Changed()
  end)
  self:On("BAG_UPDATE_DELAYED", function(mod) if mod.open then mod:Changed() end end)
end

function M:Activity()
  local s = self:Settings()
  return string.format("one-click posting at the auction house (%s)%s", M.DURATIONS[s.duration or 2][2], s.autoScan and "; price scan when it opens" or "")
end

ns.AddCommand("ahsell", "ahsell unhide | autoscan on|off | duration 12|24|48  selling at the auction house", function(arg)
  arg = tostring(arg or "")
  local s = M:Settings()
  if arg == "unhide" then
    ns.db.global.sellHidden = {}
    ns.Print("every item shows in Sell bags again")
  elseif arg:match("^autoscan") then
    s.autoScan = arg:match("on$") ~= nil
    ns.Print("price scan when the auction house opens: %s", s.autoScan and "on" or "off")
  elseif arg:match("^duration") then
    local h = tonumber(arg:match("(%d+)"))
    local map = { [12] = 1, [24] = 2, [48] = 3 }
    if map[h] then s.duration = map[h] ns.Print("auctions last %d hours", h) else ns.Print("usage: /ride ahsell duration 12|24|48") end
  else
    ns.Print("%s", M:Activity())
  end
end)

_G.BINDING_NAME_OUTRIDER_AHPOST = "Auction house: post the top item (Sell bags)"
_G.BINDING_NAME_OUTRIDER_AHCANCEL = "Auction house: cancel the next undercut auction"

-- Intelligence/EconomyOutcomes.lua  (OI03-06)
-- What your gold really did, kept apart from what it might be worth.
-- Driven by the outcome recorder (same opt-in switch, same store).
--
-- Realized flow: every money_in / money_out outcome (PLAYER_MONEY, the actual
-- change in your gold) gets a category from the window that was open (the
-- Ledger's context) and from what your own click just did:
--   auction sale (confirmed)  mail money taken from a sale invoice
--                             (GetInboxInvoiceInfo "seller")
--   transfer in / out         mail money from, or gold sent to, one of your
--                             own characters (not profit: it moves between
--                             your characters); sending includes the postage
--   auction deposit           AH money out right after you posted an auction
--   auction purchase          other AH money out
--   vendor sale / vendor spend, training, flight, bank, loot and quests,
--   mail (other), other
-- Confirmed sales: each sale invoice seen in the mailbox, with its price,
-- deposit returned and the auction house's cut (consignment). A cut the
-- client doesn't give is marked feeUnknown, never assumed.
-- Not sales: an auction that only disappeared from your list (AuctionHelper
-- marks those "unverified"); it might have expired or been cancelled.
-- Estimates are never profit: the loot value LootLog estimates is reported
-- separately, labelled as an estimate.
-- Hooks are post-hooks on functions your own clicks call (TakeInboxMoney,
-- AutoLootMailItem, SendMail, C_AuctionHouse.PostItem/PostCommodity): they
-- only note what happened, never act.

local _, ns = ...
local C = ns.Compat
local E = { WINDOW = 3, MAX_SALES = 200 }
ns.EconomyOutcomes = E

local function readable(v) if v == nil or C.IsSecret(v) then return nil end return C.Readable(v) end
local function short(name) return type(name) == "string" and name:match("^[^%-]+") or nil end

function E.OwnCharacter(name)
  local n = short(readable(name))
  if not (n and ns.db and ns.db.raw) then return false end
  for key in pairs(ns.db.raw.chars or {}) do
    if short(key) == n and key ~= ns.db.key then return true end
  end
  return false
end

local function recent(p, now) return p and now - p.at <= E.WINDOW end

-- the category of one gold change (pure apart from the noted clicks)
function E:Classify(delta, ctx, now)
  now = now or time()
  ctx = ctx or "loot & quests"
  if ctx == "mail" then
    if delta > 0 and recent(self.taken, now) then
      if self.taken.sale then return "auction sale (confirmed)" end
      if self.taken.own then return "transfer in" end
      return "mail (other)"
    end
    if delta < 0 and recent(self.sent, now) then
      return self.sent.own and "transfer out" or "mail sent (gold or postage)"
    end
    return "mail (other)"
  elseif ctx == "auction house" then
    if delta < 0 then return recent(self.posted, now) and "auction deposit" or "auction purchase" end
    return "auction house (other)"
  elseif ctx == "vendor" then
    return delta > 0 and "vendor sale" or "vendor spend"
  elseif ctx == "training" then return "training"
  elseif ctx == "flights" then return "flight"
  elseif ctx == "bank" then return "bank"
  end
  return delta > 0 and "loot and quests" or "other"
end

function E:Sales(store) store.sales = ns.KeepTable(store.sales, "Economy:char.outcomes.sales") or {} store.saleKeys = ns.KeepTable(store.saleKeys, "Economy:char.outcomes.saleKeys") or {} return store.sales end

-- read the sale invoices in the open mailbox (MAIL_INBOX_UPDATE)
function E:ScanInvoices(mod, now)
  now = now or time()
  local store = mod:Store()
  local sales = self:Sales(store)
  local n = tonumber(readable(C.Call("GetInboxNumItems"))) or 0
  for i = 1, math.min(n, 50) do
    local kind, item, buyer, bid, buyout, deposit, cut = C.CallAll("GetInboxInvoiceInfo", i)
    if readable(kind) == "seller" then
      local days = select(7, C.CallAll("GetInboxHeaderInfo", i))
      local key = table.concat({ tostring(readable(item)), tostring(readable(bid)), tostring(readable(buyout)), tostring(readable(deposit)),
        tostring(readable(cut)), tostring(math.floor((tonumber(readable(days)) or 0) * 24)) }, "|")
      if not store.saleKeys[key] then
        store.saleKeys[key] = now
        local price = tonumber(readable(buyout)) or tonumber(readable(bid))
        local fee = tonumber(readable(cut))
        sales[#sales + 1] = { at = now, item = type(readable(item)) == "string" and readable(item):sub(1, 80) or nil,
          price = price, deposit = tonumber(readable(deposit)), fee = fee, feeUnknown = fee == nil or nil,
          playSessionId = ns.PlaySession and ns.PlaySession:Id() }
        while #sales > E.MAX_SALES and ns.Archive:Shift("confirmedSales", sales, { path = "char.outcomes.sales", scope = "char" }) do end
      end
    end
  end
end

function E:Wire(mod)
  local function noteTake(i)
    if not mod.enabled then return end
    local _, _, sender = C.Call("GetInboxHeaderInfo", i)
    local kind = readable((C.Call("GetInboxInvoiceInfo", i)))
    E.taken = { at = time(), sale = kind == "seller", own = E.OwnCharacter(sender) }
  end
  if not E.hooked then
    E.hooked = true
    for _, name in ipairs({ "TakeInboxMoney", "AutoLootMailItem" }) do
      if type(rawget(_G, name)) == "function" then hooksecurefunc(name, function(i) ns.Safe("economy:" .. name, noteTake, i) end) end
    end
    if type(rawget(_G, "SendMail")) == "function" then
      hooksecurefunc("SendMail", function(to) if mod.enabled then E.sent = { at = time(), own = E.OwnCharacter(to) } end end)
    end
    local AH = rawget(_G, "C_AuctionHouse")
    if type(AH) == "table" then
      for _, name in ipairs({ "PostItem", "PostCommodity" }) do
        if type(AH[name]) == "function" then hooksecurefunc(AH, name, function() if mod.enabled then E.posted = { at = time() } end end) end
      end
    end
  end
  mod:On("MAIL_INBOX_UPDATE", function(m) E:ScanInvoices(m) end)
end

-- Realized and estimated, kept apart. events: OutcomeEvents (money ones are
-- used); sales: confirmed sale records; opts.estimatedLoot: an estimate.
function E.Summary(events, sales, opts)
  opts = opts or {}
  local by, profit, transfers = {}, 0, 0
  for _, e in ipairs(events or {}) do
    if (e.kind == "money_in" or e.kind == "money_out") and e.amount then
      local signed = e.kind == "money_in" and e.amount or -e.amount
      local cat = e.context or "other"
      by[cat] = (by[cat] or 0) + signed
      if cat == "transfer in" or cat == "transfer out" then transfers = transfers + signed else profit = profit + signed end
    end
  end
  local confirmed, fees, feeUnknown = 0, 0, 0
  for _, s in ipairs(sales or {}) do
    confirmed = confirmed + 1
    if s.fee then fees = fees + s.fee else feeUnknown = feeUnknown + 1 end
  end
  return { realized = by, realizedNet = profit, transfers = transfers,
    confirmedSales = confirmed, knownFees = fees, salesWithUnknownFee = feeUnknown,
    unverifiedAuctions = opts.unverified or 0,
    estimatedLoot = opts.estimatedLoot, estimatedLootIsEstimate = opts.estimatedLoot ~= nil or nil }
end

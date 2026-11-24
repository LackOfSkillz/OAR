-- Modules/Ledger.lua  (P5-08)
-- Where gold comes from and goes, per session and per character: every
-- PLAYER_MONEY change is booked to the window that is open at the time
-- (vendor, auction house, mail, trainer, flight, bank) or "loot & quests".
-- At logout the session total and gold per hour go to the log and to
-- ns.db.char.ledger (last 30 sessions). Read only.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Ledger", {
  title = "Gold ledger",
  phase = "P5",
  order = 73,
  defaults = {},
})
ns.Ledger = M

local CONTEXT_EVENTS = {
  MERCHANT_SHOW = "vendor", MERCHANT_CLOSED = false, AUCTION_HOUSE_SHOW = "auction house", AUCTION_HOUSE_CLOSED = false,
  MAIL_SHOW = "mail", MAIL_CLOSED = false, TRAINER_SHOW = "training", TRAINER_CLOSED = false,
  TAXIMAP_OPENED = "flights", TAXIMAP_CLOSED = false, BANKFRAME_OPENED = "bank", BANKFRAME_CLOSED = false,
}

function M:OnEnable()
  self.money = C.Call("GetMoney") or 0
  self.start, self.startMoney = time(), self.money
  self.book = {}
  self.context = nil
  for event, ctx in pairs(CONTEXT_EVENTS) do
    self:On(event, function(mod) mod.context = ctx or nil end)
  end
  self:On("PLAYER_MONEY", self.OnMoney)
  self:On("PLAYER_LOGOUT", self.OnLogout)
  self:On("OTR_PLAYSESSION", self.OnPlaySession)
end

function M:OnPlaySession(_, _, prev)
  if not (prev and prev.id) then return end
  for i = #(ns.db.char.ledger or {}), 1, -1 do
    local r = ns.db.char.ledger[i]
    if type(r) == "table" and r.playSessionId == prev.id and (r.segment or 1) == prev.segment then r.endReason = prev.reason break end
  end
end

-- saved ledger records joined into play sessions (a reload isn't a new session)
function M.Merged(list)
  return ns.PlaySession.Merge(list or ns.db.char.ledger, { sum = { "net" }, last = { "stop", "endReason" } })
end

function M:OnMoney()
  local now = C.Call("GetMoney") or self.money
  local delta = now - self.money
  self.money = now
  if delta == 0 then return end
  local ctx = self.context or "loot & quests"
  local b = self.book[ctx] or { gain = 0, spend = 0 }
  if delta > 0 then b.gain = b.gain + delta else b.spend = b.spend - delta end
  self.book[ctx] = b
end

function M:Summary()
  local net = (self.money or 0) - (self.startMoney or 0)
  local hours = math.max((time() - (self.start or time())) / 3600, 1 / 60)
  return net, net / hours
end

function M:OnLogout()
  local net, perHour = self:Summary()
  local c = ns.db.char
  c.ledger = ns.KeepTable(c.ledger, "Ledger:c.ledger") or {}
  local rec = { start = self.start, stop = time(), net = net, book = self.book }
  -- OI03-01: one record per segment of a play session; a reload's segment is
  -- marked when the next one starts (OnPlaySession) and Merged() joins them
  local P = ns.PlaySession
  if P and P:Id() then rec.playSessionId, rec.segment = P:Id(), P:Segment() end
  table.insert(c.ledger, rec)
  while #c.ledger > 30 and ns.Archive:Shift("goldLedger", c.ledger, { path = "char.ledger", scope = "char" }) do end
  local parts = {}
  for ctx, b in pairs(self.book) do
    parts[#parts + 1] = string.format("%s +%s -%s", ctx, ns.Prices.Money(b.gain), ns.Prices.Money(b.spend))
  end
  table.sort(parts)
  self:Info("session gold %s%s (%s per hour): %s", net < 0 and "-" or "+", ns.Prices.Money(math.abs(net)),
    ns.Prices.Money(math.floor(math.abs(perHour))), #parts > 0 and table.concat(parts, "; ") or "no change")
end

-- P9-01: this session and the saved sessions' gold per hour
function M:Snapshot()
  local net, perHour = self:Summary()
  local g = ns.Forecasts and ns.Forecasts.Gold(M.Merged(ns.db.char.ledger))
  return { sessionNet = net, sessionPerHour = math.floor(perHour), avgPerHour = g and math.floor(g.perHour),
    sessions = g and g.sessions }
end

function M:Activity()
  local net, perHour = self:Summary()
  return string.format("this session %s%s, %s per hour", net < 0 and "-" or "+", ns.Prices.Money(math.abs(net)),
    ns.Prices.Money(math.floor(math.abs(perHour))))
end

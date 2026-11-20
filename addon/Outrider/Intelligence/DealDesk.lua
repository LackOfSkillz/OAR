-- Intelligence/DealDesk.lua - opt-in read-only player-visible AH deal review.
-- Never issues AH searches, starts purchases, bids, posts, cancels or uses
-- protected actions. A live lot is current only while the AH remains open.
local _, ns = ...
local C = ns.Compat
local E = ns.IntelEconomy
local M = ns:NewModule("DealDesk", {
  title = "Deal Desk (read-only auction analysis)", phase = "P9", order = 106,
  defaultEnabled = false, defaults = { reserveCopper = 0 },
})
ns.DealDesk = M
M.MAX, M.AGE = 25, 120

function M:OnInitialize()
  self.lots = {}
end
function M:Reserve(gold)
  gold = tonumber(gold)
  if not gold or gold ~= gold or gold < 0 or gold > 10000000 or
      gold ~= math.floor(gold) then return false end
  self:Settings().reserveCopper = gold * 10000
  return true
end
function M:ConsiderLot(lot, context)
  if not self.enabled or not self.open then return nil, "auction house closed or feature off" end
  if type(lot) ~= "table" or type(context) ~= "table" then return nil, "no live facts" end
  local result, why = E.VendorFloor(lot, context)
  if not result then return nil, why end
  local id = tostring(lot.itemID) .. ":" .. tostring(lot.auctionID or "unknown")
  for i = #self.lots, 1, -1 do
    if self.lots[i].id == id then table.remove(self.lots, i) end
  end
  result.id = id
  result.expiresAt = context.now + M.AGE
  self.lots[#self.lots + 1] = result
  table.sort(self.lots, function(a, b)
    if a.profitCopper ~= b.profitCopper then return a.profitCopper > b.profitCopper end
    return a.id < b.id
  end)
  while #self.lots > self.MAX do table.remove(self.lots) end
  return result
end
function M:Rows()
  local now = time()
  local out = {}
  if not self.enabled or not self.open then return out end
  for _, row in ipairs(self.lots or {}) do
    if now <= row.expiresAt then out[#out + 1] = row end
  end
  self.lots = out
  return out
end
-- Triggered by a search the player (or their chosen AH addon) already made.
-- We do not send queries ourselves. Currency/IDs that are secret or missing
-- cannot be used for a deal and are silently suppressed.
function M:OnItemResults(_, itemKey)
  if not self.enabled or not self.open or C.InCombat() or
      type(itemKey) ~= "table" then return end
  local itemID = C.Readable(itemKey.itemID)
  if type(itemID) ~= "number" or itemID < 1 then return end
  local info = C.ItemInfo(itemID)
  local gold = C.Readable(C.Call("GetMoney"))
  if not info or type(info.sellPrice) ~= "number" or
      info.sellPrice <= 0 or type(gold) ~= "number" then return end
  local n = C.Call("C_AuctionHouse.GetNumItemSearchResults", itemKey)
  if type(n) ~= "number" then return end
  local now = time()
  for i = 1, math.min(n, 40) do
    local r = C.Call("C_AuctionHouse.GetItemSearchResultInfo", itemKey, i)
    if type(r) == "table" and C.Readable(r.containsOwnerItem) ~= true then
      local buyout = C.Readable(r.buyoutAmount)
      local quantity = C.Readable(r.quantity)
      local auctionID = C.Readable(r.auctionID)
      if type(auctionID) == "number" and type(buyout) == "number" and
          type(quantity) == "number" and quantity >= 1 then
        self:ConsiderLot({
          itemID = itemID, auctionID = auctionID, quantity = quantity,
          buyoutCopper = buyout, observedAt = now,
          -- A current AH listing is transferable by definition. No use,
          -- bind or purchase action is ever performed by this module.
          live = true, sellable = true, bound = false,
        }, { vendorUnitCopper = info.sellPrice, goldCopper = gold,
             reserveCopper = self:Settings().reserveCopper, now = now })
      end
    end
  end
  if self.window and self.window:IsShown() then self:Render() end
end
function M:Open()
  if not self.enabled then ns.Print("Deal Desk is off. Enable it in Outrider features.") return end
  if C.InCombat() then return end
  if not self.window then
    local p = ns.UI:Window("Outrider_IntelDealDesk", "Deal Desk - review only", 500, 330, self:Settings())
    p.entries = {}
    for i=1,5 do
      local row = {}
      row.label = ns.UI.Text(p.content, "small", "body")
      row.label:SetPoint("TOPLEFT", 8, -12 - (i - 1)*48)
      row.label:SetWidth(370)
      row.label:SetJustifyH("LEFT")
      row.button = ns.UI:Button(p.content, "Review", 70, function()
        local deal = row.deal
        if deal then
          ns.Print("Live lot item %d x%d: buyout %s, NPC total %s, margin %s. Recheck auction before buying manually.",
            deal.itemID, deal.quantity, ns.Prices.Money(deal.costCopper),
            ns.Prices.Money(deal.npcTotalCopper), ns.Prices.Money(deal.profitCopper))
        end
      end)
      row.button:SetPoint("TOPLEFT", 385, -10 - (i - 1)*48)
      p.entries[i] = row
    end
    self.window = p
  end
  self:Render()
  self.window:Show()
end
function M:Render()
  if not self.window then return end
  local rows = self:Rows()
  for i, ui in ipairs(self.window.entries) do
    local d = rows[i]
    ui.deal = d
    ui.label:SetText(d and string.format("Item %d x%d: possible %s NPC margin",
        d.itemID, d.quantity, ns.Prices.Money(d.profitCopper))
      or (i == 1 and "No currently verified profitable listings. Search the AH yourself." or ""))
    ui.button:SetShown(d ~= nil)
  end
end
function M:OnEnable()
  self.lots = {}
  self.open = false
  self:On("AUCTION_HOUSE_SHOW", function(mod) mod.open = true end)
  self:On("AUCTION_HOUSE_CLOSED", function(mod)
    mod.open, mod.lots = false, {}
    if mod.window then mod.window:Hide() end
  end)
  self:On("ITEM_SEARCH_RESULTS_UPDATED", self.OnItemResults)
end
function M:OnDisable()
  self.open, self.lots = false, {}
  if self.window then self.window:Hide() end
end
function M:Activity()
  return string.format("%d live lots, %s", #(self.lots or {}),
    self.open and "auction house open" or "closed")
end
ns.AddCommand("deals", "show | reserve <wholeGold>  review, never auto-purchase", function(arg)
  arg = type(arg) == "string" and arg:lower() or ""
  local reserve = arg:match("^%s*reserve%s+(%d+)%s*$")
  if reserve then
    ns.Print(M:Reserve(reserve) and ("Deal Desk gold reserve: " .. reserve .. "g")
      or "Invalid reserve.")
  elseif arg == "" or arg:match("^%s*show%s*$") then M:Open()
  else ns.Print("Usage: /ride deals show|reserve <wholeGold>") end
end)

-- Read-only vendor-floor checks. Never sends auction queries or purchases.
local _, ns = ...
local E = {}
ns.IntelEconomy = E
local function money(n)
  return type(n) == "number" and n == math.floor(n) and n >= 0 and n < 1000000000000
end
-- lot must come from a player-visible current auction, never historic daily lows.
-- A buyout is the total stack cost; NPC resale value is per item.
function E.VendorFloor(lot, context)
  if type(lot) ~= "table" or type(context) ~= "table" then return nil, "missing evidence" end
  for _, key in ipairs({"itemID", "quantity", "buyoutCopper", "observedAt"}) do
    if not money(lot[key]) then return nil, "invalid lot " .. key end
  end
  if lot.itemID == 0 or lot.quantity < 1 or lot.quantity > 100000 then return nil, "invalid quantity" end
  if lot.live ~= true or lot.sellable ~= true or lot.bound ~= false then
    return nil, "unverified live sale eligibility"
  end
  for _, key in ipairs({"vendorUnitCopper", "goldCopper", "reserveCopper", "now"}) do
    if not money(context[key]) then return nil, "invalid money/time " .. key end
  end
  if context.vendorUnitCopper == 0 then return nil, "no NPC value" end
  local age = context.maxAgeSec or 120
  if not money(age) or age > 600 or context.now < lot.observedAt or
      context.now - lot.observedAt > age then return nil, "stale lot" end
  if context.goldCopper < context.reserveCopper or
      context.goldCopper - context.reserveCopper < lot.buyoutCopper then
    return nil, "gold reserve"
  end
  local vendorTotal = lot.quantity * context.vendorUnitCopper
  if vendorTotal >= 1000000000000 then return nil, "overflow" end
  local profit = vendorTotal - lot.buyoutCopper
  if profit <= 0 then return nil, "not profitable" end
  return { itemID = lot.itemID, quantity = lot.quantity,
    costCopper = lot.buyoutCopper, npcTotalCopper = vendorTotal,
    profitCopper = profit, observedAt = lot.observedAt,
    source = "verified live listing and vendor value",
    actionable = true, purchaseManual = true, executesAction = false }
end
function E.HistoricalHint(itemID, price, ageDays)
  if not money(itemID) or itemID == 0 or not money(price) or price == 0 or
      not money(ageDays) then return nil end
  return { itemID = itemID, priceCopper = price, ageDays = ageDays, actionable = false,
    note = "Historical price; check a live listing before buying" }
end

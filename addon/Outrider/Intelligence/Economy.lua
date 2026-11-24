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

-- AH resale and crafting are hypotheses, never guaranteed profits. Do not
-- invent sale probability, time to sell, deposits, fees or liquidity.
function E.ResaleHypothesis(input)
  if type(input) ~= "table" then return nil, "missing resale facts" end
  for _, key in ipairs({"itemID", "quantity", "totalCostCopper", "expectedUnitCopper"}) do
    if not money(input[key]) then return nil, "invalid " .. key end
  end
  if input.itemID == 0 or input.quantity == 0 or input.quantity > 100000 then return nil, "invalid lot" end
  local value = input.quantity * input.expectedUnitCopper
  if value >= 1000000000000 then return nil, "overflow" end
  local known = money(input.feeCopper) and money(input.depositCopper)
  local net = known and (value - input.feeCopper - input.depositCopper - input.totalCostCopper) or nil
  return { itemID = input.itemID, quantity = input.quantity,
    totalCostCopper = input.totalCostCopper, expectedGrossCopper = value,
    possibleNetCopper = net, liquidity = "unknown", actionable = false,
    certainty = "hypothesis", reason = known and
      "No verified probability or timing for resale" or
      "Unknown fees/deposits and no verified resale probability" }
end

-- Only record player-confirmed outcomes. Never turn a disappeared owned
-- auction into a sale, profit, or learned success.
function E.RecordOutcome(char, outcome)
  if type(char) ~= "table" or type(outcome) ~= "table" or outcome.confirmed ~= true then return false end
  if type(outcome.kind) ~= "string" or
     (outcome.kind ~= "vendor" and outcome.kind ~= "resale" and outcome.kind ~= "craft") then return false end
  if not money(outcome.itemID) or outcome.itemID == 0 or
     type(outcome.netCopper) ~= "number" or outcome.netCopper ~= outcome.netCopper or
     math.abs(outcome.netCopper) >= 1000000000000 then return false end
  local st = ns.KeepTable(char.intelEconomyOutcomes, "Economy:char.intelEconomyOutcomes") or {}
  char.intelEconomyOutcomes = st
  st[#st + 1] = { kind = outcome.kind, itemID = outcome.itemID,
    netCopper = math.floor(outcome.netCopper), at = time(), confirmed = true }
  while #st > 100 and ns.Archive:Shift("economyOutcomes", st, { path = "char.intelEconomyOutcomes", scope = "char" }) do end
  return true
end

function E.GoldPerHour(profitCopper, elapsedSeconds, timingSource)
  if type(profitCopper) ~= "number" or profitCopper ~= profitCopper or
     not money(elapsedSeconds) or elapsedSeconds < 60 or
     timingSource ~= "observed" then return nil end
  local v = profitCopper * 3600 / elapsedSeconds
  if math.abs(v) >= 1000000000000 then return nil end
  return math.floor(v + (v >= 0 and 0.5 or -0.5))
end

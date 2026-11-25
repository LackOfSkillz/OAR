-- Intelligence/Market.lua  (OI05-15 realized economics, OI05-16 profession costs)
-- OI05-15: what selling actually did, apart from what it might do.
--   Realized(sales)  confirmed sales only (mailbox sale invoices recorded by
--                    EconomyOutcomes): count, gross, the auction house's cut and
--                    deposits where the client gave them; a sale whose cut is
--                    unknown has no net. An auction that only disappeared
--                    (AuctionHelper "unverified") is counted apart, never a sale.
--   Compare(itemID)  vendor (the item's own sell price, exact) vs auction house
--                    (your observed lowest prices: median, how many, over how
--                    many days; under MIN_SAMPLES it's "thin data"; the cut is
--                    the share measured from your own sales, else unknown; the
--                    deposit unknown) vs crafting it (reagents at known prices,
--                    else unknown). Market depth isn't known: said every time.
--   SaleChance(sold, posted) only from at least MIN_POSTS of your own posts.
-- OI05-16: skill-up paths for one profession from the recipes you know:
--   Paths(prof)  each recipe's colour from the client (orange gives a point
--                every craft; yellow and green "chance unknown" since the rates
--                aren't readable; grey none), the reagent cost (your own stock
--                first, counted as owned not free, then known prices), and cost
--                per sure point for orange. Observed skill-ups (Outcomes
--                profession events) are reported apart from these estimates.
-- Nothing here buys, posts or crafts.

local _, ns = ...
local C = ns.Compat
local M = { MIN_SAMPLES = 3, MIN_POSTS = 5 }
ns.Market = M
M.COLOURS = { [0] = "orange", [1] = "yellow", [2] = "green", [3] = "grey" }

function M.Realized(sales, unverified)
  local out = { sales = 0, gross = 0, fees = 0, deposits = 0, net = 0, feeUnknown = 0, unverified = unverified or 0, byItem = {} }
  for _, s in ipairs(sales or {}) do
    if tonumber(s.price) then
      out.sales = out.sales + 1
      out.gross = out.gross + s.price
      local key = s.item or "?"
      local b = out.byItem[key] or { n = 0, gross = 0, net = 0, netKnown = 0 }
      out.byItem[key] = b
      b.n, b.gross = b.n + 1, b.gross + s.price
      if tonumber(s.deposit) then out.deposits = out.deposits + s.deposit end
      if tonumber(s.fee) then
        out.fees = out.fees + s.fee
        out.net = out.net + s.price - s.fee
        b.net, b.netKnown = b.net + s.price - s.fee, b.netKnown + 1
      else
        out.feeUnknown = out.feeUnknown + 1
      end
    end
  end
  out.cutShare = out.gross > 0 and out.fees > 0 and out.feeUnknown == 0 and out.fees / out.gross or nil
  return out
end

local function store()
  local O = ns.Outcomes
  local ok, s = pcall(function() return O and O.Store and O:Store() end)
  return ok and type(s) == "table" and s or {}
end

local function unverifiedCount()
  local list = ns.db and ns.db.char.auctionSales or {}
  local n = 0
  for _, r in ipairs(list) do if tostring(r.result):find("unverified", 1, true) then n = n + 1 end end
  return n
end

function M.Current() return M.Realized(store().sales, unverifiedCount()) end

function M.SaleChance(sold, posted)
  sold, posted = tonumber(sold), tonumber(posted)
  if not (sold and posted) or posted < M.MIN_POSTS then return nil, "fewer than " .. M.MIN_POSTS .. " of your own posts" end
  return math.min(1, sold / posted)
end

local function priceOf(id)
  local P = ns.Prices
  local v = P and P.Get and (P:Get(id))
  return tonumber(v)
end

-- the reagent cost of one craft: owned units first (counted, not free), then prices
function M.ReagentCost(reagents, have)
  local cost, owned, unpriced = 0, 0, {}
  have = have or {}
  for id, per in pairs(reagents or {}) do
    id = tonumber(id) or id
    local mine = math.min(per, have[id] or 0)
    owned = owned + mine
    local p = priceOf(id)
    if p then cost = cost + math.floor(p * per) -- an owned unit is worth what it would sell for
    else unpriced[#unpriced + 1] = id end
  end
  return { copper = #unpriced == 0 and cost or nil, partial = #unpriced > 0 and cost or nil, ownedUnits = owned, unpriced = unpriced }
end

function M.Compare(itemID, opts)
  opts = opts or {}
  local info = C.ItemInfo(itemID)
  local out = { itemID = itemID, notes = { "market depth (how many sell) isn't known" } }
  out.vendor = info and tonumber(info.sellPrice) or nil
  local P = ns.Prices
  local st = P and P.Statistics and P:Statistics(itemID)
  if st then
    out.ah = { median = math.floor(st.median), samples = st.count, days = st.days, source = st.source,
      thin = st.count < M.MIN_SAMPLES or nil }
    local cut = opts.cutShare or M.Current().cutShare
    if cut then out.ah.afterCut = math.floor(st.median * (1 - cut)) out.ah.cutSource = "measured from your sales"
    else out.ah.cutUnknown = true end
    out.ah.depositUnknown = true
  else
    out.ah = { unknown = "no auction prices seen for this item" }
  end
  local makes = ns.Supply and ns.Supply.Makes and ns.Supply.Makes()[itemID]
  if makes then
    local rc = M.ReagentCost(makes.reagents)
    out.craft = { copper = rc.copper and math.floor(rc.copper / makes.makes) or nil, unpriced = #rc.unpriced > 0 and rc.unpriced or nil,
      yieldUnknown = not makes.makesKnown or nil }
  end
  return out
end

-- skill-up paths for one profession
function M.Paths(prof, have)
  local p = ns.db and ns.db.char.professions and ns.db.char.professions[prof]
  if type(p) ~= "table" then return nil, "no recipes recorded for " .. tostring(prof) end
  local rows = {}
  for id, r in pairs(p.recipes or {}) do
    if type(r) == "table" and r.learned ~= false and r.reagents and next(r.reagents) then
      local diff = tonumber(r.diff)
      local colour = diff and M.COLOURS[diff] or "unknown"
      local rc = M.ReagentCost(r.reagents, have)
      local row = { id = id, name = r.name or tostring(id), colour = colour, cost = rc.copper, partialCost = rc.partial,
        unpriced = #rc.unpriced > 0 and rc.unpriced or nil, ownedUnits = rc.ownedUnits }
      if colour == "orange" then
        local pts = tonumber(r.skillUps) or 1
        row.pointsPerCraft, row.sure = pts, true
        row.costPerPoint = rc.copper and math.floor(rc.copper / pts) or nil
      elseif colour == "yellow" or colour == "green" then
        row.chance = "chance unknown (the rate isn't readable)"
      elseif colour == "grey" then
        row.pointsPerCraft = 0
      end
      rows[#rows + 1] = row
    end
  end
  local rank = { orange = 1, yellow = 2, green = 3, unknown = 4, grey = 5 }
  table.sort(rows, function(a, b)
    if rank[a.colour] ~= rank[b.colour] then return rank[a.colour] < rank[b.colour] end
    local x, y = a.costPerPoint or a.cost, b.costPerPoint or b.cost
    if (x ~= nil) ~= (y ~= nil) then return x ~= nil end
    if x and y and x ~= y then return x < y end
    return a.name < b.name
  end)
  local observed = 0
  for _, e in ipairs(store().events or {}) do
    if e.kind == "profession_skill" and e.subject == "prof:" .. prof:gsub("[^%w]", "") then observed = observed + (tonumber(e.amount) or 1) end
  end
  return { prof = prof, rows = rows, observedSkillUps = observed, note = "estimates; observed skill-ups are counted apart" }
end

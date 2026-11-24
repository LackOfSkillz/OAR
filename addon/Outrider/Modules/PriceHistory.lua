-- Modules/PriceHistory.lua
-- Price history with graphs, and the best time to list (Gary, 2026-11-24:
-- "price tracking of items with graphs over time and best time of
-- day/week/month to list an item").
--
-- What is measured: the cheapest listing on the auction house each time
-- Outrider sees an item (a full scan, browsing, searching, the sell tab), and
-- how many are for sale. That is the price you'd compete with, not what
-- things sold for: nothing on the client tells us sales. A "good time to
-- list" is when the cheapest listing is usually higher than that week's
-- normal price, i.e. less undercutting.
--
-- Storage, account-wide in ns.db.global.priceLog:
--   watch = { [itemID] = { at = time, why = "sell"|"search"|"manual" } }
--   items = { [itemID] = { {time, copper, qty?}, ... } }  oldest first
-- Only tracked items keep this detail (one sample per hour, the lowest; 120
-- days; 720 rows), so SavedVariables stay small. Items you sell or search are
-- tracked by themselves; the Track button adds any other. Shopping list items
-- count as tracked. Every other item still has the 14-day daily low in
-- ns.Prices, which the graph shows too. Reading only: nothing is bought or
-- posted.

local _, ns = ...
local C, UI, Theme = ns.Compat, ns.UI, ns.Theme
local M = ns:NewModule("PriceHistory", {
  title = "Price history and best time to list",
  phase = "P5",
  order = 73,
  defaults = { tooltip = true },
})
ns.PriceHistory = M

M.KEEP_DAYS = 120
M.MAX_ROWS = 720
M.MAX_WATCH = 300
M.GAP = 3600          -- one sample per item per hour
M.MIN_BUCKET = 3      -- samples a time slot needs before it counts
M.MIN_SAMPLES = 12    -- samples an item needs before any advice
M.DAY = 86400

-- time slots (your PC's clock)
M.BLOCKS = { "Late night", "Early morning", "Morning", "Afternoon", "Evening", "Night" }
M.BLOCK_HOURS = { "0-4", "4-8", "8-12", "12-16", "16-20", "20-24" }
M.WEEKDAYS = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
M.WEEKDAY_NAMES = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
M.MONTH = { "Start", "Middle", "End" }
M.MONTH_DAYS = { "1-10", "11-20", "21-31" }

function M:OnInitialize()
  local g = ns.db.global
  local s = type(g.priceLog) == "table" and g.priceLog or {}
  s.items = type(s.items) == "table" and s.items or {}
  s.watch = type(s.watch) == "table" and s.watch or {}
  g.priceLog = s
  self.store = s
end

local function median(list)
  local n = #list
  if n == 0 then return nil end
  local t = {}
  for i = 1, n do t[i] = list[i] end
  table.sort(t)
  if n % 2 == 1 then return t[(n + 1) / 2] end
  return (t[n / 2] + t[n / 2 + 1]) / 2
end
M.Median = median

-- ------------------------------------------------------------ tracking
local function inShopping(id)
  local P = ns.Prices
  if not (P and P.ShoppingLists) then return false end
  local ok, lists = pcall(P.ShoppingLists, P)
  if not ok or type(lists) ~= "table" then return false end
  for _, list in pairs(lists) do if type(list) == "table" and list[id] then return true end end
  return false
end

function M:IsTracked(id)
  id = tonumber(id)
  if not (id and self.store) then return false end
  return self.store.watch[id] ~= nil or inShopping(id)
end

function M:WatchCount()
  local n = 0
  for _ in pairs(self.store.watch) do n = n + 1 end
  return n
end

-- Track an item. Full list: the oldest automatic one makes room; items you
-- tracked by hand are never pushed out.
function M:Watch(id, why)
  id = tonumber(id)
  if not (id and id > 0 and self.store) then return false end
  local w = self.store.watch
  local now = time()
  if w[id] then
    w[id].at = now
    if why == "manual" then w[id].why = "manual" end
    return true
  end
  if self:WatchCount() >= M.MAX_WATCH then
    local oldID, oldAt
    for k, e in pairs(w) do
      if e.why ~= "manual" and (not oldAt or (e.at or 0) < oldAt) then oldID, oldAt = k, e.at or 0 end
    end
    if not oldID then return false end
    w[oldID] = nil
  end
  w[id] = { at = now, why = why or "manual" }
  self:Debug("tracking item %d (%s)", id, why or "manual")
  return true
end

-- Stop tracking; the samples stay until they age out.
function M:Unwatch(id)
  id = tonumber(id)
  if id and self.store then self.store.watch[id] = nil end
end

-- One sighting of the cheapest listing (copper per item) and how many are up.
function M:Seen(id, copper, qty, t)
  id, copper = tonumber(id), tonumber(copper)
  if not (self.store and id and copper and copper > 0) then return false end
  if not self:IsTracked(id) then return false end
  t = t or time()
  qty = tonumber(qty)
  local rows = self.store.items[id]
  if not rows then rows = {} self.store.items[id] = rows end
  local last = rows[#rows]
  if last and math.floor(last[1] / M.GAP) == math.floor(t / M.GAP) then
    if copper < last[2] then last[2] = copper if qty then last[3] = qty end
    elseif qty and not last[3] then last[3] = qty end
    return true
  end
  if last and t < last[1] then return false end -- clock went backwards: skip
  rows[#rows + 1] = { t, copper, qty }
  while #rows > M.MAX_ROWS do table.remove(rows, 1) end
  local cut = t - M.KEEP_DAYS * M.DAY
  while rows[1] and rows[1][1] < cut do table.remove(rows, 1) end
  self.added = (self.added or 0) + 1
  return true
end

-- Drop history nobody tracks any more once it is old.
function M:Prune(now)
  now = now or time()
  local cut = now - 30 * M.DAY
  for id, rows in pairs(self.store.items) do
    local last = rows[#rows]
    if not last or (not self:IsTracked(id) and last[1] < cut) then self.store.items[id] = nil end
  end
end

-- ------------------------------------------------------------ the graph
-- One point per day: { day, low, n } for the last `days` days (nil = all),
-- from the hourly samples and the 14-day daily lows in ns.Prices.
function M:Daily(id, days, now)
  id = tonumber(id)
  now = now or time()
  local today = math.floor(now / M.DAY)
  local from = days and (today - days + 1) or -math.huge
  local byDay = {}
  local function add(d, p)
    if d >= from and d <= today and p and p > 0 then
      local e = byDay[d]
      if not e then byDay[d] = { d, p, 1 } else
        if p < e[2] then e[2] = p end
        e[3] = e[3] + 1
      end
    end
  end
  for _, r in ipairs((self.store and self.store.items[id]) or {}) do add(math.floor(r[1] / M.DAY), r[2]) end
  local P = ns.Prices
  for _, r in ipairs((P and P.db and P.db[id]) or {}) do add(tonumber(r[1]) or 0, tonumber(r[2])) end
  local out = {}
  for _, e in pairs(byDay) do out[#out + 1] = e end
  table.sort(out, function(a, b) return a[1] < b[1] end)
  return out
end

-- Numbers above the graph: now, usual, low, high, and the trend (last 7
-- days against the 3 weeks before).
function M:Summary(id, days, now)
  now = now or time()
  local pts = self:Daily(id, days, now)
  if #pts == 0 then return nil end
  local lows = {}
  local lo, hi = math.huge, 0
  for i, p in ipairs(pts) do
    lows[i] = p[2]
    if p[2] < lo then lo = p[2] end
    if p[2] > hi then hi = p[2] end
  end
  local rows = self.store.items[tonumber(id)]
  local latest = rows and rows[#rows]
  local cur = pts[#pts][2]
  local curQty
  if latest and math.floor(latest[1] / M.DAY) == pts[#pts][1] then cur, curQty = latest[2], latest[3] end
  local today = math.floor(now / M.DAY)
  local recent, before = {}, {}
  for _, p in ipairs(self:Daily(id, 28, now)) do
    if p[1] > today - 7 then recent[#recent + 1] = p[2] else before[#before + 1] = p[2] end
  end
  local trend, change
  local r, b = median(recent), median(before)
  if r and b and #recent >= 2 and #before >= 3 and b > 0 then
    change = (r - b) / b
    trend = change > 0.05 and "up" or change < -0.05 and "down" or "steady"
  end
  return { now = cur, qty = curQty, usual = median(lows), low = lo, high = hi, days = #pts,
    trend = trend, change = change, points = pts }
end

-- ------------------------------------------------------------ best time
-- Each sample compared with that week's normal price (the median of the
-- daily medians 3 days either side), so a price that drifted all month
-- doesn't make one weekday look good. Then grouped by time of day, weekday
-- and part of the month.
function M:BestTimes(id)
  id = tonumber(id)
  local rows = (self.store and self.store.items[id]) or {}
  local dayVals = {}
  for _, r in ipairs(rows) do
    local d = math.floor(r[1] / M.DAY)
    dayVals[d] = dayVals[d] or {}
    table.insert(dayVals[d], r[2])
  end
  local dayMed, dayList = {}, {}
  for d, v in pairs(dayVals) do dayMed[d] = median(v) dayList[#dayList + 1] = d end
  local res = { samples = #rows, days = #dayList }
  local function dim(n) local t = {} for i = 1, n do t[i] = { vals = {}, qty = {}, dayset = {}, days = 0 } end return t end
  local hour, week, month = dim(6), dim(7), dim(3)
  local base = {}
  for _, r in ipairs(rows) do
    local d = math.floor(r[1] / M.DAY)
    local b = base[d]
    if not b then
      local near = {}
      for k = d - 3, d + 3 do if dayMed[k] then near[#near + 1] = dayMed[k] end end
      b = median(near)
      base[d] = b
    end
    if b and b > 0 then
      local rel = r[2] / b
      local tm = date("*t", r[1])
      local slots = {
        { hour, math.floor((tm.hour or 0) / 4) + 1 },
        { week, tm.wday or 1 },
        { month, (tm.day or 1) <= 10 and 1 or (tm.day or 1) <= 20 and 2 or 3 },
      }
      for _, s in ipairs(slots) do
        local bk = s[1][s[2]]
        if bk then
          bk.vals[#bk.vals + 1] = rel
          if r[3] then bk.qty[#bk.qty + 1] = r[3] end
          if not bk.dayset[d] then bk.dayset[d] = true bk.days = bk.days + 1 end
        end
      end
    end
  end
  local function finish(list, names)
    local out = { slots = {} }
    local ready = 0
    for i, bk in ipairs(list) do
      local s = { index = i, name = names[i], n = #bk.vals, days = bk.days, rel = median(bk.vals), qty = median(bk.qty) }
      s.ready = s.n >= M.MIN_BUCKET and s.days >= 2
      if s.ready then
        ready = ready + 1
        if not out.best or s.rel > out.best.rel then out.best = s end
        if not out.worst or s.rel < out.worst.rel then out.worst = s end
      end
      out.slots[i] = s
    end
    out.ready = ready >= 2 and #rows >= M.MIN_SAMPLES
    if not out.ready then out.best, out.worst = nil, nil end
    return out
  end
  res.hour = finish(hour, M.BLOCKS)
  res.week = finish(week, M.WEEKDAY_NAMES)
  res.month = finish(month, M.MONTH)
  return res
end

local function pct(rel) return math.floor((rel - 1) * 100 + 0.5) end

-- One plain sentence of advice, or what is still missing.
function M:Advice(id)
  local b = self:BestTimes(id)
  if b.samples < M.MIN_SAMPLES then
    return nil, string.format("Still learning: %d of %d price checks. Scan the auction house at different times of day.", b.samples, M.MIN_SAMPLES), b
  end
  local parts = {}
  local function say(dim, fmt)
    if dim.ready and dim.best and pct(dim.best.rel) >= 1 then
      parts[#parts + 1] = string.format(fmt, dim.best.name, pct(dim.best.rel))
    end
  end
  say(b.week, "on %s (about %d%% higher)")
  say(b.hour, "in the %s (%d%%)")
  if b.month.ready and b.month.best and pct(b.month.best.rel) >= 1 then
    parts[#parts + 1] = string.format("near the %s of the month (%d%%)", b.month.best.name:lower(), pct(b.month.best.rel))
  end
  if #parts == 0 then
    if b.week.ready or b.hour.ready then return nil, "No time stands out yet: the price is about the same whenever you list.", b end
    return nil, "Still learning: price checks need to come from more different days and times.", b
  end
  return "Best time to list: " .. table.concat(parts, ", ") .. ".", nil, b
end

-- Short form for the tooltip: "Tue, Evening"
function M:Short(id)
  local b = self:BestTimes(id)
  if b.samples < M.MIN_SAMPLES then return nil end
  local out = {}
  if b.week.ready and b.week.best and pct(b.week.best.rel) >= 1 then out[#out + 1] = M.WEEKDAYS[b.week.best.index] end
  if b.hour.ready and b.hour.best and pct(b.hour.best.rel) >= 1 then out[#out + 1] = b.hour.best.name:lower() end
  if #out == 0 then return nil end
  return table.concat(out, " ")
end

-- ------------------------------------------------------------ item list
function M.ItemName(id)
  local info = C.ItemInfo(id)
  return info and info.name or ("item " .. id), info
end

-- Items for the page list: tracked ones first, then (when you type) every
-- item the auction house has priced whose name matches.
function M:ListItems(filter)
  filter = tostring(filter or ""):lower()
  local out, seen = {}, {}
  local function add(id, tracked)
    if seen[id] or #out >= 200 then return end
    local name = M.ItemName(id)
    if filter ~= "" and not name:lower():find(filter, 1, true) then return end
    seen[id] = true
    local sum = self:Summary(id, 30)
    out[#out + 1] = { id = id, name = name, tracked = tracked, price = sum and sum.now, trend = sum and sum.trend }
  end
  local ids = {}
  for id in pairs(self.store.watch) do ids[#ids + 1] = id end
  local P = ns.Prices
  if P and P.ShoppingLists then
    for _, list in pairs(P:ShoppingLists()) do
      if type(list) == "table" then for id in pairs(list) do if tonumber(id) then ids[#ids + 1] = tonumber(id) end end end
    end
  end
  for _, id in ipairs(ids) do add(id, true) end
  table.sort(out, function(a, b) return a.name < b.name end)
  local n = #out
  if filter ~= "" and P and P.db then
    local more = {}
    for id in pairs(P.db) do if not seen[id] then more[#more + 1] = id end end
    table.sort(more)
    for _, id in ipairs(more) do add(id, false) end
    local extra = {}
    for i = n + 1, #out do extra[#extra + 1] = out[i] end
    table.sort(extra, function(a, b) return a.name < b.name end)
    for i, e in ipairs(extra) do out[n + i] = e end
  end
  return out
end

-- ------------------------------------------------------------ widgets
-- Columns made of plain textures (works on every client; lines need
-- CreateLine, which isn't confirmed on Forever yet).
local function Columns(parent, height)
  local f = CreateFrame("Frame", nil, parent, Theme:BackdropTemplate())
  Theme:ApplyPanel(f, "raised")
  f:SetHeight(height)
  f.cols, f.labels = {}, {}
  f.top = UI.Text(f, "small", "muted") f.top:SetPoint("TOPLEFT", 6, -4)
  f.bottom = UI.Text(f, "small", "muted") f.bottom:SetPoint("BOTTOMLEFT", 6, 4)
  f.right = UI.Text(f, "small", "muted") f.right:SetPoint("BOTTOMRIGHT", -6, 4)
  f.empty = UI.Text(f, "normal", "muted") f.empty:SetPoint("CENTER")
  f.mid = f:CreateTexture(nil, "ARTWORK")
  f.mid:SetHeight(1)
  f.midText = UI.Text(f, "small", "muted")
  local function col(i)
    local c = f.cols[i]
    if c then return c end
    c = CreateFrame("Button", nil, f)
    c.bar = c:CreateTexture(nil, "ARTWORK")
    c.bar:SetPoint("BOTTOMLEFT") c.bar:SetPoint("BOTTOMRIGHT")
    c.label = UI.Text(f, "small", "muted")
    c.value = UI.Text(f, "small", "text")
    c:SetScript("OnEnter", function(self)
      if not self.tip then return end
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      for k, l in ipairs(self.tip) do
        if k == 1 then GameTooltip:AddLine(l) else GameTooltip:AddLine(l, 1, 1, 1, true) end
      end
      GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.cols[i] = c
    return c
  end
  -- items: { value, color, label?, valueText?, tip = {lines} }; opts { floor, ceil, mid, midText, top, bottom, right, labels }
  function f:Set(items, opts)
    opts = opts or {}
    local w = (self.GetWidth and self:GetWidth() or 0)
    if w < 20 then w = opts.width or 300 end
    local padB = opts.labels and 28 or 18
    local padT = opts.values and 18 or 16
    local h = (self:GetHeight() or height) - padT - padB
    local n = #items
    self.empty:SetText(n == 0 and (opts.empty or "No prices yet") or "")
    self.top:SetText(opts.top or "")
    self.bottom:SetText(opts.bottom or "")
    self.right:SetText(opts.right or "")
    local lo, hi = opts.floor or 0, opts.ceil or 1
    if hi <= lo then hi = lo + 1 end
    local gap = n > 40 and 1 or 3
    local slot = (w - 12) / math.max(1, n)
    local cw = math.max(1, slot - gap)
    for i = 1, math.max(n, #self.cols) do
      local c = col(i)
      local it = items[i]
      if it then
        local v = it.value
        local frac = v and math.max(0.02, math.min(1, (v - lo) / (hi - lo))) or 0.02
        c:ClearAllPoints()
        c:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 6 + (i - 1) * slot, padB)
        c:SetSize(cw, h)
        c.bar:SetHeight(math.max(1, h * frac))
        c.bar:SetColorTexture(Theme:Color(it.color or "gold"))
        c.tip = it.tip
        c.label:ClearAllPoints()
        c.label:SetPoint("TOP", c, "BOTTOM", 0, -3)
        c.label:SetText(it.label or "")
        c.value:ClearAllPoints()
        c.value:SetPoint("BOTTOM", c.bar, "TOP", 0, 2)
        c.value:SetText(it.valueText or "")
        c:Show() c.label:Show() c.value:Show()
      else
        c:Hide() c.label:Hide() c.value:Hide()
      end
    end
    if opts.mid and n > 0 then
      local y = padB + h * math.max(0, math.min(1, (opts.mid - lo) / (hi - lo)))
      self.mid:ClearAllPoints()
      self.mid:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 4, y)
      self.mid:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -4, y)
      self.mid:SetColorTexture(1, 1, 1, 0.35)
      self.mid:Show()
      self.midText:ClearAllPoints()
      self.midText:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -6, y + 2)
      self.midText:SetText(opts.midText or "")
      self.midText:Show()
    else
      self.mid:Hide() self.midText:Hide()
    end
    self.count = n
  end
  return f
end
M.Columns = Columns

local function coins(c) return c and ns.Prices.Coins(math.floor(c)) or "—" end
local function money(c) return c and ns.Prices.Money(math.floor(c)) or "?" end

-- the graph's columns for an item (pure; the spec reads it)
function M:GraphItems(id, days, now)
  local sum = self:Summary(id, days, now)
  if not sum then return {}, {} end
  local items = {}
  local last = #sum.points
  for i, p in ipairs(sum.points) do
    local d = date("%a %b %d", p[1] * M.DAY + 43200)
    items[i] = { value = p[2], color = i == last and "good" or "gold",
      tip = { d, "Lowest listing: " .. money(p[2]), p[3] .. (p[3] == 1 and " price check" or " price checks") } }
  end
  local lo, hi = sum.low, sum.high
  local floor = math.max(0, lo - (hi - lo) * 0.5 - lo * 0.05)
  return items, { floor = floor, ceil = hi, mid = sum.usual, midText = "usual " .. money(sum.usual),
    top = "high " .. money(hi), bottom = date("%b %d", sum.points[1][1] * M.DAY + 43200),
    right = date("%b %d", sum.points[last][1] * M.DAY + 43200), empty = "No prices yet" }, sum
end

-- one best-time chart's columns (pure)
function M.SlotItems(dimRes, short)
  local items = {}
  local lo, hi = 1, 1
  for _, s in ipairs(dimRes.slots) do
    if s.ready then lo = math.min(lo, s.rel) hi = math.max(hi, s.rel) end
  end
  for i, s in ipairs(dimRes.slots) do
    local best = dimRes.best == s
    local p = s.rel and pct(s.rel)
    items[i] = {
      value = s.ready and s.rel or nil,
      color = not s.ready and "muted" or best and "good" or (dimRes.worst == s and "bad" or "gold"),
      label = short[i],
      valueText = s.ready and ((p > 0 and "+" or "") .. p .. "%") or "?",
      tip = { s.name, s.ready and string.format("%s%d%% against the usual price", p > 0 and "+" or "", p)
        or string.format("Not enough yet: %d price checks on %d days", s.n, s.days),
        s.qty and string.format("Usually %d for sale", math.floor(s.qty + 0.5)) or nil },
    }
  end
  local span = math.max(hi - 1, 1 - lo, 0.02)
  return items, { floor = 1 - span * 1.6, ceil = 1 + span * 1.1, mid = 1, labels = true, values = true }
end

-- ------------------------------------------------------------ the page
ns.Hub:AddTab("pricehistory", "Price history", function(p)
  p.sel = nil
  p.days = 30
  p.intro = UI.Text(p, "normal", "muted")
  p.intro:SetPoint("TOPLEFT", 0, 0)
  p.intro:SetPoint("RIGHT", p, "RIGHT", -4, 0)
  p.intro:SetJustifyH("LEFT")
  p.intro:SetText("Prices over time and the best time to list. 1. Scan or browse the auction house now and then. 2. Pick an item. 3. List it when the green bar says.")
  p.search = UI:SearchBox(p, 220, "Find any priced item", function(t) p.filter = t p:Refresh() end)
  p.search:SetPoint("TOPLEFT", 0, -26)
  p.list = UI:ScrollList(p, {
    rows = 15, rowHeight = 22,
    render = function(row, e)
      local mark = e.tracked and "|cff66d980*|r " or "  "
      local tr = e.trend == "up" and " |cff66d980up|r" or e.trend == "down" and " |cffe06666down|r" or ""
      row.text:SetText(mark .. e.name .. "  |cffbbbbbb" .. (e.price and money(e.price) or "") .. "|r" .. tr)
    end,
    onClick = function(e) p.sel = e.id p:Refresh() end,
  })
  p.list:SetPoint("TOPLEFT", p.search, "BOTTOMLEFT", 0, -6)
  p.list:SetWidth(220)
  p.note = UI.Text(p, "small", "muted")
  p.note:SetPoint("TOPLEFT", p.list, "BOTTOMLEFT", 0, -6)
  p.note:SetWidth(220)
  p.note:SetJustifyH("LEFT")

  local R = CreateFrame("Frame", nil, p)
  R:SetPoint("TOPLEFT", p.search, "TOPRIGHT", 14, 0)
  R:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -4, 0)
  p.right = R
  p.title = UI.Display and UI.Display(R, "side", "goldText") or UI.Text(R, "large", "goldText")
  p.title:SetPoint("TOPLEFT", 0, 0)
  p.track = UI:Button(R, "Track", 110, function()
    if not p.sel then return end
    if M.store.watch[p.sel] then M:Unwatch(p.sel) else M:Watch(p.sel, "manual") end
    p:Refresh()
  end)
  p.track:SetPoint("TOPRIGHT", 0, 2)
  p.stats = UI:StatStrip(R)
  p.stats:SetPoint("TOPLEFT", 0, -26)
  p.stats:SetPoint("RIGHT", R, "RIGHT", 0, 0)
  p.ranges = {}
  local prev
  for _, r in ipairs({ { 7, "7 days" }, { 30, "30 days" }, { 0, "All" } }) do
    local b = UI:Button(R, r[2], 70, function() p.days = r[1] p:Refresh() end)
    b.days = r[1]
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 0, -100) end
    prev = b
    p.ranges[#p.ranges + 1] = b
  end
  p.graph = Columns(R, 150)
  p.graph:SetPoint("TOPLEFT", 0, -126)
  p.graph:SetPoint("RIGHT", R, "RIGHT", 0, 0)
  p.bestHead = UI.Text(R, "normal", "goldText")
  p.bestHead:SetPoint("TOPLEFT", p.graph, "BOTTOMLEFT", 0, -10)
  p.bestHead:SetText("Best time to list")
  p.advice = UI.Text(R, "normal", "text")
  p.advice:SetPoint("TOPLEFT", p.bestHead, "BOTTOMLEFT", 0, -4)
  p.advice:SetPoint("RIGHT", R, "RIGHT", 0, 0)
  p.advice:SetJustifyH("LEFT")
  p.slots = {}
  local heads = { "Time of day", "Day of week", "Time of month" }
  for i = 1, 3 do
    local c = Columns(R, 110)
    if i == 1 then c:SetPoint("TOPLEFT", p.advice, "BOTTOMLEFT", 0, -22)
    else c:SetPoint("TOPLEFT", p.slots[i - 1], "TOPRIGHT", 8, 0) end
    c.head = UI.Text(R, "small", "goldText")
    c.head:SetPoint("BOTTOMLEFT", c, "TOPLEFT", 2, 3)
    c.head:SetText(heads[i])
    p.slots[i] = c
  end
  function p:LayoutSlots()
    local w = (R.GetWidth and R:GetWidth() or 0)
    if w < 100 then w = 480 end
    local cw = math.floor((w - 16) / 3)
    for _, c in ipairs(self.slots) do c:SetWidth(cw) end
    return cw
  end

  function p:Refresh()
    local items = M:ListItems(self.filter)
    self.list:SetItems(items)
    if not self.sel and items[1] then self.sel = items[1].id end
    self.note:SetText(M:WatchCount() == 0 and "Items you sell or search on the auction house are tracked by themselves (*). Type a name to find any other."
      or string.format("%d tracked (*). Type a name to find any other priced item.", M:WatchCount()))
    for _, b in ipairs(self.ranges) do UI.SetPrimary(b, b.days == self.days) end
    local id = self.sel
    if not id then
      self.title:SetText("No item yet")
      self.stats:SetItems({})
      self.graph:Set({}, { empty = "Open the auction house and scan or browse: prices start here." })
      self.advice:SetText("")
      for _, c in ipairs(self.slots) do c:Set({}, { empty = "" }) end
      self.track:Hide()
      return
    end
    self.track:Show()
    self.track:SetText(M.store.watch[id] and "Stop tracking" or "Track")
    self.title:SetText(M.ItemName(id))
    local days = self.days ~= 0 and self.days or nil
    local gItems, gOpts, sum = M:GraphItems(id, days)
    gOpts.width = (self.graph.GetWidth and self.graph:GetWidth() or 0)
    if gOpts.width < 20 then gOpts.width = 480 end
    self.graph:Set(gItems, gOpts)
    local stats = {}
    if sum then
      stats[1] = { cap = "Cheapest now", value = coins(sum.now), color = "gold", note = sum.qty and (sum.qty .. " for sale") or nil }
      stats[2] = { cap = "Usual", value = coins(sum.usual), note = "middle of the daily lows" }
      stats[3] = { cap = "Range", value = money(sum.low) .. " - " .. money(sum.high), note = sum.days .. " days" }
      stats[4] = { cap = "Trend", value = sum.trend and ns.TitleCase(sum.trend) or "—",
        color = sum.trend == "up" and "good" or sum.trend == "down" and "bad" or nil,
        note = sum.change and string.format("%+d%% this week", math.floor(sum.change * 100 + 0.5)) or "needs 2 weeks" }
    end
    self.stats:SetItems(stats)
    local line, why, b = M:Advice(id)
    if not M:IsTracked(id) then
      why = "Not tracked: press Track to keep hourly prices for this item and learn its best time."
    end
    self.advice:SetText(line or why or "")
    local cw = self:LayoutSlots()
    local dims = { { b.hour, { "0-4", "4-8", "8-12", "12-16", "16-20", "20-24" } }, { b.week, { "S", "M", "T", "W", "T", "F", "S" } }, { b.month, { "1-10", "11-20", "21+" } } }
    for i, d in ipairs(dims) do
      local its, o = M.SlotItems(d[1], d[2])
      o.width = cw
      self.slots[i]:Set(its, o)
    end
    if not self.logged or not self.logged[id] then
      self.logged = self.logged or {}
      self.logged[id] = true
      M:Info("price history page: item %d, %d days on the graph, %d price checks, advice %s",
        id, #gItems, b.samples, line and "ready" or "learning")
    end
  end
end, 50)

-- ------------------------------------------------------------ tooltip
ns.TooltipLines:Add("item", "pricetime", M, function(_, data)
  if not M:Settings().tooltip then return nil end
  local id = data and C.Readable(data.id)
  if type(id) ~= "number" or not M:IsTracked(id) then return nil end
  local s = M:Short(id)
  if not s then return nil end
  return { { "Best time to list", "goldText", right = s } }
end)

function M:OnEnable()
  self:On("AUCTION_HOUSE_CLOSED", function(mod)
    if (mod.added or 0) > 0 then
      mod:Info("price history: %d new price checks this visit, %d items tracked", mod.added, mod:WatchCount())
      mod.added = 0
    end
  end)
  self:On("PLAYER_LOGOUT", function(mod) mod:Prune() end)
end

function M:Activity()
  local n = 0
  for _ in pairs(self.store.items) do n = n + 1 end
  return string.format("%d items tracked, %d with price history", self:WatchCount(), n)
end

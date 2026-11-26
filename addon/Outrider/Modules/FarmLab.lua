-- Modules/FarmLab.lua
-- What each farm really pays (Reddit request 2026-11-26, Gary: "lets add this
-- feature"). A farm run is a dungeon run (started by itself when Alts sees you
-- enter a dungeon) or an outdoor farm you time yourself (Start / Stop).
-- Each run keeps:
--   * coin looted: the game's own "You loot 1 Silver" lines (CHAT_MSG_MONEY);
--     if those can't be read, the gold that came in while a loot window was open
--   * the items you actually received (CHAT_MSG_LOOT "You receive loot:"),
--     not what a loot window showed, each with its vendor and auction price at
--     the time you got it (Prices: Auctionator, TSM, or Outrider's own scans)
--   * costs (repairs, vendor buys, training...) and other income by the window
--     that was open (Ledger's context), the real change in gold, XP and kills
-- Vendor value and auction value are two ways to sell the same loot, never
-- added together. Runs are kept for good (ns.db.global.farmlab.runs; past
-- KEEP they move to the archive, never deleted). Read only: it never loots,
-- sells or buys anything.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("FarmLab", {
  title = "FarmLab (what each farm pays)",
  phase = "P5",
  order = 80,
  defaults = { metric = "ah", scope = "char", prices = "then" },
})
ns.FarmLab = M

M.KEEP = 500           -- runs kept in the main list (older ones go to the archive)
M.SAME_RUN = 30 * 60   -- back into the same dungeon within 30 min continues the run
M.RESUME = 15 * 60     -- a farm timer survives a reload or a short relog
M.MIN_SECS = 60        -- a dungeon peek with no loot isn't a run
M.AH_CUT = 0.95        -- the auction house keeps 5%
M.RARE_QUALITY = 2     -- green and better count as rare drops

M.METRICS = {
  { key = "coin", label = "Coin looted", note = "only the gold, silver and copper you looted" },
  { key = "vendor", label = "Sell to vendor", note = "coin + every item sold to a vendor, less costs" },
  { key = "ah", label = "Sell at auction", note = "coin + items at auction price less the 5% cut (vendor price where none is known), less costs" },
  { key = "real", label = "Gold change", note = "how much your gold really went up while the run lasted" },
}

local function readable(v) return v ~= nil and C.Readable(v) and v or nil end

function M:OnInitialize()
  local g = ns.db.global
  g.farmlab = ns.KeepTable(g.farmlab, "FarmLab:g.farmlab") or {}
  local f = g.farmlab
  f.runs = ns.KeepTable(f.runs, "FarmLab:g.farmlab.runs") or {}
  self.store = f
end

-- ------------------------------------------------------------------ parsing
-- "You receive loot: %s." -> "^You receive loot: (.+)%.$" (and %d -> digits)
function M.Pattern(fmt)
  local p = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
  p = p:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
  return "^" .. p .. "$"
end

-- itemID, count from a loot line that is the player's own, else nil
function M.ParseLoot(msg)
  if type(msg) ~= "string" or C.IsSecret(msg) then return nil end
  local multi = rawget(_G, "LOOT_ITEM_SELF_MULTIPLE") or "You receive loot: %sx%d."
  local single = rawget(_G, "LOOT_ITEM_SELF") or "You receive loot: %s."
  local link, n = msg:match(M.Pattern(multi))
  if not link then link = msg:match(M.Pattern(single)) end
  local id = link and tonumber(link:match("item:(%d+)"))
  if not id then return nil end
  return id, tonumber(n) or 1
end

-- copper in "You loot 1 Gold, 2 Silver, 3 Copper" / "Your share of the loot is 5 Silver."
function M.ParseCoin(msg)
  if type(msg) ~= "string" or C.IsSecret(msg) then return 0 end
  local function amt(global, word)
    local fmt = rawget(_G, global) or ("%d " .. word)
    local n = msg:match((fmt:gsub("%%d", "(%%d+)")))
    return tonumber(n) or 0
  end
  return amt("GOLD_AMOUNT", "Gold") * 10000 + amt("SILVER_AMOUNT", "Silver") * 100 + amt("COPPER_AMOUNT", "Copper")
end

-- vendor each, auction each (or nil), price source, quality, name
function M.PriceNow(itemID)
  local info = C.ItemInfo(itemID)
  local ah, src, vendor
  if ns.Prices then ah, src, vendor = ns.Prices:Get(itemID) end
  vendor = vendor or (info and info.sellPrice) or nil
  return vendor, ah, src, info and info.quality, info and info.name
end

-- ------------------------------------------------------------------ sessions
function M:Active() return self.store.active end

local function newRun(kind, name, extra)
  local key = ns.db.key
  local _, class = C.Call("UnitClass", "player")
  local now = time()
  local r = { id = tostring(now) .. "-" .. tostring(key), kind = kind, name = name, char = key, class = readable(class),
    level = tonumber(C.Call("UnitLevel", "player")) or 1, start = now, last = now, away = 0,
    money0 = tonumber(C.Call("GetMoney")) or 0, coin = 0, coinAlt = 0, gains = {}, spend = {}, xp = 0, kills = 0,
    items = {}, zone = readable(C.Call("GetZoneText")) }
  for k, v in pairs(extra or {}) do r[k] = v end
  return r
end

function M:Begin(kind, name, extra)
  if self.store.active then self:Finish("replaced") end
  local r = newRun(kind, name, extra)
  self.store.active = r
  self.lastXP = tonumber(readable(C.Call("UnitXP", "player")))
  self.lastMax = tonumber(readable(C.Call("UnitXPMax", "player")))
  self:Info("farm run started: %s (%s)", tostring(name), kind)
  ns.Events:Fire("OTR_FARM_CHANGED", r)
  return r
end

-- Close the active run (at `at`, default now) and keep it.
function M:Finish(why, at)
  local r = self.store.active
  if not r then return nil end
  self.store.active = nil
  r.stop = at or r.leftAt or time()
  -- the real change in gold: up to when you left the dungeon, else up to now
  r.net = ((r.leftAt and r.money1) or tonumber(C.Call("GetMoney")) or 0) - (r.money0 or 0)
  r.leftAt, r.money1 = nil, nil
  r.endReason = why
  self:FillPrices(r)
  local v = M.Value(r)
  local empty = v.coin == 0 and next(r.items) == nil
  if r.kind == "dungeon" and v.secs < M.MIN_SECS and empty then
    self:Debug("dungeon peek dropped (%s)", tostring(r.name))
    ns.Events:Fire("OTR_FARM_CHANGED", nil)
    return nil
  end
  table.insert(self.store.runs, 1, r)
  while #self.store.runs > M.KEEP and ns.Archive:Pop("farmRuns", self.store.runs, { path = "global.farmlab.runs" }) do end
  self:Info("farm run done: %s %d min, coin %s, vendor %s, auction %s, costs %s (%s)", tostring(r.name),
    math.floor(v.secs / 60), ns.Prices.Money(v.coin), ns.Prices.Money(v.vendor), ns.Prices.Money(v.ah),
    ns.Prices.Money(v.spent), tostring(why))
  ns.Events:Fire("OTR_FARM_CHANGED", nil)
  return r
end

-- A manual farm timer (outdoor farming): a name or the zone you're in.
function M:StartManual(label)
  label = type(label) == "string" and label:match("^%s*(.-)%s*$") or ""
  if label == "" then label = readable(C.Call("GetZoneText")) or "Farming" end
  return self:Begin("manual", label)
end

function M:Stop() return self:Finish("stopped") end

-- left the dungeon: the run waits SAME_RUN in case you go back in (repairs
-- and restocks while you're out count as its costs)
function M:Pause(now)
  local r = self.store.active
  if not r or r.kind ~= "dungeon" then return end
  r.leftAt = now or time()
  r.money1 = tonumber(C.Call("GetMoney")) or 0
  ns.Timer.After(M.SAME_RUN + 1, function() M:Expire() end, "farmlab:expire")
  ns.Events:Fire("OTR_FARM_CHANGED", r)
end

function M:Expire(now)
  local r = self.store.active
  now = now or time()
  if r and r.leftAt and now - r.leftAt >= M.SAME_RUN then return self:Finish("left", r.leftAt) end
end

function M:OnRunStart(_, run)
  if type(run) ~= "table" then return end
  self:Expire()
  local r = self.store.active
  if r and r.kind == "manual" then
    -- your own timer keeps going; note the dungeon in it
    r.places = r.places or {}
    r.places[tostring(run.name)] = true
    return
  end
  if r and r.kind == "dungeon" and r.map == run.map and r.char == ns.db.key then
    if r.leftAt then
      r.away = (r.away or 0) + math.max(0, time() - r.leftAt)
      r.leftAt, r.money1 = nil, nil
      self:Info("farm run continues: %s", tostring(r.name))
    end
    return
  end
  self:Begin("dungeon", run.name or "Dungeon", { map = run.map })
end

function M:OnRunEnd(_, run)
  local r = self.store.active
  if r and r.kind == "dungeon" and (not run or run.map == r.map) then self:Pause(run and run.stop) end
end

-- ------------------------------------------------------------------ booking
local function touch(r) r.last = time() end

-- Two ways to see a drop (2026-11-26: Gary saw nothing recorded): the
-- "You receive loot" chat line, and an item slot emptied from your loot
-- window. Both usually fire for the same item; whichever comes second within
-- MATCH seconds is the same drop and isn't counted again.
M.MATCH = 3
local function clock() return GetTime and GetTime() or time() end

function M:Book(id, n, src)
  local r = self.store.active
  if not r or r.leftAt or not id then return false end
  local now = clock()
  self.recent = self.recent or {}
  local keep = {}
  local twin
  for _, e in ipairs(self.recent) do
    if now - e.t <= M.MATCH + 2 then
      keep[#keep + 1] = e
      if not twin and not e.matched and e.src ~= src and e.id == id and e.n == n and now - e.t <= M.MATCH then twin = e end
    end
  end
  self.recent = keep
  if twin then twin.matched = true return false end
  keep[#keep + 1] = { id = id, n = n, src = src, t = now }
  self:AddItem(r, id, n)
  self:Redraw()
  return true
end

-- the FarmLab page, if it's the one open, shows new loot within half a second
function M:Redraw()
  local hub = ns.Hub
  if self.redrawing or not (hub and hub.current == "farmlab" and hub.frame and hub.frame:IsShown()) then return end
  self.redrawing = true
  ns.Timer.After(0.5, function() M.redrawing = nil ns.Hub:Refresh() end, "farmlab:redraw")
end

-- the loot window: remember what each slot holds; a slot that empties went to you
function M:OnLootOpened()
  self.lootOpen = true
  self.slots = {}
  local num = tonumber(readable(C.Call("GetNumLootItems"))) or 0
  for slot = 1, math.min(num, 40) do
    local link = readable(C.Call("GetLootSlotLink", slot))
    local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
    if id then
      local _, _, qty, _, _, locked = C.CallAll("GetLootSlotInfo", slot)
      self.slots[slot] = { id = id, n = tonumber(readable(qty)) or 1, locked = readable(locked) and true or nil }
    end
  end
end

function M:OnSlotCleared(_, slot)
  local s = self.slots and self.slots[readable(slot)]
  if not s or s.locked then return end
  self.slots[readable(slot)] = nil
  self:Book(s.id, s.n, "window")
end

function M:OnLootLine(_, msg)
  -- the first few loot lines a session go to the log, so the client's real
  -- wording can be checked against the pattern
  self.linesSeen = (self.linesSeen or 0) + 1
  if self.linesSeen <= 3 then
    local secret = C.IsSecret(msg)
    local id = M.ParseLoot(msg)
    local text = (not secret and type(msg) == "string" and msg:find("^You")) and msg:gsub("|", "||") or nil
    self:Info("loot line %d: %s%s", self.linesSeen, secret and "secret" or (id and ("item " .. id) or "no match"),
      text and (" (" .. text:sub(1, 120) .. ")") or "")
  end
  local id, n = M.ParseLoot(msg)
  if id then self:Book(id, n, "chat") end
end

function M:AddItem(r, id, n)
  local it = r.items[id] or { n = 0 }
  r.items[id] = it
  it.n = it.n + n
  if not it.priced then
    local vendor, ah, src, q, name = M.PriceNow(id)
    it.vendor, it.ah, it.src, it.q, it.name = vendor, ah, src, q, name
    it.priced = (name ~= nil) or nil -- not loaded yet: priced at the end
  end
  touch(r)
end

function M:OnCoinLine(_, msg)
  local r = self.store.active
  if not r or r.leftAt then return end
  local c = M.ParseCoin(msg)
  if c > 0 then r.coin = r.coin + c touch(r) self:Redraw() end
end

function M:OnMoney()
  local now = tonumber(C.Call("GetMoney")) or self.money or 0
  local delta = now - (self.money or now)
  self.money = now
  local r = self.store.active
  if not r or delta == 0 then return end
  local ctx = ns.Ledger and ns.Ledger:Context() or "loot & quests"
  if delta > 0 then
    if r.leftAt then return end -- income outside doesn't belong to the run
    if self.lootOpen and ctx == "loot & quests" then r.coinAlt = r.coinAlt + delta
    else r.gains[ctx] = (r.gains[ctx] or 0) + delta end
  else
    r.spend[ctx] = (r.spend[ctx] or 0) - delta
  end
  touch(r)
end

function M:OnXP()
  local r = self.store.active
  local xp, max = tonumber(readable(C.Call("UnitXP", "player"))), tonumber(readable(C.Call("UnitXPMax", "player")))
  if r and not r.leftAt and xp and self.lastXP then
    local d = xp - self.lastXP
    if d < 0 then d = (self.lastMax or 0) - self.lastXP + xp end
    if d > 0 then r.xp = r.xp + d end
  end
  self.lastXP, self.lastMax = xp, max
end

function M:OnXPLine(_, msg)
  local r = self.store.active
  msg = readable(msg)
  if r and not r.leftAt and type(msg) == "string" and msg:find("dies", 1, true) then r.kills = r.kills + 1 end
end

-- items whose details weren't loaded when they dropped get priced now
function M:FillPrices(r)
  for id, it in pairs(r.items or {}) do
    if not it.priced then
      local vendor, ah, src, q, name = M.PriceNow(id)
      if name then
        it.vendor, it.ah, it.src, it.q, it.name, it.priced = vendor, ah, src, q, name, true
      end
    end
  end
end

-- ------------------------------------------------------------------ numbers
-- Everything about one run. today = revalue the loot at today's prices.
function M.Value(r, today)
  local v = { coin = 0, vendor = 0, ah = 0, ahNet = 0, spent = 0, gained = 0, priced = 0, unpriced = 0 }
  v.coin = (r.coin or 0) > 0 and r.coin or (r.coinAlt or 0)
  for id, it in pairs(r.items or {}) do
    local vendor, ah = it.vendor, it.ah
    if today then
      local nv, na = M.PriceNow(id)
      vendor, ah = nv or vendor, na
    end
    local n = it.n or 0
    v.vendor = v.vendor + (vendor or 0) * n
    v.ah = v.ah + (ah or vendor or 0) * n
    v.ahNet = v.ahNet + (ah and math.floor(ah * M.AH_CUT) or vendor or 0) * n
    if ah then v.priced = v.priced + 1 else v.unpriced = v.unpriced + 1 end
  end
  for _, c in pairs(r.spend or {}) do v.spent = v.spent + c end
  for _, c in pairs(r.gains or {}) do v.gained = v.gained + c end
  local stop = r.stop or r.leftAt or time()
  v.secs = math.max(1, stop - (r.start or stop) - (r.away or 0))
  v.real = r.net or (((r.leftAt and r.money1) or tonumber(C.Call("GetMoney")) or 0) - (r.money0 or 0))
  v.metric = {
    coin = v.coin,
    vendor = v.coin + v.vendor - v.spent,
    ah = v.coin + v.ahNet - v.spent,
    real = v.real,
  }
  return v
end

function M.PerHour(copper, secs) return math.floor((copper or 0) / math.max(secs or 1, 60) * 3600) end

local function median(list)
  if #list == 0 then return 0 end
  local s = {}
  for i, x in ipairs(list) do s[i] = x end
  table.sort(s)
  local m = math.floor((#s + 1) / 2)
  if #s % 2 == 1 then return s[m] end
  return math.floor((s[m] + s[m + 1]) / 2)
end
M.Median = median

-- "steady" / "mixed" / "swingy" / "too few runs" from the per-hour spread
function M.Steadiness(perHours)
  if #perHours < 3 then return "too few runs", "muted" end
  local med = median(perHours)
  local lo, hi = math.huge, -math.huge
  for _, x in ipairs(perHours) do lo, hi = math.min(lo, x), math.max(hi, x) end
  if med <= 0 then return "swingy", "bad" end
  local spread = (hi - lo) / med
  if spread <= 0.5 then return "steady", "good" end
  if spread <= 1.5 then return "mixed", "warn" end
  return "swingy (lucky drops)", "bad"
end

-- the runs that count under the page's choices
function M:Runs(scope)
  scope = scope or self:Settings().scope
  local out = {}
  for _, r in ipairs(self.store.runs) do
    if scope == "all" or r.char == ns.db.key then out[#out + 1] = r end
  end
  return out
end

-- one row per place: runs, gold per hour overall and per run (median, low, high)
function M:Places(metric, scope, today)
  metric = metric or self:Settings().metric
  today = today == nil and self:Settings().prices == "today" or today
  local by, order = {}, {}
  for _, r in ipairs(self:Runs(scope)) do
    local key = tostring(r.name or "?")
    local p = by[key]
    if not p then
      p = { name = key, kind = r.kind, runs = 0, total = 0, secs = 0, perHours = {}, chars = {} }
      by[key] = p
      order[#order + 1] = p
    end
    local v = M.Value(r, today)
    p.runs = p.runs + 1
    p.total = p.total + v.metric[metric]
    p.secs = p.secs + v.secs
    p.perHours[#p.perHours + 1] = M.PerHour(v.metric[metric], v.secs)
    p.chars[r.char or "?"] = true
    p.last = math.max(p.last or 0, r.stop or 0)
  end
  for _, p in ipairs(order) do
    p.perHour = M.PerHour(p.total, p.secs)
    p.median = median(p.perHours)
    p.low, p.high = math.huge, -math.huge
    for _, x in ipairs(p.perHours) do p.low, p.high = math.min(p.low, x), math.max(p.high, x) end
    p.avgMins = math.floor(p.secs / p.runs / 60 + 0.5)
    p.steady, p.steadyColor = M.Steadiness(p.perHours)
  end
  table.sort(order, function(a, b)
    if a.median ~= b.median then return a.median > b.median end
    return a.runs > b.runs
  end)
  return order
end

-- green-or-better drops: how many runs of that place had one (sample size shown)
function M:Drops(scope)
  local places, out = {}, {}
  for _, r in ipairs(self:Runs(scope)) do
    local key = tostring(r.name or "?")
    local p = places[key] or { runs = 0, items = {} }
    places[key] = p
    p.runs = p.runs + 1
    for id, it in pairs(r.items or {}) do
      if (it.q or 0) >= M.RARE_QUALITY then
        local d = p.items[id] or { id = id, name = it.name, q = it.q, runsWith = 0, n = 0, place = key }
        p.items[id] = d
        d.runsWith, d.n = d.runsWith + 1, d.n + (it.n or 0)
      end
    end
  end
  for _, p in pairs(places) do
    for _, d in pairs(p.items) do
      d.of = p.runs
      d.rate = d.runsWith / p.runs
      out[#out + 1] = d
    end
  end
  table.sort(out, function(a, b)
    if (a.q or 0) ~= (b.q or 0) then return (a.q or 0) > (b.q or 0) end
    if a.rate ~= b.rate then return a.rate < b.rate end
    return tostring(a.name) < tostring(b.name)
  end)
  return out
end

-- per character: runs and gold per hour under the chosen metric, all places
function M:Characters(metric, today)
  metric = metric or self:Settings().metric
  local by, out = {}, {}
  for _, r in ipairs(self.store.runs) do
    local c = by[r.char or "?"]
    if not c then c = { char = r.char or "?", class = r.class, runs = 0, total = 0, secs = 0 } by[c.char] = c out[#out + 1] = c end
    local v = M.Value(r, today)
    c.runs, c.total, c.secs = c.runs + 1, c.total + v.metric[metric], c.secs + v.secs
  end
  for _, c in ipairs(out) do c.perHour = M.PerHour(c.total, c.secs) end
  table.sort(out, function(a, b) return a.perHour > b.perHour end)
  return out
end

-- the items of one run, most valuable first
function M.ItemRows(r, today)
  local out = {}
  for id, it in pairs(r and r.items or {}) do
    local vendor, ah = it.vendor, it.ah
    if today then local nv, na = M.PriceNow(id) vendor, ah = nv or vendor, na end
    out[#out + 1] = { id = id, name = it.name or ("item " .. id), q = it.q, n = it.n or 0,
      vendor = (vendor or 0) * (it.n or 0), ah = ah and ah * (it.n or 0) or nil, src = it.src }
  end
  table.sort(out, function(a, b) return (a.ah or a.vendor) > (b.ah or b.vendor) end)
  return out
end

-- ------------------------------------------------------------------ export
local function csvCell(v)
  v = tostring(v == nil and "" or v)
  if v:find('[,"\n]') then v = '"' .. v:gsub('"', '""') .. '"' end
  return v
end

function M:ExportCSV(scope)
  local lines = { "run,date,character,place,kind,minutes,coin,vendor_value,auction_value,costs,gold_change,xp,kills" }
  local items = { "run,item_id,item,quality,count,vendor_each,auction_each,price_source" }
  for i, r in ipairs(self:Runs(scope or "all")) do
    local v = M.Value(r)
    lines[#lines + 1] = table.concat({ i, date("%Y-%m-%d %H:%M", r.start or 0), csvCell(r.char), csvCell(r.name), r.kind,
      math.floor(v.secs / 60), v.coin, v.vendor, v.ah, v.spent, v.real, r.xp or 0, r.kills or 0 }, ",")
    local ids = {}
    for id in pairs(r.items or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
      local it = r.items[id]
      items[#items + 1] = table.concat({ i, id, csvCell(it.name), it.q or "", it.n or 0, it.vendor or "", it.ah or "", csvCell(it.src) }, ",")
    end
  end
  return table.concat(lines, "\n") .. "\n\n" .. table.concat(items, "\n")
end

local function json(v)
  local t = type(v)
  if t == "number" then return (v == math.floor(v) and string.format("%.0f", v)) or tostring(v) end
  if t == "boolean" then return tostring(v) end
  if t == "string" then
    return '"' .. v:gsub('[%c"\\]', function(ch)
      if ch == '"' then return '\\"' elseif ch == "\\" then return "\\\\" elseif ch == "\n" then return "\\n" end
      return string.format("\\u%04x", ch:byte())
    end) .. '"'
  end
  if t ~= "table" then return "null" end
  if #v > 0 or next(v) == nil then
    local out = {}
    for i, x in ipairs(v) do out[i] = json(x) end
    return "[" .. table.concat(out, ",") .. "]"
  end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = tostring(k) end
  table.sort(keys)
  local out = {}
  for _, k in ipairs(keys) do
    local x = v[k]
    if x == nil then x = v[tonumber(k)] end
    out[#out + 1] = json(k) .. ":" .. json(x)
  end
  return "{" .. table.concat(out, ",") .. "}"
end
M.JSON = json

function M:ExportJSON(scope)
  local runs = {}
  for _, r in ipairs(self:Runs(scope or "all")) do
    local v = M.Value(r)
    local items = {}
    for id, it in pairs(r.items or {}) do
      items[#items + 1] = { id = id, name = it.name, quality = it.q, count = it.n, vendorEach = it.vendor, auctionEach = it.ah, source = it.src }
    end
    table.sort(items, function(a, b) return a.id < b.id end)
    runs[#runs + 1] = { start = r.start, stop = r.stop, character = r.char, place = r.name, kind = r.kind, seconds = v.secs,
      coin = v.coin, vendorValue = v.vendor, auctionValue = v.ah, costs = v.spent, goldChange = v.real, xp = r.xp, kills = r.kills,
      items = items }
  end
  return json({ farmlab = 1, runs = runs })
end

-- ------------------------------------------------------------------ module
function M:OnEnable()
  self.money = tonumber(C.Call("GetMoney")) or 0
  self:On("OTR_RUN_START", self.OnRunStart)
  self:On("OTR_RUN_END", self.OnRunEnd)
  self:On("CHAT_MSG_LOOT", self.OnLootLine)
  self:On("CHAT_MSG_MONEY", self.OnCoinLine)
  self:On("PLAYER_MONEY", self.OnMoney)
  self:On("PLAYER_XP_UPDATE", self.OnXP)
  self:On("CHAT_MSG_COMBAT_XP_GAIN", self.OnXPLine)
  self:On("LOOT_READY", self.OnLootOpened)
  self:On("LOOT_OPENED", self.OnLootOpened)
  self:On("LOOT_SLOT_CLEARED", self.OnSlotCleared)
  self:On("LOOT_CLOSED", function(mod) mod.lootOpen, mod.slots = nil, nil end)
  self:On("PLAYER_ENTERING_WORLD", function(mod, _, isLogin, isReload)
    mod.money = tonumber(C.Call("GetMoney")) or mod.money
    if not (isLogin or isReload) then return end
    -- a run saved at logout: keep timing after a reload or short relog, else close it
    local r = mod.store.active
    if not r then return end
    local gap = time() - (r.last or r.start or 0)
    if r.char ~= ns.db.key then
      -- another character's run: close it where it stopped (it stays in its owner's list)
      mod.store.active = nil
      r.stop = r.leftAt or r.last
      r.endReason = "logged out"
      mod:FillPrices(r)
      table.insert(mod.store.runs, 1, r)
      return
    end
    if r.leftAt then return mod:Expire() end
    if gap > M.RESUME then return mod:Finish("logged out", r.last) end
    mod.lastXP = tonumber(readable(C.Call("UnitXP", "player")))
    mod.lastMax = tonumber(readable(C.Call("UnitXPMax", "player")))
  end)
  self:On("PLAYER_LOGOUT", function(mod)
    local r = mod.store.active
    if r then r.last = time() end
  end)
end

function M:Snapshot()
  local best = {}
  for i, p in ipairs(self:Places("ah", "char")) do
    if i > 3 then break end
    best[#best + 1] = { place = p.name, runs = p.runs, medianPerHour = p.median, steady = p.steady }
  end
  local r = self.store.active
  return { runs = #self:Runs("char"), active = r and r.name or nil, bestFarms = best }
end

function M:Activity()
  local r = self.store.active
  if r then
    local v = M.Value(r)
    return string.format("timing %s, %d min, coin %s", tostring(r.name), math.floor(v.secs / 60), ns.Prices.Money(v.coin))
  end
  return string.format("%d farm runs saved", #self.store.runs)
end

ns.AddCommand("farm", "farm start [name] | stop | export", function(arg)
  arg = tostring(arg or "")
  local verb, rest = arg:match("^(%S*)%s*(.-)$")
  if verb == "start" then
    local r = M:StartManual(rest)
    ns.Print("farm timer started: %s", tostring(r.name))
  elseif verb == "stop" then
    local r = M:Stop()
    ns.Print(r and ("farm run saved: " .. tostring(r.name)) or "no farm timer running")
  elseif verb == "export" then
    ns.UI:TextDialog("FarmLab export (CSV)", M:ExportCSV("all"), "copy")
  else
    ns.Print("%s", M:Activity())
  end
end)

-- ------------------------------------------------------------------ page
local function money(c) return ns.Prices.Coins and ns.Prices.Coins(c or 0) or ns.Prices.Money(c or 0) end
local QCOLOR = { [0] = "9d9d9d", [1] = "ffffff", [2] = "1eff00", [3] = "0070dd", [4] = "a335ee", [5] = "ff8000" }
local function qname(name, q) return "|cff" .. (QCOLOR[q or 1] or "ffffff") .. tostring(name) .. "|r" end
local function metricOf(key)
  for _, m in ipairs(M.METRICS) do if m.key == key then return m end end
  return M.METRICS[3]
end

-- the run the top of the page shows: the one running, else the last one
function M:ShownRun()
  return self.store.active or self:Runs("char")[1] or self.store.runs[1]
end

ns.Hub:AddTab("farmlab", "FarmLab", function(p)
  local UI = ns.UI
  local s = function() return M:Settings() end
  local today = function() return s().prices == "today" end
  local refresh = function() if p.Refresh then p:Refresh() end end
  UI:FormPage(p, {
    { "header", "FarmLab" },
    { "note", "What each farm really pays you: coin, loot at vendor and auction prices, and costs, per run and per hour. 1. Go into a dungeon (it times itself) or press Start for outdoor farming. 2. Play. 3. Come back here to see which farm pays best." },
    { "stats", function()
      local r = M:ShownRun()
      if not r then
        return { { cap = "Farm runs", value = "0", note = "none yet" } }
      end
      local v = M.Value(r, today())
      return {
        { cap = M.store.active == r and "Running" or "Last run", value = string.format("%d:%02d", math.floor(v.secs / 3600), math.floor(v.secs / 60) % 60),
          note = tostring(r.name) },
        { cap = "Coin looted", value = money(v.coin), color = "gold", note = money(M.PerHour(v.coin, v.secs)) .. " an hour" },
        { cap = "Loot to a vendor", value = money(v.vendor) },
        { cap = "Loot at auction", value = money(v.ah), note = v.unpriced > 0 and (v.unpriced .. " items without a price") or nil },
      }
    end },
    { "buttons", {
      { "Start farm timer", function() M:StartManual() refresh() end, 150, "Times outdoor farming in this zone until you press Stop. Dungeons time themselves." },
      { "Stop and save", function() M:Stop() refresh() end, 130, "Ends the run that's timing now and saves it." },
      { "Export (CSV)", function() ns.UI:TextDialog("FarmLab export (CSV)", M:ExportCSV("all"), "copy") end, 120, "Every run and item as CSV to copy into a spreadsheet." },
      { "Export (JSON)", function() ns.UI:TextDialog("FarmLab export (JSON)", M:ExportJSON("all"), "copy") end, 120, "The same as JSON, for your own tools." },
    } },
    { "note", function()
      local r = M.store.active
      if not r then return "Nothing timing now. Dungeons start by themselves when you go in; press Start farm timer for anything outdoors." end
      local v = M.Value(r)
      if r.leftAt then
        return string.format("You left %s. If you go back in within %d minutes the run continues; repairs and restocks meanwhile count as its costs.",
          tostring(r.name), M.SAME_RUN / 60)
      end
      return string.format("Timing %s (%s) for %d min. Costs so far %s.", tostring(r.name),
        r.kind == "dungeon" and "dungeon, started by itself" or "your timer", math.floor(v.secs / 60), money(v.spent))
    end },
    { "header", "What dropped this run", icon = "INV_Misc_Bag_10" },
    { "table", 8, {
      { key = "name", label = "Item", width = 0, sort = function(x) return x.name end, text = function(x) return qname(x.name, x.q) end },
      { key = "n", label = "Qty", width = 50, align = "RIGHT", sort = function(x) return x.n end, text = function(x) return x.n end },
      { key = "vendor", label = "Vendor", width = 110, align = "RIGHT", sort = function(x) return x.vendor end, text = function(x) return money(x.vendor) end },
      { key = "ah", label = "Auction", width = 110, align = "RIGHT", sort = function(x) return x.ah or -1 end,
        text = function(x) return x.ah and money(x.ah) or "|cff8f96a6no price|r" end },
    }, function() return M.ItemRows(M:ShownRun(), today()) end, nil, sortKey = "ah", desc = true },
    { "note", "Only items you actually received count (not what a loot window showed). Vendor and auction are two ways to sell the same loot; they don't add up. Prices are from when you looted them unless you pick today's prices below." },
    { "header", "Which farm pays best", icon = "INV_Misc_Coin_02" },
    { "buttons", (function()
      local out = {}
      for _, m in ipairs(M.METRICS) do
        out[#out + 1] = { m.label, function() s().metric = m.key refresh() end, 130, m.note }
      end
      return out
    end)(), plain = true },
    { "buttons", {
      { "This character", function() s().scope = "char" refresh() end, 120, "Only this character's runs." },
      { "All characters", function() s().scope = "all" refresh() end, 120, "Every character's runs together." },
      { "Prices when looted", function() s().prices = "then" refresh() end, 140, "Values loot at the price it had when it dropped." },
      { "Today's prices", function() s().prices = "today" refresh() end, 120, "Revalues all old loot at today's prices." },
    }, plain = true },
    { "note", function()
      local m = metricOf(s().metric)
      return string.format("Showing: %s (%s), %s, %s. Ranked by the middle run's gold per hour, so one lucky drop doesn't decide it.",
        m.label, m.note, s().scope == "all" and "all characters" or "this character", today() and "today's prices" or "prices when looted")
    end },
    { "table", 8, {
      { key = "name", label = "Farm", width = 0, sort = function(x) return x.name end, text = function(x) return x.name end },
      { key = "runs", label = "Runs", width = 50, align = "RIGHT", sort = function(x) return x.runs end, text = function(x) return x.runs end },
      { key = "median", label = "Per hour", width = 110, align = "RIGHT", sort = function(x) return x.median end, text = function(x) return money(x.median) end },
      { key = "range", label = "Worst to best", width = 150, align = "RIGHT", sort = function(x) return x.high end,
        text = function(x) return ns.Prices.Money(math.max(0, x.low)) .. " - " .. ns.Prices.Money(math.max(0, x.high)) end },
      { key = "avg", label = "Avg time", width = 70, align = "RIGHT", sort = function(x) return x.avgMins end, text = function(x) return x.avgMins .. " min" end },
      { key = "steady", label = "Reliable?", width = 110, sort = function(x) return x.steady end,
        text = function(x) return (x.steadyColor == "good" and "|cff7fff7f" or x.steadyColor == "bad" and "|cffff7f7f" or "|cffd8c890") .. x.steady .. "|r" end },
    }, function() return M:Places() end, nil, sortKey = "median", desc = true },
    { "note", function() return #M:Runs() == 0 and "No runs saved yet for this choice. Each dungeon you finish and each farm timer you stop adds a row." or "" end },
    { "header", "Rare drops", icon = "INV_Misc_Gem_Pearl_04" },
    { "table", 6, {
      { key = "name", label = "Item", width = 0, sort = function(x) return x.name or "" end, text = function(x) return qname(x.name or ("item " .. x.id), x.q) end },
      { key = "place", label = "Farm", width = 150, sort = function(x) return x.place end, text = function(x) return x.place end },
      { key = "rate", label = "Seen in", width = 150, align = "RIGHT", sort = function(x) return x.rate end,
        text = function(x) return string.format("%d of %d runs (%d%%)", x.runsWith, x.of, math.floor(x.rate * 100 + 0.5)) end },
    }, function() return M:Drops() end, nil, sortKey = "rate", desc = false },
    { "note", "Green and better items. The number of runs is the sample size: 1 of 3 runs says little, 10 of 100 says a lot." },
    { "header", "Which character farms best", icon = "INV_Misc_Head_Human_01" },
    { "table", 5, {
      { key = "char", label = "Character", width = 0, sort = function(x) return x.char end, text = function(x) return (x.char:match("^[^-]+") or x.char) end },
      { key = "runs", label = "Runs", width = 60, align = "RIGHT", sort = function(x) return x.runs end, text = function(x) return x.runs end },
      { key = "perHour", label = "Per hour", width = 120, align = "RIGHT", sort = function(x) return x.perHour end, text = function(x) return money(x.perHour) end },
    }, function() return M:Characters(nil, today()) end, nil, sortKey = "perHour", desc = true },
    { "header", "Recent runs", icon = "Spell_Holy_SurgeOfLight" },
    { "cards", function()
      local out = {}
      for i, r in ipairs(M:Runs()) do
        if i > 6 then break end
        local v = M.Value(r, today())
        local m = v.metric[s().metric] or v.metric.ah
        out[#out + 1] = { pic = "Interface\\Icons\\" .. (r.kind == "dungeon" and "INV_Misc_Key_14" or "INV_Misc_Bag_10"),
          title = tostring(r.name), tags = { { date("%b %d %H:%M", r.start or 0), "plain" }, { money(M.PerHour(m, v.secs)) .. " an hour", "gold" } },
          line = string.format("%d min, coin %s, vendor %s, auction %s, costs %s, gold change %s", math.floor(v.secs / 60),
            ns.Prices.Money(v.coin), ns.Prices.Money(v.vendor), ns.Prices.Money(v.ah), ns.Prices.Money(v.spent),
            (v.real < 0 and "-" or "") .. ns.Prices.Money(math.abs(v.real))) }
      end
      return out
    end },
  })
end)

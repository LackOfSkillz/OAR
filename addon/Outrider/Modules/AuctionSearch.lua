-- Modules/AuctionSearch.lua
-- Free searches and shopping lists at the auction house (requirement 2026-11-22:
-- parity with Auctionator). Two views in the shopping window:
--   * Search: type what you want, with plain extras Outrider understands:
--       "linen cloth"            names containing it
--       "\"Linen Cloth\""        that exact name
--       lvl 10-20 / level 15     required level
--       under 5g / under 50s     the most you'd pay per item
--       green+ / blue+ / epic+   that quality or better
--       usable                   only what you can use
--       x20                      how many to buy (stackable goods)
--     The last searches are kept; click one to run it again.
--   * Shopping lists: save searches into named lists, search a whole list in
--     one go, import and export lists as text. Imports Auctionator lists
--     (Name^term^term, the item names) and TSM item lists (i:2589,i:2592).
-- Buy goes through the cart (AHBuy): one click per purchase, never over
-- the "under" price.

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local M = ns:NewModule("AuctionSearch", {
  title = "Auction search and shopping lists",
  phase = "P5",
  order = 79,
  defaults = { list = nil },
})
ns.AuctionSearch = M

M.HISTORY, M.MAX_LISTS, M.MAX_TERMS, M.WAIT = 15, 40, 100, 4

function M:OnInitialize()
  local g = ns.db.global
  g.ahSearchHistory = ns.KeepTable(g.ahSearchHistory, "AuctionSearch:g.ahSearchHistory") or {}
  g.ahLists = ns.KeepTable(g.ahLists, "AuctionSearch:g.ahLists") or {}
end

local function money(c) return ns.Prices.Money(c) end
local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- ------------------------------------------------------------ the query
M.QUALITY = { grey = 0, gray = 0, poor = 0, white = 1, common = 1, green = 2, uncommon = 2, blue = 3, rare = 3, purple = 4, epic = 4, orange = 5, legendary = 5 }

-- text -> { text, exact, minLevel, maxLevel, maxPrice, quality, orBetter, usable, qty, raw }
function M.Parse(input)
  local raw = trim(input)
  local q = { raw = raw }
  local s = raw
  -- an Auctionator term: the item name is the first field
  if s:find(";", 1, true) then s = s:match("^([^;]*)") or "" end
  local quoted = s:match('^"(.-)"')
  if quoted then q.exact = true s = s:gsub('^".-"', "", 1) end
  local words = {}
  local tokens = {}
  for w in s:gmatch("%S+") do tokens[#tokens + 1] = w end
  local i = 1
  while i <= #tokens do
    local w, lw = tokens[i], tokens[i]:lower()
    local nxt = tokens[i + 1] and tokens[i + 1]:lower()
    if (lw == "lvl" or lw == "level") and nxt and nxt:match("^%d+%-?%d*$") then
      local a, b = nxt:match("^(%d+)%-?(%d*)$")
      q.minLevel, q.maxLevel = tonumber(a), tonumber(b ~= "" and b or a)
      i = i + 2
    elseif (lw == "under" or lw == "max") and nxt and ns.AuctionSell and ns.AuctionSell.ParseMoney(nxt) then
      q.maxPrice = ns.AuctionSell.ParseMoney(nxt)
      i = i + 2
    elseif lw:sub(-1) == "+" and M.QUALITY[lw:sub(1, -2)] then
      -- "green+": that quality or better (a plain "green" stays part of the name)
      q.quality, q.orBetter = M.QUALITY[lw:sub(1, -2)], true
      i = i + 1
    elseif lw == "usable" then
      q.usable = true
      i = i + 1
    elseif lw:match("^x%d+$") then
      q.qty = tonumber(lw:sub(2))
      i = i + 1
    else
      words[#words + 1] = w
      i = i + 1
    end
  end
  local rest = trim(table.concat(words, " "))
  q.text = quoted and trim(quoted) or rest
  return q
end

-- Does a result fit the extras the server couldn't filter?
function M.Fits(q, itemID, price)
  local info = C.ItemInfo(itemID)
  if q.exact and q.text ~= "" and info and info.name and info.name:lower() ~= q.text:lower() then return false end
  if q.maxPrice and price and price > q.maxPrice then return false end
  if q.quality and info and info.quality then
    if q.orBetter then if info.quality < q.quality then return false end
    elseif info.quality ~= q.quality then return false end
  end
  if info and info.reqLevel and (q.minLevel or q.maxLevel) then
    if q.minLevel and info.reqLevel < q.minLevel then return false end
    if q.maxLevel and info.reqLevel > q.maxLevel then return false end
  end
  return true
end

local QUALITY_FILTER = { [0] = "PoorQuality", "CommonQuality", "UncommonQuality", "RareQuality", "EpicQuality", "LegendaryQuality" }

function M.BrowseQuery(q)
  local filters = {}
  local enum = C.Resolve("Enum.AuctionHouseFilter")
  if type(enum) == "table" then
    if q.quality then
      for k = q.quality, q.orBetter and 5 or q.quality do
        local v = enum[QUALITY_FILTER[k]]
        if v then filters[#filters + 1] = v end
      end
    end
    if q.usable and enum.UsableOnly then filters[#filters + 1] = enum.UsableOnly end
    if q.exact and enum.ExactMatch then filters[#filters + 1] = enum.ExactMatch end
  end
  return { searchString = q.text or "", sorts = { { sortOrder = 0, reverseSort = false } },
    filters = filters, itemClassFilters = {}, minLevel = q.minLevel, maxLevel = q.maxLevel }
end

-- ------------------------------------------------------------ searching
function M:Remember(raw)
  if raw == "" then return end
  local h = ns.db.global.ahSearchHistory
  for i = #h, 1, -1 do if h[i]:lower() == raw:lower() then table.remove(h, i) end end
  table.insert(h, 1, raw)
  while #h > M.HISTORY and ns.Archive:Pop("ahSearchHistory", h, { path = "global.ahSearchHistory" }) do end
end

-- Search one or several terms, one after another as the server allows.
function M:Run(terms, from)
  if not self.open then ns.Print("open the auction house first") return false end
  self.queue, self.pos, self.found, self.from = {}, 0, {}, from
  for _, t in ipairs(terms) do
    local q = M.Parse(t)
    if q.text ~= "" then self.queue[#self.queue + 1] = q end
  end
  if #self.queue == 0 then self.queue = nil return false end
  if #self.queue == 1 and from == "search" then self:Remember(self.queue[1].raw) end
  self:Info("auction search: %d term(s) (%s)", #self.queue, tostring(from))
  self:Next()
  return true
end

function M:Next()
  self.pos = (self.pos or 0) + 1
  local q = self.queue and self.queue[self.pos]
  if not q then self:Done() return end
  self.waiting = q
  pcall(C_AuctionHouse.SendBrowseQuery, M.BrowseQuery(q))
  ns.Timer.After(M.WAIT, function()
    if M.waiting == q then
      M.waiting = nil
      M.manual = true -- the server only answers a search made by a click
      M:Info("auction search: no answer for %s, one search per click now", q.raw)
      M:Changed()
    end
  end, "ahsearch:wait")
  self:Changed()
end

function M:OnResults()
  local q = self.waiting
  if not q then return end
  local results = C.Call("C_AuctionHouse.GetBrowseResults")
  if type(results) ~= "table" then return end
  self.waiting = nil
  for _, r in ipairs(results) do
    local key = r.itemKey
    local id = key and C.Readable(key.itemID)
    local price = tonumber(C.Readable(r.minPrice))
    if id and price and not self.found[id] then
      if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
      self.found[id] = { itemID = id, itemKey = key, price = price, qty = tonumber(C.Readable(r.totalQuantity)) or 1, q = q }
    end
  end
  if self.manual then self:Changed() else self:Next() end
end

function M:Done()
  self.queue, self.waiting, self.manual = nil, nil, nil
  local n = 0
  for _ in pairs(self.found or {}) do n = n + 1 end
  self:Info("auction search done: %d items", n)
  self:Changed()
end

-- { itemID, name, price, qty, commodity, action }
function M:Results()
  local out = {}
  for id, f in pairs(self.found or {}) do
    if M.Fits(f.q, id, f.price) then
      local info = C.ItemInfo(id)
      local commodity = ns.AuctionSell and ns.AuctionSell.IsCommodityKey(f.itemKey, id) or false
      local name = info and info.name or ("item " .. id)
      local action
      if commodity then
        action = { { name = name, itemID = id, qty = f.q.qty or 1, commodity = true, maxUnit = f.q.maxPrice } }
      else
        action = { { name = name, itemKey = f.itemKey, maxUnit = f.q.maxPrice } }
      end
      out[#out + 1] = { itemID = id, name = name, price = f.price, qty = f.qty, commodity = commodity,
        buy = commodity and (f.q.qty or 1) or 1, action = action, term = f.q.raw }
    end
  end
  table.sort(out, function(a, b) if a.price ~= b.price then return a.price < b.price end return a.name < b.name end)
  return out
end

function M:Changed()
  local G = ns.GearShop
  if G and G.open and (G.mode == "search" or G.mode == "lists") then
    ns.Throttle("ahsearch:refresh", 0.3, function() G:Refresh() end)
  end
end

-- ------------------------------------------------------------ lists
function M:Lists() return ns.db.global.ahLists end

function M:List(name)
  for _, l in ipairs(self:Lists()) do if l.name:lower() == tostring(name):lower() then return l end end
end

function M:Chosen()
  local l = self:List(self:Settings().list or "")
  return l or self:Lists()[1]
end

function M:NewList(name)
  name = trim(name):gsub("[%^\n]", "")
  if name == "" or #name > 40 then return nil, "a list name, up to 40 letters" end
  local l = self:List(name)
  if l then return l end
  if #self:Lists() >= M.MAX_LISTS then return nil, "too many lists" end
  l = { name = name, terms = {} }
  table.insert(self:Lists(), l)
  return l
end

function M:AddTerm(list, term)
  term = trim(term):gsub("[%^\n]", "")
  if not list or term == "" then return false end
  for _, t in ipairs(list.terms) do if t:lower() == term:lower() then return false end end
  if #list.terms >= M.MAX_TERMS then return false end
  list.terms[#list.terms + 1] = term
  return true
end

function M:DeleteList(list)
  for i, l in ipairs(self:Lists()) do if l == list then table.remove(self:Lists(), i) return true end end
end

-- "Name^term^term" (Auctionator's list format; our extras ride along in the terms)
function M.Export(list)
  return list.name .. "^" .. table.concat(list.terms, "^")
end

-- Imports one or more lists. Returns lists added, terms added.
function M:Import(text)
  text = tostring(text or "")
  local lists, terms = 0, 0
  local loose = {}
  for line in text:gmatch("[^\r\n]+") do
    line = trim(line)
    if line:find("^", 1, true) then
      local parts = {}
      for p in (line .. "^"):gmatch("(.-)%^") do parts[#parts + 1] = p end
      local l = self:NewList(parts[1] ~= "" and parts[1] or "Imported")
      if l then
        lists = lists + 1
        for k = 2, #parts do
          local q = M.Parse(parts[k])
          local term = q.exact and ('"' .. q.text .. '"') or q.text
          if term ~= "" and self:AddTerm(l, term) then terms = terms + 1 end
        end
      end
    elseif line:match("i:%d+") then
      for id in line:gmatch("i:(%d+)") do
        local info = C.ItemInfo(tonumber(id))
        if not info and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, tonumber(id)) end
        loose[#loose + 1] = info and ('"' .. info.name .. '"') or ("#" .. id)
      end
    elseif line ~= "" then
      loose[#loose + 1] = line
    end
  end
  if #loose > 0 then
    local l = self:NewList("Imported")
    if l then
      lists = lists + 1
      for _, t in ipairs(loose) do if self:AddTerm(l, t) then terms = terms + 1 end end
    end
  end
  self:Info("shopping lists imported: %d list(s), %d term(s)", lists, terms)
  return lists, terms
end

-- "#2589" terms (TSM imports of items not loaded yet) become names once known.
function M.Resolve(term)
  local id = tonumber(tostring(term):match("^#(%d+)$"))
  if not id then return term end
  local info = C.ItemInfo(id)
  return info and ('"' .. info.name .. '"') or term
end

-- ------------------------------------------------------------ the views
function M:View(mode)
  local cards = {}
  local searching = self.queue ~= nil
  local pos, total = self.pos or 0, self.queue and #self.queue or 0
  local list = mode == "lists" and self:Chosen() or nil
  local results = (not searching and self.found and self.from == mode) and self:Results() or nil
  if results then
    for _, r in ipairs(results) do
      cards[#cards + 1] = { itemID = r.itemID, item = { itemID = r.itemID }, title = r.name,
        sub = string.format("%d for sale, from %s each%s", r.qty, money(r.price), r.commodity and r.buy > 1 and string.format("  |cff8f96a6buys %d|r", r.buy) or ""),
        price = r.price * r.buy, action = r.action, pill = (mode == "lists") and r.term or nil }
    end
    local status = #cards > 0 and string.format("%d found. Buy is one click each; it never pays more than an \"under\" price.", #cards)
      or "Nothing for sale matches. Try fewer words."
    return cards, status, false, 0, 0
  end
  if searching then
    local q = self.queue[self.pos]
    local status = self.manual and string.format("The server wants a click per search: press Search again (%d of %d).", pos, total)
      or string.format("Searching %s (%d of %d)...", q and q.raw or "...", pos, total)
    return cards, status, true, pos, total
  end
  if mode == "search" then
    for _, raw in ipairs(ns.db.global.ahSearchHistory) do
      cards[#cards + 1] = { title = raw, icon = "Interface\\Icons\\INV_Misc_Spyglass_02", sub = "a recent search",
        button = { label = "Search", primary = false, click = function() M:Run({ raw }, "search") end },
        onRight = function()
          local h = ns.db.global.ahSearchHistory
          for i = #h, 1, -1 do if h[i] == raw then table.remove(h, i) end end
          M:Changed()
        end }
    end
    return cards, #cards > 0 and "Type above and press Enter. Your recent searches are below (right-click removes one)."
      or "Type above and press Enter. Extras: \"exact name\", lvl 10-20, under 5g, green+, usable, x20.", false, 0, 0
  end
  if not list then
    return cards, "No shopping lists yet. Search for something, then Save to list, or Import a list from Auctionator or TSM.", false, 0, 0
  end
  for _, t in ipairs(list.terms) do
    local term = M.Resolve(t)
    cards[#cards + 1] = { title = term, icon = "Interface\\Icons\\INV_Scroll_05", sub = "in " .. list.name,
      button = { label = "Search", primary = false, click = function() M:Run({ term }, "lists") end },
      onRight = function()
        for i = #list.terms, 1, -1 do if list.terms[i] == t then table.remove(list.terms, i) end end
        M:Changed()
      end }
  end
  return cards, string.format("%s: %d searches. Search all runs them one after another. Right-click removes one.", list.name, #list.terms), false, 0, 0
end

function M:OnPick() end

-- ------------------------------------------------------------ toolbar
function M:Toolbar(parent, mode)
  self.bars = self.bars or {}
  local bar = self.bars[mode]
  if not bar then
    bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(540, 28)
    if mode == "search" then
      bar.box = UI:SearchBox(bar, 300, "What are you looking for?")
      bar.box:SetPoint("LEFT", 0, 0)
      bar.box:SetScript("OnEnterPressed", function(box) box:ClearFocus() M:Run({ box:GetText() or "" }, "search") end)
      bar.go = UI:Button(bar, "Search", 80, function()
        if M:ClickNext() then return end
        M:Run({ bar.box:GetText() or "" }, "search")
      end)
      bar.go:SetPoint("LEFT", bar.box, "RIGHT", 6, 0)
      UI.SetPrimary(bar.go, true)
      bar.save = UI:Button(bar, "Save to list", 110, function()
        local text = trim(bar.box:GetText())
        if text == "" then ns.Print("type a search first") return end
        local l = M:Chosen() or M:NewList("My list")
        if M:AddTerm(l, text) then ns.Print("saved to %s", l.name) else ns.Print("already in %s", l.name) end
        M:Changed()
      end)
      bar.save:SetPoint("LEFT", bar.go, "RIGHT", 6, 0)
      UI.Tip(bar.save, "Save to list", "Puts this search in your shopping list (the one picked on Shopping lists).")
    else
      bar.chips = {}
      bar.search = UI:Button(bar, "Search all", 92, function()
        local l = M:Chosen()
        if not l or #l.terms == 0 then ns.Print("this list is empty") return end
        local terms = {}
        if M:ClickNext() then return end
        for _, t in ipairs(l.terms) do terms[#terms + 1] = M.Resolve(t) end
        M:Run(terms, "lists")
      end)
      UI.SetPrimary(bar.search, true)
      bar.new = UI:Button(bar, "New", 52, function()
        UI:TextDialog("New shopping list", "", "paste", function(text)
          local l, why = M:NewList(text)
          if not l then error(why) end
          M:Settings().list = l.name
          M:Changed()
        end)
      end)
      UI.Tip(bar.new, "New list", "Type a name, then Accept.")
      bar.import = UI:Button(bar, "Import", 64, function()
        UI:TextDialog("Import shopping lists", "", "paste", function(text)
          local lists, terms = M:Import(text)
          if lists == 0 then error("nothing to import: paste Name^item^item, item names one per line, or TSM i:123 lists") end
          ns.Print("imported %d list(s), %d search(es)", lists, terms)
          M:Changed()
        end)
      end)
      UI.Tip(bar.import, "Import", "Paste lists from Auctionator (Name^item^item), TSM (i:2589,i:2592) or item names, one per line.")
      bar.export = UI:Button(bar, "Export", 64, function()
        local l = M:Chosen()
        if not l then ns.Print("no list to export") return end
        UI:TextDialog("Export " .. l.name, M.Export(l), "copy")
      end)
      UI.Tip(bar.export, "Export", "Text you can copy into Auctionator or share with a friend.")
      bar.delete = UI:Button(bar, "Delete", 64, function()
        local l = M:Chosen()
        if not l then return end
        if bar.armed ~= l then bar.armed = l ns.Print("click Delete again to delete %s", l.name) return end
        M:DeleteList(l)
        bar.armed = nil
        ns.Print("deleted %s", l.name)
        M:Changed()
      end)
      UI.Tip(bar.delete, "Delete list", "Click twice to delete the picked list.")
    end
    self.bars[mode] = bar
  end
  if mode == "lists" then
    for _, chip in ipairs(bar.chips) do chip:Hide() end
    local x, chosen = 0, self:Chosen()
    for i, l in ipairs(self:Lists()) do
      if i > 4 then break end
      local chip = bar.chips[i]
      if not chip then
        chip = UI:Chip(bar, "list", function(c) M:Settings().list = c.listName M:Changed() end)
        bar.chips[i] = chip
      end
      chip.listName = l.name
      chip.label:SetText(l.name)
      chip:SetWidth(math.max(54, ((chip.label.GetStringWidth and chip.label:GetStringWidth()) or (#l.name * 6)) + 22))
      chip:ClearAllPoints()
      chip:SetPoint("LEFT", x, 0)
      chip:SetOn(l == chosen)
      chip:Show()
      x = x + chip:GetWidth() + 4
    end
    bar.search:ClearAllPoints() bar.search:SetPoint("LEFT", x + (x > 0 and 8 or 0), 0)
    bar.new:ClearAllPoints() bar.new:SetPoint("LEFT", bar.search, "RIGHT", 6, 0)
    bar.import:ClearAllPoints() bar.import:SetPoint("LEFT", bar.new, "RIGHT", 4, 0)
    bar.export:ClearAllPoints() bar.export:SetPoint("LEFT", bar.import, "RIGHT", 4, 0)
    bar.delete:ClearAllPoints() bar.delete:SetPoint("LEFT", bar.export, "RIGHT", 4, 0)
  elseif self.manual and self.queue then
    bar.go.label:SetText("Search next")
  else
    bar.go.label:SetText("Search")
  end
  return bar
end

function M:OnEnable()
  self:On("AUCTION_HOUSE_SHOW", function(mod) mod.open = true end)
  self:On("AUCTION_HOUSE_CLOSED", function(mod) mod.open, mod.queue, mod.waiting, mod.manual = false, nil, nil, nil end)
  self:On("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", self.OnResults)
  self:On("GET_ITEM_INFO_RECEIVED", function(mod) if mod.open and mod.found then mod:Changed() end end)
end

-- A click on Search while the server wants one search per click.
function M:ClickNext()
  if self.manual and self.queue then self:Next() return true end
end

function M:Activity()
  return string.format("%d shopping lists, %d recent searches", #self:Lists(), #ns.db.global.ahSearchHistory)
end

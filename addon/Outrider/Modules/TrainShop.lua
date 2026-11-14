-- Modules/TrainShop.lua
-- Auction-house shopping for profession training (Gary, 2026-11-14: "search
-- the auction house to find ingredients I need to gain skill ... and recipes
-- ... for leatherworking, alchemy, cooking ... recommend what I should buy").
-- With the auction house open, one click on "Find training materials":
--   1. Needs: for every crafting profession this character has, each known
--      recipe that still gives skill (orange, yellow, green; colours from the
--      last time its window was open) and the ingredients it uses.
--   2. Searches the auction house for each ingredient, plus the recipe
--      category of each profession (modern C_AuctionHouse browse queries, one
--      after another as the server allows). If the server only answers a
--      search made by a click, the button becomes "Search next" instead.
--   3. Ranks recipes by cost per skill point (ingredients already in the bags
--      are free; skill chance: orange 1, yellow 0.75, green 0.25) and lists
--      recipes for sale that this character doesn't know yet, with the skill
--      they need (read from the item's tooltip).
-- Read only: buying is Gary's own click in Blizzard's auction window.

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local M = ns:NewModule("TrainShop", {
  title = "Training shopping at the auction house",
  phase = "P5",
  order = 77,
  defaults = {},
})
ns.TrainShop = M

M.CHANCE = { [0] = 1, [1] = 0.75, [2] = 0.25 }
M.CRAFTS = { [0] = 10, [1] = 8, [2] = 4 } -- how many to plan per recipe before it likely greys
-- Recipe item subclasses (Enum.ItemRecipeSubclass in the client)
M.RECIPE_SUB = { Leatherworking = 1, Tailoring = 2, Engineering = 3, Blacksmithing = 4, Cooking = 5,
  Alchemy = 6, ["First Aid"] = 7, Enchanting = 8, Fishing = 9 }
M.RECIPE_CLASS = 9
M.WAIT = 4 -- seconds to wait for an answer before switching to one search per click

local function have(id) return ns.Crafter and ns.Crafter.Have(id) or 0 end
local function itemName(id) local i = C.ItemInfo(id) return i and i.name or nil end

-- { {prof, recipe, diff, reagents} } for every skill-giving recipe
function M:Recipes()
  local out = {}
  local T = ns.ProfTrainer
  for _, prof in ipairs(T and T:Professions() or {}) do
    local p = ns.db.char.professions[prof]
    for id, r in pairs(p.recipes or {}) do
      local diff = type(r) == "table" and tonumber(r.diff)
      if diff and M.CHANCE[diff] and r.name ~= "Basic Campfire" and type(r.reagents) == "table" and next(r.reagents) then
        out[#out + 1] = { prof = prof, id = id, name = r.name, diff = diff, reagents = r.reagents }
      end
    end
  end
  table.sort(out, function(a, b) if a.prof ~= b.prof then return a.prof < b.prof end return tostring(a.name) < tostring(b.name) end)
  return out
end

-- Ingredients worth looking up: { [itemID] = name } for everything the
-- skill-giving recipes use that the bags don't already hold enough of.
function M:Needs()
  local out = {}
  for _, r in ipairs(self:Recipes()) do
    for itemID, need in pairs(r.reagents) do
      if have(itemID) < need * (M.CRAFTS[r.diff] or 1) then out[itemID] = itemName(itemID) or out[itemID] or true end
    end
  end
  return out
end

-- ------------------------------------------------------------ searching
function M:Queue()
  local q = {}
  for itemID, name in pairs(self:Needs()) do
    if type(name) == "string" then q[#q + 1] = { kind = "item", itemID = itemID, text = name } end
  end
  table.sort(q, function(a, b) return a.text < b.text end)
  local owned = ns.Crafter and ns.Crafter:Owned() or {}
  local profs = {}
  for prof in pairs(owned) do if M.RECIPE_SUB[prof] then profs[#profs + 1] = prof end end
  table.sort(profs)
  for _, prof in ipairs(profs) do q[#q + 1] = { kind = "recipes", prof = prof, text = prof .. " recipes" } end
  return q
end

function M:Query(entry)
  local sorts = { { sortOrder = 0, reverseSort = false } } -- price, low first
  local query
  if entry.kind == "item" then
    query = { searchString = entry.text, sorts = sorts, filters = {} }
  else
    query = { searchString = "", sorts = sorts, filters = {},
      itemClassFilters = { { classID = M.RECIPE_CLASS, subClassID = M.RECIPE_SUB[entry.prof] } } }
  end
  local ok = pcall(C_AuctionHouse.SendBrowseQuery, query)
  self.waiting = { entry = entry, t = GetTime and GetTime() or 0 }
  self:Debug("search %s (%s)", entry.text, ok and "sent" or "failed")
  ns.Timer.After(M.WAIT, function() M:Timeout(entry) end, "trainshop:wait")
  return ok
end

-- Start (Gary's click). Searches run back to back; if one goes unanswered the
-- rest wait for a click each.
function M:Start()
  if not self.open then ns.Print("open the auction house first") return end
  self.queue, self.pos, self.prices, self.recipesForSale = self:Queue(), 0, {}, {}
  self.manual = false
  self:Info("training shopping: %d searches", #self.queue)
  self:Next()
end

function M:Next()
  if not self.queue then return end
  self.pos = self.pos + 1
  local e = self.queue[self.pos]
  if not e then self.waiting = nil self:Done() return end
  local ready = C.Call("C_AuctionHouse.IsThrottledMessageSystemReady")
  if ready == false then self.pendingNext = true self:Refresh() return end
  self:Query(e)
  self:Refresh()
end

function M:Timeout(entry)
  if self.waiting and self.waiting.entry == entry then
    self.waiting = nil
    if not self.manual then
      self.manual = true
      self:Info("search %s got no answer: one search per click from here", entry.text)
    end
    self:Refresh()
  end
end

-- Results for the search in flight.
function M:OnResults()
  local w = self.waiting
  if not w then return end
  local results = C.Call("C_AuctionHouse.GetBrowseResults")
  if type(results) ~= "table" then return end
  self.waiting = nil
  for _, r in ipairs(results) do
    local id = r.itemKey and r.itemKey.itemID
    local price = C.Readable(r.minPrice)
    if id and type(price) == "number" then
      if w.entry.kind == "item" then
        if id == w.entry.itemID then self.prices[id] = { price = price, qty = C.Readable(r.totalQuantity) } end
      else
        self:NoteRecipe(w.entry.prof, id, price)
      end
    end
  end
  if self.manual then self:Refresh() else self:Next() end
end

-- A recipe for sale: keep it when the tooltip says it's not known yet, with the skill it needs.
function M:NoteRecipe(prof, itemID, price)
  local tip = C.Call("C_TooltipInfo.GetItemByID", itemID)
  local need, known
  for _, line in ipairs(type(tip) == "table" and tip.lines or {}) do
    local t = C.Readable(line.leftText)
    if type(t) == "string" then
      local n = t:match("Requires " .. prof .. " %((%d+)%)")
      if n then need = tonumber(n) end
      if t:find("Already known", 1, true) then known = true end
    end
  end
  if known then return end
  self.recipesForSale[#self.recipesForSale + 1] = { prof = prof, itemID = itemID, name = itemName(itemID) or ("item " .. itemID),
    price = price, need = need }
end

-- ------------------------------------------------------------ ranking
-- { {recipe, perPoint, buy = { {itemID, n, cost} }, cost, missing = bool} } cheapest per point first
function M:Rank()
  local out = {}
  local left = {}
  for _, r in ipairs(self:Recipes()) do
    local crafts = M.CRAFTS[r.diff] or 1
    local cost, buy, missing = 0, {}, false
    for itemID, need in pairs(r.reagents) do
      if left[itemID] == nil then left[itemID] = have(itemID) end
      local want = need * crafts
      local from = math.min(left[itemID], want)
      left[itemID] = left[itemID] - from
      local short = want - from
      if short > 0 then
        local p = self.prices and self.prices[itemID]
        if p then
          cost = cost + short * p.price
          buy[#buy + 1] = { itemID = itemID, n = short, cost = short * p.price }
        else
          missing = true
          buy[#buy + 1] = { itemID = itemID, n = short }
        end
      end
    end
    local points = crafts * M.CHANCE[r.diff]
    out[#out + 1] = { recipe = r, crafts = crafts, points = points, cost = cost, perPoint = math.floor(cost / points), buy = buy, missing = missing }
  end
  table.sort(out, function(a, b)
    if a.missing ~= b.missing then return not a.missing end
    if a.perPoint ~= b.perPoint then return a.perPoint < b.perPoint end
    return tostring(a.recipe.name) < tostring(b.recipe.name)
  end)
  return out
end

function M:Lines()
  local lines = {}
  local money = ns.Prices.Money
  for i, x in ipairs(self:Rank()) do
    if i > 8 then break end
    local parts = {}
    for _, b in ipairs(x.buy) do
      parts[#parts + 1] = string.format("%d %s%s", b.n, itemName(b.itemID) or "?", b.cost and "" or " (not on AH)")
    end
    local head = string.format("%s: %s, about +%d", x.recipe.prof, tostring(x.recipe.name), math.floor(x.points))
    if #parts == 0 then
      lines[#lines + 1] = head .. " |cff7fff7f(you have everything)|r"
    elseif x.missing then
      lines[#lines + 1] = head .. ": buy " .. table.concat(parts, ", ")
    else
      lines[#lines + 1] = string.format("%s: %s per point, buy %s (%s)", head, money(x.perPoint), table.concat(parts, ", "), money(x.cost))
    end
  end
  local forSale = self.recipesForSale or {}
  table.sort(forSale, function(a, b) return a.price < b.price end)
  if #forSale > 0 then
    lines[#lines + 1] = "|cffffd100Recipes for sale you don't know|r"
    for i = 1, math.min(6, #forSale) do
      local r = forSale[i]
      local skill = ns.db.char.professions[r.prof] and tonumber(ns.db.char.professions[r.prof].skill)
      lines[#lines + 1] = string.format("%s: %s%s", money(r.price), r.name,
        r.need and string.format(" (needs %s %d%s)", r.prof, r.need, skill and (", you " .. skill) or "") or "")
    end
  end
  return lines
end

function M:Done()
  self.queue = nil
  local n = 0
  for _ in pairs(self.prices or {}) do n = n + 1 end
  self:Info("training shopping done: %d ingredients priced, %d recipes for sale", n, #(self.recipesForSale or {}))
  self:Refresh()
end

-- ------------------------------------------------------------ panel
function M:Build()
  if self.frame then return self.frame end
  local anchor = rawget(_G, "AuctionHouseFrame") or UIParent
  local f = CreateFrame("Frame", "Outrider_TrainShop", anchor, ns.Theme:BackdropTemplate())
  ns.Theme:ApplyPanel(f, "panel")
  f:SetSize(420, 300)
  -- above the auction window and draggable by its title (Gary, 2026-11-14: "it
  -- pops under the auction window"); where he drops it is kept per character
  f:SetFrameStrata("HIGH")
  f:SetClampedToScreen(true)
  local pt = M:Settings().point
  if type(pt) == "table" then
    f:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4])
  else
    f:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 6, -180) -- right of the AH, under the auction helper
  end
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(fr) fr:StartMoving() end)
  f:SetScript("OnDragStop", function(fr)
    fr:StopMovingOrSizing()
    local a, _, b, x, y = fr:GetPoint()
    M:Settings().point = { a, b, x, y }
  end)
  f.title = UI.Text(f, "normal", "accent")
  f.title:SetPoint("TOPLEFT", 8, -8)
  f.title:SetText("Training shopping  |cff888888(drag to move)|r")
  f.button = UI:Button(f, "Find training materials", 190, function()
    if M.queue and M.manual then M:Next() else M:Start() end
  end)
  f.button:SetPoint("TOPRIGHT", -8, -6)
  f.text = UI.Text(f, "small", "text")
  f.text:SetPoint("TOPLEFT", 8, -36)
  f.text:SetWidth(404)
  f.text:SetJustifyH("LEFT")
  f.text:SetJustifyV("TOP")
  f:Hide()
  self.frame = f
  return f
end

function M:Refresh()
  if not self.open then return end
  local f = self:Build()
  if self.queue then
    local e = self.queue[self.pos]
    f.button.label:SetText(self.manual and string.format("Search next (%d/%d)", self.pos, #self.queue) or "Searching...")
    f.text:SetText(string.format("Searching the auction house: %s (%d of %d)", e and e.text or "...", self.pos, #self.queue))
  else
    f.button.label:SetText(self.prices and "Search again" or "Find training materials")
    if self.prices then
      local lines = self:Lines()
      f.text:SetText(#lines > 0 and table.concat(lines, "\n") or "Nothing found that trains your professions.")
    else
      local n = 0
      for _ in pairs(self:Needs()) do n = n + 1 end
      f.text:SetText(n > 0 and string.format("Looks up %d ingredients your skill-up recipes need, and recipes you don't know yet. Buying stays your click.", n)
        or "Open each profession window once so Outrider knows which recipes still give skill.")
    end
  end
  f:Show()
end

function M:OnEnable()
  self:On("AUCTION_HOUSE_SHOW", function(mod) mod.open = true mod:Refresh() end)
  self:On("AUCTION_HOUSE_CLOSED", function(mod)
    mod.open, mod.queue, mod.waiting = false, nil, nil
    if mod.frame then mod.frame:Hide() end
  end)
  self:On("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", self.OnResults)
  self:On("AUCTION_HOUSE_THROTTLED_SYSTEM_READY", function(mod)
    if mod.pendingNext then mod.pendingNext = false mod.pos = mod.pos - 1 mod:Next() end
  end)
end

function M:OnDisable() if self.frame then self.frame:Hide() end end

function M:Activity()
  local n = 0
  for _ in pairs(self:Needs()) do n = n + 1 end
  return string.format("%d ingredients to look up for training (open the auction house)", n)
end

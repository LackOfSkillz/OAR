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
-- Pick a profession (Gary, 2026-11-16: "I should be able to select which
-- training I want to do"): chips for this character's crafting professions
-- only, plus All. One profession searches only its own ingredients and
-- recipes; All gives every profession a share of the list, so a long Cooking
-- list no longer pushes Alchemy off the panel.

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local M = ns:NewModule("TrainShop", {
  title = "Training shopping at the auction house",
  phase = "P5",
  order = 77,
  defaults = { prof = nil },
})
ns.TrainShop = M

M.CHANCE = { [0] = 1, [1] = 0.75, [2] = 0.25 }
M.CRAFTS = { [0] = 10, [1] = 8, [2] = 4 } -- how many to plan per recipe before it likely greys
-- Recipe item subclasses (Enum.ItemRecipeSubclass in the client)
M.RECIPE_SUB = { Leatherworking = 1, Tailoring = 2, Engineering = 3, Blacksmithing = 4, Cooking = 5,
  Alchemy = 6, ["First Aid"] = 7, Enchanting = 8, Fishing = 9 }
M.RECIPE_CLASS = 9
M.SHOW = 8 -- recipe lines on the panel
M.WAIT = 4 -- seconds to wait for an answer before switching to one search per click

local function have(id) return ns.Crafter and ns.Crafter.Have(id) or 0 end
local function itemName(id) local i = C.ItemInfo(id) return i and i.name or nil end

-- This character's crafting professions (gathering ones have no recipes).
function M:Professions()
  local T = ns.ProfTrainer
  return T and T:Professions() or {}
end

-- The chosen profession, or nil for All (a choice this character lacks = All).
function M:Chosen()
  local want = self:Settings().prof
  for _, p in ipairs(self:Professions()) do if p == want then return p end end
  return nil
end

function M:Choose(prof)
  self:Settings().prof = prof
  self.prices, self.recipesForSale, self.queue = nil, nil, nil
  self:Info("training shopping: %s", prof or "all professions")
  if self.open then self:Start() else self:Refresh() end
end

-- { {prof, recipe, diff, reagents} } for every skill-giving recipe
function M:Recipes()
  local out = {}
  local chosen = self:Chosen()
  for _, prof in ipairs(self:Professions()) do
    local p = (not chosen or prof == chosen) and ns.db.char.professions[prof]
    for id, r in pairs(p and p.recipes or {}) do
      local diff = type(r) == "table" and tonumber(r.diff)
      if diff and M.CHANCE[diff] and r.name ~= "Basic Campfire" and type(r.reagents) == "table" and next(r.reagents) then
        out[#out + 1] = { prof = prof, id = id, name = r.name, diff = diff, reagents = r.reagents, product = r.product }
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
  local profs, chosen = {}, self:Chosen()
  for prof in pairs(owned) do
    if M.RECIPE_SUB[prof] and (not chosen or prof == chosen) then profs[#profs + 1] = prof end
  end
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
  self.queue, self.pos, self.prices, self.recipesForSale, self.seenRecipes = self:Queue(), 0, {}, {}, 0
  self.knownHidden, self.altHidden = 0, {}
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
        self:NoteRecipe(w.entry.prof, id, price, r.itemKey)
      end
    end
  end
  if self.manual then self:Refresh() else self:Next() end
end

-- A recipe for sale: keep it when the tooltip says it's not known yet, with the skill it needs.
function M:NoteRecipe(prof, itemID, price, itemKey)
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
  -- known by name too: "Recipe: Elixir of Minor Defense" vs the recipes we stored
  local name = itemName(itemID)
  local taught = name and name:match("^[%a ]+: (.+)$")
  if M.Knows(ns.db.char, prof, taught) then known = true end
  self.seenRecipes = (self.seenRecipes or 0) + 1
  if known then self.knownHidden = (self.knownHidden or 0) + 1 return end
  -- one of your other characters knows it (Gary, 2026-11-20: "filter out
  -- recipes that I already know"): left out, and the status line says who
  local alts = M.AltsKnowing(prof, taught)
  if #alts > 0 then
    self.altHidden = self.altHidden or {}
    for _, who in ipairs(alts) do self.altHidden[who] = (self.altHidden[who] or 0) + 1 end
    return
  end
  self.recipesForSale[#self.recipesForSale + 1] = { prof = prof, itemID = itemID, name = name or ("item " .. itemID),
    price = price, need = need, itemKey = itemKey or { itemID = itemID } }
end

-- "Hidden: 3 you know, 2 Khreos knows."
function M:HiddenText()
  local parts = {}
  if (self.knownHidden or 0) > 0 then parts[1] = string.format("%d you know", self.knownHidden) end
  local names = {}
  for who in pairs(self.altHidden or {}) do names[#names + 1] = who end
  table.sort(names)
  for _, who in ipairs(names) do parts[#parts + 1] = string.format("%d %s knows", self.altHidden[who], who) end
  if #parts == 0 then return "" end
  return "  |cff8f96a6Hidden: " .. table.concat(parts, ", ") .. ".|r"
end

-- Does this character record (ns.db.chars[key]) know the recipe called `taught`?
function M.Knows(char, prof, taught)
  if type(taught) ~= "string" or type(char) ~= "table" then return false end
  local rec = type(char.professions) == "table" and char.professions[prof]
  if not (rec and type(rec.recipes) == "table") then return false end
  local want = taught:lower()
  for _, r in pairs(rec.recipes) do
    if type(r) == "table" and type(r.name) == "string" and r.name:lower() == want then return true end
  end
  return false
end

-- Short names of your other characters who know it (from their profession windows).
function M.AltsKnowing(prof, taught)
  local out = {}
  local chars = ns.db and ns.db.raw and ns.db.raw.chars or {}
  for key, c in pairs(chars) do
    if key ~= ns.db.key and M.Knows(c, prof, taught) then out[#out + 1] = (tostring(key):match("^([^%-]+)")) end
  end
  table.sort(out)
  return out
end

-- Recipes worth showing: skill known, usable now or within 25 points; usable
-- now first, then cheapest (Gary's first search found 119, 2026-11-14).
M.SOON = 25
function M:UsefulRecipes()
  local out, unknown = {}, 0
  for _, r in ipairs(self.recipesForSale or {}) do
    local rec = ns.db.char.professions[r.prof]
    local skill = rec and tonumber(rec.skill)
    if not r.need or not skill then unknown = unknown + 1
    elseif r.need <= skill + M.SOON then
      r.now = r.need <= skill
      out[#out + 1] = r
    end
  end
  table.sort(out, function(a, b)
    if a.now ~= b.now then return a.now end
    if a.price ~= b.price then return a.price < b.price end
    return a.name < b.name
  end)
  return out, unknown
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

-- lines, actions: actions[i] is what that line's Buy button queues (or nil)
function M:Lines()
  local lines, actions = {}, {}
  local money = ns.Prices.Money
  local picked = self:Picked()
  for _, x in ipairs(picked) do
    local parts = {}
    for _, b in ipairs(x.buy) do
      parts[#parts + 1] = string.format("%d %s%s", b.n, itemName(b.itemID) or "?", b.cost and "" or " (not on the AH: a vendor may sell it)")
    end
    local head = string.format("%s: %s, about +%d", x.recipe.prof, tostring(x.recipe.name), math.floor(x.points))
    if #parts == 0 then
      lines[#lines + 1] = head .. " |cff7fff7f(you have everything)|r"
    elseif x.missing then
      lines[#lines + 1] = head .. ": buy " .. table.concat(parts, ", ")
    else
      lines[#lines + 1] = string.format("%s: %s per point, buy %s (%s)", head, money(x.perPoint), table.concat(parts, ", "), money(x.cost))
    end
    local buys = {}
    for _, b in ipairs(x.buy) do
      if b.cost then buys[#buys + 1] = { name = itemName(b.itemID) or ("item " .. b.itemID), itemID = b.itemID, qty = b.n, commodity = true } end
    end
    if #buys > 0 then actions[#lines] = buys end
  end
  local forSale = self:UsefulRecipes()
  if #forSale > 0 then
    lines[#lines + 1] = "|cffffd100Recipes for sale you don't know (usable now or soon)|r"
    for i = 1, math.min(6, #forSale) do
      local r = forSale[i]
      local skill = tonumber(ns.db.char.professions[r.prof].skill)
      lines[#lines + 1] = string.format("%s: %s (needs %s %d, you %d)%s", money(r.price), r.name, r.prof, r.need, skill,
        r.now and "" or " |cff888888later|r")
      actions[#lines] = { { name = r.name, itemKey = r.itemKey } }
    end
  end
  return lines, actions
end

function M:Done()
  self.queue = nil
  local n = 0
  for _ in pairs(self.prices or {}) do n = n + 1 end
  local useful, unknown = self:UsefulRecipes()
  self:Info("training shopping done: %d ingredients priced; recipes: %d seen, %d not known, %d usable now or soon, %d without skill info",
    n, self.seenRecipes or 0, #(self.recipesForSale or {}), #useful, unknown)
  self:Refresh()
end

-- ------------------------------------------------------------ panel
-- Drawn inside the shopping window (GearShop): the profession chips, and the
-- cards for its three Training views (Gary, 2026-11-20: sub-items for training).

-- The skill-up lines on show: All gives each profession a fair share.
function M:Picked()
  local ranked, picked = self:Rank(), {}
  local profs = {}
  for _, x in ipairs(ranked) do profs[x.recipe.prof] = true end
  local n = 0
  for _ in pairs(profs) do n = n + 1 end
  local share, used = math.max(1, math.ceil(M.SHOW / math.max(1, n))), {}
  for _, x in ipairs(ranked) do
    local p = x.recipe.prof
    if #picked < M.SHOW and (used[p] or 0) < share then picked[#picked + 1] = x used[p] = (used[p] or 0) + 1 end
  end
  return picked
end

local function profIcon(prof)
  local P = ns.ProfExtras and ns.ProfExtras.PROF_ICON
  return "Interface\\Icons\\" .. ((P and P[prof]) or "INV_Misc_Book_09")
end

-- cards, status, searching, pos, total for "training" | "recipes" | "list"
function M:View(view)
  local money = ns.Prices.Money
  if self.queue then
    local e = self.queue[self.pos]
    local s = self.manual and string.format("The server wants a click per search: press %s again (%d of %d).", view == "recipes" and "Recipes" or "Skill-ups", self.pos, #self.queue)
      or string.format("Searching the auction house: %s (%d of %d)...", e and e.text or "...", self.pos, #self.queue)
    return {}, s, true, self.pos, #self.queue
  end
  if not self.prices then
    local n = 0
    for _ in pairs(self:Needs()) do n = n + 1 end
    return {}, n > 0 and string.format("Looks up the %d ingredients your skill-up recipes need, and recipes you don't know yet.", n)
      or "Open each profession window once so Outrider knows which recipes still give skill.", false, 0, 0
  end
  local cards = {}
  if view == "recipes" then
    for _, r in ipairs(self:UsefulRecipes()) do
      local skill = tonumber(ns.db.char.professions[r.prof].skill) or 0
      cards[#cards + 1] = { itemID = r.itemID, item = { itemID = r.itemID }, title = r.name,
        sub = string.format("Needs %s %d, you have %d%s", r.prof, r.need, skill, r.now and "" or string.format("  |cffffc84d(%d more points)|r", r.need - skill)),
        pill = r.now and "|cff7fff7fusable now|r" or "|cff8f96a6later|r", price = r.price, dim = not r.now,
        action = { { name = r.name, itemKey = r.itemKey } } }
    end
    return cards, (#cards > 0 and "Recipes for sale that you don't know yet: usable now first, then cheapest. Buy queues it; the bar above the auction window confirms."
      or "No recipe for sale that you don't know and could use soon.") .. self:HiddenText(), false, 0, 0
  end
  local picked = self:Picked()
  if view == "list" then
    local sum, order = {}, {}
    for _, x in ipairs(picked) do
      for _, b in ipairs(x.buy) do
        local s = sum[b.itemID]
        if not s then s = { itemID = b.itemID, n = 0, cost = b.cost and 0 or nil, for_ = {} } sum[b.itemID] = s order[#order + 1] = s end
        s.n = s.n + b.n
        if s.cost and b.cost then s.cost = s.cost + b.cost else s.cost = nil end
        s.for_[#s.for_ + 1] = tostring(x.recipe.name)
      end
    end
    table.sort(order, function(a, b) if (a.cost == nil) ~= (b.cost == nil) then return a.cost ~= nil end return (a.cost or 0) > (b.cost or 0) end)
    for _, s in ipairs(order) do
      local name = itemName(s.itemID) or ("item " .. s.itemID)
      cards[#cards + 1] = { itemID = s.itemID, item = { itemID = s.itemID }, title = name,
        sub = s.cost and ("For " .. table.concat(s.for_, ", ")) or "Not on the auction house: a vendor may sell it",
        pill = "x" .. s.n, price = s.cost, priceText = s.cost and nil or "|cff8f96a6vendor|r", dim = s.cost == nil,
        action = s.cost and { { name = name, itemID = s.itemID, qty = s.n, commodity = true } } or nil }
    end
    return cards, #cards > 0 and "Everything the skill-ups need that your bags don't hold, added up. Buy all queues it; each purchase still waits for your click."
      or "Your bags already hold what the skill-ups need.", false, 0, 0
  end
  for _, x in ipairs(picked) do
    local buys, reagents = {}, {}
    for _, b in ipairs(x.buy) do
      reagents[#reagents + 1] = { itemID = b.itemID, n = b.n, short = b.cost == nil }
      if b.cost then buys[#buys + 1] = { name = itemName(b.itemID) or ("item " .. b.itemID), itemID = b.itemID, qty = b.n, commodity = true } end
    end
    local r = x.recipe
    local pill = string.format("+%d skill", math.floor(x.points))
    if #x.buy > 0 and not x.missing then pill = pill .. "  ·  " .. money(x.perPoint) .. " a point" end
    cards[#cards + 1] = { itemID = r.product, icon = not r.product and profIcon(r.prof) or nil, item = r.product and { itemID = r.product } or nil,
      title = string.format("%s  |cff8f96a6%s|r", tostring(r.name), r.prof),
      sub = #x.buy == 0 and "|cff7fff7fYou have everything: craft it|r" or nil,
      reagents = reagents, pill = pill, price = (#x.buy > 0 and not x.missing) and x.cost or nil,
      priceText = #x.buy == 0 and "|cff7fff7ffree|r" or (x.missing and "|cffffc84dpart from a vendor|r" or nil),
      action = #buys > 0 and buys or nil }
  end
  return cards, #cards > 0 and "Cheapest skill first. Amber counts: not on the auction house (a vendor may sell them)."
    or "Nothing found that trains your professions.", false, 0, 0
end

function M:Build()
  if self.frame then return self.frame end
  local host = ns.GearShop and ns.GearShop:Build()
  local f = CreateFrame("Frame", "Outrider_TrainShop", host or UIParent)
  f:SetSize(540, 30)
  if host then f:SetPoint("TOPLEFT", host, "TOPLEFT", 184, -140) else f:SetPoint("CENTER") end
  -- the search starts from the menu; this one stays as a fallback without the window
  f.button = UI:Button(f, "Find training materials", 190, function()
    if M.queue and M.manual then M:Next() else M:Start() end
  end)
  f.button:SetPoint("TOPRIGHT", -8, -2)
  if host then f.button:Hide() end
  f.chips = {}
  f:Hide()
  self.frame = f
  return f
end

-- Chips for All and each crafting profession (with its icon), the chosen one lit.
function M:Chips(f)
  local list = { false }
  for _, p in ipairs(self:Professions()) do list[#list + 1] = p end
  local chosen = self:Chosen()
  local x = 0
  for i, p in ipairs(list) do
    local c = f.chips[i]
    if not c then
      c = UI:Chip(f, p or "All", function(btn) M:Choose(btn.prof or nil) end, p and profIcon(p) or "Interface\\Icons\\INV_Misc_Book_09")
      f.chips[i] = c
    end
    c.prof = p or nil
    c.label:SetText(p or "All")
    if c.icon then c.icon:SetTexture(p and profIcon(p) or "Interface\\Icons\\INV_Misc_Book_09") end
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", x, 0)
    x = x + (c:GetWidth() or 60) + 6
    c:SetOn((p or nil) == chosen)
    c:Show()
  end
  for i = #list + 1, #f.chips do f.chips[i]:Hide() end
end

function M:Refresh()
  if not self.open then return end
  local f = self:Build()
  self:Chips(f)
  if self.queue then
    f.button.label:SetText(self.manual and string.format("Search next (%d/%d)", self.pos, #self.queue) or "Searching...")
  else
    f.button.label:SetText(self.prices and "Search again" or "Find training materials")
  end
  local G = ns.GearShop
  if G and G.frame then
    if G.open then G:Refresh() end
  else
    f:Show()
  end
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

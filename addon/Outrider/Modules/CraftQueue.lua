-- Modules/CraftQueue.lua  (P5-03)
-- Hub tab "Crafting": recipes this character knows (Professions), a queue
-- (recipe x count, per character) and a shopping list:
--   need   = sum of reagents over the queue
--   have   = this character's bags + bank (Inventory)
--   alts   = other characters' stock, listed apart (it needs mailing)
--   missing = need - have (what to buy or fetch)
-- Planning only: every craft and every purchase is Gary's click.

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local M = ns:NewModule("CraftQueue", {
  title = "Craft queue and shopping list",
  phase = "P5",
  order = 78,
  defaults = { queue = {} },
})
ns.CraftQueue = M

-- All known recipes: { {key, prof, name, reagents} } sorted by name.
function M:Recipes()
  local out = {}
  for prof, p in pairs(ns.db.char.professions or {}) do
    for id, r in pairs(p.recipes or {}) do
      if r.reagents and next(r.reagents) then
        out[#out + 1] = { key = prof .. ":" .. tostring(id), prof = prof, id = id, name = r.name or tostring(id), reagents = r.reagents }
      end
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

function M:Find(key)
  for _, r in ipairs(self:Recipes()) do if r.key == key then return r end end
end

function M:Add(key, n)
  local q = self:Settings().queue
  q[key] = (q[key] or 0) + (n or 1)
  if q[key] <= 0 then q[key] = nil end
end

function M:Clear() self:Settings().queue = {} end

-- Reagent totals for the whole queue: { [itemID] = count }
function M:Needed()
  local need = {}
  for key, n in pairs(self:Settings().queue) do
    local r = self:Find(key)
    if r then for item, per in pairs(r.reagents) do need[item] = (need[item] or 0) + per * n end end
  end
  return need
end

-- { {itemID, need, have, alts, missing, altsText} } sorted by missing desc
function M:Shopping()
  local inv = ns.db.global.inventory or {}
  local me = inv[ns.db.key] or {}
  local rows = {}
  for item, need in pairs(self:Needed()) do
    local have = ((me.bags or {})[item] or 0) + ((me.bank or {})[item] or 0)
    local alts, parts = 0, {}
    for key, other in pairs(inv) do
      if key ~= ns.db.key then
        local n = ((other.bags or {})[item] or 0) + ((other.bank or {})[item] or 0) + ((other.mail or {})[item] or 0)
        if n > 0 then alts = alts + n parts[#parts + 1] = (key:match("^([^-]+)") or key) .. " " .. n end
      end
    end
    rows[#rows + 1] = { itemID = item, need = need, have = have, alts = alts, missing = math.max(0, need - have),
      altsText = table.concat(parts, ", ") }
  end
  table.sort(rows, function(a, b) if a.missing ~= b.missing then return a.missing > b.missing end return a.itemID < b.itemID end)
  return rows
end

local function itemName(id)
  local info = C.ItemInfo(id)
  return info and info.name or ("item " .. id)
end

function M:ShoppingText()
  local lines = {}
  for _, r in ipairs(self:Shopping()) do
    local price = ns.Prices and select(1, ns.Prices:Get(r.itemID))
    lines[#lines + 1] = string.format("%s: need %d, have %d%s%s%s", itemName(r.itemID), r.need, r.have,
      r.missing > 0 and (", BUY " .. r.missing) or ", ok",
      r.alts > 0 and (" (alts: " .. r.altsText .. ")") or "",
      (r.missing > 0 and price) and (" ~" .. ns.Prices.Money(price * r.missing)) or "")
  end
  return #lines > 0 and table.concat(lines, "\n") or "Queue is empty. Click a recipe on the left to add it."
end

-- P9-01: queued crafts and what is still missing for them
function M:Snapshot()
  local queue = {}
  for key, n in pairs(self:Settings().queue) do
    local r = self:Find(key)
    queue[#queue + 1] = { key = key, name = r and r.name, count = n }
  end
  local missing = {}
  for _, row in ipairs(self:Shopping()) do
    if row.missing > 0 then missing[#missing + 1] = { itemID = row.itemID, missing = row.missing, alts = row.alts } end
  end
  return { queue = queue, missing = missing }
end

function M:Activity()
  local n = 0
  for _, c in pairs(self:Settings().queue) do n = n + c end
  return string.format("%d recipes known, %d crafts queued", #self:Recipes(), n)
end

-- Plain words for a recipe's skill colour (Professions stores the client's 0-3).
M.SKILL = { [0] = { "|cffff8040", "always gives skill" }, [1] = { "|cffffff00", "likely gives skill" },
  [2] = { "|cff40c040", "sometimes gives skill" }, [3] = { "|cff808080", "no skill any more" } }

local function icon(itemID)
  if not itemID then return nil end
  return C.Call("C_Item.GetItemIconByID", itemID) or C.Call("GetItemIcon", itemID)
end

local function rec(r)
  local prof = r and ns.db.char.professions[r.prof]
  return prof and prof.recipes and prof.recipes[r.id] or {}
end

-- The page rebuilt to read at a glance (Gary, 2026-11-20): recipes with their
-- picture and whether they still give skill; your queue; what you need, with
-- pictures, what you have and what to buy.
ns.Hub:AddTab("crafting", "Crafting", function(p)
  p.prof = nil
  local function rowIcon(row)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(24, 24)
    row.icon:SetPoint("LEFT", 4, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
  end
  -- 1. recipes
  p.listHead = UI.Text(p, "large", "goldText")
  p.listHead:SetPoint("TOPLEFT", 2, 0)
  p.listHead:SetText("1. Your recipes")
  p.chips = {}
  p.list = UI:ScrollList(p, {
    rows = 14, rowHeight = 30, build = rowIcon,
    render = function(row, r)
      local rc = rec(r)
      local sk = M.SKILL[tonumber(rc.diff) or -1]
      row.icon:SetTexture(icon(rc.product) or "Interface\\Icons\\INV_Misc_Book_09")
      row.text:SetText(string.format("%s%s|r  |cff8f96a6%s%s|r", sk and sk[1] or "|cffdddddd", r.name, r.prof, sk and (" · " .. sk[2]) or ""))
    end,
    onClick = function(r) M:Add(r.key, C.Call("IsShiftKeyDown") and 5 or 1) p:Refresh() end,
  })
  p.list:SetPoint("TOPLEFT", 0, -56)
  p.list:SetWidth(330)
  p.hint = UI.Text(p, "small", "muted")
  p.hint:SetPoint("TOPLEFT", p.list, "BOTTOMLEFT", 2, -6)
  p.hint:SetWidth(330)
  p.hint:SetJustifyH("LEFT")
  p.hint:SetText("Click a recipe to add one to your queue; Shift-click adds 5. Orange and yellow ones raise your skill best.")
  local function column(title)
    local c = UI:Card(p, true)
    c.head = UI.Text(c, "large", "goldText")
    c.head:SetPoint("TOPLEFT", 14, -12)
    c.head:SetText(title)
    c.note = UI.Text(c, "small", "muted")
    c.note:SetPoint("TOPLEFT", c.head, "BOTTOMLEFT", 0, -4)
    c.note:SetPoint("RIGHT", c, "RIGHT", -14, 0)
    c.note:SetJustifyH("LEFT")
    return c
  end
  -- 2. queue
  p.qcard = column("2. Your queue")
  p.qcard:SetPoint("TOPLEFT", p.list, "TOPRIGHT", 12, 56)
  p.qcard:SetPoint("BOTTOM", p, "BOTTOM", 0, 0)
  p.qlist = UI:ScrollList(p.qcard, {
    rows = 14, rowHeight = 30, build = rowIcon,
    render = function(row, q)
      row.icon:SetTexture(icon(q.product) or "Interface\\Icons\\INV_Misc_Book_09")
      row.text:SetText(string.format("|cfff1d58e%d x|r  %s", q.n, q.name))
    end,
    onClick = function(q) M:Add(q.key, -1) p:Refresh() end,
  })
  p.qlist:SetPoint("TOPLEFT", p.qcard.note, "BOTTOMLEFT", -6, -8)
  p.qlist:SetPoint("RIGHT", p.qcard, "RIGHT", -8, 0)
  p.clear = UI:Button(p.qcard, "Clear queue", 110, function() M:Clear() p:Refresh() end)
  p.clear:SetPoint("BOTTOMLEFT", 14, 12)
  -- 3. what you need
  p.scard = column("3. What you need")
  p.scard:SetPoint("TOPLEFT", p.qcard, "TOPRIGHT", 12, 0)
  p.scard:SetPoint("BOTTOMRIGHT", -4, 0)
  p.slist = UI:ScrollList(p.scard, {
    rows = 13, rowHeight = 30, build = rowIcon,
    render = function(row, r)
      row.icon:SetTexture(icon(r.itemID) or "Interface\\Icons\\INV_Misc_QuestionMark")
      local price = ns.Prices and select(1, ns.Prices:Get(r.itemID))
      local status = r.missing > 0 and string.format("|cffffc84dbuy %d|r%s", r.missing, price and ("  ~" .. ns.Prices.Coins(price * r.missing)) or "")
        or "|cff7fff7fyou have enough|r"
      row.text:SetText(string.format("%s  |cff8f96a6have %d of %d|r   %s%s", itemName(r.itemID), r.have, r.need, status,
        r.alts > 0 and ("  |cff8f96a6(alts: " .. r.altsText .. ")|r") or ""))
    end,
  })
  p.slist:SetPoint("TOPLEFT", p.scard.note, "BOTTOMLEFT", -6, -8)
  p.slist:SetPoint("RIGHT", p.scard, "RIGHT", -8, 0)
  p.total = UI.Text(p.scard, "normal", "text")
  p.total:SetPoint("BOTTOMLEFT", 14, 16)
  p.total:SetPoint("RIGHT", p.scard, "RIGHT", -14, 0)
  p.total:SetJustifyH("LEFT")
  local function sizeCols()
    local w = (p:GetWidth() or 900) - 330 - 12 - 12 - 4
    p.qcard:SetWidth(math.max(200, math.floor(w * 0.38)))
  end
  sizeCols()
  if p.HookScript then p:HookScript("OnSizeChanged", sizeCols) end
  p.side = p.qcard
  -- the old names (other pages and tests)
  p.queue, p.shop = p.qcard.note, p.total

  function p:Refresh()
    -- profession chips
    local profs = {}
    for _, r in ipairs(M:Recipes()) do profs[r.prof] = true end
    local names = { false }
    for name in pairs(profs) do names[#names + 1] = name end
    table.sort(names, function(x, y) if x == false then return y ~= false end if y == false then return false end return x < y end)
    local x = 0
    for i, name in ipairs(names) do
      local c = self.chips[i]
      if not c then
        c = UI:Chip(self, name or "All", function(btn) p.prof = btn.prof p:Refresh() end)
        self.chips[i] = c
      end
      c.prof = name or nil
      c.label:SetText(name or "All")
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", self, "TOPLEFT", x, -26)
      x = x + (c:GetWidth() or 60) + 6
      c:SetOn((name or nil) == self.prof)
      c:Show()
    end
    for i = #names + 1, #self.chips do self.chips[i]:Hide() end
    local recipes = {}
    for _, r in ipairs(M:Recipes()) do if not self.prof or r.prof == self.prof then recipes[#recipes + 1] = r end end
    -- skill-giving first, then by name
    table.sort(recipes, function(a2, b2)
      local da, db = tonumber(rec(a2).diff) or 9, tonumber(rec(b2).diff) or 9
      if da ~= db then return da < db end
      return a2.name < b2.name
    end)
    self.list:SetItems(recipes)
    local queue = {}
    for key, n in pairs(M:Settings().queue) do
      local r = M:Find(key)
      queue[#queue + 1] = { key = key, n = n, name = r and r.name or key, product = rec(r).product }
    end
    table.sort(queue, function(a2, b2) return a2.name < b2.name end)
    self.qlist:SetItems(queue)
    self.qcard.note:SetText(#queue > 0 and "What you plan to make. Click one to take it off."
      or "Empty. Click a recipe on the left to add it.")
    local shop = M:Shopping()
    self.slist:SetItems(shop)
    local cost, buy = 0, 0
    for _, r in ipairs(shop) do
      if r.missing > 0 then
        buy = buy + 1
        local price = ns.Prices and select(1, ns.Prices:Get(r.itemID))
        if price then cost = cost + price * r.missing end
      end
    end
    self.scard.note:SetText(#shop == 0 and "Add recipes to your queue: the materials they need show here."
      or "Everything your queue needs, with what's in your bags and bank.")
    self.total:SetText(#shop == 0 and "" or (buy == 0 and "|cff7fff7fYou have everything: go craft!|r"
      or string.format("%d thing%s to buy, about %s at the auction house (its Shopping list)", buy, buy == 1 and "" or "s", ns.Prices.Coins(cost))))
  end
end, 46)

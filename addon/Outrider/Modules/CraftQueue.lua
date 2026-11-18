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

ns.Hub:AddTab("crafting", "Crafting", function(p)
  p.list = UI:ScrollList(p, {
    rows = 13, rowHeight = 24,
    render = function(row, r) row.text:SetText(r.name .. "  |cff888888" .. r.prof .. "|r") end,
    onClick = function(r) M:Add(r.key, C.Call("IsShiftKeyDown") and 5 or 1) p:Refresh() end,
  })
  -- three columns (premium rebuild 2026-11-18): recipes | queue | shopping
  p.listHead = UI.Text(p, "large", "goldText")
  p.listHead:SetPoint("TOPLEFT", 2, 0)
  p.listHead:SetText("Recipes")
  p.list:SetPoint("TOPLEFT", 0, -22)
  p.list:SetWidth(260)
  local function column(title)
    local c = UI:Card(p, true)
    c.head = UI.Text(c, "large", "goldText")
    c.head:SetPoint("TOPLEFT", 14, -12)
    c.head:SetText(title)
    c.body = UI.Text(c, "normal", "body")
    c.body:SetPoint("TOPLEFT", c.head, "BOTTOMLEFT", 0, -8)
    c.body:SetPoint("RIGHT", c, "RIGHT", -14, 0)
    c.body:SetJustifyH("LEFT")
    if c.body.SetSpacing then c.body:SetSpacing(2) end
    return c
  end
  p.qcard = column("Queue")
  p.qcard:SetPoint("TOPLEFT", p.list, "TOPRIGHT", 12, 22)
  p.qcard:SetPoint("BOTTOM", p, "BOTTOM", 0, 0)
  p.scard = column("Shopping list")
  p.scard:SetPoint("TOPLEFT", p.qcard, "TOPRIGHT", 12, 0)
  p.scard:SetPoint("BOTTOMRIGHT", -4, 0)
  local function sizeCols()
    local w = (p:GetWidth() or 900) - 260 - 12 - 12 - 4
    p.qcard:SetWidth(math.max(180, math.floor(w * 0.42)))
  end
  sizeCols()
  if p.HookScript then p:HookScript("OnSizeChanged", sizeCols) end
  p.side = p.qcard
  p.queue, p.shop = p.qcard.body, p.scard.body
  p.clear = UI:Button(p, "Clear queue", 110, function() M:Clear() p:Refresh() end)
  p.clear:SetPoint("TOPLEFT", p.list, "BOTTOMLEFT", 0, -6)
  function p:Refresh()
    self.list:SetItems(M:Recipes())
    local lines = {}
    for key, n in pairs(M:Settings().queue) do
      local r = M:Find(key)
      lines[#lines + 1] = "|cfff1d58e" .. n .. " x|r  " .. (r and r.name or key)
    end
    self.queue:SetText(#lines > 0 and table.concat(lines, "\n")
      or "|cff8f96a6Empty. Click a recipe on the left to add one (Shift adds 5).|r")
    local text = M:ShoppingText()
    if ns.SkillUp and ns.SkillUp.enabled then
      for prof in pairs(ns.db.char.professions or {}) do
        local l = ns.SkillUp:Lines(prof)
        text = text .. "\n\n" .. table.concat(l, "\n", 1, math.min(#l, 4))
      end
    end
    self.shop:SetText(text)
  end
end, 46)

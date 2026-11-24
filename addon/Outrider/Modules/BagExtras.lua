-- Modules/BagExtras.lua
-- Bag extras (gap analysis 2026-11-17, Bagnon/Baganator/Pawn style) without
-- replacing Blizzard's bags (hook, don't replace):
--   * on Blizzard's own bag slots: item level on gear, a green arrow on gear
--     that's an upgrade for you (GearScore), a coin on grey junk. A small
--     frame of ours on each slot, redrawn when the bags update.
--   * search every character's bags, bank, mail and worn gear by item name
--     (from what Inventory already records), on the My characters page and
--     /ride where <item>.
-- Steps aside when a bag addon owns the bags.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("BagExtras", {
  title = "Bag marks and item search",
  phase = "P5",
  order = 61,
  defaults = { ilvl = true, upgrade = true, junk = true },
  yieldsTo = { "Bagnon", "Baganator", "AdiBags", "ArkInventory", "Combuctor", "BetterBags" },
})
ns.BagExtras = M

local function readable(v) return v ~= nil and C.Readable(v) and v or nil end

-- DEEP-23: personal, per-character gear wish list.
function M:Wishlist()
  local db = ns.db.char
  db.gearWishlist = ns.KeepTable(db.gearWishlist, "BagExtras:db.gearWishlist") or {}
  return db.gearWishlist
end

function M:Wish(id, on)
  id = tonumber(id)
  if not id or id < 1 or id ~= math.floor(id) then return false end
  local wish = self:Wishlist()
  wish[id] = on == false and nil or { t = time(), name = (C.ItemInfo(id) or {}).name }
  return true
end

function M:Wishes()
  local out = {}
  for id, entry in pairs(self:Wishlist()) do
    local count = ns.Inventory and ns.Inventory:Count(id) or 0
    out[#out + 1] = { id = id, name = entry.name or (C.ItemInfo(id) or {}).name or ("item " .. id),
      owned = (tonumber(count) or 0) > 0, count = count }
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

ns.AddCommand("wish", "wish add|remove <itemID> | list", function(arg)
  local action, raw = tostring(arg or ""):match("^(%S+)%s*(.-)%s*$")
  if action == "list" or not action then
    for _, row in ipairs(M:Wishes()) do
      ns.Print("wishlist: %s [%d] %s", row.name, row.id, row.owned and "(owned)" or "(missing)")
    end
    return
  end
  local id = tonumber(raw:match("item:(%d+)") or raw)
  if action == "add" and M:Wish(id, true) then ns.Print("wishlist: added item %d", id)
  elseif action == "remove" and M:Wish(id, false) then ns.Print("wishlist: removed item %d", id)
  else ns.Print("usage: /ride wish add|remove <itemID> | list") end
end)

-- A tagged item tooltip, without altering any tooltip owned by other addons.
ns.TooltipLines:Add("item", "wishlist", M, function(_, data)
  local id = type(data) == "table" and tonumber(C.Readable(data.id))
  if not id or not M:Wishlist()[id] then return {} end
  return { { "Outrider wishlist: " .. ((ns.Inventory and (ns.Inventory:Count(id) or 0) > 0) and "owned" or "wanted"), "goldText" } }
end)

-- ------------------------------------------------------------------ marks
-- what a slot should show: { ilvl = n, upgrade = pct, junk = true }
function M:MarksFor(link, quality)
  local s, out = self:Settings(), {}
  if not link then return out end
  local info = C.ItemInfo(link)
  quality = quality or (info and info.quality)
  if s.junk and quality == 0 then out.junk = true end
  local equip = info and info.equipLoc
  if equip and equip ~= "" and equip ~= "INVTYPE_BAG" and equip ~= "INVTYPE_AMMO" and equip ~= "INVTYPE_QUIVER" then
    if s.ilvl then
      local detailed = C.Resolve("C_Item.GetDetailedItemLevelInfo")
      local lvl = type(detailed) == "function" and select(2, pcall(detailed, link)) or nil
      lvl = tonumber(lvl) or (info and info.ilvl)
      if lvl and lvl > 1 then out.ilvl = lvl end
    end
    if s.upgrade and ns.GearScore and quality ~= 0 then
      local ok, r = pcall(ns.GearScore.Compare, ns.GearScore, link)
      if ok and r and not r.why and r.pct and r.pct > 0.5 then out.upgrade = r.pct end
    end
  end
  return out
end

function M:Overlay(button)
  if button.otrMarks then return button.otrMarks end
  local o = CreateFrame("Frame", nil, button)
  o:SetAllPoints()
  o:SetFrameLevel((button:GetFrameLevel() or 1) + 2)
  o.ilvl = ns.UI.Text(o, "small", "text")
  o.ilvl:SetPoint("BOTTOMLEFT", 2, 2)
  o.arrow = o:CreateTexture(nil, "OVERLAY")
  o.arrow:SetSize(14, 14)
  o.arrow:SetPoint("TOPLEFT", 1, -1)
  o.arrow:SetTexture("Interface\\Buttons\\UI-MicroStream-Green")
  o.coin = o:CreateTexture(nil, "OVERLAY")
  o.coin:SetSize(12, 12)
  o.coin:SetPoint("TOPRIGHT", -1, -1)
  o.coin:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
  button.otrMarks = o
  return o
end

function M:Decorate(button, bag, slot)
  if not (button and bag and slot) then return end
  -- Hook rather than replace secure Blizzard bag click behavior.
  if not button.otrWishHook and button.HookScript then
    button.otrWishHook = true
    button:HookScript("OnClick", function(self)
      if not C.Call("IsAltKeyDown") then return end
      local bagID = self.GetBagID and self:GetBagID() or bag
      local slotID = self.GetID and self:GetID() or slot
      local data = C.Call("C_Container.GetContainerItemInfo", bagID, slotID)
      local id = type(data) == "table" and C.Readable(data.itemID)
      if type(id) == "number" then
        M:Wish(id, true)
        ns.Print("wishlist added: item %d", id)
      end
    end)
  end
  local info = C.Call("C_Container.GetContainerItemInfo", bag, slot)
  local link = type(info) == "table" and (readable(info.hyperlink) or (info.itemID and ("item:" .. info.itemID))) or nil
  local marks = self:MarksFor(link, type(info) == "table" and readable(info.quality) or nil)
  local o = self:Overlay(button)
  o.ilvl:SetText(marks.ilvl and tostring(marks.ilvl) or "")
  o.arrow:SetShown(marks.upgrade ~= nil)
  o.coin:SetShown(marks.junk == true)
  o:Show()
  return marks
end

-- every item button of an open Blizzard bag frame, with its bag and slot
local function eachButton(frame, fn)
  if frame.EnumerateValidItems then
    for _, b in frame:EnumerateValidItems() do
      local bag = b.GetBagID and b:GetBagID() or (b:GetParent() and b:GetParent():GetID())
      fn(b, bag, b:GetID())
    end
    return
  end
  local name = frame.GetName and frame:GetName()
  local bag = frame.GetID and frame:GetID()
  for i = 1, 36 do
    local b = name and rawget(_G, name .. "Item" .. i)
    if not b then break end
    fn(b, bag, b:GetID())
  end
end

function M:UpdateFrame(frame)
  if not (frame and frame.IsShown and frame:IsShown()) then return end
  eachButton(frame, function(b, bag, slot) ns.Safe("bagextras:decorate", M.Decorate, M, b, bag, slot) end)
end

function M:Frames()
  local out = {}
  local combined = rawget(_G, "ContainerFrameCombinedBags")
  if combined then out[#out + 1] = combined end
  for i = 1, 13 do
    local f = rawget(_G, "ContainerFrame" .. i)
    if f then out[#out + 1] = f end
  end
  return out
end

function M:UpdateAll()
  for _, f in ipairs(self:Frames()) do self:UpdateFrame(f) end
end

function M:Hook()
  if self.hooked then return end
  self.hooked = true
  if type(rawget(_G, "ContainerFrame_Update")) == "function" then
    hooksecurefunc("ContainerFrame_Update", function(frame) if M.enabled then M:UpdateFrame(frame) end end)
  end
  for _, f in ipairs(self:Frames()) do
    if f.UpdateItems then hooksecurefunc(f, "UpdateItems", function(frame) if M.enabled then M:UpdateFrame(frame) end end) end
  end
end

-- DEEP-34: an optional categorized inventory browser. It does NOT replace
-- protected Blizzard bag frames or intercept bag clicks; yields to bag addons.
-- For bank/alts, only last observed count snapshots are available.
M.CATEGORIES = { "all", "gear", "consumables", "trade", "quest", "other" }
function M:Category(itemID)
  local info = C.ItemInfo(itemID)
  if not info then return "other" end
  if info.equipLoc and info.equipLoc ~= "" then return "gear" end
  if info.class == 0 then return "consumables" end
  if info.class == 7 then return "trade" end
  if info.class == 12 then return "quest" end
  return "other"
end

function M:BagRows(where, character, query, category)
  local rows = {}
  local term = type(query) == "string" and query:lower() or ""
  category = category or "all"
  character = character or ns.db.key
  local function push(id, count, bag, slot, source)
    local info = C.ItemInfo(id)
    local name = info and info.name or ("Item " .. tostring(id))
    local kind = self:Category(id)
    local match = term == "" or name:lower():find(term, 1, true) ~= nil
    if category == "all" or kind == category then
      rows[#rows + 1] = { id = id, count = count, name = name, bag = bag, slot = slot,
        source = source, category = kind, match = match, boe = info and info.bindType == 2 }
    end
  end
  if character == ns.db.key and where == "bags" then
    for bag = 0, (rawget(_G, "NUM_BAG_SLOTS") or 4) do
      for slot = 1, C.NumSlots(bag) do
        local count, id = C.ItemCountAt(bag, slot)
        if id and count and count > 0 then push(id, count, bag, slot, "live bags") end
      end
    end
  else
    local inv = ns.Inventory and ns.Inventory.db and ns.Inventory.db[character]
    for id, count in pairs(inv and inv[where] or {}) do
      if count > 0 then push(id, count, nil, nil, "last observed") end
    end
  end
  table.sort(rows, function(a,b)
    if a.match ~= b.match then return a.match end
    if a.category ~= b.category then return a.category < b.category end
    return a.name < b.name
  end)
  return rows
end

function M:BuildBagWindow()
  if self.bagWindow then return self.bagWindow end
  local UI = ns.UI
  local f = UI:Window("Outrider_BagBrowser", "Inventory browser", 620, 540, ns.db.char.bagWindow or {})
  self.bagWindow = f
  f.view, f.category, f.char = "bags", "all", ns.db.key
  f.search = UI:SearchBox(f.content, 240, "Highlight item name...")
  f.search:SetPoint("TOPLEFT", 4, -6)
  f.search:SetScript("OnTextChanged", function() M:RefreshBagWindow() end)
  f.viewButton = UI:Button(f.content, "Bags / bank", 110, function()
    f.view = f.view == "bags" and "bank" or "bags"
    M:RefreshBagWindow()
  end)
  f.viewButton:SetPoint("LEFT", f.search, "RIGHT", 6, 0)
  UI.Tip(f.viewButton, "Bags / bank", "Toggle between live bags and last observed bank inventory.")
  f.categoryButton = UI:Button(f.content, "Category: all", 120, function()
    local idx = 1
    for i, v in ipairs(M.CATEGORIES) do if v == f.category then idx = i break end end
    f.category = M.CATEGORIES[idx % #M.CATEGORIES + 1]
    f.categoryButton:SetText("Category: " .. f.category)
    M:RefreshBagWindow()
  end)
  f.categoryButton:SetPoint("LEFT", f.viewButton, "RIGHT", 6, 0)
  UI.Tip(f.categoryButton, "Filter category", "Cycle gear, consumables, trade goods, quest and other.")
  f.character = UI:Button(f.content, "Next character", 120, function()
    local chars = {}
    for key in pairs(ns.Inventory and ns.Inventory.db or {}) do chars[#chars + 1] = key end
    table.sort(chars)
    for i, key in ipairs(chars) do
      if key == f.char then f.char = chars[i % #chars + 1] break end
    end
    M:RefreshBagWindow()
  end)
  f.character:SetPoint("TOPLEFT", 4, -39)
  UI.Tip(f.character, "Next character", "Browse this character's last recorded bags or bank; never reads offline live data.")
  f.count = UI.Text(f.content, "small", "muted")
  f.count:SetPoint("LEFT", f.character, "RIGHT", 8, 0)
  f.list = UI:ScrollList(f.content, {
    rows = 13, rowHeight = 28,
    render = function(row, entry)
      row.text:SetText(string.format("%s%s x%d  |cffaaaaaa[%s]%s %s|r",
        entry.match and "" or "|cff777777", entry.name, entry.count,
        entry.category, entry.boe and " BoE" or "",
        entry.source == "last observed" and "(cached)" or ""))
    end,
  })
  f.list:SetPoint("TOPLEFT", 4, -70)
  f.list:SetPoint("RIGHT", -4, 0)
  f:Hide()
  return f
end
function M:RefreshBagWindow()
  local f = self.bagWindow
  if not f or not f.list then return end
  local rows = self:BagRows(f.view, f.char, f.search:GetText(), f.category)
  f.list:SetItems(rows)
  f.count:SetText(string.format("%s | %s | %d rows; search matches highlighted",
    f.char, f.view, #rows))
end

ns.AddCommand("bags", "bags [open|close]  categorized inventory browser", function(arg)
  if not M.enabled then ns.Print("Outrider's bag browser is disabled (possibly yielding to another bag addon)") return end
  local f = M:BuildBagWindow()
  if arg == "close" then f:Hide() return end
  if arg == "open" then f:Show() else f:SetShown(not f:IsShown()) end
  M:RefreshBagWindow()
end)

-- ------------------------------------------------------------------ search
-- items whose name contains text, with where every character keeps them:
-- { {itemID, name, total, per = { {char, count, where} } } }
function M:Search(text)
  text = tostring(text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  local out = {}
  if text == "" or not ns.Inventory then return out end
  local ids = {}
  for _, inv in pairs(ns.Inventory.db or {}) do
    for _, place in ipairs({ "bags", "bank", "mail", "worn" }) do
      for id in pairs(type(inv) == "table" and inv[place] or {}) do ids[id] = true end
    end
  end
  local missing = 0
  for id in pairs(ids) do
    local info = C.ItemInfo(id)
    if info and info.name then
      if info.name:lower():find(text, 1, true) then
        local total, per = ns.Inventory:Count(id)
        out[#out + 1] = { itemID = id, name = info.name, total = total, per = per }
      end
    else
      missing = missing + 1
      C.Call("C_Item.RequestLoadItemDataByID", id)
    end
  end
  table.sort(out, function(a, b) if a.total ~= b.total then return a.total > b.total end return a.name < b.name end)
  self.unnamed = missing
  return out
end

function M.WhereText(per)
  local parts = {}
  for _, p in ipairs(per) do
    local w = {}
    for _, place in ipairs({ "bags", "bank", "mail", "worn" }) do
      if p.where[place] then w[#w + 1] = place .. " " .. p.where[place] end
    end
    parts[#parts + 1] = (p.char:match("^[^-]+") or p.char) .. ": " .. table.concat(w, ", ")
  end
  return table.concat(parts, "; ")
end

function M:OnEnable()
  self:Hook()
  self:On("BAG_UPDATE_DELAYED", function(mod) mod:UpdateAll() mod:RefreshBagWindow() end)
  self:On("PLAYER_EQUIPMENT_CHANGED", function(mod) mod:UpdateAll() end)
end

function M:OnDisable()
  for _, f in ipairs(self:Frames()) do
    eachButton(f, function(b) if b.otrMarks then b.otrMarks:Hide() end end)
  end
end

function M:Activity() return "item level, upgrade arrows and junk coins on bag slots; item search across characters" end

ns.AddCommand("where", "where your characters keep an item: /ride where <item name>", function(arg)
  local list = M:Search(arg)
  if #list == 0 then
    ns.Print(M.unnamed and M.unnamed > 0 and "nothing found yet (some item names are still loading, try again)" or "nothing found")
    return
  end
  for i, x in ipairs(list) do
    if i > 5 then break end
    ns.Print("%s x%d: %s", x.name, x.total, M.WhereText(x.per))
  end
end)

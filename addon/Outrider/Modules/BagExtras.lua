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
  self:On("BAG_UPDATE_DELAYED", function(mod) mod:UpdateAll() end)
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

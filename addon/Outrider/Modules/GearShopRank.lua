-- Modules/GearShopRank.lua
-- Gear shop ranking: what fits, bag upgrades, results, gain and provider. Split from Modules/GearShop.lua (OI01-10); behaviour unchanged.

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local M = ns.GearShop

local function instant(itemID)
  local get = C.Resolve("C_Item.GetItemInfoInstant") or rawget(_G, "GetItemInfoInstant")
  if type(get) ~= "function" then return nil end
  local ok, _, _, _, equipLoc, _, class, subclass = pcall(get, itemID)
  if ok then return equipLoc, class, subclass end
end

-- Is this item for this character at all (beyond GearScore's own checks)?
function M:Fits(itemID)
  local equipLoc, class, subclass = instant(itemID)
  if class == M.WEAPON and subclass == 20 then return false end -- fishing poles are not weapons
  if class == M.ARMOR and subclass and subclass >= 1 and subclass <= 4 and not M.ANY_MATERIAL[equipLoc or ""] then
    local want = ns.GearScore and ns.GearScore.ArmorType()
    if want and subclass ~= want then return false end
  end
  return true
end

function M.PlayerClass()
  local _, token = C.Call("UnitClass", "player")
  return token
end

-- Slots a bag has, from its tooltip ("16 Slot Bag"); nil until the item is loaded.
-- Kept per item: a bag's size never changes, and reading a tooltip for every
-- bag on every redraw made the Bags view lag (measured 2026-11-22: 2 FPS).
M.slotCache = {}
function M.BagSlotsOf(itemID)
  local c = M.slotCache[itemID]
  if c ~= nil then return c or nil end
  local tip = C.Call("C_TooltipInfo.GetItemByID", itemID)
  for _, line in ipairs(type(tip) == "table" and tip.lines or {}) do
    local t = C.Readable(line.leftText)
    local n = type(t) == "string" and t:match("(%d+) Slot")
    if n then M.slotCache[itemID] = tonumber(n) return tonumber(n) end
  end
  -- loaded and still no slot line: not a bag with slots; don't ask again
  if C.ItemInfo(itemID) and type(tip) == "table" and tip.lines and #tip.lines > 0 then M.slotCache[itemID] = false end
end

-- The bags you carry: smallest general bag (0 for an empty bag slot) and the
-- quiver or pouch, if any. A bag's family comes from GetContainerNumFreeSlots
-- (0 = holds anything; 1 arrows, 2 bullets).
function M:WornBags()
  local general, quiver = {}, nil
  for bag = 1, 4 do
    local slots = C.NumSlots(bag) or 0
    local _, family = C.Call("C_Container.GetContainerNumFreeSlots", bag)
    if family == nil then _, family = C.Call("GetContainerNumFreeSlots", bag) end
    family = tonumber(C.Readable(family)) or 0
    if slots == 0 or family == 0 then general[#general + 1] = slots
    elseif family == 1 or family == 2 then quiver = math.max(quiver or 0, slots) end
  end
  table.sort(general)
  return { smallest = general[1], general = general, quiver = quiver }
end

-- Which ammo the worn ranged weapon shoots: "arrows" (bow, crossbow), "bullets" (gun) or nil.
function M.AmmoKind()
  local link = C.Call("GetInventoryItemLink", "player", 18)
  local id = link and tonumber(tostring(link):match("item:(%d+)"))
  local _, class, sub = instant(id or 0)
  if class ~= M.WEAPON then return nil end
  if sub == 2 or sub == 18 then return "arrows" end
  if sub == 3 then return "bullets" end
end

local function hasProf(name)
  local p = ns.db.char.professions
  return type(p) == "table" and p[name] ~= nil
end

-- Bags worth buying: { kind, name, slots, gain, replaces, price, perSlot }.
-- General bags first (most slots gained, then cheapest), then quivers, then
-- profession bags. Returns list, skippedForGold.
function M:BagResults()
  local money = ns.AHBuy and ns.AHBuy.Money() or 0
  local level = C.Call("UnitLevel", "player") or 1
  local cls, ammo, worn = M.PlayerClass(), M.AmmoKind(), self:WornBags()
  local all, skipped = {}, 0
  for itemID, f in pairs(self.found or {}) do
    local _, class, sub = instant(itemID)
    local kind = M.BAG_KINDS[class or -1] and M.BAG_KINDS[class][sub or -1]
    local slots = kind and M.BagSlotsOf(itemID)
    local info = C.ItemInfo("item:" .. itemID)
    local ok = kind and slots and (not kind.class or kind.class == cls) and (not kind.prof or hasProf(kind.prof))
      and (not kind.ammo or not ammo or kind.ammo == ammo)
      and not (info and type(info.reqLevel) == "number" and info.reqLevel > level)
    if ok then
      local replaces, order
      if class == M.QUIVER then replaces, order = worn.quiver or 0, 2
      elseif sub == 0 then replaces, order = worn.smallest or (#worn.general < 4 and 0) or slots, 1
      else replaces, order = 0, 3 end
      local gain = slots - replaces
      if gain > 0 then
        if f.price > money then skipped = skipped + 1
        else
          all[#all + 1] = { mode = "bags", kind = kind.name, order = order, itemID = itemID, itemKey = f.itemKey,
            price = f.price, slots = slots, gain = gain, replaces = replaces,
            name = info and info.name or ("item " .. itemID), perSlot = math.floor(f.price / gain) }
        end
      end
    end
  end
  table.sort(all, function(a, b)
    if a.order ~= b.order then return a.order < b.order end
    if a.gain ~= b.gain then return a.gain > b.gain end
    return a.price < b.price
  end)
  local out = {}
  for i = 1, math.min(M.TOP, #all) do out[i] = all[i] end
  return out, skipped
end

-- Second line for a bag: what it replaces and the price per new slot.
function M.BagLine(b)
  local what
  if b.order == 3 then what = string.format("%d slots (%s only)", b.slots, b.kind:gsub(" bag$", ""):lower())
  elseif b.replaces == 0 then what = string.format("%d slots in an empty %s slot", b.slots, b.order == 2 and "quiver" or "bag")
  else what = string.format("%d slots, replaces your %d-slot %s", b.slots, b.replaces, b.order == 2 and "quiver" or "bag") end
  return string.format("%s   |cffcccccc%s per new slot|r", what, ns.Prices.Money(b.perSlot))
end

-- Upgrades you can afford: weapons the top 10 by gain; armor the best per slot.
-- Returns list, skippedForGold.
function M:Results()
  if self.mode == "bags" then return self:BagResults() end
  local G = ns.GearScore
  if not G or not self.found then return {}, 0 end
  local money = ns.AHBuy and ns.AHBuy.Money() or 0
  local all, skipped = {}, 0
  for itemID, f in pairs(self.found) do
    local link = "item:" .. itemID
    local r = self:Fits(itemID) and G:Compare(link)
    local learn = r and type(r.why) == "string" and r.why:find("^learn ") and r.why or nil
    if r and (not r.why or learn) and (r.pct >= 1 or (r.empty and r.new > 0)) then
      if f.price > money then skipped = skipped + 1
      else
        local info = C.ItemInfo(link)
        all[#all + 1] = { slot = r.slot, slotName = G.SLOT_NAMES[r.slot] or tostring(r.slot), itemID = itemID,
          itemKey = f.itemKey, price = f.price, pct = r.empty and 999 or r.pct, empty = r.empty, capped = r.capped,
          name = info and info.name or ("item " .. itemID), learn = learn, against = r.against, new = r.new, old = r.old }
      end
    end
  end
  -- weapons you can use now first, then ones needing a weapon skill you haven't learned
  table.sort(all, function(a, b)
    if (a.learn == nil) ~= (b.learn == nil) then return a.learn == nil end
    if a.pct ~= b.pct then return a.pct > b.pct end
    return a.price < b.price
  end)
  if self.mode == "weapons" then
    local out = {}
    for i = 1, math.min(M.TOP, #all) do out[i] = all[i] end
    return out, skipped
  end
  local per, out = {}, {}
  for _, b in ipairs(all) do if not per[b.slot] then per[b.slot] = b out[#out + 1] = b end end
  table.sort(out, function(a, b) return a.slot < b.slot end)
  return out, skipped
end

-- The net of every gain and loss, each stat weighed by what this class needs
-- (GearScore's score): "= overall +12% (score 24.0 -> 27.0)" (requirement 2026-11-14:
-- the overall result when, say, a little spirit is traded for agility).
function M.Overall(b)
  if b.empty then return "|cff7fff7f= fills an empty slot|r" end
  local pct = math.floor(b.pct + 0.5)
  local color = pct > 0 and "|cff7fff7f" or (pct < 0 and "|cffff6060" or "|cffcccccc")
  local score = (b.new and b.old) and string.format(" (score %.1f -> %.1f)", b.old, b.new) or ""
  return string.format("%s= overall %s%d%%%s|r", color, pct > 0 and "+" or "", pct, score)
end

function M.Gain(b)
  if b.mode == "bags" then return string.format("+%d slots", b.gain) end
  if b.learn then return string.format("|cffffc84d%s first|r", b.learn) end
  if b.empty then return "empty slot" end
  if b.capped then return "big upgrade" end
  return string.format("+%d%%", math.floor(b.pct + 0.5))
end

-- ------------------------------------------------------------ panel
-- The shopping window beside the auction house (requirement 2026-11-20: a
-- showpiece auction UI, good enough for a hero image). A painted header
-- with your gold, a side menu (Training: Skill-ups, Recipes, Shopping list;
-- Gear: Weapons, Armor, Bags) and item cards: icon in its quality colour,
-- name, what it does for you, the price in coins and a Buy button. Every Buy
-- goes through the confirm bar (AHBuy): one click from Gary per purchase.
M.W, M.NAV, M.HEAD = 740, 168, 96
M.CARD_H, M.PAGE = 50, 8
M.ROWS = M.PAGE

M.NAV_ITEMS = {
  { head = "Training" },
  { id = "training", label = "Skill-ups", icon = "Trade_BlackSmithing", tip = "The cheapest way to your next skill points: what each recipe needs and what that costs per point." },
  { id = "recipes", label = "Recipes", icon = "INV_Scroll_03", tip = "Recipes for sale that you don't know yet, usable now or within 25 points." },
  { id = "list", label = "Shopping list", icon = "INV_Misc_Bag_10", tip = "Every ingredient the skill-ups need, added up, with one Buy all." },
  { head = "Gear" },
  { id = "weapons", label = "Weapons", icon = "INV_Sword_04", tip = "Weapons your class can use, in your level range, that your gold covers: the top upgrades." },
  { id = "armor", label = "Armor", icon = "INV_Chest_Chain_05", tip = "The best upgrade per slot in your armor type that your gold covers." },
  { id = "bags", label = "Bags", icon = "INV_Misc_Bag_08", tip = "Bags bigger than your smallest one; hunters also get a quiver or ammo pouch." },
  { head = "Profit" },
  { id = "flips", label = "Vendor flips", icon = "INV_Misc_Coin_01", tip = "Listings under what a vendor pays: buy them, sell them at any vendor. From Scan all prices." },
  { id = "resale", label = "Resale", icon = "INV_Misc_Coin_17", tip = "Listings well under their usual auction price, after the 5% cut and deposit. Not sure: it has to sell again." },
  { head = "Sell" },
  { id = "sell", label = "Sell bags", icon = "INV_Misc_Bag_07", tip = "What in your bags can go on the auction house, priced just under the lowest now. One click on Post puts it up." },
  { id = "auctions", label = "My auctions", icon = "INV_Misc_Note_01", tip = "Your auctions and whether someone undercut them. One click on Cancel takes one down." },
  { head = "Search" },
  { id = "search", label = "Search", icon = "INV_Misc_Spyglass_02", tip = "Search for anything, with extras like lvl 10-20, under 5g or green+. Your recent searches are kept." },
  { id = "lists", label = "Shopping lists", icon = "INV_Scroll_05", tip = "Your saved searches in named lists: search a whole list at once, import and export (Auctionator and TSM lists too)." },
}
-- views another module fills: cards, status, searching, pos, total from
-- module:View(id); a toolbar row from module:Toolbar(frame, id)
M.PROVIDERS = { sell = "AuctionSell", auctions = "AuctionSell", search = "AuctionSearch", lists = "AuctionSearch" }
function M.Provider(id)
  local name = M.PROVIDERS[id]
  local mod = name and ns[name]
  if mod and mod.enabled ~= false then return mod end
end
M.PROFIT_VIEWS = { flips = true, resale = true }
M.TRAINING_VIEWS = { training = true, recipes = true, list = true }

M.QUALITY = { [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 },
  [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 } }

function M.Icon(itemID)
  local tex = C.Call("C_Item.GetItemIconByID", itemID) or C.Call("GetItemIcon", itemID)
  if not tex then local info = C.ItemInfo(itemID) tex = info and info.icon end
  return tex or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function M.Quality(itemID)
  local info = C.ItemInfo(itemID)
  return M.QUALITY[info and info.quality or 1] or M.QUALITY[1]
end

-- One item card: icon with a quality border, a title, a line under it, small
-- reagent icons, the price and a Buy button. Shared with TrainShop.

-- Modules/KitShare.lua
-- Gear for the people who need it (requirement 2026-11-14: know what other
-- Outrider users need and suggest sending an item you have or just found;
-- check alts first, then family and friends, then the
-- wider Outrider community (all Outrider users)).
-- A kit card says what a character can use and how good its gear is now:
--   { name, class, level, faction, armor, weapons = {subclass=true}, slots = {[slotID]=score}, t }
-- Scores use that character's class weights (GearScore:Score with its class).
-- Cards come from:
--   * alts: this account's own characters, saved at each login (no messages);
--   * family / friends: names Gary adds on the Sharing page;
--   * the wider Outrider family: any Outrider user whose card arrives over
--     GUILD or PARTY (addon messages, hard rule 10).
-- Sending and receiving cards happens only while sharing is on (setting
-- `share`, off by default). Cards are kept account-wide in ns.db.global.kits.
-- For an item in the bags that can still be mailed (not soulbound) Outrider
-- checks alts first, then family and friends, then everyone else, and offers
-- the biggest upgrade in the first group that has one, once per item and
-- person: "Agile Boots: +22% feet for Lily (family). Mail it?" At a mailbox it
-- fills in the name; attaching the item and Send stay Gary's clicks.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("KitShare", {
  title = "Gear for alts, family and other Outrider users",
  phase = "P8",
  order = 91,
  defaults = { share = false, family = {}, minPct = 5 },
})
ns.KitShare = M

M.TIERS = { "alt", "family", "outrider" }
M.TIER_LABEL = { alt = "your alt", family = "family", outrider = "Outrider user" }
M.MAX_AGE = 30 * 86400
local BOP = 1

local function short(key) return tostring(key):match("^([^-]+)") or tostring(key) end

function M:OnInitialize()
  local g = ns.db.global
  g.kits = ns.KeepTable(g.kits, "KitShare:g.kits") or {}
  g.kitOffers = ns.KeepTable(g.kitOffers, "KitShare:g.kitOffers") or {}
end

-- ------------------------------------------------------------ cards
function M:Card()
  local G = ns.GearScore
  if not G then return nil end
  local cls = ns.PlayerClass()
  local level = C.Call("UnitLevel", "player") or 1
  local slots = {}
  for slot = 1, 18 do
    local link = C.Call("GetInventoryItemLink", "player", slot)
    if link then
      local info = C.ItemInfo(link)
      slots[slot] = G:Score(link, info and info.equipLoc, cls)
    else
      slots[slot] = 0
    end
  end
  local weapons = {}
  for sub in pairs(G.WEAPON_SKILL or {}) do
    local known = G.KnowsWeapon(sub)
    if known == nil then known = G.WEAPON_TYPES[cls] and G.WEAPON_TYPES[cls][sub] or false end
    if known then weapons[sub] = true end
  end
  return { name = ns.db.key, class = cls, level = level, faction = C.Readable(C.Call("UnitFactionGroup", "player")),
    armor = G.ArmorType(cls, level), weapons = weapons, slots = slots, t = time(), build = ns.build }
end

function M:SaveOwn()
  local card = self:Card()
  if not card then return end
  card.tier = "alt"
  ns.db.global.kits[ns.db.key] = card
  return card
end

-- Which group a card belongs to, from where this character stands.
function M:Tier(card)
  if card.tier == "alt" then return "alt" end
  for _, n in ipairs(self:Settings().family or {}) do
    if short(card.name):lower() == tostring(n):lower() then return "family" end
  end
  return "outrider"
end

function M:Broadcast()
  if not (self:Settings().share and ns.Comm) then return end
  local card = self:Card()
  if not card then return end
  if C.Call("IsInGuild") then ns.Comm:Send("KIT", card, "GUILD") end
  if C.Call("IsInGroup") then ns.Comm:Send("KIT", card, "PARTY") end
end

function M:OnComm(_, kind, data, sender)
  if kind ~= "KIT" or not self:Settings().share or type(data) ~= "table" then return end
  if type(data.slots) ~= "table" or type(data.class) ~= "string" then return end
  data.name = sender or data.name
  data.tier = nil
  local isNew = not ns.db.global.kits[data.name]
  ns.db.global.kits[data.name] = data
  self:Debug("kit card from %s (%s %s)", tostring(sender), tostring(data.class), tostring(data.level))
  -- someone new: answer with our card so both sides know each other
  if isNew and ns.Comm and sender then
    local mine = self:Card()
    if mine then ns.Comm:Send("KIT", mine, "WHISPER", sender) end
  end
  ns.Throttle("kitshare:scan", 3, function() M:ScanBags() end)
end

-- ------------------------------------------------------------ matching
local function instant(itemID)
  local get = C.Resolve("C_Item.GetItemInfoInstant") or rawget(_G, "GetItemInfoInstant")
  if type(get) ~= "function" then return nil end
  local ok, _, _, _, equipLoc, _, class, subclass = pcall(get, itemID)
  if ok then return equipLoc, class, subclass end
end

-- How much better this item is for the card's character (percent), or nil.
function M:GainFor(card, itemID)
  local G = ns.GearScore
  local link = "item:" .. itemID
  local info = C.ItemInfo(link)
  local equipLoc, class, subclass = instant(itemID)
  equipLoc = (info and info.equipLoc) or equipLoc
  local slots = equipLoc and G.SLOTS[equipLoc]
  if not slots then return nil end
  if info and info.reqLevel and info.reqLevel > (card.level or 1) then return nil end
  if class == 4 and subclass and subclass >= 1 and subclass <= 4 and not (ns.GearShop and ns.GearShop.ANY_MATERIAL[equipLoc]) then
    if card.armor and subclass ~= card.armor then return nil end
  end
  if class == 4 and subclass == 6 and not (card.class == "WARRIOR" or card.class == "PALADIN" or card.class == "SHAMAN") then return nil end
  if class == 2 and subclass and not (card.weapons or {})[subclass] then return nil end
  local new = G:Score(link, equipLoc, card.class)
  local old
  if equipLoc == "INVTYPE_2HWEAPON" then
    old = (card.slots[16] or 0) + (card.slots[17] or 0)
  else
    for _, s in ipairs(slots) do
      local v = card.slots[s] or 0
      if not old or v < old then old = v end
    end
  end
  old = old or 0
  if new <= old then return nil end
  local pct = (new - old) / math.max(old, G.MIN_BASE) * 100
  return math.min(pct, G.MAX_PCT), slots[1]
end

-- The best person for an item: alts first, then family, then other Outrider users.
function M:BestFor(itemID)
  local now, me, minPct = time(), ns.db.key, self:Settings().minPct or 5
  local myFaction = C.Readable(C.Call("UnitFactionGroup", "player"))
  local byTier = {}
  for name, card in pairs(ns.db.global.kits) do
    if name ~= me and type(card) == "table" and (now - (card.t or 0)) < M.MAX_AGE
      and (not card.faction or not myFaction or card.faction == myFaction) then
      local tier = self:Tier(card)
      local ok = tier == "alt" or self:Settings().share
      local pct, slot = ok and self:GainFor(card, itemID)
      if pct and pct >= minPct then
        local cur = byTier[tier]
        if not cur or pct > cur.pct then byTier[tier] = { name = name, pct = pct, slot = slot, tier = tier } end
      end
    end
  end
  for _, tier in ipairs(M.TIERS) do if byTier[tier] then return byTier[tier] end end
  return nil
end

-- Items in the bags that can still be mailed: { {itemID, name} }
function M:Mailable()
  local out = {}
  for bag = 0, 4 do
    for slot = 1, (C.Call("C_Container.GetContainerNumSlots", bag) or 0) do
      local info = C.Call("C_Container.GetContainerItemInfo", bag, slot)
      if type(info) == "table" and info.itemID and not C.Readable(info.isBound) then
        local it = C.ItemInfo(info.itemID)
        if it and it.equipLoc and it.equipLoc ~= "" and it.bindType ~= BOP then
          out[#out + 1] = { itemID = info.itemID, name = it.name }
        end
      end
    end
  end
  return out
end

function M:ScanBags()
  local offers = ns.db.global.kitOffers
  local made = 0
  for _, it in ipairs(self:Mailable()) do
    local best = self:BestFor(it.itemID)
    if best then
      local key = it.itemID .. ":" .. best.name
      if not offers[key] then
        offers[key] = { itemID = it.itemID, name = it.name, to = best.name, pct = best.pct, tier = best.tier, t = time() }
        made = made + 1
        local slotName = ns.GearScore.SLOT_NAMES[best.slot] or "gear"
        ns.Toast:Show({ title = string.format("%s for %s?", tostring(it.name), short(best.name)),
          text = string.format("+%d%% %s for %s (%s). Mail it at a mailbox.", math.floor(best.pct + 0.5), slotName,
            short(best.name), M.TIER_LABEL[best.tier] or best.tier),
          color = "good", duration = 15 })
        self:Info("suggest %s to %s (%s) +%d%%", tostring(it.name), tostring(best.name), best.tier, math.floor(best.pct + 0.5))
      end
    end
  end
  return made
end

-- At a mailbox: offers for items still in the bags, best group first.
function M:Pending()
  local have = {}
  for _, it in ipairs(self:Mailable()) do have[it.itemID] = true end
  local out = {}
  for key, o in pairs(ns.db.global.kitOffers) do
    if have[o.itemID] and o.to ~= ns.db.key then out[#out + 1] = o else
      if not have[o.itemID] then ns.db.global.kitOffers[key] = nil end
    end
  end
  local rank = { alt = 1, family = 2, outrider = 3 }
  table.sort(out, function(a, b)
    if (rank[a.tier] or 9) ~= (rank[b.tier] or 9) then return (rank[a.tier] or 9) < (rank[b.tier] or 9) end
    return a.pct > b.pct
  end)
  return out
end

function M:OnMail()
  local list = self:Pending()
  -- alts' BoE upgrades already get the Handoffs mailbox note: don't say it twice
  if ns.Handoffs and ns.Handoffs.enabled then
    for i = #list, 1, -1 do if list[i].tier == "alt" then table.remove(list, i) end end
  end
  local o = list[1]
  if not o then return end
  local more = #list > 1 and string.format(" (+%d more)", #list - 1) or ""
  ns.Toast:Show({ title = string.format("Mail %s to %s%s", tostring(o.name), short(o.to), more),
    text = string.format("+%d%% for %s (%s). Address fills in the name; you attach the item and click Send.",
      math.floor(o.pct + 0.5), short(o.to), M.TIER_LABEL[o.tier] or o.tier),
    color = "accent", duration = 20,
    action = { label = "Address", fn = function() if ns.Handoffs then ns.Handoffs:Address(o.to) end end } })
end

-- Family and friends (names, without realm).
function M:SetFamily(name, on)
  local list = self:Settings().family
  name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then return end
  for i = #list, 1, -1 do if list[i]:lower() == name:lower() then table.remove(list, i) end end
  if on then list[#list + 1] = ns.TitleCase(name:lower()) end
  table.sort(list)
end

function M:OnEnable()
  if ns.Comm then ns.Comm.KNOWN_TYPES.KIT = true end
  self:On("PLAYER_ENTERING_WORLD", function(mod)
    mod:SaveOwn()
    mod:Broadcast()
    mod:ScanBags()
  end)
  self:On("PLAYER_EQUIPMENT_CHANGED", function(mod)
    ns.Throttle("kitshare:own", 5, function() M:SaveOwn() end)
  end)
  self:On("PLAYER_LEVEL_UP", function(mod) mod:SaveOwn() mod:Broadcast() end)
  self:On("GROUP_ROSTER_UPDATE", function(mod) ns.Throttle("kitshare:party", 10, function() M:Broadcast() end) end)
  self:On("OTR_LOOT", function(mod) ns.Throttle("kitshare:scan", 2, function() M:ScanBags() end) end)
  self:On("OTR_COMM", self.OnComm)
  self:On("MAIL_SHOW", self.OnMail)
end

function M:Activity()
  local n = { alt = 0, family = 0, outrider = 0 }
  for name, card in pairs(ns.db.global.kits) do
    if name ~= ns.db.key and type(card) == "table" then local t = self:Tier(card) n[t] = (n[t] or 0) + 1 end
  end
  return string.format("knows %d alts, %d family, %d other Outrider users%s", n.alt, n.family, n.outrider,
    self:Settings().share and "" or " (sharing off: alts only)")
end

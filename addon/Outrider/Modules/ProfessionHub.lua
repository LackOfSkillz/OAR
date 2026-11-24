-- Modules/ProfessionHub.lua  (Professions, "Your professions": the first tab)
-- Requirement 2026-11-21: one place for all professions; craft from what is in
-- the bags, or point to the auction house or the closest places on the
-- map in the character's level range to get the ingredients; showpiece
-- UI/UX, easy at an 8th-grade level.
-- One page, three steps:
--   1 pick a profession on the left (skill bar, how many you can make now)
--   2 Make now: what your bags can make, best for skill first; a click makes it
--   3 Next for your skill: the best recipes you're short of, each missing
--     ingredient with its best source: a vendor, a creature around your level
--     that drops it, herb or ore nodes you can gather, or the auction house
--     with its price. A click sends the gold arrow (or the whole trip).
-- Gathering professions show where to gather for your skill instead.
-- Ingredient sources: Outrider_Data_Reagents (QuestieDB, tools/import_reagents.py;
-- community data, unchecked). Recipes, colours and reagents: what Outrider saw
-- the last time each profession window was open (Professions module).
-- Every craft is Gary's click (hard rule 1): the button makes one batch.

local _, ns = ...
local C = ns.Compat
local UI, Theme = ns.UI, ns.Theme
local M = ns:NewModule("ProfessionHub", {
  title = "Your professions",
  phase = "P5",
  order = 52,
  defaults = {},
})
ns.ProfessionHub = M

M.ADDON = "Outrider_Data_Reagents"
M.GATHER = { Herbalism = "herb", Mining = "ore", Skinning = "skin", Fishing = "fish" }
M.ICON = {
  Cooking = "INV_Misc_Food_15", ["First Aid"] = "Spell_Holy_SealOfSacrifice", Fishing = "Trade_Fishing",
  Alchemy = "Trade_Alchemy", Blacksmithing = "Trade_BlackSmithing", Enchanting = "Trade_Engraving",
  Engineering = "Trade_Engineering", Leatherworking = "INV_Misc_ArmorKit_17", Tailoring = "Trade_Tailoring",
  Herbalism = "Trade_Herbalism", Mining = "Trade_Mining", Skinning = "INV_Misc_Pelt_Wolf_01",
}
M.COLOR = { [0] = { "orange", "best for skill", "|cffff8040" }, [1] = { "yellow", "good for skill", "|cffffd100" },
  [2] = { "green", "a little skill", "|cff40c040" }, [3] = { "grey", "no skill", "|cff9d9d9d" } }
M.LEVEL_BELOW, M.LEVEL_ABOVE = 6, 3   -- creatures that drop an ingredient: this far below / above you
M.FAR = 600                            -- seconds: further than this, the auction house wins when it has a price

-- ---------------------------------------------------------------- data
function M:Pack()
  if self.pack ~= nil then return self.pack end
  if not rawget(_G, "Outrider_DataReagents") then C.LoadAddOn(self.ADDON) end
  local d = rawget(_G, "Outrider_DataReagents")
  self.pack = type(d) == "table" and type(d.items) == "table" and d or false
  self:Info(self.pack and "ingredient pack loaded from %s" or "no ingredient pack (%s): sources show as the auction house only",
    self.pack and tostring(d.source) or self.ADDON)
  return self.pack
end

-- The crafting pack (Outrider_Data_Crafting, tools/import_crafting.py: WoW
-- Forever's client tables, AllTheThings, ForeverDB): what every recipe makes,
-- its skill colours, and where you learn it.
M.CRAFT_ADDON = "Outrider_Data_Crafting"
function M:Crafting()
  if self.crafting ~= nil then return self.crafting end
  if not rawget(_G, "Outrider_DataCrafting") then C.LoadAddOn(self.CRAFT_ADDON) end
  local d = rawget(_G, "Outrider_DataCrafting")
  self.crafting = type(d) == "table" and type(d.recipes) == "table" and d or false
  return self.crafting
end

-- Recipes to learn next for a profession at a skill (requirement 2026-11-23):
-- not known yet, learnable now or within LEARN_AHEAD points, still giving
-- skill (below grey); learnable now first, then the ones that give the most
-- (orange before yellow), then by skill. Each with how to learn it:
-- { name, itemID, at, color, how, text, source = {kind, target, text} }
M.LEARN_AHEAD, M.LEARN_SHOWN = 25, 5
function M:ToLearn(prof, skill, known)
  local pack = self:Crafting()
  if not (pack and prof and skill) then return {} end
  known = known or {}
  local knownNames = {}
  for _, r in pairs(known) do if type(r) == "table" and r.name then knownNames[r.name] = true end end
  local out = {}
  for spell, r in pairs(pack.recipes) do
    local name = r[10] or ("item " .. tostring(r[5]))
    if r[1] == prof and not known[spell] and not knownNames[name] and r[2] <= skill + M.LEARN_AHEAD and (r[4] == 0 or skill < r[4]) then
      local color = skill < r[2] and 0 or (r[3] > 0 and skill < r[3]) and 0 or (skill < (r[3] + r[4]) / 2) and 1 or 2
      out[#out + 1] = { spell = spell, name = name, itemID = r[5], at = r[2], color = color, how = r[8], recipeItem = r[9], now = r[2] <= skill }
    end
  end
  table.sort(out, function(a, b)
    if a.now ~= b.now then return a.now end
    if a.color ~= b.color then return a.color < b.color end
    if a.at ~= b.at then return a.at < b.at end
    return a.spell < b.spell
  end)
  local keep = {}
  for i = 1, math.min(#out, M.LEARN_SHOWN) do keep[i] = out[i] self:LearnSource(keep[i]) end
  return keep
end

-- Where to learn one recipe: the trainer, or the recipe item's nearest source.
function M:LearnSource(e)
  local pack = self:Crafting()
  local prep = ns.Travel and ns.Travel:Prepare()
  local faction = C.Call("UnitFactionGroup", "player")
  if e.how == "trainer" then
    e.source = { kind = "trainer", text = "your " .. "trainer teaches it" }
    return
  end
  local ri = e.recipeItem and pack and pack.recipeItems and pack.recipeItems[e.recipeItem]
  if not ri then
    e.source = { kind = "hint", text = e.how == "quest" and "from a quest" or "where to learn it isn't known yet" }
    return
  end
  local best
  for _, s in ipairs(ri[2] or {}) do
    if s[2] and s[2] ~= 0 and (not s[6] or s[6] == faction) then
      local p = ns.Travel and ns.Travel.Point(s[2], s[3], s[4], s[5])
      local t = p and prep and ns.Travel:TimeTo(prep, p)
      local text = (s[1] == "vendor" and ("buy " .. ri[1] .. " from " .. s[5]))
        or ("pattern drops from " .. s[5] .. ((s[7] or 0) > 0 and string.format(" (%.1f%%)", s[7] / 100) or ""))
      if p and (not best or (t or 1e9) < (best.seconds or 1e9) or (s[1] == "vendor" and best.kind ~= "vendor" and (t or 1e9) < (best.seconds or 1e9) * 2)) then
        best = { kind = s[1], text = text, target = p, seconds = t, who = s[5] }
      end
    end
  end
  e.source = best or { kind = "ah", text = ri[1] .. ": the auction house" }
end

-- Your professions: { {name, skill, max, gather = kind or nil, recipes} } crafting first, by name.
function M:Profs()
  local store = ns.db.char.professions or {}
  local owned = ns.Crafter and ns.Crafter:Owned() or {}
  local out, seen = {}, {}
  local function add(name)
    if seen[name] or name == "" then return end
    seen[name] = true
    local p = store[name] or {}
    out[#out + 1] = { name = name, skill = tonumber(p.skill), max = tonumber(p.max), gather = M.GATHER[name], recipes = p.recipes or {} }
  end
  for name in pairs(owned) do add(name) end
  for name, p in pairs(store) do if type(p) == "table" and (p.skill or next(p.recipes or {})) then add(name) end end
  table.sort(out, function(a, b)
    if (a.gather ~= nil) ~= (b.gather ~= nil) then return a.gather == nil end
    return a.name < b.name
  end)
  return out
end

local function have(itemID)
  local n = ns.Crafter and ns.Crafter.Have(itemID) or 0
  if n == 0 and ns.Inventory then
    local inv = ns.Inventory.db and ns.Inventory.db[ns.db.key]
    for _, place in ipairs({ "bags", "bank" }) do n = n + ((inv and inv[place] and inv[place][itemID]) or 0) end
  end
  return n
end
M.Have = have

function M.ItemName(itemID)
  local info = C.ItemInfo(itemID)
  local pack = M:Pack()
  local e = pack and pack.items[itemID]
  return (info and info.name) or (e and e[1]) or ("item " .. tostring(itemID))
end

local function makeable(r)
  if not (r.reagents and next(r.reagents)) then return 0 end
  local fit
  for id, need in pairs(r.reagents) do
    local k = math.floor(have(id) / math.max(need, 1))
    fit = fit and math.min(fit, k) or k
  end
  return fit or 0
end

-- { now = { {id, name, diff, n, recipe} }, next = { {id, name, diff, missing = { {itemID, name, need, have} }} } }
function M:Recipes(prof)
  local p = (ns.db.char.professions or {})[prof]
  local now, nxt = {}, {}
  for id, r in pairs(p and p.recipes or {}) do
    local diff = tonumber(r.diff) or 2
    local n = makeable(r)
    local e = { id = id, name = r.name or tostring(id), diff = diff, n = n, recipe = r }
    if n > 0 and r.name ~= "Basic Campfire" then
      now[#now + 1] = e
    elseif diff <= 2 and r.reagents and next(r.reagents) then
      e.missing = {}
      for itemID, need in pairs(r.reagents) do
        local got = have(itemID)
        if got < need then e.missing[#e.missing + 1] = { itemID = itemID, name = M.ItemName(itemID), need = need - got, have = got } end
      end
      table.sort(e.missing, function(a, b) return a.name < b.name end)
      nxt[#nxt + 1] = e
    end
  end
  local function byDiff(a, b)
    if a.diff ~= b.diff then return a.diff < b.diff end
    if (a.missing and #a.missing or 0) ~= (b.missing and #b.missing or 0) then return #(a.missing or {}) < #(b.missing or {}) end
    return a.name < b.name
  end
  table.sort(now, byDiff)
  table.sort(nxt, byDiff)
  return { now = now, next = nxt }
end

-- ---------------------------------------------------------------- where to get it
-- The nearest spawn point of a source: point (Travel.Point) and seconds, or nil.
local function nearestPoint(spawns, label, prep)
  local best, bestT
  for mapID, pts in pairs(spawns or {}) do
    for i = 1, #pts - 1, 2 do
      local p = ns.Travel.Point(mapID, pts[i], pts[i + 1], label)
      local t = p and prep and ns.Travel:TimeTo(prep, p)
      if t and (not bestT or t < bestT) then best, bestT = p, t end
    end
  end
  return best, bestT
end

-- The ways to get an ingredient, best first:
-- { kind = "vendor"|"drop"|"node"|"ah"|"alts", text, target?, seconds?, price? }
function M:Sources(itemID, need)
  local out = {}
  local pack = self:Pack()
  local e = pack and pack.items[itemID]
  local level = C.Call("UnitLevel", "player") or 1
  local faction = (C.Call("UnitFactionGroup", "player") or ""):sub(1, 1)
  local prep = ns.Travel and ns.Travel:Prepare()
  local owned = ns.Crafter and ns.Crafter:Owned() or {}
  local price = ns.Prices and ns.Prices.Get and ns.Prices:Get(itemID)
  if e then
    for _, nid in ipairs(e[6] or {}) do
      local n = pack.npcs[nid]
      if n and (n[4] == nil or n[4] == faction) then
        local p, t = nearestPoint(n[5], n[1], prep)
        if p then out[#out + 1] = { kind = "vendor", text = "Buy from " .. n[1] .. " (vendor)", target = p, seconds = t, who = n[1] } end
      end
    end
    for _, nid in ipairs(e[4] or {}) do
      local n = pack.npcs[nid]
      if n and n[3] >= level - M.LEVEL_BELOW and n[2] <= level + M.LEVEL_ABOVE and n[4] == nil then
        local p, t = nearestPoint(n[5], n[1], prep)
        local lv = n[2] == n[3] and tostring(n[2]) or (n[2] .. "-" .. n[3])
        if p then out[#out + 1] = { kind = "drop", text = string.format("Drops from %s (level %s)", n[1], lv), target = p, seconds = t, who = n[1] } end
      end
    end
    local canHerb, canOre = owned.Herbalism ~= nil, owned.Mining ~= nil
    for _, oid in ipairs(e[5] or {}) do
      local o = pack.objects[oid]
      local name = o and o[1] or ""
      local herbish = e[3] == 9
      local oreish = name:find("Vein") or name:find("Deposit")
      if o and ((herbish and canHerb) or (oreish and canOre) or (not herbish and not oreish)) then
        local p, t = nearestPoint(o[2], name, prep)
        if p then out[#out + 1] = { kind = "node", text = (herbish and "Pick " or oreish and "Mine " or "Open ") .. name, target = p, seconds = t, who = name } end
      end
    end
  end
  -- the closest of each kind, nearest first; the auction house where it beats a long trip
  table.sort(out, function(a, b) return (a.seconds or 1e9) < (b.seconds or 1e9) end)
  local keep, kinds = {}, {}
  for _, s in ipairs(out) do
    if not kinds[s.kind] then kinds[s.kind] = true keep[#keep + 1] = s end
  end
  local ah = { kind = "ah", price = price,
    text = price and ("Auction house, about " .. ns.Prices.Coins(price) .. " each") or "Auction house (no price seen yet)" }
  if price and (not keep[1] or (keep[1].seconds or 1e9) > M.FAR) then table.insert(keep, 1, ah) else keep[#keep + 1] = ah end
  -- your other characters
  if ns.Inventory and ns.Inventory.Count then
    local _, per = ns.Inventory:Count(itemID)
    for _, c in ipairs(per or {}) do
      if c.char ~= ns.db.key then
        keep[#keep + 1] = { kind = "alts", text = string.format("%s has %d (mail it over)", tostring(c.char):match("^[^-]+") or c.char, c.count) }
        break
      end
    end
  end
  if not e or (#(e[4] or {}) + #(e[5] or {}) + #(e[6] or {})) == 0 then
    local sub = e and e[3]
    local hint = sub == 6 and (owned.Skinning and "Skin beasts around your level" or "Skinners get it from beasts")
      or sub == 5 and "Drops from humanoids around your level" or nil
    if hint then table.insert(keep, keep[1] and keep[1].kind == "ah" and 2 or 1, { kind = "hint", text = hint }) end
  end
  return keep
end

-- Send the gold arrow (or the whole trip) to a source; the auction house
-- source goes to the nearest auctioneer.
function M:Go(s)
  if not s then return false end
  if s.kind == "ah" then return ns.Nearest and ns.Nearest:Go("auction") end
  if s.target and ns.Journey then
    return ns.Journey:Go({ name = s.who or s.text, sub = s.text, target = s.target, seconds = s.seconds })
  end
  return false
end

-- Make a recipe now (player's click): opens the profession window on the first
-- click, makes the batch on the next.
function M:Make(prof, e)
  if not (ns.Crafter and prof) then return "unknown" end
  if C.InCombat() then ns.Print("%s: not in combat", prof) return "combat" end
  if e and e.id and ns.Crafter:OpenFor(prof) then
    local ok = pcall(C_TradeSkillUI.CraftRecipe, e.id, e.n or 1)
    self:Info("make %s: %d x %s%s", prof, e.n or 1, tostring(e.name), ok and "" or " - CraftRecipe failed")
    if ok then ns.Print("%s: making %d x %s", prof, e.n or 1, tostring(e.name)) end
    return ok and "made" or "failed"
  end
  return ns.Crafter:Make(prof)
end

-- Gathering: what to look for, for your skill, and the nearest spot.
-- Herbs worth picking at your skill, in the guide's order (Data/Herbs.lua
-- lists them easiest first): every herb up to the first one whose stated
-- skill is above yours, the last few of them, each with its nearest spot from
-- the ingredient pack (bug 2026-11-23: the Herbalism page was empty).
M.HERBS_SHOWN = 4
function M:GatherRows(p)
  if p.gather ~= "herb" or not ns.Data then return {} end
  local pack = self:Pack()
  local byName = {}
  for id, e in pairs(pack and pack.items or {}) do
    if type(e) == "table" and e[1] and not byName[e[1]] and e[5] then byName[e[1]] = id end
  end
  local list = {}
  -- the guide's own order (Data:All is unordered)
  local guide = ns.Data.packs and ns.Data.packs.herb and ns.Data.packs.herb["forever-guides"] or {}
  for _, h in ipairs(guide) do
    if h.skill and p.skill and h.skill > p.skill then break end
    list[#list + 1] = h
  end
  local rows = {}
  for i = math.max(1, #list - M.HERBS_SHOWN + 1), #list do
    local h = list[i]
    local id = byName[h.name]
    local src
    if id then
      for _, s in ipairs(self:Sources(id, 1)) do if s.kind == "node" then src = s break end end
    end
    rows[#rows + 1] = { item = { name = h.name, need = 1, itemID = id }, source = src or { kind = "hint",
      text = h.zones and ("grows in " .. table.concat(h.zones, ", ", 1, math.min(3, #h.zones))) or "no spot known yet" }, herb = true }
  end
  -- newest herb first: it gives the most skill
  local out = {}
  for i = #rows, 1, -1 do out[#out + 1] = rows[i] end
  return out
end

function M:GatherLine(p)
  if p.gather == "herb" and ns.Data then
    local names = {}
    for _, h in ipairs(ns.Data:All("herb") or {}) do
      if h.skill and p.skill and h.skill <= p.skill and h.skill >= (p.skill - 75) then names[#names + 1] = h.name end
    end
    return #names > 0 and ("Herbs for your skill: " .. table.concat(names, ", ") .. ". Their spots show on your map.")
      or "Herbs show on your map: green squares are up, grey were picked lately."
  elseif p.gather == "ore" then
    return "Ore veins show on your map. Copper first, then Tin and Silver as your skill grows."
  elseif p.gather == "skin" then
    return "Skin every beast you kill. Beasts around your level give the most skill and Light or Medium Leather."
  elseif p.gather == "fish" then
    return "Fishing has its own tab: your fishing key, where to fish for your skill, and the next book to read."
  end
  return ""
end

function M:Activity()
  local n = 0
  for _, p in ipairs(self:Profs()) do if not p.gather then n = n + #self:Recipes(p.name).now end end
  return string.format("%d professions; %d things you can make right now", #self:Profs(), n)
end

-- ---------------------------------------------------------------- page
local function bar(parent, w)
  local b = CreateFrame("StatusBar", nil, parent)
  b:SetSize(w, 8)
  b:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
  b:SetStatusBarColor(Theme:Color("gold"))
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:SetColorTexture(Theme:Color("border"))
  b:SetMinMaxValues(0, 1)
  return b
end

ns.Hub:AddTab("professions", "Professions", function(p)
  -- left: one card per profession
  p.cards = {}
  local function card(i)
    local c = p.cards[i]
    if c then return c end
    c = CreateFrame("Button", nil, p, Theme:BackdropTemplate())
    c:SetSize(250, 62)
    c:SetPoint("TOPLEFT", 0, -4 - (i - 1) * 68)
    Theme:ApplyPanel(c, "raised", "border")
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(40, 40)
    c.icon:SetPoint("LEFT", 10, 0)
    c.name = UI.Text(c, "large", "goldText")
    c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 10, 0)
    c.skill = UI.Text(c, "normal", "text")
    c.skill:SetPoint("TOPRIGHT", -10, -10)
    c.bar = bar(c, 180)
    c.bar:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -6)
    c.note = UI.Text(c, "small", "muted")
    c.note:SetPoint("TOPLEFT", c.bar, "BOTTOMLEFT", 0, -4)
    c:SetScript("OnClick", function(self) p.pick = self.prof p:Refresh() end)
    p.cards[i] = c
    return c
  end

  -- right: the chosen profession
  local d = UI:Card(p, true)
  p.detail = d
  d:SetPoint("TOPLEFT", 266, -4)
  d:SetPoint("BOTTOMRIGHT", -4, 0)
  d.icon = d:CreateTexture(nil, "ARTWORK")
  d.icon:SetSize(56, 56)
  d.icon:SetPoint("TOPLEFT", 16, -14)
  d.title = UI.Display(d, "page", "goldText")
  d.title:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 14, -2)
  d.sub = UI.Text(d, "normal", "text")
  d.sub:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -6)
  d.sub:SetPoint("RIGHT", d, "RIGHT", -200, 0)
  d.sub:SetJustifyH("LEFT")
  d.best = UI:PrimaryButton(d, "Make the best one now", 180, function() if p.pick then M:Make(p.pick) end end)
  d.best:SetHeight(32)
  d.best:SetPoint("TOPRIGHT", -16, -18)

  d.h1 = UI.Display(d, "card", "goldText")
  d.h1:SetPoint("TOPLEFT", 16, -88)
  d.h1:SetText("Make now, from your bags")
  d.now = UI:ScrollList(d, {
    rows = 5, rowHeight = 28,
    build = function(row)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(22, 22)
      row.icon:SetPoint("LEFT", 6, 0)
      row.text:ClearAllPoints()
      row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
      row.text:SetPoint("RIGHT", row, "RIGHT", -90, 0)
      row.go = UI.Text(row, "normal", "goldText")
      row.go:SetPoint("RIGHT", -10, 0)
    end,
    render = function(row, e)
      local col = M.COLOR[e.diff] or M.COLOR[2]
      local product = e.recipe and e.recipe.product
      local info = product and C.ItemInfo(product)
      row.icon:SetTexture(info and info.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
      row.text:SetText(string.format("%s%s|r  |cff8f96a6%s, you can make %d|r", col[3], e.name, col[2], e.n))
      row.go:SetText("Make  >")
    end,
    onClick = function(e) M:Make(p.pick, e) end,
  })
  d.now:SetPoint("TOPLEFT", d.h1, "BOTTOMLEFT", -6, -6)
  d.now:SetPoint("RIGHT", d, "RIGHT", -12, 0)
  d.none = UI.Text(d, "normal", "muted")
  d.none:SetPoint("TOPLEFT", d.h1, "BOTTOMLEFT", 0, -10)
  d.none:SetPoint("RIGHT", d, "RIGHT", -16, 0)
  d.none:SetJustifyH("LEFT")

  d.h2 = UI.Display(d, "card", "goldText")
  d.h2:SetPoint("TOPLEFT", d.now, "BOTTOMLEFT", 6, -14)
  d.h2:SetText("Next for your skill: what you still need")
  d.need = UI:ScrollList(d, {
    rows = 9, rowHeight = 26,
    build = function(row)
      row.text:ClearAllPoints()
      row.text:SetPoint("LEFT", 8, 0)
      row.text:SetPoint("RIGHT", row, "RIGHT", -90, 0)
      row.go = UI.Text(row, "normal", "goldText")
      row.go:SetPoint("RIGHT", -10, 0)
    end,
    render = function(row, r)
      if r.heading then
        row.text:SetText("|cffffd100" .. r.heading .. "|r")
        row.go:SetText("")
        return
      end
      if r.learn then
        local e, s = r.learn, r.learn.source or {}
        local col = M.COLOR[e.color] or M.COLOR[2]
        row.text:SetText(string.format("%s%s|r  |cff8f96a6skill %d: %s%s|r", col[3], e.name, e.at, s.text or "?",
          s.seconds and ("  (" .. ns.Travel.Minutes(s.seconds) .. " away)") or ""))
        row.go:SetText((s.target or s.kind == "ah") and "Go  >" or "")
        return
      end
      if r.recipe then
        local col = M.COLOR[r.recipe.diff] or M.COLOR[2]
        row.text:SetText(string.format("%s%s|r  |cff8f96a6%s|r", col[3], r.recipe.name, col[2]))
        row.go:SetText("")
      else
        local s = r.source
        if r.herb then
          row.text:SetText(string.format("%s:  %s%s", r.item.name, s and s.text or "?",
            s and s.seconds and ("  |cff8f96a6(" .. ns.Travel.Minutes(s.seconds) .. " away)|r") or ""))
          row.go:SetText(s and s.target and "Go  >" or "")
          return
        end
        row.text:SetText(string.format("     %s x%d:  %s%s", r.item.name, r.item.need, s and s.text or "?",
          s and s.seconds and ("  |cff8f96a6(" .. ns.Travel.Minutes(s.seconds) .. " away)|r") or ""))
        row.go:SetText(s and (s.target or s.kind == "ah") and "Go  >" or "")
      end
    end,
    onClick = function(r) if r.source then M:Go(r.source) end end,
  })
  d.need:SetPoint("TOPLEFT", d.h2, "BOTTOMLEFT", -6, -6)
  d.need:SetPoint("RIGHT", d, "RIGHT", -12, 0)
  d.gather = UI.Text(d, "normal", "text")
  d.gather:SetPoint("TOPLEFT", d.h2, "BOTTOMLEFT", 0, -10)
  d.gather:SetPoint("RIGHT", d, "RIGHT", -16, 0)
  d.gather:SetJustifyH("LEFT")
  d.note = UI.Text(d, "small", "muted")
  d.note:SetPoint("BOTTOMLEFT", 16, 10)
  d.note:SetPoint("RIGHT", d, "RIGHT", -16, 0)
  d.note:SetJustifyH("LEFT")
  d.note:SetText("Recipes and colours are from the last time you opened this profession. Where things come from is community data, unchecked; your own finds win.")

  function p:Refresh()
    local profs = M:Profs()
    for i, c in ipairs(self.cards) do if i > #profs then c:Hide() end end
    if #profs == 0 then
      d.title:SetText("No professions yet")
      d.sub:SetText("Visit a profession trainer to learn one: Map and places, Your trainers.")
      d.now:SetItems({}) d.need:SetItems({}) d.none:SetText("") d.gather:SetText("")
      return
    end
    local pick
    for _, pr in ipairs(profs) do if pr.name == self.pick then pick = pr end end
    pick = pick or profs[1]
    self.pick = pick.name
    for i, pr in ipairs(profs) do
      local c = card(i)
      c.prof = pr.name
      c.icon:SetTexture("Interface\\Icons\\" .. (M.ICON[pr.name] or "INV_Misc_QuestionMark"))
      c.name:SetText(pr.name)
      c.skill:SetText(pr.skill and string.format("%d / %d", pr.skill, pr.max or 0) or "")
      c.bar:SetValue(pr.skill and pr.max and pr.max > 0 and pr.skill / pr.max or 0)
      local n = not pr.gather and #M:Recipes(pr.name).now or 0
      c.note:SetText(pr.gather and "gathering" or n > 0 and string.format("|cff40ff40%d you can make now|r", n) or "nothing to make yet")
      Theme:ApplyPanel(c, pr.name == pick.name and "hover" or "raised", pr.name == pick.name and "gold" or "border")
      c:Show()
    end
    d.icon:SetTexture("Interface\\Icons\\" .. (M.ICON[pick.name] or "INV_Misc_QuestionMark"))
    d.title:SetText(pick.name)
    local capped = pick.skill and pick.max and pick.skill >= pick.max
    d.sub:SetText((pick.skill and string.format("Skill %d of %d.  ", pick.skill, pick.max or 0) or "")
      .. (capped and "|cffffd100You're at the cap: visit your trainer to learn the next rank.|r" or ""))
    if pick.gather then
      d.best:Hide()
      d.h1:SetText("How to raise it")
      -- the empty lists sat on top of the text (bug 2026-11-23): hide the make-now list
      d.now:Hide()
      d.none:SetText(M:GatherLine(pick))
      local rows = M:GatherRows(pick)
      d.h2:SetText(#rows > 0 and "Herbs for your skill: the closest spot of each" or "")
      d.need:SetShown(#rows > 0)
      d.need:SetItems(rows)
      d.gather:SetText("")
      return
    end
    d.best:Show()
    d.now:Show() d.need:Show()
    d.h1:SetText("Make now, from your bags")
    d.h2:SetText("Next for your skill: what you still need")
    local r = M:Recipes(pick.name)
    d.now:SetItems(r.now)
    d.none:SetText(#r.now == 0 and (next(pick.recipes) and "Nothing in your bags makes a recipe yet. See below what to get."
      or "Open " .. pick.name .. " once (from your spellbook) so Outrider can read your recipes.") or "")
    local rows = {}
    for i, e in ipairs(r.next) do
      if i > 3 then break end
      rows[#rows + 1] = { recipe = e }
      for _, it in ipairs(e.missing) do rows[#rows + 1] = { item = it, source = M:Sources(it.itemID, it.need)[1] } end
    end
    local gotAll = #rows == 0 and #r.now > 0
    -- recipes to learn next (crafting pack), with where to learn each
    local learn = M:ToLearn(pick.name, pick.skill, pick.recipes)
    if #learn > 0 then
      rows[#rows + 1] = { heading = "Recipes to learn next" }
      for _, e in ipairs(learn) do rows[#rows + 1] = { learn = e, source = e.source } end
    end
    d.need:SetItems(rows)
    d.gather:SetText(gotAll and #learn == 0 and "You have everything for your best recipes. Make them above." or "")
  end
end, 30)

-- UI/Pages.lua
-- Hub pages that turn /ride commands into controls (Gary, 2026-11-13: "do
-- everything inside the Outrider window, logical and helpful"). Buttons run
-- the same code as the typed command (UI.Run), so nothing behaves differently.
-- Anything without its own control is on the All commands tab in Help.
-- Home: what you need right now (nearest places, where you're headed, best
-- quests, upgrades, rare watch, errands, pet).

local _, ns = ...
local UI, Theme = ns.UI, ns.Theme
local C = ns.Compat
local Run = UI.Run

local function mod(name) return ns.Modules:Get(name) end
local function set(name) local m = mod(name) return m and m:Settings() or {} end
local function onoff(v) return v and "on" or "off" end

-- ------------------------------------------------------------------ Home
-- Home, rebuilt as the showpiece (Gary, 2026-11-21: "if the rest of the pages
-- are hero shot worthy this page needs to be epic legendary worthy ... more
-- options for directions and more informative ... an average 8th grader
-- should be able to look at it and instantly know what to do").
--   hero: painted scene, class emblem, name, level, zone (and if it suits
--   you), XP bar with rested, gold; 1-2-3 steps
--   next step: big card, Go, and two other ideas you can click
--   at a glance: bags, repair, rested, talent points, ammo (hunters)
--   where to?: picture tiles for every place and your class trainer, a search
--   six picture cards whose every line sets the arrow
local HOME_PAD = 8

-- a card with a picture, a title and up to n clickable lines
local HOME_ROWS = 6
local function homeList(parent, title, art, n)
  local c = UI:Card(parent)
  c.pic = c:CreateTexture(nil, "ARTWORK")
  c.pic:SetSize(34, 34)
  c.pic:SetPoint("TOPLEFT", 10, -8)
  if not (ns.Art and ns.Art:Set(c.pic, art, "Interface\\Icons\\INV_Misc_Book_09")) then c.pic:SetTexture("Interface\\Icons\\INV_Misc_Book_09") end
  c.title = UI.Display(c, "side", "goldText")
  c.title:SetPoint("LEFT", c.pic, "RIGHT", 10, 0)
  c.title:SetText(title)
  c.more = UI:Button(c, "More", 64, nil)
  c.more:SetHeight(20)
  c.more:SetPoint("TOPRIGHT", -10, -12)
  c.rows = {}
  for i = 1, n do
    local b = CreateFrame("Button", nil, c)
    b:SetHeight(24)
    b:SetPoint("TOPLEFT", 10, -48 - (i - 1) * 26)
    b:SetPoint("RIGHT", c, "RIGHT", -10, 0)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    local r, g, bl = Theme:Color("gold")
    b.hl:SetColorTexture(r, g, bl, 0.12)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(20, 20)
    b.icon:SetPoint("LEFT", 2, 0)
    b.text = UI.Text(b, "normal", "text")
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
    b.text:SetPoint("RIGHT", b, "RIGHT", -22, 0)
    b.text:SetJustifyH("LEFT")
    if b.text.SetWordWrap then b.text:SetWordWrap(false) end
    b.go = UI.Text(b, "normal", "goldText")
    b.go:SetPoint("RIGHT", -4, 0)
    b.go:SetText(">")
    b:SetScript("OnClick", function(self) if self.fn then ns.Safe("home:row", self.fn) end end)
    b:SetScript("OnEnter", function(self)
      if not self.tip then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.tip, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:Hide()
    c.rows[i] = b
  end
  c.empty = UI.Text(c, "normal", "muted")
  c.empty:SetPoint("TOPLEFT", 12, -50)
  c.empty:SetPoint("RIGHT", c, "RIGHT", -12, 0)
  c.empty:SetJustifyH("LEFT")
  -- items = { { icon, text, fn, tip }, ... }
  function c:Fill(items, emptyText)
    for i, b in ipairs(self.rows) do
      local it = i <= (self.cap or 3) and items[i] or nil
      if it then
        b.icon:SetTexture(it[1] or "Interface\\Icons\\INV_Misc_QuestionMark")
        b.text:SetText(it[2])
        b.fn, b.tip = it[3], it[4]
        b.go:SetShown(it[3] ~= nil)
        b:Show()
      else
        b:Hide()
      end
    end
    self.empty:SetText(#items == 0 and (emptyText or "") or "")
  end
  return c
end

local function itemIcon(id)
  return id and (C.Call("C_Item.GetItemIconByID", id) or C.Call("GetItemIcon", id)) or nil
end

ns.Hub:AddTab("home", "Home", function(p)
  local cls = ns.PlayerClass and ns.PlayerClass() or ""
  -- ---------------------------------------------------------------- hero
  p.hero = CreateFrame("Frame", nil, p, Theme:BackdropTemplate())
  p.hero:SetPoint("TOPLEFT", 0, 0)
  p.hero:SetPoint("RIGHT", p, "RIGHT", 0, 0)
  p.hero:SetHeight(164)
  Theme:ApplyPanel(p.hero, "bg", "gold")
  -- the painting comes in two halves (WoW loads addon pictures up to 1024
  -- wide; one 2048-wide file showed black: Gary's screenshot, 2026-11-21)
  p.hero.artL = p.hero:CreateTexture(nil, "BACKGROUND")
  p.hero.artL:SetPoint("TOPLEFT", 1, -1)
  p.hero.artL:SetPoint("BOTTOMRIGHT", p.hero, "BOTTOM", 0, 1)
  p.hero.artR = p.hero:CreateTexture(nil, "BACKGROUND")
  p.hero.artR:SetPoint("TOPLEFT", p.hero, "TOP", 0, -1)
  p.hero.artR:SetPoint("BOTTOMRIGHT", -1, 1)
  p.hero.halves = ns.Art and ns.Art:Set(p.hero.artL, "home_hero_l") and ns.Art:Set(p.hero.artR, "home_hero_r")
  if not p.hero.halves then
    p.hero.artR:Hide()
    p.hero.artL:ClearAllPoints()
    p.hero.artL:SetPoint("TOPLEFT", 1, -1)
    p.hero.artL:SetPoint("BOTTOMRIGHT", -1, 1)
    if not (ns.Art and (ns.Art:Set(p.hero.artL, "header_world") or ns.Art:Set(p.hero.artL, "header"))) then
      p.hero.artL:SetColorTexture(Theme:Color("panel"))
    end
  end
  -- darker on the left so the words read over the painting
  -- solid dark under the emblem and name, then a long soft fade to clear, so
  -- every word reads even where the painting is bright (Gary's screenshot,
  -- 2026-11-21: "rested" and step 3 ran into the adventurer)
  p.hero.shade = p.hero:CreateTexture(nil, "BORDER")
  p.hero.shade:SetPoint("TOPLEFT", 1, -1)
  p.hero.shade:SetPoint("BOTTOMLEFT", 1, 1)
  p.hero.shade:SetWidth(470)
  p.hero.shade:SetColorTexture(0, 0, 0, 0.62)
  p.hero.fade = p.hero:CreateTexture(nil, "BORDER")
  p.hero.fade:SetPoint("TOPLEFT", p.hero.shade, "TOPRIGHT", 0, 0)
  p.hero.fade:SetPoint("BOTTOMLEFT", p.hero.shade, "BOTTOMRIGHT", 0, 0)
  p.hero.fade:SetWidth(480)
  p.hero.fade:SetColorTexture(1, 1, 1, 1)
  local okFade = false
  if p.hero.fade.SetGradient and rawget(_G, "CreateColor") then
    okFade = pcall(p.hero.fade.SetGradient, p.hero.fade, "HORIZONTAL", CreateColor(0, 0, 0, 0.62), CreateColor(0, 0, 0, 0))
  end
  if not okFade and p.hero.fade.SetGradientAlpha then
    okFade = pcall(p.hero.fade.SetGradientAlpha, p.hero.fade, "HORIZONTAL", 0, 0, 0, 0.62, 0, 0, 0, 0)
  end
  if not okFade then p.hero.fade:SetColorTexture(0, 0, 0, 0.35) end
  p.hero.tile = CreateFrame("Frame", nil, p.hero, Theme:BackdropTemplate())
  p.hero.tile:SetSize(96, 96)
  p.hero.tile:SetPoint("LEFT", 20, 4)
  Theme:ApplyPanel(p.hero.tile, "bg", "gold")
  p.hero.emblem = p.hero.tile:CreateTexture(nil, "ARTWORK")
  p.hero.emblem:SetPoint("TOPLEFT", 3, -3)
  p.hero.emblem:SetPoint("BOTTOMRIGHT", -3, 3)
  if not (ns.Art and ns.Art:Set(p.hero.emblem, "class_" .. cls:lower(), "Interface\\Icons\\INV_Misc_Book_09")) then
    p.hero.emblem:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
  end
  p.heading = UI.Display(p.hero, "page", "text")
  p.heading:SetPoint("TOPLEFT", p.hero.tile, "TOPRIGHT", 18, -2)
  p.sub = UI.Text(p.hero, "large", "text")
  p.sub:SetPoint("TOPLEFT", p.heading, "BOTTOMLEFT", 0, -6)
  p.zone = UI.Text(p.hero, "normal", "body")
  p.zone:SetPoint("TOPLEFT", p.sub, "BOTTOMLEFT", 0, -6)
  -- XP bar: gold for your XP, blue for rested
  p.xp = CreateFrame("Frame", nil, p.hero, Theme:BackdropTemplate())
  p.xp:SetSize(340, 14)
  p.xp:SetPoint("TOPLEFT", p.zone, "BOTTOMLEFT", 0, -10)
  Theme:ApplyPanel(p.xp, "bg", "border")
  p.xp.fill = p.xp:CreateTexture(nil, "ARTWORK")
  p.xp.fill:SetPoint("TOPLEFT", 1, -1)
  p.xp.fill:SetPoint("BOTTOMLEFT", 1, 1)
  p.xp.fill:SetColorTexture(Theme:Color("gold"))
  p.xp.rest = p.xp:CreateTexture(nil, "ARTWORK")
  p.xp.rest:SetPoint("TOPLEFT", p.xp.fill, "TOPRIGHT", 0, 0)
  p.xp.rest:SetPoint("BOTTOMLEFT", p.xp.fill, "BOTTOMRIGHT", 0, 0)
  p.xp.rest:SetColorTexture(0.35, 0.55, 1, 0.6)
  p.xp.text = UI.Text(p.hero, "small", "text")
  p.xp.text:SetPoint("LEFT", p.xp, "RIGHT", 10, 0)
  -- your gold on a dark pill: the painting's city is bright there
  p.goldBack = CreateFrame("Frame", nil, p.hero, Theme:BackdropTemplate())
  p.goldBack:SetPoint("BOTTOMRIGHT", -10, 10)
  p.goldBack:SetSize(130, 30)
  Theme:ApplyPanel(p.goldBack, "bg", "gold")
  if p.goldBack.SetBackdropColor then p.goldBack:SetBackdropColor(0, 0, 0, 0.75) end
  p.gold = UI.Display(p.goldBack, "card", "goldText")
  p.gold:SetPoint("RIGHT", -10, 0)
  -- 1-2-3, on the painting's lower edge
  p.steps = {}
  local STEPS = { "Do your next step", "Pick where to go", "Click any line below for the arrow" }
  local prevStep
  for i, txt in ipairs(STEPS) do
    local box = p.hero:CreateTexture(nil, "OVERLAY")
    box:SetSize(18, 18)
    if prevStep then box:SetPoint("LEFT", prevStep, "RIGHT", 18, 0) else box:SetPoint("BOTTOMLEFT", p.hero.tile, "BOTTOMRIGHT", 18, -20) end
    box:SetColorTexture(Theme:Color("gold"))
    local num = UI.Text(p.hero, "small", "onGold")
    num:SetPoint("CENTER", box, "CENTER", 0, 0)
    num:SetText(tostring(i))
    local t = UI.Text(p.hero, "normal", "text")
    t:SetPoint("LEFT", box, "RIGHT", 6, 0)
    t:SetText(txt)
    p.steps[i] = { box = box, num = num, text = t }
    prevStep = t
  end

  -- --------------------------------------------------------- next step
  p.next = UI:Card(p, true)
  if p.next.SetBackdropBorderColor then p.next:SetBackdropBorderColor(Theme:Color("gold")) end
  p.next:SetHeight(128)
  p.next:SetPoint("TOPLEFT", p.hero, "BOTTOMLEFT", 0, -HOME_PAD)
  p.next.pic = p.next:CreateTexture(nil, "ARTWORK")
  p.next.pic:SetSize(76, 76)
  p.next.pic:SetPoint("TOPLEFT", 14, -14)
  p.next.label = UI.Text(p.next, "small", "goldText")
  p.next.label:SetPoint("TOPLEFT", p.next.pic, "TOPRIGHT", 14, 0)
  p.next.label:SetText("YOUR NEXT STEP")
  p.next.title = UI.Display(p.next, "card", "text")
  p.next.title:SetPoint("TOPLEFT", p.next.label, "BOTTOMLEFT", 0, -4)
  p.next.title:SetPoint("RIGHT", p.next, "RIGHT", -150, 0)
  p.next.title:SetJustifyH("LEFT")
  p.next.why = UI.Text(p.next, "normal", "body")
  p.next.why:SetPoint("TOPLEFT", p.next.title, "BOTTOMLEFT", 0, -6)
  p.next.why:SetPoint("RIGHT", p.next, "RIGHT", -150, 0)
  p.next.why:SetJustifyH("LEFT")
  p.next.go = UI:PrimaryButton(p.next, "Go  >", 128, function() if p.step and ns.WhatNow then ns.WhatNow:Go(p.step) end end)
  p.next.go:SetHeight(34)
  p.next.go:SetPoint("TOPRIGHT", -14, -18)
  UI.Tip(p.next.go, "Go", "Starts your next step: sets the gold arrow or opens what you need.")
  p.next.all = UI:Button(p.next, "All steps", 128, function() ns.Hub.frame.tabBar:Select("whatnow") end)
  p.next.all:SetHeight(22)
  p.next.all:SetPoint("TOP", p.next.go, "BOTTOM", 0, -8)
  p.next.alts = {}
  for i = 1, 2 do
    local b = CreateFrame("Button", nil, p.next)
    b:SetHeight(18)
    b:SetPoint("BOTTOMLEFT", p.next.pic, "BOTTOMRIGHT", 14, -18 - (i - 1) * 0)
    b.text = UI.Text(b, "small", "muted")
    b.text:SetPoint("LEFT")
    b:SetScript("OnClick", function(self) if self.step and ns.WhatNow then ns.WhatNow:Go(self.step) end end)
    b:SetScript("OnEnter", function(self) self.text:SetTextColor(Theme:Color("goldText")) end)
    b:SetScript("OnLeave", function(self) self.text:SetTextColor(Theme:Color("muted")) end)
    p.next.alts[i] = b
  end

  -- -------------------------------------------------------- at a glance
  p.glance = UI:Card(p)
  p.glance:SetPoint("TOPLEFT", p.next, "TOPRIGHT", HOME_PAD, 0)
  p.glance:SetPoint("RIGHT", p, "RIGHT", 0, 0)
  p.glance:SetHeight(128)
  p.glance.title = UI.Display(p.glance, "side", "goldText")
  p.glance.title:SetPoint("TOPLEFT", 12, -9)
  p.glance.title:SetText("At a glance")
  p.glance.tiles = {}
  for i = 1, 4 do
    local t = CreateFrame("Frame", nil, p.glance, Theme:BackdropTemplate())
    t:SetSize(100, 72)
    Theme:ApplyPanel(t, "raised", "border")
    t.cap = UI.Text(t, "small", "muted")
    t.cap:SetPoint("TOPLEFT", 8, -8)
    t.value = UI.Display(t, "card", "text")
    t.value:SetPoint("TOPLEFT", t.cap, "BOTTOMLEFT", 0, -6)
    t.note = UI.Text(t, "small", "muted")
    t.note:SetPoint("BOTTOMLEFT", 8, 8)
    p.glance.tiles[i] = t
  end

  -- ----------------------------------------------------------- where to
  p.where = UI:Card(p)
  p.where:SetPoint("TOPLEFT", p.next, "BOTTOMLEFT", 0, -HOME_PAD)
  p.where:SetPoint("RIGHT", p, "RIGHT", 0, 0)
  p.where:SetHeight(122)
  p.where.title = UI.Display(p.where, "side", "goldText")
  p.where.title:SetPoint("TOPLEFT", 12, -9)
  p.where.title:SetText("Where to?")
  p.where.hint = UI.Text(p.where, "small", "muted")
  p.where.hint:SetPoint("LEFT", p.where.title, "RIGHT", 12, 0)
  p.where.hint:SetText("press a place: the gold arrow points to the nearest one")
  p.where.box = UI:SearchBox(p.where, 220, "Take me to... (a name, quest, place)")
  p.where.box:SetHeight(20)
  p.where.box:SetPoint("TOPRIGHT", -12, -9)
  p.where.box:SetScript("OnEnterPressed", function(box) local t = box:GetText() or "" box:ClearFocus() ns.Hub:Search(t) end)
  -- small picture tiles in one or two rows
  p.where.tiles = {}
  local function tileList()
    local items = {}
    local clsName = C.Readable(C.Call("UnitClass", "player")) or "Class"
    items[#items + 1] = { clsName .. " trainer", "class_" .. cls:lower(), "INV_Misc_Book_09", function()
      local _, msg = ns.Nearest:Go("class_trainer") ns.Print(tostring(msg)) end }
    for _, it in ipairs(ns.ClassPage and ns.ClassPage.PlaceTiles and ns.ClassPage.PlaceTiles() or {}) do items[#items + 1] = it end
    return items
  end
  local TW, TH = 86, 62
  for i, it in ipairs(tileList()) do
    local b = CreateFrame("Button", nil, p.where, Theme:BackdropTemplate())
    b:SetSize(TW, TH)
    Theme:ApplyPanel(b, "raised", "border")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(30, 30)
    b.icon:SetPoint("TOP", 0, -6)
    if not (ns.Art and it[2] and ns.Art:Set(b.icon, it[2], "Interface\\Icons\\" .. (it[3] or "INV_Misc_QuestionMark"))) then
      b.icon:SetTexture("Interface\\Icons\\" .. (it[3] or "INV_Misc_QuestionMark"))
    end
    b.label = UI.Text(b, "small", "text")
    b.label:SetPoint("BOTTOM", 0, 6)
    b.label:SetText(it[1])
    b:SetScript("OnClick", function() ns.Safe("home:tile", it[4]) end)
    b:SetScript("OnEnter", function(self) Theme:ApplyPanel(self, "hover", "gold") end)
    b:SetScript("OnLeave", function(self) Theme:ApplyPanel(self, "raised", "border") end)
    UI.Tip(b, it[1], it[5] or ("Points the gold arrow at the nearest " .. it[1]:lower() .. "."))
    p.where.tiles[i] = b
  end

  -- ---------------------------------------------------------- six cards
  p.cards = {
    quests = homeList(p, "Quests for you", "kind_quest", HOME_ROWS),
    gear = homeList(p, "Upgrades near you", "kind_gear", HOME_ROWS),
    dungeon = homeList(p, "Your next dungeon", "kind_dungeon", HOME_ROWS),
    rares = homeList(p, "Rares", "kind_rare", HOME_ROWS),
    town = homeList(p, "To do in town", "kind_errand", HOME_ROWS),
    trip = homeList(p, "Your trip", "kind_zone", HOME_ROWS),
  }
  p.cards.quests.more:SetScript("OnClick", function() ns.Hub.frame.tabBar:Select("quests") end)
  p.cards.gear.more:SetScript("OnClick", function() ns.Hub.frame.tabBar:Select("gear") end)
  p.cards.dungeon.more:SetScript("OnClick", function() ns.Hub.frame.tabBar:Select("dungeonquests") end)
  p.cards.rares.more:SetScript("OnClick", function() ns.Hub.frame.tabBar:Select("rares") end)
  p.cards.town.more:SetScript("OnClick", function() ns.Hub.frame.tabBar:Select("errands") end)
  p.cards.trip.more:SetScript("OnClick", function() ns.Hub.frame.tabBar:Select("journey") end)
  p.cards.trip.more.label:SetText("Find")
  local ORDER = { "quests", "gear", "dungeon", "rares", "town", "trip" }

  -- widths follow the window
  function p:Layout()
    local w = self:GetWidth() or 1100
    if w < 400 then w = 1100 end
    -- the hero painting is 4:1; show the band that fills the banner without
    -- stretching, a little above the middle (the adventurer's head and the
    -- dungeon gate sit there)
    local hw, hh = w - 2, (self.hero:GetHeight() or 150) - 2
    if self.hero.halves and hw > 0 and hh > 0 and self.hero.artL.SetTexCoord then
      local band = math.min(1, 4 * hh / hw)
      local top = math.max(0, math.min(1 - band, 0.46 - band / 2))
      self.hero.artL:SetTexCoord(0, 1, top, top + band)
      self.hero.artR:SetTexCoord(0, 1, top, top + band)
    end
    self.next:SetWidth(math.floor((w - HOME_PAD) * 0.6))
    -- glance tiles in a row
    local gw = (w - HOME_PAD) * 0.4
    local tw = math.floor((gw - 24 - 3 * 6) / 4)
    for i, t in ipairs(self.glance.tiles) do
      t:SetWidth(tw)
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", 12 + (i - 1) * (tw + 6), -40)
    end
    -- place tiles: as many per row as fit
    local per = math.max(1, math.floor((w - 24 + 6) / (TW + 6)))
    for i, b in ipairs(self.where.tiles) do
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", 12 + ((i - 1) % per) * (TW + 6), -38 - math.floor((i - 1) / per) * (TH + 6))
    end
    local rowsOfTiles = math.ceil(#self.where.tiles / per)
    self.where:SetHeight(46 + rowsOfTiles * (TH + 6))
    -- cards: three columns, two rows, as tall as the window allows (Gary's
    -- screenshot: a third of the page was empty)
    local cw = math.floor((w - 2 * HOME_PAD) / 3)
    local used = (self.hero:GetHeight() or 164) + (self.next:GetHeight() or 128) + (self.where:GetHeight() or 122) + 3 * HOME_PAD
    local free = (self:GetHeight() or 0) - used - 2 * HOME_PAD
    local ch = math.max(134, math.min(56 + HOME_ROWS * 26, math.floor(free / 2)))
    self.cardRows = math.max(3, math.min(HOME_ROWS, math.floor((ch - 56) / 26)))
    for i, key in ipairs(ORDER) do
      local c = self.cards[key]
      c:ClearAllPoints()
      c:SetSize(cw, ch)
      local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
      c:SetPoint("TOPLEFT", self.where, "BOTTOMLEFT", col * (cw + HOME_PAD), -HOME_PAD - row * (ch + HOME_PAD))
      c.cap = self.cardRows
    end
  end
  p:Layout()
  if p.HookScript then p:HookScript("OnSizeChanged", function(self) self:Layout() end) end

  function p:Refresh()
    self:Layout()
    -- hero
    local name = tostring(ns.db.key):match("^[^-]+") or "?"
    self.heading:SetText("Welcome back, " .. name)
    local level = tonumber(C.Readable(C.Call("UnitLevel", "player"))) or 1
    self.sub:SetText(string.format("Level %d %s", level, tostring(C.Readable(C.Call("UnitClass", "player")) or "")))
    local mapID = C.PlayerPosition("player")
    local zoneName = mapID and ns.Travel and ns.Travel.ZoneName(mapID) or ""
    local lo, hi = nil, nil
    -- a capital city has no level range: its guards are 55 (Thunder Bluff read "50-60: too high")
    local city = ns.ZoneLevels and ns.ZoneLevels.CITIES and ns.ZoneLevels.CITIES[zoneName]
    if mapID and not city and ns.ZoneLevels and ns.ZoneLevels.Range then lo, hi = ns.ZoneLevels:Range(mapID) end
    if lo then
      local col = ns.ZoneLevels.Color(lo, hi, level)
      self.zone:SetText(string.format("%s   %s%d-%d: %s|r", zoneName, Theme:Hex(col), lo, hi, ns.ZoneLevels.WORDS[col] or ""))
    else
      self.zone:SetText(city and (zoneName .. "   |cff8f96a6a capital city: trainers, bank and auction house|r") or zoneName)
    end
    local xp = tonumber(C.Readable(C.Call("UnitXP", "player"))) or 0
    local need = tonumber(C.Readable(C.Call("UnitXPMax", "player"))) or 0
    local rested = tonumber(C.Readable(C.Call("GetXPExhaustion"))) or 0
    local full = (self.xp:GetWidth() or 340) - 2
    local f1 = need > 0 and math.min(1, xp / need) or 0
    local f2 = need > 0 and math.min(1 - f1, rested / need) or 0
    self.xp.fill:SetWidth(math.max(1, full * f1))
    self.xp.rest:SetWidth(math.max(1, full * f2))
    self.xp.text:SetText(need > 0 and string.format("%d%% to level %d%s", math.floor(f1 * 100), level + 1,
      rested > 0 and string.format(",  |cff5a8cffrested +%d%%|r", math.floor(rested / need * 100)) or "") or "")
    local money = tonumber(C.Call("GetMoney")) or 0
    self.gold:SetText(ns.Prices and ns.Prices.Coins and ns.Prices.Coins(money) or tostring(money))
    self.goldBack:SetWidth(math.max(80, (self.gold:GetStringWidth() or 100) + 22))
    -- next step and two other ideas
    local list = ns.WhatNow and ns.WhatNow.enabled and ns.WhatNow:List() or {}
    local step = list[1]
    self.step = step
    if step then
      ns.Art:SetKind(self.next.pic, step.kind)
      self.next.title:SetText(step.title or "")
      self.next.why:SetText((step.why or "") .. (step.where and step.where ~= "" and ("  |cff8f96a6" .. step.where .. "|r") or ""))
      self.next.go:Show()
    else
      ns.Art:SetKind(self.next.pic, "quest")
      self.next.title:SetText("Nothing stands out right now")
      self.next.why:SetText("Pick a goal on Next steps, or a place below.")
      self.next.go:Hide()
    end
    for i, b in ipairs(self.next.alts) do
      local s2 = list[i + 1]
      b.step = s2
      b.text:SetText(s2 and ((i == 1 and "Or: " or "Or: ") .. tostring(s2.title)) or "")
      b:SetWidth(math.max(40, (b.text:GetStringWidth() or 200) + 4))
      b:ClearAllPoints()
      if i == 1 then b:SetPoint("TOPLEFT", self.next.why, "BOTTOMLEFT", 0, -8)
      else b:SetPoint("TOPLEFT", self.next.alts[1], "BOTTOMLEFT", 0, -2) end
      b:SetShown(s2 ~= nil)
    end
    -- at a glance
    local IB = ns.InfoBar
    local free, total = 0, 0
    if IB and IB.Bags then free, total = IB.Bags() end
    local dura = IB and IB.Durability and select(2, IB.Durability())
    local pts = tonumber(C.Readable(C.Call("UnitCharacterPoints", "player"))) or 0
    local G = {
      { "Bag space", string.format("%d free", free or 0), (free or 0) < 4 and "bad" or "text", total and total > 0 and ("of " .. total) or "" },
      { "Gear repair", dura and (math.floor(dura + 0.5) .. "%") or "-", dura and dura < 30 and "bad" or "text", dura and dura < 30 and "repair soon" or "lowest piece" },
      { "Rested", need > 0 and (math.floor(rested / need * 100) .. "%") or "-", rested > 0 and "accent" or "text", rested > 0 and "bonus XP" or "rest in an inn" },
    }
    if cls == "HUNTER" and IB and IB.Ammo then
      local a = IB.Ammo()
      G[4] = { "Ammo", tostring(a or 0), (a or 0) < 200 and "bad" or "text", "arrows or bullets" }
    else
      G[4] = { "Talent points", level < 10 and "at 10" or tostring(pts), pts > 0 and "good" or "text", pts > 0 and "press N" or "all spent" }
    end
    for i, t in ipairs(self.glance.tiles) do
      local g = G[i]
      t.cap:SetText(g[1])
      t.value:SetText(g[2])
      t.value:SetTextColor(Theme:Color(g[3]))
      t.note:SetText(g[4])
    end
    -- quests for you
    local items = {}
    for i, e in ipairs(ns.Finder and ns.Finder:Find({ kind = "quest" }) or {}) do
      if i > HOME_ROWS then break end
      items[#items + 1] = { "Interface\\GossipFrame\\AvailableQuestIcon", string.format("|cff8f96a6[%d]|r %s  |cff8f96a6%s|r", e.level or 0, tostring(e.name), ns.Travel.Minutes(e.seconds)),
        e.target and function() ns.Journey:Go(e) end, tostring(e.sub or "") }
    end
    self.cards.quests:Fill(items, "None found nearby. Look for ! on the map.")
    -- upgrades near you
    items = {}
    for i, c in ipairs(ns.Nearby and ns.Nearby:Candidates() or {}) do
      if i > HOME_ROWS then break end
      local w = c.where or {}
      items[#items + 1] = { itemIcon(c.itemID), string.format("%s  %s", tostring(c.name), ns.GearScore and ns.GearScore.UpText and ns.GearScore.UpText(c.pct) or ""),
        w.mapID and function() ns.Waypoints:Set(w.mapID, w.x, w.y, tostring(c.name)) end, ns.Nearby.Source and ns.Nearby.Source(c) or "" }
    end
    self.cards.gear:Fill(items, "Nothing better than what you wear around here.")
    -- your next dungeon
    items = {}
    local D = ns.DungeonQuests
    if D and D.enabled then
      local ctx = D:Context()
      local best, unlock = D:Next(ctx)
      if best then
        items[#items + 1] = { "Interface\\Icons\\INV_Misc_Key_14", string.format("%s  |cff8f96a6levels %d-%d|r", best.name, best.lo, best.hi),
          best.entrance and function() D:Go(best.entrance) end, "Go to the entrance" }
        for _, st in ipairs(best.steps) do
          if #items >= HOME_ROWS then break end
          if D:Status(st, ctx) == "todo" then
            items[#items + 1] = { "Interface\\GossipFrame\\AvailableQuestIcon", string.format("Take %s  |cff8f96a6%s|r", tostring(st.quest), tostring(st.zone)),
              function() D:Go(st) end, tostring(st.note or "") }
          end
        end
      elseif unlock then
        items[#items + 1] = { "Interface\\Icons\\INV_Misc_Key_14", string.format("%s opens at level %d", unlock.name, unlock.lo), nil, nil }
      end
    end
    self.cards.dungeon:Fill(items, "No dungeon right for your level yet.")
    -- rares: watched first, then known ones in this zone
    items = {}
    for k in pairs(set("RareScan").watch or {}) do
      if #items >= HOME_ROWS then break end
      items[#items + 1] = { "Interface\\TargetingFrame\\UI-TargetingFrame-Skull", "Watching " .. ns.TitleCase(tostring(k)), function() ns.Hub.frame.tabBar:Select("rares") end }
    end
    if #items < HOME_ROWS and mapID and ns.MapPins then
      for _, pin in ipairs(ns.MapPins:PinsFor(mapID)) do
        if #items >= HOME_ROWS then break end
        if pin.kind == "rare" and pin.npcID and not tostring(pin.id):match("^rare%-%d+%-%d+$") then
          items[#items + 1] = { "Interface\\TargetingFrame\\UI-TargetingFrame-Skull", (tostring(pin.name):match("^([^%(,]+)") or pin.name) .. (pin.stateLine and ("  |cff8f96a6" .. pin.stateLine .. "|r") or ""),
            function() ns.Waypoints:Set(mapID, pin.x, pin.y, tostring(pin.name)) end, "Sets the arrow to where it spawns" }
        end
      end
    end
    self.cards.rares:Fill(items, "No rares known here yet. Mouse over one and Outrider remembers it.")
    -- to do in town
    items = {}
    for i, e in ipairs(ns.Errands and ns.Errands:List() or {}) do
      if i > HOME_ROWS then break end
      items[#items + 1] = { "Interface\\Icons\\" .. ((ns.Errands.KIND_ICON or {})[e.kind] or "INV_Misc_Note_01"), e.text, function() ns.Errands:Go(e) end, "Sets the arrow to the nearest place for this." }
    end
    self.cards.town:Fill(items, "Nothing to do in town. You're good to go.")
    -- your trip
    items = {}
    local J = ns.Journey
    if J and J.goal then
      items[#items + 1] = { "Interface\\Icons\\INV_Misc_Map_01", "To " .. tostring(J.goal.name), function() J:Step("home") end, "Points the arrow at the next step again." }
      local st = J.route and J.route.steps and J.route.steps[1]
      if st then items[#items + 1] = { "Interface\\Icons\\Ability_Mount_Gryphon_01", tostring(st.text), nil, tostring(st.text) } end
      items[#items + 1] = { "Interface\\Buttons\\UI-GroupLoot-Pass-Up", "Stop this trip", function() J:Stop("home") p:Refresh() end }
    end
    self.cards.trip:Fill(items, "No trip planned. Press Find to plan one, or pick a place above.")
  end
end)

-- ------------------------------------------------------------ Waypoints
-- A grid of picture tiles (Gary, 2026-11-20: pages an 8th grader gets at a
-- glance): { {label, art, fallbackIcon, fn, tip}, ... }, used as a "custom" form row.
local function iconTiles(items, perRow)
  perRow = perRow or 6
  return function(host)
    local f = CreateFrame("Frame", nil, host)
    local TW, TH, GAP = 112, 76, 8
    f:SetSize(perRow * (TW + GAP), math.ceil(#items / perRow) * (TH + GAP))
    for i, it in ipairs(items) do
      local b = CreateFrame("Button", nil, f, ns.Theme:BackdropTemplate())
      b:SetSize(TW, TH)
      b:SetPoint("TOPLEFT", ((i - 1) % perRow) * (TW + GAP), -math.floor((i - 1) / perRow) * (TH + GAP))
      ns.Theme:ApplyPanel(b, "raised", "border")
      b.icon = b:CreateTexture(nil, "ARTWORK")
      b.icon:SetSize(36, 36)
      b.icon:SetPoint("TOP", 0, -8)
      if not (ns.Art and it[2] and ns.Art:Set(b.icon, it[2], "Interface\\Icons\\" .. (it[3] or "INV_Misc_QuestionMark"))) then
        b.icon:SetTexture("Interface\\Icons\\" .. (it[3] or "INV_Misc_QuestionMark"))
      end
      b.label = UI.Text(b, "normal", "text")
      b.label:SetPoint("BOTTOM", 0, 9)
      b.label:SetText(it[1])
      b:SetScript("OnClick", function() ns.Safe("tile:" .. it[1], it[4]) end)
      b:SetScript("OnEnter", function(self) ns.Theme:ApplyPanel(self, "hover", "gold") end)
      b:SetScript("OnLeave", function(self) ns.Theme:ApplyPanel(self, "raised", "border") end)
      UI.Tip(b, it[1], it[5] or ("Points the gold arrow at the nearest " .. it[1]:lower() .. "."))
    end
    return f
  end
end
ns.ClassPage = ns.ClassPage or {}
ns.ClassPage.IconTiles = iconTiles

-- The trainers that matter to this character (Gary, 2026-11-20: "waypoints
-- should have all the trainers ... anything relevant to the character"):
-- class trainer, weapon master, pet trainer for hunters, the cooking, first
-- aid and fishing trainers everyone can use, and one per profession learned.
local SECONDARY = { "Cooking", "First Aid", "Fishing" }
local function trainerTiles()
  local items = {}
  local cls = ns.PlayerClass and ns.PlayerClass() or ""
  local clsName = C.Readable(C.Call("UnitClass", "player")) or "Class"
  items[#items + 1] = { clsName .. " trainer", "class_" .. cls:lower(), "INV_Misc_Book_09", Run("near class"),
    "Your " .. clsName:lower() .. " trainer: new spells and ranks." }
  items[#items + 1] = { "Weapon master", "pin_weaponmaster", "INV_Sword_04", Run("near trainer weapon master"), "Learn to use more kinds of weapons." }
  if cls == "HUNTER" then
    items[#items + 1] = { "Pet trainer", "pin_pettrainer", "Ability_Hunter_BeastCall", Run("near trainer pet trainer"), "Pet skills for your pet." }
  end
  local profs, seen = {}, {}
  for name, d in pairs(ns.db.char.professions or {}) do
    if type(d) == "table" and d.skill then profs[#profs + 1] = name seen[name] = true end
  end
  table.sort(profs)
  for _, n in ipairs(SECONDARY) do if not seen[n] then profs[#profs + 1] = n end end
  local icons = ns.ProfExtras and ns.ProfExtras.PROF_ICON or {}
  for _, name in ipairs(profs) do
    items[#items + 1] = { name, "prof_" .. name:lower():gsub(" ", ""), icons[name] or "INV_Misc_Book_09",
      (function()
        local d = seen[name] and ns.db.char.professions[name]
        local need = d and ns.Nearest and ns.Nearest.NextRank(d.max)
        return function()
          local _, msg = ns.Nearest:Go("trainer:" .. name:lower() .. (need and (":" .. need) or ""))
          ns.Print(tostring(msg))
        end
      end)(),
      (seen[name] and "Your " or "Learn ") .. name:lower() .. (seen[name] and " trainer: the next rank and new recipes." or " here: anyone can.") }
  end
  return items
end

local function placeTiles()
  local hunter = ns.PlayerClass and ns.PlayerClass() == "HUNTER"
  local places = {
    { "Inn", "pin_inn", "INV_Misc_Rune_01", Run("near inn"), "The nearest inn: rest for bonus XP and set your hearthstone." },
    { "Vendor", "pin_vendor", "INV_Misc_Bag_10", Run("near vendor"), "The nearest vendor: sell junk, buy food and drink." },
    { "Repair", "pin_repair", "Trade_BlackSmithing", Run("near repair"), "The nearest place to repair your gear." },
    { "Flight", "pin_flight", "Ability_Mount_Gryphon_01", Run("near flight"), "The nearest flight master." },
    { "Mail", "pin_mail", "INV_Letter_15", Run("near mail"), "The nearest mailbox." },
    { "Bank", "pin_bank", "INV_Misc_Coin_02", Run("near bank"), "The nearest bank." },
    { "Auction", "pin_auction", "INV_Misc_Coin_01", Run("near ah"), "The nearest auction house." },
    { "Spirit healer", "pin_spirit", "Spell_Holy_Resurrection", Run("near spirit"), "The nearest spirit healer." },
  }
  -- stable and ammo only for the class that needs them
  if hunter then
    places[#places + 1] = { "Stable", "pin_stable", "Ability_Hunter_BeastCall", Run("near stable"), "The nearest stable master." }
    places[#places + 1] = { "Ammo", "pin_ammo", "INV_Ammo_Arrow_02", Run("near ammo"), "The nearest arrow and bullet vendor." }
  end
  return places
end
ns.ClassPage.PlaceTiles, ns.ClassPage.TrainerTiles = placeTiles, trainerTiles

ns.Hub:AddTab("waypoints", "Waypoints", function(p)
  local places, trainers = placeTiles(), trainerTiles()
  local rows = function(n) return math.ceil(n / 6) * 84 + 4 end
  UI:FormPage(p, {
    { "header", "Your arrow" },
    -- where the arrow points, at a glance (premium rebuild 2026-11-18)
    { "stats", function()
      local W = ns.Waypoints
      local w = W.current
      local d = w and W:Distance()
      local q = W:Settings().queue or {}
      return {
        { cap = "Arrow to", value = w and tostring(w.title or "a spot") or "Nothing", color = w and "gold" or nil },
        { cap = "Distance", value = d and (math.floor(d + 0.5) .. " yd") or "—" },
        { cap = "Queued stops", value = tostring(#q), note = #q > 0 and "the arrow moves on by itself" or "none" },
      }
    end },
    { "note", function()
      local w = ns.Waypoints.current
      return w and ("Arrow to " .. tostring(w.title) .. ", " .. tostring(ns.Waypoints:Activity())) or "No waypoint set."
    end },
    { "buttons", { { "Clear arrow", Run("way clear") }, { "Say my coordinates", Run("coords") } } },
    { "header", "Take me to the nearest..." },
    { "note", "Press a place: the gold arrow points to the closest one Outrider knows. Follow it; it clears when you arrive." },
    -- picture tiles (Gary, 2026-11-20): the map-pin pictures, one press each
    { "custom", iconTiles(places, 6), rows(#places) },
    { "header", "Your trainers" },
    { "note", "Every trainer that matters to you, nearest first when you press one. A trainer Outrider hasn't seen yet says so: talk to one once, or stand next to it." },
    { "custom", iconTiles(trainers, 6), rows(#trainers) },
    { "header", "Go to map coordinates" },
    { "note", "Got coordinates from a quest or a friend, like 45.2 61.8? Type them here." },
    { "input", "Coordinates (x y)", "45.2 61.8", "Set arrow", function(t) ns.Slash:Run("way " .. t) end },
    { "check", "Arrow to the spirit healer when you die", function() return set("Nearest").spiritOnDeath end,
      function(on) set("Nearest").spiritOnDeath = on end },
  })
end)

-- ---------------------------------------------------------- Rare alerts
ns.Hub:AddTab("rarealerts", "Rare alerts", function(p)
  local function watched()
    local out = {}
    for k in pairs(set("RareScan").watch or {}) do out[#out + 1] = k end
    table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
    return out
  end
  UI:FormPage(p, {
    { "header", "Watch list" },
    { "input", "Watch a rare", "Mystmane, or an NPC id", "Watch", function(t) ns.Slash:Run("watch " .. t) end },
    { "note", "Click a name to stop watching it." },
    { "list", 5, function(row, k) row.text:SetText(ns.TitleCase(tostring(k))) end,
      function(k) ns.Slash:Run("unwatch " .. tostring(k)) p:Refresh() end, watched,
      empty = "No rare on your watch list. Type a name above and press Watch." },
    { "header", "Timers" },
    { "note", function() return ns.RareTimer and ns.RareTimer:Activity() or "" end, 36 },
    { "header", "How you're told" },
    { "check", "Sound", function() return set("RareAlerts").sound end, function(on) set("RareAlerts").sound = on end },
    { "check", "Pop-up", function() return set("RareAlerts").toast end, function(on) set("RareAlerts").toast = on end },
    { "check", "Only rares on your watch list", function() return set("RareAlerts").mode == "watch" end,
      function(on) set("RareAlerts").mode = on and "watch" or "all" end },
    { "header", "Recently met" },
    { "buttons", { { "Last 10 NPCs met", Run("discovered 10") }, { "Rares tab", function() ns.Hub.frame.tabBar:Select("rares") end } } },
  })
end)

-- ------------------------------------------------------------ Class page
-- One page named after the character's class (Gary, 2026-11-13: "class aware,
-- dynamic, relevant to the character being played"). A hunter sees hunter
-- tools only, a mage mage tools only. Sections appear when the class has them.
local CLASS_ICON = "Interface\\Icons\\ClassIcon_"
local CLASS_NAME = { WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
  SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid" }
local KEY_NOTE = {
  HUNTER = "Fight (ranged), Strike (melee) and Pet (care) follow your spellbook and ranged weapon.",
  MAGE = "Fight (Frostbolt) and Strike (close: Frost Nova, Fire Blast, Arcane Explosion) follow your spellbook.",
  PRIEST = "Fight (Shadow Word: Pain once, Mind Blast, Smite) and Heal follow your spellbook.",
  WARRIOR = "Fight on key 1 (Charge, Shout, Rend, big strike, Heroic Strike); Strike on key 2 (Overpower, Execute, Thunder Clap).",
  ROGUE = "Fight (Stealth, an opener from Stealth, Sinister Strike, Slice and Dice, Eviscerate), Pull (Throw or your bow) and Strike (Stealth, then Pick Pocket; Evasion and Kick in a fight).",
  WARLOCK = "Fight on key 1 (demon, curse, dots once, Drain Life or wand); Strike on key 2 (Life Tap, Shift: Fear).",
  DRUID = "Fight on key 1 follows your form (caster, Bear, Cat); Heal on key 2 (Swipe, Tiger's Fury or a heal).",
  PALADIN = "Fight on key 1 (Blessing, Aura, Seal and Judgement, Holy Strike); Heal on key 2 (Holy Light).",
  SHAMAN = "Fight on key 1 (imbue, Shield, bolt, totem, shocks, Stormstrike); Heal on key 2 (Healing Wave).",
}

-- Spells your class trainer teaches (Data/SpellInfo.lua, the client's
-- spellbook pages; talents left out): ready now (your level, not known yet)
-- and the next two levels that bring something new.
local function trainerSpells(cls)
  -- what your trainer showed you is the truth (Gary, 2026-11-21); the typed-in
  -- spell table is only a fallback until you've opened your trainer once
  if ns.Spellbook and ns.Spellbook.TrainerLists and (not cls or cls == (ns.PlayerClass and ns.PlayerClass())) then
    local now, soon, nextLevel, any = ns.Spellbook:TrainerLists()
    if any then return now, soon, nextLevel, "trainer" end
  end
  local info = ns.SpellInfo and ns.SpellInfo[cls or ""] or {}
  local level = tonumber(C.Readable(C.Call("UnitLevel", "player"))) or 1
  local now, later = {}, {}
  for name, sp in pairs(info) do
    if type(sp) == "table" and sp.level and not sp.tree then
      local known = ns.Spellbook and ns.Spellbook:Known(name)
      if sp.level <= level and not known then now[#now + 1] = { name = name, level = sp.level, icon = sp.icon }
      elseif sp.level > level then later[#later + 1] = { name = name, level = sp.level, icon = sp.icon } end
    end
  end
  local byName = function(a, b) if a.level ~= b.level then return a.level < b.level end return a.name < b.name end
  table.sort(now, byName)
  table.sort(later, byName)
  local soon, levels = {}, {}
  for _, sp in ipairs(later) do
    if not levels[sp.level] then levels[sp.level] = true levels[#levels + 1] = sp.level end
    if #levels <= 2 then soon[#soon + 1] = sp end
  end
  return now, soon, levels[1], "estimate"
end
ns.ClassPage = ns.ClassPage or {}
ns.ClassPage.TrainerSpells = trainerSpells

-- a spell icon: a file ID or full path (from the trainer) or an icon name (typed data)
local function iconPath(icon, fallback)
  if type(icon) == "number" then return icon end
  if type(icon) == "string" and (icon:find("\\", 1, true) or icon:find("/", 1, true)) then return icon end
  return "Interface\\Icons\\" .. tostring(icon or fallback or "INV_Misc_QuestionMark")
end

local function spellChips(list, max)
  local out = {}
  for i, sp in ipairs(list) do
    if i > (max or 6) then break end
    out[#out + 1] = { icon = "Interface\\Icons\\" .. tostring(sp.icon or "INV_Misc_QuestionMark"), text = sp.name .. "  |cff8f96a6" .. sp.level .. "|r",
      tip = sp.name .. " (level " .. sp.level .. ")" }
  end
  return out
end

local function classRows(cls, page)
  local rows = {}
  local function r(t) rows[#rows + 1] = t end
  local F = function() return set("HunterFight") end
  local function opt(key) return function(on) ns.Slash:Run("fight " .. key .. " " .. onoff(on)) end end
  local fight = ns.HunterFight and ns.HunterFight:Supported()
  -- at a glance: level, talent points, spells waiting at the trainer (Gary, 2026-11-20)
  r({ "stats", function()
    local now, _, nextLevel = trainerSpells(cls)
    local level = tonumber(C.Readable(C.Call("UnitLevel", "player"))) or 1
    local pts = tonumber(C.Readable(C.Call("UnitCharacterPoints", "player"))) or 0
    return {
      { cap = "Level", value = tostring(level), color = "text" },
      { cap = "Spells to learn now", value = tostring(#now), color = #now > 0 and "good" or "text",
        note = #now > 0 and "visit your class trainer" or "you're up to date" },
      { cap = "Next new spell", value = nextLevel and ("level " .. nextLevel) or "none", color = "gold" },
      { cap = "Talent points", value = level < 10 and "at 10" or tostring(pts), color = pts > 0 and "good" or "text",
        note = pts > 0 and "press N to spend them" or nil },
    }
  end })
  r({ "header", "Spells from your trainer" })
  r({ "cards", function()
    local now, soon, _, from = trainerSpells(cls)
    local out = {}
    if from ~= "trainer" then
      out[#out + 1] = { title = "Open your class trainer once", pic = "Interface\\Icons\\INV_Misc_Book_09", tags = { { "estimate", "warn" } },
        line = "Until you've talked to your trainer, this list is a guess. Talk to them once and Outrider shows exactly what they teach, with ranks.",
        actions = { { "Arrow to trainer", function() ns.Slash:Run("near class") end, "Points the gold arrow at the nearest class trainer." } } }
    end
    if #now > 0 then
      out[#out + 1] = { title = string.format("%d new spell%s ready to learn", #now, #now == 1 and "" or "s"), highlight = true,
        pic = "Interface\\Icons\\" .. tostring(now[1].icon or "INV_Misc_Book_09"),
        line = from == "trainer" and "From your trainer's own list: you can learn these now." or "Your class trainer should teach these now.",
        chips = spellChips(now, 6), tags = { { "ready now", "gold" } },
        actions = { { "Arrow to trainer", function() ns.Slash:Run("near class") end, "Points the gold arrow at your nearest class trainer." } } }
    else
      out[#out + 1] = { title = "You know every spell for your level", pic = "Interface\\Icons\\INV_Misc_Book_09",
        line = "Nothing to learn right now. Come back when you reach the level below." }
    end
    if #soon > 0 then
      out[#out + 1] = { title = "Coming next", pic = "Interface\\Icons\\" .. tostring(soon[1].icon or "INV_Misc_Book_09"),
        line = string.format("At level %d%s.", soon[1].level, soon[#soon].level ~= soon[1].level and (" and " .. soon[#soon].level) or ""),
        chips = spellChips(soon, 6) }
    end
    return out
  end })
  if fight then
    r({ "header", "Your fight keys" })
    r({ "note", "Put these on your action bar and press them in every fight: Outrider keeps them up to date. " .. (KEY_NOTE[cls] or "") })
    r({ "buttons", { { "Make or show the macros", Run("fight") }, { "Open macro window", function()
      if C.Call("ShowMacroFrame") == nil then C.Call("MacroFrame_LoadUI") C.Call("ShowMacroFrame") end end } } })
    if cls == "HUNTER" then
      r({ "check", "Concussive Shot in Fight", function() return F().concussive end, opt("concussive") })
      r({ "check", "Wing Clip in Strike", function() return F().wingclip end, opt("wingclip") })
      r({ "check", "Send the pet in", function() return F().pet end, opt("pet") })
    end
    r({ "check", "Rewrite when you learn a spell", function() return F().auto end, opt("auto") })
  end
  if cls == "HUNTER" then
    r({ "header", "Taming" })
    r({ "input", "Tame macro for", "Mystmane", "Make macro", function(t) ns.Slash:Run("tamemacro " .. t) end })
    r({ "note", "Press: send the pet in. Shift-press: dismiss it. Press again: Tame Beast." })
    r({ "input", "Trap tame macro for", "Mystmane", "Make trap macro", function(t) ns.Slash:Run("tamemacro trap " .. t) end })
    r({ "note", "No pet out. Press: Freezing Trap. Press: Concussive Shot pulls her onto it. Then press to tame; if it breaks, press for Wing Clip, press to tame again. Shift: a new trap." })
    r({ "header", "Pet and ammo" })
    r({ "check", "Show the pet panel", function() return set("PetStatus").show end,
      function(on) if ns.PetStatus then ns.PetStatus:SetPanel(on) end end })
    r({ "note", function() local m = mod("PetStatus") return m and m.enabled and m:Activity() or "" end })
    r({ "note", function() local m = mod("Ammo") return m and m.enabled and m:Activity() or "" end })
  end
  -- click-to-heal bars (Modules/HealPanel.lua)
  local HP = ns.HealPanel
  if HP and HP.spec.classes[cls or ""] then
    r({ "header", "Heal bars" })
    r({ "note", function() return HP:Summary() end })
    r({ "check", "Show the heal bars in a group", function() return set("HealPanel").show ~= "off" end,
      function(on) ns.Slash:Run("heal " .. (on and "group" or "off")) end })
    if cls ~= "HUNTER" then
      r({ "check", "Keep my own bar when players are assigned", function() return set("HealPanel").withSelf end,
        function(on) ns.Slash:Run("heal self " .. onoff(on)) end })
      r({ "note", "Assigned to you: click a name (out of combat). With anyone assigned, only they get bars." })
      r({ "list", 6, function(row, name)
        row.text:SetText((HP:IsAssigned(name) and "|cffffd100[assigned]|r " or "[ ] ") .. name)
      end, function(name)
        HP:Assign(name, not HP:IsAssigned(name))
        if page and page.Refresh then page:Refresh() end
      end, function() return HP:Members() end })
    end
  end
  -- talent advisor (Modules/Talents.lua)
  local Tal = ns.Talents
  if Tal and #Tal.Builds(cls) == 0 then
    -- no sourced build for this class yet: one honest line, no empty plan box
    -- and no switches for rings that never show (tour 2026-11-19, Rogue page)
    r({ "header", "Talents" })
    r({ "note", "From level 10 you get a talent point each level: press N to open the talent window and spend it. Outrider has no tested levelling build for your class yet, so it doesn't suggest one (it never makes builds up)." })
  elseif Tal then
    r({ "header", "Talents" })
    r({ "note", function()
      local b = Tal:Build()
      if not b then return "No levelling build for your class yet." end
      return string.format("%s. %s\n|cff888888%s, from %s; not yet checked in game.|r", Tal:Summary(), b.note or "", b.name, b.source)
    end })
    r({ "note", "The plan, from your next point: gold = spend now, grey = later. In the talent window the gold rings show where." })
    r({ "list", 8, function(row, st)
      local tag = st.next and "|cffffd100now|r" or (st.locked and "|cffff6060row not open|r") or (st.missing and "|cffff6060not on this client|r") or ("level " .. st.level)
      row.text:SetText(string.format("%d. %s  %s", st.level, Tal.StepText(st), tag))
    end, nil, function()
      local out = {}
      for _, st in ipairs((Tal:Current()).steps) do if not st.done then out[#out + 1] = st end end
      return out
    end })
    local builds = Tal.Builds(cls)
    if #builds > 1 then
      local btns = {}
      for _, bd in ipairs(builds) do btns[#btns + 1] = { bd.name, function() ns.Slash:Run("talents build " .. bd.id) end } end
      r({ "buttons", btns })
    end
    r({ "check", "Gold rings in the talent window", function() return set("Talents").highlight end,
      function(on) ns.Slash:Run("talents " .. onoff(on)) end })
    r({ "check", "Tell me in chat when a point is ready", function() return set("Talents").notify end,
      function(on) set("Talents").notify = on end })
  end
  r({ "header", "More keys for your class" })
  r({ "note", "The Macros page has every ready-made key for your class, by level: Stop, Save, Burst, Recover and Team, and one-spell keys. Drag them to your bar." })
  r({ "buttons", { { "Open Macros", function() ns.Hub.frame.tabBar:Select("macros") end } } })
  if not fight then
    r({ "note", "Fight macros that follow your spellbook exist for hunters, mages and priests so far." })
  end
  return rows
end

do
  local cls = ns.PlayerClass and ns.PlayerClass() or nil
  ns.Hub:AddTab("class", CLASS_NAME[cls or ""] or "Class", function(p)
    UI:FormPage(p, classRows(ns.PlayerClass(), p))
  end, nil, { icon = cls and (CLASS_ICON .. (CLASS_NAME[cls] or "")) or nil })
end

-- -------------------------------------------------------------- Gear sets
ns.Hub:AddTab("gearsets", "Gear sets", function(p)
  local function sets()
    local out = {}
    for name in pairs(set("GearSets").sets or {}) do out[#out + 1] = name end
    table.sort(out)
    return out
  end
  UI:FormPage(p, {
    { "header", "Gear sets" },
    { "input", "Save what you wear as", "Questing", "Save", function(t) ns.Slash:Run("gear save " .. t) end },
    { "note", "Click a set to put it on (out of combat). Delete removes it." },
    { "list", 6, function(row, name) row.text:SetText(name) end, function(name) ns.Slash:Run("gear " .. name) end, sets,
      empty = "No gear sets saved yet. Type a name above and press Save." },
    { "input", "Delete set", "Questing", "Delete", function(t) ns.Slash:Run("gear delete " .. t) end },
    { "header", "How gear is scored" },
    { "buttons", { { "Show my stat weights", Run("weights") }, { "Upgrades in this zone", Run("nearby") } } },
    { "input", "Compare an item", "Shift-click an item here", "Compare", function(t) ns.Slash:Run("score " .. t) end },
  })
end)

-- ------------------------------------------------------------ Professions
-- Only the professions this character has (sections appear as you learn them;
-- the page is rebuilt at the next login).
local function profRows()
  local owned = ns.Crafter and ns.Crafter:Owned() or {}
  local function make(prof) return function() if ns.Crafter then ns.Crafter:Make(prof) end end end
  local rows = {}
  local function r(t) rows[#rows + 1] = t end
  -- a skill bar per profession you have (premium rebuild 2026-11-18)
  r({ "stats", function()
    local out = {}
    for name, d in pairs(ns.db.char.professions or {}) do
      if type(d) == "table" and d.skill then
        out[#out + 1] = { cap = name, value = d.skill .. " / " .. tostring(d.max or "?"), color = "gold",
          fill = d.max and d.max > 0 and d.skill / d.max or nil }
      end
    end
    table.sort(out, function(x, y) return x.cap < y.cap end)
    return out
  end })
  -- each profession in plain words: where it stands and what to do next (Gary, 2026-11-20)
  r({ "header", "What to do next" })
  r({ "cards", function()
    local out = {}
    local GATHER = { Herbalism = "pick herbs", Mining = "mine ore", Skinning = "skin beasts you kill", Fishing = "fish" }
    local icons = ns.ProfExtras and ns.ProfExtras.PROF_ICON or {}
    local names = {}
    for name, d in pairs(ns.db.char.professions or {}) do if type(d) == "table" and d.skill then names[#names + 1] = name end end
    table.sort(names)
    for _, name in ipairs(names) do
      local d = ns.db.char.professions[name]
      local skill, max = tonumber(d.skill) or 0, tonumber(d.max) or 0
      local line, tag, act
      if max > 0 and skill >= max then
        line = string.format("You've reached the most this rank allows (%d). Visit a %s trainer to learn the next rank and keep going.", max, name:lower())
        tag = { "visit a trainer", "gold" }
        -- a trainer who teaches the rank you need next, not just any (2026-11-21)
        local which, need = name:lower(), ns.Nearest and ns.Nearest.NextRank(max)
        local RANKS = { "Apprentice", "Journeyman", "Expert", "Artisan" }
        act = { { "Arrow to trainer", function()
          local _, msg = ns.Nearest:Go("trainer:" .. which .. (need and (":" .. need) or ""))
          ns.Print(tostring(msg))
        end, "Points the gold arrow at the nearest " .. which .. " trainer who teaches " .. (RANKS[need or 0] or "the next rank") .. "." } }
      elseif GATHER[name] then
        line = string.format("Raise it by doing it: %s. Harder ones give more skill as you go.", GATHER[name])
      else
        line = "Raise it by making things: the craft button and the training button below pick the best recipe for you."
      end
      local artName = "prof_" .. name:lower():gsub(" ", "")
      out[#out + 1] = { title = string.format("%s  %d / %d", name, skill, max), pic = "Interface\\Icons\\" .. (icons[name] or "INV_Misc_Book_09"),
        art = (ns.Art and ns.Art:Has(artName)) and artName or nil,
        line = line, tags = tag and { tag } or nil, actions = act, highlight = tag ~= nil }
    end
    if #out == 0 then
      out[1] = { title = "No professions yet", pic = "Interface\\Icons\\INV_Misc_Book_09",
        line = "Professions let you make or gather things to use and sell. Visit a profession trainer in a city to learn one." }
    end
    return out
  end })
  local crafts = {}
  if owned.Cooking then crafts[#crafts + 1] = { "Cook", make("Cooking") } end
  if owned.Alchemy then crafts[#crafts + 1] = { "Brew", make("Alchemy") } end
  if #crafts > 0 then
    r({ "header", "Craft in one click" })
    r({ "note", "Press it: Outrider makes the recipe that raises your skill most with what's in your bags, as many as you can. For cooking, stand next to a fire." })
    crafts[#crafts + 1] = { "Make bar macros", Run("make") }
    r({ "buttons", crafts })
  end
  -- One-button training for every crafting profession this character has.
  local T = ns.ProfTrainer
  local crafting = T and T.Professions and T:Professions() or {}
  if #crafting > 0 then
    r({ "header", "Skill-up button" })
    r({ "note", "When your bags hold enough to gain about 10 skill, a button pops up on your screen. Press it again and again: each press makes the next recipe that still gives skill (for cooking it builds a fire first)." })
    r({ "check", "Show the training button", function() return set("ProfTrainer").show end,
      function(on) set("ProfTrainer").show = on if T then T:Evaluate() end end })
    r({ "key", "Training key", function() return set("ProfTrainer").key end,
      function(k) if T then T:SetKey(k) end end, "presses the button while it shows" })
    for _, prof in ipairs(crafting) do
      r({ "check", "Offer " .. prof, function() return not (set("ProfTrainer").off or {})[prof] end,
        function(on)
          local s = set("ProfTrainer")
          s.off = s.off or {}
          s.off[prof] = (not on) or nil
          if T then T:Evaluate() end
        end })
    end
    r({ "note", function() local m = mod("ProfTrainer") return m and m.enabled and m:Activity() or "" end, 36 })
  end
  if next(owned) then
    -- the example is one of your own crafts (tour 2026-11-19: it said Alchemy to a leatherworker)
    local example
    for _, prof in ipairs({ "Leatherworking", "Tailoring", "Blacksmithing", "Engineering", "Alchemy", "Enchanting", "Cooking", "First Aid" }) do
      if owned[prof] then example = prof .. " 75" break end
    end
    if example then
      r({ "header", "Plan to a goal" })
      r({ "note", "Type a profession and the skill you want to reach, like the example. Outrider lists what to make and what to buy, cheapest first." })
      r({ "input", "Profession and target", example, "Plan", function(t) ns.Slash:Run("skillup " .. t) end, true })
    end
  end
  if owned.Herbalism then
    r({ "header", "Herbalism" })
    r({ "buttons", { { "Where each herb grows", Run("herbs") } } })
    r({ "note", function() local m = mod("HerbHelper") return m and m.enabled and m:Activity() or "" end })
  end
  if not next(owned) then
    r({ "header", "Professions" })
    r({ "note", "No professions yet. Visit a trainer; their tools appear here once you've learned one." })
  end
  -- trainer list, skill-up chance, craft cooldowns, profitable crafts, undercuts (gap analysis 2026-11-17)
  if ns.ProfExtras then
    local ok, extra = pcall(ns.ProfExtras.PageRows, ns.ProfExtras)
    for _, row in ipairs(ok and extra or {}) do r(row) end
  end
  return rows
end

ns.Hub:AddTab("professions", "Professions", function(p)
  UI:FormPage(p, profRows())
end)

-- ----------------------------------------------------------------- Money
-- Best ways to earn at this level and with these professions (MoneyGuide).
local function moneyRows()
  local G = ns.MoneyGuide
  local rows = {}
  local function r(t) rows[#rows + 1] = t end
  if not (G and G.enabled) then
    r({ "header", "Money" })
    r({ "note", "The Money guide module is off (Modules tab in Settings)." })
    return rows
  end
  local level = ns.Compat.Call("UnitLevel", "player") or 1
  r({ "header", "Money" })
  r({ "stats", function()
    local L, F = ns.Ledger, ns.Forecasts
    local net, perHour = 0, 0
    if L and L.Summary then net, perHour = L:Summary() end
    local g = F and F.Gold and F.Gold(ns.db.char.ledger)
    local coins = ns.Prices.Coins
    return {
      { cap = "Gold", value = coins(tonumber(ns.Compat.Readable(ns.Compat.Call("GetMoney"))) or 0), color = "gold" },
      { cap = "This session", value = (net < 0 and "-" or "+") .. coins(math.abs(net)), color = net > 0 and "good" or net < 0 and "bad" or nil },
      { cap = "Usual per hour", value = g and coins(math.floor(math.abs(g.perHour))) or "—",
        note = g and (g.sessions .. " sessions" .. (g.trend and (", " .. g.trend) or "")) or "log out once to start" },
    }
  end })
  r({ "header", "Best ways to earn at level " .. level })
  r({ "note", "Ranked for your level and professions. Guide numbers are early Forever reports (unverified); after 15 minutes of a kind of earning your own gold per hour replaces them." })
  local ranked = G:Rank(level)
  r({ "cards", function()
    local out = {}
    for i, x in ipairs(G:Rank(level)) do
      if i > 8 then break end
      local e = x.entry
      local actions = {}
      for z = 1, math.min(#(e.zones or {}), 2) do
        local zone = e.zones[z]
        actions[#actions + 1] = { "Find " .. zone, function() ns.Hub:Search(zone) end, "Finds " .. zone .. " on the Find page." }
      end
      -- a picture per way of earning when installed (money_mob, money_skin...), else the gold one
      local cat = type(e.category) == "table" and e.category[1] or e.category
      local own = cat and ns.Art and ns.Art:Has("money_" .. tostring(cat)) and ("money_" .. tostring(cat)) or "kind_gold"
      out[#out + 1] = { art = own, pic = "Interface\\Icons\\INV_Misc_Coin_02", title = e.title,
        tags = { { G.RateText(x), "gold" } }, line = (e.how or "") .. "  |cff888888(" .. tostring(e.source) .. ")|r",
        actions = actions, highlight = i == 1 }
    end
    return out
  end })
  if #ranked == 0 then r({ "note", "No tips for this level yet." }) end
  if ns.Favor and ns.Favor.enabled then
    r({ "header", "Merchant's Favor and crates" })
    r({ "note", function() return table.concat(ns.Favor:Lines(), "\n") end, 80 })
  end
  r({ "header", "Crafting for profit" })
  r({ "note", function() return table.concat(G:ProfitLines(5), "\n") end, 110 })
  r({ "header", "Your own earnings" })
  r({ "note", function()
    local lines = G:YourLines()
    return #lines > 0 and table.concat(lines, "\n") or "Nothing yet: loot, gather, skin or fish and Outrider adds up what it's worth."
  end, 80 })
  r({ "note", "Prices: auction price less 5% when Outrider has seen one (open the auction house now and then), else the vendor price." })
  -- selling at the auction house (moved from Professions, 2026-11-20 layout)
  r({ "header", "Selling at the auction house" })
  r({ "input", "Undercut by", "2% or 50c", "Set", function(t) ns.Slash:Run("undercut " .. t) end })
  r({ "note", function() local s = set("AuctionHelper") return "Your listings go this far under the cheapest one. Now: " .. (s.undercutCopper and (s.undercutCopper .. " copper") or ((s.undercutPct or 2) .. "%")) end })
  return rows
end

ns.Hub:AddTab("money", "Money", function(p)
  UI:FormPage(p, moneyRows())
end)

-- ------------------------------------------------------------- Dungeons
-- Ready now, best upgrades per dungeon, and the next tier (DungeonGuide).
local function dungeonRows()
  local D = ns.DungeonGuide
  local rows = {}
  local function r(t) rows[#rows + 1] = t end
  if not (D and D.enabled) then
    r({ "header", "Dungeons" })
    r({ "note", "The dungeon guide module is off (Modules tab in Settings)." })
    return rows
  end
  if not D:Pack() then
    r({ "header", "Dungeons" })
    r({ "note", "The dungeon data pack (Outrider_Data_Dungeons) isn't installed." })
    return rows
  end
  D:Warm()
  local level = ns.Compat.Call("UnitLevel", "player") or 1
  r({ "header", "Dungeons" })
  r({ "buttons", { { "Open dungeon journal", function()
    if ns.DungeonJournal then ns.DungeonJournal:Toggle()
    else ns.Print("Dungeon Journal module is disabled") end
  end, 210, "Browse bosses, loot, dungeon quests, readiness and entrances." } } })
  -- Ready check: a tile per check, green or red (premium look, 2026-11-16)
  r({ "header", "Ready check", icon = "INV_Misc_Book_08" })
  r({ "tiles", function()
    local out = {}
    for _, c in ipairs(D:ReadyCheck()) do
      local t = c.text:lower()
      local icon = t:find("repair") and "Trade_BlackSmithing" or t:find("food") and "INV_Misc_Food_15"
        or t:find("drink") and "INV_Drink_07" or t:find("bag") and "INV_Misc_Bag_08" or t:find("ammo") and "INV_Ammo_Arrow_02"
        or "INV_Misc_Note_01"
      out[#out + 1] = { ok = c.ok, text = c.text, icon = "Interface\\Icons\\" .. icon }
    end
    return out
  end })
  r({ "buttons", { { "Share with my party", function()
    local ok, why = D:ShareReady()
    ns.Print(ok and "ready check sent to your party" or ("not sent: " .. tostring(why or "sharing failed")))
  end, 180 } } })
  r({ "note", function() return D:PartyText() end })
  local function slug(name) return "dungeon_" .. name:lower():gsub("[^%w]", "") end
  local function chips(ups, later, n)
    local out = {}
    for _, u in ipairs(ups) do
      if (u.later and true or false) == (later and true or false) then
        out[#out + 1] = { itemID = u.itemID, text = string.format("|cff7fff7f%s|r %s", ns.GearScore.UpText(u.pct), tostring(u.name)),
          note = (u.boss and ("Drops from " .. u.boss) or "") .. (u.later and (", usable at " .. u.reqLevel) or "") }
        if #out >= (n or 3) then break end
      end
    end
    return out
  end
  local function cardFor(x, kind)
    local tags = { { string.format("Levels %d-%d", x.info.min, x.info.max), "plain" },
      { x.info.raid and (x.info.size .. "-player raid") or "5-player", "plain" } }
    if x.info.new then tags[#tags + 1] = { "New on Forever", "gold" } end
    local line, chipList
    if kind == "next" then
      tags[#tags + 1] = { "Next tier", "warn" }
      line = string.format("%d upgrades waiting once you're a little higher.", x.laterCount)
      chipList = chips(x.ups, true, 3)
    elseif x.status == "soon" then
      tags[#tags + 1] = { "Soon", "warn" }
      line = string.format("%d upgrades for you once you're closer to level %d.", x.laterCount, x.info.min)
      chipList = chips(x.ups, true, 3)
    elseif x.count == 0 then
      line = "Nothing here beats what you wear."
      chipList = {}
    else
      line = string.format("%d upgrades for you now:", x.count)
      chipList = chips(x.ups, false, 3)
    end
    return { art = slug(x.name), pic = "Interface\\Icons\\INV_Misc_Key_14", title = x.name, tags = tags, line = line,
      chips = chipList, highlight = kind == "next",
      actions = { { "Go to the entrance", function() D:Go(x) end, "Sets the arrow to the dungeon's entrance." } } }
  end
  r({ "header", "Next tier", icon = "INV_Chest_Plate06" })
  r({ "cards", function()
    local n = D:NextTier()
    return n and { cardFor(n, "next") } or {}
  end })
  r({ "note", function() return D:NextTier() and "" or "No upcoming dungeon with gear for you in the next few levels." end })
  r({ "header", "Ready now (level " .. level .. ")", icon = "INV_Misc_Key_14" })
  r({ "cards", function()
    local out = {}
    for _, x in ipairs(D:Rank()) do if x.status == "ready" then out[#out + 1] = cardFor(x) end end
    return out
  end })
  r({ "note", function()
    for _, x in ipairs(D:Rank()) do if x.status == "ready" then return "" end end
    return "No dungeon in your level range yet."
  end })
  r({ "header", "Coming up", icon = "INV_Misc_PocketWatch_01" })
  r({ "cards", function()
    -- the next tier is already its own card above: not twice (tour 2026-11-19)
    local out, nxt = {}, D:NextTier()
    for _, x in ipairs(D:Rank()) do
      if x.status == "soon" and not (nxt and nxt.name == x.name) then out[#out + 1] = cardFor(x) end
    end
    return out
  end })
  r({ "note", "Upgrades are scored for your class against what you wear. Hover an item for its tooltip. Level ranges and loot are community data, not yet checked in game." })
  return rows
end

ns.Hub:AddTab("dungeons", "Dungeons", function(p)
  UI:FormPage(p, dungeonRows())
end)

-- ------------------------------------------------------------- What now?
-- Pathfinder Lite in the Expedition look (Gary's concept picture, 2026-11-15):
-- page title in the display font, goal chips with icons, step cards with a
-- picture, Go / Details / Not useful, and a side column with errands, rare
-- watch, this session and a character snapshot. Pictures come from ns.Art
-- (Gary's custom art when installed, game icons until then). No made-up
-- numbers: confidence shows as Unchecked / Guess, never as a percentage.
local CARD_H, CARD_GAP, SIDE_W, TOP, PIC, BTN_W = 116, 8, 224, 104, 76, 124
local GOAL_ICON = {
  level = "Interface\\Icons\\INV_Misc_Book_09", gold = "Interface\\Icons\\INV_Misc_Coin_02",
  gear = "Interface\\Icons\\INV_Shield_06", professions = "Interface\\Icons\\Trade_BlackSmithing",
  explore = "Interface\\Icons\\INV_Misc_Map_01", mix = "Interface\\Icons\\Spell_Holy_HolyBolt",
}

local function wrap(fs, lines)
  if fs.SetWordWrap then fs:SetWordWrap(lines > 1) end
  if fs.SetMaxLines then pcall(fs.SetMaxLines, fs, lines) end
  if fs.SetJustifyH then fs:SetJustifyH("LEFT") end
  if fs.SetJustifyV then fs:SetJustifyV("TOP") end
end

local function details(owner, s)
  local tip = rawget(_G, "GameTooltip")
  if not (tip and s) then return end
  tip:SetOwner(owner, "ANCHOR_LEFT")
  tip:AddLine(s.title or "", 1, 0.82, 0.3)
  if s.why then tip:AddLine(s.why, 0.85, 0.85, 0.85, true) end
  if s.where then tip:AddLine("Where: " .. s.where, 0.7, 0.7, 0.7, true) end
  if s.seconds and ns.Travel then tip:AddLine("Trip: about " .. ns.Travel.Minutes(s.seconds), 0.7, 0.7, 0.7) end
  if s.caveat then tip:AddLine(s.caveat, 1, 0.78, 0.3, true) end
  if s.alt then tip:AddLine("Or: " .. tostring(s.alt.text), 0.7, 0.7, 0.7, true) end
  tip:AddLine(string.format("Score %.2f (benefit %.2f, data %s)", s.score or 0, s.benefit or 0,
    (s.confidence or 1) >= 0.7 and "fairly sure" or "unchecked"), 0.5, 0.5, 0.5)
  tip:Show()
end

local function stepCard(parent, i, W, p)
  local c = UI:Card(parent, i == 1)
  c:SetHeight(CARD_H)
  if i == 1 and c.SetBackdropBorderColor then c:SetBackdropBorderColor(Theme:Color("gold")) end
  -- picture with a thin gold-grey frame
  c.frame = CreateFrame("Frame", nil, c, Theme:BackdropTemplate())
  c.frame:SetSize(PIC + 4, PIC + 4)
  c.frame:SetPoint("LEFT", 12, 0)
  Theme:ApplyPanel(c.frame, "bg", "strong")
  c.pic = c.frame:CreateTexture(nil, "ARTWORK")
  c.pic:SetPoint("TOPLEFT", 2, -2)
  c.pic:SetPoint("BOTTOMRIGHT", -2, 2)
  local left = PIC + 28
  c.title = UI.Display(c, "card", "text")
  c.title:SetPoint("TOPLEFT", left, -12)
  wrap(c.title, 1)
  c.tag = UI:Tag(c, "Unchecked", "plain")
  c.tag:SetPoint("LEFT", c.title, "RIGHT", 10, 0)
  c.why = UI.Text(c, "normal", "body")
  c.why:SetPoint("TOPLEFT", left, -38)
  c.why:SetPoint("RIGHT", c, "RIGHT", -(BTN_W + 24), 0)
  c.why:SetHeight(30)
  wrap(c.why, 2)
  c.where = UI.Text(c, "small", "muted")
  c.where:SetPoint("TOPLEFT", left, -72)
  c.where:SetPoint("RIGHT", c, "RIGHT", -(BTN_W + 24), 0)
  wrap(c.where, 1)
  c.alt = CreateFrame("Button", nil, c)
  c.alt:SetHeight(16)
  c.alt:SetPoint("TOPLEFT", left, -90)
  c.alt:SetPoint("RIGHT", c, "RIGHT", -(BTN_W + 24), 0)
  c.alt.label = UI.Text(c.alt, "small", "muted")
  c.alt.label:SetAllPoints()
  wrap(c.alt.label, 1)
  c.alt:SetScript("OnClick", function()
    local s = c.step
    if s and s.alt and s.alt.go then
      W:Info("what now alternative: %s -> %s", tostring(s.key), tostring(s.alt.text))
      ns.Safe("whatnow:alt", s.alt.go)
    end
  end)
  c.alt:SetScript("OnEnter", function() if c.step and c.step.alt and c.step.alt.go then c.alt.label:SetTextColor(Theme:Color("goldText")) end end)
  c.alt:SetScript("OnLeave", function() c.alt.label:SetTextColor(Theme:Color("muted")) end)
  -- the action column
  c.go = UI:PrimaryButton(c, "Go  >", BTN_W, function() local s = c.step if s then W:Go(s) end end)
  c.go:SetHeight(26)
  c.go:SetPoint("TOPRIGHT", -12, -14)
  c.more = UI:Button(c, "Details", BTN_W, function(self) details(self, c.step) end)
  c.more:SetHeight(20)
  c.more:SetPoint("TOP", c.go, "BOTTOM", 0, -6)
  c.more:HookScript("OnEnter", function(self) details(self, c.step) end)
  c.more:HookScript("OnLeave", function() local tip = rawget(_G, "GameTooltip") if tip then tip:Hide() end end)
  c.skip = UI:Button(c, "x  Not useful", BTN_W, function() local s = c.step if s then W:Skip(s) p:Refresh() end end)
  c.skip:SetHeight(20)
  c.skip:SetPoint("TOP", c.more, "BOTTOM", 0, -6)
  function c:Fill(s)
    self.step = s
    ns.Art:SetKind(self.pic, s.kind)
    self.title:SetText(s.title or "")
    if i == 1 then
      self.tag:SetStyle("gold") self.tag:SetLabel("Recommended") self.tag:Show()
    elseif (s.confidence or 1) < 0.7 then
      self.tag:SetStyle("plain") self.tag:SetLabel(s.kind == "rare" and "Guess" or "Unchecked") self.tag:Show()
    else
      self.tag:Hide()
    end
    self.why:SetText(s.why or "")
    local trip = s.seconds and ns.Travel and ("   ~" .. ns.Travel.Minutes(s.seconds)) or ""
    self.where:SetText((s.where and ("Where: " .. s.where) or "") .. trip
      .. (s.near and "   |cffd4a84asame area as step 1|r" or ""))
    self.alt.label:SetText(s.alt and ("Or: " .. tostring(s.alt.text)) or (s.caveat or ""))
    self.go:Show() self.more:Show() self.skip:Show()
  end
  function c:Empty()
    self.step = nil
    ns.Art:SetKind(self.pic, "quest")
    self.title:SetText("Nothing stands out right now")
    self.tag:Hide()
    self.why:SetText("Outrider learns more as you play: talk to NPCs, open your profession windows, visit the auction house.")
    self.where:SetText("")
    self.alt.label:SetText("")
    self.go:Hide() self.more:Hide() self.skip:Hide()
  end
  return c
end

-- side cards: a display-font heading, then label / value rows
local function sideCard(parent, title, rows, height)
  local c = UI:Card(parent)
  c:SetWidth(SIDE_W)
  c:SetHeight(height)
  c.head = UI.Display(c, "side", "text")
  c.head:SetPoint("TOPLEFT", 12, -10)
  c.head:SetText(title)
  c.rule = c:CreateTexture(nil, "ARTWORK")
  c.rule:SetHeight(1)
  c.rule:SetPoint("TOPLEFT", 12, -32)
  c.rule:SetPoint("TOPRIGHT", -12, -32)
  c.rule:SetColorTexture(Theme:Color("border"))
  c.rows = {}
  for r = 1, rows do
    local l = UI.Text(c, "normal", "body")
    l:SetPoint("TOPLEFT", 12, -40 - (r - 1) * 20)
    l:SetPoint("RIGHT", c, "RIGHT", -70, 0)
    wrap(l, 1)
    local v = UI.Text(c, "normal", "text")
    v:SetPoint("TOPRIGHT", -12, -40 - (r - 1) * 20)
    if v.SetJustifyH then v:SetJustifyH("RIGHT") end
    c.rows[r] = { l, v }
  end
  function c:Row(r, label, value)
    local row = self.rows[r]
    if not row then return end
    row[1]:SetText(label or "")
    row[2]:SetText(value or "")
  end
  return c
end

local function moneyText(c) return ns.Prices and ns.Prices.Money and ns.Prices.Money(c or 0) or tostring(c or 0) end

ns.Hub:AddTab("whatnow", "What now?", function(p)
  local W = ns.WhatNow
  if not W then UI:FormPage(p, { { "note", "What now? is switched off (Modules tab in Settings)." } }) return end
  -- page title
  p.mark = p:CreateTexture(nil, "ARTWORK")
  p.mark:SetSize(36, 36)
  p.mark:SetPoint("TOPLEFT", 0, -2)
  ns.Art:Set(p.mark, "emblem")
  p.heading = UI.Display(p, "page", "text")
  p.heading:SetPoint("TOPLEFT", p.mark, "TOPRIGHT", 10, 2)
  p.heading:SetText("What now?")
  p.sub = UI.Text(p, "normal", "muted")
  p.sub:SetPoint("TOPLEFT", p.heading, "BOTTOMLEFT", 0, -4)
  -- the scene behind the title, once Gary's header art is in
  if ns.Art:Has("header") then
    p.scene = p:CreateTexture(nil, "BACKGROUND")
    p.scene:SetPoint("TOPLEFT", 0, 0)
    p.scene:SetPoint("RIGHT", p, "RIGHT", -(SIDE_W + 12), 0)
    p.scene:SetHeight(TOP - 46)
    ns.Art:Set(p.scene, "header")
    if p.scene.SetAlpha then p.scene:SetAlpha(0.55) end
  end
  -- goal chips
  p.chips = {}
  local prev
  for _, g in ipairs(W.GOALS) do
    local chip = UI:Chip(p, g.label, function() W:SetGoal(g.id) p:Refresh() end, GOAL_ICON[g.id])
    chip.goal = g.id
    if prev then chip:SetPoint("LEFT", prev, "RIGHT", 6, 0) else chip:SetPoint("TOPLEFT", 0, -(TOP - 36)) end
    p.chips[#p.chips + 1] = chip
    prev = chip
  end
  -- step cards
  p.cards = {}
  for i = 1, W.MAX do
    local c = stepCard(p, i, W, p)
    c:SetPoint("TOPLEFT", 0, -TOP - (i - 1) * (CARD_H + CARD_GAP))
    c:SetPoint("RIGHT", p, "RIGHT", -(SIDE_W + 12), 0)
    p.cards[i] = c
  end
  p.more = UI.Text(p, "small", "muted")
  -- side column
  p.errands = sideCard(p, "Errands", 3, 104)
  p.errands:SetPoint("TOPRIGHT", 0, 0)
  p.rare = sideCard(p, "Rare watch", 2, 84)
  p.rare:SetPoint("TOPRIGHT", p.errands, "BOTTOMRIGHT", 0, -8)
  p.session = sideCard(p, "This session", 3, 104)
  p.session:SetPoint("TOPRIGHT", p.rare, "BOTTOMRIGHT", 0, -8)
  p.snap = sideCard(p, "Character", 3, 176)
  p.snap:SetPoint("TOPRIGHT", p.session, "BOTTOMRIGHT", 0, -8)
  p.portrait = UI:Portrait(p.snap, 40)
  p.portrait:SetPoint("TOPLEFT", 14, -42)
  p.who = UI.Display(p.snap, "side", "text")
  p.who:SetPoint("TOPLEFT", p.portrait, "TOPRIGHT", 10, -2)
  p.where = UI.Text(p.snap, "small", "muted")
  p.where:SetPoint("TOPLEFT", p.who, "BOTTOMLEFT", 0, -3)
  -- the snapshot's rows sit under the portrait
  for r, row in ipairs(p.snap.rows) do
    row[1]:ClearAllPoints() row[2]:ClearAllPoints()
    row[1]:SetPoint("TOPLEFT", 12, -96 - (r - 1) * 22)
    row[2]:SetPoint("TOPRIGHT", -12, -96 - (r - 1) * 22)
  end
  p.xpbg = p.snap:CreateTexture(nil, "ARTWORK")
  p.xpbg:SetHeight(6)
  p.xpbg:SetPoint("TOPLEFT", 12, -114)
  p.xpbg:SetPoint("TOPRIGHT", -12, -114)
  p.xpbg:SetColorTexture(Theme:Color("border"))
  p.xpfill = p.snap:CreateTexture(nil, "OVERLAY")
  p.xpfill:SetHeight(6)
  p.xpfill:SetPoint("TOPLEFT", p.xpbg, "TOPLEFT", 0, 0)
  p.xpfill:SetColorTexture(0.55, 0.36, 0.95, 1)
  -- move row 2 and 3 below the bar
  for r = 2, 3 do
    local row = p.snap.rows[r]
    row[1]:ClearAllPoints() row[2]:ClearAllPoints()
    row[1]:SetPoint("TOPLEFT", 12, -128 - (r - 2) * 22)
    row[2]:SetPoint("TOPRIGHT", -12, -128 - (r - 2) * 22)
  end

  function p:Refresh()
    local key = tostring(ns.db.key)
    local name = key:match("^[^-]+") or "?"
    self.sub:SetText("Next steps for " .. name .. ", picked for your goal.")
    -- goal chips
    local goal = W:Goal()
    for _, chip in ipairs(self.chips) do chip:SetOn(chip.goal == goal) end
    -- steps: as many cards as the window has room for
    local list = W:List()
    local room = math.floor(((self:GetHeight() or 0) - TOP + CARD_GAP) / (CARD_H + CARD_GAP))
    if room < 1 then room = W.MAX end
    local shown = 0
    for i, c in ipairs(self.cards) do
      local s = list[i]
      if i <= room and (s or i == 1) then
        if s then c:Fill(s) else c:Empty() end
        c:Show()
        shown = i
      else
        c:Hide()
      end
    end
    local hidden = #list - math.min(#list, shown)
    self.more:ClearAllPoints()
    self.more:SetPoint("TOPLEFT", 0, -TOP - shown * (CARD_H + CARD_GAP))
    self.more:SetText(hidden > 0 and string.format("%d more step%s: make the window taller to see %s.", hidden,
      hidden == 1 and "" or "s", hidden == 1 and "it" or "them") or "")
    -- errands
    local errands = {}
    if ns.Errands then
      local ok, l = pcall(ns.Errands.List, ns.Errands)
      if ok and type(l) == "table" then errands = l end
    end
    for r = 1, 3 do
      local e = errands[r]
      self.errands:Row(r, e and e.text or (r == 1 and "Nothing to do in town" or ""), "")
    end
    -- rare watch
    local scan, S = ns.Modules:Get("RareScan"), ns.Sightings
    local rname, rstate = "Nothing watched", ""
    if scan and S then
      local npcs = ns.db.global.discovered and ns.db.global.discovered.npcs or {}
      for id in pairs(scan:Settings().watch or {}) do
        if type(id) == "number" then
          local ok, w = pcall(S.Window, S, id)
          local state = ok and type(w) == "table" and w.state or "unknown"
          rname = npcs[id] and npcs[id].name or ("rare " .. id)
          rstate = state == "unknown" and "no sightings yet" or ("window " .. tostring(state))
          if state == "open" or state == "alive" or state == "overdue" then break end
        end
      end
    end
    self.rare:Row(1, rname, "")
    self.rare:Row(2, rstate, "")
    -- this session
    local st = W:SessionStats()
    if st then
      self.session:Row(1, "XP gained", (st.levels > 0 and ("+" .. st.levels .. " lvl, ") or "") .. "+" .. st.xp)
      self.session:Row(2, "Gold", (st.money >= 0 and "+" or "-") .. moneyText(math.abs(st.money)))
      self.session:Row(3, "Time played", ns.Travel and ns.Travel.Minutes(st.seconds) or (math.floor(st.seconds / 60) .. " min"))
    else
      self.session:Row(1, "Starts at login", "")
    end
    -- character snapshot
    local cls = ns.PlayerClass and ns.PlayerClass() or ""
    local colors = rawget(_G, "RAID_CLASS_COLORS")
    local cc = colors and colors[cls]
    local r, g, b = 0.9, 0.9, 0.9
    if cc then r, g, b = cc.r, cc.g, cc.b end
    self.portrait:SetUnit("player")
    local level = C.Call("UnitLevel", "player") or "?"
    self.who:SetText(string.format("%s  |cff%02x%02x%02x%s|r", name, r * 255, g * 255, b * 255,
      tostring(C.Call("UnitClass", "player") or cls)))
    local mapID = C.PlayerPosition("player")
    self.where:SetText(string.format("Level %s%s", tostring(level),
      mapID and ns.Travel and ("   " .. ns.Travel.ZoneName(mapID)) or ""))
    local xp, max = C.Call("UnitXP", "player") or 0, C.Call("UnitXPMax", "player") or 0
    local pct = max > 0 and xp / max or 0
    self.snap:Row(1, "XP", max > 0 and string.format("%d / %d (%d%%)", xp, max, math.floor(pct * 100)) or "max level")
    local barW = SIDE_W - 24
    self.xpfill:SetWidth(math.max(1, barW * pct))
    self.snap:Row(2, "Gold", moneyText(C.Call("GetMoney") or 0))
    local il = W.ItemLevel()
    self.snap:Row(3, "Item level", il and tostring(il) or "?")
  end
end)

-- ----------------------------------------------------------------- Chat
ns.Hub:AddTab("chat", "Chat", function(p)
  local function words()
    local out = {}
    for w in pairs(set("Chat").words or {}) do out[#out + 1] = w end
    table.sort(out)
    return out
  end
  UI:FormPage(p, {
    { "header", "Chat" },
    { "check", "Hide repeated spam", function() return set("Chat").spam end, function(on) ns.Slash:Run("chat spam " .. onoff(on)) end },
    { "check", "LFG and Trade in their own tab", function() return set("Chat").lfgTab end, function(on) ns.Slash:Run("chat lfgtab " .. onoff(on)) end },
    { "check", "Time stamps", function() return (C.Call("GetCVar", "showTimestamps") or "none") ~= "none" end,
      function(on) ns.Slash:Run("chat time " .. onoff(on)) end },
    { "check", "Keep chat after a reload", function() return ns.Tweaks:Settings().history end, function(on) ns.Tweaks:Settings().history = on end },
    { "buttons", { { "Copy the last 100 chat lines", Run("copychat") }, { "Recent alerts", Run("feed") } } },
    { "header", "Highlighted words" },
    { "input", "Highlight a word", "Mystmane", "Add", function(t) ns.Slash:Run("chat word add " .. t) end },
    { "note", "Click a word to stop highlighting it." },
    { "list", 4, function(row, w) row.text:SetText(w) end, function(w) ns.Slash:Run("chat word remove " .. w) p:Refresh() end, words,
      empty = "No highlighted words yet. Your name always stands out." },
    { "header", "Spell check" },
    { "input", "Add a word", "Skyborne", "Add", function(t) ns.Slash:Run("spell add " .. t) end },
    { "input", "Remove a word", "Skyborne", "Remove", function(t) ns.Slash:Run("spell remove " .. t) end },
  })
end)

-- -------------------------------------------------------------- Sharing
ns.Hub:AddTab("sharing", "Sharing", function(p)
  UI:FormPage(p, {
    { "header", "Share with your guild or party" },
    { "note", "|cfff1d58eNothing is shared until you turn it on.|r  Only other Outrider users see these messages, over guild, party or whisper. Nothing leaves the game." },
    { "check", "Say hello to other Outrider users", function() return set("Comm").hello end,
      function(on) ns.Slash:Run("share hello " .. onoff(on)) end },
    { "check", "Rares: guild", function() return set("RareShare").guild end, function(on) ns.Slash:Run("share rares guild " .. onoff(on)) end },
    { "check", "Rares: party", function() return set("RareShare").party end, function(on) ns.Slash:Run("share rares party " .. onoff(on)) end },
    { "check", "Herb and ore spots: guild", function() return set("GatherShare").guild end, function(on) ns.Slash:Run("share nodes " .. onoff(on)) end },
    { "check", "My location: party", function() return set("LocationShare").on end, function(on) ns.Slash:Run("share location " .. onoff(on)) end },
    { "header", "Gear for alts, family and other Outrider users" },
    { "note", "When something in your bags is an upgrade for someone, Outrider says so: your alts first, then family and friends, then other Outrider users in your guild or party. At a mailbox it fills in their name." },
    { "check", "Share my gear card and see others' (guild and party)", function() return set("KitShare").share end,
      function(on) set("KitShare").share = on if on and ns.KitShare then ns.KitShare:Broadcast() end end, "off: your alts only" },
    { "input", "Add family or friend", "character name", "Add", function(t) if ns.KitShare then ns.KitShare:SetFamily(t, true) end end },
    { "input", "Remove family or friend", "character name", "Remove", function(t) if ns.KitShare then ns.KitShare:SetFamily(t, false) end end },
    { "note", function()
      local fam = set("KitShare").family or {}
      local m = mod("KitShare")
      return "Family and friends: " .. (#fam > 0 and table.concat(fam, ", ") or "none yet") .. "\n" .. (m and m.enabled and m:Activity() or "")
    end, 36 },
  })
end)

-- -------------------------------------------------------------- Settings
ns.Hub:AddTab("settings", "Settings", function(p)
  local A = function() return ns.Theme:Access() end
  local confirm = false
  UI:FormPage(p, {
    { "header", "Look" },
    { "custom", function(host)
      local row = CreateFrame("Frame", nil, host)
      row:SetSize(570, 58)
      local box = UI:SearchBox(row, 300, "Find a setting...")
      box:SetPoint("TOPLEFT", 0, 0)
      local result = UI.Text(row, "small", "muted")
      result:SetPoint("LEFT", box, "RIGHT", 8, 0)
      local function find()
        local label, matches = p.form:FindSetting(box:GetText())
        result:SetText(label and (matches .. " matches: " .. label) or "No setting found")
      end
      box:SetScript("OnEnterPressed", find)
      -- Results as you type, grouped by section, each switch showing ON/OFF;
      -- click one to jump there (gallery idea from Leatrix Plus, 2026-11-18).
      local res = UI:ScrollList(p, {
        rows = 8, rowHeight = 22,
        render = function(r, m)
          local state = m.on == true and "  |cff66d980ON|r" or m.on == false and "  |cff8f96a6OFF|r" or ""
          r.text:SetText(string.format("|cff8f96a6%s:|r  %s%s", m.section ~= "" and m.section or "Settings", m.label, state))
        end,
        onClick = function(m) p.form:JumpTo(m.y) p.searchResults:Hide() end,
      })
      res:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -2)
      res:SetWidth(520)
      if res.SetFrameStrata then res:SetFrameStrata("DIALOG") end
      res:Hide()
      p.searchResults = res
      box:HookScript("OnTextChanged", function(self)
        local q = self:GetText() or ""
        local list = q ~= "" and p.form and p.form:SearchAll(q) or {}
        res:SetItems(list)
        res:SetShown(#list > 0)
        result:SetText(q == "" and "" or (#list .. " found"))
      end)
      box:HookScript("OnEscapePressed", function() res:Hide() end)
      local btn = UI:Button(row, "Find next", 110, find)
      btn:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -4)
      UI.Tip(btn, "Find next setting", "Searches settings labels and scrolls to the next matching control.")
      row.searchBox, row.searchResult, row.searchNext = box, result, btn
      p.settingsSearch = row
      return row
    end, 65 },
    { "check", "Class color accent (after reload)", function() return ns.db.char.classAccent ~= false end,
      function(on) ns.db.char.classAccent = on and true or false end },
    { "check", "Minimap button", function() return not ns.db.global.minimap.hide end,
      function(on) ns.Slash:Run("minimap " .. onoff(on)) end },
    { "slider", "Text size (after reload)", 0.8, 1.5, 0.1, function() return A().fontScale or 1 end,
      function(v) ns.Slash:Run(string.format("access font %.1f", v)) end, "%.1f" },
    { "slider", "Window size (after reload)", 0.7, 1.5, 0.1, function() return A().uiScale or 1 end,
      function(v) ns.Slash:Run(string.format("access scale %.1f", v)) end, "%.1f" },
    { "check", "Colorblind colors", function() return A().colorblind end, function(on) ns.Slash:Run("access colorblind " .. onoff(on)) end },
    { "check", "High contrast", function() return A().highContrast end, function(on) ns.Slash:Run("access contrast " .. onoff(on)) end },
    { "check", "Reduced motion", function() return A().reducedMotion end, function(on) ns.Slash:Run("access motion " .. onoff(not on)) end },
    { "buttons", { { "Reload now", function() C.Call("ReloadUI") end }, { "First-run setup", Run("setup") } } },
    { "header", "Info bar" },
    { "check", "Show the info bar", function() return ns.InfoBar:Settings().shown end, function(on) ns.Slash:Run("bar " .. onoff(on)) end },
    { "check", "Bar: gold", function() return ns.InfoBar:Settings().gold ~= false end, function(on) ns.InfoBar:Settings().gold = on ns.InfoBar:Apply() end },
    { "check", "Bar: bag space", function() return ns.InfoBar:Settings().bags ~= false end, function(on) ns.InfoBar:Settings().bags = on ns.InfoBar:Apply() end },
    { "check", "Bar: durability", function() return ns.InfoBar:Settings().dura ~= false end, function(on) ns.InfoBar:Settings().dura = on ns.InfoBar:Apply() end },
    { "check", "Bar: ammo", function() return ns.InfoBar:Settings().ammo ~= false end, function(on) ns.InfoBar:Settings().ammo = on ns.InfoBar:Apply() end },
    { "check", "Bar: experience", function() return ns.InfoBar:Settings().xp ~= false end, function(on) ns.InfoBar:Settings().xp = on ns.InfoBar:Apply() end },
    { "check", "Bar: clock", function() return ns.InfoBar:Settings().clock ~= false end, function(on) ns.InfoBar:Settings().clock = on ns.InfoBar:Apply() end },
    { "check", "Bar: latency and frame rate", function() return ns.InfoBar:Settings().net ~= false end, function(on) ns.InfoBar:Settings().net = on ns.InfoBar:Apply() end },
    { "buttons", { { "Put the bar back at the top", Run("bar reset"), 210 } } },
    { "header", "Bags" },
    { "check", "Bag slots: item level", function() return ns.BagExtras:Settings().ilvl end, function(on) ns.BagExtras:Settings().ilvl = on ns.BagExtras:UpdateAll() end },
    { "check", "Bag slots: upgrade arrows", function() return ns.BagExtras:Settings().upgrade end, function(on) ns.BagExtras:Settings().upgrade = on ns.BagExtras:UpdateAll() end },
    { "check", "Bag slots: junk coins", function() return ns.BagExtras:Settings().junk end, function(on) ns.BagExtras:Settings().junk = on ns.BagExtras:UpdateAll() end },
    { "header", "Tooltip details" },
    { "check", "Only show Outrider tooltip details while holding Shift",
      function() return ns.TooltipLines:Settings().shiftOnly end,
      function(on) ns.TooltipLines:Settings().shiftOnly = on and true or false end },
    { "slider", "Maximum tooltip lines per source (0 = all)", 0, 10, 1,
      function() return ns.TooltipLines:Settings().limit end,
      function(value) ns.TooltipLines:Settings().limit = math.floor(value + 0.5) end, "%.0f" },
    { "slider", "Quest item references per category", 1, 10, 1,
      function() return ns.TooltipLines:Settings().questUsesLimit or 2 end,
      function(value) ns.TooltipLines:Settings().questUsesLimit = math.floor(value + 0.5) end, "%.0f" },
    { "check", "Tooltip: quest objectives", function() return ns.TooltipLines:Enabled("quest") end,
      function(on) ns.TooltipLines:SetEnabled("quest", on) end },
    { "check", "Tooltip: quests started by / using items", function() return ns.TooltipLines:Enabled("questuses") end,
      function(on) ns.TooltipLines:SetEnabled("questuses", on) end },
    { "check", "Tooltip: gear comparisons", function() return ns.TooltipLines:Enabled("verdict") end,
      function(on) ns.TooltipLines:SetEnabled("verdict", on) end },
    { "check", "Tooltip: item market values", function() return ns.TooltipLines:Enabled("value") end,
      function(on) ns.TooltipLines:SetEnabled("value", on) end },
    { "check", "Tooltip: rare and beast details", function() return ns.TooltipLines:Enabled("beast") end,
      function(on) ns.TooltipLines:SetEnabled("beast", on) end },
    { "note", "For every individual tooltip source, use /ride toolextras list, hide <key>, or show <key>. Re-hover if Shift refresh is unavailable." },
    { "header", "Small switches" },
    { "check", "Hide the big zone names", function() return ns.Tweaks:Settings().zoneText end, function(on) ns.Tweaks:Settings().zoneText = on ns.Tweaks:ApplyClutter() end },
    { "check", "Hide red error text", function() return ns.Tweaks:Settings().errors end, function(on) ns.Tweaks:Settings().errors = on ns.Tweaks:ApplyClutter() end },
    { "check", "Hide the talking head", function() return ns.Tweaks:Settings().talkingHead end, function(on) ns.Tweaks:Settings().talkingHead = on ns.Tweaks:ApplyClutter() end },
    { "check", "Camera zooms out further", function() return ns.Tweaks:Settings().zoom end, function(on) ns.Tweaks:Settings().zoom = on ns.Tweaks:ApplyZoom() end },
    { "check", "Gather addon minimap buttons", function() return ns.Tweaks:Settings().buttonBag end, function(on) ns.Tweaks:Settings().buttonBag = on ns.Tweaks:Gather(on) end },
    { "note", "Wowhead link: hover an item, NPC or spell and press the key you bind to Outrider: Wowhead link (Key Bindings, AddOns), or type /ride wowhead." },
    { "header", "Edit Mode layout per situation" },
    { "input", "Situation and layout", "questing Questing", "Set", function(t) ns.Slash:Run("layout " .. t) end },
    { "buttons", { { "Show layouts", Run("layout") }, { "Turn off", Run("layout off") } } },
    { "header", "Your settings" },
    { "buttons", { { "Export", Run("export") }, { "Import", Run("import") }, { "Copy from a character", function() ns.Hub.frame.tabBar:Select("characters") end } } },
    { "buttons", { { "Reset this character", function(self)
      if not confirm then confirm = true self.label:SetText("Click again to reset") return end
      ns.Slash:Run("reset char confirm")
    end, 170 } } },
  })
end)

-- ---------------------------------------------------------- All commands
-- Every /ride command with its help line: pick one, add what it needs, Run.
ns.Hub:AddTab("commands", "All commands", function(p)
  local head = UI.Text(p, "small", "muted")
  head:SetPoint("TOPLEFT", 0, 0)
  head:SetText("Every Outrider command. Type to filter, click one, add what it needs, then Run. Results show in chat.")
  p.filter = UI:SearchBox(p, 220, "filter commands")
  p.filter:SetPoint("TOPRIGHT", p, "TOPRIGHT", -4, 2)
  p.filter:HookScript("OnTextChanged", function() if p.Refresh then p:Refresh() end end)
  p.count = UI.Text(p, "small", "muted")
  p.count:SetPoint("RIGHT", p.filter, "LEFT", -10, 0)
  p.list = UI:ScrollList(p, {
    rows = 22, rowHeight = 22,
    -- the usage repeats the name ("bossloot bossloot <boss>"): show it once
    render = function(row, c)
      local usage = tostring(c.usage or ""):gsub("^" .. c.name:gsub("%p", "%%%0") .. "%s*", "")
      -- "|" starts a colour or link code in game text ("add|remove" showed as
      -- "addemove"); doubled, it prints as a plain bar
      usage = usage:gsub("|", "||")
      row.text:SetText(string.format("|cfff1d58e%s|r   |cffc3c8d2%s|r", c.name, usage))
    end,
    onClick = function(c) p.current = c p.label:SetText(c.name) p.box:SetText("") p.box:SetFocus() end,
  })
  p.list:SetPoint("TOPLEFT", 0, -26)
  p.list:SetPoint("RIGHT", p, "RIGHT", -4, 0)
  p.label = UI.Text(p, "large", "goldText")
  p.label:SetPoint("TOPLEFT", p.list, "BOTTOMLEFT", 0, -10)
  p.label:SetText("Pick a command")
  p.box = UI:SearchBox(p, 300, "what it needs, if anything")
  p.box:SetPoint("LEFT", p.label, "RIGHT", 10, 0)
  local function run()
    if not p.current then return end
    ns.Slash:Run(p.current.name .. " " .. (p.box:GetText() or ""))
    p.box:ClearFocus()
  end
  p.run = UI:Button(p, "Run", 80, run)
  p.run:SetPoint("LEFT", p.box, "RIGHT", 6, 0)
  p.box:SetScript("OnEnterPressed", run)
  function p:Refresh()
    local out = {}
    for _, name in ipairs(ns.Slash.order) do
      local c = ns.Slash.commands[name]
      local q = tostring(self.filter and self.filter:GetText() or ""):lower()
      if c and (q == "" or name:find(q, 1, true) or tostring(c.usage or ""):lower():find(q, 1, true)) then
        out[#out + 1] = { name = name, usage = c.usage }
      end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    self.list:SetItems(out)
    self.count:SetText(#out .. " commands")
  end
end)

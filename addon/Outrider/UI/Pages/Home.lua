-- UI/Pages/Home.lua
-- Home: hero, next step, at-a-glance tiles, where-to cards. Split from UI/Pages.lua (OI01-08); page ids, titles and order unchanged.

local _, ns = ...
local UI, Theme = ns.UI, ns.Theme
local C = ns.Compat
local Run = UI.Run
local K = ns.PageKit
local mod, set, onoff = K.mod, K.set, K.onoff


-- ------------------------------------------------------------------ Home
-- Home, rebuilt as the showpiece (requirement 2026-11-21: the flagship page,
-- above the other hero pages; more directions, more information, and an
-- 8th-grade reader should
-- know at a glance what to do).
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

-- Unspent talent points: the talent reader first (Forever's C_Traits; the old
-- UnitCharacterPoints said 0 while the game said "unspent talent points").
local function classTalentPoints()
  local T = ns.Talents
  local ok, state = pcall(function() return T and T.Read and T:Read() end)
  local n = ok and type(state) == "table" and tonumber(state.unspent)
  if n then return n end
  return tonumber(C.Readable(C.Call("UnitCharacterPoints", "player"))) or 0
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
  -- every word reads even where the painting is bright (screenshot
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
    -- The hero painting: two 1024x256 halves cut from the band the banner
    -- shows (2026-11-23: the 1024x512 halves, 2 MB each, drew black on
    -- Forever while the 1 MB page headers drew fine). The cut band is 7.7:1;
    -- show the middle part that fills the banner without stretching.
    local hw, hh = w - 2, (self.hero:GetHeight() or 150) - 2
    if self.hero.halves and hw > 0 and hh > 0 and self.hero.artL.SetTexCoord then
      local band = math.min(1, 7.7 * hh / hw)
      local top = (1 - band) / 2
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
    -- cards: three columns, two rows, as tall as the window allows (a
    -- screenshot showed a third of the page empty)
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
    -- Self-check, once a session (bug 2026-11-23: the painting showed as a
    -- black banner on a druid): what each half of the painting holds. A
    -- half the game reports as empty falls back to the world header art.
    if not self.artChecked then
      self.artChecked = true
      local parts = {}
      for _, k in ipairs({ "artL", "artR" }) do
        local t = self.hero[k]
        local file = t.GetTextureFilePath and t:GetTextureFilePath() or (t.GetTexture and t:GetTexture())
        local l, r, top, bottom = 0, 0, 0, 0
        if t.GetTexCoord then l, top, _, bottom, r = t:GetTexCoord() end
        parts[#parts + 1] = string.format("%s file=%s shown=%s alpha=%.2f size=%.0fx%.0f crop=%.2f-%.2f", k, tostring(file),
          tostring(t:IsShown()), t:GetAlpha() or 0, t:GetWidth() or 0, t:GetHeight() or 0, tonumber(top) or 0, tonumber(bottom) or 0)
        if file == nil or file == "" then
          if not (ns.Art and ns.Art:Set(t, "header_world")) then t:SetColorTexture(Theme:Color("panel")) end
        end
      end
      ns.Log:Info("Home", "painting: halves=%s, %s, hero %.0fx%.0f", tostring(self.hero.halves), table.concat(parts, "; "),
        self.hero:GetWidth() or 0, self.hero:GetHeight() or 0)
    end
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
    local pts = classTalentPoints()
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
-- A grid of picture tiles (requirement 2026-11-20: pages an 8th grader gets at a
-- glance): { {label, art, fallbackIcon, fn, tip}, ... }, used as a "custom" form row.

K.classTalentPoints = classTalentPoints

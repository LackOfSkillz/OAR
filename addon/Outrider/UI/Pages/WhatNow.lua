-- UI/Pages/WhatNow.lua
-- What now? (Pathfinder Lite) page. Split from UI/Pages.lua (OI01-08); page ids, titles and order unchanged.

local _, ns = ...
local UI, Theme = ns.UI, ns.Theme
local C = ns.Compat
local Run = UI.Run
local K = ns.PageKit
local mod, set, onoff = K.mod, K.set, K.onoff

-- ------------------------------------------------------------- What now?
-- Pathfinder Lite in the Expedition look (owner's concept picture, 2026-11-15):
-- page title in the display font, goal chips with icons, step cards with a
-- picture, Go / Details / Not useful, and a side column with errands, rare
-- watch, this session and a character snapshot. Pictures come from ns.Art
-- (the custom art when installed, game icons until then). No made-up
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

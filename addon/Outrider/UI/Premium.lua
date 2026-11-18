-- UI/Premium.lua
-- Premium building blocks (Gary, 2026-11-16: "a lot of pages need artwork and
-- premium ui/ux feel"), in the style of the What now? cards, for any page:
--   UI:CardList(parent)   rich cards: picture, title, tags, a line, item chips
--                         (real item icons, item tooltip on hover), buttons
--   UI:StatusTiles(parent) a checklist as tiles: icon, text, green or red mark
-- Both have :SetItems(list) and :LayoutHeight() so Form pages can hold them
-- ({ "cards", getItems } and { "tiles", getItems } rows in UI/Form.lua).

local _, ns = ...
local UI, Theme = ns.UI, ns.Theme
-- (exposed for pages that build card items)
local ICON = "Interface\\Icons\\"

local function itemIcon(itemID)
  local f = C_Item and C_Item.GetItemIconByID or rawget(_G, "GetItemIcon")
  if type(f) ~= "function" then return nil end
  local ok, tex = pcall(f, itemID)
  return ok and tex or nil
end

local function setPic(tex, it)
  if it.art and ns.Art and ns.Art:Set(tex, it.art, it.pic or (ICON .. "INV_Misc_QuestionMark")) then return end
  if not it.art then
    tex:SetTexture(it.pic or (ICON .. "INV_Misc_QuestionMark"))
    if tex.SetTexCoord then tex:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
  end
end

UI.ItemIcon = itemIcon

-- ------------------------------------------------------------------ cards
local CARD_H, PIC, GAP = 106, 72, 8

local function chip(parent)
  local c = CreateFrame("Button", nil, parent, Theme:BackdropTemplate())
  c:SetHeight(24)
  Theme:ApplyPanel(c, "bg", "border")
  c.icon = c:CreateTexture(nil, "ARTWORK")
  c.icon:SetSize(18, 18)
  c.icon:SetPoint("LEFT", 3, 0)
  c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  c.text = UI.Text(c, "small", "body")
  c.text:SetPoint("LEFT", c.icon, "RIGHT", 6, 0)
  c:SetScript("OnEnter", function(self)
    if self.SetBackdropBorderColor then self:SetBackdropBorderColor(Theme:Color("gold")) end
    local tt = rawget(_G, "GameTooltip")
    if not tt then return end
    tt:SetOwner(self, "ANCHOR_RIGHT")
    if self.itemID and tt.SetItemByID then
      pcall(tt.SetItemByID, tt, self.itemID)
    elseif self.tip then
      tt:AddLine(self.tip, 1, 1, 1, true)
    end
    if self.note then tt:AddLine(self.note, 0.5, 1, 0.5, true) end
    tt:Show()
  end)
  c:SetScript("OnLeave", function(self)
    if self.SetBackdropBorderColor then self:SetBackdropBorderColor(Theme:Color("border")) end
    local tt = rawget(_G, "GameTooltip")
    if tt then tt:Hide() end
  end)
  return c
end

local function card(list, i)
  local c = UI:Card(list, false)
  c:SetHeight(CARD_H)
  c.frame = CreateFrame("Frame", nil, c, Theme:BackdropTemplate())
  c.frame:SetSize(PIC + 4, PIC + 4)
  c.frame:SetPoint("TOPLEFT", 12, -14)
  Theme:ApplyPanel(c.frame, "bg", "strong")
  c.pic = c.frame:CreateTexture(nil, "ARTWORK")
  c.pic:SetPoint("TOPLEFT", 2, -2)
  c.pic:SetPoint("BOTTOMRIGHT", -2, 2)
  local left = PIC + 30
  c.title = UI.Display(c, "card", "goldText")
  c.title:SetPoint("TOPLEFT", left, -12)
  c.title:SetJustifyH("LEFT")
  if c.title.SetWordWrap then c.title:SetWordWrap(false) end
  c.tags = {}
  c.line = UI.Text(c, "normal", "body")
  c.line:SetPoint("TOPLEFT", left, -38)
  c.line:SetPoint("RIGHT", c, "RIGHT", -190, 0)
  c.line:SetJustifyH("LEFT")
  c.line:SetJustifyV("TOP")
  c.line:SetHeight(30)
  if c.line.SetWordWrap then c.line:SetWordWrap(true) end
  if c.line.SetMaxLines then pcall(c.line.SetMaxLines, c.line, 2) end
  -- hovering the picture shows the item's own tooltip when the card is an item
  c.frame:EnableMouse(true)
  c.frame:SetScript("OnEnter", function(self)
    local tt, it = rawget(_G, "GameTooltip"), self:GetParent().item
    if not (tt and it) then return end
    tt:SetOwner(self, "ANCHOR_RIGHT")
    if it.itemID and tt.SetItemByID then pcall(tt.SetItemByID, tt, it.itemID)
    else tt:AddLine(it.title or "", 1, 0.82, 0) if it.line then tt:AddLine(it.line, 1, 1, 1, true) end end
    tt:Show()
  end)
  c.frame:SetScript("OnLeave", function() local tt = rawget(_G, "GameTooltip") if tt then tt:Hide() end end)
  c.chips = {}
  c.buttons = {}
  c.Place = function(self)
    -- Title and tags never run under the buttons on the right (premium plan
    -- B6): the room is the card minus the picture and the button column;
    -- the title takes what it needs up to 70% of it, tags that don't fit hide.
    local reserve = (self.nButtons or 0) > 0 and 190 or 20
    local room = (self:GetWidth() or 600) - left - reserve
    if room < 120 then room = 120 end
    local sw = self.title.GetStringWidth and tonumber((self.title:GetStringWidth())) or 0
    local tw = math.min(sw > 0 and sw + 2 or room, room)
    if #self.tags > 0 then tw = math.min(tw, math.floor(room * 0.7)) end
    self.title:SetWidth(tw)
    local prev, used = self.title, tw
    for _, t in ipairs(self.tags) do
      if t:IsShown() then
        local w = (t.GetWidth and t:GetWidth()) or 60
        if used + 8 + w > room then t:Hide()
        else t:ClearAllPoints() t:SetPoint("LEFT", prev, "RIGHT", 8, 0) prev, used = t, used + 8 + w end
      end
    end
    self.line:ClearAllPoints()
    self.line:SetPoint("TOPLEFT", left, -38)
    self.line:SetPoint("RIGHT", self, "RIGHT", -reserve, 0)
  end
  return c
end

function UI:CardList(parent)
  local list = CreateFrame("Frame", nil, parent)
  list:SetSize(560, 10)
  list.cards, list.items = {}, {}
  function list:SetItems(items)
    self.items = items or {}
    for i, it in ipairs(self.items) do
      local c = self.cards[i] or card(self, i)
      self.cards[i] = c
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", 0, -(i - 1) * (CARD_H + GAP))
      c:SetPoint("RIGHT", self, "RIGHT", 0, 0)
      if c.SetEdge then c:SetEdge(it.highlight) end
      if c.SetBackdropBorderColor then c:SetBackdropBorderColor(Theme:Color(it.highlight and "gold" or "border")) end
      c.item = it
      if it.itemID and not it.pic and not it.art then it.pic = itemIcon(it.itemID) end
      setPic(c.pic, it)
      c.title:SetText(it.title or "")
      -- tags
      for k, tg in ipairs(it.tags or {}) do
        local t = c.tags[k]
        if not t then t = UI:Tag(c, "", "plain") c.tags[k] = t end
        if t.SetStyle then t:SetStyle(tg[2] or "plain") end
        if t.SetLabel then t:SetLabel(tg[1]) end
        t:Show()
      end
      for k = #(it.tags or {}) + 1, #c.tags do c.tags[k]:Hide() end
      c:Place()
      c.line:SetText(it.line or "")
      -- chips in a row under the line
      local x = PIC + 30
      for k, ch in ipairs(it.chips or {}) do
        local b = c.chips[k]
        if not b then b = chip(c) c.chips[k] = b end
        b.itemID, b.tip, b.note = ch.itemID, ch.tip, ch.note
        local tex = ch.icon or (ch.itemID and itemIcon(ch.itemID)) or (ICON .. "INV_Misc_QuestionMark")
        b.icon:SetTexture(tex)
        b.text:SetText(ch.text or "")
        local tw = b.text.GetStringWidth and b.text:GetStringWidth()
        local w = math.min(230, (type(tw) == "number" and tw or 80) + 34)
        b:SetWidth(w)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", c, "TOPLEFT", x, -70)
        x = x + w + 6
        b:SetShown(x < (c:GetWidth() or 900) - 180)
      end
      for k = #(it.chips or {}) + 1, #c.chips do c.chips[k]:Hide() end
      -- buttons on the right, stacked
      for k, a in ipairs(it.actions or {}) do
        local b = c.buttons[k]
        if not b then
          b = UI:Button(c, "", 160, function(self) if self.fn then ns.Safe("card:" .. tostring(self.label:GetText()), self.fn) end end)
          b:SetHeight(26)
          c.buttons[k] = b
        end
        b.fn = a[2]
        b.label:SetText(a[1])
        UI.SetPrimary(b, k == 1)
        if a[3] then UI.Tip(b, a[1], a[3]) end
        b:ClearAllPoints()
        b:SetPoint("TOPRIGHT", c, "TOPRIGHT", -14, -14 - (k - 1) * 32)
        b:Show()
      end
      for k = #(it.actions or {}) + 1, #c.buttons do c.buttons[k]:Hide() end
      c.nButtons = #(it.actions or {})
      c:Place()
      c:Show()
    end
    for i = #self.items + 1, #self.cards do self.cards[i]:Hide() end
    self:SetHeight(math.max(1, self:LayoutHeight()))
  end
  function list:LayoutHeight()
    local n = #self.items
    return n > 0 and (n * (CARD_H + GAP)) or 0
  end
  return list
end

-- ------------------------------------------------------------------ tiles
local TILE_H, TILE_GAP, COLS = 44, 8, 2

function UI:StatusTiles(parent)
  local box = CreateFrame("Frame", nil, parent)
  box:SetSize(560, 10)
  box.tiles, box.items = {}, {}
  function box:SetItems(items)
    self.items = items or {}
    local w = (self:GetWidth() or 560)
    if w < 200 then w = 560 end
    -- more columns on a wide page (premium plan S1)
    local cols = w >= 900 and 4 or w >= 680 and 3 or COLS
    self.cols = cols
    local tw = math.floor((w - TILE_GAP * (cols - 1)) / cols)
    for i, it in ipairs(self.items) do
      local t = self.tiles[i]
      if not t then
        t = CreateFrame("Frame", nil, self, Theme:BackdropTemplate())
        t.icon = t:CreateTexture(nil, "ARTWORK")
        t.icon:SetSize(28, 28)
        t.icon:SetPoint("LEFT", 8, 0)
        t.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        t.text = UI.Text(t, "normal", "text")
        t.text:SetPoint("LEFT", t.icon, "RIGHT", 10, 0)
        t.text:SetPoint("RIGHT", t, "RIGHT", -34, 0)
        t.text:SetJustifyH("LEFT")
        t.mark = UI.Display(t, "card", "good")
        t.mark:SetPoint("RIGHT", -10, 0)
        self.tiles[i] = t
      end
      t:SetSize(tw, TILE_H)
      local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", col * (tw + TILE_GAP), -row * (TILE_H + TILE_GAP))
      Theme:ApplyPanel(t, it.ok and "raised" or "goldSoft", it.ok and "border" or "bad")
      t.icon:SetTexture(it.icon or (ICON .. (it.ok and "Achievement_General" or "INV_Misc_QuestionMark")))
      t.text:SetText(it.text or "")
      t.mark:SetText(it.ok and "OK" or "!")
      t.mark:SetTextColor(Theme:Color(it.ok and "good" or "bad"))
      t:Show()
    end
    for i = #self.items + 1, #self.tiles do self.tiles[i]:Hide() end
    self:SetHeight(math.max(1, self:LayoutHeight()))
  end
  function box:LayoutHeight()
    local n = #self.items
    if n == 0 then return 0 end
    local rows = math.ceil(n / (self.cols or COLS))
    return rows * TILE_H + (rows - 1) * TILE_GAP + 6
  end
  return box
end

-- ------------------------------------------------------------------ bars
-- A ranked bar chart: items { label, fill (0..1), text, color = {r,g,b} }.
local BAR_H, BAR_GAP, LABEL_W, VALUE_W = 20, 4, 140, 110

function UI:BarList(parent)
  local box = CreateFrame("Frame", nil, parent)
  box:SetSize(560, 10)
  box.rows, box.items = {}, {}
  function box:SetItems(items)
    self.items = items or {}
    local w = (self:GetWidth() or 560)
    if w < 300 then w = 560 end
    local track = w - LABEL_W - VALUE_W - 16
    for i, it in ipairs(self.items) do
      local r = self.rows[i]
      if not r then
        r = CreateFrame("Frame", nil, self)
        r.label = UI.Text(r, "normal", "text")
        r.label:SetPoint("LEFT", 0, 0)
        r.label:SetWidth(LABEL_W)
        r.label:SetJustifyH("LEFT")
        r.track = r:CreateTexture(nil, "BACKGROUND")
        r.track:SetPoint("LEFT", LABEL_W + 8, 0)
        r.track:SetHeight(BAR_H - 6)
        r.track:SetColorTexture(Theme:Color("bg"))
        r.fill = r:CreateTexture(nil, "ARTWORK")
        r.fill:SetPoint("LEFT", r.track, "LEFT", 0, 0)
        r.fill:SetHeight(BAR_H - 6)
        r.value = UI.Text(r, "small", "body")
        r.value:SetPoint("LEFT", r.track, "RIGHT", 8, 0)
        self.rows[i] = r
      end
      r:SetSize(w, BAR_H)
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", 0, -(i - 1) * (BAR_H + BAR_GAP))
      r.track:SetWidth(track)
      r.fill:SetWidth(math.max(2, track * math.min(1, math.max(0, tonumber(it.fill) or 0))))
      if it.color then r.fill:SetColorTexture(it.color[1], it.color[2], it.color[3], 0.9)
      else r.fill:SetColorTexture(Theme:Color("gold")) end
      r.label:SetText(it.label or "")
      r.value:SetText(it.text or "")
      r:Show()
    end
    for i = #self.items + 1, #self.rows do self.rows[i]:Hide() end
    self:SetHeight(math.max(1, self:LayoutHeight()))
  end
  function box:LayoutHeight()
    local n = #self.items
    return n > 0 and (n * (BAR_H + BAR_GAP) + 4) or 0
  end
  return box
end

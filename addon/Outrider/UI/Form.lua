-- UI/Form.lua
-- Pages built from rows, so every /ride command can be a control (requirement
-- 2026-11-13: everything doable in the UI, no typed slash commands). A form is
-- a scrolling column of rows:
--   { "header", "Text" }                         section heading
--   { "note", "Text" or function }               muted help line (function = live text)
--   { "check", "Label", get, set, note }         toggle
--   { "buttons", { {"Label", fn}, ... } }         a row of buttons
--   { "input", "Label", "placeholder", "Button", fn(text), keep } text box + button
--   { "key", "Label", get, set(key or nil), note } press-a-key setter (right-click clears)
--   { "slider", "Label", min, max, step, get, set, fmt }
--   { "list", rows, render, onClick, getItems }   embedded scroll list
--   { "stats", getItems }                         hero row of 2-4 big numbers
-- form:Refresh() re-reads every check, slider, live note and list.

local _, ns = ...
local UI, Theme = ns.UI, ns.Theme

local ROW = { header = 28, note = 20, check = 30, buttons = 36, input = 34, slider = 44 }

function UI:Form(parent, rows)
  local scroll = CreateFrame("ScrollFrame", nil, parent)
  scroll:SetPoint("TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", 0, 0)
  local c = CreateFrame("Frame", nil, scroll)
  c:SetSize(620, 10)
  scroll:SetScrollChild(c)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local max = math.max(0, (c.height or 0) - (self:GetHeight() or 0))
    local v = math.max(0, math.min(max, (self:GetVerticalScroll() or 0) - delta * 40))
    self:SetVerticalScroll(v)
  end)
  -- the content follows the window's width, so cards stretch like Home's
  if scroll.HookScript then
    scroll:HookScript("OnSizeChanged", function(self, w)
      if type(w) == "number" and w > 200 then
        c:SetWidth(w - 14)
        if self.Layout and math.abs((self.laidWidth or 0) - w) > 2 then self.laidWidth = w self:Layout() end
      end
    end)
  end
  scroll.content, scroll.items = c, {}
  -- Layout engine (2026-11-16): rows are recorded in order and placed by
  -- Layout(), which measures text each time, so a live note that grows to
  -- three lines pushes the rows below it down instead of running over them.
  local entries = {}
  local host, pad, card = c, 0, nil
  local W = 600
  local function place(f, h, indent)
    entries[#entries + 1] = { f = f, h = h, indent = (indent or 0) + pad, card = card }
  end
  -- Full width (premium plan S1, 2026-11-18): rows that should span the page
  -- get the width that's actually there at layout time, not a fixed 560.
  local function stretch(e)
    if not e.stretch then return end
    local cw = c:GetWidth() or 620
    if cw < 200 then cw = 620 end
    local w = math.floor(cw - e.indent - (e.card and 22 or 6))
    if w < 160 then return end
    local cur = e.f.GetWidth and e.f:GetWidth() or 0
    if math.abs(cur - w) < 1 then return end
    e.f:SetWidth(w)
    if e.dynamic and e.dynamic.items and e.dynamic.SetItems then e.dynamic:SetItems(e.dynamic.items) end
    if e.table then e.table:SetItems(e.table.raw) end
  end
  local function measure(e)
    if e.f and e.f.LayoutHeight and not e.dynamic then
      local h = e.f:LayoutHeight()
      if type(h) == "number" then return h end
    end
    if e.dynamic then return e.dynamic:LayoutHeight() + (e.dynamic:LayoutHeight() > 0 and 6 or 0) end
    if e.text then
      local txt = e.text.GetText and e.text:GetText()
      if txt == nil or txt == "" then return 0 end
      local sh = e.text.GetStringHeight and e.text:GetStringHeight()
      return math.max(e.h, (type(sh) == "number" and sh or 0) + 8)
    end
    return e.h
  end
  function scroll:Layout()
    local y, open = 0, nil
    for _, e in ipairs(entries) do
      if e.cardOpen then
        e.cardOpen:ClearAllPoints()
        e.cardOpen:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y)
        e.cardOpen:SetPoint("RIGHT", c, "RIGHT", -4, 0)
        open = { card = e.cardOpen, top = y }
        y = y + 14
      elseif e.cardClose then
        if open then
          y = y + 10
          open.card:SetHeight(y - open.top)
          y = y + 12
          open = nil
        end
      else
        stretch(e)
        local h = measure(e)
        e.y = y
        e.f:ClearAllPoints()
        e.f:SetPoint("TOPLEFT", c, "TOPLEFT", e.indent, -y)
        y = y + h
      end
    end
    c.height = y + 10
    c:SetHeight(c.height)
    if scroll.UpdateBar then scroll:UpdateBar() end
  end
  local function closeCard()
    if not card then return end
    entries[#entries + 1] = { cardClose = true }
    card, host, pad, W = nil, c, 0, 600
  end
  -- A card: picture tile, title in the display font, a hairline.
  local function openCard(title, icon)
    closeCard()
    card = UI:Card(c, true)
    entries[#entries + 1] = { cardOpen = card }
    host, pad, W = card, 18, 560
    scroll.cards = scroll.cards or {}
    scroll.cards[#scroll.cards + 1] = card
    if not title then return end
    local head = CreateFrame("Frame", nil, card)
    head:SetSize(W, 40)
    head.tile = CreateFrame("Frame", nil, head, Theme:BackdropTemplate())
    head.tile:SetSize(34, 34)
    head.tile:SetPoint("LEFT", 0, 0)
    Theme:ApplyPanel(head.tile, "bg", "gold")
    head.pic = head.tile:CreateTexture(nil, "ARTWORK")
    head.pic:SetPoint("TOPLEFT", 2, -2)
    head.pic:SetPoint("BOTTOMRIGHT", -2, 2)
    UI.SectionPicture(head.pic, title, icon, parent)
    local t = UI.Display(head, "card", "goldText")
    t:SetPoint("LEFT", head.tile, "RIGHT", 12, 0)
    t:SetText(title)
    head.title = t
    card.title = t
    local rule = head:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", head.tile, "BOTTOMRIGHT", 12, -2)
    rule:SetPoint("RIGHT", card, "RIGHT", -18, 0)
    local r, g, b = Theme:Color("gold")
    rule:SetColorTexture(r, g, b, 0.35)
    place(head, 48)
    entries[#entries].searchLabel = title
  end
  local titled = false
  for _, r in ipairs(rows) do
    local kind = r[1]
    -- rows between the page title and the first section get an untitled card
    -- (a stat strip sits straight under the page title, outside any card)
    if kind ~= "header" and kind ~= "stats" and titled and not card then openCard(nil) end
    if kind == "header" then
      -- the page's first heading is its title: in the hub's title strip when
      -- the page has one, else large in the display font; later headings
      -- open a card with a gold title and a hairline
      if not titled then
        titled = true
        local same = parent.hubTitle and tostring(parent.hubTitle:GetText() or ""):lower() == tostring(r[2]):lower()
        if parent.hubTitle and not same then
          openCard(r[2], r.icon)
        elseif parent.hubTitle then
          card = card -- the hero already says it
        else
          local t = UI.Display(c, "page", "text")
          t:SetText(r[2])
          place(t, 42)
        end
      else
        openCard(r[2], r.icon)
      end
    elseif kind == "note" then
      local t = UI.Text(host, "normal", "body")
      t:SetWidth(W)
      t:SetJustifyH("LEFT")
      if t.SetSpacing then t:SetSpacing(2) end
      local src = r[2]
      t:SetText(type(src) == "function" and "" or src)
      if type(src) == "function" then scroll.items[#scroll.items + 1] = { note = t, fn = src } end
      -- measured by Layout: a long note takes the lines it needs
      place(t, r[3] or ROW.note)
      entries[#entries].text = t
      entries[#entries].stretch = true
    elseif kind == "check" then
      local chk = UI:Check(host, r[2], r[3], r[4])
      if r[5] then chk.note:SetText(r[5]) end
      place(chk, ROW.check)
      entries[#entries].searchLabel = r[2]
      scroll.items[#scroll.items + 1] = chk
    elseif kind == "buttons" then
      local row = CreateFrame("Frame", nil, host)
      row:SetSize(W, 26)
      local prev
      local btns = {}
      for _, b in ipairs(r[2]) do
        local btn = UI:Button(row, b[1], b[3] or math.max(110, #b[1] * 7 + 28), b[2])
        btn:SetHeight(26)
        if not prev and not r.plain and not r.active then UI.SetPrimary(btn, true) end
        if prev then btn:SetPoint("LEFT", prev, "RIGHT", 8, 0) else btn:SetPoint("LEFT", 0, 0) end
        prev = btn
        btns[#btns + 1] = btn
      end
      -- a filter row (tour 2026-11-19): r.active(i) says which button is the
      -- current choice, and only that one is gold, so gold never looks chosen
      -- when it isn't ("In my zone" was gold while everyone was listed)
      if type(r.active) == "function" then
        row.Refresh = function()
          for i, btn in ipairs(btns) do UI.SetPrimary(btn, r.active(i) and true or false) end
        end
        row.Refresh()
        scroll.items[#scroll.items + 1] = row
      end
      place(row, ROW.buttons)
    elseif kind == "input" then
      local row = CreateFrame("Frame", nil, host)
      row:SetSize(W, 26)
      local label = UI.Text(row, "normal", "text")
      label:SetPoint("LEFT", 0, 0)
      label:SetWidth(170)
      label:SetJustifyH("LEFT")
      label:SetText(r[2])
      local box = UI:SearchBox(row, 230, r[3])
      box:SetPoint("LEFT", label, "RIGHT", 6, 0)
      local fn, keep = r[5], r[6]
      local function run()
        ns.Safe("form:" .. r[2], fn, box:GetText() or "")
        if not keep then box:SetText("") end
        box:ClearFocus()
        if scroll.Refresh then scroll:Refresh() end
      end
      local btn = UI:Button(row, r[4] or "Go", 90, run)
      btn:SetPoint("LEFT", box, "RIGHT", 6, 0)
      box:SetScript("OnEnterPressed", run)
      -- the box and the button explain the row: "<label>: e.g. <example>"
      local _, what = UI.TipFor(r[4] or "Go")
      local tip = (what and (what .. " ") or "") .. "Type here, e.g. " .. tostring(r[3] or "") .. ", then press Enter."
      UI.Tip(box, r[2], tip)
      UI.Tip(btn, r[2], tip)
      row.box, row.button = box, btn
      place(row, ROW.input)
      entries[#entries].searchLabel = r[2]
    elseif kind == "key" then
      -- { "key", "Label", get, set(key or nil), note }: click, then press a key
      -- (or a mouse side/middle button); right-click clears; Escape cancels.
      local row = CreateFrame("Frame", nil, host)
      row:SetSize(W, 26)
      local label = UI.Text(row, "normal", "text")
      label:SetPoint("LEFT", 0, 0)
      label:SetWidth(170)
      label:SetJustifyH("LEFT")
      label:SetText(r[2])
      local get, set = r[3], r[4]
      local btn
      local function show() btn.label:SetText(btn.capturing and "Press a key..." or (get() or "Not set")) end
      local function stop() btn.capturing = false if btn.EnableKeyboard then btn:EnableKeyboard(false) end show() end
      local MODS = { LSHIFT = 1, RSHIFT = 1, LCTRL = 1, RCTRL = 1, LALT = 1, RALT = 1, LMETA = 1, RMETA = 1 }
      local MOUSE = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }
      local function take(key)
        local mods = (IsAltKeyDown and IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown and IsControlKeyDown() and "CTRL-" or "")
          .. (IsShiftKeyDown and IsShiftKeyDown() and "SHIFT-" or "")
        ns.Safe("form:key:" .. r[2], set, mods .. key)
        stop()
      end
      btn = UI:Button(row, "Not set", 160, function(self, button)
        if button == "RightButton" then ns.Safe("form:key:" .. r[2], set, nil) stop() return end
        self.capturing = true
        if self.EnableKeyboard then self:EnableKeyboard(true) end
        show()
      end)
      if btn.RegisterForClicks then btn:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
      btn:SetScript("OnKeyDown", function(self, key)
        if not self.capturing or MODS[key] then return end
        if key == "ESCAPE" then stop() return end
        take(key)
      end)
      btn:SetScript("OnMouseDown", function(self, button)
        if self.capturing and MOUSE[button] then take(MOUSE[button]) end
      end)
      btn:SetPoint("LEFT", label, "RIGHT", 6, 0)
      if r[5] then
        local note = UI.Text(row, "small", "muted")
        note:SetPoint("LEFT", btn, "RIGHT", 8, 0)
        note:SetText(r[5])
      end
      row.button = btn
      row.Refresh = show
      show()
      place(row, ROW.input)
      entries[#entries].searchLabel = r[2]
      scroll.items[#scroll.items + 1] = row
    elseif kind == "slider" then
      local s = UI:Slider(host, r[2], r[3], r[4], r[5], r[6], r[7], r[8])
      s:SetWidth(320)
      UI.Tip(s, r[2], "Drag to change it, from " .. tostring(r[3]) .. " to " .. tostring(r[4]) .. ".")
      place(s, ROW.slider)
      entries[#entries].searchLabel = r[2]
      scroll.items[#scroll.items + 1] = { slider = s, get = r[6] }
    elseif kind == "list" then
      local list = UI:ScrollList(host, { rows = r[2], rowHeight = 22, render = r[3], onClick = r[4] })
      list:SetWidth(W)
      place(list, r[2] * 22 + 10)
      entries[#entries].stretch = true
      -- an empty list shows a picture and a line instead of a blank box
      -- (tour 2026-11-19): { "list", ..., empty = "text", emptyArt = "empty_quiet" }
      if r.empty then
        local e = CreateFrame("Frame", nil, list)
        e:SetAllPoints()
        e.pic = e:CreateTexture(nil, "ARTWORK")
        e.pic:SetSize(128, 64)
        e.pic:SetPoint("CENTER", 0, 12)
        e.text = UI.Text(e, "normal", "muted")
        e.text:SetPoint("TOP", e.pic, "BOTTOM", 0, -6)
        e.text:SetText(r.empty)
        if not (ns.Art and ns.Art:Set(e.pic, r.emptyArt or "empty_quiet")) then
          e.pic:Hide()
          e.text:ClearAllPoints()
          e.text:SetPoint("CENTER")
        end
        e:Hide()
        list.emptyView = e
      end
      scroll.items[#scroll.items + 1] = { list = list, getItems = r[5] }
    elseif kind == "cards" or kind == "tiles" or kind == "bars" or kind == "stats" then
      -- { "cards", getItems } / { "tiles", getItems } / { "bars", getItems } /
      -- { "stats", getItems } (the hero row of big numbers): premium blocks (UI/Premium.lua)
      local f = kind == "cards" and UI:CardList(host) or kind == "bars" and UI:BarList(host)
        or kind == "stats" and UI:StatStrip(host) or UI:StatusTiles(host)
      f:SetWidth(W)
      if r.compact then f.compact = true end
      f.getItems = r[2]
      f.Refresh = function(self)
        -- a block that errors is recorded (Tools page, tests), never silently blank
        local ok, items = ns.Safe("form:" .. kind, self.getItems)
        self:SetItems(ok and items or {})
      end
      f:Refresh()
      place(f, 0)
      entries[#entries].dynamic = f
      entries[#entries].stretch = true
      scroll.items[#scroll.items + 1] = f
    elseif kind == "table" then
      -- { "table", rows, cols, getItems, onClick, sortKey = , desc = }: a sortable table
      local tb = UI:Table(host, r[3], { rows = r[2], onClick = r[5], sortKey = r.sortKey, desc = r.desc })
      tb:SetWidth(W)
      tb.getItems = r[4]
      tb.Refresh = function(self)
        local ok, items = ns.Safe("form:table", self.getItems)
        self:SetItems(ok and items or {})
      end
      tb:Refresh()
      place(tb, tb:LayoutHeight())
      entries[#entries].stretch = true
      entries[#entries].table = tb
      scroll.items[#scroll.items + 1] = tb
    elseif kind == "custom" then
      local f = r[2](host)
      place(f, r[3] or 30)
      -- { "custom", build, height, stretch = true }: the frame takes the page's
      -- width, and its own LayoutHeight() (if any) sets the row height
      if r.stretch then entries[#entries].stretch = true end
      if f.Refresh then scroll.items[#scroll.items + 1] = f end
    end
  end
  closeCard()

  -- A slim gold scroll bar and a fade at the bottom whenever the page is
  -- taller than the window (premium plan S3), so nothing looks cut off.
  local track = CreateFrame("Frame", nil, parent)
  track:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", -1, -2)
  track:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", -1, 2)
  track:SetWidth(4)
  track.bg = track:CreateTexture(nil, "BACKGROUND")
  track.bg:SetAllPoints()
  track.bg:SetColorTexture(Theme:Color("raised"))
  track.thumb = track:CreateTexture(nil, "ARTWORK")
  track.thumb:SetWidth(4)
  track.thumb:SetColorTexture(Theme:Color("gold"))
  local fade = parent:CreateTexture(nil, "OVERLAY")
  fade:SetPoint("BOTTOMLEFT", scroll, "BOTTOMLEFT", 0, 0)
  fade:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", -8, 0)
  fade:SetHeight(28)
  fade:SetColorTexture(1, 1, 1, 1)
  local br, bgc, bb = Theme:Color("bg")
  if fade.SetGradient and CreateColor then
    pcall(fade.SetGradient, fade, "VERTICAL", CreateColor(br, bgc, bb, 0.95), CreateColor(br, bgc, bb, 0))
  else
    fade:SetColorTexture(br, bgc, bb, 0.6)
  end
  scroll.track, scroll.fade = track, fade
  function scroll:UpdateBar()
    local view = self:GetHeight() or 0
    local total = c.height or 0
    local over = total - view
    if view < 40 or over <= 4 then track:Hide() fade:Hide() return end
    local pos = math.max(0, math.min(over, self:GetVerticalScroll() or 0))
    local th = math.max(24, (track:GetHeight() or view) * view / total)
    local room = math.max(0, (track:GetHeight() or view) - th)
    track.thumb:ClearAllPoints()
    track.thumb:SetPoint("TOP", track, "TOP", 0, -room * pos / over)
    track.thumb:SetHeight(th)
    track:Show()
    fade:SetShown(pos < over - 4)
  end
  scroll:HookScript("OnMouseWheel", function(self) self:UpdateBar() end)
  scroll:Layout()

  -- Search the actual control labels and jump to their measured positions.
  function scroll:FindSetting(query)
    query = type(query) == "string" and query:lower():match("^%s*(.-)%s*$") or ""
    if query == "" then return nil, 0 end
    local matches = {}
    for _, e in ipairs(entries) do
      if type(e.searchLabel) == "string" and e.searchLabel:lower():find(query, 1, true) then
        matches[#matches + 1] = e
      end
    end
    if #matches == 0 then return nil, 0 end
    if self.lastSearch == query then
      self.searchIndex = (self.searchIndex or 0) % #matches + 1
    else
      self.lastSearch, self.searchIndex = query, 1
    end
    local match = matches[self.searchIndex]
    if self.SetVerticalScroll then self:SetVerticalScroll(match.y or 0) end
    return match.searchLabel, #matches
  end

  -- Every match at once, grouped by its card (gallery idea from Leatrix Plus,
  -- 2026-11-18): { label, section, y, on = true|false|nil (switches only) }.
  function scroll:SearchAll(query)
    query = type(query) == "string" and query:lower():match("^%s*(.-)%s*$") or ""
    local out = {}
    if query == "" then return out end
    for _, e in ipairs(entries) do
      local section = e.card and e.card.title and e.card.title.GetText and e.card.title:GetText() or nil
      local hit = type(e.searchLabel) == "string" and (e.searchLabel:lower():find(query, 1, true)
        or (section and section:lower():find(query, 1, true)))
      if hit and e.searchLabel ~= section then -- the card's own heading isn't a setting
        out[#out + 1] = { label = e.searchLabel, section = section or "", y = e.y or 0,
          on = type(e.f) == "table" and e.f.on ~= nil and e.f.on or nil }
      end
    end
    return out
  end
  function scroll:JumpTo(y) if self.SetVerticalScroll then self:SetVerticalScroll(math.max(0, (y or 0) - 8)) self:UpdateBar() end end

  function scroll:Refresh()
    for _, it in ipairs(self.items) do
      if it.Refresh then ns.Safe("form:refresh", it.Refresh, it)
      elseif it.note then
        local ok, text = pcall(it.fn)
        it.note:SetText(ok and tostring(text or "") or "")
      elseif it.slider and it.get then
        local ok, v = pcall(it.get)
        if ok and v then it.slider.slider:SetValue(v) end
      elseif it.list and it.getItems then
        local ok, items = pcall(it.getItems)
        items = ok and items or {}
        it.list:SetItems(items)
        if it.list.emptyView then it.list.emptyView:SetShown(#items == 0) end
      end
    end
    self:Layout()
  end
  return scroll
end

-- A section's picture: the row's icon, a known one for its title, else the
-- page's own picture.
function UI.SectionPicture(tex, title, icon, page)
  local I = "Interface\\Icons\\"
  local secs = ns.Tips and ns.Tips.sections or {}
  local known = icon or secs[title]
  if not known and type(title) == "string" then
    for k, v in pairs(secs) do if title:find(k, 1, true) == 1 then known = v break end end
  end
  if known then
    tex:SetTexture(known:find("\\", 1, true) and known or (I .. known))
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  elseif page and page.hubPic and page.hubPic.GetTexture then
    tex:SetTexture(page.hubPic:GetTexture())
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  else
    tex:SetTexture(I .. "INV_Misc_Book_09")
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
end

-- A page that is just a form: p.Refresh re-reads it.
function UI:FormPage(p, rows)
  p.form = UI:Form(p, rows)
  function p:Refresh() self.form:Refresh() end
  return p.form
end

-- Run a /ride command from a button (same code path as typing it).
function UI.Run(line) return function() ns.Slash:Run(line) end end

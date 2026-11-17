-- UI/Form.lua
-- Pages built from rows, so every /ride command can be a control (Gary,
-- 2026-11-13: "do everything in the UI, no typing slash commands"). A form is
-- a scrolling column of rows:
--   { "header", "Text" }                         section heading
--   { "note", "Text" or function }               muted help line (function = live text)
--   { "check", "Label", get, set, note }         toggle
--   { "buttons", { {"Label", fn}, ... } }         a row of buttons
--   { "input", "Label", "placeholder", "Button", fn(text), keep } text box + button
--   { "key", "Label", get, set(key or nil), note } press-a-key setter (right-click clears)
--   { "slider", "Label", min, max, step, get, set, fmt }
--   { "list", rows, render, onClick, getItems }   embedded scroll list
-- form:Refresh() re-reads every check, slider, live note and list.

local _, ns = ...
local UI, Theme = ns.UI, ns.Theme

local ROW = { header = 28, note = 18, check = 24, buttons = 30, input = 32, slider = 44 }

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
    scroll:HookScript("OnSizeChanged", function(self, w) if type(w) == "number" and w > 200 then c:SetWidth(w - 8) end end)
  end
  scroll.content, scroll.items = c, {}
  local y = 0
  -- Expedition look (2026-11-15): every section after a heading sits in a
  -- card. Rows are created on the current card (host) so they draw above it;
  -- all are anchored to the content frame.
  local host, pad, cardTop, card = c, 0, nil, nil
  local W = 600
  local function place(f, h, indent)
    f:SetPoint("TOPLEFT", c, "TOPLEFT", (indent or 0) + pad, -y)
    y = y + h
  end
  local function closeCard()
    if not card then return end
    y = y + 8
    card:SetHeight(y - cardTop)
    y = y + 10
    card, host, pad, W = nil, c, 0, 600
  end
  local function openCard(title)
    closeCard()
    card = UI:Card(c)
    card:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y)
    card:SetPoint("RIGHT", c, "RIGHT", -4, 0)
    cardTop, host, pad, W = y, card, 14, 572
    scroll.cards = scroll.cards or {}
    scroll.cards[#scroll.cards + 1] = card
    y = y + 10
    if not title then return end
    local t = UI.Display(card, "side", "goldText")
    t:SetText(title)
    card.title = t
    local rule = card:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", c, "TOPLEFT", pad, -(y + 22))
    rule:SetPoint("RIGHT", card, "RIGHT", -pad, 0)
    rule:SetColorTexture(Theme:Color("border"))
    place(t, ROW.header + 4)
  end
  local titled = false
  for _, r in ipairs(rows) do
    local kind = r[1]
    -- rows between the page title and the first section get an untitled card
    if kind ~= "header" and titled and not card then openCard(nil) end
    if kind == "header" then
      -- the page's first heading is its title: in the hub's title strip when
      -- the page has one, else large in the display font; later headings
      -- open a card with a gold title and a hairline
      if not titled then
        titled = true
        if parent.hubTitle then
          parent.hubTitle:SetText(r[2])
        else
          local t = UI.Display(c, "page", "text")
          t:SetText(r[2])
          place(t, 42)
        end
      else
        openCard(r[2])
      end
    elseif kind == "note" then
      local t = UI.Text(host, "small", "muted")
      t:SetWidth(W)
      t:SetJustifyH("LEFT")
      local src = r[2]
      t:SetText(type(src) == "function" and "" or src)
      if type(src) == "function" then scroll.items[#scroll.items + 1] = { note = t, fn = src } end
      -- a long note takes the lines it needs instead of running into the next row
      local h = type(src) == "string" and t.GetStringHeight and t:GetStringHeight() or nil
      if type(h) ~= "number" then h = nil end
      place(t, r[3] or math.max(ROW.note, (h or 0) + 6))
    elseif kind == "check" then
      local chk = UI:Check(host, r[2], r[3], r[4])
      if r[5] then chk.note:SetText(r[5]) end
      place(chk, ROW.check)
      scroll.items[#scroll.items + 1] = chk
    elseif kind == "buttons" then
      local row = CreateFrame("Frame", nil, host)
      row:SetSize(W, 26)
      local prev
      for _, b in ipairs(r[2]) do
        local btn = UI:Button(row, b[1], b[3] or math.max(90, #b[1] * 7 + 20), b[2])
        if prev then btn:SetPoint("LEFT", prev, "RIGHT", 6, 0) else btn:SetPoint("LEFT", 0, 0) end
        prev = btn
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
      scroll.items[#scroll.items + 1] = row
    elseif kind == "slider" then
      local s = UI:Slider(host, r[2], r[3], r[4], r[5], r[6], r[7], r[8])
      s:SetWidth(320)
      UI.Tip(s, r[2], "Drag to change it, from " .. tostring(r[3]) .. " to " .. tostring(r[4]) .. ".")
      place(s, ROW.slider)
      scroll.items[#scroll.items + 1] = { slider = s, get = r[6] }
    elseif kind == "list" then
      local list = UI:ScrollList(host, { rows = r[2], rowHeight = 22, render = r[3], onClick = r[4] })
      list:SetWidth(W)
      place(list, r[2] * 22 + 10)
      scroll.items[#scroll.items + 1] = { list = list, getItems = r[5] }
    elseif kind == "custom" then
      local f = r[2](host)
      place(f, r[3] or 30)
      if f.Refresh then scroll.items[#scroll.items + 1] = f end
    end
  end
  closeCard()
  c.height = y + 10
  c:SetHeight(c.height)
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
        it.list:SetItems(ok and items or {})
      end
    end
  end
  return scroll
end

-- A page that is just a form: p.Refresh re-reads it.
function UI:FormPage(p, rows)
  p.form = UI:Form(p, rows)
  function p:Refresh() self.form:Refresh() end
  return p.form
end

-- Run a /ride command from a button (same code path as typing it).
function UI.Run(line) return function() ns.Slash:Run(line) end end

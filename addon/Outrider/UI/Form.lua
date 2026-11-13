-- UI/Form.lua
-- Pages built from rows, so every /ride command can be a control (Gary,
-- 2026-11-13: "do everything in the UI, no typing slash commands"). A form is
-- a scrolling column of rows:
--   { "header", "Text" }                         section heading
--   { "note", "Text" or function }               muted help line (function = live text)
--   { "check", "Label", get, set, note }         toggle
--   { "buttons", { {"Label", fn}, ... } }         a row of buttons
--   { "input", "Label", "placeholder", "Button", fn(text), keep } text box + button
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
  scroll.content, scroll.items = c, {}
  local y = 0
  local function place(f, h, indent)
    f:SetPoint("TOPLEFT", indent or 0, -y)
    y = y + h
  end
  for _, r in ipairs(rows) do
    local kind = r[1]
    if kind == "header" then
      if y > 0 then y = y + 6 end
      local t = UI.Text(c, "large", "accent")
      t:SetText(r[2])
      place(t, ROW.header)
    elseif kind == "note" then
      local t = UI.Text(c, "small", "muted")
      t:SetWidth(600)
      t:SetJustifyH("LEFT")
      local src = r[2]
      t:SetText(type(src) == "function" and "" or src)
      if type(src) == "function" then scroll.items[#scroll.items + 1] = { note = t, fn = src } end
      place(t, r[3] or ROW.note)
    elseif kind == "check" then
      local chk = UI:Check(c, r[2], r[3], r[4])
      if r[5] then chk.note:SetText(r[5]) end
      place(chk, ROW.check)
      scroll.items[#scroll.items + 1] = chk
    elseif kind == "buttons" then
      local row = CreateFrame("Frame", nil, c)
      row:SetSize(600, 26)
      local prev
      for _, b in ipairs(r[2]) do
        local btn = UI:Button(row, b[1], b[3] or math.max(90, #b[1] * 7 + 20), b[2])
        if prev then btn:SetPoint("LEFT", prev, "RIGHT", 6, 0) else btn:SetPoint("LEFT", 0, 0) end
        prev = btn
      end
      place(row, ROW.buttons)
    elseif kind == "input" then
      local row = CreateFrame("Frame", nil, c)
      row:SetSize(600, 26)
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
      row.box, row.button = box, btn
      place(row, ROW.input)
    elseif kind == "slider" then
      local s = UI:Slider(c, r[2], r[3], r[4], r[5], r[6], r[7], r[8])
      s:SetWidth(320)
      place(s, ROW.slider)
      scroll.items[#scroll.items + 1] = { slider = s, get = r[6] }
    elseif kind == "list" then
      local list = UI:ScrollList(c, { rows = r[2], rowHeight = 22, render = r[3], onClick = r[4] })
      list:SetWidth(600)
      place(list, r[2] * 22 + 10)
      scroll.items[#scroll.items + 1] = { list = list, getItems = r[5] }
    elseif kind == "custom" then
      local f = r[2](c)
      place(f, r[3] or 30)
      if f.Refresh then scroll.items[#scroll.items + 1] = f end
    end
  end
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

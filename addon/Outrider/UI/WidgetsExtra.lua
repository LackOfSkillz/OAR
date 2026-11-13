-- UI/WidgetsExtra.lua
-- More of the widget kit (P1-07): ScrollList, Tabs, Dropdown, Slider,
-- SearchBox. All token-driven (ns.Theme), all insecure. The dropdown is our
-- own frame: UIDropDownMenu is shared with Blizzard menus and taints them.

local _, ns = ...
local UI, Theme = ns.UI, ns.Theme

-- ------------------------------------------------------------ ScrollList
-- Virtualized: only `rows` row frames exist; scrolling changes which items
-- they show. render(row, item, index) fills a row; build(row) (optional)
-- adds per-row children once.
function UI:ScrollList(parent, opts)
  opts = opts or {}
  local rowH = opts.rowHeight or 22
  local list = CreateFrame("Frame", nil, parent, Theme:BackdropTemplate())
  Theme:ApplyPanel(list, "panel")
  list.rowH, list.offset, list.items, list.rowFrames = rowH, 0, {}, {}
  list.render = opts.render or function(row, item) row.text:SetText(tostring(item)) end
  local n = opts.rows or 10
  list:SetHeight(n * rowH + 4)
  for i = 1, n do
    local row = CreateFrame("Button", nil, list)
    row:SetHeight(rowH)
    row:SetPoint("TOPLEFT", 2, -2 - (i - 1) * rowH)
    row:SetPoint("RIGHT", list, "RIGHT", -2, 0)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    local hr, hg, hb = Theme:Color("accent")
    hl:SetColorTexture(hr, hg, hb, 0.15) -- see-through: the highlight layer draws over the text
    row.text = UI.Text(row, "normal", "text")
    row.text:SetPoint("LEFT", 6, 0)
    row.text:SetPoint("RIGHT", -6, 0)
    row.text:SetJustifyH("LEFT")
    if row.text.SetWordWrap then row.text:SetWordWrap(false) end -- long lines end in "..." instead of spilling
    if opts.build then opts.build(row) end
    row:SetScript("OnClick", function(self, button)
      if opts.onClick and self.item ~= nil then ns.Safe("list:click", opts.onClick, self.item, self.index, button) end
    end)
    list.rowFrames[i] = row
  end
  list:EnableMouseWheel(true)
  list:SetScript("OnMouseWheel", function(self, delta) self:Scroll(-delta * (opts.wheelStep or 3)) end)

  function list:MaxOffset() return math.max(0, #self.items - #self.rowFrames) end
  function list:SetOffset(o)
    self.offset = math.max(0, math.min(math.floor(o), self:MaxOffset()))
    self:Refresh()
  end
  function list:Scroll(d) self:SetOffset(self.offset + d) end
  function list:SetItems(items)
    self.items = items or {}
    self:SetOffset(self.offset)
  end
  function list:Refresh()
    for i, row in ipairs(self.rowFrames) do
      local idx = self.offset + i
      local item = self.items[idx]
      row.item, row.index = item, idx
      if item ~= nil then
        ns.Safe("list:render", self.render, row, item, idx)
        row:Show()
      else
        row:Hide()
      end
    end
  end
  -- Items currently on screen (used by tests and by "visible only" work).
  function list:VisibleItems()
    local out = {}
    for _, row in ipairs(self.rowFrames) do if row.item ~= nil and row:IsShown() then out[#out + 1] = row.item end end
    return out
  end
  return list
end

-- ------------------------------------------------------------ Tabs
-- tabs = { { id, title }, ... }; onSelect(id). :Select(id) switches.
-- vertical = width of a sidebar: one tab per line, growing downward (the hub
-- outgrew one row of tabs, Gary's screenshot 2026-11-11).
function UI:Tabs(parent, tabs, onSelect, vertical)
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetHeight(24)
  if vertical then bar:SetWidth(vertical) end
  bar.buttons, bar.order = {}, {}
  local prev
  local function place(b, after)
    b:ClearAllPoints()
    if vertical then
      if after then b:SetPoint("TOPLEFT", after, "BOTTOMLEFT", 0, -3) else b:SetPoint("TOPLEFT", 0, 0) end
    else
      if after then b:SetPoint("LEFT", after, "RIGHT", 4, 0) else b:SetPoint("LEFT", 0, 0) end
    end
  end
  function bar:Add(id, title)
    local b = UI:Button(self, title, vertical or math.max(70, #title * 7 + 20), function() self:Select(id) end)
    b:SetHeight(22)
    if vertical and b.label then b.label:ClearAllPoints() b.label:SetPoint("LEFT", 10, 0) end
    place(b, prev)
    prev = b
    b.id = id
    self.buttons[id] = b
    self.order[#self.order + 1] = id
    return b
  end
  -- Re-anchor buttons in the given id order (tabs added later by modules).
  function bar:SetOrder(ids)
    local seen, order = {}, {}
    for _, id in ipairs(ids) do if self.buttons[id] and not seen[id] then order[#order + 1] = id seen[id] = true end end
    for _, id in ipairs(self.order) do if not seen[id] then order[#order + 1] = id end end
    self.order = order
    local last
    for _, id in ipairs(order) do
      local b = self.buttons[id]
      place(b, last)
      last = b
    end
    prev = last
  end
  function bar:Select(id)
    if not self.buttons[id] then id = self.order[1] end
    if not id then return end
    self.selected = id
    for tid, b in pairs(self.buttons) do
      b.label:SetTextColor(Theme:Color(tid == id and "accent" or "muted"))
      if b.SetBackdropColor then b:SetBackdropColor(Theme:Color(tid == id and "raised" or "panel")) end
    end
    if onSelect then ns.Safe("tabs:select", onSelect, id) end
  end
  for _, t in ipairs(tabs or {}) do bar:Add(t[1], t[2]) end
  return bar
end

-- ------------------------------------------------------------ Dropdown
-- options = { { value, label }, ... }; get() returns current value; set(value).
function UI:Dropdown(parent, width, options, get, set)
  local dd = UI:Button(parent, "", width or 160)
  dd.options = options or {}
  local menu = CreateFrame("Frame", nil, dd, Theme:BackdropTemplate())
  menu:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -2)
  menu:SetWidth(width or 160)
  menu:SetFrameStrata("FULLSCREEN_DIALOG")
  Theme:ApplyPanel(menu, "raised")
  menu:Hide()
  menu.items = {}
  dd.menu = menu

  function dd:Label()
    local v = get and get()
    for _, o in ipairs(self.options) do if o[1] == v then return o[2] end end
    return tostring(v or "-")
  end
  function dd:Refresh() self.label:SetText(self:Label() .. "  v") end
  function dd:Choose(value)
    if set then ns.Safe("dropdown:set", set, value) end
    menu:Hide()
    self:Refresh()
  end
  function dd:Open()
    for _, b in ipairs(menu.items) do b:Hide() end
    for i, o in ipairs(self.options) do
      local b = menu.items[i] or UI:Button(menu, "", (width or 160) - 8)
      menu.items[i] = b
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 24)
      b.label:SetText(o[2])
      b:SetScript("OnClick", function() dd:Choose(o[1]) end)
      b:Show()
    end
    menu:SetHeight(8 + #self.options * 24)
    menu:Show()
  end
  dd:SetScript("OnClick", function(self) if menu:IsShown() then menu:Hide() else self:Open() end end)
  dd:Refresh()
  return dd
end

-- ------------------------------------------------------------ Slider
function UI:Slider(parent, label, minV, maxV, step, get, set, fmt)
  local wrap = CreateFrame("Frame", nil, parent)
  wrap:SetSize(260, 40)
  wrap.label = UI.Text(wrap, "normal", "text")
  wrap.label:SetPoint("TOPLEFT", 0, 0)
  wrap.value = UI.Text(wrap, "normal", "accent")
  wrap.value:SetPoint("TOPRIGHT", 0, 0)
  local s = CreateFrame("Slider", nil, wrap, Theme:BackdropTemplate())
  s:SetOrientation("HORIZONTAL")
  s:SetHeight(12)
  s:SetPoint("BOTTOMLEFT", 0, 4)
  s:SetPoint("BOTTOMRIGHT", 0, 4)
  Theme:ApplyPanel(s, "raised")
  s:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
  local thumb = s:GetThumbTexture()
  if thumb then thumb:SetSize(10, 14) thumb:SetVertexColor(Theme:Color("accent")) end
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step or 1)
  s:SetObeyStepOnDrag(true)
  wrap.slider = s
  local function show(v) wrap.value:SetText(string.format(fmt or "%s", v)) end
  wrap.label:SetText(label)
  local cur = (get and get()) or minV
  s:SetValue(cur)
  show(cur)
  s:SetScript("OnValueChanged", function(_, v)
    if step then v = math.floor(v / step + 0.5) * step end
    show(v)
    if set then ns.Safe("slider:" .. label, set, v) end
  end)
  return wrap
end

-- ------------------------------------------------------------ SearchBox
-- onChange(text) runs throttled (0.2 s, trailing) so filtering a long list
-- doesn't run on every keystroke.
function UI:SearchBox(parent, width, placeholder, onChange)
  local box = CreateFrame("EditBox", nil, parent, Theme:BackdropTemplate())
  box:SetSize(width or 200, 22)
  box:SetAutoFocus(false)
  box:SetFontObject("ChatFontNormal")
  box:SetTextInsets(6, 6, 0, 0)
  Theme:ApplyPanel(box, "raised")
  box.hint = UI.Text(box, "normal", "muted")
  box.hint:SetPoint("LEFT", 6, 0)
  box.hint:SetPoint("RIGHT", -6, 0) -- the hint stays inside the box
  box.hint:SetJustifyH("LEFT")
  if box.hint.SetWordWrap then box.hint:SetWordWrap(false) end
  box.hint:SetText(placeholder or "Search")
  local key = "search:" .. tostring(box)
  box:SetScript("OnTextChanged", function(self)
    local t = self:GetText() or ""
    self.hint:SetShown(t == "")
    if onChange then ns.Throttle(key, 0.2, onChange, t) end
  end)
  box:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
  box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  return box
end

-- ------------------------------------------------------------ test window
-- /ride selftest widgets: one window showing every widget, for a screenshot.
function UI:WidgetTest()
  local w = self.widgetTest
  if not w then
    w = self:Window("Outrider_WidgetTest", "Outrider widget test", 460, 420)
    local c = w.content
    local items = {}
    for i = 1, 60 do items[i] = "Row " .. i end
    w.tabs = self:Tabs(c, { { "a", "First" }, { "b", "Second" }, { "c", "Third" } }, function(id) w.tabText:SetText("tab " .. id) end)
    w.tabs:SetPoint("TOPLEFT", 0, 0)
    w.tabs:SetPoint("RIGHT", 0, 0)
    w.tabText = self.Text(c, "small", "muted")
    w.tabText:SetPoint("TOPRIGHT", 0, -4)
    w.list = self:ScrollList(c, { rows = 8 })
    w.list:SetPoint("TOPLEFT", 0, -34)
    w.list:SetWidth(200)
    w.list:SetItems(items)
    w.search = self:SearchBox(c, 200, "Filter rows", function(t)
      local out = {}
      for _, s in ipairs(items) do if t == "" or s:lower():find(t:lower(), 1, true) then out[#out + 1] = s end end
      w.list:SetOffset(0)
      w.list:SetItems(out)
    end)
    w.search:SetPoint("TOPLEFT", w.list, "BOTTOMLEFT", 0, -8)
    local pick = "b"
    w.dropdown = self:Dropdown(c, 180, { { "a", "Option A" }, { "b", "Option B" }, { "c", "Option C" } },
      function() return pick end, function(v) pick = v end)
    w.dropdown:SetPoint("TOPLEFT", 220, -34)
    local val = 50
    w.slider = self:Slider(c, "Volume", 0, 100, 5, function() return val end, function(v) val = v end, "%d%%")
    w.slider:SetPoint("TOPLEFT", 220, -76)
    w.slider:SetWidth(200)
    w.accent = self:Check(c, "Class color accent", function() return ns.db.char.classAccent ~= false end, function(on)
      ns.db.char.classAccent = on
      ns.Print("class accent %s. /reload to apply.", on and "on" or "off")
    end)
    w.accent:SetPoint("TOPLEFT", 220, -130)
    w.accent:SetWidth(220)
    self.widgetTest = w
    w.tabs:Select("a")
  end
  w:Show()
  ns.Log:Info("selftest", "widget test window shown")
  return w
end

-- UI/Hub.lua
-- The one Outrider window, in tabs:
--   Overview    who you are, saved-settings check, errors, probe, detected addons
--   Modules     which modules are on for THIS character and why
--   Characters  every character Outrider knows, copy settings from one
--   Tools       export, import, errors, probe, debug, reload
-- Feature modules add tabs with ns.Hub:AddTab(id, title, build, order); build
-- receives the tab's panel once, and panel.Refresh (if set) runs each time
-- the tab is shown. The last tab is remembered per character.

local _, ns = ...
local Hub = { name = "hub", tabs = {}, byId = {} }
ns.Hub = Hub
local UI, Theme = ns.UI, ns.Theme

local MAX_ROWS = 18 -- visible module rows; the list scrolls with the mouse wheel
local W, H = 600, 480

local L = {
  overview = "Overview", modules = "Modules", characters = "Characters", tools = "Tools",
  modulesHeading = "Modules for this character",
  charsHint = "Click Copy to take that character's settings (then /reload).",
  noOthers = "no other characters saved yet: log in on another character once.",
}

function Hub:AddTab(id, title, build, order)
  if self.byId[id] then return self.byId[id] end
  local t = { id = id, title = title, build = build, order = order or (100 + #self.tabs) }
  self.tabs[#self.tabs + 1] = t
  self.byId[id] = t
  table.sort(self.tabs, function(a, b) return a.order < b.order end)
  if self.frame then self:AddTabButton(t) end
  return t
end

-- Old name kept for anything written against the pre-tab hub.
function Hub:AddSection(title, build) return self:AddTab(title:lower(), title, build) end

function Hub:AddTabButton(t)
  local bar = self.frame.tabBar
  bar:Add(t.id, t.title)
  local ids = {}
  for i, o in ipairs(self.tabs) do ids[i] = o.id end
  bar:SetOrder(ids)
end

function Hub:Build()
  if self.frame then return self.frame end
  local f = UI:Window("Outrider_Hub", "Outrider", W, H, ns.db.char.hub)
  self.frame = f
  local c = f.content
  f.tabBar = UI:Tabs(c, {}, function(id) Hub:ShowTab(id) end)
  f.tabBar:SetPoint("TOPLEFT", 0, 0)
  f.tabBar:SetPoint("RIGHT", 0, 0)
  for _, t in ipairs(self.tabs) do self:AddTabButton(t) end

  f:SetScript("OnShow", function()
    ns.db.char.hub.shown = true
    f.tabBar:Select(ns.db.char.hub.tab or "overview")
  end)
  f:SetScript("OnHide", function() ns.db.char.hub.shown = false end)
  return f
end

function Hub:Panel(t)
  if t.panel then return t.panel end
  local p = CreateFrame("Frame", nil, self.frame.content)
  p:SetPoint("TOPLEFT", 0, -32)
  p:SetPoint("BOTTOMRIGHT", 0, 0)
  p:Hide()
  t.panel = p
  if t.build then ns.Safe("hub:build:" .. t.id, t.build, p) end
  return p
end

function Hub:ShowTab(id)
  local t = self.byId[id] or self.tabs[1]
  if not t then return end
  for _, o in ipairs(self.tabs) do if o.panel and o ~= t then o.panel:Hide() end end
  local p = self:Panel(t)
  p:Show()
  if p.Refresh then ns.Safe("hub:refresh:" .. t.id, p.Refresh, p) end
  self.current = t.id
  ns.db.char.hub.tab = t.id
end

-- Refresh whatever tab is on screen (modules call this after changes).
function Hub:Refresh()
  local t = self.current and self.byId[self.current]
  if self.frame and self.frame:IsShown() and t and t.panel and t.panel.Refresh then
    ns.Safe("hub:refresh:" .. t.id, t.panel.Refresh, t.panel)
  end
end

function Hub:Toggle()
  local f = self:Build()
  f:SetShown(not f:IsShown())
end

-- ------------------------------------------------------------- Overview
local function textLine(p, size, color, y)
  local fs = UI.Text(p, size, color)
  fs:SetPoint("TOPLEFT", 0, y)
  fs:SetWidth(W - 20)
  fs:SetJustifyH("LEFT")
  return fs
end

Hub:AddTab("overview", L.overview, function(p)
  p.who = textLine(p, "large", "text", 0)
  p.build = textLine(p, "small", "muted", -22)
  p.sv = textLine(p, "normal", "text", -50)
  p.errors = textLine(p, "normal", "text", -72)
  p.probe = textLine(p, "normal", "text", -94)
  p.mods = textLine(p, "normal", "text", -116)
  p.layer = textLine(p, "normal", "text", -138)
  p.addons = textLine(p, "small", "muted", -164)
  function p:Refresh()
    local meta = ns.db.char.meta
    self.who:SetText(string.format("%s  |  %s %s %s", ns.db.key, tostring(meta.race or ""), tostring(meta.class),
      tostring(meta.level or "?")))
    self.build:SetText(string.format("v%s  build %s", ns.version, ns.build))
    local sv, loads = ns.DB:SavedVariablesStatus()
    self.sv:SetText(string.format("Saved settings read back: %s  (loads %d)", sv, loads))
    local nerr = #ns.Errors.list
    self.errors:SetText(nerr == 0 and "Errors: none" or (Theme:Hex("bad") .. "Errors: " .. nerr .. "|r  (Tools tab)"))
    self.probe:SetText(ns.Probe:Summary())
    local on, total = 0, 0
    for _, s in ipairs(ns.Modules:Status()) do total = total + 1 if s.enabled then on = on + 1 end end
    self.mods:SetText(string.format("Modules on for this character: %d of %d", on, total))
    local id, conf, label = ns.Layers:Current()
    self.layer:SetText(id and string.format("Layer: %s (%.0f%% sure)", label, conf * 100) or "Layer: not known yet (look at a few mobs)")
    local names = {}
    for _, k in ipairs(ns.Conflicts:Detect()) do names[#names + 1] = k.addon .. " (" .. k.relation .. ")" end
    self.addons:SetText("Detected addons: " .. (#names > 0 and table.concat(names, ", ") or "none"))
  end
end, 10)

-- ------------------------------------------------------------- Modules
Hub:AddTab("modules", L.modules, function(p)
  local heading = UI.Text(p, "large", "accent")
  heading:SetPoint("TOPLEFT", 0, 0)
  heading:SetText(L.modulesHeading)
  p.rows = {}
  for i = 1, MAX_ROWS do
    local row = UI:Check(p, "", function() local r = p.rows[i] return r and r.mod and r.mod.enabled end,
      function(on)
        local mod = p.rows[i] and p.rows[i].mod
        if not mod then return end
        local ok, err = ns.Modules:SetEnabled(mod.name, on)
        if not ok then ns.Print("%s: %s", mod.name, err) end
        p:Refresh()
      end)
    row:SetPoint("TOPLEFT", 0, -24 - (i - 1) * 21)
    row:SetWidth(W - 40)
    p.rows[i] = row
  end
  p:EnableMouseWheel(true)
  p:SetScript("OnMouseWheel", function(self, delta) self.offset = (self.offset or 0) - delta * 3 self:Refresh() end)
  function p:Refresh()
    local status = ns.Modules:Status()
    self.offset = math.max(0, math.min(self.offset or 0, #status - #self.rows))
    for i, row in ipairs(self.rows) do
      local s = status[i + (self.offset or 0)]
      if s then
        row.mod = ns.Modules:Get(s.name)
        row.label:SetText(s.title)
        if s.enabled then
          row.note:SetText(s.activity and (ns.Theme:Hex("good") .. s.activity .. "|r") or "")
        else
          row.note:SetText(tostring(s.reason))
        end
        row:Refresh()
        row:Show()
      else
        row.mod = nil
        row:Hide()
      end
    end
  end
end, 20)

-- ------------------------------------------------------------- Characters
Hub:AddTab("characters", L.characters, function(p)
  local hint = UI.Text(p, "small", "muted")
  hint:SetPoint("TOPLEFT", 0, 0)
  hint:SetText(L.charsHint)
  p.list = UI:ScrollList(p, {
    rows = 12, rowHeight = 26,
    build = function(row)
      row.copy = UI:Button(row, "Copy", 70)
      row.copy:SetHeight(20)
      row.copy:SetPoint("RIGHT", -4, 0)
    end,
    render = function(row, ch)
      local when = ch.lastLogin and ch.lastLogin > 0 and date("%Y-%m-%d", ch.lastLogin) or "?"
      row.text:SetText(string.format("%s%s  %s %s  |  last login %s", ch.key, ch.current and "  (you)" or "",
        tostring(ch.class or "?"), tostring(ch.level or "?"), when))
      row.copy:SetShown(not ch.current)
      row.copy:SetScript("OnClick", function()
        local ok, err = ns.Profiles:CopyFrom(ch.key)
        ns.Print(ok and ("copied settings from " .. ch.key .. ". Type /reload to apply everything.") or tostring(err))
      end)
    end,
  })
  p.list:SetPoint("TOPLEFT", 0, -20)
  p.list:SetPoint("RIGHT", 0, 0)
  function p:Refresh() self.list:SetItems(ns.DB:Characters()) end
end, 30)

-- Kept for /ride copy-style flows and older callers: copies from the first
-- other character only when exactly one exists, otherwise opens the tab.
function Hub:ShowCopyMenu()
  local others = {}
  for _, ch in ipairs(ns.DB:Characters()) do if not ch.current then others[#others + 1] = ch end end
  if #others == 0 then ns.Print(L.noOthers) return end
  local f = self:Build()
  f:Show()
  f.tabBar:Select("characters")
end

-- ------------------------------------------------------------- Tools
Hub:AddTab("tools", L.tools, function(p)
  local function btn(label, x, y, fn)
    local b = UI:Button(p, label, 130, fn)
    b:SetPoint("TOPLEFT", x, y)
    return b
  end
  btn("Export", 0, 0, function()
    local s, err = ns.Profiles:Export()
    if s then UI:TextDialog("Export settings (" .. ns.db.key .. ")", s, "copy")
    else ns.Print("export failed: %s", tostring(err)) end
  end)
  btn("Import", 140, 0, function()
    UI:TextDialog("Import settings into " .. ns.db.key, "", "paste", function(text)
      local ok, err = ns.Profiles:Import(text)
      if ok then ns.Print("settings imported. Type /reload to apply everything.") end
      return ok, err
    end)
  end)
  p.errorsBtn = btn("Errors", 280, 0, function() ns.Slash:Run("errors") end)
  btn("Clear errors", 420, 0, function() ns.Slash:Run("errors clear") p:Refresh() end)
  btn("Run probe", 0, -30, function() ns.Slash:Run("probe") p:Refresh() end)
  btn("Reload UI", 140, -30, function() ReloadUI() end)
  p.debug = UI:Check(p, "Debug logging", function() return ns.db.global.debug end,
    function(on) ns.db.global.debug = on and true or false end)
  p.debug:SetPoint("TOPLEFT", 0, -66)
  p.accent = UI:Check(p, "Class color accent (after /reload)", function() return ns.db.char.classAccent end,
    function(on) ns.db.char.classAccent = on and true or false end)
  p.accent:SetPoint("TOPLEFT", 0, -90)
  p.probe = UI.Text(p, "small", "muted")
  p.probe:SetPoint("TOPLEFT", 0, -122)
  p.probe:SetWidth(W - 20)
  p.probe:SetJustifyH("LEFT")
  p.recent = UI.Text(p, "small", "muted")
  p.recent:SetPoint("TOPLEFT", 0, -144)
  p.recent:SetWidth(W - 20)
  p.recent:SetJustifyH("LEFT")
  function p:Refresh()
    self.errorsBtn.label:SetText("Errors (" .. #ns.Errors.list .. ")")
    self.debug:Refresh()
    self.accent:Refresh()
    self.probe:SetText(ns.Probe:Summary())
    local lines = {}
    for _, e in ipairs(ns.Errors:Recent(5)) do lines[#lines + 1] = string.format("x%d %s: %s", e.count, e.where, e.msg) end
    self.recent:SetText(#lines > 0 and table.concat(lines, "\n") or "No recent errors.")
  end
end, 90)

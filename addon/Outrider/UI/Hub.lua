-- UI/Hub.lua
-- The one Outrider window: a top bar (who you are, one search box), a grouped
-- sidebar (Home, Explore, Character, Town, Social, Outrider) and one page at a
-- time. Every /ride command has a control on some page (UI/Pages.lua; the
-- All commands page lists the rest). Core pages defined here:
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

local MAX_ROWS = 19 -- visible module rows; the list scrolls with the mouse wheel
local W, H = 1080, 720        -- starting size; the window is resizable (Gary, 2026-11-13)
local MIN_W, MIN_H, MAX_W, MAX_H = 860, 520, 1400, 1000
local SIDE = 160             -- grouped sidebar on the left; pages to its right

local L = {
  overview = "Status", modules = "Modules", characters = "Characters", tools = "Tools",
  modulesHeading = "Modules for this character",
  charsHint = "Click Copy to take that character's settings (then /reload).",
  noOthers = "no other characters saved yet: log in on another character once.",
}

-- Where each page sits in the sidebar (Gary chose a grouped sidebar,
-- 2026-11-13). Pages not listed land under "More" in the order they ask for.
Hub.GROUPS = { "", "Explore", "Character", "Town", "Social", "Outrider", "More" }
local ICON = "Interface\\Icons\\"
Hub.PLACE = {
  home        = { "", 1, "INV_Misc_Book_09" },
  whatnow     = { "", 2, "INV_Misc_Map_01" },
  help        = { "", 3, "INV_Misc_Book_07" },
  journey     = { "Explore", 10, "INV_Misc_Map_01" },
  map         = { "Explore", 11, "INV_Misc_Map02" },
  waypoints   = { "Explore", 12, "Ability_Tracking" },
  rares       = { "Explore", 13, "Ability_Hunter_SniperShot" },
  rarealerts  = { "Explore", 14, "INV_Misc_Spyglass_02" },
  dungeons    = { "Explore", 15, "INV_Misc_Key_14" },
  quests      = { "Explore", 16, "INV_Misc_Note_01" },
  class       = { "Character", 20 }, -- icon and title follow the character's class
  gear        = { "Character", 21, "INV_Chest_Chain" },
  gearsets    = { "Character", 22, "INV_Shoulder_02" },
  professions = { "Character", 23, "Trade_Alchemy" },
  crafting    = { "Character", 24, "Trade_BlackSmithing" },
  alts        = { "Character", 26, "INV_Misc_Head_Human_01" },
  macros      = { "Character", 25, "INV_Misc_Note_01" },
  money       = { "Town", 29, "INV_Misc_Coin_02" },
  errands     = { "Town", 30, "INV_Misc_Bag_08" },
  forecasts   = { "Town", 31, "INV_Misc_Coin_01" },
  feed        = { "Town", 32, "INV_Letter_15" },
  chat        = { "Social", 40, "INV_Misc_Note_02" },
  sharing     = { "Social", 41, "INV_Letter_09" },
  census      = { "Social", 42, "INV_Misc_GroupLooking" },
  people      = { "Social", 43, "INV_Shirt_GuildTabard_01" },
  settings    = { "Outrider", 50, "Trade_Engineering" },
  modules     = { "Outrider", 51, "INV_Gizmo_01" },
  characters  = { "Outrider", 52, "INV_Misc_Head_Human_01" },
  advisor     = { "Outrider", 53, "INV_Misc_Book_11" },
  overview    = { "Outrider", 54, "INV_Misc_QuestionMark" },
  tools       = { "Outrider", 55, "INV_Misc_Wrench_01" },
  commands    = { "Outrider", 56, "INV_Misc_Note_06" },
}

function Hub:AddTab(id, title, build, order, opts)
  if self.byId[id] then return self.byId[id] end
  local place = self.PLACE[id]
  local t = { id = id, title = title, build = build, opts = opts,
    group = place and place[1] or (opts and opts.group) or "More",
    order = place and place[2] or order or (100 + #self.tabs),
    icon = (place and place[3] and (ICON .. place[3])) or (opts and opts.icon) }
  self.tabs[#self.tabs + 1] = t
  self.byId[id] = t
  local rank = {}
  for i, g in ipairs(self.GROUPS) do rank[g] = i end
  table.sort(self.tabs, function(a, b)
    if a.group ~= b.group then return (rank[a.group] or 99) < (rank[b.group] or 99) end
    return a.order < b.order
  end)
  if self.frame then self:AddTabButton(t) end
  return t
end

-- Old name kept for anything written against the pre-tab hub.
function Hub:AddSection(title, build) return self:AddTab(title:lower(), title, build) end

-- Pages a character can't use (the Hunter page for a mage) stay out of the sidebar.
function Hub:Visible(t)
  local o = t.opts
  if o and o.class and o.class ~= ns.PlayerClass() then return false end
  return true
end

-- ------------------------------------------------------------- sidebar
-- Same interface the old tab bar had (Add, SetOrder, Select, order, buttons),
-- plus group headings and icons.
local function Sidebar(parent, onSelect)
  local bar = CreateFrame("Frame", nil, parent, Theme:BackdropTemplate())
  bar:SetWidth(SIDE)
  Theme:ApplyPanel(bar, "panel")
  if bar.SetClipsChildren then bar:SetClipsChildren(true) end -- nothing spills out of the window
  bar.buttons, bar.order, bar.heads, bar.scroll = {}, {}, {}, 0
  -- the list scrolls with the mouse wheel when it is taller than the window
  bar:EnableMouseWheel(true)
  bar:SetScript("OnMouseWheel", function(self, delta)
    local over = math.max(0, (self.listHeight or 0) - ((self:GetHeight() or 0) - 8))
    self.scroll = math.max(0, math.min(over, self.scroll - delta * 40))
    self:SetOrder(self.order, self.groups)
  end)
  function bar:Add(id, title, icon)
    local b = CreateFrame("Button", nil, self)
    b:SetSize(SIDE - 8, 22)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(Theme:Color("hover"))
    b.bg:Hide()
    -- the current page: lighter row and a gold strip on the left
    b.mark = b:CreateTexture(nil, "ARTWORK")
    b.mark:SetPoint("TOPLEFT", 0, 0)
    b.mark:SetPoint("BOTTOMLEFT", 0, 0)
    b.mark:SetWidth(2)
    b.mark:SetColorTexture(Theme:Color("gold"))
    b.mark:Hide()
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    local hr, hg, hb = Theme:Color("accent")
    hl:SetColorTexture(hr, hg, hb, 0.15) -- see-through, or the hovered row looks blank
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(16, 16)
    b.icon:SetPoint("LEFT", 6, 0)
    if icon then b.icon:SetTexture(icon) b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    b.label = UI.Text(b, "normal", "body")
    b.label:SetPoint("LEFT", 28, 0)
    b.label:SetText(title)
    b.id = id
    b:SetScript("OnClick", function() self:Select(id) end)
    self.buttons[id] = b
    self.order[#self.order + 1] = id
    return b
  end
  local function head(self, i, text)
    local h = self.heads[i]
    if not h then
      h = UI.Text(self, "small", "muted")
      -- group heading: small capitals in muted gold, a hairline to the right
      local r, g, b = Theme:Color("gold")
      h:SetTextColor(r * 0.8, g * 0.8, b * 0.8)
      h.line = self:CreateTexture(nil, "ARTWORK")
      h.line:SetHeight(1)
      h.line:SetPoint("LEFT", h, "RIGHT", 6, 0)
      h.line:SetPoint("RIGHT", self, "RIGHT", -10, 0)
      h.line:SetColorTexture(Theme:Color("border"))
      local hs = h.Hide
      h.Hide = function(s) hs(s) s.line:Hide() end
      self.heads[i] = h
    end
    h:SetText(tostring(text):upper())
    h:Show()
    h.line:Show()
    return h
  end
  function bar:SetOrder(ids, groups)
    self.groups = groups or self.groups
    groups = self.groups
    local seen, order = {}, {}
    for _, id in ipairs(ids) do if self.buttons[id] and not seen[id] then order[#order + 1] = id seen[id] = true end end
    for _, id in ipairs(self.order) do if not seen[id] then order[#order + 1] = id end end
    self.order = order
    for _, h in ipairs(self.heads) do h:Hide() end
    local y, last, nh = -4 + (self.scroll or 0), nil, 0
    local top = y
    for _, id in ipairs(order) do
      local b = self.buttons[id]
      local g = groups and groups[id] or ""
      if g ~= last and g ~= "" then
        nh = nh + 1
        local h = head(self, nh, g)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", 10, y - 4)
        y = y - 18
      end
      last = g
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", 4, y)
      y = y - 23
    end
    self.listHeight = top - y
  end
  function bar:Select(id)
    if not self.buttons[id] then id = self.order[1] end
    if not id then return end
    self.selected = id
    for tid, b in pairs(self.buttons) do
      b.label:SetTextColor(Theme:Color(tid == id and "text" or "body"))
      b.bg:SetShown(tid == id)
      if b.mark then b.mark:SetShown(tid == id) end
    end
    if onSelect then ns.Safe("tabs:select", onSelect, id) end
  end
  return bar
end

function Hub:AddTabButton(t)
  local bar = self.frame.tabBar
  if not self:Visible(t) then return end
  -- the page's custom picture when Gary's art is in (sidebar icons match the page header)
  local art = ns.Art and ns.Art:Path(t.id == "class" and ("class_" .. tostring(ns.PlayerClass and ns.PlayerClass() or "")):lower() or ("page_" .. t.id))
  local btn = bar:Add(t.id, t.title, art or t.icon)
  local tip = ns.Tips and ns.Tips.pages[t.id]
  if btn and tip then UI.Tip(btn, t.title, tip) elseif btn then UI.untipped["page:" .. t.id] = true end
  local ids, groups = {}, {}
  for _, o in ipairs(self.tabs) do
    if bar.buttons[o.id] then ids[#ids + 1] = o.id groups[o.id] = o.group end
  end
  bar:SetOrder(ids, groups)
end

-- Top bar: who you are, and one search box for everything (Enter opens the
-- Journey page with that search).
function Hub:TopBar(f)
  -- Expedition look: gold window edge, emblem, the name in the display font
  if f.SetBackdropBorderColor then f:SetBackdropBorderColor(Theme:Color("gold")) end
  f.emblem = f.bar:CreateTexture(nil, "ARTWORK")
  f.emblem:SetSize(20, 20)
  f.emblem:SetPoint("LEFT", 8, 0)
  ns.Art:Set(f.emblem, "emblem")
  f.title:ClearAllPoints()
  f.title:SetPoint("LEFT", f.emblem, "RIGHT", 6, 0)
  Theme:StyleDisplay(f.title, "brand", "gold")
  f.title:SetText("Outrider")
  f.who = UI.Text(f.bar, "small", "muted")
  f.who:SetPoint("LEFT", f.title, "RIGHT", 12, 0)
  f.gear = CreateFrame("Button", nil, f.bar)
  f.gear:SetSize(18, 18)
  f.gear:SetPoint("RIGHT", f.close, "LEFT", -6, 0)
  f.gear.tex = f.gear:CreateTexture(nil, "ARTWORK")
  f.gear.tex:SetAllPoints()
  f.gear.tex:SetTexture("Interface\\Icons\\Trade_Engineering")
  f.gear.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  f.gear:SetScript("OnClick", function() f.tabBar:Select("settings") end)
  f.search = UI:SearchBox(f.bar, 240, "Search Outrider (Enter)")
  f.search:SetHeight(20)
  f.search:SetPoint("RIGHT", f.gear, "LEFT", -8, 0)
  f.search:SetScript("OnEnterPressed", function(box)
    local text = box:GetText() or ""
    box:ClearFocus()
    Hub:Search(text)
  end)
end

function Hub:Search(text)
  local f = self:Build()
  f:Show()
  self.pendingSearch = text
  f.tabBar:Select("journey")
end

function Hub:UpdateWho()
  local f = self.frame
  if not f or not f.who then return end
  local meta = ns.db.char.meta or {}
  local mapID = ns.Compat.PlayerPosition("player")
  local zone = mapID and ns.Travel and ns.Travel.ZoneName(mapID) or ""
  f.who:SetText(string.format("%s, level %s %s%s", tostring(ns.db.key):match("^[^-]+") or "?",
    tostring(meta.level or "?"), tostring(meta.class or ""):lower(), zone ~= "" and (", " .. zone) or ""))
end

-- Drag the bottom-right corner to resize; the size is saved per character.
function Hub:Resizer(f)
  local saved = ns.db.char.hub
  if f.SetResizable then f:SetResizable(true) end
  if f.SetResizeBounds then f:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
  elseif f.SetMinResize then f:SetMinResize(MIN_W, MIN_H) f:SetMaxResize(MAX_W, MAX_H) end
  if saved.w and saved.h then
    f:SetSize(math.max(MIN_W, math.min(MAX_W, saved.w)), math.max(MIN_H, math.min(MAX_H, saved.h)))
  end
  local grip = CreateFrame("Button", nil, f)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -2, 2)
  grip.tex = grip:CreateTexture(nil, "OVERLAY")
  grip.tex:SetAllPoints()
  grip.tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
    saved.w, saved.h = math.floor(f:GetWidth() + 0.5), math.floor(f:GetHeight() + 0.5)
  end)
  f.grip = grip
end

function Hub:Build()
  if self.frame then return self.frame end
  local f = UI:Window("Outrider_Hub", "Outrider", W, H, ns.db.char.hub)
  self.frame = f
  self:TopBar(f)
  self:Resizer(f)
  local c = f.content
  f.tabBar = Sidebar(c, function(id) Hub:ShowTab(id) end)
  f.tabBar:SetPoint("TOPLEFT", 0, 0)
  f.tabBar:SetPoint("BOTTOMLEFT", 0, 0)
  for _, t in ipairs(self.tabs) do self:AddTabButton(t) end

  f:SetScript("OnShow", function()
    ns.db.char.hub.shown = true
    Hub:UpdateWho()
    f.tabBar:Select(ns.db.char.hub.tab or "home")
  end)
  f:SetScript("OnHide", function() ns.db.char.hub.shown = false end)
  return f
end

-- Pages that draw their own heading (Expedition layouts) skip the title strip.
Hub.OWN_HEADING = { home = true, whatnow = true }
Hub.TITLE_H = 80

-- The page's picture: custom art page_<id> (or class_<CLASS> for the class
-- page) when Gary's art is in, else the sidebar icon.
function Hub.SetPagePicture(tex, t)
  local name = t.id == "class" and ("class_" .. tostring(ns.PlayerClass and ns.PlayerClass() or "")):lower() or ("page_" .. t.id)
  local place = Hub.PLACE[t.id]
  local fb = t.icon or (place and place[3] and (ICON .. place[3])) or (ICON .. "INV_Misc_Book_09")
  if ns.Art then ns.Art:Set(tex, name, fb) else tex:SetTexture(fb) end
end

function Hub:Panel(t)
  if t.panel then return t.panel end
  local p = CreateFrame("Frame", nil, self.frame.content)
  p:SetPoint("BOTTOMRIGHT", -6, 14)
  p:Hide()
  t.panel = p
  if self.OWN_HEADING[t.id] then
    p:SetPoint("TOPLEFT", SIDE + 14, -2)
  else
    -- Expedition look on every page (2026-11-15): the page title in the
    -- display font over the header scene, a gold rule, then the page. The
    -- strip belongs to the panel (drawn above its top edge) so it shows and
    -- hides with it. A form page's first heading replaces the title text.
    p:SetPoint("TOPLEFT", SIDE + 14, -(self.TITLE_H + 2))
    if ns.Art and ns.Art:Has("header") then
      p.scene = p:CreateTexture(nil, "BACKGROUND")
      p.scene:SetPoint("BOTTOMLEFT", p, "TOPLEFT", 0, 6)
      p.scene:SetPoint("RIGHT", p, "RIGHT", 0, 0)
      p.scene:SetHeight(self.TITLE_H - 6)
      ns.Art:Set(p.scene, "header")
      if p.scene.SetAlpha then p.scene:SetAlpha(0.45) end
    end
    -- hero (2026-11-16, Gary: "every page a custom premium feel", like What
    -- now?): the page's picture in a gold frame, the title, what the page is
    -- for, and Help on the right.
    p.hubTile = CreateFrame("Frame", nil, p, Theme:BackdropTemplate())
    p.hubTile:SetSize(52, 52)
    p.hubTile:SetPoint("BOTTOMLEFT", p, "TOPLEFT", 0, 12)
    Theme:ApplyPanel(p.hubTile, "bg", "gold")
    p.hubPic = p.hubTile:CreateTexture(nil, "ARTWORK")
    p.hubPic:SetPoint("TOPLEFT", 2, -2)
    p.hubPic:SetPoint("BOTTOMRIGHT", -2, 2)
    Hub.SetPagePicture(p.hubPic, t)
    p.hubTitle = UI.Display(p, "page", "text")
    p.hubTitle:SetPoint("TOPLEFT", p.hubTile, "TOPRIGHT", 14, 0)
    p.hubTitle:SetText(t.title or "")
    p.hubSub = UI.Text(p, "normal", "muted")
    p.hubSub:SetPoint("TOPLEFT", p.hubTitle, "BOTTOMLEFT", 0, -6)
    p.hubSub:SetPoint("RIGHT", p, "RIGHT", -60, 0)
    p.hubSub:SetJustifyH("LEFT")
    if p.hubSub.SetWordWrap then p.hubSub:SetWordWrap(false) end
    p.hubSub:SetText(ns.Tips and ns.Tips.pages[t.id] or "")
    if t.id ~= "help" then
      p.helpBtn = UI:Button(p, "?", 30, function() if ns.HelpPage then ns.HelpPage.Open(t.id) end end)
      p.helpBtn:SetHeight(26)
      p.helpBtn:SetPoint("BOTTOMRIGHT", p, "TOPRIGHT", 0, 16)
      UI.Tip(p.helpBtn, "Help for this page", "Opens Help on what this page does and how to use it.")
    end
    p.hubRule = p:CreateTexture(nil, "ARTWORK")
    p.hubRule:SetHeight(1)
    p.hubRule:SetPoint("BOTTOMLEFT", p, "TOPLEFT", 0, 6)
    p.hubRule:SetPoint("RIGHT", p, "RIGHT", 0, 0)
    local r, g, b = Theme:Color("gold")
    p.hubRule:SetColorTexture(r, g, b, 0.5)
  end
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
-- Expedition look: a card filling a hand-built page, kept at the page's own
-- frame level so the page's checks and buttons draw above it.
local function pageCard(p, height)
  local card = UI:Card(p)
  card:SetPoint("TOPLEFT", 0, 0)
  if height then card:SetPoint("RIGHT", p, "RIGHT", -4, 0) card:SetHeight(height)
  else card:SetPoint("BOTTOMRIGHT", -4, 0) end
  if card.SetFrameLevel and p.GetFrameLevel then card:SetFrameLevel(p:GetFrameLevel() or 1) end
  return card
end

local function textLine(p, size, color, y)
  local fs = UI.Text(p, size, color)
  fs:SetPoint("TOPLEFT", 14, y - 12)
  fs:SetWidth(W - SIDE - 68)
  fs:SetJustifyH("LEFT")
  return fs
end

Hub:AddTab("overview", L.overview, function(p)
  local box = pageCard(p, 196)
  p.who = textLine(box, "large", "text", 0)
  p.build = textLine(box, "small", "muted", -22)
  p.sv = textLine(box, "normal", "text", -50)
  p.errors = textLine(box, "normal", "text", -72)
  p.probe = textLine(box, "normal", "text", -94)
  p.mods = textLine(box, "normal", "text", -116)
  p.layer = textLine(box, "normal", "text", -138)
  p.addons = textLine(box, "small", "muted", -164)
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
-- Modules grouped by phase, with a header line per group; status text in a
-- quiet color, cut to one line (the full text shows on hover).
local GROUPS = { P0 = "Core", P1 = "Core", P2 = "Rares and class tools", P3 = "Maps and places", P4 = "Macros",
  P5 = "Professions and gold", P6 = "Gear", P7 = "Interface", P8 = "Sharing and town", P9 = "Advisor" }
local PANEL_W = W - SIDE - 40

Hub:AddTab("modules", L.modules, function(p)
  local box = pageCard(p)
  local heading = UI.Display(box, "side", "goldText")
  heading:SetPoint("TOPLEFT", 14, -10)
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
    row:SetPoint("TOPLEFT", 14, -36 - (i - 1) * 21)
    row:SetWidth(PANEL_W - 28)
    row.label:SetWidth(210) row.label:SetJustifyH("LEFT") row.label:SetWordWrap(false)
    row.note:SetWidth(PANEL_W - 240) row.note:SetJustifyH("LEFT") row.note:SetWordWrap(false)
    row.head = UI.Text(row, "normal", "accent")
    row.head:SetPoint("LEFT", 0, 0)
    row:SetScript("OnEnter", function(self)
      if not self.full then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.label:GetText() or "")
      GameTooltip:AddLine(self.full, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p.rows[i] = row
  end
  p:EnableMouseWheel(true)
  p:SetScript("OnMouseWheel", function(self, delta) self.offset = (self.offset or 0) - delta * 3 self:Refresh() end)
  function p:Refresh()
    local lines, last = {}, nil
    local myClass = ns.PlayerClass()
    for _, s in ipairs(ns.Modules:Status()) do
      local mod = ns.Modules:Get(s.name)
      local classes = mod and mod.spec.classes
      if classes and not classes[myClass] then mod = nil end -- other classes' modules stay out of sight
      local group = mod and (GROUPS[mod.spec.phase or ""] or "Other")
      if group then
        if group ~= last then lines[#lines + 1] = { header = group } last = group end
        lines[#lines + 1] = s
      end
    end
    local status = lines
    self.offset = math.max(0, math.min(self.offset or 0, #status - #self.rows))
    for i, row in ipairs(self.rows) do
      local s = status[i + (self.offset or 0)]
      if s and s.header then
        row.mod, row.full = nil, nil
        row.head:SetText(s.header) row.head:Show()
        row.box:Hide() row.label:SetText("") row.note:SetText("")
        row:Show()
      elseif s then
        row.head:Hide() row.box:Show()
        row.mod = ns.Modules:Get(s.name)
        row.label:SetText(s.title)
        local text = s.enabled and (s.activity or "") or ("off: " .. tostring(s.reason))
        row.full = text ~= "" and text or nil
        row.note:SetText(ns.Theme:Hex(s.enabled and "muted" or "warn") .. text .. "|r")
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
  local box = pageCard(p, 260)
  local function btn(label, x, y, fn)
    local b = UI:Button(p, label, 130, fn)
    b:SetPoint("TOPLEFT", x + 14, y - 12)
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
  p.debug:SetPoint("TOPLEFT", 14, -78)
  p.accent = UI:Check(p, "Class color accent (after /reload)", function() return ns.db.char.classAccent ~= false end,
    function(on) ns.db.char.classAccent = on and true or false end)
  p.accent:SetPoint("TOPLEFT", 14, -102)
  p.probe = UI.Text(box, "small", "muted")
  p.probe:SetPoint("TOPLEFT", 14, -134)
  p.probe:SetWidth(W - SIDE - 68)
  p.probe:SetJustifyH("LEFT")
  p.recent = UI.Text(box, "small", "muted")
  p.recent:SetPoint("TOPLEFT", 14, -156)
  p.recent:SetWidth(W - SIDE - 68)
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

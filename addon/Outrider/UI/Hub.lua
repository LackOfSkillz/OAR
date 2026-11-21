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

local MAX_ROWS = 44 -- module rows built; as many show as the page has room for (tour 2026-11-19: 19 left half the page empty), the rest scroll with the mouse wheel
-- starting size; the window is resizable (Gary, 2026-11-13). Larger since
-- 2026-11-19 (Gary: "open a little larger"), never more than 90% of the screen.
local W, H = 1280, 860
local MIN_W, MIN_H, MAX_W, MAX_H = 860, 520, 1800, 1200
local SIDE = 160             -- grouped sidebar on the left; pages to its right

local L = {
  overview = "Status", modules = "Modules", characters = "Characters", tools = "Tools",
  modulesHeading = "Modules for this character",
  charsHint = "Click Copy to take that character's settings (then /reload).",
  noOthers = "no other characters saved yet: log in on another character once.",
}

-- Where each page sits in the sidebar. Redesigned 2026-11-20 (Gary: "a more
-- logical grouping ... use all best practice ui/ux"): grouped by what you're
-- doing, most-used first, Advisor / Settings / Help at the bottom. Twin pages
-- became one sidebar entry with sub-tabs (Hub.SUBS); every old page id still
-- opens (links, commands, the remembered page), on its host's sub-tab.
Hub.GROUPS = { "", "World", "Character", "Professions", "Gold", "Social", "Outrider", "More" }
local ICON = "Interface\\Icons\\"
Hub.PLACE = {
  home        = { "", 1, "INV_Misc_Book_09" },
  journey     = { "", 2, "INV_Misc_Spyglass_03" },
  feed        = { "", 3, "INV_Letter_15" },
  waypoints   = { "World", 10, "INV_Misc_Map02" },
  quests      = { "World", 11, "INV_Misc_Note_01" },
  rares       = { "World", 12, "Ability_Hunter_SniperShot" },
  dungeons    = { "World", 13, "INV_Misc_Key_14" },
  class       = { "Character", 20 }, -- icon and title follow the character's class
  gear        = { "Character", 21, "INV_Chest_Chain" },
  macros      = { "Character", 22, "INV_Misc_Note_06" },
  alts        = { "Character", 23, "INV_Misc_Head_Human_01" },
  professions = { "Professions", 30, "Trade_Alchemy" },
  crafting    = { "Professions", 31, "Trade_BlackSmithing" },
  fishing     = { "Professions", 32, "Trade_Fishing" },
  money       = { "Gold", 40, "INV_Misc_Coin_02" },
  chat        = { "Social", 50, "INV_Misc_Note_02" },
  sharing     = { "Social", 51, "INV_Letter_09" },
  people      = { "Social", 52, "INV_Shirt_GuildTabard_01" },
  advisor     = { "Outrider", 60, "INV_Misc_Book_11" },
  settings    = { "Outrider", 61, "Trade_Engineering" },
  help        = { "Outrider", 62, "INV_Misc_Book_07" },
}
-- One sidebar entry, several pages: { host = { {page id, sub-tab label}, ... } }.
-- The first page is the host itself.
Hub.SUBS = {
  home      = { { "home", "Overview" }, { "whatnow", "Next steps" }, { "errands", "Town errands" } },
  waypoints = { { "waypoints", "Places and arrow" }, { "map", "Map pins" } },
  quests    = { { "quests", "Quest log" }, { "questsnear", "Near me" }, { "questchains", "Chains" }, { "journal", "Diary" } },
  rares     = { { "rares", "Rares" }, { "rarealerts", "Watch and alerts" } },
  gear      = { { "gear", "Wearing and upgrades" }, { "gearsets", "Sets and scoring" } },
  alts      = { { "alts", "Characters" }, { "characters", "Copy settings" } },
  money     = { { "money", "Earn" }, { "forecasts", "Forecasts" } },
  people    = { { "people", "Players and guilds" }, { "census", "Census" } },
  settings  = { { "settings", "Settings" }, { "modules", "Modules" }, { "tools", "Tools" }, { "overview", "Status" } },
  help      = { { "help", "Help" }, { "feedback", "Report or idea" }, { "commands", "All commands" } },
  dungeons  = { { "dungeonquests", "Quests and keys" }, { "dungeons", "Ready and gear" } },
}
-- the sub-tab a sidebar entry opens the first time (else the host itself)
Hub.DEFAULT_SUB = { dungeons = "dungeonquests", quests = "questsnear" }
-- clearer names for some pages (sidebar and page title)
Hub.TITLES = { journey = "Find", feed = "Alerts", waypoints = "Map and places", alts = "My characters", people = "People" }
-- page id -> the sidebar entry it lives under
Hub.NAV = {}
for host, subs in pairs(Hub.SUBS) do
  for i, s in ipairs(subs) do
    if s[1] ~= host then
      Hub.NAV[s[1]] = host
      local hp = Hub.PLACE[host]
      Hub.PLACE[s[1]] = { hp[1], hp[2] + i / 100, hp[3] }
    end
  end
end

-- The sidebar entry for a page, and the sub-tab to open when that entry is clicked
-- (the one you looked at last).
function Hub.NavOf(id) return Hub.NAV[id] or id end
function Hub.LastSub(host)
  local hub = ns.db and ns.db.char and ns.db.char.hub
  local last = hub and type(hub.sub) == "table" and hub.sub[host]
  if last and Hub.NAV[last] == host and Hub.byId[last] then return last end
  if last == host then return host end
  local def = Hub.DEFAULT_SUB[host]
  return (def and Hub.byId[def]) and def or host
end

function Hub:AddTab(id, title, build, order, opts)
  if self.byId[id] then return self.byId[id] end
  local place = self.PLACE[id]
  title = self.TITLES[id] or title
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
    b.mark:SetWidth(3)
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
    b:SetScript("OnClick", function() self:Select(Hub.LastSub(id)) end)
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
  -- Light up a row without opening anything (Hub:ShowTab calls this, so the
  -- sidebar follows pages opened by buttons, the tour or code: B1, 2026-11-18).
  function bar:Highlight(id)
    if not self.buttons[id] then return end
    self.selected = id
    for tid, b in pairs(self.buttons) do
      b.label:SetTextColor(Theme:Color(tid == id and "goldText" or "body"))
      b.bg:SetShown(tid == id)
      if b.mark then b.mark:SetShown(tid == id) end
    end
  end
  function bar:Select(id)
    -- a sub-tab page lights up its sidebar entry
    if not (Hub.byId[id] and self.buttons[Hub.NavOf(id)]) then id = self.order[1] end
    if not id then return end
    self:Highlight(Hub.NavOf(id))
    if onSelect then ns.Safe("tabs:select", onSelect, id) end
  end
  return bar
end

function Hub:AddTabButton(t)
  local bar = self.frame.tabBar
  if not self:Visible(t) then return end
  if self.NAV[t.id] then return end -- a sub-tab: no sidebar row of its own
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
  -- fit the screen: the starting size is at most 90% of it
  local sw = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 0
  local sh = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 0
  local fitW = sw > 300 and math.floor(math.min(W, sw * 0.9)) or W
  local fitH = sh > 300 and math.floor(math.min(H, sh * 0.9)) or H
  -- once: a size saved from the old smaller start grows to the new one (a size you dragged bigger stays)
  if not saved.grew1119 then
    saved.grew1119 = true
    if saved.w and saved.w < fitW then saved.w = fitW end
    if saved.h and saved.h < fitH then saved.h = fitH end
  end
  local w, h = saved.w or fitW, saved.h or fitH
  f:SetSize(math.max(MIN_W, math.min(MAX_W, w)), math.max(MIN_H, math.min(MAX_H, h)))
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
    ns.Events:Fire("OTR_HUB_SHOWN")
  end)
  f:SetScript("OnHide", function() ns.db.char.hub.shown = false ns.Events:Fire("OTR_HUB_HIDDEN") end)
  return f
end

-- Pages that draw their own heading (Expedition layouts) skip the title strip.
Hub.OWN_HEADING = { home = true, whatnow = true }
Hub.TITLE_H = 100

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
    -- each sidebar group gets its own banner when the art is in (batch 4b)
    -- the 2026-11-20 groups reuse the banners painted for the old ones
    local BANNER = { world = "explore", gold = "town", professions = "character" }
    local g = tostring(t.group or ""):lower()
    local banner = "header_" .. (BANNER[g] and not (ns.Art and ns.Art:Has("header_" .. g)) and BANNER[g] or g)
    if not (ns.Art and ns.Art:Has(banner)) then banner = "header" end
    if ns.Art and ns.Art:Has(banner) then
      p.scene = p:CreateTexture(nil, "BACKGROUND")
      p.scene:SetPoint("BOTTOMLEFT", p, "TOPLEFT", 0, 6)
      p.scene:SetPoint("RIGHT", p, "RIGHT", 0, 0)
      p.scene:SetHeight(self.TITLE_H - 6)
      ns.Art:Set(p.scene, banner)
      if p.scene.SetAlpha then p.scene:SetAlpha(0.45) end
    end
    -- hero (2026-11-16, Gary: "every page a custom premium feel", like What
    -- now?): the page's picture in a gold frame, the title, what the page is
    -- for, and Help on the right.
    p.hubTile = CreateFrame("Frame", nil, p, Theme:BackdropTemplate())
    p.hubTile:SetSize(52, 52)
    -- higher when the page has steps under its title (they sit above the rule)
    p.hubTile:SetPoint("BOTTOMLEFT", p, "TOPLEFT", 0, (ns.Tips and ns.Tips.steps and ns.Tips.steps[t.id]) and 34 or 22)
    Theme:ApplyPanel(p.hubTile, "bg", "gold")
    p.hubPic = p.hubTile:CreateTexture(nil, "ARTWORK")
    p.hubPic:SetPoint("TOPLEFT", 2, -2)
    p.hubPic:SetPoint("BOTTOMRIGHT", -2, 2)
    Hub.SetPagePicture(p.hubPic, t)
    p.hubTitle = UI.Display(p, "page", "text")
    p.hubTitle:SetPoint("TOPLEFT", p.hubTile, "TOPRIGHT", 14, 0)
    local host = self.byId[self.NavOf(t.id)]
    p.hubTitle:SetText((host and host.title) or t.title or "")
    p.hubSub = UI.Text(p, "normal", "muted")
    p.hubSub:SetPoint("TOPLEFT", p.hubTitle, "BOTTOMLEFT", 0, -6)
    p.hubSub:SetPoint("RIGHT", p, "RIGHT", -60, 0)
    p.hubSub:SetJustifyH("LEFT")
    if p.hubSub.SetWordWrap then p.hubSub:SetWordWrap(false) end
    p.hubSub:SetText(ns.Tips and ns.Tips.pages[t.id] or "")
    -- how to use it, in numbered steps (Gary, 2026-11-20: an 8th grader gets the page at a glance)
    local steps = ns.Tips and ns.Tips.steps and ns.Tips.steps[t.id]
    if steps then
      p.hubSteps = {}
      local prev
      for i, txt in ipairs(steps) do
        local n = p:CreateTexture(nil, "ARTWORK")
        n:SetSize(16, 16)
        if prev then n:SetPoint("LEFT", prev, "RIGHT", 18, 0) else n:SetPoint("TOPLEFT", p.hubSub, "BOTTOMLEFT", 0, -8) end
        n:SetColorTexture(Theme:Color("gold"))
        local num = UI.Text(p, "small", "onGold")
        num:SetPoint("CENTER", n, "CENTER", 0, 0)
        num:SetText(tostring(i))
        local tx = UI.Text(p, "normal", "text")
        tx:SetPoint("LEFT", n, "RIGHT", 6, 0)
        tx:SetText(txt)
        p.hubSteps[i] = { box = n, num = num, text = tx }
        prev = tx
      end
    end
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
  self:SubTabs(p, t)
  if t.build then ns.Safe("hub:build:" .. t.id, t.build, p) end
  return p
end

-- The sub-tabs of a sidebar entry, at the right of the page header (on pages
-- that draw their own heading: top right). The one on screen is gold.
function Hub:SubTabs(p, t)
  local nav = self.NavOf(t.id)
  local subs = self.SUBS[nav]
  if not subs then return end
  p.subTabs = {}
  local prev
  for i = #subs, 1, -1 do
    local id, label = subs[i][1], subs[i][2]
    if self.byId[id] then
      local c = UI:Chip(p, label, function() Hub.frame.tabBar:Select(id) end)
      c.page = id
      UI.Tip(c, label, ns.Tips and ns.Tips.pages[id] or label)
      if prev then c:SetPoint("RIGHT", prev, "LEFT", -6, 0)
      elseif self.OWN_HEADING[t.id] then c:SetPoint("TOPRIGHT", p, "TOPRIGHT", -4, -6)
      else c:SetPoint("BOTTOMRIGHT", p, "TOPRIGHT", -40, 18) end
      c:SetOn(id == t.id)
      table.insert(p.subTabs, 1, c)
      prev = c
    end
  end
  if self.OWN_HEADING[t.id] and p.subTabs[1] then
    local back = CreateFrame("Frame", nil, p, Theme:BackdropTemplate())
    back:SetPoint("TOPLEFT", p.subTabs[1], "TOPLEFT", -6, 5)
    back:SetPoint("BOTTOMRIGHT", p.subTabs[#p.subTabs], "BOTTOMRIGHT", 6, -5)
    Theme:ApplyPanel(back, "bg", "border")
    if back.SetBackdropColor then back:SetBackdropColor(0, 0, 0, 0.8) end
    back:SetFrameLevel(math.max(1, (p.subTabs[1]:GetFrameLevel() or 2) - 1))
    for _, c in ipairs(p.subTabs) do c:SetFrameLevel((back:GetFrameLevel() or 1) + 2) end
    p.subBack = back
  end
end

function Hub:ShowTab(id)
  local t = self.byId[id] or self.tabs[1]
  if not t then return end
  for _, o in ipairs(self.tabs) do if o.panel and o ~= t then o.panel:Hide() end end
  local p = self:Panel(t)
  p:Show()
  local nav = self.NavOf(t.id)
  if self.frame and self.frame.tabBar and self.frame.tabBar.selected ~= nav then self.frame.tabBar:Highlight(nav) end
  if self.SUBS[nav] then
    local hub = ns.db.char.hub
    hub.sub = type(hub.sub) == "table" and hub.sub or {}
    hub.sub[nav] = t.id
  end
  if p.subTabs then for _, c in ipairs(p.subTabs) do c:SetOn(c.page == t.id) end end
  if p.Refresh then ns.Safe("hub:refresh:" .. t.id, p.Refresh, p) end
  -- the page you came from, for a report (Feedback)
  if t.id ~= "feedback" and t.id ~= "help" then self.lastPage = t.id end
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

-- Premium rebuild (2026-11-18 tour): one health line in plain words, two rows
-- of stat tiles, detected addons as a short list. Developer detail (build id,
-- probe numbers) moves into tiles' captions.
Hub:AddTab("overview", L.overview, function(p)
  p.health = UI.Text(p, "large", "good")
  p.health:SetPoint("TOPLEFT", 2, 0)
  p.who = UI.Text(p, "small", "muted")
  p.who:SetPoint("TOPLEFT", p.health, "BOTTOMLEFT", 0, -4)
  p.row1 = UI:StatStrip(p)
  p.row1:SetPoint("TOPLEFT", 0, -46)
  p.row1:SetPoint("RIGHT", p, "RIGHT", -4, 0)
  p.row2 = UI:StatStrip(p)
  p.row2:SetPoint("TOPLEFT", 0, -122)
  p.row2:SetPoint("RIGHT", p, "RIGHT", -4, 0)
  p.addons = UI.Text(p, "normal", "body")
  p.addons:SetPoint("TOPLEFT", 2, -204)
  p.addons:SetPoint("RIGHT", p, "RIGHT", -8, 0)
  p.addons:SetJustifyH("LEFT")
  p.toTools = UI:Button(p, "Open Tools", 120, function() Hub:ShowTab("tools") end)
  p.toTools:SetPoint("TOPRIGHT", p, "TOPRIGHT", -4, 0)
  function p:Refresh()
    local meta = ns.db.char.meta
    local all = #ns.Errors.list
    local nerr = ns.Errors:Fresh() -- only this build's errors need a look
    local older = all - nerr
    local sv, loads = ns.DB:SavedVariablesStatus()
    local svOK = tostring(sv):lower():find("ok") or tostring(sv):lower():find("yes")
    self.health:SetTextColor(Theme:Color(nerr == 0 and svOK and "good" or "warn"))
    self.health:SetText(nerr == 0 and (svOK and "All systems OK" or "Settings not confirmed saved yet")
      or (nerr == 1 and "1 error needs a look" or (nerr .. " errors need a look")))
    self.toTools:SetShown(all > 0)
    self.who:SetText(string.format("%s  ·  %s %s, level %s  ·  v%s", ns.db.key, tostring(meta.race or ""), tostring(meta.class or ""),
      tostring(meta.level or "?"), tostring(ns.version)))
    local on, total = 0, 0
    for _, st in ipairs(ns.Modules:Status()) do total = total + 1 if st.enabled then on = on + 1 end end
    local pr = ns.db.global.probe
    local present, missing = pr and pr.summary and pr.summary.present or 0, pr and pr.summary and pr.summary.missing or 0
    local id, conf, label = ns.Layers:Current()
    self.row1:SetItems({
      { cap = "Errors on this build", value = tostring(nerr), color = nerr > 0 and "bad" or "good",
        note = nerr > 0 and "see Tools" or older > 0 and (older .. " older, fixed or gone: see Tools") or "none" },
      { cap = "Settings saved", value = svOK and "Yes" or tostring(sv), color = svOK and "good" or "warn", note = loads .. " loads" },
      { cap = "Features on", value = on .. " / " .. total, fill = total > 0 and on / total or nil },
    })
    self.row2:SetItems({
      { cap = "Game functions found", value = present .. " / " .. (present + missing),
        fill = (present + missing) > 0 and present / (present + missing) or nil },
      { cap = "Layer", value = id and label or "—", note = id and string.format("%.0f%% sure", conf * 100) or "learning from nearby mobs" },
      { cap = "Build", value = tostring(ns.build):match("^(%d%d%d%d%d%d%d%d)") or tostring(ns.build), note = tostring(ns.build):match("%-(%x+)$") },
    })
    -- counted, not named (Gary, 2026-11-20: no other addon's name in Outrider)
    local n = #ns.Conflicts:Detect()
    self.addons:SetText("|cfff1d58eOther addons|r   " .. (n > 0 and (n .. " found; Outrider shares or steps aside, and never needs them")
      or "none found; Outrider needs no other addon"))
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
    -- names get room to show in full (they were cut mid-word at 210 px)
    row.label:SetWidth(330) row.label:SetJustifyH("LEFT") row.label:SetWordWrap(false)
    row.note:SetWidth(PANEL_W - 370) row.note:SetJustifyH("LEFT") row.note:SetWordWrap(false)
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
    -- one block per group, each group once (the tour showed "Rares and class
    -- tools" twice because modules came in load order), with "n of m on"
    local lines, byGroup, order = {}, {}, {}
    local myClass = ns.PlayerClass()
    for _, s in ipairs(ns.Modules:Status()) do
      local mod = ns.Modules:Get(s.name)
      local classes = mod and mod.spec.classes
      if classes and not classes[myClass] then mod = nil end -- other classes' modules stay out of sight
      local group = mod and (GROUPS[mod.spec.phase or ""] or "Other")
      if group then
        if not byGroup[group] then byGroup[group] = {} order[#order + 1] = group end
        table.insert(byGroup[group], s)
      end
    end
    local rank = { Core = 1, ["Rares and class tools"] = 2, ["Maps and places"] = 3, Macros = 4,
      ["Professions and gold"] = 5, Gear = 6, Interface = 7, ["Sharing and town"] = 8, Advisor = 9, Other = 10 }
    table.sort(order, function(a, b) return (rank[a] or 99) < (rank[b] or 99) end)
    for _, g in ipairs(order) do
      local on = 0
      for _, s in ipairs(byGroup[g]) do if s.enabled then on = on + 1 end end
      lines[#lines + 1] = { header = string.format("%s   |cff8f96a6%d of %d on|r", g, on, #byGroup[g]) }
      for _, s in ipairs(byGroup[g]) do lines[#lines + 1] = s end
    end
    local status = lines
    local h = self.GetHeight and self:GetHeight() or 0
    local fit = h >= 300 and math.min(#self.rows, math.floor((h - 70) / 21)) or 19 -- 19 until the page has a real size
    self.offset = math.max(0, math.min(self.offset or 0, #status - fit))
    if not self.more then
      self.more = UI.Text(self, "small", "muted")
      self.more:SetPoint("BOTTOMLEFT", 14, 8)
    end
    local last = math.min(#status, fit + self.offset)
    self.more:SetText(#status > fit and string.format("Lines %d-%d of %d: scroll with the mouse wheel for the rest", self.offset + 1, last, #status) or "")
    for i, row in ipairs(self.rows) do
      local s = i <= fit and status[i + (self.offset or 0)]
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
-- Premium rebuild (2026-11-18 tour): three labelled groups of actions and the
-- error log as a table (count, where, short message; full text on hover).
Hub:AddTab("tools", L.tools, function(p)
  local function head(text, y)
    local t = UI.Text(p, "large", "goldText")
    t:SetPoint("TOPLEFT", 2, y)
    t:SetText(text)
    return t
  end
  local function btn(label, x, y, fn, w)
    local b = UI:Button(p, label, w or 130, fn)
    b:SetPoint("TOPLEFT", x, y)
    return b
  end
  -- export, import, reload and the class colour live on Settings (one place each, 2026-11-20 layout)
  head("Diagnostics", 0)
  btn("Run probe", 0, -24, function() ns.Slash:Run("probe") p:Refresh() end)
  btn("Reload UI", 138, -24, function() ReloadUI() end)
  p.debug = UI:Check(p, "Debug logging", function() return ns.db.global.debug end,
    function(on) ns.db.global.debug = on and true or false end)
  p.debug:SetPoint("TOPLEFT", 290, -24)
  p.errHead = head("Errors", -68)
  p.errorsBtn = btn("Copy report", 0, -196, function() ns.Slash:Run("errors") end, 120)
  p.errorsBtn:ClearAllPoints()
  p.errorsBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -4, -64)
  local clear = btn("Clear errors", 0, -196, function() ns.Slash:Run("errors clear") p:Refresh() end, 120)
  clear:ClearAllPoints()
  clear:SetPoint("RIGHT", p.errorsBtn, "LEFT", -8, 0)
  p.errList = UI:ScrollList(p, {
    rows = 14, rowHeight = 22,
    build = function(row)
      row:SetScript("OnEnter", function(self)
        if not self.full then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.full, 1, 1, 1, true)
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end,
    render = function(row, e)
      local where = tostring(e.where or "?"):gsub("^module:", "")
      local msg = tostring(e.msg or ""):gsub("^[^:]*%.lua:%d+: ", "")
      local taint = tostring(e.msg or ""):find("BLOCKED", 1, true) or tostring(e.kind or "") == "taint"
      local old = not (e.build and e.build == ns.build) -- from an earlier build: greyed, with a tag
      row.text:SetText(string.format("%sx%d|r  |cfff1d58e%s|r  %s%s", Theme:Hex(old and "muted" or taint and "warn" or "bad"), e.count or 1, where,
        old and "|cff8f96a6" or "", msg .. (old and "  (earlier build)|r" or "")))
      row.full = tostring(e.msg or "")
    end,
  })
  p.errList:SetPoint("TOPLEFT", 0, -94)
  p.errList:SetPoint("RIGHT", p, "RIGHT", -4, 0)
  p.empty = UI.Text(p, "normal", "good")
  p.empty:SetPoint("TOPLEFT", 4, -228)
  p.empty:SetText("No errors. Everything Outrider ran this session worked.")
  p.probe = UI.Text(p, "small", "muted")
  p.probe:SetPoint("LEFT", p.debug, "RIGHT", 210, 0)
  function p:Refresh()
    local n = #ns.Errors.list
    local fresh = ns.Errors:Fresh()
    self.errHead:SetText(n > 0 and string.format("Errors (%d on this build, %d earlier)", fresh, n - fresh) or "Errors")
    self.debug:Refresh()
    self.probe:SetText(ns.Probe:Summary())
    local list = ns.Errors:Recent(100)
    self.errList:SetItems(list)
    self.errList:SetShown(#list > 0)
    self.empty:SetShown(#list == 0)
  end
end, 90)

-- ------------------------------------------------------------- page tour
-- Development only (Gary, 2026-11-18, D19): a screenshot of every Outrider
-- page so Claude can review the UI. /ride tour opens the first page and shows
-- a Next button; each click of Next saves one screenshot of what's on screen
-- (the game's own Screenshot()), then moves on. Nothing happens without that
-- click, it never runs in combat, and it only pictures Outrider's interface.
local C = ns.Compat
local Tour = {}
Hub.Tour = Tour

function Tour:Steps()
  local steps = {}
  for _, t in ipairs(Hub.tabs) do
    if Hub:Visible(t) then steps[#steps + 1] = { label = t.title, tab = t.id } end
  end
  steps[#steps + 1] = { label = "World map with pins", map = true }
  steps[#steps + 1] = { label = "World map Pins menu", map = true, menu = true }
  return steps
end

function Tour:Bar()
  if self.bar then return self.bar end
  local b = CreateFrame("Frame", "Outrider_TourBar", UIParent, Theme:BackdropTemplate())
  b:SetSize(360, 34)
  b:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 140)
  b:SetFrameStrata("FULLSCREEN_DIALOG")
  Theme:ApplyPanel(b, "panel")
  b.text = UI.Text(b, "small", "text")
  b.text:SetPoint("LEFT", 10, 0)
  b.text:SetWidth(220)
  b.text:SetJustifyH("LEFT")
  b.next = UI:Button(b, "Next", 60, function() Tour:Capture() end)
  b.next:SetPoint("RIGHT", -72, 0)
  b.stop = UI:Button(b, "Stop", 56, function() Tour:Stop("stopped") end)
  b.stop:SetPoint("RIGHT", -8, 0)
  UI.Tip(b.next, "Next", "Saves a screenshot of this page, then opens the next one.")
  UI.Tip(b.stop, "Stop", "Ends the page tour.")
  self.bar = b
  return b
end

function Tour:Show()
  local s = self.steps and self.steps[self.i]
  if not s then return self:Stop("done") end
  local map = rawget(_G, "WorldMapFrame")
  if s.map then
    if Hub.frame then Hub.frame:Hide() end
    if map and not map:IsShown() and type(rawget(_G, "ToggleWorldMap")) == "function" then pcall(ToggleWorldMap) end
    if s.menu and ns.MapPins and ns.MapPins.ToggleMenu then
      local menu = rawget(_G, "Outrider_MapPinsMenu")
      if not (menu and menu:IsShown()) then ns.Safe("tour:pinsmenu", ns.MapPins.ToggleMenu, ns.MapPins) end
    end
  else
    local f = Hub:Build()
    f:Show()
    Hub:ShowTab(s.tab)
  end
  local b = self:Bar()
  b.text:SetText(string.format("Tour %d/%d: %s", self.i, #self.steps, s.label))
  b:Show()
end

function Tour:Start()
  if C.InCombat() then ns.Print("tour: not in combat") return end
  self.steps, self.i, self.shots = self:Steps(), 1, 0
  ns.Log:Info("tour", "page tour started: %d steps", #self.steps)
  self:Show()
end

-- Gary's click: hide the bar, take the picture, then move on.
function Tour:Capture()
  if not self.steps or self.busy then return end
  if C.InCombat() then ns.Print("tour: paused in combat") return end
  self.busy = true
  local b = self:Bar()
  b:Hide()
  local s = self.steps[self.i]
  ns.Timer.After(0.1, function()
    if C.Has("Screenshot") then C.Call("Screenshot") self.shots = self.shots + 1 end
    ns.Log:Info("tour", "screenshot %d: %s", self.i, s and s.label or "?")
  end, "tour:shot")
  ns.Timer.After(1.2, function()
    self.busy = false
    self.i = self.i + 1
    self:Show()
  end, "tour:next")
end

function Tour:Stop(why)
  if self.bar then self.bar:Hide() end
  local map = rawget(_G, "WorldMapFrame")
  if map and map:IsShown() and type(rawget(_G, "ToggleWorldMap")) == "function" then pcall(ToggleWorldMap) end
  local menu = rawget(_G, "Outrider_MapPinsMenu")
  if menu and menu:IsShown() then menu:Hide() end
  ns.Log:Info("tour", "page tour %s: %d screenshots", tostring(why), self.shots or 0)
  ns.Print("tour %s: %d screenshots saved in your Screenshots folder", tostring(why), self.shots or 0)
  self.steps, self.busy = nil, false
end

ns.AddCommand("tour", "tour  development: a screenshot of every Outrider page, one click of Next each", function()
  Tour:Start()
end)

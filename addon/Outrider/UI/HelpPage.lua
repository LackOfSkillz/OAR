-- UI/HelpPage.lua
-- The Help system (Gary, 2026-11-16: the first version was "really bad ux ...
-- we need an elite premium help system").
--   * Landing: a card per section (icon, name, what's in it); click to open.
--   * Left pane: search box and the topic list grouped by section, with icons.
--   * Right pane: one topic at a time in a large readable font, its points
--     one per line, buttons that open the page it describes or run its
--     command, related topics on the same page, Previous / Next.
--   * Every page of the hub gets a "?" next to its title that opens Help on
--     that page's topic (ns.HelpPage.Open(pageId)).
-- Text: UI/HelpData.lua (the same text is docs/USER_GUIDE.md).

local _, ns = ...
local UI = ns.UI
local Theme = ns.Theme
local LIST_W = 250
local ICON = "Interface\\Icons\\"

local H = {}
ns.HelpPage = H

local function icon(sec, size) return sec.icon and string.format("|T%s%s:%d:%d:0:0:64:64:5:59:5:59|t ", ICON, sec.icon, size or 14, size or 14) or "" end

-- Flat list for the left pane: { kind = "section"|"topic", sec, topic, i, j }
function H.Items(query)
  local q = query and query:lower():gsub("^%s+", ""):gsub("%s+$", "") or ""
  local out = {}
  for i, sec in ipairs(ns.HelpData or {}) do
    local hits = {}
    for j, t in ipairs(sec[3]) do
      if q == "" or t[1]:lower():find(q, 1, true) or t[2]:lower():find(q, 1, true) or sec[1]:lower():find(q, 1, true) then
        hits[#hits + 1] = { kind = "topic", sec = sec, topic = t, i = i, j = j }
      end
    end
    if #hits > 0 then
      out[#out + 1] = { kind = "section", sec = sec, i = i }
      for _, h in ipairs(hits) do out[#out + 1] = h end
    end
  end
  return out
end

-- A topic's text as points, one sentence per line.
function H.Points(text)
  local out = {}
  for sentence in (text .. " "):gmatch("(.-[%.%?!:])%s+") do
    sentence = sentence:gsub("^%s+", "")
    if sentence ~= "" then out[#out + 1] = sentence end
  end
  if #out == 0 then out[1] = text end
  return out
end

-- Other topics that open the same page.
function H.Related(topic)
  local out = {}
  if not topic.page then return out end
  for _, sec in ipairs(ns.HelpData or {}) do
    for _, t in ipairs(sec[3]) do
      if t ~= topic and t.page == topic.page then out[#out + 1] = { sec = sec, topic = t } end
    end
  end
  return out
end

-- The first topic about a hub page.
function H.TopicFor(pageId)
  for i, sec in ipairs(ns.HelpData or {}) do
    for j, t in ipairs(sec[3]) do
      if t.page == pageId then return { kind = "topic", sec = sec, topic = t, i = i, j = j } end
    end
  end
end

local function pageTitle(id)
  local t = ns.Hub and ns.Hub.byId[id]
  return t and t.title or id
end

local function goPage(id)
  local f = ns.Hub and ns.Hub.frame
  if f and f.tabBar and f.tabBar.buttons[id] then f.tabBar:Select(id) elseif ns.Hub then ns.Hub:ShowTab(id) end
end

-- Open Help, on the topic for this page if there is one.
function H.Open(pageId)
  local hub = ns.Hub
  if not hub then return end
  if not (hub.frame and hub.frame:IsShown()) then hub:Toggle() end
  goPage("help")
  local p = hub.byId.help and hub.byId.help.panel
  if p and p.search then
    p.search:SetText("")
    H.Filter(p, "")
    local it = pageId and H.TopicFor(pageId)
    if it then
      for _, o in ipairs(p.items) do if o.topic == it.topic then H.Show(p, o) end end
    else
      H.Landing(p)
    end
  end
end

-- ------------------------------------------------------------------ build
function H.Build(p)
  p.search = UI:SearchBox(p, LIST_W, "Search help", function(text) H.Filter(p, text) end)
  p.search:SetPoint("TOPLEFT", 0, 0)
  UI.Tip(p.search, "Search help", "Type any word: a feature, a spell, a page name. The list keeps only the topics that mention it.")
  p.home = UI:Button(p, "All sections", LIST_W, function() p.search:SetText("") H.Filter(p, "") H.Landing(p) end)
  p.home:SetPoint("TOPLEFT", p.search, "BOTTOMLEFT", 0, -6)
  UI.Tip(p.home, "All sections", "Back to the overview of every part of Outrider.")
  p.list = UI:ScrollList(p, {
    rows = 28, rowHeight = 22,
    render = function(row, it)
      if it.kind == "section" then
        row.text:SetText(icon(it.sec) .. "|cffc9a227" .. it.sec[1]:upper() .. "|r")
      else
        local on = p.current and p.current.topic == it.topic
        row.text:SetText(on and ("      |cffffd100" .. it.topic[1] .. "|r") or ("      " .. it.topic[1]))
      end
    end,
    onClick = function(it)
      if it.kind == "section" then
        for _, o in ipairs(p.items) do if o.kind == "topic" and o.i == it.i then H.Show(p, o) return end end
      else
        H.Show(p, it)
      end
    end,
  })
  p.list:SetPoint("TOPLEFT", p.home, "BOTTOMLEFT", 0, -6)
  p.list:SetWidth(LIST_W)

  -- right pane: a card holding either the landing grid or one topic
  local right = UI:Card(p, true)
  right:SetPoint("TOPLEFT", LIST_W + 18, 0)
  right:SetPoint("BOTTOMRIGHT", 0, 0)
  p.right = right
  H.BuildTopic(p, right)
  H.BuildLanding(p, right)

  function p:Refresh() if not self.items then H.Filter(self, "") end end
  H.Filter(p, "")
  H.Landing(p)
end

function H.BuildTopic(p, right)
  local v = CreateFrame("Frame", nil, right)
  v:SetPoint("TOPLEFT", 22, -18)
  v:SetPoint("BOTTOMRIGHT", -22, 14)
  p.topicView = v
  v.icon = v:CreateTexture(nil, "ARTWORK")
  v.icon:SetSize(40, 40)
  v.icon:SetPoint("TOPLEFT", 0, 0)
  v.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  v.sec = UI.Text(v, "small", "muted")
  v.sec:SetPoint("TOPLEFT", v.icon, "TOPRIGHT", 12, -2)
  v.title = UI.Display(v, "page", "text")
  v.title:SetPoint("TOPLEFT", v.sec, "BOTTOMLEFT", 0, -4)
  v.title:SetPoint("RIGHT", v, "RIGHT", 0, 0)
  v.title:SetJustifyH("LEFT")
  v.rule = v:CreateTexture(nil, "ARTWORK")
  v.rule:SetHeight(1)
  v.rule:SetPoint("TOPLEFT", v.icon, "BOTTOMLEFT", 0, -12)
  v.rule:SetPoint("RIGHT", v, "RIGHT", 0, 0)
  local r, g, b = Theme:Color("gold")
  v.rule:SetColorTexture(r, g, b, 0.45)
  -- points: up to 8 lines, each with a gold bullet
  v.points = {}
  for i = 1, 8 do
    local dot = v:CreateTexture(nil, "ARTWORK")
    dot:SetSize(6, 6)
    dot:SetColorTexture(r, g, b, 0.9)
    local line = UI.Text(v, "large", "text")
    line:SetJustifyH("LEFT")
    line:SetPoint("RIGHT", v, "RIGHT", 0, 0)
    if line.SetSpacing then line:SetSpacing(4) end
    v.points[i] = { dot = dot, line = line }
  end
  v.intro = UI.Text(v, "normal", "muted")
  v.intro:SetJustifyH("LEFT")
  v.intro:SetPoint("RIGHT", v, "RIGHT", 0, 0)
  if v.intro.SetSpacing then v.intro:SetSpacing(3) end
  v.open = UI:PrimaryButton(v, "Open page", 200, function()
    local t = p.current and p.current.topic
    if t and t.page then goPage(t.page) end
  end)
  v.run = UI:Button(v, "Run", 200, function()
    local t = p.current and p.current.topic
    if t and t.cmd then ns.Slash:Run(t.cmd) end
  end)
  UI.Tip(v.open, "Open the page", "Goes straight to the Outrider page this topic is about.")
  UI.Tip(v.run, "Run the command", "Runs it now, as if you typed it in chat. Results show in chat.")
  v.relHead = UI.Text(v, "small", "muted")
  v.related = {}
  for i = 1, 4 do
    local c = UI:Chip(v, "", function(btn) if btn.item then
      for _, o in ipairs(p.items) do if o.topic == btn.item.topic then H.Show(p, o) return end end
      p.search:SetText("") H.Filter(p, "")
      for _, o in ipairs(p.items) do if o.topic == btn.item.topic then H.Show(p, o) return end end
    end end)
    v.related[i] = c
  end
  v.prev = UI:Button(v, "< Previous", 120, function() H.Step(p, -1) end)
  v.prev:SetPoint("BOTTOMLEFT", 0, 0)
  v.next = UI:Button(v, "Next >", 120, function() H.Step(p, 1) end)
  v.next:SetPoint("LEFT", v.prev, "RIGHT", 8, 0)
  v.count = UI.Text(v, "small", "muted")
  v.count:SetPoint("LEFT", v.next, "RIGHT", 14, 0)
  UI.Tip(v.prev, "Previous topic", "The topic above this one in the list.")
  UI.Tip(v.next, "Next topic", "The topic below this one. Read the whole guide front to back this way.")
end

function H.BuildLanding(p, right)
  local v = CreateFrame("Frame", nil, right)
  v:SetPoint("TOPLEFT", 22, -18)
  v:SetPoint("BOTTOMRIGHT", -22, 14)
  p.landing = v
  v.title = UI.Display(v, "page", "text")
  v.title:SetPoint("TOPLEFT", 0, 0)
  v.title:SetText("Outrider Help")
  v.sub = UI.Text(v, "large", "muted")
  v.sub:SetPoint("TOPLEFT", v.title, "BOTTOMLEFT", 0, -8)
  v.sub:SetPoint("RIGHT", v, "RIGHT", 0, 0)
  v.sub:SetJustifyH("LEFT")
  v.sub:SetText("Everything Outrider does, one topic at a time. Pick a section, search on the left, or press ? on any page for help with that page.")
  v.cards = {}
end

function H.Landing(p)
  p.current = nil
  p.topicView:Hide()
  local v = p.landing
  v:Show()
  local w = (v:GetWidth() or 700)
  if w < 300 then w = 700 end
  local cols = 3
  local gap = 12
  local cw = math.floor((w - gap * (cols - 1)) / cols)
  local ch = 92 -- room for a two-line name and three lines of topics (tour 2026-11-19: text ran past the card)
  for i, sec in ipairs(ns.HelpData or {}) do
    local c = v.cards[i]
    if not c then
      c = CreateFrame("Button", nil, v, Theme:BackdropTemplate())
      Theme:ApplyPanel(c, "bg", "border")
      c.icon = c:CreateTexture(nil, "ARTWORK")
      c.icon:SetSize(32, 32)
      c.icon:SetPoint("TOPLEFT", 10, -10)
      c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      c.name = UI.Display(c, "card", "text")
      c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 10, 0)
      c.name:SetPoint("RIGHT", c, "RIGHT", -8, 0)
      c.name:SetJustifyH("LEFT")
      c.blurb = UI.Text(c, "small", "muted")
      c.blurb:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -4)
      c.blurb:SetPoint("RIGHT", c, "RIGHT", -8, 0)
      c.blurb:SetJustifyH("LEFT")
      if c.blurb.SetWordWrap then c.blurb:SetWordWrap(true) end
      if c.blurb.SetMaxLines then c.blurb:SetMaxLines(3) end
      c.blurb:SetPoint("BOTTOM", c, "BOTTOM", 0, 6)
      if c.blurb.SetJustifyV then c.blurb:SetJustifyV("TOP") end
      c:SetScript("OnEnter", function(self) if self.SetBackdropBorderColor then self:SetBackdropBorderColor(Theme:Color("gold")) end end)
      c:SetScript("OnLeave", function(self) if self.SetBackdropBorderColor then self:SetBackdropBorderColor(Theme:Color("border")) end end)
      c:SetScript("OnClick", function(self)
        for _, o in ipairs(p.items) do if o.kind == "topic" and o.i == self.index then H.Show(p, o) return end end
      end)
      v.cards[i] = c
    end
    c.index = i
    c:SetSize(cw, ch)
    local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", v.sub, "BOTTOMLEFT", col * (cw + gap), -18 - row * (ch + gap))
    c.icon:SetTexture(sec.icon and (ICON .. sec.icon) or nil)
    c.name:SetText(sec[1])
    local names = {}
    for k, t in ipairs(sec[3]) do if k <= 3 then names[#names + 1] = t[1] end end
    c.blurb:SetText(string.format("%d topics: %s%s", #sec[3], table.concat(names, ", "), #sec[3] > 3 and "..." or ""))
    c:Show()
  end
  p.list:Refresh()
end

function H.Filter(p, text)
  p.items = H.Items(text)
  p.list:SetItems(p.items)
  if text and text ~= "" then
    local keep
    for _, it in ipairs(p.items) do if it.kind == "topic" then keep = it break end end
    H.Show(p, keep)
  elseif p.current then
    for _, it in ipairs(p.items) do if it.topic == p.current.topic then H.Show(p, it) end end
  end
end

function H.Step(p, d)
  local topics, at = {}, nil
  for _, it in ipairs(p.items or {}) do
    if it.kind == "topic" then
      topics[#topics + 1] = it
      if p.current and it.topic == p.current.topic then at = #topics end
    end
  end
  local nxt = topics[(at or 0) + d]
  if nxt then H.Show(p, nxt) end
end

function H.Show(p, it)
  p.landing:Hide()
  local v = p.topicView
  v:Show()
  p.current = it
  for _, pt in ipairs(v.points) do pt.dot:Hide() pt.line:Hide() end
  for _, c in ipairs(v.related) do c:Hide() end
  v.relHead:Hide()
  if not it then
    v.icon:SetTexture(nil)
    v.sec:SetText("")
    v.title:SetText("Nothing found")
    v.intro:SetText("No topic mentions that. Try a shorter word, or clear the search.")
    v.intro:ClearAllPoints()
    v.intro:SetPoint("TOPLEFT", v.rule, "BOTTOMLEFT", 0, -16)
    v.intro:SetPoint("RIGHT", v, "RIGHT", 0, 0)
    v.open:Hide() v.run:Hide()
    v.count:SetText("")
    p.list:Refresh()
    return
  end
  local t = it.topic
  v.icon:SetTexture(it.sec.icon and (ICON .. it.sec.icon) or nil)
  v.sec:SetText(it.sec[1]:upper())
  v.title:SetText(t[1])
  local anchor, y = v.rule, -18
  for i, s in ipairs(H.Points(t[2])) do
    local pt = v.points[i]
    if not pt then break end
    pt.line:SetText(s)
    pt.line:ClearAllPoints()
    pt.line:SetPoint("TOPLEFT", anchor, anchor == v.rule and "BOTTOMLEFT" or "BOTTOMLEFT", anchor == v.rule and 16 or 0, y)
    pt.line:SetPoint("RIGHT", v, "RIGHT", 0, 0)
    pt.dot:ClearAllPoints()
    pt.dot:SetPoint("RIGHT", pt.line, "TOPLEFT", -9, -7)
    pt.dot:Show()
    pt.line:Show()
    anchor, y = pt.line, -12
  end
  v.intro:ClearAllPoints()
  v.intro:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", anchor == v.rule and 0 or -16, -22)
  v.intro:SetPoint("RIGHT", v, "RIGHT", 0, 0)
  v.intro:SetText(it.sec[2] and ("About " .. it.sec[1]:lower() .. ": " .. it.sec[2]) or "")
  local below = v.intro
  v.open:ClearAllPoints()
  v.run:ClearAllPoints()
  if t.page then
    v.open.label:SetText("Open " .. pageTitle(t.page))
    v.open:SetPoint("TOPLEFT", v.intro, "BOTTOMLEFT", 0, -20)
    v.open:Show()
    below = v.open
  else
    v.open:Hide()
  end
  if t.cmd then
    v.run.label:SetText("Run /ride " .. t.cmd)
    if t.page then v.run:SetPoint("LEFT", v.open, "RIGHT", 10, 0) else v.run:SetPoint("TOPLEFT", v.intro, "BOTTOMLEFT", 0, -20) below = v.run end
    v.run:Show()
  else
    v.run:Hide()
  end
  local rel = H.Related(t)
  if #rel > 0 then
    v.relHead:SetText("ALSO ON THIS PAGE")
    v.relHead:ClearAllPoints()
    v.relHead:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -24)
    v.relHead:Show()
    local prev
    for i, r in ipairs(rel) do
      local c = v.related[i]
      if not c then break end
      c.item = r
      c.label:SetText(r.topic[1])
      local tw = c.label.GetStringWidth and c.label:GetStringWidth() or (#r.topic[1] * 7)
      c:SetWidth(math.max(60, (tonumber(tw) or 60) + 24))
      c:ClearAllPoints()
      if prev then c:SetPoint("LEFT", prev, "RIGHT", 6, 0) else c:SetPoint("TOPLEFT", v.relHead, "BOTTOMLEFT", 0, -8) end
      c:Show()
      prev = c
    end
  end
  local n, at = 0, 0
  for _, o in ipairs(p.items or {}) do if o.kind == "topic" then n = n + 1 if o.topic == t then at = n end end end
  v.count:SetText(string.format("Topic %d of %d", at, n))
  p.list:Refresh()
  for idx, o in ipairs(p.items or {}) do
    if o == it then
      local rows = #p.list.rowFrames
      if idx <= p.list.offset or idx > p.list.offset + rows then p.list:SetOffset(idx - 2) end
    end
  end
end

ns.Hub:AddTab("help", "Help", function(p) H.Build(p) end)

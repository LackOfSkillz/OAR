-- UI/Pages/Settings.lua
-- Settings and All commands pages. Split from UI/Pages.lua (OI01-08); page ids, titles and order unchanged.

local _, ns = ...
local UI, Theme = ns.UI, ns.Theme
local C = ns.Compat
local Run = UI.Run
local K = ns.PageKit
local mod, set, onoff = K.mod, K.set, K.onoff

ns.Hub:AddTab("settings", "Settings", function(p)
  local A = function() return ns.Theme:Access() end
  local confirm = false
  UI:FormPage(p, {
    { "header", "Look" },
    { "custom", function(host)
      local row = CreateFrame("Frame", nil, host)
      row:SetSize(570, 58)
      local box = UI:SearchBox(row, 300, "Find a setting...")
      box:SetPoint("TOPLEFT", 0, 0)
      local result = UI.Text(row, "small", "muted")
      result:SetPoint("LEFT", box, "RIGHT", 8, 0)
      local function find()
        local label, matches = p.form:FindSetting(box:GetText())
        result:SetText(label and (matches .. " matches: " .. label) or "No setting found")
      end
      box:SetScript("OnEnterPressed", find)
      -- Results as you type, grouped by section, each switch showing ON/OFF;
      -- click one to jump there (gallery idea from Leatrix Plus, 2026-11-18).
      local res = UI:ScrollList(p, {
        rows = 8, rowHeight = 22,
        render = function(r, m)
          local state = m.on == true and "  |cff66d980ON|r" or m.on == false and "  |cff8f96a6OFF|r" or ""
          r.text:SetText(string.format("|cff8f96a6%s:|r  %s%s", m.section ~= "" and m.section or "Settings", m.label, state))
        end,
        onClick = function(m) p.form:JumpTo(m.y) p.searchResults:Hide() end,
      })
      res:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -2)
      res:SetWidth(520)
      if res.SetFrameStrata then res:SetFrameStrata("DIALOG") end
      res:Hide()
      p.searchResults = res
      box:HookScript("OnTextChanged", function(self)
        local q = self:GetText() or ""
        local list = q ~= "" and p.form and p.form:SearchAll(q) or {}
        res:SetItems(list)
        res:SetShown(#list > 0)
        result:SetText(q == "" and "" or (#list .. " found"))
      end)
      box:HookScript("OnEscapePressed", function() res:Hide() end)
      local btn = UI:Button(row, "Find next", 110, find)
      btn:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -4)
      UI.Tip(btn, "Find next setting", "Searches settings labels and scrolls to the next matching control.")
      row.searchBox, row.searchResult, row.searchNext = box, result, btn
      p.settingsSearch = row
      return row
    end, 65 },
    { "check", "Class color accent (after reload)", function() return ns.db.char.classAccent ~= false end,
      function(on) ns.db.char.classAccent = on and true or false end },
    { "check", "Minimap button", function() return not ns.db.global.minimap.hide end,
      function(on) ns.Slash:Run("minimap " .. onoff(on)) end },
    { "slider", "Text size (after reload)", 0.8, 1.5, 0.1, function() return A().fontScale or 1 end,
      function(v) ns.Slash:Run(string.format("access font %.1f", v)) end, "%.1f" },
    { "slider", "Window size (after reload)", 0.7, 1.5, 0.1, function() return A().uiScale or 1 end,
      function(v) ns.Slash:Run(string.format("access scale %.1f", v)) end, "%.1f" },
    { "check", "Colorblind colors", function() return A().colorblind end, function(on) ns.Slash:Run("access colorblind " .. onoff(on)) end },
    { "check", "High contrast", function() return A().highContrast end, function(on) ns.Slash:Run("access contrast " .. onoff(on)) end },
    { "check", "Reduced motion", function() return A().reducedMotion end, function(on) ns.Slash:Run("access motion " .. onoff(not on)) end },
    { "buttons", { { "Reload now", function() C.Call("ReloadUI") end }, { "First-run setup", Run("setup") } } },
    { "header", "Info bar" },
    { "check", "Show the info bar", function() return ns.InfoBar:Settings().shown end, function(on) ns.Slash:Run("bar " .. onoff(on)) end },
    { "check", "Bar: gold", function() return ns.InfoBar:Settings().gold ~= false end, function(on) ns.InfoBar:Settings().gold = on ns.InfoBar:Apply() end },
    { "check", "Bar: bag space", function() return ns.InfoBar:Settings().bags ~= false end, function(on) ns.InfoBar:Settings().bags = on ns.InfoBar:Apply() end },
    { "check", "Bar: durability", function() return ns.InfoBar:Settings().dura ~= false end, function(on) ns.InfoBar:Settings().dura = on ns.InfoBar:Apply() end },
    { "check", "Bar: ammo", function() return ns.InfoBar:Settings().ammo ~= false end, function(on) ns.InfoBar:Settings().ammo = on ns.InfoBar:Apply() end },
    { "check", "Bar: experience", function() return ns.InfoBar:Settings().xp ~= false end, function(on) ns.InfoBar:Settings().xp = on ns.InfoBar:Apply() end },
    { "check", "Bar: clock", function() return ns.InfoBar:Settings().clock ~= false end, function(on) ns.InfoBar:Settings().clock = on ns.InfoBar:Apply() end },
    { "check", "Bar: latency and frame rate", function() return ns.InfoBar:Settings().net ~= false end, function(on) ns.InfoBar:Settings().net = on ns.InfoBar:Apply() end },
    { "buttons", { { "Put the bar back at the top", Run("bar reset"), 210 } } },
    { "header", "Bags" },
    { "check", "Bag slots: item level", function() return ns.BagExtras:Settings().ilvl end, function(on) ns.BagExtras:Settings().ilvl = on ns.BagExtras:UpdateAll() end },
    { "check", "Bag slots: upgrade arrows", function() return ns.BagExtras:Settings().upgrade end, function(on) ns.BagExtras:Settings().upgrade = on ns.BagExtras:UpdateAll() end },
    { "check", "Bag slots: junk coins", function() return ns.BagExtras:Settings().junk end, function(on) ns.BagExtras:Settings().junk = on ns.BagExtras:UpdateAll() end },
    { "header", "Tooltip details" },
    { "check", "Only show Outrider tooltip details while holding Shift",
      function() return ns.TooltipLines:Settings().shiftOnly end,
      function(on) ns.TooltipLines:Settings().shiftOnly = on and true or false end },
    { "slider", "Maximum tooltip lines per source (0 = all)", 0, 10, 1,
      function() return ns.TooltipLines:Settings().limit end,
      function(value) ns.TooltipLines:Settings().limit = math.floor(value + 0.5) end, "%.0f" },
    { "slider", "Quest item references per category", 1, 10, 1,
      function() return ns.TooltipLines:Settings().questUsesLimit or 2 end,
      function(value) ns.TooltipLines:Settings().questUsesLimit = math.floor(value + 0.5) end, "%.0f" },
    { "check", "Tooltip: quest objectives", function() return ns.TooltipLines:Enabled("quest") end,
      function(on) ns.TooltipLines:SetEnabled("quest", on) end },
    { "check", "Tooltip: quests started by / using items", function() return ns.TooltipLines:Enabled("questuses") end,
      function(on) ns.TooltipLines:SetEnabled("questuses", on) end },
    { "check", "Tooltip: gear comparisons", function() return ns.TooltipLines:Enabled("verdict") end,
      function(on) ns.TooltipLines:SetEnabled("verdict", on) end },
    { "check", "Tooltip: item market values", function() return ns.TooltipLines:Enabled("value") end,
      function(on) ns.TooltipLines:SetEnabled("value", on) end },
    { "check", "Tooltip: rare and beast details", function() return ns.TooltipLines:Enabled("beast") end,
      function(on) ns.TooltipLines:SetEnabled("beast", on) end },
    { "note", "For every individual tooltip source, use /ride toolextras list, hide <key>, or show <key>. Re-hover if Shift refresh is unavailable." },
    { "header", "Small switches" },
    { "check", "Hide the big zone names", function() return ns.Tweaks:Settings().zoneText end, function(on) ns.Tweaks:Settings().zoneText = on ns.Tweaks:ApplyClutter() end },
    { "check", "Hide red error text", function() return ns.Tweaks:Settings().errors end, function(on) ns.Tweaks:Settings().errors = on ns.Tweaks:ApplyClutter() end },
    { "check", "Hide the talking head", function() return ns.Tweaks:Settings().talkingHead end, function(on) ns.Tweaks:Settings().talkingHead = on ns.Tweaks:ApplyClutter() end },
    { "check", "Camera zooms out further", function() return ns.Tweaks:Settings().zoom end, function(on) ns.Tweaks:Settings().zoom = on ns.Tweaks:ApplyZoom() end },
    { "check", "Gather addon minimap buttons", function() return ns.Tweaks:Settings().buttonBag end, function(on) ns.Tweaks:Settings().buttonBag = on ns.Tweaks:Gather(on) end },
    { "note", "Wowhead link: hover an item, NPC or spell and press the key you bind to Outrider: Wowhead link (Key Bindings, AddOns), or type /ride wowhead." },
    { "header", "Edit Mode layout per situation" },
    { "input", "Situation and layout", "questing Questing", "Set", function(t) ns.Slash:Run("layout " .. t) end },
    { "buttons", { { "Show layouts", Run("layout") }, { "Turn off", Run("layout off") } } },
    { "header", "Your settings" },
    { "buttons", { { "Export", Run("export") }, { "Import", Run("import") }, { "Copy from a character", function() ns.Hub.frame.tabBar:Select("characters") end } } },
    { "buttons", { { "Reset this character", function(self)
      if not confirm then confirm = true self.label:SetText("Click again to reset") return end
      ns.Slash:Run("reset char confirm")
    end, 170 } } },
  })
end)

-- ---------------------------------------------------------- All commands
-- Every /ride command with its help line: pick one, add what it needs, Run.
ns.Hub:AddTab("commands", "All commands", function(p)
  local head = UI.Text(p, "small", "muted")
  head:SetPoint("TOPLEFT", 0, 0)
  head:SetText("Every Outrider command. Type to filter, click one, add what it needs, then Run. Results show in chat.")
  p.filter = UI:SearchBox(p, 220, "filter commands")
  p.filter:SetPoint("TOPRIGHT", p, "TOPRIGHT", -4, 2)
  p.filter:HookScript("OnTextChanged", function() if p.Refresh then p:Refresh() end end)
  p.count = UI.Text(p, "small", "muted")
  p.count:SetPoint("RIGHT", p.filter, "LEFT", -10, 0)
  p.list = UI:ScrollList(p, {
    rows = 22, rowHeight = 22,
    -- the usage repeats the name ("bossloot bossloot <boss>"): show it once
    render = function(row, c)
      local usage = tostring(c.usage or ""):gsub("^" .. c.name:gsub("%p", "%%%0") .. "%s*", "")
      -- "|" starts a colour or link code in game text ("add|remove" showed as
      -- "addemove"); doubled, it prints as a plain bar
      usage = usage:gsub("|", "||")
      row.text:SetText(string.format("|cfff1d58e%s|r   |cffc3c8d2%s|r", c.name, usage))
    end,
    onClick = function(c) p.current = c p.label:SetText(c.name) p.box:SetText("") p.box:SetFocus() end,
  })
  p.list:SetPoint("TOPLEFT", 0, -26)
  p.list:SetPoint("RIGHT", p, "RIGHT", -4, 0)
  p.label = UI.Text(p, "large", "goldText")
  p.label:SetPoint("TOPLEFT", p.list, "BOTTOMLEFT", 0, -10)
  p.label:SetText("Pick a command")
  p.box = UI:SearchBox(p, 300, "what it needs, if anything")
  p.box:SetPoint("LEFT", p.label, "RIGHT", 10, 0)
  local function run()
    if not p.current then return end
    ns.Slash:Run(p.current.name .. " " .. (p.box:GetText() or ""))
    p.box:ClearFocus()
  end
  p.run = UI:Button(p, "Run", 80, run)
  p.run:SetPoint("LEFT", p.box, "RIGHT", 6, 0)
  p.box:SetScript("OnEnterPressed", run)
  function p:Refresh()
    local out = {}
    for _, name in ipairs(ns.Slash.order) do
      local c = ns.Slash.commands[name]
      local q = tostring(self.filter and self.filter:GetText() or ""):lower()
      if c and (q == "" or name:find(q, 1, true) or tostring(c.usage or ""):lower():find(q, 1, true)) then
        out[#out + 1] = { name = name, usage = c.usage }
      end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    self.list:SetItems(out)
    self.count:SetText(#out .. " commands")
  end
end)

-- UI/Pages.lua
-- Hub pages that turn /ride commands into controls (Gary, 2026-11-13: "do
-- everything inside the Outrider window, logical and helpful"). Buttons run
-- the same code as the typed command (UI.Run), so nothing behaves differently.
-- Anything without its own control is on the All commands page.
-- Home: what you need right now (nearest places, where you're headed, best
-- quests, upgrades, rare watch, errands, pet).

local _, ns = ...
local UI, Theme = ns.UI, ns.Theme
local C = ns.Compat
local Run = UI.Run

local function mod(name) return ns.Modules:Get(name) end
local function set(name) local m = mod(name) return m and m:Settings() or {} end
local function onoff(v) return v and "on" or "off" end

-- ------------------------------------------------------------------ Home
local NEAREST = { { "Inn", "inn" }, { "Vendor", "vendor" }, { "Repair", "repair" }, { "Flight", "flight" },
  { "Trainer", "trainer" }, { "Mail", "mail" }, { "Bank", "bank" }, { "Auction", "ah" }, { "Stable", "stable" },
  { "Spirit healer", "spirit" } }

local function card(parent, title, x, y, w, h)
  local f = CreateFrame("Frame", nil, parent, Theme:BackdropTemplate())
  f:SetPoint("TOPLEFT", x, y)
  f:SetSize(w, h)
  Theme:ApplyPanel(f, "panel")
  f.title = UI.Text(f, "normal", "accent")
  f.title:SetPoint("TOPLEFT", 8, -6)
  f.title:SetText(title)
  f.body = UI.Text(f, "small", "text")
  f.body:SetPoint("TOPLEFT", 8, -24)
  f.body:SetWidth(w - 16)
  f.body:SetJustifyH("LEFT")
  f.body:SetJustifyV("TOP")
  return f
end

ns.Hub:AddTab("home", "Home", function(p)
  local W2 = 300
  p.near = card(p, "Nearest", 0, 0, W2 * 2 + 10, 68)
  local prev
  for i, n in ipairs(NEAREST) do
    local b = UI:Button(p.near, n[1], 84, function() ns.Nearest:Go(n[2]) end)
    if i == 1 then b:SetPoint("TOPLEFT", 8, -24) elseif i == 7 then b:SetPoint("TOPLEFT", 8, -46)
    else b:SetPoint("LEFT", prev, "RIGHT", 4, 0) end
    b:SetHeight(20)
    prev = b
  end
  p.near.body:Hide()
  p.journey = card(p, "Where you're headed", 0, -76, W2, 74)
  p.stop = UI:Button(p.journey, "Stop", 60, function() ns.Journey:Stop("home") p:Refresh() end)
  p.stop:SetPoint("BOTTOMRIGHT", -6, 6)
  p.quests = card(p, "Best quests for you (XP per minute)", W2 + 10, -76, W2, 74)
  p.gear = card(p, "Upgrades in this zone", 0, -158, W2, 90)
  p.rares = card(p, "Rare watch", W2 + 10, -158, W2, 90)
  p.errands = card(p, "To do in town", 0, -256, W2, 90)
  p.pet = card(p, "Pet", W2 + 10, -256, W2, 90)
  p.more = UI.Text(p, "small", "muted")
  p.more:SetPoint("TOPLEFT", 0, -354)
  p.more:SetText("Search anything with the box at the top. Every page is in the sidebar; Outrider > All commands lists the rest.")
  function p:Refresh()
    local J = ns.Journey
    if J and J.goal then
      self.journey.body:SetText(string.format("%s\n%s", tostring(J.goal.name),
        J.route and J.route.steps[1] and J.route.steps[1].text or ""))
      self.stop:Show()
    else
      self.journey.body:SetText("Nowhere. Pick a quest, rare or place in Journey and click Guide me.")
      self.stop:Hide()
    end
    local lines = {}
    if ns.Finder then
      local list = ns.Finder:Find({ kind = "quest" })
      for i = 1, math.min(3, #list) do
        local e = list[i]
        lines[#lines + 1] = string.format("[%d] %s, %s", e.level or 0, tostring(e.name), ns.Travel.Minutes(e.seconds))
      end
    end
    self.quests.body:SetText(#lines > 0 and table.concat(lines, "\n") or "None found (the NPC pack may be missing).")
    lines = {}
    for i, c in ipairs(ns.Nearby and ns.Nearby:Candidates() or {}) do
      if i > 4 then break end
      lines[#lines + 1] = (ns.Nearby.Describe(c):gsub("|c%x+", ""):gsub("|r", ""))
    end
    self.gear.body:SetText(#lines > 0 and table.concat(lines, "\n") or "Nothing better here right now.")
    lines = {}
    for k in pairs(set("RareScan").watch or {}) do lines[#lines + 1] = ns.TitleCase(tostring(k)) end
    table.sort(lines)
    self.rares.body:SetText(#lines > 0 and ("Watching: " .. table.concat(lines, ", ")) or "Not watching any rare. Add one in Rare alerts.")
    lines = {}
    for _, e in ipairs(ns.Errands and ns.Errands:List() or {}) do lines[#lines + 1] = e.text end
    self.errands.body:SetText(#lines > 0 and table.concat(lines, "\n") or "Nothing to do in town.")
    local pet = mod("PetStatus")
    self.pet.body:SetText(pet and pet.enabled and pet:Activity() or "No pet tools for this class.")
  end
end)

-- ------------------------------------------------------------ Waypoints
ns.Hub:AddTab("waypoints", "Waypoints", function(p)
  UI:FormPage(p, {
    { "header", "Waypoint" },
    { "note", function()
      local w = ns.Waypoints.current
      return w and ("Arrow to " .. tostring(w.title) .. ", " .. tostring(ns.Waypoints:Activity())) or "No waypoint set."
    end },
    { "input", "Coordinates (x y)", "45.2 61.8", "Set arrow", function(t) ns.Slash:Run("way " .. t) end },
    { "buttons", { { "Clear arrow", Run("way clear") }, { "Say my coordinates", Run("coords") } } },
    { "header", "Nearest place" },
    { "buttons", { { "Inn", Run("near inn") }, { "Vendor", Run("near vendor") }, { "Repair", Run("near repair") },
      { "Flight", Run("near flight") }, { "Trainer", Run("near trainer") } } },
    { "buttons", { { "Mail", Run("near mail") }, { "Bank", Run("near bank") }, { "Auction", Run("near ah") },
      { "Stable", Run("near stable") }, { "Spirit healer", Run("near spirit") } } },
    { "check", "Arrow to the spirit healer when you die", function() return set("Nearest").spiritOnDeath end,
      function(on) set("Nearest").spiritOnDeath = on end },
    { "header", "Map and minimap pins" },
    { "slider", "Places on the minimap", 0, 30, 1, function() return set("MinimapPins").max or 12 end,
      function(v) ns.Slash:Run("minipins " .. v) end, "%d" },
    { "check", "Quest givers on the minimap", function() return set("MinimapPins").quests end,
      function(on) ns.Slash:Run("minipins quests " .. onoff(on)) end },
    { "check", "Grey quests (no XP) on the map", function() return set("NPCPack").grey end,
      function(on) ns.Slash:Run("questpins grey " .. onoff(on)) end },
  })
end)

-- ---------------------------------------------------------- Rare alerts
ns.Hub:AddTab("rarealerts", "Rare alerts", function(p)
  local function watched()
    local out = {}
    for k in pairs(set("RareScan").watch or {}) do out[#out + 1] = k end
    table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
    return out
  end
  UI:FormPage(p, {
    { "header", "Watch list" },
    { "input", "Watch a rare", "Mystmane, or an NPC id", "Watch", function(t) ns.Slash:Run("watch " .. t) end },
    { "note", "Click a name to stop watching it." },
    { "list", 5, function(row, k) row.text:SetText(ns.TitleCase(tostring(k))) end,
      function(k) ns.Slash:Run("unwatch " .. tostring(k)) p:Refresh() end, watched },
    { "header", "How you're told" },
    { "check", "Sound", function() return set("RareAlerts").sound end, function(on) set("RareAlerts").sound = on end },
    { "check", "Pop-up", function() return set("RareAlerts").toast end, function(on) set("RareAlerts").toast = on end },
    { "check", "Only rares on your watch list", function() return set("RareAlerts").mode == "watch" end,
      function(on) set("RareAlerts").mode = on and "watch" or "all" end },
    { "header", "Recently met" },
    { "buttons", { { "Last 10 NPCs met", Run("discovered 10") }, { "Rares tab", function() ns.Hub.frame.tabBar:Select("rares") end } } },
  })
end)

-- ---------------------------------------------------------------- Hunter
ns.Hub:AddTab("hunter", "Hunter", function(p)
  local F = function() return set("HunterFight") end
  local function opt(key) return function(on) ns.Slash:Run("fight " .. key .. " " .. onoff(on)) end end
  UI:FormPage(p, {
    { "header", "Fight, Strike and Pet macros" },
    { "note", "Fight (ranged) and Strike (melee) follow your spellbook; Pet revives, calls or mends your pet." },
    { "buttons", { { "Make or show the macros", Run("fight") }, { "Open macro window", function()
      if C.Call("ShowMacroFrame") == nil then C.Call("MacroFrame_LoadUI") C.Call("ShowMacroFrame") end end } } },
    { "check", "Concussive Shot in Fight", function() return F().concussive end, opt("concussive") },
    { "check", "Wing Clip in Strike", function() return F().wingclip end, opt("wingclip") },
    { "check", "Send the pet in", function() return F().pet end, opt("pet") },
    { "check", "Rewrite when you learn a spell", function() return F().auto end, opt("auto") },
    { "header", "Taming" },
    { "input", "Tame macro for", "Mystmane", "Make macro", function(t) ns.Slash:Run("tamemacro " .. t) end },
    { "note", "Press: send the pet in. Shift-press: dismiss it. Press again: Tame Beast." },
    { "header", "Pet and ammo" },
    { "note", function() local m = mod("PetStatus") return m and m.enabled and m:Activity() or "" end },
    { "note", function() local m = mod("Ammo") return m and m.enabled and m:Activity() or "" end },
  })
end, nil, { class = "HUNTER" })

-- -------------------------------------------------------------- Gear sets
ns.Hub:AddTab("gearsets", "Gear sets", function(p)
  local function sets()
    local out = {}
    for name in pairs(set("GearSets").sets or {}) do out[#out + 1] = name end
    table.sort(out)
    return out
  end
  UI:FormPage(p, {
    { "header", "Gear sets" },
    { "input", "Save what you wear as", "Questing", "Save", function(t) ns.Slash:Run("gear save " .. t) end },
    { "note", "Click a set to put it on (out of combat). Delete removes it." },
    { "list", 6, function(row, name) row.text:SetText(name) end, function(name) ns.Slash:Run("gear " .. name) end, sets },
    { "input", "Delete set", "Questing", "Delete", function(t) ns.Slash:Run("gear delete " .. t) end },
    { "header", "How gear is scored" },
    { "buttons", { { "Show my stat weights", Run("weights") }, { "Upgrades in this zone", Run("nearby") } } },
    { "input", "Compare an item", "Shift-click an item here", "Compare", function(t) ns.Slash:Run("score " .. t) end },
  })
end)

-- ------------------------------------------------------------ Professions
ns.Hub:AddTab("professions", "Professions", function(p)
  local function make(prof) return function() if ns.Crafter then ns.Crafter:Make(prof) end end end
  UI:FormPage(p, {
    { "header", "Make what you can" },
    { "note", "Each click makes the best skill-up recipe you have every ingredient for (Create All). Stand by a fire to cook." },
    { "buttons", { { "Cook", make("Cooking") }, { "Brew", make("Alchemy") }, { "Make bar macros (Cook, Brew, Herb)", Run("make") } } },
    { "header", "Skill-up planner" },
    { "input", "Profession and target", "Alchemy 75", "Plan", function(t) ns.Slash:Run("skillup " .. t) end, true },
    { "header", "Herbalism" },
    { "buttons", { { "Where each herb grows", Run("herbs") } } },
    { "note", function() local m = mod("HerbHelper") return m and m.enabled and m:Activity() or "" end },
    { "header", "Fishing" },
    { "input", "Fishing key", "F, or off", "Set key", function(t) ns.Slash:Run("fishkey " .. t) end },
    { "note", function() return "Current key: " .. tostring(set("Fishing").key or "none") end },
    { "header", "Auction house" },
    { "input", "Undercut by", "2% or 50c", "Set", function(t) ns.Slash:Run("undercut " .. t) end },
    { "note", function() local s = set("AuctionHelper") return "Now: " .. (s.undercutCopper and (s.undercutCopper .. " copper") or ((s.undercutPct or 2) .. "%")) end },
  })
end)

-- ----------------------------------------------------------------- Chat
ns.Hub:AddTab("chat", "Chat", function(p)
  local function words()
    local out = {}
    for w in pairs(set("Chat").words or {}) do out[#out + 1] = w end
    table.sort(out)
    return out
  end
  UI:FormPage(p, {
    { "header", "Chat" },
    { "check", "Hide repeated spam", function() return set("Chat").spam end, function(on) ns.Slash:Run("chat spam " .. onoff(on)) end },
    { "check", "LFG and Trade in their own tab", function() return set("Chat").lfgTab end, function(on) ns.Slash:Run("chat lfgtab " .. onoff(on)) end },
    { "check", "Time stamps", function() return (C.Call("GetCVar", "showTimestamps") or "none") ~= "none" end,
      function(on) ns.Slash:Run("chat time " .. onoff(on)) end },
    { "buttons", { { "Copy the last 100 chat lines", Run("copychat") }, { "Recent alerts", Run("feed") } } },
    { "header", "Highlighted words" },
    { "input", "Highlight a word", "Mystmane", "Add", function(t) ns.Slash:Run("chat word add " .. t) end },
    { "note", "Click a word to stop highlighting it." },
    { "list", 4, function(row, w) row.text:SetText(w) end, function(w) ns.Slash:Run("chat word remove " .. w) p:Refresh() end, words },
    { "header", "Spell check" },
    { "input", "Add a word", "Skyborne", "Add", function(t) ns.Slash:Run("spell add " .. t) end },
    { "input", "Remove a word", "Skyborne", "Remove", function(t) ns.Slash:Run("spell remove " .. t) end },
  })
end)

-- -------------------------------------------------------------- Sharing
ns.Hub:AddTab("sharing", "Sharing", function(p)
  UI:FormPage(p, {
    { "header", "Share with your guild or party (all off by default)" },
    { "note", "Only other Outrider users see these messages. Nothing leaves the game." },
    { "check", "Say hello to other Outrider users", function() return set("Comm").hello end,
      function(on) ns.Slash:Run("share hello " .. onoff(on)) end },
    { "check", "Rares: guild", function() return set("RareShare").guild end, function(on) ns.Slash:Run("share rares guild " .. onoff(on)) end },
    { "check", "Rares: party", function() return set("RareShare").party end, function(on) ns.Slash:Run("share rares party " .. onoff(on)) end },
    { "check", "Herb and ore spots: guild", function() return set("GatherShare").guild end, function(on) ns.Slash:Run("share nodes " .. onoff(on)) end },
    { "check", "My location: party", function() return set("LocationShare").on end, function(on) ns.Slash:Run("share location " .. onoff(on)) end },
  })
end)

-- -------------------------------------------------------------- Settings
ns.Hub:AddTab("settings", "Settings", function(p)
  local A = function() return ns.Theme:Access() end
  local confirm = false
  UI:FormPage(p, {
    { "header", "Look" },
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
  head:SetText("Every Outrider command. Click one, add what it needs, then Run. Results show in chat.")
  p.list = UI:ScrollList(p, {
    rows = 14, rowHeight = 22,
    render = function(row, c) row.text:SetText(string.format("%s  |cffbbbbbb%s|r", c.name, c.usage)) end,
    onClick = function(c) p.current = c p.label:SetText(c.name) p.box:SetText("") p.box:SetFocus() end,
  })
  p.list:SetPoint("TOPLEFT", 0, -18)
  p.list:SetWidth(620)
  p.label = UI.Text(p, "large", "accent")
  p.label:SetPoint("TOPLEFT", p.list, "BOTTOMLEFT", 0, -10)
  p.label:SetText("pick a command")
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
      if c then out[#out + 1] = { name = name, usage = c.usage } end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    self.list:SetItems(out)
  end
end)

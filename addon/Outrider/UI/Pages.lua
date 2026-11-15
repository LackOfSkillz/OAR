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
if ns.PlayerClass and ns.PlayerClass() == "HUNTER" then NEAREST[#NEAREST + 1] = { "Ammo", "ammo" } end

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

-- Home in the Expedition look (2026-11-15): a welcome heading, the next step
-- from What now?, the Nearest buttons, and six cards in two columns that
-- stretch with the window.
local function homeCard(parent, title, height)
  local c = UI:Card(parent)
  c:SetHeight(height)
  c.title = UI.Display(c, "side", "text")
  c.title:SetPoint("TOPLEFT", 12, -9)
  c.title:SetText(title)
  c.rule = c:CreateTexture(nil, "ARTWORK")
  c.rule:SetHeight(1)
  c.rule:SetPoint("TOPLEFT", 12, -31)
  c.rule:SetPoint("TOPRIGHT", -12, -31)
  c.rule:SetColorTexture(Theme:Color("border"))
  c.body = UI.Text(c, "normal", "body")
  c.body:SetPoint("TOPLEFT", 12, -38)
  c.body:SetPoint("BOTTOMRIGHT", -12, 8)
  c.body:SetJustifyH("LEFT")
  c.body:SetJustifyV("TOP")
  return c
end

ns.Hub:AddTab("home", "Home", function(p)
  if ns.Art:Has("header") then
    p.scene = p:CreateTexture(nil, "BACKGROUND")
    p.scene:SetPoint("TOPLEFT", 0, 0)
    p.scene:SetPoint("RIGHT", p, "RIGHT", 0, 0)
    p.scene:SetHeight(48)
    ns.Art:Set(p.scene, "header")
    if p.scene.SetAlpha then p.scene:SetAlpha(0.55) end
  end
  p.heading = UI.Display(p, "page", "text")
  p.heading:SetPoint("TOPLEFT", 0, 0)
  p.sub = UI.Text(p, "normal", "muted")
  p.sub:SetPoint("TOPLEFT", p.heading, "BOTTOMLEFT", 0, -4)
  -- the next step, straight from What now?
  p.next = UI:Card(p, true)
  if p.next.SetBackdropBorderColor then p.next:SetBackdropBorderColor(Theme:Color("gold")) end
  p.next:SetHeight(76)
  p.next:SetPoint("TOPLEFT", 0, -54)
  p.next:SetPoint("RIGHT", p, "RIGHT", 0, 0)
  p.next.pic = p.next:CreateTexture(nil, "ARTWORK")
  p.next.pic:SetSize(52, 52)
  p.next.pic:SetPoint("LEFT", 12, 0)
  p.next.label = UI.Text(p.next, "small", "goldText")
  p.next.label:SetPoint("TOPLEFT", 76, -10)
  p.next.label:SetText("NEXT STEP")
  p.next.title = UI.Display(p.next, "card", "text")
  p.next.title:SetPoint("TOPLEFT", 76, -24)
  p.next.why = UI.Text(p.next, "normal", "body")
  p.next.why:SetPoint("TOPLEFT", 76, -48)
  p.next.why:SetPoint("RIGHT", p.next, "RIGHT", -150, 0)
  if p.next.why.SetWordWrap then p.next.why:SetWordWrap(false) end
  p.next.go = UI:PrimaryButton(p.next, "Go  >", 120, function() if p.step and ns.WhatNow then ns.WhatNow:Go(p.step) end end)
  p.next.go:SetHeight(26)
  p.next.go:SetPoint("TOPRIGHT", -12, -12)
  p.next.all = UI:Button(p.next, "All steps", 120, function() ns.Hub:ShowTab("whatnow") end)
  p.next.all:SetHeight(20)
  p.next.all:SetPoint("TOP", p.next.go, "BOTTOM", 0, -6)
  -- nearest
  p.near = homeCard(p, "Nearest", 92)
  p.near:SetPoint("TOPLEFT", p.next, "BOTTOMLEFT", 0, -8)
  p.near:SetPoint("RIGHT", p, "RIGHT", 0, 0)
  local prev
  local perRow = 7
  for i, n in ipairs(NEAREST) do
    local b = UI:Button(p.near, n[1], 92, function()
      local _, msg = ns.Nearest:Go(ns.Nearest.ALIASES[n[2]] or n[2]) -- "inn" means innkeeper, and so on
      ns.Print(tostring(msg))
    end)
    b:SetHeight(20)
    if i == 1 then b:SetPoint("TOPLEFT", 12, -40)
    elseif (i - 1) % perRow == 0 then b:SetPoint("TOPLEFT", 12, -64)
    else b:SetPoint("LEFT", prev, "RIGHT", 6, 0) end
    prev = b
  end
  p.near.body:Hide()
  -- two columns
  local function pair(leftCard, rightCard, above)
    leftCard:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -8)
    leftCard:SetPoint("RIGHT", p, "TOP", -4, 0)
    rightCard:SetPoint("TOPLEFT", leftCard, "TOPRIGHT", 8, 0)
    rightCard:SetPoint("RIGHT", p, "RIGHT", 0, 0)
  end
  p.journey = homeCard(p, "Where you're headed", 92)
  p.quests = homeCard(p, "Best quests for you", 92)
  pair(p.journey, p.quests, p.near)
  p.stop = UI:Button(p.journey, "Stop", 60, function() ns.Journey:Stop("home") p:Refresh() end)
  p.stop:SetPoint("TOPRIGHT", -10, -8)
  p.stop:SetHeight(20)
  p.gear = homeCard(p, "Upgrades in this zone", 112)
  p.rares = homeCard(p, "Rare watch", 112)
  pair(p.gear, p.rares, p.journey)
  p.errands = homeCard(p, "To do in town", 104)
  p.pet = homeCard(p, "Pet", 104)
  pair(p.errands, p.pet, p.gear)
  p.more = UI.Text(p, "small", "muted")
  p.more:SetPoint("TOPLEFT", p.errands, "BOTTOMLEFT", 0, -8)
  p.more:SetText("Search anything with the box at the top. Every page is in the sidebar; Outrider > All commands lists the rest.")
  function p:Refresh()
    local name = tostring(ns.db.key):match("^[^-]+") or "?"
    self.heading:SetText("Welcome back, " .. name)
    local mapID = C.PlayerPosition("player")
    self.sub:SetText(string.format("Level %s %s%s", tostring(C.Call("UnitLevel", "player") or "?"),
      tostring(C.Call("UnitClass", "player") or ""), mapID and ns.Travel and ("   " .. ns.Travel.ZoneName(mapID)) or ""))
    local step = ns.WhatNow and ns.WhatNow.enabled and ns.WhatNow:List()[1]
    self.step = step
    if step then
      ns.Art:SetKind(self.next.pic, step.kind)
      self.next.title:SetText(step.title or "")
      self.next.why:SetText(step.why or "")
      self.next.go:Show()
    else
      ns.Art:SetKind(self.next.pic, "quest")
      self.next.title:SetText("Nothing stands out right now")
      self.next.why:SetText("Open What now? to pick a goal.")
      self.next.go:Hide()
    end
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
    local timers = {}
    for npcID in pairs(ns.db.global.rareTimers or {}) do timers[#timers + 1] = ns.RareTimer and ns.RareTimer:Line(npcID) end
    self.rares.body:SetText((#lines > 0 and ("Watching: " .. table.concat(lines, ", ")) or "Not watching any rare. Add one in Rare alerts.")
      .. (#timers > 0 and ("\n" .. table.concat(timers, "\n")) or ""))
    lines = {}
    for _, e in ipairs(ns.Errands and ns.Errands:List() or {}) do lines[#lines + 1] = e.text end
    self.errands.body:SetText(#lines > 0 and table.concat(lines, "\n") or "Nothing to do in town.")
    local pet = mod("PetStatus")
    if pet and pet.enabled then
      self.pet.title:SetText("Pet")
      self.pet.body:SetText(pet:Activity())
    else
      local HF = ns.HunterFight
      self.pet.title:SetText("Your class keys")
      self.pet.body:SetText(HF and HF.enabled and HF:Supported() and HF:Activity()
        or "Your class page has your class macros.")
    end
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
    { "buttons", { { "Ammo vendor", Run("near ammo") } } },
    { "check", "Arrow to the spirit healer when you die", function() return set("Nearest").spiritOnDeath end,
      function(on) set("Nearest").spiritOnDeath = on end },
    { "header", "Map and minimap pins" },
    { "slider", "Places on the minimap", 0, 30, 1, function() return set("MinimapPins").max or 12 end,
      function(v) ns.Slash:Run("minipins " .. v) end, "%d" },
    { "check", "Quest givers on the minimap", function() return set("MinimapPins").quests end,
      function(on) ns.Slash:Run("minipins quests " .. onoff(on)) end },
    { "check", "Grey quests (no XP) on the map", function() return set("NPCPack").grey end,
      function(on) ns.Slash:Run("questpins grey " .. onoff(on)) end },
    { "check", "Herb and ore spots from the database", function() return set("NodePack").show end,
      function(on) ns.NodePack:SetShown(on) end, "off: only nodes you gathered" },
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
    { "header", "Timers" },
    { "note", function() return ns.RareTimer and ns.RareTimer:Activity() or "" end, 36 },
    { "header", "How you're told" },
    { "check", "Sound", function() return set("RareAlerts").sound end, function(on) set("RareAlerts").sound = on end },
    { "check", "Pop-up", function() return set("RareAlerts").toast end, function(on) set("RareAlerts").toast = on end },
    { "check", "Only rares on your watch list", function() return set("RareAlerts").mode == "watch" end,
      function(on) set("RareAlerts").mode = on and "watch" or "all" end },
    { "header", "Recently met" },
    { "buttons", { { "Last 10 NPCs met", Run("discovered 10") }, { "Rares tab", function() ns.Hub.frame.tabBar:Select("rares") end } } },
  })
end)

-- ------------------------------------------------------------ Class page
-- One page named after the character's class (Gary, 2026-11-13: "class aware,
-- dynamic, relevant to the character being played"). A hunter sees hunter
-- tools only, a mage mage tools only. Sections appear when the class has them.
local CLASS_ICON = "Interface\\Icons\\ClassIcon_"
local CLASS_NAME = { WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
  SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid" }
local KEY_NOTE = {
  HUNTER = "Fight (ranged), Strike (melee) and Pet (care) follow your spellbook and ranged weapon.",
  MAGE = "Fight (Frostbolt) and Strike (close: Frost Nova, Fire Blast, Arcane Explosion) follow your spellbook.",
  PRIEST = "Fight (Shadow Word: Pain once, Mind Blast, Smite) and Heal follow your spellbook.",
}

local function classRows(cls)
  local rows = {}
  local function r(t) rows[#rows + 1] = t end
  local F = function() return set("HunterFight") end
  local function opt(key) return function(on) ns.Slash:Run("fight " .. key .. " " .. onoff(on)) end end
  local fight = ns.HunterFight and ns.HunterFight:Supported()
  if fight then
    r({ "header", "Fight macros" })
    r({ "note", KEY_NOTE[cls] or "" })
    r({ "buttons", { { "Make or show the macros", Run("fight") }, { "Open macro window", function()
      if C.Call("ShowMacroFrame") == nil then C.Call("MacroFrame_LoadUI") C.Call("ShowMacroFrame") end end } } })
    if cls == "HUNTER" then
      r({ "check", "Concussive Shot in Fight", function() return F().concussive end, opt("concussive") })
      r({ "check", "Wing Clip in Strike", function() return F().wingclip end, opt("wingclip") })
      r({ "check", "Send the pet in", function() return F().pet end, opt("pet") })
    end
    r({ "check", "Rewrite when you learn a spell", function() return F().auto end, opt("auto") })
  end
  if cls == "HUNTER" then
    r({ "header", "Taming" })
    r({ "input", "Tame macro for", "Mystmane", "Make macro", function(t) ns.Slash:Run("tamemacro " .. t) end })
    r({ "note", "Press: send the pet in. Shift-press: dismiss it. Press again: Tame Beast." })
    r({ "header", "Pet and ammo" })
    r({ "check", "Show the pet panel", function() return set("PetStatus").show end,
      function(on) if ns.PetStatus then ns.PetStatus:SetPanel(on) end end })
    r({ "note", function() local m = mod("PetStatus") return m and m.enabled and m:Activity() or "" end })
    r({ "note", function() local m = mod("Ammo") return m and m.enabled and m:Activity() or "" end })
  end
  r({ "header", "Your class macros" })
  r({ "note", "Ready-made macros for your class only, in the Macros page: click one to see what it does, then Install." })
  r({ "buttons", { { "Open Macros", function() ns.Hub.frame.tabBar:Select("macros") end } } })
  if not fight then
    r({ "note", "Fight macros that follow your spellbook exist for hunters, mages and priests so far." })
  end
  return rows
end

do
  local cls = ns.PlayerClass and ns.PlayerClass() or nil
  ns.Hub:AddTab("class", CLASS_NAME[cls or ""] or "Class", function(p)
    UI:FormPage(p, classRows(ns.PlayerClass()))
  end, nil, { icon = cls and (CLASS_ICON .. (CLASS_NAME[cls] or "")) or nil })
end

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
-- Only the professions this character has (sections appear as you learn them;
-- the page is rebuilt at the next login).
local function profRows()
  local owned = ns.Crafter and ns.Crafter:Owned() or {}
  local function make(prof) return function() if ns.Crafter then ns.Crafter:Make(prof) end end end
  local rows = {}
  local function r(t) rows[#rows + 1] = t end
  local crafts = {}
  if owned.Cooking then crafts[#crafts + 1] = { "Cook", make("Cooking") } end
  if owned.Alchemy then crafts[#crafts + 1] = { "Brew", make("Alchemy") } end
  if #crafts > 0 then
    r({ "header", "Make what you can" })
    r({ "note", "Each click makes the best skill-up recipe you have every ingredient for (Create All). Stand by a fire to cook." })
    crafts[#crafts + 1] = { "Make bar macros", Run("make") }
    r({ "buttons", crafts })
  end
  -- One-button training for every crafting profession this character has.
  local T = ns.ProfTrainer
  local crafting = T and T.Professions and T:Professions() or {}
  if #crafting > 0 then
    r({ "header", "Training button" })
    r({ "note", "When your bags hold enough to gain +10 in a profession, a button pops up: each press makes the next recipe that still gives skill (cooking builds a fire first)." })
    r({ "check", "Show the training button", function() return set("ProfTrainer").show end,
      function(on) set("ProfTrainer").show = on if T then T:Evaluate() end end })
    r({ "key", "Training key", function() return set("ProfTrainer").key end,
      function(k) if T then T:SetKey(k) end end, "presses the button while it shows" })
    for _, prof in ipairs(crafting) do
      r({ "check", "Offer " .. prof, function() return not (set("ProfTrainer").off or {})[prof] end,
        function(on)
          local s = set("ProfTrainer")
          s.off = s.off or {}
          s.off[prof] = (not on) or nil
          if T then T:Evaluate() end
        end })
    end
    r({ "note", function() local m = mod("ProfTrainer") return m and m.enabled and m:Activity() or "" end, 36 })
  end
  if next(owned) then
    r({ "header", "Skill-up planner" })
    r({ "input", "Profession and target", "Alchemy 75", "Plan", function(t) ns.Slash:Run("skillup " .. t) end, true })
  end
  if owned.Herbalism or owned.Mining then
    r({ "header", "Herb and ore map" })
    r({ "check", "Herb and ore spots from the database", function() return set("NodePack").show end,
      function(on) ns.NodePack:SetShown(on) end, "off: only nodes you gathered" })
  end
  if owned.Herbalism then
    r({ "header", "Herbalism" })
    r({ "buttons", { { "Where each herb grows", Run("herbs") } } })
    r({ "note", function() local m = mod("HerbHelper") return m and m.enabled and m:Activity() or "" end })
  end
  if owned.Fishing then
    r({ "header", "Fishing" })
    r({ "key", "Fishing key", function() return set("Fishing").key end,
      function(k) ns.Slash:Run("fishkey " .. (k or "off")) end, "only while a pole is equipped" })
    r({ "note", "Press 1 casts (or puts a lure on when yours has run out), press 2 hooks and loots. Click the box, then press the key you want; right-click clears it." })
    r({ "check", "Fishing HUD while a pole is equipped", function() return set("FishingHUD").show end,
      function(on) set("FishingHUD").show = on if ns.FishingHUD then ns.FishingHUD:Update() end end, "skill, lure, what bites here, gold, goal" })
    r({ "check", "Sound for rare catches", function() return set("FishingHUD").rareSound end,
      function(on) set("FishingHUD").rareSound = on end })
  end
  if not next(owned) then
    r({ "header", "Professions" })
    r({ "note", "No professions yet. Visit a trainer; their tools appear here once you've learned one." })
  end
  r({ "header", "Auction house" })
  r({ "input", "Undercut by", "2% or 50c", "Set", function(t) ns.Slash:Run("undercut " .. t) end })
  r({ "note", function() local s = set("AuctionHelper") return "Now: " .. (s.undercutCopper and (s.undercutCopper .. " copper") or ((s.undercutPct or 2) .. "%")) end })
  return rows
end

ns.Hub:AddTab("professions", "Professions", function(p)
  UI:FormPage(p, profRows())
end)

-- ----------------------------------------------------------------- Money
-- Best ways to earn at this level and with these professions (MoneyGuide).
local function moneyRows()
  local G = ns.MoneyGuide
  local rows = {}
  local function r(t) rows[#rows + 1] = t end
  if not (G and G.enabled) then
    r({ "header", "Money" })
    r({ "note", "The Money guide module is off (Modules page)." })
    return rows
  end
  local level = ns.Compat.Call("UnitLevel", "player") or 1
  r({ "header", "Best ways to earn at level " .. level })
  r({ "note", "Ranked for your level and professions. Guide numbers are early Forever reports (unverified); after 15 minutes of a kind of earning your own gold per hour replaces them." })
  local ranked = G:Rank(level)
  for i = 1, math.min(#ranked, 8) do
    local x = ranked[i]
    local e = x.entry
    r({ "note", function()
      local now = G:Rank(level)
      for _, y in ipairs(now) do if y.entry.id == e.id then x = y end end
      return string.format("|cffffd100%d. %s|r  %s\n%s  (%s)", i, e.title, G.RateText(x), e.how or "", e.source)
    end, 46 })
    local zones = e.zones or {}
    if #zones > 0 then
      local btns = {}
      for z = 1, math.min(#zones, 3) do
        btns[#btns + 1] = { "Find " .. zones[z], function() ns.Hub:Search(zones[z]) end }
      end
      r({ "buttons", btns })
    end
  end
  if #ranked == 0 then r({ "note", "No tips for this level yet." }) end
  r({ "header", "Your own earnings" })
  r({ "note", function()
    local lines = G:YourLines()
    return #lines > 0 and table.concat(lines, "\n") or "Nothing yet: loot, gather, skin or fish and Outrider adds up what it's worth."
  end, 80 })
  r({ "note", "Prices: auction price less 5% when Outrider has seen one (open the auction house now and then), else the vendor price." })
  return rows
end

ns.Hub:AddTab("money", "Money", function(p)
  UI:FormPage(p, moneyRows())
end)

-- ------------------------------------------------------------- Dungeons
-- Ready now, best upgrades per dungeon, and the next tier (DungeonGuide).
local function dungeonRows()
  local D = ns.DungeonGuide
  local rows = {}
  local function r(t) rows[#rows + 1] = t end
  if not (D and D.enabled) then
    r({ "header", "Dungeons" })
    r({ "note", "The dungeon guide module is off (Modules page)." })
    return rows
  end
  if not D:Pack() then
    r({ "header", "Dungeons" })
    r({ "note", "The dungeon data pack (Outrider_Data_Dungeons) isn't installed." })
    return rows
  end
  D:Warm()
  local level = ns.Compat.Call("UnitLevel", "player") or 1
  local rank = D:Rank()
  local function find(name) for _, x in ipairs(D:Rank()) do if x.name == name then return x end end end
  local nxt = D:NextTier(rank)
  r({ "header", "Dungeons" })
  r({ "header", "Ready check" })
  r({ "note", function() return D.ReadyText(D:ReadyCheck()) end, 100 })
  r({ "header", "Next tier" })
  r({ "note", function()
    local n = D:NextTier()
    if not n then return "No upcoming dungeon with gear for you in the next few levels." end
    return string.format("|cffffd100%s|r (levels %d-%d): %d upgrades waiting once you're a little higher.\n%s",
      n.name, n.info.min, n.info.max, n.laterCount, D.UpgradeLine(n.ups, 4, true))
  end, 44 })
  if nxt then r({ "buttons", { { "Go to " .. nxt.name, function() D:Go(nxt) end, 260 } } }) end
  r({ "header", "Ready now (level " .. level .. ")" })
  local ready = 0
  for _, x in ipairs(rank) do
    if x.status == "ready" then
      ready = ready + 1
      local name = x.name
      r({ "note", function()
        local y = find(name) or x
        local kind = y.info.raid and (y.info.size .. "-player raid") or "5-player"
        local head = string.format("|cffffd100%s|r  levels %d-%d, %s%s", y.name, y.info.min, y.info.max, kind, y.info.new and ", new on Forever" or "")
        if y.count == 0 then return head .. "\nNothing here beats what you wear." end
        return string.format("%s\n%d upgrades: %s", head, y.count, D.UpgradeLine(y.ups, 3, false))
      end, 44 })
      r({ "buttons", { { "Go to the entrance", function() D:Go(x) end, 160 } } })
    end
  end
  if ready == 0 then r({ "note", "No dungeon in your level range yet." }) end
  local soon = {}
  for _, x in ipairs(rank) do if x.status == "soon" then soon[#soon + 1] = x end end
  if #soon > 0 then
    r({ "header", "Coming up" })
    r({ "note", function()
      local lines = {}
      for _, x in ipairs(D:Rank()) do
        if x.status == "soon" then
          lines[#lines + 1] = string.format("%s (%d-%d): %d upgrades later", x.name, x.info.min, x.info.max, x.laterCount)
        end
      end
      return table.concat(lines, "\n")
    end, 18 * #soon + 4 })
  end
  r({ "note", "Upgrades are scored for your class against what you wear; level ranges from foreverdb.net, loot from QuestieDB (both unverified)." })
  return rows
end

ns.Hub:AddTab("dungeons", "Dungeons", function(p)
  UI:FormPage(p, dungeonRows())
end)

-- ------------------------------------------------------------- What now?
-- Pathfinder Lite in the Expedition look (Gary's concept picture, 2026-11-15):
-- page title in the display font, goal chips with icons, step cards with a
-- picture, Go / Details / Not useful, and a side column with errands, rare
-- watch, this session and a character snapshot. Pictures come from ns.Art
-- (Gary's custom art when installed, game icons until then). No made-up
-- numbers: confidence shows as Unchecked / Guess, never as a percentage.
local CARD_H, CARD_GAP, SIDE_W, TOP, PIC, BTN_W = 116, 8, 224, 104, 76, 124
local GOAL_ICON = {
  level = "Interface\\Icons\\INV_Misc_Book_09", gold = "Interface\\Icons\\INV_Misc_Coin_02",
  gear = "Interface\\Icons\\INV_Shield_06", professions = "Interface\\Icons\\Trade_BlackSmithing",
  explore = "Interface\\Icons\\INV_Misc_Map_01", mix = "Interface\\Icons\\Spell_Holy_HolyBolt",
}

local function wrap(fs, lines)
  if fs.SetWordWrap then fs:SetWordWrap(lines > 1) end
  if fs.SetMaxLines then pcall(fs.SetMaxLines, fs, lines) end
  if fs.SetJustifyH then fs:SetJustifyH("LEFT") end
  if fs.SetJustifyV then fs:SetJustifyV("TOP") end
end

local function details(owner, s)
  local tip = rawget(_G, "GameTooltip")
  if not (tip and s) then return end
  tip:SetOwner(owner, "ANCHOR_LEFT")
  tip:AddLine(s.title or "", 1, 0.82, 0.3)
  if s.why then tip:AddLine(s.why, 0.85, 0.85, 0.85, true) end
  if s.where then tip:AddLine("Where: " .. s.where, 0.7, 0.7, 0.7, true) end
  if s.seconds and ns.Travel then tip:AddLine("Trip: about " .. ns.Travel.Minutes(s.seconds), 0.7, 0.7, 0.7) end
  if s.caveat then tip:AddLine(s.caveat, 1, 0.78, 0.3, true) end
  if s.alt then tip:AddLine("Or: " .. tostring(s.alt.text), 0.7, 0.7, 0.7, true) end
  tip:AddLine(string.format("Score %.2f (benefit %.2f, data %s)", s.score or 0, s.benefit or 0,
    (s.confidence or 1) >= 0.7 and "fairly sure" or "unchecked"), 0.5, 0.5, 0.5)
  tip:Show()
end

local function stepCard(parent, i, W, p)
  local c = UI:Card(parent, i == 1)
  c:SetHeight(CARD_H)
  if i == 1 and c.SetBackdropBorderColor then c:SetBackdropBorderColor(Theme:Color("gold")) end
  -- picture with a thin gold-grey frame
  c.frame = CreateFrame("Frame", nil, c, Theme:BackdropTemplate())
  c.frame:SetSize(PIC + 4, PIC + 4)
  c.frame:SetPoint("LEFT", 12, 0)
  Theme:ApplyPanel(c.frame, "bg", "strong")
  c.pic = c.frame:CreateTexture(nil, "ARTWORK")
  c.pic:SetPoint("TOPLEFT", 2, -2)
  c.pic:SetPoint("BOTTOMRIGHT", -2, 2)
  local left = PIC + 28
  c.title = UI.Display(c, "card", "text")
  c.title:SetPoint("TOPLEFT", left, -12)
  wrap(c.title, 1)
  c.tag = UI:Tag(c, "Unchecked", "plain")
  c.tag:SetPoint("LEFT", c.title, "RIGHT", 10, 0)
  c.why = UI.Text(c, "normal", "body")
  c.why:SetPoint("TOPLEFT", left, -38)
  c.why:SetPoint("RIGHT", c, "RIGHT", -(BTN_W + 24), 0)
  c.why:SetHeight(30)
  wrap(c.why, 2)
  c.where = UI.Text(c, "small", "muted")
  c.where:SetPoint("TOPLEFT", left, -72)
  c.where:SetPoint("RIGHT", c, "RIGHT", -(BTN_W + 24), 0)
  wrap(c.where, 1)
  c.alt = CreateFrame("Button", nil, c)
  c.alt:SetHeight(16)
  c.alt:SetPoint("TOPLEFT", left, -90)
  c.alt:SetPoint("RIGHT", c, "RIGHT", -(BTN_W + 24), 0)
  c.alt.label = UI.Text(c.alt, "small", "muted")
  c.alt.label:SetAllPoints()
  wrap(c.alt.label, 1)
  c.alt:SetScript("OnClick", function()
    local s = c.step
    if s and s.alt and s.alt.go then
      W:Info("what now alternative: %s -> %s", tostring(s.key), tostring(s.alt.text))
      ns.Safe("whatnow:alt", s.alt.go)
    end
  end)
  c.alt:SetScript("OnEnter", function() if c.step and c.step.alt and c.step.alt.go then c.alt.label:SetTextColor(Theme:Color("goldText")) end end)
  c.alt:SetScript("OnLeave", function() c.alt.label:SetTextColor(Theme:Color("muted")) end)
  -- the action column
  c.go = UI:PrimaryButton(c, "Go  >", BTN_W, function() local s = c.step if s then W:Go(s) end end)
  c.go:SetHeight(26)
  c.go:SetPoint("TOPRIGHT", -12, -14)
  c.more = UI:Button(c, "Details", BTN_W, function(self) details(self, c.step) end)
  c.more:SetHeight(20)
  c.more:SetPoint("TOP", c.go, "BOTTOM", 0, -6)
  c.more:HookScript("OnEnter", function(self) details(self, c.step) end)
  c.more:HookScript("OnLeave", function() local tip = rawget(_G, "GameTooltip") if tip then tip:Hide() end end)
  c.skip = UI:Button(c, "x  Not useful", BTN_W, function() local s = c.step if s then W:Skip(s) p:Refresh() end end)
  c.skip:SetHeight(20)
  c.skip:SetPoint("TOP", c.more, "BOTTOM", 0, -6)
  function c:Fill(s)
    self.step = s
    ns.Art:SetKind(self.pic, s.kind)
    self.title:SetText(s.title or "")
    if i == 1 then
      self.tag:SetStyle("gold") self.tag:SetLabel("Recommended") self.tag:Show()
    elseif (s.confidence or 1) < 0.7 then
      self.tag:SetStyle("plain") self.tag:SetLabel(s.kind == "rare" and "Guess" or "Unchecked") self.tag:Show()
    else
      self.tag:Hide()
    end
    self.why:SetText(s.why or "")
    local trip = s.seconds and ns.Travel and ("   ~" .. ns.Travel.Minutes(s.seconds)) or ""
    self.where:SetText((s.where and ("Where: " .. s.where) or "") .. trip
      .. (s.near and "   |cffd4a84asame area as step 1|r" or ""))
    self.alt.label:SetText(s.alt and ("Or: " .. tostring(s.alt.text)) or (s.caveat or ""))
    self.go:Show() self.more:Show() self.skip:Show()
  end
  function c:Empty()
    self.step = nil
    ns.Art:SetKind(self.pic, "quest")
    self.title:SetText("Nothing stands out right now")
    self.tag:Hide()
    self.why:SetText("Outrider learns more as you play: talk to NPCs, open your profession windows, visit the auction house.")
    self.where:SetText("")
    self.alt.label:SetText("")
    self.go:Hide() self.more:Hide() self.skip:Hide()
  end
  return c
end

-- side cards: a display-font heading, then label / value rows
local function sideCard(parent, title, rows, height)
  local c = UI:Card(parent)
  c:SetWidth(SIDE_W)
  c:SetHeight(height)
  c.head = UI.Display(c, "side", "text")
  c.head:SetPoint("TOPLEFT", 12, -10)
  c.head:SetText(title)
  c.rule = c:CreateTexture(nil, "ARTWORK")
  c.rule:SetHeight(1)
  c.rule:SetPoint("TOPLEFT", 12, -32)
  c.rule:SetPoint("TOPRIGHT", -12, -32)
  c.rule:SetColorTexture(Theme:Color("border"))
  c.rows = {}
  for r = 1, rows do
    local l = UI.Text(c, "normal", "body")
    l:SetPoint("TOPLEFT", 12, -40 - (r - 1) * 20)
    l:SetPoint("RIGHT", c, "RIGHT", -70, 0)
    wrap(l, 1)
    local v = UI.Text(c, "normal", "text")
    v:SetPoint("TOPRIGHT", -12, -40 - (r - 1) * 20)
    if v.SetJustifyH then v:SetJustifyH("RIGHT") end
    c.rows[r] = { l, v }
  end
  function c:Row(r, label, value)
    local row = self.rows[r]
    if not row then return end
    row[1]:SetText(label or "")
    row[2]:SetText(value or "")
  end
  return c
end

local function moneyText(c) return ns.Prices and ns.Prices.Money and ns.Prices.Money(c or 0) or tostring(c or 0) end

ns.Hub:AddTab("whatnow", "What now?", function(p)
  local W = ns.WhatNow
  if not W then UI:FormPage(p, { { "note", "What now? is switched off (Modules page)." } }) return end
  -- page title
  p.mark = p:CreateTexture(nil, "ARTWORK")
  p.mark:SetSize(36, 36)
  p.mark:SetPoint("TOPLEFT", 0, -2)
  ns.Art:Set(p.mark, "emblem")
  p.heading = UI.Display(p, "page", "text")
  p.heading:SetPoint("TOPLEFT", p.mark, "TOPRIGHT", 10, 2)
  p.heading:SetText("What now?")
  p.sub = UI.Text(p, "normal", "muted")
  p.sub:SetPoint("TOPLEFT", p.heading, "BOTTOMLEFT", 0, -4)
  -- the scene behind the title, once Gary's header art is in
  if ns.Art:Has("header") then
    p.scene = p:CreateTexture(nil, "BACKGROUND")
    p.scene:SetPoint("TOPLEFT", 0, 0)
    p.scene:SetPoint("RIGHT", p, "RIGHT", -(SIDE_W + 12), 0)
    p.scene:SetHeight(TOP - 46)
    ns.Art:Set(p.scene, "header")
    if p.scene.SetAlpha then p.scene:SetAlpha(0.55) end
  end
  -- goal chips
  p.chips = {}
  local prev
  for _, g in ipairs(W.GOALS) do
    local chip = UI:Chip(p, g.label, function() W:SetGoal(g.id) p:Refresh() end, GOAL_ICON[g.id])
    chip.goal = g.id
    if prev then chip:SetPoint("LEFT", prev, "RIGHT", 6, 0) else chip:SetPoint("TOPLEFT", 0, -(TOP - 36)) end
    p.chips[#p.chips + 1] = chip
    prev = chip
  end
  -- step cards
  p.cards = {}
  for i = 1, W.MAX do
    local c = stepCard(p, i, W, p)
    c:SetPoint("TOPLEFT", 0, -TOP - (i - 1) * (CARD_H + CARD_GAP))
    c:SetPoint("RIGHT", p, "RIGHT", -(SIDE_W + 12), 0)
    p.cards[i] = c
  end
  p.more = UI.Text(p, "small", "muted")
  -- side column
  p.errands = sideCard(p, "Errands", 3, 104)
  p.errands:SetPoint("TOPRIGHT", 0, 0)
  p.rare = sideCard(p, "Rare watch", 2, 84)
  p.rare:SetPoint("TOPRIGHT", p.errands, "BOTTOMRIGHT", 0, -8)
  p.session = sideCard(p, "This session", 3, 104)
  p.session:SetPoint("TOPRIGHT", p.rare, "BOTTOMRIGHT", 0, -8)
  p.snap = sideCard(p, "Character", 3, 176)
  p.snap:SetPoint("TOPRIGHT", p.session, "BOTTOMRIGHT", 0, -8)
  p.portrait = UI:Portrait(p.snap, 40)
  p.portrait:SetPoint("TOPLEFT", 14, -42)
  p.who = UI.Display(p.snap, "side", "text")
  p.who:SetPoint("TOPLEFT", p.portrait, "TOPRIGHT", 10, -2)
  p.where = UI.Text(p.snap, "small", "muted")
  p.where:SetPoint("TOPLEFT", p.who, "BOTTOMLEFT", 0, -3)
  -- the snapshot's rows sit under the portrait
  for r, row in ipairs(p.snap.rows) do
    row[1]:ClearAllPoints() row[2]:ClearAllPoints()
    row[1]:SetPoint("TOPLEFT", 12, -96 - (r - 1) * 22)
    row[2]:SetPoint("TOPRIGHT", -12, -96 - (r - 1) * 22)
  end
  p.xpbg = p.snap:CreateTexture(nil, "ARTWORK")
  p.xpbg:SetHeight(6)
  p.xpbg:SetPoint("TOPLEFT", 12, -114)
  p.xpbg:SetPoint("TOPRIGHT", -12, -114)
  p.xpbg:SetColorTexture(Theme:Color("border"))
  p.xpfill = p.snap:CreateTexture(nil, "OVERLAY")
  p.xpfill:SetHeight(6)
  p.xpfill:SetPoint("TOPLEFT", p.xpbg, "TOPLEFT", 0, 0)
  p.xpfill:SetColorTexture(0.55, 0.36, 0.95, 1)
  -- move row 2 and 3 below the bar
  for r = 2, 3 do
    local row = p.snap.rows[r]
    row[1]:ClearAllPoints() row[2]:ClearAllPoints()
    row[1]:SetPoint("TOPLEFT", 12, -128 - (r - 2) * 22)
    row[2]:SetPoint("TOPRIGHT", -12, -128 - (r - 2) * 22)
  end

  function p:Refresh()
    local key = tostring(ns.db.key)
    local name = key:match("^[^-]+") or "?"
    self.sub:SetText("Next steps for " .. name .. ", picked for your goal.")
    -- goal chips
    local goal = W:Goal()
    for _, chip in ipairs(self.chips) do chip:SetOn(chip.goal == goal) end
    -- steps: as many cards as the window has room for
    local list = W:List()
    local room = math.floor(((self:GetHeight() or 0) - TOP + CARD_GAP) / (CARD_H + CARD_GAP))
    if room < 1 then room = W.MAX end
    local shown = 0
    for i, c in ipairs(self.cards) do
      local s = list[i]
      if i <= room and (s or i == 1) then
        if s then c:Fill(s) else c:Empty() end
        c:Show()
        shown = i
      else
        c:Hide()
      end
    end
    local hidden = #list - math.min(#list, shown)
    self.more:ClearAllPoints()
    self.more:SetPoint("TOPLEFT", 0, -TOP - shown * (CARD_H + CARD_GAP))
    self.more:SetText(hidden > 0 and string.format("%d more step%s: make the window taller to see %s.", hidden,
      hidden == 1 and "" or "s", hidden == 1 and "it" or "them") or "")
    -- errands
    local errands = {}
    if ns.Errands then
      local ok, l = pcall(ns.Errands.List, ns.Errands)
      if ok and type(l) == "table" then errands = l end
    end
    for r = 1, 3 do
      local e = errands[r]
      self.errands:Row(r, e and e.text or (r == 1 and "Nothing to do in town" or ""), "")
    end
    -- rare watch
    local scan, S = ns.Modules:Get("RareScan"), ns.Sightings
    local rname, rstate = "Nothing watched", ""
    if scan and S then
      local npcs = ns.db.global.discovered and ns.db.global.discovered.npcs or {}
      for id in pairs(scan:Settings().watch or {}) do
        if type(id) == "number" then
          local ok, w = pcall(S.Window, S, id)
          local state = ok and type(w) == "table" and w.state or "unknown"
          rname = npcs[id] and npcs[id].name or ("rare " .. id)
          rstate = state == "unknown" and "no sightings yet" or ("window " .. tostring(state))
          if state == "open" or state == "alive" or state == "overdue" then break end
        end
      end
    end
    self.rare:Row(1, rname, "")
    self.rare:Row(2, rstate, "")
    -- this session
    local st = W:SessionStats()
    if st then
      self.session:Row(1, "XP gained", (st.levels > 0 and ("+" .. st.levels .. " lvl, ") or "") .. "+" .. st.xp)
      self.session:Row(2, "Gold", (st.money >= 0 and "+" or "-") .. moneyText(math.abs(st.money)))
      self.session:Row(3, "Time played", ns.Travel and ns.Travel.Minutes(st.seconds) or (math.floor(st.seconds / 60) .. " min"))
    else
      self.session:Row(1, "Starts at login", "")
    end
    -- character snapshot
    local cls = ns.PlayerClass and ns.PlayerClass() or ""
    local colors = rawget(_G, "RAID_CLASS_COLORS")
    local cc = colors and colors[cls]
    local r, g, b = 0.9, 0.9, 0.9
    if cc then r, g, b = cc.r, cc.g, cc.b end
    self.portrait:SetUnit("player")
    local level = C.Call("UnitLevel", "player") or "?"
    self.who:SetText(string.format("%s  |cff%02x%02x%02x%s|r", name, r * 255, g * 255, b * 255,
      tostring(C.Call("UnitClass", "player") or cls)))
    local mapID = C.PlayerPosition("player")
    self.where:SetText(string.format("Level %s%s", tostring(level),
      mapID and ns.Travel and ("   " .. ns.Travel.ZoneName(mapID)) or ""))
    local xp, max = C.Call("UnitXP", "player") or 0, C.Call("UnitXPMax", "player") or 0
    local pct = max > 0 and xp / max or 0
    self.snap:Row(1, "XP", max > 0 and string.format("%d / %d (%d%%)", xp, max, math.floor(pct * 100)) or "max level")
    local barW = SIDE_W - 24
    self.xpfill:SetWidth(math.max(1, barW * pct))
    self.snap:Row(2, "Gold", moneyText(C.Call("GetMoney") or 0))
    local il = W.ItemLevel()
    self.snap:Row(3, "Item level", il and tostring(il) or "?")
  end
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
    { "header", "Gear for alts, family and other Outrider users" },
    { "note", "When something in your bags is an upgrade for someone, Outrider says so: your alts first, then family and friends, then other Outrider users in your guild or party. At a mailbox it fills in their name." },
    { "check", "Share my gear card and see others' (guild and party)", function() return set("KitShare").share end,
      function(on) set("KitShare").share = on if on and ns.KitShare then ns.KitShare:Broadcast() end end, "off: your alts only" },
    { "input", "Add family or friend", "character name", "Add", function(t) if ns.KitShare then ns.KitShare:SetFamily(t, true) end end },
    { "input", "Remove family or friend", "character name", "Remove", function(t) if ns.KitShare then ns.KitShare:SetFamily(t, false) end end },
    { "note", function()
      local fam = set("KitShare").family or {}
      local m = mod("KitShare")
      return "Family and friends: " .. (#fam > 0 and table.concat(fam, ", ") or "none yet") .. "\n" .. (m and m.enabled and m:Activity() or "")
    end, 36 },
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

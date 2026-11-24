-- UI/Pages/Character.lua
-- Class page and gear sets. Split from UI/Pages.lua (OI01-08); page ids, titles and order unchanged.

local _, ns = ...
local UI, Theme = ns.UI, ns.Theme
local C = ns.Compat
local Run = UI.Run
local K = ns.PageKit
local mod, set, onoff = K.mod, K.set, K.onoff
local classTalentPoints = K.classTalentPoints

-- ------------------------------------------------------------ Class page
-- One page named after the character's class (requirement 2026-11-13: class aware,
-- dynamic, relevant to the character being played). A hunter sees hunter
-- tools only, a mage mage tools only. Sections appear when the class has them.
local CLASS_ICON = "Interface\\Icons\\ClassIcon_"
local CLASS_NAME = { WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
  SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid" }
local KEY_NOTE = {
  HUNTER = "Fight (ranged), Strike (melee) and Pet (care) follow your spellbook and ranged weapon.",
  MAGE = "Fight (Frostbolt) and Strike (close: Frost Nova, Fire Blast, Arcane Explosion) follow your spellbook.",
  PRIEST = "Fight (Shadow Word: Pain once, Mind Blast, Smite) and Heal follow your spellbook.",
  WARRIOR = "Fight on key 1 (Charge, Shout, Rend, big strike, Heroic Strike); Strike on key 2 (Overpower, Execute, Thunder Clap).",
  ROGUE = "Fight (Stealth, an opener from Stealth, Sinister Strike, Slice and Dice, Eviscerate), Pull (Throw or your bow) and Strike (Stealth, then Pick Pocket; Evasion and Kick in a fight).",
  WARLOCK = "Fight on key 1 (demon, curse, dots once, Drain Life or wand); Strike on key 2 (Life Tap, Shift: Fear).",
  DRUID = "Fight on key 1 follows your form (caster, Bear, Cat); Heal on key 2 (Swipe, Tiger's Fury or a heal).",
  PALADIN = "Fight on key 1 (Blessing, Aura, Seal and Judgement, Holy Strike); Heal on key 2 (Holy Light).",
  SHAMAN = "Fight on key 1 (imbue, Shield, bolt, totem, shocks, Stormstrike); Heal on key 2 (Healing Wave).",
}

-- Spells your class trainer teaches (Data/SpellInfo.lua, the client's
-- spellbook pages; talents left out): ready now (your level, not known yet)
-- and the next two levels that bring something new.
local function trainerSpells(cls)
  -- what your trainer showed you is the truth (bug 2026-11-21); the typed-in
  -- spell table is only a fallback until you've opened your trainer once
  if ns.Spellbook and ns.Spellbook.TrainerLists and (not cls or cls == (ns.PlayerClass and ns.PlayerClass())) then
    local now, soon, nextLevel, any = ns.Spellbook:TrainerLists()
    if any then return now, soon, nextLevel, "trainer" end
  end
  local info = ns.SpellInfo and ns.SpellInfo[cls or ""] or {}
  local level = tonumber(C.Readable(C.Call("UnitLevel", "player"))) or 1
  local now, later = {}, {}
  for name, sp in pairs(info) do
    if type(sp) == "table" and sp.level and not sp.tree then
      local known = ns.Spellbook and ns.Spellbook:Known(name)
      if sp.level <= level and not known then now[#now + 1] = { name = name, level = sp.level, icon = sp.icon }
      elseif sp.level > level then later[#later + 1] = { name = name, level = sp.level, icon = sp.icon } end
    end
  end
  local byName = function(a, b) if a.level ~= b.level then return a.level < b.level end return a.name < b.name end
  table.sort(now, byName)
  table.sort(later, byName)
  local soon, levels = {}, {}
  for _, sp in ipairs(later) do
    if not levels[sp.level] then levels[sp.level] = true levels[#levels + 1] = sp.level end
    if #levels <= 2 then soon[#soon + 1] = sp end
  end
  return now, soon, levels[1], "estimate"
end
ns.ClassPage = ns.ClassPage or {}
ns.ClassPage.TrainerSpells = trainerSpells

-- a spell icon: a file ID or full path (from the trainer) or an icon name (typed data)
local function iconPath(icon, fallback)
  if type(icon) == "number" then return icon end
  if type(icon) == "string" and (icon:find("\\", 1, true) or icon:find("/", 1, true)) then return icon end
  return "Interface\\Icons\\" .. tostring(icon or fallback or "INV_Misc_QuestionMark")
end

local function spellChips(list, max)
  local out = {}
  for i, sp in ipairs(list) do
    if i > (max or 6) then break end
    out[#out + 1] = { icon = "Interface\\Icons\\" .. tostring(sp.icon or "INV_Misc_QuestionMark"), text = sp.name .. "  |cff8f96a6" .. sp.level .. "|r",
      tip = sp.name .. " (level " .. sp.level .. ")" }
  end
  return out
end

local function classRows(cls, page)
  local rows = {}
  local function r(t) rows[#rows + 1] = t end
  local F = function() return set("HunterFight") end
  local function opt(key) return function(on) ns.Slash:Run("fight " .. key .. " " .. onoff(on)) end end
  local fight = ns.HunterFight and ns.HunterFight:Supported()
  -- at a glance: level, talent points, spells waiting at the trainer (requirement 2026-11-20)
  r({ "stats", function()
    local now, _, nextLevel = trainerSpells(cls)
    local level = tonumber(C.Readable(C.Call("UnitLevel", "player"))) or 1
    local pts = classTalentPoints()
    return {
      { cap = "Level", value = tostring(level), color = "text" },
      { cap = "Spells to learn now", value = tostring(#now), color = #now > 0 and "good" or "text",
        note = #now > 0 and "visit your class trainer" or "you're up to date" },
      { cap = "Next new spell", value = nextLevel and ("level " .. nextLevel) or "none", color = "gold" },
      { cap = "Talent points", value = level < 10 and "at 10" or tostring(pts), color = pts > 0 and "good" or "text",
        note = pts > 0 and "spend them in the talent window (N)" or nil },
    }
  end })
  -- what to do now, in order, in plain words (requirement 2026-11-23: the old text was not 8th-grade ready)
  r({ "header", "Do this now" })
  r({ "cards", function()
    local now = trainerSpells(cls)
    local level = tonumber(C.Readable(C.Call("UnitLevel", "player"))) or 1
    local pts = level >= 10 and classTalentPoints() or 0
    local out = {}
    local function step(t) t.title = string.format("%d. %s", #out + 1, t.title) out[#out + 1] = t end
    if #now > 0 then
      step({ title = string.format("Learn %d new spell%s", #now, #now == 1 and "" or "s"), highlight = true,
        pic = "Interface\\Icons\\INV_Misc_Book_09", line = "Go to your class trainer in a town and buy them.",
        actions = { { "Arrow to trainer", function() ns.Slash:Run("near class") end, "Points the gold arrow at your nearest class trainer." } } })
    end
    if pts > 0 then
      step({ title = string.format("Spend %d talent point%s", pts, pts == 1 and "" or "s"), highlight = #out == 0,
        pic = "Interface\\Icons\\Ability_Marksmanship", line = "The Talents page shows the best builds for you and where your next point goes.",
        actions = { { "Open Talents", function() ns.Hub:ShowTab("talentlab") end, "Opens the Talents page." } } })
    end
    if ns.HunterFight and ns.HunterFight:Supported() then
      step({ title = "Fight with your keys", pic = "Interface\\Icons\\Ability_DualWield",
        line = "Your Fight, Pull and Heal keys are on the Macros page: drag them to your action bar once. Outrider keeps them up to date.",
        actions = { { "Open Macros", function() ns.Hub.frame.tabBar:Select("macros") end, "Opens the Macros page." } } })
    end
    return out
  end })
  r({ "header", "Spells from your trainer" })
  r({ "cards", function()
    local now, soon, _, from = trainerSpells(cls)
    local out = {}
    if from ~= "trainer" then
      out[#out + 1] = { title = "Open your class trainer once", pic = "Interface\\Icons\\INV_Misc_Book_09", tags = { { "estimate", "warn" } },
        line = "Until you've talked to your trainer, this list is a guess. Talk to them once and Outrider shows exactly what they teach, with ranks.",
        actions = { { "Arrow to trainer", function() ns.Slash:Run("near class") end, "Points the gold arrow at the nearest class trainer." } } }
    end
    if #now > 0 then
      out[#out + 1] = { title = string.format("%d new spell%s ready to learn", #now, #now == 1 and "" or "s"), highlight = true,
        pic = "Interface\\Icons\\" .. tostring(now[1].icon or "INV_Misc_Book_09"),
        line = from == "trainer" and "From your trainer's own list: you can learn these now." or "Your class trainer should teach these now.",
        chips = spellChips(now, 6), tags = { { "ready now", "gold" } },
        actions = { { "Arrow to trainer", function() ns.Slash:Run("near class") end, "Points the gold arrow at your nearest class trainer." } } }
    else
      out[#out + 1] = { title = "You know every spell for your level", pic = "Interface\\Icons\\INV_Misc_Book_09",
        line = "Nothing to learn right now. Come back when you reach the level below." }
    end
    if #soon > 0 then
      out[#out + 1] = { title = "Coming next", pic = "Interface\\Icons\\" .. tostring(soon[1].icon or "INV_Misc_Book_09"),
        line = string.format("At level %d%s.", soon[1].level, soon[#soon].level ~= soon[1].level and (" and " .. soon[#soon].level) or ""),
        chips = spellChips(soon, 6) }
    end
    return out
  end })
  if fight then
    r({ "header", "Your fight keys" })
    r({ "note", "Put these on your action bar and press them in every fight: Outrider keeps them up to date. " .. (KEY_NOTE[cls] or "") })
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
    r({ "input", "Trap tame macro for", "Mystmane", "Make trap macro", function(t) ns.Slash:Run("tamemacro trap " .. t) end })
    r({ "note", "No pet out. Press: Freezing Trap. Press: Concussive Shot pulls her onto it. Then press to tame; if it breaks, press for Wing Clip, press to tame again. Shift: a new trap." })
    r({ "header", "Pet and ammo" })
    r({ "check", "Show the pet panel", function() return set("PetStatus").show end,
      function(on) if ns.PetStatus then ns.PetStatus:SetPanel(on) end end })
    r({ "note", function() local m = mod("PetStatus") return m and m.enabled and m:Activity() or "" end })
    r({ "note", function() local m = mod("Ammo") return m and m.enabled and m:Activity() or "" end })
  end
  -- click-to-heal bars (Modules/HealPanel.lua)
  local HP = ns.HealPanel
  if HP and HP.spec.classes[cls or ""] then
    r({ "header", "Heal bars" })
    r({ "note", function() return HP:Summary() end })
    r({ "check", "Show the heal bars in a group", function() return set("HealPanel").show ~= "off" end,
      function(on) ns.Slash:Run("heal " .. (on and "group" or "off")) end })
    if cls ~= "HUNTER" then
      r({ "check", "Keep my own bar when players are assigned", function() return set("HealPanel").withSelf end,
        function(on) ns.Slash:Run("heal self " .. onoff(on)) end })
      r({ "note", "Assigned to you: click a name (out of combat). With anyone assigned, only they get bars." })
      r({ "list", 3, function(row, name)
        row.text:SetText((HP:IsAssigned(name) and "|cffffd100[assigned]|r " or "[ ] ") .. name)
      end, function(name)
        HP:Assign(name, not HP:IsAssigned(name))
        if page and page.Refresh then page:Refresh() end
      end, function() return HP:Members() end, empty = "Join a group and the players show here." })
    end
  end
  -- talents: the Talents page has the builds (Modules/TalentLab.lua, 2026-11-23)
  r({ "header", "Talents" })
  r({ "note", function()
    local level = tonumber(C.Readable(C.Call("UnitLevel", "player"))) or 1
    if level < 10 then return "Your first talent point comes at level 10." end
    local pts = classTalentPoints()
    local T = ns.Talents
    local b = T and T:Build()
    local head = pts > 0 and string.format("You have %d talent point%s to spend.", pts, pts == 1 and "" or "s") or "No talent point to spend right now."
    if b and T then return head .. " " .. T:Summary() .. "\n|cff888888Following " .. tostring(b.name) .. " (not checked in game yet).|r" end
    return head .. " Pick a build on the Talents page and press Follow: the game's talent window then rings your next points."
  end })
  r({ "buttons", { { "Open Talents", function() ns.Hub:ShowTab("talentlab") end } } })
  r({ "check", "Gold rings in the talent window", function() return set("Talents").highlight end,
    function(on) ns.Slash:Run("talents " .. onoff(on)) end })
  r({ "header", "More keys for your class" })
  r({ "note", "The Macros page has every ready-made key for your class, by level: Stop, Save, Burst, Recover and Team, and one-spell keys. Drag them to your bar." })
  r({ "buttons", { { "Open Macros", function() ns.Hub.frame.tabBar:Select("macros") end } } })
  if not fight then
    r({ "note", "Fight macros that follow your spellbook exist for hunters, mages and priests so far." })
  end
  return rows
end

do
  local cls = ns.PlayerClass and ns.PlayerClass() or nil
  ns.Hub:AddTab("class", CLASS_NAME[cls or ""] or "Class", function(p)
    UI:FormPage(p, classRows(ns.PlayerClass(), p))
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
    { "list", 6, function(row, name) row.text:SetText(name) end, function(name) ns.Slash:Run("gear " .. name) end, sets,
      empty = "No gear sets saved yet. Type a name above and press Save." },
    { "input", "Delete set", "Questing", "Delete", function(t) ns.Slash:Run("gear delete " .. t) end },
    { "header", "How gear is scored" },
    { "buttons", { { "Show my stat weights", Run("weights") }, { "Upgrades in this zone", Run("nearby") } } },
    { "input", "Compare an item", "Shift-click an item here", "Compare", function(t) ns.Slash:Run("score " .. t) end },
  })
end)

-- ------------------------------------------------------------ Professions
-- Only the professions this character has (sections appear as you learn them;
-- the page is rebuilt at the next login).

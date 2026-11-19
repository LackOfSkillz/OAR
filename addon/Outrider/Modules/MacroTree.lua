-- Modules/MacroTree.lua  (Gary, 2026-11-19: "the macro page should be similar
-- to the talents layout ... macros pre-created ... in tiers of levels 1 to 10
-- ... icons people just drag onto their action bar ... and explanation. Our
-- macros are supposed to give even a new player ... that same level of skill.")
--
-- The Macros page as a skill tree:
--   * Your keys: the fight keys (Fight, Pull, Strike, Heal, Pet...) that
--     Outrider rewrites as you learn spells; set up once. Under them, what the
--     main key does press by press, from the fight plan's reasons.
--   * The tree: rows are level bands (1-10 ... 51-60), columns are "Every
--     <class>" and one per talent tree. Each cell holds the macros that unlock
--     there: the class macro library and the plan's extra keys (Burst, Break,
--     Recover, Trap...). Level and tree come from the macro itself or from the
--     spells in it (the fight plan's learn table: level and talent tree).
--   * Click an icon to read it (when to press, what it does, every line in
--     plain words); drag it to your action bar. Dragging writes the macro first
--     if it isn't in your macros yet (out of combat, from your drag: rule 1).
--   * A PvE / PvP switch shows the PvP versions; it changes only this view.
-- Nothing here casts anything: these are ordinary macros you press.

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local E = ns.MacroEngine
local T = ns:NewModule("MacroTree", {
  title = "Macros page: skill tree, tooltips, missing buffs",
  phase = "P4",
  order = 62,
  -- seen: macros you've looked at (no "new" badge); planned: the build you
  -- chose before 10 talent points; tooltips: Outrider's words under a macro
  -- on your action bar; buffs: the missing-buffs row
  defaults = { seen = {}, planned = nil, tooltips = true, buffs = true },
})
ns.MacroTree = T

-- ------------------------------------------------------------------ module
-- One chat line per session when macros unlock (rule 6); the page shows a
-- "new" badge on each until you open it.
function T:OnEnable()
  self:On("PLAYER_ENTERING_WORLD", function(mod, _, isLogin, isReload)
    if isLogin or isReload or not mod.baseline then mod.baseline = mod:UnlockedIds() end
  end)
  local function check(mod) ns.Throttle("macrotree:new", 3, function() mod:CheckNew() end) end
  self:On("PLAYER_LEVEL_UP", check)
  self:On("SPELLS_CHANGED", function(mod) mod.tipCache = nil check(mod) end)
  self:On("LEARNED_SPELL_IN_TAB", check)
  -- Outrider's words under one of its macros on your action bar (a hook: the
  -- game's tooltip stays as it is, two lines are added under it)
  if not self.tipHooked and GameTooltip and type(rawget(_G, "hooksecurefunc")) == "function" then
    self.tipHooked = true
    hooksecurefunc(GameTooltip, "SetAction", function(tt, slot)
      if T.enabled and T:Settings().tooltips and not C.IsAddOnLoaded("MacroKit") then ns.Safe("macrotree:tooltip", T.AddTooltip, T, tt, slot) end
    end)
  end
end

-- name -> { when, what } for every macro Outrider can write for you
function T:TipFor(name)
  if not self.tipCache then
    local c = {}
    for _, k in ipairs(self:Keys()) do
      c[k.name] = { when = T.KEY_WHEN[k.name] or "Press it in every fight.", what = k.entry.explain }
    end
    for _, it in ipairs(self:Items("pve")) do
      if not c[it.name] then
        local tag = it.tags and it.tags[1]
        c[it.name] = { when = T.WHEN[tag or ""], what = it.why }
      end
    end
    self.tipCache = c
  end
  return self.tipCache[name]
end

function T:AddTooltip(tt, slot)
  local kind, id = C.Call("GetActionInfo", slot)
  if kind ~= "macro" or not id then return end
  local name = C.Call("GetMacroInfo", id)
  local lib = ns.MacroLibrary
  if type(name) ~= "string" or not (lib and lib:Settings().installed[name]) then return end
  local t = self:TipFor(name)
  if not t then return end
  tt:AddLine(" ")
  if t.when then tt:AddLine("Outrider: " .. t.when, 0.95, 0.82, 0.45, true) end
  if t.what and t.what ~= "" then tt:AddLine(t.what, 0.8, 0.8, 0.8, true) end
  tt:Show()
end

function T:OnDisable() ns.ThrottleCancel("macrotree:new") end

-- ids of the tree's macros you can use now
function T:UnlockedIds()
  local lib = ns.MacroLibrary
  if lib and not lib.held then return lib:Hold(self.UnlockedIds, self) end
  local out = {}
  for _, it in ipairs(self:Items("pve")) do
    local st = self:State(it)
    if st ~= "locked" and not (type(st) == "string" and st:find("^needs")) then out[it.id] = it.name end
  end
  return out
end

-- newly usable and not yet looked at: { names }
function T:CheckNew()
  if not self.baseline then self.baseline = self:UnlockedIds() return {} end
  local now, fresh = self:UnlockedIds(), {}
  local seen = self:Settings().seen
  for id, name in pairs(now) do
    if not self.baseline[id] and not seen[id] then fresh[#fresh + 1] = name end
  end
  self.baseline = now
  table.sort(fresh)
  if #fresh > 0 then
    if not self.toldNew then
      self.toldNew = true
      ns.Print("new macros on your Macros page: %s (drag them to your bar)", table.concat(fresh, ", "))
    end
    self:Info("macros unlocked: %s", table.concat(fresh, ", "))
  end
  return fresh
end

function T:Activity()
  local n, new = 0, 0
  local seen = self:Settings().seen
  for id in pairs(self:UnlockedIds()) do n = n + 1 if not seen[id] then new = new + 1 end end
  return string.format("%d macros ready for you on the Macros page, %d not looked at yet", n, new)
end

T.BANDS = { { 1, 10 }, { 11, 20 }, { 21, 30 }, { 31, 40 }, { 41, 50 }, { 51, 60 } }
-- words that are tags, not talent trees (the rogue tree "combat" is also the "in a fight" tag)
T.GENERIC_TAGS = { combat = true, control = true, defensive = true, utility = true, heal = true, pet = true, rare = true,
  talent = true, cooldown = true }
-- a game icon per kind of macro, until the spell's own icon or Outrider's art (batch 6) is there
T.TAG_ICON = { combat = "INV_Sword_04", control = "Ability_Hunter_SniperShot", defensive = "INV_Chest_Plate06",
  utility = "INV_Misc_Bag_08", heal = "Spell_Holy_SurgeOfLight", pet = "Ability_Hunter_BeastTaming", rare = "Ability_Tracking",
  burst = "Spell_Holy_SurgeOfLight", ["break"] = "INV_Chest_Plate06", recover = "INV_Misc_PocketWatch_01",
  trap = "Ability_Tracking" }
-- when to press it, by what it's for (the explanation on every macro)
T.WHEN = {
  combat = "In the fight, whenever its spell is ready.",
  control = "When an enemy starts casting, runs away, or a second one joins the fight.",
  defensive = "When your health drops fast or the fight is going wrong.",
  utility = "Between fights, out of combat.",
  heal = "When you or a friend needs health.",
  pet = "To tell your pet what to do.",
  rare = "When a rare you're hunting is near.",
  burst = "At the start of a hard fight: a rare, an elite, a fight you might lose, or a duel.",
  ["break"] = "When you're stunned, feared, slowed or about to die.",
  recover = "Between fights, or while your target can't act.",
  trap = "Before the pull, or when a second enemy runs at you.",
}
T.KEY_WHEN = {
  Fight = "Over and over, from the moment you pick a target until it dies. This is the button you press most.",
  Pull = "Once, from range, to start a fight on your terms.",
  Strike = "The second key: press it when the moment comes (it says which below).",
  Heal = "When you or a friend needs health; point the mouse at a friend to heal them.",
  Pet = "Between fights or when your pet is hurt: it revives, calls or heals your pet.",
  Reach = "When the enemy is out of melee range.",
}

-- ------------------------------------------------------------------ model
function T.Plan() return ns.FightPlans and ns.FightPlans:Class(ns.PlayerClass()) or nil end
function T.Learn() local p = T.Plan() return p and p.learn or {} end
-- the class spellbook from the live client (Data/SpellInfo.lua): level, tree, icon
function T.Info(sp) local s = ns.SpellInfo and ns.SpellInfo[ns.PlayerClass() or ""] return s and s[sp] end
function T.Level() return tonumber(C.Readable(C.Call("UnitLevel", "player"))) or 1 end

function T.Band(level)
  level = tonumber(level) or 1
  for i, b in ipairs(T.BANDS) do if level <= b[2] then return i end end
  return #T.BANDS
end

-- Spell names a macro casts, in order, once each: "/cast [stealth] Ambush; Backstab" -> {Ambush, Backstab}
function T.SpellsIn(body)
  local out, seen = {}, {}
  local function add(name)
    name = (name or ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("^!", "")
    if name ~= "" and name ~= "null" and not name:match("^%d+$") and not seen[name] then seen[name] = true out[#out + 1] = name end
  end
  for line in (tostring(body or "") .. "\n"):gmatch("(.-)\n") do
    local cmd, rest = line:match("^/(%a+)%s+(.*)$")
    if cmd == "cast" or cmd == "use" then
      for clause in (rest .. ";"):gmatch("([^;]*);") do
        add((clause:gsub("%b[]", "")))
      end
    elseif cmd == "castsequence" then
      local list = rest:gsub("%b[]", ""):gsub("^%s*reset=%S+%s*", "")
      for sp in list:gmatch("[^,]+") do add(sp) end
    end
  end
  return out
end

-- The level a macro unlocks at: its own, else the highest learn level of its spells.
function T.LevelOf(spells, own)
  if tonumber(own) then return tonumber(own) end
  local learn, best = T.Learn(), 1
  for _, sp in ipairs(spells) do
    local e, info = learn[sp], T.Info(sp)
    -- the plan's level, else the trainer's, else 10 for a talent (points start at 10)
    local lv = e and e[1] or info and (info.level or (info.tree and 10)) or nil
    if lv and lv > best then best = lv end
  end
  return best
end

-- The talent tree a macro belongs to (a tree id from the plan), or nil for every build.
function T.TreeOf(spells, tags, own)
  local plan = T.Plan()
  local trees = plan and plan.trees or {}
  local isTree = {}
  for _, t in ipairs(trees) do isTree[t] = true end
  if own and isTree[own] then return own end
  local learn = T.Learn()
  for _, sp in ipairs(spells) do
    local e, info = learn[sp], T.Info(sp)
    if e and e[2] and isTree[e[2]] then return e[2] end
    if info and info.tree and isTree[info.tree] then return info.tree end
  end
  local map = ns.MacroLibrary and ns.MacroLibrary.SPEC_TAG or {}
  for _, tag in ipairs(tags or {}) do
    local t = map[tag] or tag
    if isTree[t] and not T.GENERIC_TAGS[tag] then return t end
  end
  return nil
end

local function utilityKinds()
  local set = {}
  local FP = ns.FightPlan
  if FP and FP.enabled then for _, u in ipairs(FP:Utility()) do set[u.kind] = true end end
  return set
end

-- Your keys: the fight keys (not the extra utility keys, which sit in the tree).
-- { {kind, entry, steps = { {text, why} }} }
function T:Keys()
  local F = ns.HunterFight
  if not (F and F.enabled and F:Supported()) then return {} end
  local util, out = utilityKinds(), {}
  for _, kind in ipairs(F:Kinds()) do
    if not util[kind] then
      local entry = F:Entry(kind)
      if entry and not entry.empty then
        local steps = {}
        for _, l in ipairs(F:Lines(kind)) do
          if not l.text:find("^/targetenemy") then steps[#steps + 1] = { text = l.text, why = l.why } end
        end
        entry.whys = {}
        for _, s in ipairs(steps) do if s.why and s.why ~= "" then entry.whys[s.text] = s.why end end
        out[#out + 1] = { kind = kind, entry = entry, steps = steps, name = entry.name }
      end
    end
  end
  return out
end

-- Every macro in the tree for this class: library macros and the plan's extra
-- keys, for PvE or PvP. { {id, name, body, level, tree, tags, why, entry, source} }
function T:Items(mode)
  local cls = ns.PlayerClass()
  local out = {}
  for _, e in ipairs(ns.Data and ns.Data:All("macro") or {}) do
    if e.class == cls then
      local spells = T.SpellsIn(e.body)
      for _, sp in ipairs(e.needsSpells or {}) do spells[#spells + 1] = sp end
      out[#out + 1] = { id = e.id, name = e.name, body = e.body, level = T.LevelOf(spells, e.level),
        tree = T.TreeOf(spells, e.tags, e.tree), tags = e.tags or {}, why = e.explain, entry = e, source = "library",
        spells = spells, verified = e.verified }
    end
  end
  local plan = T.Plan()
  local race = ns.FightPlan and ns.FightPlan.Race and ns.FightPlan.Race()
  local pvpNames = {}
  for _, u in ipairs(plan and plan.utility or {}) do
    if tostring(u.id):find("%-pvp$") then pvpNames[(u.spec or "") .. ":" .. u.name] = true end
  end
  for _, u in ipairs(plan and plan.utility or {}) do
    local isPvp = tostring(u.id):find("%-pvp$") ~= nil
    local key = (u.spec or "") .. ":" .. u.name
    local fitsMode = mode == "pvp" and (isPvp or not pvpNames[key]) or (mode ~= "pvp" and not isPvp)
    if (u.race == nil or u.race == race) and fitsMode then
      local spells = T.SpellsIn(u.text)
      local kindTag = u.name:lower()
      out[#out + 1] = { id = u.id, name = u.name, body = u.text, level = T.LevelOf(spells), tree = T.TreeOf(spells, nil, u.spec),
        tags = { kindTag }, why = u.why, source = "plan", spells = spells, race = u.race,
        entry = { id = u.id, name = u.name, class = cls, body = u.text, scope = "char", explain = u.why, planUtility = true } }
    end
  end
  -- each build's talent spells, as the line that build's fight plan uses for it
  -- (not when a macro above already casts that spell: Intim and Intimidation were both there)
  local covered = {}
  for _, it in ipairs(out) do for _, sp in ipairs(it.spells or {}) do covered[sp] = true end end
  for _, it in ipairs(self:TalentItems(mode)) do
    if not covered[it.spells[1]] then out[#out + 1] = it end
  end
  -- one macro per name: a plan key (race and build aware) wins over a library one of the same name
  local byName, keep = {}, {}
  for _, it in ipairs(out) do
    local prev = byName[it.name]
    if not prev then byName[it.name] = it keep[#keep + 1] = it
    elseif it.source == "plan" and prev.source ~= "plan" then
      for i, k in ipairs(keep) do if k == prev then keep[i] = it end end
      byName[it.name] = it
    end
  end
  out = keep
  table.sort(out, function(a, b) if a.level ~= b.level then return a.level < b.level end return a.name < b.name end)
  return out
end

-- Talent spells of each tree (the learn table's tree tag), each as a button of
-- its own: the line the build's plan uses for it and the plan's reason.
function T:TalentItems(mode)
  local plan = T.Plan()
  if not plan then return {} end
  local cls, out = ns.PlayerClass(), {}
  -- talents from the plan's learn table, then the client spellbook's (Data/SpellInfo.lua)
  local names, meta = {}, {}
  for sp, e in pairs(plan.learn or {}) do if e[2] then names[#names + 1] = sp meta[sp] = { e[2], e[1] } end end
  local isTree = {}
  for _, t in ipairs(plan.trees or {}) do isTree[t] = true end
  for sp, info in pairs(ns.SpellInfo and ns.SpellInfo[cls] or {}) do
    if type(info) == "table" and info.tree and isTree[info.tree] and not meta[sp] then
      names[#names + 1] = sp
      meta[sp] = { info.tree, info.level or 10 }
    end
  end
  table.sort(names)
  for _, sp in ipairs(names) do
    local tree, lvl = meta[sp][1], meta[sp][2]
    local s = plan.specs and plan.specs[tree]
    local m = s and (s[mode] or s.pve)
    local line, why
    for _, brackets in pairs(m or {}) do
      for _, b in ipairs(brackets) do
        for _, sl in ipairs(b.slots) do
          if type(sl) == "table" and not line then
            for _, x in ipairs(sl.spells or {}) do
              if x:gsub("^!", "") == sp and sl.line:find("^/cast") then line, why = sl.line, sl.why end
            end
          end
        end
      end
    end
    local name = sp:gsub("[^%w ]", ""):sub(1, 16)
    local body = "#showtooltip\n" .. (line or ("/cast " .. sp))
    out[#out + 1] = { id = cls:lower() .. "-talent-" .. (sp:lower():gsub("%W", "")), name = name,
      body = body, level = lvl, tree = tree, tags = { "combat" },
      why = (why and (why:sub(1, 1):upper() .. why:sub(2) .. ". ") or "") .. "A talent of this build. "
        .. (line and "Your Fight key for this build already uses it; this button is for when you want it yourself." or "Press it when it helps."),
      source = "talent", spells = { sp },
      entry = { id = "talent-" .. sp, name = name, class = cls, body = body, scope = "char",
        needsSpells = { sp } } }
  end
  return out
end

-- Columns: "every" then the class's trees. Cells: grid[band][column] = { items }.
function T:Grid(mode)
  local plan = T.Plan()
  local cols = { "every" }
  for _, t in ipairs(plan and plan.trees or {}) do cols[#cols + 1] = t end
  local index = {}
  for i, c in ipairs(cols) do index[c] = i end
  local grid = {}
  for b = 1, #T.BANDS do grid[b] = {} for c = 1, #cols do grid[b][c] = {} end end
  for _, it in ipairs(self:Items(mode)) do
    local col = index[it.tree or "every"] or 1
    local cell = grid[T.Band(it.level)][col]
    cell[#cell + 1] = it
  end
  return grid, cols
end

-- The macro text to write for an item now: the plan's extra keys drop the
-- clauses this character can't cast yet (like the fight keys do).
function T.BodyFor(it)
  if it.source ~= "plan" then return it.entry.body end
  local FP = ns.FightPlan
  local lines, casts = {}, 0
  for l in tostring(it.body):gmatch("[^\n]+") do
    local kept = FP and FP.KnownLine and FP.KnownLine(l) or l
    if kept then
      lines[#lines + 1] = kept
      if kept:find("^/cast") then casts = casts + 1 end
    end
  end
  return casts > 0 and table.concat(lines, "\n") or nil
end

-- "ready" | "installed" | "changed" | "locked" (level) | "needs X" | "on bar"
function T:State(it)
  local lvl = T.Level()
  if it.level and it.level > lvl then return "locked" end
  local lib = ns.MacroLibrary
  if not lib then return "ready" end
  local entry = it.entry
  if it.source == "plan" then
    local body = T.BodyFor(it)
    if not body then return "needs " .. (it.spells[1] or "a spell") end
    entry = { id = it.id, name = it.name, class = entry.class, body = body, scope = "char", explain = it.why }
  end
  return lib:State(entry)
end

-- Macros on your action bars, by name (gold ring on the page).
function T.OnBars()
  local set = {}
  for slot = 1, 120 do
    local kind, id = C.Call("GetActionInfo", slot)
    if kind == "macro" and id then
      local name = C.Call("GetMacroInfo", id)
      if type(name) == "string" then set[name] = true end
    end
  end
  return set
end

-- Writes the macro if needed, then puts it on the cursor to drop on a bar.
-- Out of combat only. Returns ok, message.
function T:PickUp(it)
  if C.InCombat() then return false, "not in combat: macros can't be written during a fight" end
  local lib = ns.MacroLibrary
  if not lib then return false, "macro library is off" end
  local entry = it.entry
  if it.level and it.level > T.Level() then return false, string.format("unlocks at level %d", it.level) end
  if it.source == "plan" then
    local body = T.BodyFor(it)
    if not body then return false, "learn " .. (it.spells[1] or "its spell") .. " first" end
    entry = { id = it.id, name = it.name, class = ns.PlayerClass(), body = body, scope = "char", explain = it.why }
  end
  local st = lib:State(entry)
  if st ~= "installed" then
    local ok, why = lib:Install(entry)
    if not ok then return false, why end
  end
  -- remember which build it belongs to, for "macros from your old build" after a respec
  local rec = lib:Settings().installed[entry.name]
  if rec then rec.tree = it.tree end
  self:Settings().seen[it.id] = true
  local index = C.Call("GetMacroIndexByName", entry.name) or 0
  if index == 0 then return false, "the macro wasn't found after writing it" end
  C.Call("PickupMacro", index)
  ns.Log:Info("macrotree", "picked up %s (%s)", tostring(entry.name), tostring(it.id))
  return true
end

-- Outrider macros written for another build than yours (after a respec):
-- { {name, tree} }. Kept until you clear them (MacroKit's idea, our code).
function T:OldBuild()
  local FP = ns.FightPlan
  local spec = FP and FP.enabled and FP:Spec() or "levelling"
  if spec == "levelling" or not ns.MacroLibrary then return {} end
  local out = {}
  for name, rec in pairs(ns.MacroLibrary:Settings().installed) do
    if rec.tree and rec.tree ~= spec then out[#out + 1] = { name = name, tree = rec.tree } end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

-- Removes them (only the ones Outrider wrote and you didn't change). Returns removed, kept.
function T:ClearOldBuild()
  if C.InCombat() then return 0, { "not in combat" } end
  local lib, removed, kept = ns.MacroLibrary, 0, {}
  for _, o in ipairs(self:OldBuild()) do
    local ok, why = lib:Remove({ name = o.name })
    if ok then removed = removed + 1 else kept[#kept + 1] = o.name .. ": " .. tostring(why) end
  end
  self:Info("old build macros cleared: %d removed, %d kept", removed, #kept)
  return removed, kept
end

-- ------------------------------------------------------------------ macro check
-- Spells Forever renamed or changed, from the Forever patch notes as community
-- macro guides report them (MacroKit's notes, foreverwow.com, 2026-11): a macro
-- still using the old name does nothing. verified = false.
T.RENAMED = {
  ["Curse of Agony"] = { to = "Bane of Agony", note = "Forever renamed it" },
  ["Elemental Mastery"] = { to = "Lightning Mastery", note = "Forever renamed it" },
  ["Faerie Fire (Feral)"] = { to = "Faerie Fire", note = "in Forever Faerie Fire works in Cat and Bear form" },
}

-- Your own macros (not Outrider's): old spell names and exact copies.
-- { {name, problem, fix} }
function T:Audit()
  local acct, char = C.Call("GetNumMacros")
  acct, char = tonumber(C.Readable(acct)) or 0, tonumber(C.Readable(char)) or 0
  local base = rawget(_G, "MAX_ACCOUNT_MACROS") or 120
  local ours = ns.MacroLibrary and ns.MacroLibrary:Settings().installed or {}
  local out, bodies = {}, {}
  local idx = {}
  for i = 1, acct do idx[#idx + 1] = i end
  for i = base + 1, base + char do idx[#idx + 1] = i end
  for _, i in ipairs(idx) do
    local name, _, body = C.Call("GetMacroInfo", i)
    name, body = C.Readable(name), C.Readable(body)
    if type(name) == "string" and type(body) == "string" and not ours[name] then
      for _, sp in ipairs(T.SpellsIn(body)) do
        local r = T.RENAMED[sp]
        if r and not (ns.Spellbook and ns.Spellbook:Known(sp)) then
          out[#out + 1] = { name = name, problem = sp .. " (" .. r.note .. ")", fix = "use " .. r.to }
        end
      end
      local key = body:gsub("%s+", " ")
      if bodies[key] and key ~= "" then
        out[#out + 1] = { name = name, problem = "the same text as " .. bodies[key], fix = "keep one, free a macro slot" }
      else bodies[key] = name end
    end
  end
  return out
end

-- Character macro slots: used, max (a character holds 18).
function T.Slots()
  local _, char = C.Call("GetNumMacros")
  return tonumber(C.Readable(char)) or 0, rawget(_G, "MAX_CHARACTER_MACROS") or 18
end

-- The icon for an item: its first known spell's icon, else Outrider's art or a game icon by kind.
function T.Icon(it)
  for _, sp in ipairs(it.spells or {}) do
    local rec = ns.Spellbook and ns.Spellbook:Known(sp)
    local tex = rec and C.SpellIcon(rec.id or sp)
    if tex then return tex, true end
  end
  -- the spell's own game icon, from the client's spellbook data, before you know it
  for _, sp in ipairs(it.spells or {}) do
    local info = T.Info(sp)
    if info and info.icon then return "Interface\\Icons\\" .. info.icon, true end
  end
  local tag = it.tags and it.tags[1]
  local art = tag and ns.Art and ns.Art:Path("macro_" .. tag)
  if art then return art, false end
  return "Interface\\Icons\\" .. (T.TAG_ICON[tag or ""] or "INV_Misc_Note_01"), false
end

-- Words for the detail panel: { title, sub, when, what, lines = {..}, note }
function T:Explain(it, key)
  local out = { title = it.name, lines = {} }
  local entry = key and key.entry or it.entry
  local body = key and entry.body or (T.BodyFor(it) or it.body)
  body = E.Fill(body, ns.MacroLibrary and ns.MacroLibrary:Values() or {})
  out.body = body
  if key then
    out.when = T.KEY_WHEN[entry.name] or "Press it in every fight; Outrider keeps it up to date."
    out.what = entry.explain
  else
    local tag = it.tags and it.tags[1]
    out.when = T.WHEN[tag or ""] or "When its spell helps."
    out.what = it.why
  end
  local whys = entry.whys
  for line in (body .. "\n"):gmatch("(.-)\n") do
    if line ~= "" and not line:find("^#showtooltip") then
      local w = whys and whys[line]
      out.lines[#out.lines + 1] = w and (w:sub(1, 1):upper() .. w:sub(2)) or E.ExplainLine(line) or line
    end
  end
  return out
end

-- ------------------------------------------------------------------ page
local ICON, BIG = 36, 54
local COLOR = { gold = { 0.95, 0.78, 0.30 } }

local function slotButton(parent, size)
  local b = CreateFrame("Button", nil, parent, ns.Theme:BackdropTemplate())
  b:SetSize(size, size)
  ns.Theme:ApplyPanel(b, "bg", "strong")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 2, -2)
  b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.badge = UI.Text(b, "small", "text")
  b.badge:SetPoint("BOTTOMRIGHT", 2, -2)
  b.ring = b:CreateTexture(nil, "OVERLAY")
  b.ring:SetPoint("TOPLEFT", -3, 3)
  b.ring:SetPoint("BOTTOMRIGHT", 3, -3)
  b.ring:SetColorTexture(COLOR.gold[1], COLOR.gold[2], COLOR.gold[3], 0.35)
  b.ring:Hide()
  b:RegisterForDrag("LeftButton")
  return b
end

ns.Hub:AddTab("macros", "Macros", function(p)
  T:Info("macros page: building")
  local Theme = ns.Theme
  p.mode = "pve"
  p.who = UI.Text(p, "normal", "goldText")
  p.who:SetPoint("TOPLEFT", 2, 0)
  p.pve = UI:Button(p, "PvE", 56, function() p.mode = "pve" p:Refresh() end)
  p.pvp = UI:Button(p, "PvP", 56, function() p.mode = "pvp" p:Refresh() end)
  UI.Tip(p.pve, "PvE", "Macros for questing and dungeons.")
  UI.Tip(p.pvp, "PvP", "The PvP versions, for battlegrounds, duels and world PvP. Only changes this view.")

  -- the detail panel on the right
  local d = UI:Card(p)
  d:SetWidth(270)
  d:SetPoint("TOPRIGHT", -4, -26)
  d:SetPoint("BOTTOMRIGHT", -4, 0)
  p.detail = d
  p.pvp:SetPoint("TOPRIGHT", d, "TOPRIGHT", 0, 26)
  p.pve:SetPoint("RIGHT", p.pvp, "LEFT", -6, 0)
  -- character macro slots: a character holds 18
  p.slots = UI.Text(p, "small", "muted")
  p.slots:SetPoint("RIGHT", p.pve, "LEFT", -12, 0)
  -- before 10 talent points: pick the build you're heading for
  p.plan = UI:Dropdown(p, 170, {}, function() return T:Settings().planned or "levelling" end, function(v)
    T:Settings().planned = v ~= "levelling" and v or nil
    if ns.HunterFight and ns.HunterFight.enabled then ns.HunterFight:Update("planned build") end
    T:Info("planned build: %s", tostring(v))
    p:Refresh()
  end)
  p.plan:SetPoint("RIGHT", p.slots, "LEFT", -12, 0)
  UI.Tip(p.plan, "Planned build", "Before 10 talent points, pick the build you're heading for: your keys and the tree follow it. Your talents take over from 10 points.")
  d.title = UI.Display(d, "side", "goldText") d.title:SetPoint("TOPLEFT", 14, -10) d.title:SetPoint("RIGHT", d, "RIGHT", -12, 0)
  d.title:SetJustifyH("LEFT")
  d.sub = UI.Text(d, "small", "muted") d.sub:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -4) d.sub:SetPoint("RIGHT", d, "RIGHT", -12, 0)
  d.sub:SetJustifyH("LEFT")
  d.text = UI.Text(d, "small", "text") d.text:SetPoint("TOPLEFT", d.sub, "BOTTOMLEFT", 0, -10) d.text:SetPoint("RIGHT", d, "RIGHT", -12, 0)
  d.text:SetJustifyH("LEFT") if d.text.SetJustifyV then d.text:SetJustifyV("TOP") end
  d.msg = UI.Text(d, "small", "warn") d.msg:SetPoint("BOTTOMLEFT", 14, 44) d.msg:SetPoint("RIGHT", d, "RIGHT", -12, 0) d.msg:SetJustifyH("LEFT")
  d.pick = UI:Button(d, "Pick up", 110, function() p:PickCurrent() end)
  d.pick:SetPoint("BOTTOMLEFT", 14, 12)
  UI.SetPrimary(d.pick, true)
  UI.Tip(d.pick, "Pick up", "Writes the macro if it isn't in your macros yet, then puts it on your cursor: click an action bar slot to drop it.")
  d.remove = UI:Button(d, "Remove", 90, function()
    local it = p.current
    if not (it and ns.MacroLibrary) then return end
    local ok, why = ns.MacroLibrary:Remove(it.key and it.key.entry or it.entry)
    d.msg:SetText(ok and "Removed from your macros." or tostring(why))
    p:Refresh()
  end)
  d.remove:SetPoint("LEFT", d.pick, "RIGHT", 6, 0)
  d.copy = UI:Button(d, "Copy text", 90, function()
    local it = p.current
    if not it then return end
    local x = T:Explain(it, it.key)
    UI:TextDialog(it.name, x.body, "copy")
  end)
  d.copy:SetPoint("LEFT", d.remove, "RIGHT", 6, 0)
  UI.Tip(d.copy, "Copy text", "Shows the macro's text to copy, so you can change it and make your own.")
  -- your own macro next to Outrider's (FightPlan's check): Use Outrider's / Keep mine
  d.useOurs = UI:Button(d, "Use Outrider's", 120, function()
    local f = p.own
    local F = ns.HunterFight
    local mine = f and F and F:Entry(f.kind or "ranged")
    local ok, why = false, "nothing to install"
    if mine then ok, why = ns.MacroLibrary:Install(mine) end
    d.msg:SetText(ok and ("Outrider's " .. mine.name .. " is in your macros. Drag it to your bar in place of yours.") or tostring(why))
    p:Refresh(true)
  end)
  d.useOurs:SetPoint("BOTTOMLEFT", 14, 12)
  d.keep = UI:Button(d, "Keep mine", 100, function()
    local f = p.own
    if f and ns.FightPlan then ns.FightPlan:KeepMine(f.name, f.body) end
    p.own, p.current = nil, nil
    d.msg:SetText("Kept. Outrider won't mention this macro again unless you change it.")
    p:Refresh(true)
  end)
  d.keep:SetPoint("LEFT", d.useOurs, "RIGHT", 6, 0)
  d.useOurs:Hide() d.keep:Hide()

  -- your keys
  local keys = UI:Card(p)
  keys:SetPoint("TOPLEFT", 0, -26)
  keys:SetPoint("RIGHT", d, "LEFT", -12, 0)
  keys:SetHeight(128)
  p.keys = keys
  keys.head = UI.Text(keys, "normal", "goldText") keys.head:SetPoint("TOPLEFT", 12, -8)
  keys.head:SetText("Your keys  |cff8f96a6set up once; Outrider rewrites them as you learn spells|r")
  keys.flow = UI.Text(keys, "small", "muted") keys.flow:SetPoint("BOTTOMLEFT", 12, 8) keys.flow:SetPoint("RIGHT", keys, "RIGHT", -12, 0)
  keys.flow:SetJustifyH("LEFT")
  keys.btns = {}

  -- the tree
  local tree = CreateFrame("Frame", nil, p)
  tree:SetPoint("TOPLEFT", keys, "BOTTOMLEFT", 0, -10)
  tree:SetPoint("RIGHT", d, "LEFT", -12, 0)
  tree:SetPoint("BOTTOM", p, "BOTTOM", 0, 34)
  p.tree = tree
  tree.colHeads, tree.rowHeads, tree.cells, tree.pool, tree.emblems = {}, {}, {}, {}, {}
  -- a painted backdrop behind the tree when installed (art batch 6: macro_tree_<class>, else macro_tree)
  tree.bg = tree:CreateTexture(nil, "BACKGROUND")
  tree.bg:SetAllPoints()
  tree.bg:SetAlpha(0.35)
  tree.bg:Hide()
  p.legend = UI.Text(p, "small", "muted")
  p.legend:SetPoint("BOTTOMLEFT", 2, 14)
  p.legend:SetPoint("RIGHT", d, "LEFT", -12, 0)
  p.legend:SetJustifyH("LEFT")
  p.legend:SetText("Click an icon to read it; drag it (or Pick up) onto your action bar.  Gold: on your bar.  Grey with a number: unlocks at that level.")
  -- banner: one of your own macros misses parts of your build
  p.ownLine = UI.Text(p, "small", "warn")
  p.ownLine:SetPoint("BOTTOMLEFT", p.legend, "TOPLEFT", 0, 6)
  -- banner: your own macros with an old spell name or an exact copy
  p.auditLine = UI.Text(p, "small", "warn")
  -- banner: Outrider macros from the build you had before a respec
  p.oldLine = UI.Text(p, "small", "warn")
  p.oldLine:SetPoint("BOTTOMLEFT", p.ownLine, "TOPLEFT", 0, 8)
  p.auditLine:SetPoint("BOTTOMLEFT", p.oldLine, "TOPLEFT", 0, 8)
  p.auditLine:SetPoint("RIGHT", d, "LEFT", -12, 0)
  p.auditLine:SetJustifyH("LEFT")
  p.oldBtn = UI:Button(p, "Clear them", 90, function()
    local n, kept = T:ClearOldBuild()
    d.msg:SetText(string.format("Removed %d.%s", n, #kept > 0 and (" Kept: " .. table.concat(kept, "; ")) or ""))
    p:Refresh(true)
  end)
  p.oldBtn:SetHeight(20)
  p.oldBtn:SetPoint("LEFT", p.oldLine, "RIGHT", 8, 0)
  UI.Tip(p.oldBtn, "Clear them", "Removes the macros Outrider wrote for your old build. A macro you changed stays.")
  p.ownBtn = UI:Button(p, "Compare", 80, function() if p.findings and p.findings[1] then p:ShowOwn(p.findings[1]) end end)
  p.ownBtn:SetHeight(20)
  p.ownBtn:SetPoint("LEFT", p.ownLine, "RIGHT", 8, 0)
  p.export = UI:Button(p, "Export", 80, function()
    local s, err = ns.MacroLibrary and ns.MacroLibrary:Export()
    if s then UI:TextDialog("Outrider macros (" .. ns.db.key .. ")", s, "copy") else d.msg:SetText(tostring(err)) end
  end)
  p.export:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT", -12, 8)
  p.import = UI:Button(p, "Import", 80, function()
    UI:TextDialog("Import macros into " .. ns.db.key, "", "paste", function(text)
      local n, skipped = ns.MacroLibrary:Import(text)
      if not n then return false, skipped end
      d.msg:SetText(string.format("Installed %d.%s", n, #skipped > 0 and (" Skipped: " .. table.concat(skipped, "; ")) or ""))
      p:Refresh()
      return true
    end)
  end)
  p.import:SetPoint("RIGHT", p.export, "LEFT", -6, 0)

  local function hookButton(b)
    b:SetScript("OnClick", function(self) p:Show(self.item) end)
    b:SetScript("OnDragStart", function(self) p:Show(self.item) p:PickCurrent() end)
    b:SetScript("OnEnter", function(self)
      local it = self.item
      if not it then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(it.name)
      GameTooltip:AddLine(it.stateText or "", 0.75, 0.75, 0.75, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end

  local function paint(b, it, onBars, size)
    b.item = it
    local tex, own = T.Icon(it)
    -- Outrider's own key art when installed (art batch 6: macro_key_fight ...)
    local keyArt = it.key and ns.Art and ns.Art:Path("macro_key_" .. tostring(it.name):lower())
    if keyArt then tex = keyArt end
    b.icon:SetTexture(tex)
    local st = it.key and (ns.MacroLibrary and ns.MacroLibrary:State(it.key.entry) or "ready") or T:State(it)
    it.state = st
    local locked = st == "locked" or (type(st) == "string" and st:find("^needs"))
    if b.icon.SetDesaturated then b.icon:SetDesaturated(locked and true or false) end
    b.icon:SetAlpha(locked and 0.55 or 1)
    local usable = not locked
    local new = usable and not it.key and not T:Settings().seen[it.id]
    b.badge:SetText(st == "locked" and tostring(it.level) or new and "|cfff1d58enew|r" or "")
    local on = onBars[it.name] and true or false
    b.ring:SetShown(on)
    Theme:ApplyPanel(b, "bg", on and "gold" or "strong")
    it.stateText = st == "locked" and string.format("Unlocks at level %d", it.level)
      or (on and "On your bar") or (st == "installed" and "In your macros; drag it to a bar")
      or (st == "changed" and "In your macros, but its text was changed") or (st == "ready" and "Ready: drag it to a bar")
      or tostring(st)
    b:SetSize(size, size)
    b:Show()
  end

  function p:PickCurrent()
    local it = self.current
    if not it then return end
    local ok, why
    if it.key then
      if C.InCombat() then ok, why = false, "not in combat"
      else
        local lib = ns.MacroLibrary
        if lib:State(it.key.entry) ~= "installed" then ok, why = lib:Install(it.key.entry) else ok = true end
        if ok then
          local index = C.Call("GetMacroIndexByName", it.key.entry.name) or 0
          if index > 0 then C.Call("PickupMacro", index) else ok, why = false, "the macro wasn't found" end
        end
      end
    else
      ok, why = T:PickUp(it)
    end
    d.msg:SetText(ok and "On your cursor: click an action bar slot to drop it." or tostring(why))
    self:Refresh(true)
  end

  -- your macro and Outrider's for the same key, side by side
  function p:ShowOwn(f)
    self.own, self.current = f, nil
    local FP, F = ns.FightPlan, ns.HunterFight
    local mine = F and F:Entry(f.kind or "ranged")
    d.title:SetText(f.name .. "  |cffffc74d(your macro)|r")
    d.sub:SetText("A better fit is available")
    local lines = { "|cff8f96a6Yours:|r", tostring(f.body or ""),
      string.format("\nCovers about %d%% of your build's %s rotation.", math.floor((f.score or 0) * 100 + 0.5),
        FP.SPEC_NAMES[FP:Spec()] or FP:Spec()) }
    if #(f.missing or {}) > 0 then lines[#lines + 1] = "Missing: " .. table.concat(f.missing, ", ") end
    for _, i in ipairs(f.issues or {}) do lines[#lines + 1] = "Problem: " .. i .. " (needs /stopmacro [channeling])" end
    if mine then lines[#lines + 1] = "\n|cfff1d58eOutrider's " .. mine.name .. ":|r" lines[#lines + 1] = mine.body end
    d.text:SetText(table.concat(lines, "\n"))
    d.pick:Hide() d.remove:Hide()
    d.useOurs:SetShown(mine ~= nil) d.keep:Show()
    d.msg:SetText("")
  end

  function p:Show(it)
    if not it then return end
    self.current, self.own = it, nil
    d.useOurs:Hide() d.keep:Hide()
    if it.id and it.state ~= "locked" then T:Settings().seen[it.id] = true end
    local x = T:Explain(it, it.key)
    d.title:SetText(x.title)
    local names = ns.FightPlan and ns.FightPlan.SPEC_NAMES or {}
    local sub = it.key and "One of your keys" or (it.tree and ((names[it.tree] or it.tree) .. " build") or "Every build")
    sub = sub .. "  ·  " .. (it.stateText or "")
    sub = sub .. string.format("  ·  %d / 255 characters", #(x.body or ""))
    d.sub:SetText(sub)
    local parts = { "|cfff1d58eWhen to press|r", x.when }
    if x.what and x.what ~= "" then parts[#parts + 1] = "\n|cfff1d58eWhat it does|r" parts[#parts + 1] = x.what end
    parts[#parts + 1] = "\n|cfff1d58eLine by line|r"
    for i, l in ipairs(x.lines) do parts[#parts + 1] = i .. ". " .. l end
    parts[#parts + 1] = "\n|cff8f96a6" .. x.body:gsub("\n", "  |  ") .. "|r"
    d.text:SetText(table.concat(parts, "\n"))
    local st = it.state
    d.pick:SetShown(st ~= "locked")
    d.copy:Show()
    d.remove:SetShown(st == "installed" or st == "changed")
    d.msg:SetText(st == "locked" and string.format("Unlocks at level %d. It appears here so you can plan ahead.", it.level) or "")
  end

  T:Info("macros page: built")
  function p:Refresh(keepMsg)
    -- one set of macro values for the whole page (see MacroLibrary:Hold)
    if ns.MacroLibrary and not ns.MacroLibrary.held then
      local t0 = C.Call("debugprofilestop")
      local r = ns.MacroLibrary:Hold(self.Refresh, self, keepMsg)
      local t1 = C.Call("debugprofilestop")
      if t0 and t1 then T:Info("macros page drawn: %d icons in %.0f ms", self.count or 0, t1 - t0) end
      return r
    end
    local cls = ns.PlayerClass() or ""
    local FP = ns.FightPlan
    local spec = FP and FP.enabled and FP:Spec() or "levelling"
    local specName = FP and FP.SPEC_NAMES and FP.SPEC_NAMES[spec] or spec
    self.who:SetText(string.format("%s%s  ·  %s  ·  level %d", cls:sub(1, 1), cls:sub(2):lower(),
      spec == "levelling" and "levelling build (talents from level 10)" or (ns.TitleCase(specName or "") .. " build"), T.Level()))
    local used, max = T.Slots()
    self.slots:SetText(string.format("%s%d / %d character macros|r", used >= max and "|cffff6060" or "|cff8f96a6", used, max))
    -- the build menu, while talents don't decide yet
    local plan = T.Plan()
    local opts = { { "levelling", "Levelling (no build yet)" } }
    for _, t in ipairs(plan and plan.trees or {}) do opts[#opts + 1] = { t, "Plan: " .. ((FP and FP.SPEC_NAMES[t]) or t) } end
    if self.plan.SetOptions then self.plan:SetOptions(opts) else self.plan.options = opts end
    local fromTalents = FP and FP.enabled and spec ~= "levelling" and spec ~= (T:Settings().planned or "")
    self.plan:SetShown(not fromTalents and #opts > 1)
    if self.plan.Refresh then self.plan:Refresh() end
    UI.SetPrimary(self.pve, self.mode == "pve")
    UI.SetPrimary(self.pvp, self.mode == "pvp")
    local onBars = T.OnBars()

    -- keys
    local list = T:Keys()
    for i, k in ipairs(list) do
      local b = keys.btns[i]
      if not b then
        b = slotButton(keys, BIG)
        b.cap = UI.Text(keys, "small", "text")
        b.cap:SetPoint("TOP", b, "BOTTOM", 0, -3)
        hookButton(b)
        keys.btns[i] = b
      end
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", keys, "TOPLEFT", 16 + (i - 1) * (BIG + 34), -30)
      local it = { name = k.name, key = k, spells = T.SpellsIn(k.entry.body), tags = { "combat" }, level = 1 }
      paint(b, it, onBars, BIG)
      b.cap:SetText(k.name)
      b.cap:Show()
    end
    for i = #list + 1, #keys.btns do keys.btns[i]:Hide() keys.btns[i].cap:Hide() end
    local main = list[1]
    local flow = {}
    for _, s in ipairs(main and main.steps or {}) do
      local sp = T.SpellsIn(s.text)
      if #sp > 0 then flow[#flow + 1] = table.concat(sp, " / ") end
    end
    keys.flow:SetText(#flow > 0 and (main.name .. ", press by press:  " .. table.concat(flow, "  >  ")) or
      (#list == 0 and "Fight keys for your class come with the fight plans." or ""))

    -- tree
    for _, b in ipairs(tree.pool) do b:Hide() end
    local grid, cols = T:Grid(self.mode)
    local W = math.max(400, tree:GetWidth() or 0)
    if W < 300 then W = 520 end
    local labelW = 46
    -- "Every <class>" holds most macros: it gets two shares of the width, each build one
    local shares = #cols + 1
    local unit = math.floor((W - labelW) / shares)
    local colX, colWs = {}, {}
    local x = labelW
    for c = 1, #cols do
      colWs[c] = c == 1 and unit * 2 or unit
      colX[c] = x
      x = x + colWs[c]
    end
    for c, id in ipairs(cols) do
      local h = tree.colHeads[c]
      if not h then h = UI.Text(tree, "small", "text") tree.colHeads[c] = h end
      h:ClearAllPoints()
      h:SetPoint("TOPLEFT", tree, "TOPLEFT", colX[c], 0)
      h:SetWidth(colWs[c])
      h:SetJustifyH("CENTER")
      local names = FP and FP.SPEC_NAMES or {}
      local name = id == "every" and ("Every " .. cls:lower()) or (names[id] or id)
      local mine = id == spec
      h:SetText((mine and "|cfff1d58e" or "|cffbbbbbb") .. name .. (mine and "  (yours)" or "") .. "|r")
      h:Show()
      -- the build's emblem left of its name (art batch 6: spec_<class>_<tree>)
      local em = tree.emblems[c]
      if not em then em = tree:CreateTexture(nil, "ARTWORK") em:SetSize(16, 16) tree.emblems[c] = em end
      local art = id ~= "every" and ns.Art and ns.Art:Path("spec_" .. cls:lower() .. "_" .. id)
      if art then
        em:SetTexture(art)
        em:ClearAllPoints()
        em:SetPoint("RIGHT", h, "CENTER", -((h.GetStringWidth and h:GetStringWidth() or 60) / 2) - 4, 0)
        em:Show()
      else em:Hide() end
    end
    local bgArt = ns.Art and (ns.Art:Path("macro_tree_" .. cls:lower()) or ns.Art:Path("macro_tree"))
    if bgArt then tree.bg:SetTexture(bgArt) tree.bg:Show() else tree.bg:Hide() end
    for c = #cols + 1, #tree.colHeads do tree.colHeads[c]:Hide() end
    -- each band as tall as its fullest cell (icons wrap inside a cell)
    local step = ICON + 4
    local n, y = 0, -20
    for bIdx, band in ipairs(T.BANDS) do
      local lines = 1
      for c = 1, #cols do
        local per = math.max(1, math.floor((colWs[c] - 4) / step))
        lines = math.max(lines, math.ceil(#grid[bIdx][c] / per))
      end
      local rh = tree.rowHeads[bIdx]
      if not rh then rh = UI.Text(tree, "small", "muted") tree.rowHeads[bIdx] = rh end
      rh:ClearAllPoints()
      rh:SetPoint("TOPLEFT", tree, "TOPLEFT", 0, y - 12)
      local here = T.Band(T.Level()) == bIdx
      rh:SetText((here and "|cfff1d58e" or "") .. band[1] .. "-" .. band[2] .. (here and "|r" or ""))
      for c = 1, #cols do
        local items = grid[bIdx][c]
        local per = math.max(1, math.floor((colWs[c] - 4) / step))
        for i, it in ipairs(items) do
          n = n + 1
          local btn = tree.pool[n]
          if not btn then btn = slotButton(tree, ICON) hookButton(btn) tree.pool[n] = btn end
          btn:ClearAllPoints()
          local row, col = math.floor((i - 1) / per), (i - 1) % per
          local inRow = math.min(per, #items - row * per)
          local x0 = colX[c] + math.floor((colWs[c] - inRow * step) / 2)
          btn:SetPoint("TOPLEFT", tree, "TOPLEFT", x0 + col * step, y - 4 - row * step)
          paint(btn, it, onBars, ICON)
        end
      end
      y = y - (lines * step + 10)
    end
    p.count = n
    -- your own macros that miss big parts of your build's rotation
    local own = {}
    for _, f in ipairs(FP and FP.findings or {}) do
      if not (FP.dismissed and FP.dismissed[f.name]) then own[#own + 1] = f end
    end
    self.findings = own
    local audit = T:Audit()
    self.audit = audit
    self.auditLine:SetText(#audit > 0 and string.format("Macro check: %s: %s, %s.%s", audit[1].name, audit[1].problem, audit[1].fix,
      #audit > 1 and string.format(" (%d more in /ride macrocheck)", #audit - 1) or "") or "")
    local old = T:OldBuild()
    local oldNames = {}
    for i, o in ipairs(old) do if i <= 4 then oldNames[#oldNames + 1] = o.name end end
    self.oldLine:SetText(#old > 0 and string.format("%d macro%s from your old build: %s%s.", #old, #old == 1 and "" or "s",
      table.concat(oldNames, ", "), #old > 4 and "..." or "") or "")
    self.oldBtn:SetShown(#old > 0)
    self.ownLine:SetText(#own > 0 and string.format("Your macro %s misses parts of your build's rotation.", own[1].name) or "")
    self.ownBtn:SetShown(#own > 0)
    if not keepMsg then d.msg:SetText("") end
    if self.own then self:ShowOwn(self.own)
    elseif self.current then self:Show(self.current)
    elseif list[1] then self:Show(keys.btns[1].item)
    elseif tree.pool[1] and tree.pool[1]:IsShown() then self:Show(tree.pool[1].item) end
  end
end, 42)

ns.AddCommand("macrocheck", "your own macros: old spell names and exact copies", function()
  local list = T:Audit()
  if #list == 0 then ns.Print("macro check: nothing to fix") return end
  for i, f in ipairs(list) do if i <= 8 then ns.Print("%s: %s, %s", f.name, f.problem, f.fix) end end
end)

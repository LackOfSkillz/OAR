-- Modules/MacroTreeModel.lua
-- Macro tree model: eligibility (level band, talent tree), the grid, state, explanations and pick-up. Split from Modules/MacroTree.lua (OI01-09); behaviour unchanged.

local _, ns = ...
local C = ns.Compat
local E = ns.MacroEngine
local T = ns.MacroTree

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
    -- your class's macros and the every-class ones (bandage, quest item...); profession ones only if you have it
    if (e.class == cls or e.class == "ALL") and (not ns.MacroLibrary or ns.MacroLibrary.HasProfession(e)) then
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
  -- singles a combined key already covers stay out of the tree unless asked for
  local spells, ids = {}, {}
  if ns.ComboKeys and ns.ComboKeys.enabled and not self:Settings().singles then spells, ids = ns.ComboKeys:Covered() end
  grid.hidden = 0
  for _, it in ipairs(self:Items(mode)) do
    local covered = ids[it.id] or false
    if not covered and #(it.spells or {}) > 0 then
      covered = true
      for _, sp in ipairs(it.spells) do if not spells[sp] then covered = false end end
    end
    if covered and it.tags[1] ~= "handy" then
      grid.hidden = grid.hidden + 1
    -- handy keys sit with your keys, not in the tree
    elseif it.tags[1] == "handy" then
      grid.handy = grid.handy or {}
      grid.handy[#grid.handy + 1] = it
    else
    local col = index[it.tree or "every"] or 1
    local cell = grid[T.Band(it.level)][col]
    cell[#cell + 1] = it
    end
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
    -- your own edits stay, but the drag still works: pick up the macro as it is
    local have = C.Call("GetMacroIndexByName", entry.name) or 0
    if not ok and st == "changed" and have > 0 then
      C.Call("PickupMacro", have)
      return true, "On your cursor as you edited it (Outrider leaves your changes alone): click an action bar slot."
    end
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
  -- a macro's own icon (the handy keys)
  if it.entry and it.entry.icon then return "Interface\\Icons\\" .. it.entry.icon, true end
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

-- Column widths for the tree (tidy-up 2026-11-20): each column as wide as its
-- fullest band needs, at least wide enough for its name; spare room shared out
-- evenly. When it doesn't all fit, the build columns keep their room and
-- "Every <class>" (column 1) wraps its icons onto more lines.
T.MIN_COL = 120

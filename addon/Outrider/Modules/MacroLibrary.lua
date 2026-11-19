-- Modules/MacroLibrary.lua  (P4-03 library tab, P4-04 installer)
-- Hub tab "Macros": the macro packs for this character's class (plus ALL),
-- each with its state (needs a spell / level / ready / installed / changed),
-- the filled-in text, a line-by-line explanation and Install / Update /
-- Remove / Pick up. Installing uses CreateMacro/EditMacro out of combat from
-- Gary's click; Outrider only edits or removes macros it installed itself
-- (tracked per character), never one Gary made.

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local E = ns.MacroEngine
local M = ns:NewModule("MacroLibrary", {
  title = "Macro library",
  phase = "P4",
  order = 61,
  defaults = { installed = {} },
})
ns.MacroLibrary = M

-- Entries for this character: its class plus "ALL", sorted by name.
function M:Entries()
  local class = ns.PlayerClass()
  local out = {}
  for _, e in ipairs(ns.Data:All("macro")) do
    if e.class == class or e.class == "ALL" then out[#out + 1] = e end
  end
  -- the hunter Fight macro is written from the spellbook, not a pack
  if ns.HunterFight and ns.HunterFight.enabled then
    for _, kind in ipairs(ns.HunterFight:Kinds()) do
      local e = ns.HunterFight:Entry(kind)
      if not e.empty then
        -- each line's reason from the fight plan, shown line by line on the page
        e.kind, e.whys = kind, {}
        for _, l in ipairs(ns.HunterFight:Lines(kind)) do if l.why and l.why ~= "" then e.whys[l.text] = l.why end end
        out[#out + 1] = e
      end
    end
  end
  if ns.Crafter and ns.Crafter.enabled then
    for _, e in ipairs(ns.Crafter:Entries()) do out[#out + 1] = e end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

-- Placeholder values available now (P4-05 adds food, drink and mount).
function M:Values()
  local v = {}
  local scan = ns.Modules:Get("RareScan")
  if scan then
    local names = {}
    for k in pairs(scan:Settings().watch) do if type(k) == "string" then names[#names + 1] = ns.TitleCase(k) end end
    table.sort(names)
    v.TARGET = names[1]
  end
  if ns.BagFood then
    if not ns.BagFood.food and not ns.BagFood.drink then ns.BagFood:Scan() end
    v.FOOD, v.DRINK = ns.BagFood.food, ns.BagFood.drink
  end
  if ns.RareMacros and ns.RareMacros.enabled then ns.RareMacros:Values(v) end
  return v
end

function M:Missing(entry)
  for _, sp in ipairs(entry.needsSpells or {}) do
    if not (ns.Spellbook and ns.Spellbook:Known(sp)) then return "needs " .. sp end
  end
  local lvl = C.Call("UnitLevel", "player") or 0
  if entry.level and entry.level > lvl then return "level " .. entry.level end
  local _, missing = E.Fill(entry.body, self:Values())
  -- words, not the macro's placeholder names (tour 2026-11-19: "needs DRINK")
  local words = { FOOD = "food in your bags", DRINK = "a drink in your bags", MOUNT = "a mount", TARGET = "a watched rare",
    PET = "a pet", AMMO = "ammo" }
  for i, k in ipairs(missing) do missing[i] = words[k] or tostring(k):lower() end
  if #missing > 0 then return "needs " .. table.concat(missing, ", ") end
  return nil
end

-- "ready" | "installed" | "changed" | reason it can't be installed yet
function M:State(entry)
  local rec = self:Settings().installed[entry.name]
  if rec then
    local index = C.Call("GetMacroIndexByName", entry.name) or 0
    if index == 0 then self:Settings().installed[entry.name] = nil
    else
      local _, _, body = C.Call("GetMacroInfo", index)
      local want = E.Fill(entry.body, self:Values())
      if not E.Same(body, rec.body) and not self.mismatchLogged then
        self.mismatchLogged = true
        self:Debug("macro %s: game text %d chars, written %d chars", entry.name, type(body) == "string" and #body or -1, #rec.body)
      end
      return (E.Same(body, rec.body) and E.Same(body, want)) and "installed" or "changed"
    end
  end
  return self:Missing(entry) or "ready"
end

function M:Install(entry, force)
  if not entry or type(entry.name) ~= "string" or type(entry.body) ~= "string" then return false, "invalid library entry" end
  if C.InCombat() then return false, "not in combat" end
  local why = self:Missing(entry)
  if why then return false, why end
  local body = E.Fill(entry.body, self:Values())
  if E.Errors(body) > 0 then return false, "macro has errors" end
  local installed = self:Settings().installed
  local index = C.Call("GetMacroIndexByName", entry.name) or 0
  if index > 0 and not installed[entry.name] then
    -- Even a force flag must not overwrite a same-named player macro.
    return false, "you already have a macro called " .. entry.name .. " that Outrider didn't make"
  end
  local perChar = entry.scope ~= "account"
  if index > 0 then
    local rec = installed[entry.name]
    local _, _, current = C.Call("GetMacroInfo", index)
    if not rec or not E.Same(C.Readable(current), rec.body) then
      return false, "macro text was changed outside Outrider; review it manually before updating"
    end
    local ok, result = pcall(EditMacro, index, entry.name, nil, body)
    if not ok or result == false then return false, "EditMacro failed" end
  else
    local acct, char = C.Call("GetNumMacros")
    local maxA = rawget(_G, "MAX_ACCOUNT_MACROS") or 120
    local maxC = rawget(_G, "MAX_CHARACTER_MACROS") or 18
    if perChar and (char or 0) >= maxC then return false, "no free character macro slot" end
    if not perChar and (acct or 0) >= maxA then return false, "no free general macro slot" end
    local ok, newIndex = pcall(CreateMacro, entry.name, entry.icon or "INV_MISC_QUESTIONMARK", body, perChar)
    if not ok or not newIndex then return false, "CreateMacro failed" end
    index = newIndex
  end
  installed[entry.name] = { id = entry.id, body = body, t = time() }
  self:Info("installed macro %s (%s, index %s, %d chars)", entry.name, entry.id, tostring(index), #body)
  return true, index
end

function M:Remove(entry)
  if not entry or type(entry.name) ~= "string" then return false, "invalid library entry" end
  if C.InCombat() then return false, "not in combat" end
  local rec = self:Settings().installed[entry.name]
  if not rec then return false, "Outrider didn't install this one" end
  local index = C.Call("GetMacroIndexByName", entry.name) or 0
  if index > 0 then
    local _, _, current = C.Call("GetMacroInfo", index)
    if not E.Same(C.Readable(current), rec.body) then
      return false, "macro text changed outside Outrider; not deleting player edits"
    end
    local ok, result = pcall(DeleteMacro, index)
    if not ok or result == false then return false, "DeleteMacro failed" end
  end
  self:Settings().installed[entry.name] = nil
  self:Info("removed macro %s", entry.name)
  return true
end

-- --------------------------------------------------------------- P4-09
-- Export the library macros this character installed as an OTR1: string.
-- Only library ids travel; the importing character fills the text itself
-- (its own food, watchlist, spell names), so no foreign macro text is ever
-- installed.
M.KIND, M.VERSION = "macros", 1

function M:Export()
  local ids = {}
  for name, rec in pairs(self:Settings().installed) do if rec.id then ids[#ids + 1] = rec.id end end
  table.sort(ids)
  if #ids == 0 then return nil, "no library macros installed on this character" end
  return ns.Serialize.Export({ kind = self.KIND, v = self.VERSION, from = ns.db.key, ids = ids })
end

-- Returns installed, skipped (list of "name: reason")
function M:Import(text)
  local p, err = ns.Serialize.Import(text)
  if not p then return nil, err end
  if type(p) ~= "table" or p.kind ~= self.KIND then return nil, "this string is not an Outrider macro export" end
  if type(p.v) ~= "number" or p.v > self.VERSION then return nil, "made by a newer Outrider" end
  if type(p.ids) ~= "table" then return nil, "no macros in this string" end
  -- A copied string is untrusted; never let it cause unbounded CreateMacro
  -- operations even when the player explicitly clicks Import.
  if #p.ids < 1 or #p.ids > 120 then return nil, "macro set size is invalid" end
  local checked = {}
  for _, id in ipairs(p.ids) do
    if type(id) ~= "string" or #id < 1 or #id > 100 or checked[id] then
      return nil, "duplicate or invalid macro id"
    end
    checked[id] = true
  end
  local byId = {}
  for _, e in ipairs(self:Entries()) do byId[e.id] = e end
  local installed, skipped = 0, {}
  for _, id in ipairs(p.ids) do
    local e = type(id) == "string" and byId[id]
    if not e then
      skipped[#skipped + 1] = tostring(id) .. ": not for this class"
    else
      local ok, why = self:Install(e)
      if ok then installed = installed + 1 else skipped[#skipped + 1] = e.name .. ": " .. tostring(why) end
    end
  end
  self:Info("imported %d macros from %s, skipped %d", installed, tostring(p.from), #skipped)
  return installed, skipped
end

function M:Activity()
  local n = 0
  for _ in pairs(self:Settings().installed) do n = n + 1 end
  return string.format("%d library macros for you, %d installed", #self:Entries(), n)
end

-- --------------------------------------------------------------- tab
local STATE_COLOR = { ready = "text", installed = "good", changed = "warn" }

-- Build- and level-aware list (Gary, 2026-11-18: "a rogue ... should only be
-- presented with rogue macros ... and the recommendations based on their
-- build and their level"). Entries() is already this class only; Sections()
-- orders them: Recommended for you (the fight keys written for your build,
-- then pack macros for your build and level), From level N (not yet), and
-- Other builds (tagged for another talent tree of your class).
M.SPEC_TAG = { survival = "sv", marksmanship = "mm", beastmastery = "bm", ["beast mastery"] = "bm" }
local function specTagOf(e, trees)
  for _, t in ipairs(e.tags or {}) do
    local tag = M.SPEC_TAG[t] or t
    for _, tree in ipairs(trees) do if tree == tag then return tag end end
  end
end

function M:Sections()
  local FP = ns.FightPlan
  local plan = FP and FP.Plan and FP.Plan()
  local trees = plan and plan.trees or {}
  local spec = FP and FP.enabled and FP:Spec() or "levelling"
  local level = tonumber(C.Readable(C.Call("UnitLevel", "player"))) or 1
  local rec, recPack, later, other = {}, {}, {}, {}
  for _, e in ipairs(self:Entries()) do
    local tag = specTagOf(e, trees)
    local st = self:State(e)
    if e.dynamic then rec[#rec + 1] = e
    elseif tag and spec ~= "levelling" and tag ~= spec then other[#other + 1] = e
    elseif (e.level and e.level > level) or not (st == "ready" or st == "installed" or st == "changed") then later[#later + 1] = e
    else recPack[#recPack + 1] = e end
  end
  table.sort(later, function(a, b) return (a.level or 0) < (b.level or 0) end)
  local out = {}
  local function section(title, list)
    if #list == 0 then return end
    out[#out + 1] = { header = title }
    for _, e in ipairs(list) do out[#out + 1] = e end
  end
  -- your own macros that miss big parts of your build's rotation (FightPlan check)
  local own = {}
  for _, f in ipairs(FP and FP.findings or {}) do
    if not (FP.dismissed and FP.dismissed[f.name]) then
      own[#own + 1] = { id = "own:" .. f.name, name = f.name, body = f.body or "", own = true, finding = f, class = ns.PlayerClass() }
    end
  end
  section("Your macros: a better fit is available", own)
  section("Recommended for you", rec)
  section(#rec > 0 and "Also good for your build" or "Recommended for you", recPack)
  section("Not yet (level or spell to learn)", later)
  section("Other builds of your class", other)
  return out, spec, level
end

-- The Macros page itself is Modules/MacroTree.lua (the skill-tree layout, 2026-11-19).

-- Modules/FightPlan.lua  (Gary, 2026-11-18: "research every class, spec, race
-- and faction ... a pre-generated fight macro for each ... best rotation for
-- the level ... both the ranged and melee version ... and tell them when the
-- macro isn't efficient for their build")
--
-- The fight keys HunterFight writes now come from Data/FightPlans.lua (built
-- from docs/fight_macro_catalog_draft.lua; research in
-- docs/FIGHT_MACRO_RESEARCH_2026-11-18.md). For this character:
--   * spec   = the talent tree with the most points (under 10 points: levelling)
--   * mode   = PvE, or PvP in a battleground/arena or when chosen in settings
--   * level  = the newest bracket whose spells this character actually knows
--     (a spell not trained yet falls back to the bracket before)
--   * race   = the racial Burst / Break / Recover keys for this race
-- Every line is an ordinary macro line (hard rule 1); buffs already up are left
-- out, as before. Unverified (verified = false) until the fight logs agree.
--
-- Builder kinds keep their old names and macro names; each class maps them to
-- the plan's keys (a warrior's key 1 "Fight" is the plan's melee key, key 2
-- "Strike" its reactive key). New keys (Pull, Reach, Trap, Burst...) are extra
-- kinds with the plan's names.

local _, ns = ...
local C = ns.Compat
local F = ns.HunterFight
if not F then return end

local M = ns:NewModule("FightPlan", {
  title = "Fight macros by class, spec, race and level",
  phase = "P4",
  order = 31,
  defaults = { mode = "auto", suggest = true, kept = {} },
})
ns.FightPlan = M

-- builder kind -> plan key, per class (only where they differ from the kind)
M.KIND_MAP = {
  WARRIOR = { ranged = "melee", melee = "react", pull = "ranged" },
  ROGUE = { ranged = "melee", melee = "utility", pull = "ranged" },
  PALADIN = { ranged = "melee", reach = "ranged" },
}
-- extra builder kinds per class (beyond HunterFight's CLASS_KINDS), named after the plan's keys
M.EXTRA = {
  WARRIOR = { "pull" }, ROGUE = { "pull" }, PALADIN = { "reach" },
  PRIEST = { "melee" }, SHAMAN = { "melee" }, DRUID = { "melee" },
}

local function known(name)
  if not name or name == "" then return true end
  name = name:gsub("^!", "")
  return ns.Spellbook and ns.Spellbook:Known(name) ~= nil
end

-- ------------------------------------------------------------ who you are
function M.Plan() return ns.FightPlans and ns.FightPlans:Class(ns.PlayerClass()) end

function M:Spec()
  local plan = M.Plan()
  if not plan then return "levelling" end
  local T = ns.Talents and ns.Talents.Read and ns.Talents:Read()
  if not (T and T.tabs) then return "levelling" end
  local best, bestN, total = nil, -1, 0
  for i, tab in ipairs(T.tabs) do
    -- Secret/unreadable talent points cannot establish a specialization.
    local raw = tab and C.Readable(tab.spent)
    if type(raw) ~= "number" or raw < 0 or raw ~= raw then return "levelling" end
    local n = raw
    total = total + n
    if n > bestN then best, bestN = i, n end
  end
  if total < 10 or not best then return "levelling" end
  return plan.trees[best] or "levelling"
end

function M:Mode()
  local s = self:Settings()
  if s.mode == "pve" or s.mode == "pvp" then return s.mode end
  local _, kind = C.Call("IsInInstance")
  kind = C.Readable(kind)
  if kind == "pvp" or kind == "arena" then return "pvp" end
  -- world PvP: a hostile player targeted (read out of combat, when macros can change)
  if C.Readable(C.Call("UnitIsPlayer", "target")) and C.Readable(C.Call("UnitCanAttack", "player", "target")) then return "pvp" end
  return "pve"
end

-- Race as the plan names it: Scourge is Undead; Skyborne differs by faction.
function M.Race()
  local _, file = C.Call("UnitRace", "player")
  file = C.Readable(file)
  if file == "Scourge" then return "Undead" end
  if file == "Skyborne" then
    local fac = C.Readable(C.Call("UnitFactionGroup", "player"))
    if fac == "Alliance" then return "SkyborneAlliance" end
    if fac == "Horde" then return "SkyborneHorde" end
    return nil -- unknown faction must never select the wrong racial macro
  end
  return file
end

function M.Level() return tonumber(C.Readable(C.Call("UnitLevel", "player"))) or 1 end

-- ------------------------------------------------------------ brackets
-- The plan entry for a builder kind: { brackets } or nil.
function M:Brackets(kind)
  local plan = M.Plan()
  if not plan then return nil end
  local key = (M.KIND_MAP[ns.PlayerClass()] or {})[kind] or kind
  local spec, mode = self:Spec(), self:Mode()
  local s = plan.specs[spec] or plan.specs.levelling
  local m = s and (s[mode] or s.pve)
  return m and m[key], key
end

-- Resolves "same line as before" strings to their full slots.
local function resolve(brackets)
  local byLine, out = {}, {}
  for _, b in ipairs(brackets) do
    local slots = {}
    for _, sl in ipairs(b.slots) do
      if type(sl) == "table" then byLine[sl.line] = sl slots[#slots + 1] = sl
      elseif byLine[sl] then slots[#slots + 1] = byLine[sl] end
    end
    out[#out + 1] = { from = b.from, slots = slots }
  end
  return out
end

local function allKnown(slots)
  for _, sl in ipairs(slots) do
    for _, sp in ipairs(sl.spells or {}) do if not known(sp) then return false end end
  end
  return true
end

-- The slots for this character now: the newest bracket at or below the level
-- whose spells are all known; if none fits whole, the first bracket with the
-- unknown slots left out.
function M:Slots(kind)
  local brackets = self:Brackets(kind)
  if not brackets or #brackets == 0 then return nil end
  local list, level = resolve(brackets), M.Level()
  for i = #list, 1, -1 do
    if list[i].from <= level and allKnown(list[i].slots) then return list[i].slots, list[i].from end
  end
  local keep = {}
  for _, sl in ipairs(list[1].slots) do if allKnown({ sl }) then keep[#keep + 1] = sl end end
  return keep, list[1].from
end

-- Feeds HunterFight's builder (add(keep, text, why)). Returns true when the
-- plan had lines for this kind.
function M:Lines(kind, add)
  if not self.enabled then return false end
  -- a hunter with a thrown weapon or none: the old builder knows what to leave out
  if ns.PlayerClass() == "HUNTER" and kind == "ranged" and F.Ranged and F:Ranged() ~= "bow" then return false end
  local slots = self:Slots(kind)
  if not slots or #slots == 0 then return false end
  local casts = 0
  for _, sl in ipairs(slots) do
    local skip = false
    if sl.kind == "buff" then
      -- a buff already up is left out (the line comes back when it drops)
      for _, sp in ipairs(sl.spells or {}) do if F.AuraOn(sp:gsub("^!", "")) then skip = true end end
    end
    -- a clause for a spell not learned yet drops out of the line (the rogue
    -- Strike key's Pick Pocket before level 4); a line with nothing left is skipped
    local text = not skip and M.KnownLine(sl.line)
    if not text then skip = true end
    if not skip then
      add(sl.keep or 5, text, sl.why)
      if not text:find("^/targetenemy") and not text:find("^/startattack") and not text:find("^/petattack") then casts = casts + 1 end
    end
  end
  return casts > 0
end

-- ------------------------------------------------------------ extra keys
-- Utility keys from the plan for this class and race (Trap, Burst, Break,
-- Recover...): the text with the lines for spells this character lacks taken out.
function M:Utility()
  local plan = M.Plan()
  if not plan then return {} end
  local race, spec, mode, out, seen = M.Race(), self:Spec(), self:Mode(), {}, {}
  -- in PvP a "-pvp" version replaces the plain one of the same name
  local pvpNames = {}
  for _, u in ipairs(plan.utility or {}) do if tostring(u.id):find("%-pvp$") then pvpNames[u.name] = true end end
  for _, u in ipairs(plan.utility or {}) do
    local isPvp = tostring(u.id):find("%-pvp$") ~= nil
    local fits = (u.race == nil or u.race == race) and (u.spec == nil or u.spec == spec)
      and (mode == "pvp" and (isPvp or not pvpNames[u.name]) or (mode ~= "pvp" and not isPvp))
    if fits and not seen[u.name] then
      local lines, casts = {}, 0
      for l in tostring(u.text):gmatch("[^\n]+") do
        local kept = M.KnownLine(l)
        if kept then
          lines[#lines + 1] = kept
          if kept:find("^/cast") then casts = casts + 1 end
        end
      end
      if casts > 0 then
        seen[u.name] = true
        out[#out + 1] = { kind = u.name:lower(), name = u.name, text = table.concat(lines, "\n"), why = u.why, id = u.id }
      end
    end
  end
  return out
end

-- A macro line with the choices this character can't cast taken out:
-- "/cast [mod:shift] Frost Trap; [mod:ctrl] Explosive Trap; Freezing Trap" at
-- level 20 keeps "/cast Freezing Trap" (a clause's own conditions stay). nil
-- when nothing castable is left. Other lines (/use, #showtooltip...) pass.
function M.KnownLine(l)
  local verb, rest = l:match("^(/cast)%s+(.*)$")
  if not verb then return l end
  local keep = {}
  for clause in (rest .. ";"):gmatch("([^;]*);") do
    local c = clause:match("^%s*(.-)%s*$")
    local spell = c:gsub("^%[[^%]]*%]%s*", ""):gsub("^%[[^%]]*%]%s*", "")
    if spell ~= "" and known(spell) then keep[#keep + 1] = c end
  end
  if #keep == 0 then return nil end
  -- Preserve the modifier even if only that clause is known; stripping it
  -- would turn a Shift-only panic action into an unmodified key press.
  -- keep the line's own separator: the rogue Stealth line is written with ";"
  -- (no space) to stay within 255 characters
  return verb .. " " .. table.concat(keep, rest:find("; ", 1, true) and "; " or ";")
end

-- The kinds HunterFight should write for this class: its own plus the plan's
-- extra keys that have lines for this character.
function M:Kinds(base)
  local out = {}
  for _, k in ipairs(base or {}) do out[#out + 1] = k end
  if not self.enabled or not M.Plan() then return out end
  for _, k in ipairs(M.EXTRA[ns.PlayerClass()] or {}) do
    local slots = self:Slots(k)
    if slots and #slots > 0 then out[#out + 1] = k end
  end
  return out
end

-- The macro name for a plan key (Pull, Reach, Strike...).
function M:Name(kind)
  local plan = M.Plan()
  local key = (M.KIND_MAP[ns.PlayerClass()] or {})[kind] or kind
  return plan and plan.keys and plan.keys[key] or nil
end

-- ------------------------------------------------------------ wrong-macro check
-- A hand-written fight macro is scored against this character's plan (research
-- section 8): the share of the plan's weighted slots (once/opener/cooldown 3,
-- filler 2, reactive 1) whose spell appears in it, over spells known; plus the
-- known mistakes (a channel without a /stopmacro [channeling] guard). Out of
-- combat only; one chat line per session at most (rule 6), the rest to the log.
M.WEIGHT = { once = 3, opener = 3, cooldown = 3, filler = 2, reactive = 1 }
M.CHANNELS = { ["Drain Life"] = true, ["Mind Flay"] = true, ["Arcane Missiles"] = true, ["Drain Soul"] = true, ["Drain Mana"] = true }

function M:Score(body, kind)
  local slots = self:Slots(kind or "ranged") or {}
  local total, got, missing = 0, 0, {}
  for _, sl in ipairs(slots) do
    local w = M.WEIGHT[sl.kind]
    if w then
      local any, has = false, false
      for _, sp in ipairs(sl.spells or {}) do
        local name = sp:gsub("^!", "")
        if known(name) then
          any = true
          if body:find(name, 1, true) then has = true end
        end
      end
      if any then
        total = total + w
        if has then got = got + w
        elseif w >= 3 then missing[#missing + 1] = (sl.spells[1] or ""):gsub("^!", "") end
      end
    end
  end
  local issues = {}
  for ch in pairs(M.CHANNELS) do
    if body:find(ch, 1, true) and not body:find("/stopmacro%s*%[channeling%]") then issues[#issues + 1] = ch .. " can be cut short" end
  end
  return total > 0 and got / total or 1, missing, issues
end

local SPEC_NAMES = { bm = "Beast Mastery", mm = "Marksmanship", sv = "Survival", disc = "Discipline", holy = "Holy",
  shadow = "Shadow", arcane = "Arcane", fire = "Fire", frost = "Frost", arms = "Arms", fury = "Fury", prot = "Protection",
  assassination = "Assassination", combat = "Combat", subtlety = "Subtlety", affliction = "Affliction",
  demonology = "Demonology", destruction = "Destruction", balance = "Balance", feral = "Feral", resto = "Restoration",
  ret = "Retribution", elemental = "Elemental", enhancement = "Enhancement", levelling = "levelling" }
M.SPEC_NAMES = SPEC_NAMES

function M:Check(why)
  if not (self.enabled and self:Settings().suggest) or C.InCombat() or not M.Plan() then return end
  local n = tonumber(C.Readable(C.Call("GetNumMacros"))) or 0
  local ours = ns.MacroLibrary and ns.MacroLibrary:Settings().installed or {}
  local found = {}
  for i = 1, math.min(n, 138) do
    local name, _, body = C.Call("GetMacroInfo", i)
    name, body = C.Readable(name), C.Readable(body)
    local kept = self:Settings().kept or {}
    if type(body) == "string" and type(name) == "string" and not ours[name] and kept[name] ~= body then
      -- compare with whichever of your keys it is closest to (Fight, Strike, Heal...)
      local best
      for _, kind in ipairs(F:Kinds()) do
        if self:Slots(kind) then
          local score, missing, issues = self:Score(body, kind)
          if not best or score > best.score then best = { kind = kind, score = score, missing = missing, issues = issues } end
        end
      end
      local casts = select(2, body:gsub("/cast", ""))
      if best and casts >= 2 and ((best.score < 0.6 and #best.missing > 0) or #best.issues > 0) then
        found[#found + 1] = { name = name, body = body, kind = best.kind, score = best.score, missing = best.missing, issues = best.issues }
      end
    end
  end
  self.findings = found
  for _, f in ipairs(found) do
    self:Info("macro check (%s): '%s' scores %.2f, missing %s%s", tostring(why), f.name, f.score,
      table.concat(f.missing, ", "), #f.issues > 0 and (", " .. table.concat(f.issues, ", ")) or "")
  end
  local first = found[1]
  if first and not self.said then
    self.said = true
    local spec = SPEC_NAMES[self:Spec()] or self:Spec()
    if #first.issues > 0 then
      ns.Print("your \"%s\" macro: %s when you press it again. Outrider's Fight macro waits for the channel (Macros page).", first.name, first.issues[1])
    else
      ns.Print("your \"%s\" macro looks set up for a different build. For %s at level %d it's missing %s. See the Macros page, or ignore this.",
        first.name, spec, M.Level(), table.concat(first.missing, ", ", 1, math.min(3, #first.missing)))
    end
  end
end

-- "Keep mine": this macro, with this exact text, is never mentioned again.
-- Changing the macro brings the check back.
function M:KeepMine(name, body)
  local s = self:Settings()
  s.kept = type(s.kept) == "table" and s.kept or {}
  s.kept[name] = body
  for i = #(self.findings or {}), 1, -1 do if self.findings[i].name == name then table.remove(self.findings, i) end end
  self:Info("kept the player's own macro '%s'", tostring(name))
end

function M:OnEnable()
  -- checked at once (no timer left pending); the once-per-session cap keeps it quiet
  self:On("PLAYER_ENTERING_WORLD", function() M:Check("login") end)
  self:On("UPDATE_MACROS", function() M:Check("macros changed") end)
  -- auto mode follows your target out of combat: a hostile player brings the
  -- PvP keys, a mob brings PvE back (only rewritten when the set changes)
  self:On("PLAYER_TARGET_CHANGED", function(mod)
    if C.InCombat() or mod:Settings().mode ~= "auto" then return end
    local m = mod:Mode()
    if m ~= mod.lastMode then
      local first = mod.lastMode == nil
      mod.lastMode = m
      if not first and F.Update then F:Update("mode " .. m) end
    end
  end)
  for _, e in ipairs({ "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "CHARACTER_POINTS_CHANGED" }) do
    self:On(e, function() if F.Update then F:Update("respec") end M:Check("respec") end)
  end
end

function M:Activity()
  if not M.Plan() then return "no plan for this class" end
  return string.format("%s, %s, level %d (%s)", SPEC_NAMES[self:Spec()] or self:Spec(), self:Mode():upper(), M.Level(), tostring(M.Race()))
end

ns.AddCommand("fightplan", "pve|pvp|auto  which fight macros to use; no word: what Outrider picked for you", function(arg)
  arg = tostring(arg or ""):lower()
  if arg == "pve" or arg == "pvp" or arg == "auto" then
    M:Settings().mode = arg
    if F.Update then F:Update("mode") end
    ns.Print("fight macros: %s", arg)
    return
  end
  ns.Print("fight macros for %s", M:Activity())
  for _, f in ipairs(M.findings or {}) do ns.Print("  \"%s\": %.0f%% of the plan%s", f.name, f.score * 100,
    #f.missing > 0 and (", missing " .. table.concat(f.missing, ", ")) or "") end
end)

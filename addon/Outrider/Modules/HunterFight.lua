-- Modules/HunterFight.lua  (class Fight macros; the file keeps its first name)
-- Spam macros per class (Gary, 2026-11-13: "class aware, only what is relevant
-- to the character being played"). Each class has its own keys, built only
-- from spells this character knows:
--   HUNTER  Fight (ranged), Strike (melee), Pet (care)
--   MAGE    Fight (ranged nuke), Strike (close: Frost Nova, Fire Blast, Arcane Explosion)
--   PRIEST  Fight (Shadow Word: Pain once, Mind Blast, Smite), Heal (best heal on mouseover, target or you)
-- Mage and priest orders follow the same one-spell-per-press rule as the
-- hunter's and are unverified until their fight logs are read.
-- Original hunter notes: two macros for hunters that Gary spams, written by Outrider from what this
-- character knows right now (Spellbook) and what is in the ranged slot, and
-- rewritten out of combat whenever a spell is learned or the ranged weapon
-- changes. Each is an ordinary macro: every press does what a hand-written
-- macro would do (hard rule 1). Outrider never casts anything.
--   Fight  - ranged: Hunter's Mark, Concussive Shot, Auto Shot (once), Serpent Sting, then Arcane Shot
--   Strike - melee:  Raptor Strike, Wing Clip, Mongoose Bite
--
-- What Forever allows (measured 2026-11-12, 12 fights, see FOREVER_CONSTRAINTS):
--   * one spell attempt per press: a line that casts, or is refused for a real
--     reason ("Target too close", "Out of range"), ends the press; only "Spell
--     is not ready yet" (cooldown, global cooldown) moves on to the next line;
--   * a macro can't see range, so ranged and melee are two keys;
--   * "reset=target" alone did not re-arm a castsequence reliably (Hunter's Mark went
--     out in 3 of 16 fights), and a reset=N timer never runs out while the key
--     is spammed (Mark 3 of 14 with reset=30/target), so once-per-pull lines
--     use reset=combat/target: they re-arm when combat ends or the target changes.
-- So each macro is ordered: once-per-pull spells first ("/castsequence
-- reset=combat/target X,null": one cast, then the line is null until combat
-- ends or the target changes), cooldown spells next (they fall
-- through while cooling down), and the always-usable spell last.
-- Each fight's casts and refusals are logged (UNIT_SPELLCAST_*, UI_ERROR_MESSAGE,
-- not the combat log) so the order can be checked without Gary typing anything.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("HunterFight", {
  title = "Fight macros for your class",
  phase = "P4",
  order = 64,
  classes = { HUNTER = true, MAGE = true, PRIEST = true },
  defaults = { auto = true, name = "Fight", meleeName = "Strike", petName = "Pet", healName = "Heal",
    concussive = true, wingclip = true, pet = true },
})
ns.HunterFight = M

local SHOOTERS = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true } -- bow / gun / crossbow
M.MAX = 255
M.KINDS = { "ranged", "melee", "pet" } -- the hunter's; see M:Kinds()
M.CLASS_KINDS = { HUNTER = { "ranged", "melee", "pet" }, MAGE = { "ranged", "melee" }, PRIEST = { "ranged", "heal" } }
M.SUFFIX = { ranged = "fight", melee = "strike", pet = "pet", heal = "heal" }

function M:Kinds() return M.CLASS_KINDS[ns.PlayerClass()] or {} end
function M:Supported() return M.CLASS_KINDS[ns.PlayerClass()] ~= nil end

local function known(name) return ns.Spellbook and ns.Spellbook:Known(name) ~= nil end

-- The call-pet spell's name as the spellbook shows it. Forever renames it
-- after the pet ("Call TempMystMane", measured 2026-11-12), so "Call Pet" or
-- any known spell named "Call <something>".
function M.CallPetName()
  if known("Call Pet") then return "Call Pet" end
  local best
  for _, sp in pairs(ns.Spellbook and ns.Spellbook.spells or {}) do
    if type(sp.name) == "string" and sp.name:match("^Call %S") and (not best or sp.name < best) then best = sp.name end
  end
  return best
end

-- "bow", "thrown" or nil (empty ranged slot)
function M:Ranged()
  local link = C.Call("GetInventoryItemLink", "player", 18)
  if not link then return nil end
  local info = C.ItemInfo(link)
  local loc = info and info.equipLoc
  if not loc then return "bow" end -- not cached yet: assume a shooter, rebuilt on the next change
  if loc == "INVTYPE_THROWN" then return "thrown" end
  return SHOOTERS[loc] and "bow" or nil
end

-- The lines in press order, each with a keep rank (lower = kept when the
-- macro has to shrink under 255 characters) and why it is there.
local CASTER = {}

-- Mage: one ranged nuke key and one close key.
function CASTER.MAGE(kind, add)
  add(1, "/targetenemy [noharm][dead]", "picks the nearest enemy when you have none")
  if kind == "melee" then
    if known("Frost Nova") then add(2, "/cast Frost Nova", "freezes it in place when it reaches you") end
    if known("Fire Blast") then add(3, "/cast Fire Blast", "whenever it is off cooldown") end
    if known("Arcane Explosion") then add(4, "/cast Arcane Explosion", "close-range filler") end
    return
  end
  if known("Frostbolt") then add(2, "/cast Frostbolt", "main nuke, slows it on the way in")
  elseif known("Fireball") then add(2, "/cast Fireball", "main nuke until you learn Frostbolt") end
end

-- Priest: damage key with the DoT once per pull, and a heal key.
function CASTER.PRIEST(kind, add)
  if kind == "heal" then
    local heal = known("Heal") and "Heal" or known("Lesser Heal") and "Lesser Heal" or nil
    if heal then
      add(1, "/cast [@mouseover,help,nodead][@target,help,nodead][@player] " .. heal,
        "heals who you point at, your friendly target, or you")
    end
    return
  end
  add(1, "/targetenemy [noharm][dead]", "picks the nearest enemy when you have none")
  if known("Shadow Word: Pain") then
    add(2, "/castsequence reset=combat/target Shadow Word: Pain,null", "once per pull (and per new target)")
  end
  if known("Mind Blast") then add(3, "/cast Mind Blast", "whenever it is off cooldown") end
  if known("Holy Fire") then add(4, "/cast Holy Fire", "whenever it is off cooldown") end
  if known("Smite") then add(2, "/cast Smite", "filler") end
end

function M:Lines(kind)
  local s = self:Settings()
  local L = {}
  local function add(keep, text, why) L[#L + 1] = { keep = keep, text = text, why = why } end
  local cls = ns.PlayerClass()
  if CASTER[cls] then CASTER[cls](kind, add) return L end
  if cls ~= "HUNTER" then return L end
  -- Pet key (Gary got his pet, 2026-11-12): one button for pet care, out of
  -- the spam keys because Mend Pet is a channel. Dead pet: Revive Pet; no pet
  -- out: Call Pet; otherwise Mend Pet.
  if kind == "pet" then
    local c = {}
    if known("Revive Pet") then c[#c + 1] = "[@pet,dead] Revive Pet" end
    local call = M.CallPetName()
    if call then c[#c + 1] = "[nopet] " .. call end
    if known("Mend Pet") then c[#c + 1] = "Mend Pet" end
    if #c > 0 then add(1, "/cast " .. table.concat(c, "; "), "dead pet: Revive; no pet: Call; otherwise Mend") end
    return L
  end
  add(1, "/targetenemy [noharm][dead]", "picks the nearest enemy when you have none")
  if s.pet then add(9, "/petattack [pet,harm]", "sends the pet at your target every press, so it pulls aggro off you") end
  if kind == "melee" then
    add(1, "/startattack", "keeps swinging")
    if s.wingclip and known("Wing Clip") then
      add(5, "/castsequence reset=combat/target Wing Clip,null", "slows once per pull so you can step back and shoot")
    end
    if known("Raptor Strike") then add(2, "/cast Raptor Strike", "whenever it is off cooldown") end
    if known("Mongoose Bite") then add(4, "/cast Mongoose Bite", "only after the target dodges") end
    return L
  end
  if self:Ranged() ~= "bow" then return L end
  -- One sequence per pull: Hunter's Mark, Concussive Shot, then Auto Shot,
  -- then Serpent Sting (Gary 2026-11-12: open with Mark and Concussive, not a
  -- plain arrow). Auto Shot sits inside the sequence so it starts once, right
  -- after Concussive, and is never re-sent ("!Auto Shot" in a castsequence
  -- works and moves on, measured 2026-11-12; re-sending it every press
  -- restarted the shot). A spell on cooldown or the global cooldown holds the
  -- sequence and the press falls through to Arcane Shot.
  -- Aspect of the Hawk before the pull (more ranged damage; Gary learned it,
  -- 2026-11-13). Out of combat only, and "!" never turns it off. Distracting
  -- Shot stays out: it pulls the mob off the pet onto you.
  if known("Aspect of the Hawk") then
    add(6, "/cast [nocombat] !Aspect of the Hawk", "before the pull: Hawk on (never turned off)")
  end
  local seq = {}
  if known("Hunter's Mark") then seq[#seq + 1] = "Hunter's Mark" end
  if s.concussive and known("Concussive Shot") then seq[#seq + 1] = "Concussive Shot" end
  if known("Auto Shot") then seq[#seq + 1] = "!Auto Shot" end
  if known("Serpent Sting") then seq[#seq + 1] = "Serpent Sting" end
  if #seq > 0 then
    add(2, "/castsequence reset=combat/target " .. table.concat(seq, ",") .. ",null",
      (table.concat(seq, ", then "):gsub("!", "")) .. ": once each per pull (and per new target)")
  end
  if known("Arcane Shot") then add(4, "/cast Arcane Shot", "whenever it is off cooldown") end
  return L
end

-- Body text; drops the lowest-priority lines until it fits. Returns body, dropped lines.
function M:Body(kind)
  local lines = self:Lines(kind or "ranged")
  local dropped = {}
  local function build()
    local t = { "#showtooltip" }
    for _, l in ipairs(lines) do t[#t + 1] = l.text end
    return table.concat(t, "\n")
  end
  local body = build()
  while #body > M.MAX and #lines > 1 do
    local worst = 1
    for i, l in ipairs(lines) do if l.keep >= lines[worst].keep then worst = i end end
    dropped[#dropped + 1] = table.remove(lines, worst).text
    body = build()
  end
  return body, dropped
end

local EXPLAIN = {
  MAGE = { ranged = "Ranged key: spam it. Frostbolt (or Fireball before you learn it).",
    melee = "Close key: when it reaches you. Frost Nova, Fire Blast, then Arcane Explosion." },
  PRIEST = { ranged = "Damage key: spam it. Shadow Word: Pain once, Mind Blast on cooldown, Smite between.",
    heal = "Heal key: heals who you point at, your friendly target, or you." },
}

-- Lines that cast something (targeting lines alone don't make a macro worth writing).
function M.Spells(lines)
  local n = 0
  for _, l in ipairs(lines) do if not l.text:find("^/targetenemy") then n = n + 1 end end
  return n
end

function M:Entry(kind)
  kind = kind or "ranged"
  local s = self:Settings()
  local body = self:Body(kind)
  local cls = ns.PlayerClass()
  if cls ~= "HUNTER" then
    local name = kind == "heal" and s.healName or kind == "melee" and s.meleeName or s.name
    return { id = cls:lower() .. "-" .. (M.SUFFIX[kind] or kind), name = name, class = cls, body = body, scope = "char",
      tags = { "combat" }, dynamic = true, empty = M.Spells(self:Lines(kind)) == 0,
      explain = (EXPLAIN[cls] or {})[kind] or "Outrider rewrites it when you learn a spell." }
  end
  if kind == "pet" then
    return { id = "hunter-pet", name = s.petName, class = "HUNTER", body = body, scope = "char",
      tags = { "pet" }, dynamic = true, empty = #self:Lines("pet") == 0,
      explain = "Pet care: Revive a dead pet, Call it when it's away, otherwise Mend Pet. Not a spam key." }
  end
  if kind == "melee" then
    return { id = "hunter-strike", name = s.meleeName, class = "HUNTER", body = body, scope = "char",
      tags = { "combat" }, dynamic = true,
      explain = "Melee key: press it when the mob reaches you. Outrider rewrites it when you learn a spell." }
  end
  return { id = "hunter-fight", name = s.name, class = "HUNTER", body = body, scope = "char",
    tags = { "combat" }, dynamic = true,
    explain = "Ranged key: spam it. Outrider rewrites it when you learn a spell or change your ranged weapon." }
end

-- Writes or rewrites both macros (out of combat; waits for combat to end).
function M:Update(why)
  if not ns.MacroLibrary then return end
  ns.Combat:Run("HunterFight", function()
    local lib = ns.MacroLibrary
    local installed = lib:Settings().installed
    local made = {}
    for _, kind in ipairs(self:Kinds()) do
      local entry = self:Entry(kind)
      -- Created only from Gary's click (Macros tab Install or /ride fight), like
      -- every library macro; once ours, it follows the spellbook by itself.
      -- Strike also comes along once Fight is ours (Gary asked for both, 2026-11-12).
      local wanted = not entry.empty and (installed[entry.name] or why == "command" or (kind ~= "ranged" and installed[self:Settings().name]))
      if wanted and lib:State(entry) ~= "installed" then
        local ok, msg = lib:Install(entry)
        if ok then
          made[#made + 1] = entry.name
          self:Info("%s macro written (%s): %d chars, %d lines", entry.name, tostring(why), #entry.body,
            select(2, entry.body:gsub("\n", "")))
          self:Debug("%s macro text: %s", entry.name, (entry.body:gsub("\n", " | ")))
        else
          self:Warn("%s macro not written: %s", entry.name, tostring(msg))
        end
      end
    end
    if why == "command" and #made > 0 then
      ns.Print("macros %s ready: open the macro window (/macro), Character tab, and drag them to your bar",
        table.concat(made, " and "))
    end
  end, "hunterfight")
end

-- ------------------------------------------------------- fight log (self-check)
-- Casts in the 6 s before combat count too: Hunter's Mark doesn't start
-- combat, so it lands before PLAYER_REGEN_DISABLED (Mark looked missing in
-- 12 of 14 fights while the next line, Concussive, went out in 11).
M.PRE = 6

function M:OnCombatStart()
  if not M.enabled then return end
  local now = C.Call("GetTime") or 0
  M.fight = { t0 = now, casts = {}, failed = {}, errors = {}, pet = C.Readable(C.Call("UnitExists", "pet")) == true }
  for _, p in ipairs(M.pre or {}) do
    if now - p.t <= M.PRE then M.fight.casts[#M.fight.casts + 1] = string.format("%s@%.1f", p.name, p.t - now) end
  end
  M.pre = {}
end

function M:OnCast(_, unit, _, spellID)
  if unit ~= "player" then return end
  local name = C.SpellName(spellID)
  if not name then return end
  local f = M.fight
  if not f then
    M.pre = M.pre or {}
    if #M.pre >= 5 then table.remove(M.pre, 1) end
    M.pre[#M.pre + 1] = { name = name, t = C.Call("GetTime") or 0 }
    return
  end
  if #f.casts >= 40 then return end
  f.casts[#f.casts + 1] = string.format("%s@%.1f", name, (C.Call("GetTime") or 0) - f.t0)
end

-- What a press tried and the game refused (failed cast, red error text), to
-- see why a line was skipped (2026-11-12: Serpent Sting never went out).
function M:OnFailed(_, unit, _, spellID)
  local f = M.fight
  if unit ~= "player" or not f then return end
  local name = C.SpellName(spellID)
  if name then f.failed[name] = (f.failed[name] or 0) + 1 end
end

function M:OnUIError(_, _, message)
  local f = M.fight
  local msg = C.Readable(message)
  if not f or type(msg) ~= "string" then return end
  f.errors[msg] = (f.errors[msg] or 0) + 1
end

local function counts(t)
  local out = {}
  for k, n in pairs(t) do out[#out + 1] = string.format("%s x%d", k, n) end
  table.sort(out)
  return #out > 0 and table.concat(out, ", ") or "none"
end

-- Whole-session tally, logged once at logout: the per-fight lines stop after
-- 15 fights and a long session pushes them out of the 600-line log (2026-11-12).
function M:Tally(f, secs)
  local t = M.tally or { fights = 0, secs = 0, castIn = {}, failed = {}, errors = {} }
  M.tally = t
  t.fights, t.secs = t.fights + 1, t.secs + secs
  if f.pet then t.withPet = (t.withPet or 0) + 1 end
  local seen = {}
  for _, c in ipairs(f.casts) do
    local name = c:match("^(.-)@")
    if name and not seen[name] then seen[name] = true; t.castIn[name] = (t.castIn[name] or 0) + 1 end
  end
  for k, n in pairs(f.failed) do t.failed[k] = (t.failed[k] or 0) + n end
  for k, n in pairs(f.errors) do t.errors[k] = (t.errors[k] or 0) + n end
end

function M:OnLogout()
  local t = M.tally
  if not t or t.fights == 0 then return end
  local cast = {}
  for k, n in pairs(t.castIn) do cast[#cast + 1] = string.format("%s %d/%d", k, n, t.fights) end
  table.sort(cast)
  M:Info("fights this session: %d, average %.0fs, pet out in %d; cast in: %s", t.fights, t.secs / t.fights, t.withPet or 0,
    table.concat(cast, ", "))
  if t.autoGaps and t.autoGaps > 0 then
    local speed = C.Call("UnitRangedDamage", "player")
    M:Info("auto shot: %d gaps, average %.2fs (weapon speed %s)", t.autoGaps, t.autoGapSum / t.autoGaps,
      type(C.Readable(speed)) == "number" and string.format("%.2fs", speed) or "?")
  end
  M:Info("fights refused this session: failed %s; errors %s", counts(t.failed), counts(t.errors))
end

-- Gaps between Auto Shots in one fight's cast list: a clipped shot shows as
-- gaps longer than the weapon speed. Returns { n, sum } or nil.
function M.AutoGaps(casts)
  local last, n, sum
  for _, c in ipairs(casts or {}) do
    local t = c:match("^Auto Shot@(%-?[%d%.]+)$")
    t = tonumber(t)
    if t then
      if last and t - last < 10 then n, sum = (n or 0) + 1, (sum or 0) + (t - last) end
      last = t
    end
  end
  return n and { n = n, sum = sum } or nil
end

function M:OnCombatEnd()
  local f = M.fight
  M.fight = nil
  if not f or (#f.casts == 0 and not next(f.failed)) then return end
  M:Tally(f, (C.Call("GetTime") or 0) - f.t0)
  local gap = M.AutoGaps(f.casts)
  if gap then
    local t = M.tally
    t.autoGaps, t.autoGapSum = (t.autoGaps or 0) + gap.n, (t.autoGapSum or 0) + gap.sum
  end
  M.fights = (M.fights or 0) + 1
  if M.fights > 15 then return end -- enough to judge the order; keep the log small
  M:Info("fight %.0fs, ranged %s: %s", (C.Call("GetTime") or 0) - f.t0, tostring(M:Ranged()), table.concat(f.casts, ", "))
  M:Info("fight refused: failed %s; errors %s", counts(f.failed), counts(f.errors))
end

-- Blizzard's own one-button rotation (Single-Button Assistant). The API is on
-- Forever (probe 2026-11-12); log whether hunters can use it, once per login.
function M:AssistedCombat()
  if not (C_AssistedCombat and C_AssistedCombat.GetNextCastSpell) then return nil end
  local available = C.Call("C_AssistedCombat.IsAvailable")
  local actionSpell = C.Call("C_AssistedCombat.GetActionSpell")
  local rotation = C.Call("C_AssistedCombat.GetRotationSpells")
  local names = {}
  if type(rotation) == "table" then
    for _, id in ipairs(rotation) do names[#names + 1] = C.SpellName(id) or tostring(id) end
  end
  return { available = available, actionSpell = actionSpell, actionName = actionSpell and C.SpellName(actionSpell),
    rotation = names }
end

function M:OnEnable()
  -- One time: Gary asked to turn Wing Clip back on (2026-11-12). After this,
  -- /ride fight wingclip on|off is his to change again.
  local s = self:Settings()
  if not s.wingclipOn20261112 then s.wingclipOn20261112, s.wingclip = true, true end
  local function later(why) ns.Throttle("hunterfight", 2, function() M:Update(why) end) end
  self:On("PLAYER_ENTERING_WORLD", function(mod, _, isLogin)
    if not mod:Settings().auto then return end
    later(isLogin and "login" or "reload")
    if not mod.assistLogged then
      mod.assistLogged = true
      local a = mod:AssistedCombat()
      if a then
        mod:Info("assisted combat: available %s, button spell %s (%s), rotation %d: %s", tostring(a.available),
          tostring(a.actionName), tostring(a.actionSpell), #a.rotation, table.concat(a.rotation, ", "))
      else
        mod:Info("assisted combat: not on this client")
      end
    end
  end)
  self:On("SPELLS_CHANGED", function(mod) if mod:Settings().auto then later("spells") end end)
  self:On("PLAYER_LEVEL_UP", function(mod) if mod:Settings().auto then later("level") end end)
  self:On("PLAYER_EQUIPMENT_CHANGED", function(mod, _, slot)
    if slot == 18 and mod:Settings().auto then later("ranged weapon") end
  end)
  self:On("PLAYER_REGEN_DISABLED", self.OnCombatStart)
  self:On("UNIT_SPELLCAST_SUCCEEDED", self.OnCast)
  self:On("PLAYER_REGEN_ENABLED", self.OnCombatEnd)
  self:On("UNIT_SPELLCAST_FAILED", self.OnFailed)
  self:On("UI_ERROR_MESSAGE", self.OnUIError)
  self:On("PLAYER_LOGOUT", self.OnLogout)
end

function M:OnDisable() ns.ThrottleCancel("hunterfight") end

function M:Activity()
  local parts = {}
  for _, k in ipairs(self:Kinds()) do
    local e = self:Entry(k)
    if not e.empty then parts[#parts + 1] = string.format("%s %d chars", e.name, #e.body) end
  end
  return #parts > 0 and table.concat(parts, ", ") or "no spells for these keys yet"
end

local OPTIONS = { concussive = true, wingclip = true, pet = true, auto = true }
ns.AddCommand("fight", "[concussive|wingclip|pet|auto on|off]  make, show or change your class's Fight macros (hunter, mage, priest)", function(arg)
  if not M:Supported() or not M.enabled then ns.Print("no Fight macros for your class yet") return end
  local key, val = (arg or ""):lower():match("^(%a+)%s+(%a+)$")
  if key and OPTIONS[key] and (val == "on" or val == "off") then
    M:Settings()[key] = val == "on"
    ns.Print("Fight macro: %s %s", key, val)
  end
  M:Update("command")
  for _, kind in ipairs(M:Kinds()) do
    local entry = M:Entry(kind)
    local body, dropped = M:Body(kind)
    ns.Print("%s (%s, %d chars), top line first:", entry.name, kind, #body)
    for _, l in ipairs(M:Lines(kind)) do ns.Print("  %s  |cffbbbbbb%s|r", l.text, l.why) end
    if #dropped > 0 then ns.Print("left out to fit 255 characters: %s", table.concat(dropped, "; ")) end
  end
end)

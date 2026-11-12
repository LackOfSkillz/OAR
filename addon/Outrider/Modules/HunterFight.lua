-- Modules/HunterFight.lua
-- Two macros for hunters that Gary spams, written by Outrider from what this
-- character knows right now (Spellbook) and what is in the ranged slot, and
-- rewritten out of combat whenever a spell is learned or the ranged weapon
-- changes. Each is an ordinary macro: every press does what a hand-written
-- macro would do (hard rule 1). Outrider never casts anything.
--   Fight  - ranged: Hunter's Mark, Concussive Shot, Serpent Sting, Arcane Shot, Auto Shot
--   Strike - melee:  Raptor Strike, Wing Clip, Mongoose Bite
--
-- What Forever allows (measured 2026-11-12, 12 fights, see FOREVER_CONSTRAINTS):
--   * one spell attempt per press: a line that casts, or is refused for a real
--     reason ("Target too close", "Out of range"), ends the press; only "Spell
--     is not ready yet" (cooldown, global cooldown) moves on to the next line;
--   * a macro can't see range, so ranged and melee are two keys;
--   * "reset=target" alone did not re-arm a castsequence reliably (Hunter's Mark went
--     out in 3 of 16 fights; Serpent Sting with a 15 s timer went out fine), so
--     every once-per-pull line also has a timer.
-- So each macro is ordered: once-per-target spells first ("/castsequence
-- reset=target X,null": one cast, then the line is null until the target
-- changes; Serpent Sting also every 15 s), cooldown spells next (they fall
-- through while cooling down), and the always-usable spell last.
-- Each fight's casts and refusals are logged (UNIT_SPELLCAST_*, UI_ERROR_MESSAGE,
-- not the combat log) so the order can be checked without Gary typing anything.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("HunterFight", {
  title = "Hunter Fight and Strike macros",
  phase = "P4",
  order = 64,
  classes = { HUNTER = true },
  defaults = { auto = true, name = "Fight", meleeName = "Strike", concussive = true, wingclip = true, pet = true },
})
ns.HunterFight = M

local SHOOTERS = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true } -- bow / gun / crossbow
M.MAX = 255
M.KINDS = { "ranged", "melee" }

local function known(name) return ns.Spellbook and ns.Spellbook:Known(name) ~= nil end

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
function M:Lines(kind)
  local s = self:Settings()
  local L = {}
  local function add(keep, text, why) L[#L + 1] = { keep = keep, text = text, why = why } end
  add(1, "/targetenemy [noharm][dead]", "picks the nearest enemy when you have none")
  if s.pet then add(9, "/petattack [pet,harm]", "sends the pet") end
  if kind == "melee" then
    add(1, "/startattack", "keeps swinging")
    if s.wingclip and known("Wing Clip") then
      add(5, "/castsequence reset=10/target Wing Clip,null", "slows once per pull (again after 10 s) so you can step back and shoot")
    end
    if known("Raptor Strike") then add(2, "/cast Raptor Strike", "whenever it is off cooldown") end
    if known("Mongoose Bite") then add(4, "/cast Mongoose Bite", "only after the target dodges") end
    return L
  end
  if self:Ranged() ~= "bow" then return L end
  if known("Hunter's Mark") then add(5, "/castsequence reset=30/target Hunter's Mark,null", "once per pull (again after 30 s)") end
  if s.concussive and known("Concussive Shot") then
    add(8, "/castsequence reset=20/target Concussive Shot,null", "first shot after Mark: slows it on the way in, more shots before it reaches you (Gary, 2026-11-12)")
  end
  if known("Serpent Sting") then
    add(3, "/castsequence reset=15/target Serpent Sting,null", "once per target, again after 15 s")
  end
  if known("Arcane Shot") then add(4, "/cast Arcane Shot", "whenever it is off cooldown") end
  if known("Auto Shot") then add(2, "/cast !Auto Shot", "last: keeps shooting (never toggles off)") end
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

function M:Entry(kind)
  kind = kind or "ranged"
  local s = self:Settings()
  local body = self:Body(kind)
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
    for _, kind in ipairs(M.KINDS) do
      local entry = self:Entry(kind)
      -- Created only from Gary's click (Macros tab Install or /ride fight), like
      -- every library macro; once ours, it follows the spellbook by itself.
      -- Strike also comes along once Fight is ours (Gary asked for both, 2026-11-12).
      local wanted = installed[entry.name] or why == "command" or (kind == "melee" and installed[self:Settings().name])
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
function M:OnCombatStart()
  if not M.enabled then return end
  M.fight = { t0 = C.Call("GetTime") or 0, casts = {}, failed = {}, errors = {} }
end

function M:OnCast(_, unit, _, spellID)
  local f = M.fight
  if unit ~= "player" or not f or #f.casts >= 40 then return end
  local name = C.SpellName(spellID)
  if not name then return end
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
  M:Info("fights this session: %d, average %.0fs; cast in: %s", t.fights, t.secs / t.fights, table.concat(cast, ", "))
  M:Info("fights refused this session: failed %s; errors %s", counts(t.failed), counts(t.errors))
end

function M:OnCombatEnd()
  local f = M.fight
  M.fight = nil
  if not f or (#f.casts == 0 and not next(f.failed)) then return end
  M:Tally(f, (C.Call("GetTime") or 0) - f.t0)
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
  local f, m = self:Body("ranged"), self:Body("melee")
  return string.format("%s %d chars, %s %d chars", self:Settings().name, #f, self:Settings().meleeName, #m)
end

local OPTIONS = { concussive = true, wingclip = true, pet = true, auto = true }
ns.AddCommand("fight", "[concussive|wingclip|pet|auto on|off]  make, show or change the hunter Fight (ranged) and Strike (melee) macros", function(arg)
  if ns.PlayerClass() ~= "HUNTER" or not M.enabled then ns.Print("the Fight macro is for hunters") return end
  local key, val = (arg or ""):lower():match("^(%a+)%s+(%a+)$")
  if key and OPTIONS[key] and (val == "on" or val == "off") then
    M:Settings()[key] = val == "on"
    ns.Print("Fight macro: %s %s", key, val)
  end
  M:Update("command")
  for _, kind in ipairs(M.KINDS) do
    local entry = M:Entry(kind)
    local body, dropped = M:Body(kind)
    ns.Print("%s (%s, %d chars), top line first:", entry.name, kind, #body)
    for _, l in ipairs(M:Lines(kind)) do ns.Print("  %s  |cffbbbbbb%s|r", l.text, l.why) end
    if #dropped > 0 then ns.Print("left out to fit 255 characters: %s", table.concat(dropped, "; ")) end
  end
end)

-- Modules/HunterFight.lua
-- One "Fight" macro for hunters that Gary spams. Outrider writes its text from
-- what this character knows right now (Spellbook) and what is in the ranged
-- slot, and rewrites it out of combat whenever a spell is learned, the level
-- changes or the ranged weapon changes. The macro itself is an ordinary macro:
-- each press does what a hand-written macro would do (hard rule 1). Outrider
-- never casts anything.
--
-- How one press picks the attack (a macro can't read cooldowns or debuffs, so
-- the order of the lines does the choosing):
--   * every /cast line is tried top to bottom; a spell that is on cooldown,
--     out of range or too close simply fails and the next line is tried; only
--     one global-cooldown spell can go off per press;
--   * at range the melee strikes fail (too far), in melee the shots fail (too
--     close): that is the ranged/melee switch;
--   * spells that should go out once per target use "/castsequence ... ,null":
--     after the one cast the line stays on "null" and does nothing until the
--     target changes (reset=target); Serpent Sting also resets after 15 s.
-- Each fight's casts are logged (UNIT_SPELLCAST_SUCCEEDED, not the combat
-- log) so we can check the order in game without Gary typing anything.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("HunterFight", {
  title = "Hunter Fight macro (one key)",
  phase = "P4",
  order = 64,
  classes = { HUNTER = true },
  defaults = { auto = true, name = "Fight", concussive = true, wingclip = false, pet = true },
})
ns.HunterFight = M

local SHOOTERS = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true } -- bow / gun / crossbow
M.MAX = 255

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
function M:Lines()
  local s = self:Settings()
  local shooter = self:Ranged() == "bow"
  local L = {}
  local function add(keep, text, why) L[#L + 1] = { keep = keep, text = text, why = why } end
  add(1, "/targetenemy [noharm][dead]", "picks the nearest enemy when you have none")
  if s.pet then add(9, "/petattack [pet,harm]", "sends the pet") end
  if shooter and known("Auto Shot") then add(2, "/cast !Auto Shot", "keeps shooting (never toggles off)") end
  if known("Mongoose Bite") then add(6, "/cast Mongoose Bite", "melee: only after the target dodges") end
  if known("Raptor Strike") then add(3, "/cast Raptor Strike", "melee: your next swing hits harder") end
  if s.wingclip and known("Wing Clip") then
    add(10, "/castsequence reset=target Wing Clip,null", "melee: slows once so you can step back")
  end
  if known("Hunter's Mark") then add(5, "/castsequence reset=target Hunter's Mark,null", "once per target") end
  if shooter and known("Serpent Sting") then
    add(4, "/castsequence reset=15/target Serpent Sting,null", "once per target, again after 15 s")
  end
  if shooter and s.concussive and known("Concussive Shot") then
    add(8, "/castsequence reset=target Concussive Shot,null", "slows once per target so it reaches you later")
  end
  if shooter and known("Arcane Shot") then add(4, "/cast Arcane Shot", "whenever it is off cooldown") end
  return L
end

-- Body text; drops the lowest-priority lines until it fits. Returns body, dropped lines.
function M:Body()
  local lines = self:Lines()
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

function M:Entry()
  local body = self:Body()
  return { id = "hunter-fight", name = self:Settings().name, class = "HUNTER", body = body, scope = "char",
    tags = { "combat" }, dynamic = true,
    explain = "One key for every fight: spam it. Outrider rewrites it when you learn a spell or change your ranged weapon." }
end

-- Writes or rewrites the macro (out of combat; waits for combat to end).
function M:Update(why)
  if not ns.MacroLibrary then return end
  ns.Combat:Run("HunterFight", function()
    local entry = self:Entry()
    local lib = ns.MacroLibrary
    -- Created only from Gary's click (Macros tab Install or /ride fight), like
    -- every library macro; once it is ours, it follows the spellbook by itself.
    if not lib:Settings().installed[entry.name] and why ~= "command" then return end
    if lib:State(entry) == "installed" then return end
    local ok, msg = ns.MacroLibrary:Install(entry)
    if ok then
      self:Info("Fight macro written (%s): %d chars, %d lines", tostring(why), #entry.body, select(2, entry.body:gsub("\n", "")))
      self:Debug("Fight macro text: %s", (entry.body:gsub("\n", " | ")))
      if why == "command" then
        ns.Print("macro %s is ready: open the macro window (/macro), Character tab, and drag it to your bar", entry.name)
      end
    else
      self:Warn("Fight macro not written: %s", tostring(msg))
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

function M:OnCombatEnd()
  local f = M.fight
  M.fight = nil
  if not f or (#f.casts == 0 and not next(f.failed)) then return end
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
end

function M:OnDisable() ns.ThrottleCancel("hunterfight") end

function M:Activity()
  local body = self:Body()
  return string.format("%s macro: %d lines, %d chars", self:Settings().name, select(2, body:gsub("\n", "")), #body)
end

local OPTIONS = { concussive = true, wingclip = true, pet = true, auto = true }
ns.AddCommand("fight", "[concussive|wingclip|pet|auto on|off]  show or change the one-key hunter Fight macro", function(arg)
  if ns.PlayerClass() ~= "HUNTER" or not M.enabled then ns.Print("the Fight macro is for hunters") return end
  local key, val = (arg or ""):lower():match("^(%a+)%s+(%a+)$")
  if key and OPTIONS[key] and (val == "on" or val == "off") then
    M:Settings()[key] = val == "on"
    ns.Print("Fight macro: %s %s", key, val)
  end
  M:Update("command")
  local body, dropped = M:Body()
  ns.Print("Fight macro (%d chars), top line first:", #body)
  for _, l in ipairs(M:Lines()) do ns.Print("  %s  |cffbbbbbb%s|r", l.text, l.why) end
  if #dropped > 0 then ns.Print("left out to fit 255 characters: %s", table.concat(dropped, "; ")) end
end)

-- Modules/HunterFight.lua  (class Fight macros; the file keeps its first name)
-- Spam macros per class (requirement 2026-11-13: class aware, only what is relevant
-- to the character being played). Each class has its own keys, built only
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
--   Strike - melee:  Aspect of the Monkey (once), Wing Clip, Raptor Strike, Immolation Trap, Mongoose Bite
--   (Fight puts Hawk back: before the pull, and in a fight when nothing else is ready)
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
  classes = { HUNTER = true, MAGE = true, PRIEST = true, WARRIOR = true, ROGUE = true, WARLOCK = true,
    DRUID = true, PALADIN = true, SHAMAN = true }, -- the six others: Modules/ClassFight.lua
  defaults = { auto = true, name = "Fight", meleeName = "Strike", petName = "Pet", healName = "Heal", pullName = "Pull",
    concussive = false, wingclip = true, pet = true, shotHints = true }, -- Concussive off: guides keep it for when the pet loses aggro
})
ns.HunterFight = M

local SHOOTERS = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true } -- bow / gun / crossbow
M.MAX = 255
M.KINDS = { "ranged", "melee", "pet" } -- the hunter's; see M:Kinds()
M.CLASS_KINDS = { HUNTER = { "ranged", "melee", "pet" }, MAGE = { "ranged", "melee" }, PRIEST = { "ranged", "heal" } }
M.SUFFIX = { ranged = "fight", melee = "strike", pet = "pet", heal = "heal" }

-- Is this buff on the player? (buff names; secret or unreadable = assume off)
function M.AuraOn(name)
  local get = C.Resolve("C_UnitAuras.GetAuraDataByIndex")
  if type(get) ~= "function" then return false end
  for i = 1, 40 do
    local ok, a = pcall(get, "player", i, "HELPFUL")
    if not ok or type(a) ~= "table" then break end
    if C.Readable(a.name) == name then return true end
  end
  return false
end
function M.HawkOn() return M.AuraOn("Aspect of the Hawk") end

-- Buffs the macros depend on (a macro can't see buffs, so the macro is
-- rewritten out of combat when one goes on or off). M.WATCH[class] = names;
-- Modules/ClassFight.lua fills the other classes.
M.WATCH = { HUNTER = { "Aspect of the Hawk", "Aspect of the Monkey" } }
function M.WatchState()
  local out = {}
  for _, n in ipairs(M.WATCH[ns.PlayerClass()] or {}) do out[#out + 1] = n .. (M.AuraOn(n) and " on" or " off") end
  if M.WatchExtra then out[#out + 1] = M.WatchExtra() end
  return table.concat(out, ", ")
end
function M.MonkeyOn() return M.AuraOn("Aspect of the Monkey") end

function M:Kinds()
  local cls = ns.PlayerClass()
  local base = M.CLASS_KINDS[cls] or {}
  -- the plan adds keys (Pull, Reach, Strike for casters) and the class/race
  -- utility keys (Trap, Burst, Break, Recover); Modules/FightPlan.lua
  local FP = ns.FightPlan
  local out
  if FP and FP.enabled then
    out = FP:Kinds(base)
    for _, u in ipairs(FP:Utility()) do out[#out + 1] = u.kind end
  else
    out = {}
    for _, k in ipairs(base) do out[#out + 1] = k end
  end
  -- Bug 2026-11-23: a druid with no Bear or Cat Form yet had a Strike key
  -- that did the same as Fight. Strike waits for a form; Pull takes its place.
  if cls == "DRUID" and not (M.FormIndex and (M.FormIndex("Bear Form", "Dire Bear Form") or M.FormIndex("Cat Form"))) then
    for i = #out, 1, -1 do if out[i] == "melee" then table.remove(out, i) end end
  end
  if M.PULL[cls] then
    local has = false
    for _, k in ipairs(out) do if k == "pull" then has = true end end
    if not has and #self:PullLines() > 1 then table.insert(out, 2, "pull") end
  end
  return out
end

-- ------------------------------------------------------------ Pull
-- A Pull key for the classes without one (requirement 2026-11-23: pull with a
-- ranged weapon if there is one, otherwise with a spell).
-- Warriors and rogues have the plan's own Pull; hunters pull with
-- Fight. The spell is the class's ranged opener, the first one known.
M.PULL = {
  DRUID = { "Moonfire", "Wrath" },
  SHAMAN = { "Lightning Bolt", "Earth Shock" },
  PRIEST = { "Shadow Word: Pain", "Smite" },
  MAGE = { "Frostbolt", "Fireball" },
  WARLOCK = { "Immolate", "Shadow Bolt" },
}
local function knows(name) return ns.Spellbook and ns.Spellbook:Known(name) ~= nil end
-- the ranged weapon's own shot, by the item's subclass
M.SHOTS = { Bows = "Shoot Bow", Guns = "Shoot Gun", Crossbows = "Shoot Crossbow", Thrown = "Throw", Wands = "Shoot" }

function M.WeaponShot()
  local link = C.Call("GetInventoryItemLink", "player", 18)
  local info = link and C.ItemInfo(link)
  local shot = info and M.SHOTS[info.subclass or ""]
  if shot and knows(shot) then return shot end
end

-- { {keep, text, why} } for the Pull key
function M:PullLines()
  local L = {}
  local function add(keep, text, why) L[#L + 1] = { keep = keep, text = text, why = why } end
  add(1, "/targetenemy [noharm][dead]", "picks the nearest enemy when you have none")
  local shot = M.WeaponShot()
  if shot then
    add(2, "/cast " .. shot, "pulls with your ranged weapon")
    return L
  end
  for _, sp in ipairs(M.PULL[ns.PlayerClass()] or {}) do
    if knows(sp) then add(2, "/cast " .. sp, "no ranged weapon: pulls with " .. sp) break end
  end
  return L
end
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
M.CASTER = CASTER -- Modules/ClassFight.lua adds the other classes

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
  -- ",null" wraps on Forever: the DoT goes in a sequence of real spells,
  -- last, with the cooldown spells above it (they fall through while cooling)
  if known("Mind Blast") then add(3, "/cast Mind Blast", "whenever it is off cooldown") end
  if known("Holy Fire") then add(4, "/cast Holy Fire", "whenever it is off cooldown") end
  if known("Shadow Word: Pain") and known("Smite") then
    add(2, "/castsequence reset=combat/target Shadow Word: Pain,Smite,Smite,Smite,Smite,Smite", "Shadow Word: Pain, then Smite while it ticks")
  elseif known("Smite") then add(2, "/cast Smite", "filler") end
end

function M:Lines(kind)
  if kind == "pull" and M.PULL[ns.PlayerClass()] then return self:PullLines() end
  local s = self:Settings()
  local L = {}
  local function add(keep, text, why) L[#L + 1] = { keep = keep, text = text, why = why } end
  local cls = ns.PlayerClass()
  -- Class/spec/race/level plans first (Modules/FightPlan.lua, research
  -- 2026-11-18); the hand-built orders below stay as the fallback.
  local FP = ns.FightPlan
  if FP and FP.enabled then
    for _, u in ipairs(FP:Utility()) do
      if u.kind == kind then
        local k = 1
        for l in u.text:gmatch("[^\n]+") do
          if not l:find("^#showtooltip") then add(k, l, u.why) k = k + 1 end
        end
        return L
      end
    end
    if FP:Lines(kind, add) then return L end
    L = {}
  end
  if CASTER[cls] then CASTER[cls](kind, add) return L end
  if cls ~= "HUNTER" then return L end
  -- Pet key (added when the first pet was tamed, 2026-11-12): one button for pet care, out of
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
    -- Requirement 2026-11-16: Strike means melee, so switch to Monkey (Fight
    -- switches back to Hawk). Once per fight: a macro can't see buffs and
    -- "!" on an aspect that is already up still spends the press. Left out
    -- only when Monkey is already up and nothing (no Hawk) will replace it.
    local monkey
    if known("Aspect of the Monkey") and not (M.MonkeyOn() and not known("Aspect of the Hawk")) then
      monkey = true
    end
    if s.wingclip and known("Wing Clip") then
      add(5, "/cast [mod:shift] Wing Clip", "Shift: slows it so you can step back and shoot")
    end
    if known("Raptor Strike") then add(2, "/cast Raptor Strike", "whenever it is off cooldown") end
    -- Requirement 2026-11-17: Immolation Trap. On Forever traps can be set in
    -- combat (Icy Veins, Mobalytics Forever hunter guides); it lands at your
    -- feet, so it belongs in the melee key where the mob stands on it. The
    -- Survival guide puts it between Raptor Strike and Mongoose Bite. On
    -- cooldown the press falls through to the next line.
    if known("Immolation Trap") then add(4, "/cast Immolation Trap", "at your feet while the mob is on you, every time it's ready") end
    if known("Mongoose Bite") then add(4, "/cast Mongoose Bite", "only after the target dodges") end
    -- last: reached only while the strikes cool down (",null" wraps on Forever)
    if monkey then add(3, "/cast [combat] !Aspect of the Monkey", "in melee: Monkey on while the strikes cool down") end
    return L
  end
  if self:Ranged() ~= "bow" then return L end
  -- One sequence per pull: Hunter's Mark, Concussive Shot, then Auto Shot,
  -- then Serpent Sting (requirement 2026-11-12: open with Mark and Concussive, not a
  -- plain arrow). Auto Shot sits inside the sequence so it starts once, right
  -- after Concussive, and is never re-sent ("!Auto Shot" in a castsequence
  -- works and moves on, measured 2026-11-12; re-sending it every press
  -- restarted the shot). A spell on cooldown or the global cooldown holds the
  -- sequence and the press falls through to Arcane Shot.
  -- Aspect of the Hawk before the pull (more ranged damage; Gary learned it,
  -- 2026-11-13). Out of combat only, and "!" never turns it off. Distracting
  -- Shot stays out: it pulls the mob off the pet onto you.
  -- Only while Hawk is off: a macro can't test buffs, so Outrider rewrites
  -- Fight (out of combat) when Hawk turns on or off (bug 2026-11-13: a
  -- press spent on Hawk when it was already on wasted a click).
  if known("Aspect of the Hawk") and not M.HawkOn() then
    add(6, "/cast [nocombat] !Aspect of the Hawk", "before the pull: Hawk on (never turned off)")
  end
  local seq = {}
  if known("Hunter's Mark") then seq[#seq + 1] = "Hunter's Mark" end
  if s.concussive and known("Concussive Shot") then seq[#seq + 1] = "Concussive Shot" end
  if known("Auto Shot") then seq[#seq + 1] = "!Auto Shot" end
  if known("Serpent Sting") then seq[#seq + 1] = "Serpent Sting" end
  -- ",null" wraps on Forever (2026-11-21): the sequence goes on into Arcane
  -- Shot, whose cooldown holds it (the press falls through), and Sting comes
  -- round again about every 15 s; Auto Shot is sent once per loop
  if known("Arcane Shot") then
    seq[#seq + 1] = "Arcane Shot"
    if known("Serpent Sting") then
      seq[#seq + 1] = "Arcane Shot"
      seq[#seq + 1] = "Serpent Sting"
      seq[#seq + 1] = "Arcane Shot"
      seq[#seq + 1] = "Arcane Shot"
    end
  elseif known("Raptor Strike") then
    seq[#seq + 1] = "Raptor Strike" -- out of range the line waits there: Auto Shot isn't sent again
  end
  if #seq > 0 then
    add(2, "/castsequence reset=combat/target " .. table.concat(seq, ","),
      "Mark, Auto Shot, Sting, then Arcane Shot on cooldown, round and round")
  end
  -- Back to Hawk after Strike put Monkey up (requirement 2026-11-16). Last line,
  -- so it is only reached when Arcane Shot is cooling down: a press that
  -- would do nothing else. Hawk already up = that press does nothing.
  if known("Aspect of the Hawk") and known("Aspect of the Monkey") then
    add(7, "/cast [combat] !Aspect of the Hawk", "in a fight, back to Hawk when Arcane Shot is cooling down")
  end
  return L
end

-- Body text; drops the lowest-priority lines until it fits. Returns body, dropped lines.
function M:Body(kind)
  local lines = self:Lines(kind or "ranged")
  -- Alt on the Heal key: the best mana potion in your bags (Modules/ManaCare.lua;
  -- a macro can't see mana, so you press it when the low mana cue says so)
  local MC = ns.ManaCare
  local potion = kind == "heal" and #lines > 0 and MC and MC:Potion()
  if potion then
    -- after the class's own Alt line (Innervate, Inner Focus): that one first,
    -- the potion when it is cooling down
    local at = 1
    for i, l in ipairs(lines) do if l.text:find("mod:alt", 1, true) or l.text == "/cancelform" then at = i + 1 end end
    table.insert(lines, at, { keep = 3, text = "/use [mod:alt] " .. potion, why = "Alt: drink " .. potion .. " (when the low mana cue shows)" })
  end
  -- Every fight key swings too (bug 2026-11-23: after a pull the mob walked
  -- up and needed a second click to start auto attack). Not where a shot
  -- repeats (Auto Shot, a wand's Shoot, Throw): starting melee would stop it.
  local fighting, shoots, swings, at = false, false, false, nil
  for i, l in ipairs(lines) do
    if l.text:find("^/targetenemy") then fighting, at = true, at or i end
    if l.text:find("^/startattack") then swings = true end
    if l.text:find("Auto Shot", 1, true) or l.text:find("Shoot", 1, true) or l.text:find("Throw", 1, true) then shoots = true end
  end
  -- (warriors' and rogues' strikes start it themselves; hunters shoot)
  if fighting and not shoots and not swings and M.PULL[ns.PlayerClass()] then
    table.insert(lines, at + 1, { keep = 1, text = "/startattack", why = "starts your auto attack, so you swing when it reaches you" })
  end
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

local EXPLAIN = {}
M.EXPLAIN = EXPLAIN
for k, v in pairs({
  MAGE = { ranged = "Ranged key: spam it. Frostbolt (or Fireball before you learn it).",
    melee = "Close key: when it reaches you. Frost Nova, Fire Blast, then Arcane Explosion." },
  PRIEST = { ranged = "Damage key: spam it. Shadow Word: Pain once, Mind Blast on cooldown, Smite between.",
    heal = "Heal key: heals who you point at, your friendly target, or you." },
}) do EXPLAIN[k] = v end

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
  if kind == "pull" and M.PULL[cls] then
    return { id = cls:lower() .. "-pull", name = s.pullName or "Pull", class = cls, body = body, scope = "char",
      tags = { "combat" }, dynamic = true, empty = M.Spells(self:PullLines()) == 0,
      explain = "Pull key: press it once to start the fight from range: your ranged weapon if you have one, otherwise a spell. Then use Fight." }
  end
  -- keys the plan added (Pull, Reach, Trap, Burst, Break, Recover...) carry its names
  local FP = ns.FightPlan
  if FP and FP.enabled and not (kind == "ranged" or kind == "heal" or kind == "pet" or (kind == "melee" and M.CLASS_KINDS[cls] and
    (function() for _, k in ipairs(M.CLASS_KINDS[cls]) do if k == "melee" then return true end end end)())) then
    local name = FP:Name(kind)
    for _, u in ipairs(FP:Utility()) do if u.kind == kind then name = u.name end end
    if kind == "melee" then name = s.meleeName end
    if name then
      return { id = cls:lower() .. "-" .. kind, name = name, class = cls, body = body, scope = "char",
        tags = { "combat" }, dynamic = true, empty = M.Spells(self:Lines(kind)) == 0,
        explain = "From the fight plan for your class, spec and race. Outrider rewrites it when you learn a spell." }
    end
  end
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
      -- Strike also comes along once Fight is ours (both requested, 2026-11-12).
      local wanted = not entry.empty and (installed[entry.name] or why == "command" or (kind ~= "ranged" and installed[self:Settings().name]))
      if wanted and lib:State(entry) ~= "installed" then
        local ok, msg = lib:Install(entry)
        if ok then
          made[#made + 1] = entry.name
          self:Info("%s macro written (%s): %d chars, %d lines", entry.name, tostring(why), #entry.body,
            select(2, entry.body:gsub("\n", "")))
          self:Debug("%s macro text: %s", entry.name, (entry.body:gsub("\n", " | ")))
          if kind == "ranged" and ns.PlayerClass() == "SHAMAN" and M.TotemState then self:Info("totems: %s", M.TotemState()) end
        else
          -- once per macro per session (it repeated after every fight)
          self.warned = self.warned or {}
          if not self.warned[entry.name] then
            self.warned[entry.name] = true
            self:Warn("%s macro not written: %s", entry.name, tostring(msg))
          end
        end
      end
    end
    if why == "command" and #made > 0 then
      ns.Print("macros %s ready: open the macro window (/macro), Character tab, and drag them to your bar",
        table.concat(made, " and "))
    elseif #made > 0 and not self.toldRewrite then
      -- Feedback 2026-11-19: a silent rewrite at level-up looked like nothing
      -- happened. One line per session (rule 6); the macro on your bar is the
      -- same slot, only its text changed.
      self.toldRewrite = true
      ns.Print("%s updated for your new spells (same button on your bar; Macros page shows each line)",
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
  -- out of combat a cast may have put on a buff, imbue or totem: look again
  -- once the game has applied it (OnEnable's watch)
  if M.watchNow and not C.InCombat() then ns.Timer.After(0.6, function() M.watchNow(M) end, "hunterfight:watch") end
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
  -- probe (2026-11-22): what Forever says to a spell pressed in Ghost Wolf,
  -- so the shaman keys can be made to fit (once per kind of message)
  if type(msg) == "string" and ns.PlayerClass() == "SHAMAN" and M.AuraOn("Ghost Wolf") then
    M.wolfSeen = M.wolfSeen or {}
    if not M.wolfSeen[msg] then M.wolfSeen[msg] = true M:Info("ghost wolf probe: a press in Ghost Wolf got '%s'", msg) end
  end
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
  self:ShotOverlay()
  -- One time: Wing Clip turned back on by request (2026-11-12). After this,
  -- /ride fight wingclip on|off is the player's to change again.
  local s = self:Settings()
  if not s.wingclipOn20261112 then s.wingclipOn20261112, s.wingclip = true, true end
  -- One time: guide order (chosen 2026-11-13): Hawk, Mark, Auto Shot,
  -- Serpent, Arcane; Concussive leaves the spam key (the Class page toggle
  -- brings it back).
  if not s.guideOrder20261113 then s.guideOrder20261113, s.concussive = true, false end
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
  -- Hawk or Monkey on or off changes Fight and Strike: rewrite when one flips (out of combat)
  local function watch(mod)
    if not mod:Settings().auto then return end
    local on = M.WatchState()
    if on == "" then return end
    if on ~= mod.aspectWas then
      mod.aspectWas = on
      if ns.PlayerClass() == "SHAMAN" and M.TotemState then mod:Info("buffs %s; totems: %s", on, M.TotemState()) end
      later(on)
    end
  end
  self:On("UNIT_AURA", function(mod, _, unit) if unit == "player" then watch(mod) end end)
  -- shaman totems down or gone (ClassFight.lua's pre-pull totem lines)
  self:On("PLAYER_TOTEM_UPDATE", function(mod) if ns.PlayerClass() == "SHAMAN" then watch(mod) end end)
  -- a weapon imbue is no aura: UNIT_AURA never fires for it, so Rockbiter was
  -- recast every press before the pull (Gary's shaman, 2026-11-25). The weapon
  -- slot changes, and every cast of your own out of combat is checked once
  -- the game has applied it.
  self:On("UNIT_INVENTORY_CHANGED", function(mod, _, unit) if unit == "player" then watch(mod) end end)
  M.watchNow = watch
  self:On("PLAYER_EQUIPMENT_CHANGED", function(mod, _, slot)
    if (slot == 18 or slot == 16) and mod:Settings().auto then later(slot == 18 and "ranged weapon" or "main hand") end
  end)
  -- druid forms: the macro names forms by their number on the stance bar
  self:On("UPDATE_SHAPESHIFT_FORMS", function(mod) if mod:Settings().auto and ns.PlayerClass() == "DRUID" then later("forms") end end)
  self:On("PLAYER_REGEN_DISABLED", self.OnCombatStart)
  self:On("UNIT_SPELLCAST_SUCCEEDED", self.OnCast)
  self:On("PLAYER_REGEN_ENABLED", self.OnCombatEnd)
  self:On("UNIT_SPELLCAST_FAILED", self.OnFailed)
  self:On("UI_ERROR_MESSAGE", self.OnUIError)
  self:On("PLAYER_LOGOUT", self.OnLogout)
end

function M:OnDisable() ns.ThrottleCancel("hunterfight") end

-- DEEP-16: a read-only overlay by the client's own ranged swing timer.
-- The game retains all swing timing and Edit Mode layout ownership.
function M:ShotReadiness()
  if ns.PlayerClass() ~= "HUNTER" then return nil end
  local get = C.Resolve("UnitRangedDamage")
  if type(get) ~= "function" then return { known = false } end
  local ok, speed = pcall(get, "player")
  speed = ok and tonumber(C.Readable(speed)) or nil
  if not speed or speed <= 0 then return { known = false } end
  local moving = C.Readable(C.Call("GetUnitSpeed", "player"))
  local enemy = C.Readable(C.Call("UnitExists", "target"))
  local inRange
  local check = C.Resolve("C_Spell.IsSpellInRange")
  local spell = ns.Spellbook and ns.Spellbook:Known("Auto Shot")
  if enemy and spell and spell.id and type(check) == "function" then
    local success, r = pcall(check, spell.id, "target")
    r = success and C.Readable(r)
    if type(r) == "boolean" then inRange = r end
  end
  return { known = true, speed = speed, moving = type(moving) == "number" and moving > 0 or false,
    inRange = inRange }
end

function M:ShotOverlay()
  local bar = rawget(_G, "SwingTimerRanged")
  if not (bar and self:Supported() and ns.PlayerClass() == "HUNTER") then return nil end
  if self.shotOverlay then return self.shotOverlay end
  local frame = CreateFrame("Frame", nil, bar)
  frame:SetPoint("BOTTOM", bar, "TOP", 0, 3)
  frame:SetSize(190, 18)
  local text = ns.UI.Text(frame, "small", "warn")
  text:SetPoint("CENTER")
  frame.label = text
  self.shotOverlay = frame
  frame:SetScript("OnUpdate", function(_, dt)
    M.shotElapsed = (M.shotElapsed or 0) + (dt or 0)
    if M.shotElapsed >= 0.25 then M.shotElapsed = 0 M:UpdateShotOverlay() end
  end)
  return frame
end

function M:UpdateShotOverlay()
  local status = self:ShotReadiness()
  local frame = self:ShotOverlay()
  if not frame then return end
  if not self:Settings().shotHints or not status or not status.known then frame.label:SetText("") return end
  -- Only mid-fight with an enemy targeted; walking around town says nothing.
  if not C.InCombat() or not C.Readable(C.Call("UnitCanAttack", "player", "target")) then frame.label:SetText("") return end
  local hints = {}
  if status.moving then hints[#hints + 1] = "Stop moving for Auto Shot" end
  if status.inRange == false then hints[#hints + 1] = "Target out of Auto Shot range" end
  frame.label:SetText(table.concat(hints, " | "))
end

function M:Activity()
  local parts = {}
  for _, k in ipairs(self:Kinds()) do
    local e = self:Entry(k)
    if not e.empty then parts[#parts + 1] = string.format("%s %d chars", e.name, #e.body) end
  end
  return #parts > 0 and table.concat(parts, ", ") or "no spells for these keys yet"
end

local OPTIONS = { concussive = true, wingclip = true, pet = true, auto = true }
ns.AddCommand("fight", "[concussive|wingclip|pet|auto on|off]  make, show or change your class's Fight macros (every class)", function(arg)
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

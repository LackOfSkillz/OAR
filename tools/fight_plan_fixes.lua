-- tools/fight_plan_fixes.lua  (2026-11-22)
-- Applied by tools/build_fight_plans.lua to the research catalog before it is
-- written to Data/FightPlans.lua. The draft (docs/fight_macro_catalog_draft.lua)
-- stays as the 2026-11-18 research; these are the fixes measured or found since:
--
--  1. ",null" does not hold on Forever (FOREVER_CONSTRAINTS, Gul's paladin
--     2026-11-21): a "/castsequence X,null" recasts X on every press. Every
--     such line becomes
--       * a DoT sequence padded with the filler, sized to the DoT
--         (Shadow Word: Pain + 5 Smites, Bane,Corruption,Immolate + 4 Shadow
--         Bolts...). It never parks, so it goes LAST and cooldown spells sit
--         above it (they fall through while cooling down);
--       * the hunter loop Mark, Auto Shot, Sting, Arcane x2, Sting, Arcane x2,
--         which parks on Arcane Shot's cooldown (never re-sends Auto Shot);
--       * a modifier line for once-in-a-while spells (Battle Shout on Alt,
--         totems and Power Word: Shield on Ctrl, Wing Clip and Hamstring on Shift);
--       * a pre-pull line for the paladin's first Seal.
--  2. The wand as a spam filler ("/cast !Shoot") moves to Shift: pressing it
--     again restarts the wand like !Auto Shot did (C16b), and a wand finish is
--     the player's call when mana runs low.
--  3. Lava Burst was removed from Forever (Nov 3 notes, foreverchanges.pro).
--  4. The Heal keys of druid, priest, paladin and shaman are rebuilt for the
--     most healing per second with sane mana (research 2026-11-22, scratchpad
--     macro_research.md; copied into docs/HEAL_MACRO_RESEARCH_2026-11-22.md):
--     a HoT then the efficient heal in one sequence sized to the HoT, the fast
--     heal on Ctrl, the emergency combo on Shift, the class mana cooldown on
--     Alt (Outrider adds the best mana potion after it, Modules/ManaCare.lua).
-- Everything stays verified = false until the fight logs agree.

local PAD = { Smite = 5, ["Shadow Bolt"] = 4, ["Mind Flay"] = 3, ["Drain Life"] = 4, ["Lightning Bolt"] = 4,
  ["Heroic Strike"] = 5, Wrath = 3, Fireball = 3, Frostbolt = 3 }
local DEFAULT_PAD = { PRIEST = "Smite", WARLOCK = "Shadow Bolt", SHAMAN = "Lightning Bolt", WARRIOR = "Heroic Strike" }

local function copy(t)
  local o = {}
  for k, v in pairs(t) do o[k] = type(v) == "table" and copy(v) or v end
  return o
end

-- strings ("same line as before") to full slots, per key list
local function resolve(list)
  local by, out = {}, {}
  for _, b in ipairs(list) do
    local s = {}
    for _, sl in ipairs(b.slots) do
      if type(sl) == "table" then by[sl.line] = sl s[#s + 1] = copy(sl)
      elseif by[sl] then s[#s + 1] = copy(by[sl]) end
    end
    out[#out + 1] = { from = b.from, slots = s }
  end
  return out
end

local function uniq(list)
  local seen, out = {}, {}
  for _, n in ipairs(list) do if not seen[n] then seen[n] = true out[#out + 1] = n end end
  return out
end

local function modsUsed(slots)
  local used = {}
  for _, sl in ipairs(slots) do
    for m in sl.line:gmatch("mod:(%a+)") do used[m] = true end
    if sl.line:find("%[mod[%],]") then used.shift, used.ctrl, used.alt = true, true, true end
  end
  return used
end
local function freeMod(slots, prefs)
  local used = modsUsed(slots)
  for _, m in ipairs(prefs) do if not used[m] then return m end end
end

-- "/castsequence [c] reset=x A,B,null" -> cond, reset, { A, B }
local function parseNull(line)
  local rest = line:match("^/castsequence%s+(.+),null$")
  if not rest then return nil end
  local cond = rest:match("^(%b[])") or ""
  rest = rest:sub(#cond + 1):match("^%s*(.-)$")
  local reset, list = rest:match("^reset=(%S+)%s+(.+)$")
  if not list then return nil end
  local spells = {}
  for n in list:gmatch("[^,]+") do spells[#spells + 1] = n end
  return cond, reset, spells
end

local function plainSpell(line)
  local sp = line:match("^/cast%s+([^%[;][^;]*)$")
  return sp and sp:match("^%s*(.-)%s*$")
end

local function fixBracket(cls, key, b)
  local slots = b.slots
  -- 3. Lava Burst is gone: the opener pulls with Lightning Bolt, the cooldown line goes
  local keep = {}
  local hasBoltOpener = false
  for _, sl in ipairs(slots) do if sl.line == "/cast [nocombat] Lightning Bolt" then hasBoltOpener = true end end
  for _, sl in ipairs(slots) do
    if sl.line:find("Lava Burst", 1, true) then
      if sl.line == "/cast [nocombat] Lava Burst" and not hasBoltOpener then
        sl.line, sl.spells, sl.why = "/cast [nocombat] Lightning Bolt", { "Lightning Bolt" }, "pulls from range (Lava Burst was removed on Forever)"
        keep[#keep + 1] = sl
      end
    else keep[#keep + 1] = sl end
  end
  slots = keep
  -- 2. the wand moves to Shift, near the top
  local wandAt
  for i, sl in ipairs(slots) do if sl.line == "/cast !Shoot" then wandAt = i end end
  local hasShiftWand = false
  for _, sl in ipairs(slots) do if sl.line == "/cast [mod:shift] !Shoot" then hasShiftWand = true end end
  if wandAt then
    local w = table.remove(slots, wandAt)
    if not hasShiftWand and freeMod(slots, { "shift" }) then
      w.line, w.kind, w.keep, w.why = "/cast [mod:shift] !Shoot", "utility", 3, "Shift: the wand (when mana runs low)"
      local at = 1
      while slots[at] and (slots[at].kind == "target" or slots[at].kind == "guard" or slots[at].kind == "control") do at = at + 1 end
      table.insert(slots, at, w)
    end
  end
  -- the damage filler for padding sequences
  local pad, padAt
  for i, sl in ipairs(slots) do
    local sp = sl.kind == "filler" and plainSpell(sl.line)
    if sp and PAD[sp] then pad, padAt = sp, i end
  end
  pad = pad or DEFAULT_PAD[cls]
  -- 1. every ",null" line
  local out, last = {}, {}
  local hasArcane = false
  for _, sl in ipairs(slots) do if sl.line == "/cast Arcane Shot" then hasArcane = true end end
  local seqMade
  for _, sl in ipairs(slots) do
    local cond, reset, spells = parseNull(sl.line)
    if not spells then
      out[#out + 1] = sl
    elseif cls == "HUNTER" and key == "ranged" then
      local s = {}
      for _, n in ipairs(spells) do s[#s + 1] = n end
      local sting = false
      for _, n in ipairs(spells) do if n == "Serpent Sting" then sting = true end end
      if hasArcane then
        s[#s + 1] = "Arcane Shot"
        if sting then
          s[#s + 1] = "Arcane Shot"
          s[#s + 1] = "Serpent Sting"
          for _, n in ipairs({ "Arcane Shot", "Arcane Shot" }) do s[#s + 1] = n end
        end
        sl.why = "Mark, Auto Shot, Sting, then Arcane Shot on cooldown (the line waits on it, the press goes on): Sting again about every 15 s"
      else
        s[#s + 1] = "Raptor Strike"
        sl.why = "Auto Shot once, Sting, then Raptor Strike when it reaches you (out of range the line waits, Auto Shot isn't sent again)"
      end
      sl.line = "/castsequence " .. cond .. (cond ~= "" and " " or "") .. "reset=" .. reset .. " " .. table.concat(s, ",")
      sl.spells, sl.kind = uniq(s), "once"
      out[#out + 1] = sl
      seqMade = true
    elseif reset:find("target", 1, true) and (spells[#spells] == "Shadow Word: Pain" or spells[1] == "Shadow Word: Pain"
        or cls == "WARLOCK" or spells[1] == "Flame Shock" or spells[#spells] == "Rend") then
      -- a DoT sequence: pad with the filler, put it last
      local s = {}
      for _, n in ipairs(spells) do s[#s + 1] = n end
      local earthShock = false
      for _, x in ipairs(slots) do if x.line == "/cast Earth Shock" then earthShock = true end end
      if cls == "SHAMAN" and key == "melee" and earthShock and not (padAt and pad == "Lightning Bolt") then
        -- enhancement: the shocks share a cooldown, so Flame Shock, Earth Shock alternate and park
        sl.line = "/castsequence " .. cond .. (cond ~= "" and " " or "") .. "reset=" .. reset .. " Flame Shock,Earth Shock"
        sl.spells, sl.kind, sl.why = { "Flame Shock", "Earth Shock" }, "cooldown", "Flame Shock, then Earth Shock on the shared shock cooldown, round and round"
        out[#out + 1] = sl
      else
        local p = (cls == "WARRIOR") and "Heroic Strike" or pad
        if spells[1] == "Demoralizing Shout" then
          table.remove(s, 1)
          local m = freeMod(slots, { "ctrl", "alt" })
          if m then out[#out + 1] = { line = "/cast [mod:" .. m .. "] Demoralizing Shout", spells = { "Demoralizing Shout" }, kind = "utility", keep = 5,
            why = (m == "ctrl" and "Ctrl" or "Alt") .. ": Demoralizing Shout (they hit softer)" } end
        end
        if spells[1] == "Vampiric Embrace" then
          s = { "Vampiric Embrace", "Shadow Word: Pain", p, p, p, "Shadow Word: Pain", p }
        else
          for _ = 1, PAD[p] or 4 do s[#s + 1] = p end
        end
        sl.line = "/castsequence " .. cond .. (cond ~= "" and " " or "") .. "reset=" .. reset .. " " .. table.concat(s, ",")
        sl.spells, sl.kind, sl.keep = uniq(s), "filler", 2
        sl.why = table.concat(uniq(spells), ", ") .. ", then " .. p .. " while it ticks; again on a new target"
        last[#last + 1] = sl
        seqMade = true
      end
    else
      -- once-in-a-while spells
      local n = spells[1]
      local name = n:gsub("^!", "")
      if name == "Battle Shout" then
        local m = freeMod(slots, { "alt", "ctrl" })
        if m then sl.line, sl.kind, sl.keep, sl.why = "/cast [mod:" .. m .. "] Battle Shout", "utility", 5, (m == "alt" and "Alt" or "Ctrl") .. ": Battle Shout (3 minutes)" out[#out + 1] = sl end
      elseif name == "Searing Totem" or name == "Call of the Elements" then
        local m = freeMod(slots, { "ctrl", "alt" })
        if m then sl.line, sl.kind, sl.keep, sl.why = "/cast [mod:" .. m .. "] " .. name, "utility", 5, (m == "ctrl" and "Ctrl" or "Alt") .. ": " .. name out[#out + 1] = sl end
      elseif name == "Power Word: Shield" then
        local m = freeMod(slots, { "ctrl", "alt" })
        if m then sl.line, sl.kind, sl.keep, sl.why = "/cast [mod:" .. m .. ",@player] Power Word: Shield", "utility", 4, (m == "ctrl" and "Ctrl" or "Alt") .. ": shield yourself" out[#out + 1] = sl end
      elseif name == "Wing Clip" or name == "Hamstring" then
        local m = freeMod(slots, { "shift", "ctrl" })
        if m then sl.line, sl.kind, sl.keep, sl.why = "/cast [mod:" .. m .. "] " .. name, "utility", 5, (m == "shift" and "Shift" or "Ctrl") .. ": " .. name .. " (slows it)" out[#out + 1] = sl end
      elseif name == "Aspect of the Monkey" then
        sl.line, sl.kind, sl.keep, sl.why = "/cast [combat] !Aspect of the Monkey", "control", 6, "in melee, Monkey on when the strikes are cooling down"
        last[#last + 1] = sl
      elseif name:find("^Seal of") then
        sl.line, sl.kind, sl.keep, sl.why = "/cast [nocombat] " .. name, "buff", 3, "Seal before the pull (it lasts 30 s)"
        out[#out + 1] = sl
      else
        error("fight_plan_fixes: no rule for " .. sl.line)
      end
    end
  end
  -- the padded sequence replaces the plain filler it pads with
  if seqMade and padAt then
    local p = slots[padAt]
    for i = #out, 1, -1 do if out[i] == p then table.remove(out, i) end end
  end
  if cls == "HUNTER" and seqMade then
    for i = #out, 1, -1 do if out[i].line == "/cast Arcane Shot" then table.remove(out, i) end end
  end
  for _, sl in ipairs(last) do out[#out + 1] = sl end
  b.slots = out
end

-- 4. Heal keys. U = who you point at (mouseover), else your friendly target or you.
local U = "[@mouseover,help,nodead][]"
local function S(line, spells, kind, keep, why) return { line = line, spells = spells, kind = kind, keep = keep, why = why } end
local CANCEL = S("/cancelform", {}, "control", 1, "out of a form first: no heal works in one")

local HEAL = {}
HEAL.DRUID = {
  { from = 1, slots = { CANCEL, S("/cast " .. U .. " Healing Touch", { "Healing Touch" }, "heal", 1, "heals who you point at, your friendly target, or you") } },
  { from = 4, slots = { CANCEL,
    S("/castsequence " .. U .. " reset=target Rejuvenation,Healing Touch,Healing Touch,Healing Touch,Healing Touch", { "Rejuvenation", "Healing Touch" }, "heal", 1,
      "Rejuvenation (12 s), then Healing Touch while it ticks; Rejuvenation comes round as it runs out") } },
  { from = 12, slots = { CANCEL,
    S("/cast [mod:ctrl] Healing Touch", { "Healing Touch" }, "heal", 3, "Ctrl: one big Healing Touch"),
    S("/castsequence " .. U .. " reset=target Rejuvenation,Regrowth,Regrowth,Healing Touch", { "Rejuvenation", "Regrowth", "Healing Touch" }, "heal", 1,
      "Rejuvenation, Regrowth twice (the most healing per mana on Forever), Healing Touch; about 10 s, as long as Rejuvenation") } },
  { from = 25, slots = { CANCEL,
    S("/cast [mod:shift] Nature's Swiftness", { "Nature's Swiftness" }, "cooldown", 3, "Shift: Nature's Swiftness, then an instant Healing Touch"),
    S("/cast [mod:shift/ctrl] Healing Touch", { "Healing Touch" }, "heal", 3, "Shift or Ctrl: Healing Touch"),
    S("/castsequence " .. U .. " reset=target Rejuvenation,Regrowth,Swiftmend,Healing Touch", { "Rejuvenation", "Regrowth", "Swiftmend", "Healing Touch" }, "heal", 1,
      "Rejuvenation, Regrowth, Swiftmend (it doesn't use up the HoTs on Forever; waits on its 15 s cooldown), Healing Touch") } },
  { from = 40, slots = { CANCEL,
    S("/cast [mod:alt,@player] Innervate", { "Innervate" }, "cooldown", 2, "Alt: Innervate on yourself (6 minutes), then the mana potion"),
    S("/cast [mod:ctrl] Healing Touch", { "Healing Touch" }, "heal", 3, "Ctrl: one big Healing Touch"),
    S("/castsequence " .. U .. " reset=target Rejuvenation,Regrowth,Regrowth,Healing Touch", { "Rejuvenation", "Regrowth", "Healing Touch" }, "heal", 1,
      "Rejuvenation, Regrowth twice, Healing Touch") } },
  { from = 40, slots = { CANCEL,
    S("/cast [mod:alt,@player] Innervate", { "Innervate" }, "cooldown", 2, "Alt: Innervate on yourself (6 minutes), then the mana potion"),
    S("/cast [mod:shift] Nature's Swiftness", { "Nature's Swiftness" }, "cooldown", 3, "Shift: Nature's Swiftness, then an instant Healing Touch"),
    S("/cast [mod:shift/ctrl] Healing Touch", { "Healing Touch" }, "heal", 3, "Shift or Ctrl: Healing Touch"),
    S("/castsequence " .. U .. " reset=target Rejuvenation,Regrowth,Swiftmend,Healing Touch", { "Rejuvenation", "Regrowth", "Swiftmend", "Healing Touch" }, "heal", 1,
      "Rejuvenation, Regrowth, Swiftmend, Healing Touch") } },
  { from = 40, slots = { CANCEL,
    S("/cast [mod:alt,@player] Innervate", { "Innervate" }, "cooldown", 2, "Alt: Innervate on yourself (6 minutes), then the mana potion"),
    S("/cast [mod:shift] Nature's Swiftness", { "Nature's Swiftness" }, "cooldown", 3, "Shift: Nature's Swiftness, then an instant Healing Touch"),
    S("/cast [mod:shift] Healing Touch;[mod:ctrl] Wild Growth", { "Healing Touch", "Wild Growth" }, "heal", 3, "Shift: Healing Touch; Ctrl: Wild Growth (the party)"),
    S("/castsequence " .. U .. " reset=target Rejuvenation,Regrowth,Swiftmend,Healing Touch", { "Rejuvenation", "Regrowth", "Swiftmend", "Healing Touch" }, "heal", 1,
      "Rejuvenation, Regrowth, Swiftmend, Healing Touch") } },
}
local SHIELD = "[mod:shift] Power Word: Shield"
HEAL.PRIEST = {
  { from = 1, slots = { S("/cast " .. U .. " Lesser Heal", { "Lesser Heal" }, "heal", 1, "heals who you point at, your friendly target, or you") } },
  { from = 6, slots = { S("/cast " .. SHIELD .. ";" .. U .. " Lesser Heal", { "Power Word: Shield", "Lesser Heal" }, "heal", 1, "Shift: Power Word: Shield; plain: Lesser Heal") } },
  { from = 8, slots = { S("/cast " .. SHIELD, { "Power Word: Shield" }, "cooldown", 3, "Shift: Power Word: Shield"),
    S("/castsequence " .. U .. " reset=target Renew,Lesser Heal,Lesser Heal,Lesser Heal,Lesser Heal", { "Renew", "Lesser Heal" }, "heal", 1,
      "Renew (15 s), then Lesser Heal while it ticks") } },
  { from = 16, slots = { CANCEL, S("/cast " .. SHIELD, { "Power Word: Shield" }, "cooldown", 3, "Shift: Power Word: Shield"),
    S("/castsequence " .. U .. " reset=target Renew,Heal,Heal,Heal,Heal", { "Renew", "Heal" }, "heal", 1, "Renew, then Heal while it ticks (about 13 s against Renew's 15)") } },
  { from = 20, slots = { CANCEL, S("/cast " .. SHIELD .. ";[mod:ctrl] Flash Heal", { "Power Word: Shield", "Flash Heal" }, "cooldown", 3, "Shift: shield; Ctrl: Flash Heal when it must land now"),
    S("/castsequence " .. U .. " reset=target Renew,Heal,Heal,Heal,Heal", { "Renew", "Heal" }, "heal", 1, "Renew, then Heal while it ticks") } },
  { from = 30, slots = { S("/stopmacro [channeling]", {}, "guard", 1, "doesn't cut Penance short"),
    S("/cast " .. SHIELD .. ";[mod:ctrl] Flash Heal", { "Power Word: Shield", "Flash Heal" }, "cooldown", 3, "Shift: shield; Ctrl: Flash Heal"),
    S("/cast " .. U .. " Penance", { "Penance" }, "cooldown", 2, "Penance whenever it is off cooldown"),
    S("/castsequence " .. U .. " reset=target Renew,Heal,Heal,Heal,Heal", { "Renew", "Heal" }, "heal", 1, "Renew, then Heal while it ticks") } },
  { from = 40, slots = { CANCEL, S("/cast " .. SHIELD .. ";[mod:ctrl] Flash Heal", { "Power Word: Shield", "Flash Heal" }, "cooldown", 3, "Shift: shield; Ctrl: Flash Heal"),
    S("/castsequence " .. U .. " reset=target Renew,Greater Heal,Greater Heal,Greater Heal,Greater Heal", { "Renew", "Greater Heal" }, "heal", 1,
      "Renew, then Greater Heal (the most healing per mana)") } },
  { from = 40, slots = { S("/stopmacro [channeling]", {}, "guard", 1, "doesn't cut Penance short"),
    S("/cast " .. SHIELD .. ";[mod:ctrl] Flash Heal", { "Power Word: Shield", "Flash Heal" }, "cooldown", 3, "Shift: shield; Ctrl: Flash Heal"),
    S("/cast " .. U .. " Penance", { "Penance" }, "cooldown", 2, "Penance whenever it is off cooldown"),
    S("/castsequence " .. U .. " reset=target Renew,Greater Heal,Greater Heal,Greater Heal,Greater Heal", { "Renew", "Greater Heal" }, "heal", 1, "Renew, then Greater Heal") } },
  { from = 40, slots = { CANCEL, S("/cast [mod:alt] Inner Focus", { "Inner Focus" }, "cooldown", 2, "Alt: Inner Focus (the next heal is free), then the mana potion"),
    S("/cast " .. SHIELD .. ";[mod:ctrl] Flash Heal", { "Power Word: Shield", "Flash Heal" }, "cooldown", 3, "Shift: shield; Ctrl: Flash Heal"),
    S("/castsequence " .. U .. " reset=target Renew,Greater Heal,Flash Heal,Greater Heal,Greater Heal", { "Renew", "Greater Heal", "Flash Heal" }, "heal", 1,
      "Renew, Greater Heal, Flash Heal, two Greater Heals: mixed heals for Litany of Light, about 12 s") } },
}
HEAL.PALADIN = {
  { from = 1, slots = { S("/cast " .. U .. " Holy Light", { "Holy Light" }, "heal", 1, "Holy Light: the most healing per second and per mana") } },
  { from = 20, slots = { S("/cast [mod:ctrl] Flash of Light;" .. U .. " Holy Light", { "Flash of Light", "Holy Light" }, "heal", 1, "Plain: Holy Light; Ctrl: Flash of Light when little is missing") } },
  { from = 30, slots = { S("/cast [mod:shift] Divine Favor", { "Divine Favor" }, "cooldown", 3, "Shift: Divine Favor, then Holy Shock (a sure crit)"),
    S("/cast [mod:shift] Holy Shock;[mod:ctrl] Flash of Light;" .. U .. " Holy Light", { "Holy Shock", "Flash of Light", "Holy Light" }, "heal", 1,
      "Shift: Holy Shock; Ctrl: Flash of Light; plain: Holy Light") } },
}
HEAL.SHAMAN = {
  { from = 1, slots = { S("/cast " .. U .. " Healing Wave", { "Healing Wave" }, "heal", 1, "Healing Wave: the efficient heal") } },
  { from = 20, slots = { S("/cast [mod:ctrl] Lesser Healing Wave;" .. U .. " Healing Wave", { "Lesser Healing Wave", "Healing Wave" }, "heal", 1, "Plain: Healing Wave; Ctrl: Lesser Healing Wave when it must land fast") } },
  { from = 20, slots = { S("/cast [mod:shift] Nature's Swiftness", { "Nature's Swiftness" }, "cooldown", 3, "Shift: Nature's Swiftness, then an instant Healing Wave"),
    S("/cast [mod:shift] Healing Wave;[mod:ctrl] Lesser Healing Wave;" .. U .. " Healing Wave", { "Lesser Healing Wave", "Healing Wave" }, "heal", 1,
      "Shift: Healing Wave; Ctrl: Lesser Healing Wave; plain: Healing Wave") } },
  { from = 40, slots = { S("/cast [mod:shift] Nature's Swiftness", { "Nature's Swiftness" }, "cooldown", 3, "Shift: Nature's Swiftness, then an instant Healing Wave"),
    S("/cast [mod:shift] Healing Wave;[mod:ctrl] Chain Heal", { "Healing Wave", "Chain Heal" }, "heal", 3, "Shift: Healing Wave; Ctrl: Chain Heal"),
    S("/castsequence " .. U .. " reset=target Riptide,Healing Wave,Healing Wave,Healing Wave,Lesser Healing Wave", { "Riptide", "Healing Wave", "Lesser Healing Wave" }, "heal", 1,
      "Riptide, three Healing Waves, Lesser Healing Wave: 12 s, as long as Riptide's cooldown") } },
}

-- later identical slots back to "same line as before" strings
local function compress(list)
  local seen = {}
  for _, b in ipairs(list) do
    for i, sl in ipairs(b.slots) do
      local key = sl.line
      local prev = seen[key]
      if prev and prev.kind == sl.kind and prev.keep == sl.keep and prev.why == sl.why and table.concat(prev.spells or {}, "|") == table.concat(sl.spells or {}, "|") then
        b.slots[i] = key
      else
        seen[key] = sl
      end
    end
  end
  return list
end

-- 5. Gated spells (2026-11-22, Gary: "the hunter macro knows when the target
-- dodged"): the game itself refuses Mongoose Bite, Overpower, Execute... until
-- their moment, so they sit where a refusal costs nothing (last line). Added:
--   * paladin Hammer of Wrath (44, target under 20%): last line of Fight;
--   * warlock Shadowburn is NOT gated (it fires whenever it's ready and spends
--     a Soul Shard), so it moves from a plain line to Alt: your finisher call.
local function gated(cls, key, list)
  if cls == "PALADIN" and key == "melee" then
    -- on every bracket with no required spells: the builder leaves a /cast
    -- line out until the spell is learned, so it simply appears at 44
    for _, b in ipairs(list) do
      b.slots[#b.slots + 1] = S("/cast Hammer of Wrath", {}, "reactive", 4,
        "target under 20% health: the game only lets it fire then, so it sits last")
    end
  end
  if cls == "WARLOCK" then
    for _, b in ipairs(list) do
      for _, sl in ipairs(b.slots) do
        if sl.line == "/cast Shadowburn" then
          local m = freeMod(b.slots, { "alt", "ctrl", "shift" })
          if m then
            sl.line, sl.kind, sl.why = "/cast [mod:" .. m .. "] Shadowburn", "utility",
              (m == "alt" and "Alt" or m == "ctrl" and "Ctrl" or "Shift") .. ": Shadowburn to finish it (uses a Soul Shard)"
          else sl.line = nil end
        end
      end
      local keep = {}
      for _, sl in ipairs(b.slots) do if sl.line then keep[#keep + 1] = sl end end
      b.slots = keep
    end
  end
end

return function(catalog)
  local n = 0
  for cls, c in pairs(catalog) do
    if type(c) == "table" and c.specs then
      for _, spec in pairs(c.specs) do
        for _, mode in pairs(spec) do
          for key, list in pairs(mode.brackets or {}) do
            local r = resolve(list)
            for _, b in ipairs(r) do fixBracket(cls, key, b) end
            if key == "heal" and HEAL[cls] then r = resolve(HEAL[cls]) end
            gated(cls, key, r)
            mode.brackets[key] = compress(r)
            n = n + 1
          end
        end
      end
    end
  end
  return n
end

-- Modules/MacroEngine.lua  (P4-01)
-- Pure macro logic, no game calls, so all of it is unit-tested:
--   Fill(body, values)  -> text, missing  ({TARGET} style placeholders)
--   Validate(body)      -> problems { level = "error"|"warn", msg }
--   Explain(body)       -> one plain-English line per macro line
-- Classic/Forever macro syntax: /cast, /castsequence, [conditions], ";" for
-- "otherwise", "!" so a second press doesn't toggle Auto Shot or an aspect off.

local _, ns = ...
local E = { MAX = 255 }
ns.MacroEngine = E

-- --------------------------------------------------------------- Fill
function E.Fill(body, values)
  values = values or {}
  local missing = {}
  local out = body:gsub("{([%u_]+)}", function(key)
    local v = values[key]
    if v == nil then missing[#missing + 1] = key return "{" .. key .. "}" end
    return tostring(v)
  end)
  return out, missing
end

-- --------------------------------------------------------------- Validate
local KNOWN = {}
for cmd in ([[cast use castsequence castrandom userandom target targetexact targetenemy targetfriend
  targetlasttarget targetparty targetraid assist focus clearfocus cleartarget petattack petfollow petpassive
  petdefensive petaggressive petstay petmoveto petautocaston petautocastoff petautocasttoggle startattack
  stopattack stopcasting stopspelltarget stopmacro dismount cancelaura cancelform equip equipslot equipset
  click run script say yell emote e s y p g w whisper raid ra rw i instance reload console tm targetmarker
  wm worldmarker cwm clearworldmarker follow f stopwatch petdismiss dismisspet]]):gmatch("%S+") do
  KNOWN[cmd] = true
end
E.KNOWN = KNOWN

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

function E.Validate(body)
  local problems = {}
  local function add(level, msg) problems[#problems + 1] = { level = level, msg = msg } end
  if #body > E.MAX then add("error", string.format("%d characters, the limit is %d", #body, E.MAX)) end
  local hasTooltip = false
  local i = 0
  for line in (body .. "\n"):gmatch("(.-)\n") do
    i = i + 1
    local l = trim(line)
    if l:match("^#show") then
      hasTooltip = true
    elseif l:match("^{[%u_]+}$") then
      add("warn", string.format("line %d: %s is filled in at install time", i, l))
    elseif l ~= "" then
      local cmd, rest = l:match("^/(%S+)%s*(.*)$")
      if not cmd then
        add("error", string.format("line %d is not a command", i))
      else
        cmd = cmd:lower()
        if not KNOWN[cmd] then add("warn", string.format("line %d: /%s is not a known command (an emote is fine)", i, cmd)) end
        local _, opens = l:gsub("%[", "")
        local _, closes = l:gsub("%]", "")
        if opens ~= closes then add("error", string.format("line %d: unbalanced [ ]", i)) end
        if l:find("%[%s*%]") then add("warn", string.format("line %d: empty [ ] means always", i)) end
        if cmd == "cast" or cmd == "castsequence" then
          if rest:find("Auto Shot", 1, true) and not rest:find("!Auto Shot", 1, true) then
            add("warn", string.format("line %d: use !Auto Shot so a second press doesn't stop shooting", i))
          end
          if rest:find("Aspect of", 1, true) and not rest:find("!Aspect of", 1, true) then
            add("warn", string.format("line %d: use !Aspect so a second press doesn't turn it off", i))
          end
          if (cmd == "castsequence" or rest:find(";", 1, true)) and not hasTooltip then
            add("warn", "several spells on one button: add #showtooltip so the icon follows")
          end
        end
      end
    end
  end
  return problems
end

function E.Errors(body)
  local n = 0
  for _, p in ipairs(E.Validate(body)) do if p.level == "error" then n = n + 1 end end
  return n
end

-- --------------------------------------------------------------- Explain
local COND = {
  ["mod:shift"] = "Shift is held", ["mod:ctrl"] = "Ctrl is held", ["mod:alt"] = "Alt is held", mod = "a modifier is held",
  nomod = "no modifier is held", harm = "it is hostile", noharm = "it is not hostile", help = "it is friendly",
  nohelp = "it is not friendly", dead = "it is dead", nodead = "it is alive", exists = "it exists",
  noexists = "there is none", combat = "you are in combat", nocombat = "you are out of combat",
  channeling = "you are channeling", nochanneling = "you are not channeling", stealth = "you are stealthed",
  mounted = "you are mounted", nomounted = "you are not mounted", pet = "you have a pet", nopet = "you have no pet",
}
local UNIT = { mouseover = "your mouseover", focus = "your focus", pet = "your pet", player = "yourself",
  target = "your target", targettarget = "your target's target" }

-- Split leading "[..][..]" blocks from the rest: returns conds, rest.
local function splitConds(s)
  s = trim(s)
  local pos = 1
  while true do
    local a, b = s:find("^%s*%b[]", pos)
    if not a then break end
    pos = b + 1
  end
  return s:sub(1, pos - 1), trim(s:sub(pos))
end
E.SplitConds = splitConds

-- "[@mouseover,harm,nodead][nomod]" -> list of condition groups (OR of ANDs)
local function parseConds(s)
  local groups = {}
  for inner in s:gmatch("%[(.-)%]") do
    local g = { conds = {} }
    for part in inner:gmatch("[^,]+") do
      part = trim(part)
      local unit = part:match("^@(.+)$") or part:match("^target=(.+)$")
      if unit then g.unit = unit elseif part ~= "" then g.conds[#g.conds + 1] = part end
    end
    groups[#groups + 1] = g
  end
  return groups
end

-- "it is hostile and it is alive" -> "your focus is hostile and alive"
local function describeGroup(g)
  local who = g.unit and (UNIT[g.unit] or g.unit) or nil
  local words = {}
  local named = false -- the unit has been named once; later "it is X" -> "X"
  for _, c in ipairs(g.conds) do
    local w = COND[c] or c
    if w:sub(1, 3) == "it " then
      if named then
        w = w:gsub("^it is ", ""):gsub("^it ", "")
      elseif who then
        w = who .. w:sub(3)
      end
      named = true
    end
    words[#words + 1] = w
  end
  if #words == 0 and who then return "for " .. who, who end
  return table.concat(words, " and "), who
end

-- "!Auto Shot" -> "Auto Shot (a second press won't stop it)"
local function spellText(spell)
  local name = spell:match("^!(.+)$")
  if name then return name .. " (a second press won't stop it)" end
  return spell
end

-- one "[conds] Spell" clause -> "if X, cast Spell on Y"
local function explainClause(verb, clause)
  local condPart, spell = splitConds(clause)
  local groups = parseConds(condPart)
  if #groups == 0 then return nil, verb .. " " .. spellText(spell) end
  local alts = {}
  for _, g in ipairs(groups) do
    local text = describeGroup(g)
    alts[#alts + 1] = text ~= "" and text or "always"
  end
  return table.concat(alts, ", or "), verb .. " " .. spellText(spell)
end

local function explainCast(verb, rest)
  local parts = {}
  local clauses = {}
  for c in (rest .. ";"):gmatch("(.-);") do clauses[#clauses + 1] = c end
  for i, c in ipairs(clauses) do
    local cond, action = explainClause(verb, c)
    if cond then
      parts[#parts + 1] = (i == 1 and "If " or "if ") .. cond .. ", " .. action
    else
      parts[#parts + 1] = (i == 1 and "" or "otherwise ") .. action
    end
  end
  local s = table.concat(parts, "; ")
  return (s:gsub("^%l", string.upper))
end

local SLOTS = { ["13"] = "top trinket", ["14"] = "bottom trinket" }

function E.ExplainLine(line)
  local l = trim(line)
  if l == "" then return nil end
  local tip = l:match("^#showtooltip%s*(.*)$")
  if tip then return tip ~= "" and ("Shows " .. tip .. " on the button") or "The button shows whichever spell is next" end
  local cmd, rest = l:match("^/(%S+)%s*(.*)$")
  if not cmd then return l end
  cmd = cmd:lower()
  if cmd == "cast" then return explainCast("cast", rest) end
  if cmd == "use" then
    local slot = rest:match("^(%d+)$")
    if slot then return "Use item slot " .. slot .. (SLOTS[slot] and (" (" .. SLOTS[slot] .. ")") or "") end
    return explainCast("use", rest)
  end
  if cmd == "castsequence" then
    local cond, body = splitConds(rest)
    local reset = body:match("^reset=(%S+)%s+")
    if reset then body = trim(body:sub(#("reset=" .. reset) + 1)) end
    local spells = {}
    for sp in body:gmatch("[^,]+") do spells[#spells + 1] = trim(sp) end
    local s = "Each press casts the next of: " .. table.concat(spells, ", then ")
    if reset then
      local words = {}
      for r in reset:gmatch("[^/]+") do
        words[#words + 1] = tonumber(r) and (r .. " seconds idle") or (r == "combat" and "leaving combat")
          or (r == "target" and "a new target") or ("pressing with " .. r)
      end
      s = s .. " (starts over after " .. table.concat(words, " or ") .. ")"
    end
    if cond ~= "" then
      local groups = parseConds(cond)
      local text = describeGroup(groups[1])
      s = "If " .. text .. ": " .. s:sub(1, 1):lower() .. s:sub(2)
    end
    return s
  end
  if cmd == "stopmacro" then
    local groups = parseConds(rest)
    local alts = {}
    for _, g in ipairs(groups) do alts[#alts + 1] = (describeGroup(g)) end
    return "Stop here if " .. table.concat(alts, ", or if ")
  end
  if cmd == "cleartarget" then
    if rest == "" then return "Clear your target" end
    return "Clear your target if " .. (describeGroup(parseConds(rest)[1]))
  end
  if cmd == "targetexact" then return "Target exactly " .. rest end
  if cmd == "target" then return "Target " .. rest end
  if cmd == "targetenemy" then
    if rest == "" then return "Target the nearest enemy" end
    local alts = {}
    for _, g in ipairs(parseConds(rest)) do alts[#alts + 1] = (describeGroup(g)) end
    return "Target the nearest enemy if " .. table.concat(alts, ", or if ")
  end
  if cmd == "petattack" then return "Send your pet to attack" end
  if cmd == "petpassive" then return "Set your pet to passive" end
  if cmd == "stopattack" then return "Stop attacking" end
  if cmd == "clearfocus" then
    if rest == "" then return "Clear your focus" end
    return "Clear your focus if " .. (describeGroup(parseConds(rest)[1]))
  end
  if cmd == "petfollow" then return "Call your pet back" end
  if cmd == "startattack" then return "Start melee attacking" end
  if cmd == "stopcasting" then return "Stop what you are casting" end
  if cmd == "equip" then return "Equip " .. rest end
  if cmd == "focus" then
    if rest == "" then return "Set your focus to your target" end
    local alts = {}
    for _, g in ipairs(parseConds(rest)) do
      local text, who = describeGroup(g)
      alts[#alts + 1] = (who or "your target") .. (text ~= "" and text ~= ("for " .. tostring(who)) and (" if " .. text) or "")
    end
    return "Set your focus to " .. table.concat(alts, ", otherwise to ")
  end
  return "/" .. cmd .. (rest ~= "" and (" " .. rest) or "")
end

function E.Explain(body)
  local out = {}
  for line in (body .. "\n"):gmatch("(.-)\n") do
    local e = E.ExplainLine(line)
    if e then out[#out + 1] = e end
  end
  return out
end

-- Modules/ComboKeys.lua  (requirement 2026-11-20: too many single-action
-- macros; fold the best sequences into fewer macros)
-- Five combined keys per class, built from what the character knows:
--   Stop     interrupt; Shift stun; Ctrl / Alt longer crowd control
--   Save     your big defensive; Shift escape; Ctrl / Alt the next one
--   Burst    both trinkets + your cooldown; Shift the second cooldown
--   Recover  out of combat eat and drink, in combat healthstone then potion; Shift bandage
--   Team     assist; Shift set focus; Ctrl clear focus
-- Each layer is a modifier the player holds (Data/ComboKeys.lua). Like the
-- Fight key, a combined key Outrider wrote follows the spellbook: learn Kick
-- and the Stop key on your bar gains it. Only from your press (rule 1).

local _, ns = ...
local C = ns.Compat
local E = ns.MacroEngine
local M = ns:NewModule("ComboKeys", {
  title = "Combined keys",
  phase = "P4",
  order = 63,
  defaults = { auto = true },
})
ns.ComboKeys = M

M.ORDER = { "Stop", "Save", "Burst", "Recover", "Team" }
M.MODS = { { "Ctrl", "mod:ctrl" }, { "Shift", "mod:shift" }, { "Alt", "mod:alt" }, { "", "nomod" } }
M.KEY_EXPLAIN = {
  Stop = "Stops an enemy. Plain press: your interrupt (on your focus if it's an enemy, else your target).",
  Save = "Saves your life. Plain press: your big defensive; hold a modifier for the next one.",
}

local function known(sp) return ns.Spellbook and ns.Spellbook:Known(sp) ~= nil end
local function data() return ns.ComboKeyData or {} end

-- The spell (and its condition and target) a layer gives this character, or nil.
local function pick(alts)
  for _, a in ipairs(alts or {}) do
    if known(a[1]) then return a end
  end
end

-- The condition blocks for one layer: "[mod:shift,@focus,harm,nodead][mod:shift]"
local function blocks(mod, a)
  local base = mod .. (a.cond and ("," .. a.cond) or "")
  if a.at == "focus" then return "[" .. base .. ",@focus,harm,nodead][" .. base .. "]"
  elseif a.at == "mouseover" then return "[" .. base .. ",@mouseover,harm,nodead][" .. base .. "]"
  elseif a.at == "player" then return "[" .. base .. ",@player]" end
  return "[" .. base .. "]"
end

-- One /cast line from a class key's layers (Stop, StopShift, StopCtrl, StopAlt).
-- Returns the line and { {mod label, spell} } in press order.
function M.CastLine(def, key)
  local parts, layers = {}, {}
  for _, m in ipairs(M.MODS) do
    local label, mod = m[1], m[2]
    local a = pick(def[key .. label])
    if a then
      parts[#parts + 1] = blocks(mod, a) .. " " .. a[1]
      layers[#layers + 1] = { label == "" and "Press" or label, a[1] }
    end
  end
  local rank = { Press = 1, Shift = 2, Ctrl = 3, Alt = 4 }
  table.sort(layers, function(x, y) return rank[x[1]] < rank[y[1]] end)
  if #parts == 0 then return nil, layers end
  return "/cast " .. table.concat(parts, "; "), layers
end

-- The text of each key for this character, or nil when it has nothing yet.
function M:Body(name)
  local cls = ns.PlayerClass()
  local def = data()[cls] or {}
  local values = ns.MacroLibrary and ns.MacroLibrary:Values() or {}
  local have = function(k) return values[k] ~= nil and values[k] ~= "" end
  if name == "Recover" then
    local lines = {}
    if have("BANDAGE") then lines[#lines + 1] = "/use [mod:shift,@player] {BANDAGE}" end
    local mana = ns.ManaCare and ns.ManaCare:Potion()
    if mana then lines[#lines + 1] = "/use [mod:ctrl] " .. mana end
    if have("HEALTHSTONE") and have("POTION") then lines[#lines + 1] = "/castsequence [combat,nomod] reset=combat {HEALTHSTONE}, {POTION}"
    elseif have("HEALTHSTONE") then lines[#lines + 1] = "/use [combat,nomod] {HEALTHSTONE}"
    elseif have("POTION") then lines[#lines + 1] = "/use [combat,nomod] {POTION}" end
    if have("DRINK") then lines[#lines + 1] = "/use [nocombat,nomod] {DRINK}" end
    if have("FOOD") then lines[#lines + 1] = "/use [nocombat,nomod] {FOOD}" end
    if #lines == 0 then return nil end
    return "#showtooltip\n" .. table.concat(lines, "\n")
  elseif name == "Team" then
    return "/focus [mod:shift,@mouseover,exists,nodead][mod:shift]\n/clearfocus [mod:ctrl]\n/assist [nomod,@mouseover,help,nodead][nomod]"
  elseif name == "Burst" then
    local line = M.CastLine(def, "Burst")
    return "#showtooltip\n/use [nomod] 13\n/use [nomod] 14" .. (line and ("\n" .. line) or "")
  end
  local line = M.CastLine(def, name)
  if not line then return nil end
  return "#showtooltip\n" .. line
end

-- What each layer does, in words: "Press: Kick · Shift: Gouge · Ctrl: Kidney Shot"
function M:Layers(name)
  local def = data()[ns.PlayerClass()] or {}
  if name == "Recover" then return "Press: eat and drink (out of combat), healthstone then potion (in combat) · Shift: bandage yourself" .. ((ns.ManaCare and ns.ManaCare:Potion()) and " · Ctrl: mana potion" or "") end
  if name == "Team" then return "Press: assist · Shift: set focus · Ctrl: clear focus" end
  local _, layers = M.CastLine(def, name)
  local out = {}
  if name == "Burst" then out[1] = "Press: both trinkets" end
  for _, l in ipairs(layers) do
    if name == "Burst" and l[1] == "Press" then out[1] = "Press: both trinkets + " .. l[2]
    else out[#out + 1] = l[1] .. ": " .. l[2] end
  end
  return table.concat(out, "  ·  ")
end

local function shared(name)
  for _, k in ipairs(data().ALL or {}) do if k.name == name then return k end end
end

-- Library-style entries for the keys this character can have now.
function M:Entries()
  local cls, out = ns.PlayerClass(), {}
  for _, name in ipairs(M.ORDER) do
    local body = self:Body(name)
    if body and E.Errors((E.Fill(body, ns.MacroLibrary and ns.MacroLibrary:Values() or {}))) == 0 then
      local s = shared(name)
      out[#out + 1] = { id = "combo-" .. name:lower(), name = name, class = cls, body = body, scope = "char",
        icon = "INV_MISC_QUESTIONMARK", tags = { "combo" }, combo = true, layers = self:Layers(name),
        explain = (s and s.explain) or M.KEY_EXPLAIN[name] or "", replaces = s and s.replaces }
    end
  end
  return out
end

-- Spells and single-macro ids a combined key already covers (the Macros page
-- hides those singles). Only keys this character actually has count.
function M:Covered()
  local spells, ids = {}, {}
  for _, e in ipairs(self:Entries()) do
    for _, id in ipairs(e.replaces or {}) do ids[id] = true end
    for sp in e.body:gmatch("%] ([^;\n%[]+)") do spells[(sp:gsub("%s+$", ""))] = true end
  end
  return spells, ids
end

-- Rewrite the combined keys Outrider already wrote when spells or bags change.
function M:Update(why)
  if not ns.MacroLibrary then return end
  ns.Combat:Run("ComboKeys", function()
    local lib = ns.MacroLibrary
    local installed = lib:Settings().installed
    for _, e in ipairs(self:Entries()) do
      if installed[e.name] and installed[e.name].id == e.id and lib:State(e) ~= "installed" then
        local ok, msg = lib:Install(e)
        if ok then self:Info("%s key rewritten (%s)", e.name, tostring(why)) else self:Debug("%s key not rewritten: %s", e.name, tostring(msg)) end
      end
    end
  end, "combokeys")
end

function M:OnEnable()
  local function later(why) ns.Throttle("combokeys", 3, function() M:Update(why) end) end
  self:On("PLAYER_ENTERING_WORLD", function() later("login") end)
  self:On("SPELLS_CHANGED", function(mod) if mod:Settings().auto then later("spells") end end)
  self:On("PLAYER_LEVEL_UP", function(mod) if mod:Settings().auto then later("level") end end)
  self:On("BAG_UPDATE_DELAYED", function(mod) if mod:Settings().auto and not C.InCombat() then later("bags") end end)
end

function M:OnDisable() ns.ThrottleCancel("combokeys") end

function M:Activity()
  local names = {}
  for _, e in ipairs(self:Entries()) do names[#names + 1] = e.name end
  return string.format("%d combined keys for you: %s", #names, table.concat(names, ", "))
end

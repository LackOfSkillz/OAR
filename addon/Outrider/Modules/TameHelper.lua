-- Modules/TameHelper.lua  (HUNTER, P2-08; this file starts with the macro part)
-- /ride tamemacro <Beast Name>: writes Gary's tame macro for that beast with
-- the in-game macro API (EditMacro/CreateMacro), out of combat, from a typed
-- command (a key press). We never edit WTF\ files: the client overwrites
-- them at logout and keeps a server copy of macros.
-- Macro flow (one press = one action, like any normal macro). Gary's plan
-- for Mystmane (2026-11-13): a throwaway pet takes the knockdown, then he
-- dismisses it and tames.
--   pet out            press: target the beast and send the pet in
--   pet out + Shift    Dismiss Pet (after the pet has taken the knockdown)
--   no pet, no combat  press: Concussive Shot pulls and slows
--   no pet, in combat  press: Tame Beast
--   no pet + Shift     Concussive Shot again (she wandered off)
-- /stopmacro [channeling] first, so a press never breaks the tame channel.
-- Whether Forever lets you tame with a dismissed pet is not known yet: a
-- refusal shows in the fight log's errors; abandoning the pet from its
-- portrait is then the way.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("TameHelper", {
  title = "Tame helper",
  phase = "P2",
  order = 35,
  classes = { HUNTER = true },
  defaults = {},
})

M.TEMPLATE = table.concat({
  "#showtooltip",
  "/stopmacro [channeling]",
  "/cleartarget",
  "/targetexact {NAME}",
  "/stopmacro [noharm][dead]",
  "/cast [mod,pet] Dismiss Pet; [mod][nopet,nocombat] Concussive Shot",
  "/petattack [pet,nomod]",
  "/stopmacro [pet]",
  "/cast [combat] Tame Beast",
}, "\n")

-- "mystmane" -> "Mystmane", "ghost howl" -> "Ghost Howl" (names are typed by hand).
function M.Capitalize(name)
  return (name:gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end))
end

function M:Body(beast)
  return (self.TEMPLATE:gsub("{NAME}", beast))
end

-- ------------------------------------------------------------ name check
-- A typo in the beast's name ("Mystmade" for Mystmane, 2026-11-13) makes
-- /targetexact never find it. Names are checked against creatures Outrider
-- knows: the creature pack and everything met (Discovery). A close miss (up
-- to 2 letters off) is corrected; an exact match keeps its proper spelling.
local function distance(a, b)
  a, b = a:lower(), b:lower()
  if math.abs(#a - #b) > 2 then return 99 end
  local prev = {}
  for j = 0, #b do prev[j] = j end
  for i = 1, #a do
    local cur = { [0] = i }
    for j = 1, #b do
      local cost = a:sub(i, i) == b:sub(j, j) and 0 or 1
      cur[j] = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
    end
    prev = cur
  end
  return prev[#b]
end
M.Distance = distance

function M:KnownNames()
  local out = {}
  local d = ns.db.global.discovered
  for _, e in pairs(type(d) == "table" and d.npcs or {}) do if type(e.name) == "string" then out[e.name] = true end end
  local mobs = ns.Finder and ns.Finder:Mobs()
  for _, rows in pairs(mobs or {}) do
    for _, r in ipairs(rows) do out[r[2]] = true end
  end
  return out
end

-- Returns the name to use and whether it was corrected.
function M:CheckName(name)
  local names, best, bd = self:KnownNames(), nil, 3
  for n in pairs(names) do
    if n:lower() == name:lower() then return n, false end
    local dd = distance(name, n)
    if dd < bd then best, bd = n, dd end
  end
  if best then return best, true end
  return name, false
end

-- At login: a tame macro Outrider wrote for a name no creature has, but one
-- is 1-2 letters off, gets the right name (and so does the rare watch list).
function M:FixTypos()
  if C.InCombat() then return end
  local last = (rawget(_G, "MAX_ACCOUNT_MACROS") or 120) + (rawget(_G, "MAX_CHARACTER_MACROS") or 18)
  for index = 1, last do
    local name, _, body = C.Call("GetMacroInfo", index)
    local target = type(body) == "string" and body:find("/stopmacro [channeling]", 1, true) and body:match("/targetexact ([^\n]+)")
    if target then
      local fixed, changed = self:CheckName(target)
      if changed then
        local newName = (name and name:lower() == target:lower()) and fixed:sub(1, 16) or name
        local ok = pcall(EditMacro, index, newName, nil, self:Body(fixed))
        self:Info("tame macro %s: %s -> %s (%s)", tostring(name), target, fixed, ok and "fixed" or "EditMacro failed")
        local scan = ns.Modules:Get("RareScan")
        if ok and scan then scan:Watch(target, false) scan:Watch(fixed, true) end
        if ok then ns.Print("fixed your tame macro: %s is spelled %s", target, fixed) end
      end
    end
  end
end

function M:OnEnable()
  self:On("PLAYER_ENTERING_WORLD", function(mod) ns.Combat:Run("tame:fix", function() mod:FixTypos() end, "tame:fix") end)
end

-- Returns ok, message. macroName defaults to the beast name (16 chars max).
function M:WriteMacro(beast, macroName)
  if type(beast) ~= "string" or beast == "" then return false, "usage: /ride tamemacro <Beast Name>" end
  if C.InCombat() then return false, "not in combat: macros can only be changed out of combat" end
  beast = M.Capitalize(beast)
  local fixed, changed = self:CheckName(beast)
  if changed then ns.Print("no creature called %s; using %s", beast, fixed) end
  beast = fixed
  macroName = (macroName or beast):sub(1, 16)
  local body = self:Body(beast)
  if #body > 255 then return false, "macro would be over 255 characters" end
  local index = C.Call("GetMacroIndexByName", macroName) or 0
  if index > 0 then
    -- Keep the existing macro's own name and icon; only the text changes.
    local existing = C.Call("GetMacroInfo", index)
    -- (a macro named after the beast gets the beast's proper capitals)
    if existing and existing:lower() ~= beast:lower() then macroName = existing end
    local ok = pcall(EditMacro, index, macroName, nil, body)
    if not ok then return false, "EditMacro failed" end
    self:Info("tame macro updated: %s (index %d, %d chars)", macroName, index, #body)
    return true, "updated macro '" .. macroName .. "'"
  end
  local _, perChar = C.Call("GetNumMacros")
  local maxChar = rawget(_G, "MAX_CHARACTER_MACROS") or 18
  if perChar and perChar >= maxChar then return false, "no free character macro slot" end
  local ok, newIndex = pcall(CreateMacro, macroName, "INV_MISC_QUESTIONMARK", body, true)
  if not ok or not newIndex then return false, "CreateMacro failed" end
  self:Info("tame macro created: %s (index %s, %d chars)", macroName, tostring(newIndex), #body)
  return true, "created macro '" .. macroName .. "' (drag it from the macro window to your bar)"
end

ns.AddCommand("tamemacro", "<Beast Name>  write a pull + tame macro for that beast", function(arg)
  if ns.PlayerClass() ~= "HUNTER" then ns.Print("tame macros are for hunters") return end
  local ok, msg = M:WriteMacro(arg and strtrim(arg))
  ns.Print(msg)
  -- A beast worth a tame macro is worth an alert: watch it on this character.
  local scan = ns.Modules:Get("RareScan")
  if ok and scan then scan:Watch((M:CheckName(M.Capitalize(strtrim(arg)))), true) end
end)

function M:Activity() return "/ride tamemacro <Beast> writes a pull + tame macro" end

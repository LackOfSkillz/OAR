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

-- Returns ok, message. macroName defaults to the beast name (16 chars max).
function M:WriteMacro(beast, macroName)
  if type(beast) ~= "string" or beast == "" then return false, "usage: /ride tamemacro <Beast Name>" end
  if C.InCombat() then return false, "not in combat: macros can only be changed out of combat" end
  beast = M.Capitalize(beast)
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
  if ok and scan then scan:Watch(M.Capitalize(strtrim(arg)), true) end
end)

function M:Activity() return "/ride tamemacro <Beast> writes a pull + tame macro" end

-- Intelligence/Modes.lua  (OI07-01: experience modes)
-- How much Outrider says, never what it knows: Beginner, Experienced or
-- Advanced, per character (char.uiMode). A new character starts as Beginner,
-- an existing one as Experienced. Every engine works the same in every mode;
-- only the words on a card change:
--   Beginner     the plain line only
--   Experienced  the plain line and the first two details
--   Advanced     everything, and the evidence behind it
-- Pick(short, details, evidence) is what pages call. Settings has the switch
-- (Look section) and /ride mode beginner|experienced|advanced.

local _, ns = ...
local MD = { MODES = { "beginner", "experienced", "advanced" }, LABELS = { beginner = "Beginner", experienced = "Experienced", advanced = "Advanced" } }
ns.Modes = MD
local VALID = { beginner = true, experienced = true, advanced = true }

function MD.Current()
  local c = ns.db and ns.db.char
  if not c then return "experienced" end
  if not VALID[c.uiMode] then c.uiMode = (ns.DB and ns.DB.freshChar) and "beginner" or "experienced" end
  return c.uiMode
end

function MD.Set(mode)
  if not VALID[mode] then return false, "beginner, experienced or advanced" end
  ns.db.char.uiMode = mode
  if ns.Events and ns.Events.Fire then ns.Events:Fire("OTR_MODE_CHANGED", mode) end
  return true
end

function MD.Pick(short, details, evidence, mode)
  mode = mode or MD.Current()
  local parts = { tostring(short or "") }
  details = details or {}
  local n = mode == "beginner" and 0 or mode == "experienced" and math.min(2, #details) or #details
  for i = 1, n do parts[#parts + 1] = tostring(details[i]) end
  if mode == "advanced" then for _, e in ipairs(evidence or {}) do parts[#parts + 1] = "Evidence: " .. tostring(e) end end
  return table.concat(parts, " ")
end

ns.AddCommand("mode", "mode beginner|experienced|advanced: how much detail pages show", function(arg)
  arg = tostring(arg or ""):lower()
  if arg == "" then ns.Print("mode: %s", MD.LABELS[MD.Current()]) return end
  local ok, why = MD.Set(arg)
  if ok then ns.Print("mode: %s", MD.LABELS[arg]) else ns.Print("usage: /ride mode %s", why) end
end)

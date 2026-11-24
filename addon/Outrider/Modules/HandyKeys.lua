-- Modules/HandyKeys.lua  (requirement 2026-11-19: find what scripts inside
-- macros are useful for, and build those helpers into the macros)
-- One-press helpers you put on a bar, each a macro line "/ride <command>":
--   Nameplates  enemy nameplates on or off (rares are seen from much further)
--   Vendor      at a merchant: sell grey junk and repair
--   Status      rested XP, XP to the next level, durability, bags, gold this session
--   Next Step   What now?'s top step, with the arrow set
-- And quiet presses: Outrider's casting macros end with a line that clears
-- the red "not ready yet" text (where it fits in 255 characters), and a
-- switch turns off the error voice ("I can't do that yet").
-- Written as Outrider commands rather than raw /run scripts: the same effect,
-- tested here, aware of combat, and no script prompt from the game. Nothing
-- here casts, targets or acts on its own (rule 1): each runs from your press.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("HandyKeys", {
  title = "Handy keys and quiet presses",
  phase = "P4",
  order = 64,
  defaults = { quiet = true },
})
ns.HandyKeys = M

M.QUIET_LINE = "/run UIErrorsFrame:Clear()"

-- The macro text Outrider writes: a casting macro gets the quiet line at the
-- end when it fits (MacroLibrary:Install and :State both use this).
function M.Final(body)
  if type(body) ~= "string" or not (M.enabled and M:Settings().quiet) then return body end
  if not (body:find("\n/cast", 1, true) or body:find("^/cast") or body:find("\n/castsequence", 1, true)) then return body end
  if body:find(M.QUIET_LINE, 1, true) then return body end
  local out = body .. "\n" .. M.QUIET_LINE
  if #out > (ns.MacroEngine and ns.MacroEngine.MAX or 255) then return body end
  return out
end

-- The game's error voice ("I can't do that yet"): off with quiet presses, on without.
function M:SetVoice(on)
  local set = C.Resolve("C_CVar.SetCVar") or rawget(_G, "SetCVar")
  if type(set) == "function" then pcall(set, "Sound_EnableErrorSpeech", on and "1" or "0") end
end

function M:SetQuiet(on)
  self:Settings().quiet = on and true or false
  self:SetVoice(not on)
  self:Info("quiet presses %s", on and "on" or "off")
  -- rewrite Outrider's macros so the quiet line comes or goes (out of combat)
  if ns.HunterFight and ns.HunterFight.enabled then ns.HunterFight:Update("quiet") end
end

-- ------------------------------------------------------------------ the keys
function M:Plates()
  if C.InCombat() then return false, "nameplates can't be switched during a fight" end
  local get = C.Resolve("C_CVar.GetCVar") or rawget(_G, "GetCVar")
  local set = C.Resolve("C_CVar.SetCVar") or rawget(_G, "SetCVar")
  if type(get) ~= "function" or type(set) ~= "function" then return false, "nameplates can't be switched on this client" end
  local on = tostring(get("nameplateShowEnemies")) == "1"
  local ok = pcall(set, "nameplateShowEnemies", on and "0" or "1")
  if not ok then return false, "the game refused the change" end
  return true, on and "enemy nameplates off" or "enemy nameplates on: rares are seen from much further away"
end

function M:Vendor()
  local mer = ns.Merchant
  if not (mer and mer.vendorOpen) then return false, "talk to a vendor first, then press it" end
  if C.InCombat() then return false, "not in combat" end
  local sold, value = mer:SellJunk()
  local cost, can = mer:RepairCost()
  local repaired = false
  if can and (cost or 0) > 0 then repaired = mer:Repair() and true or false end
  local parts = {}
  parts[#parts + 1] = sold > 0 and string.format("sold %d junk for %s", sold, ns.Prices.Money(value)) or "no junk to sell"
  if repaired then parts[#parts + 1] = "repaired for " .. ns.Prices.Money(cost)
  elseif (cost or 0) > 0 then parts[#parts + 1] = "repair " .. ns.Prices.Money(cost) .. " (not enough gold?)" end
  if sold >= (mer.PER_CLICK or 12) then parts[#parts + 1] = "press again for the rest" end
  return true, table.concat(parts, ", ")
end

function M:Status()
  local parts = {}
  local xp, max = tonumber(C.Readable(C.Call("UnitXP", "player"))), tonumber(C.Readable(C.Call("UnitXPMax", "player")))
  local rested = tonumber(C.Readable(C.Call("GetXPExhaustion")))
  if xp and max and max > 0 then
    parts[#parts + 1] = string.format("%d XP to level %d", max - xp, (tonumber(C.Readable(C.Call("UnitLevel", "player"))) or 0) + 1)
    if rested and rested > 0 then parts[#parts + 1] = string.format("rested %d%%", math.floor(rested / max * 100 + 0.5)) end
  end
  local IB = ns.InfoBar
  local dura = IB and IB.Durability and IB.Durability()
  if dura then parts[#parts + 1] = string.format("durability %d%%", math.floor(dura + 0.5)) end
  local free = IB and IB.Bags and IB.Bags()
  if free then parts[#parts + 1] = string.format("%d bag slots free", free) end
  if ns.Ledger and ns.Ledger.Summary then
    local net = ns.Ledger:Summary()
    parts[#parts + 1] = string.format("gold this session %s%s", net < 0 and "-" or "+", ns.Prices.Money(math.abs(net)))
  end
  return true, table.concat(parts, ", ")
end

function M:Next()
  local W = ns.WhatNow
  local step = W and W.enabled and W:List()[1]
  if not step then return false, "no next step yet: open What now? once" end
  local arrow = step.go and select(2, pcall(step.go)) and " (arrow set)" or ""
  return true, tostring(step.title) .. (step.where and (": " .. tostring(step.where)) or "") .. arrow
end

local function say(ok, msg) ns.Print("%s", ok and msg or ("|cffff7f7f" .. tostring(msg) .. "|r")) end
ns.AddCommand("plates", "enemy nameplates on or off (out of combat)", function() say(M:Plates()) end)
ns.AddCommand("vendor", "at a merchant: sell grey junk and repair", function() say(M:Vendor()) end)
ns.AddCommand("me", "rested XP, XP to level, durability, bags and gold this session", function() say(M:Status()) end)
ns.AddCommand("next", "What now?'s top step, with the arrow set", function() say(M:Next()) end)
ns.AddCommand("quiet", "on|off  quiet presses: no 'not ready yet' text or voice", function(arg)
  if arg == "on" or arg == "off" then M:SetQuiet(arg == "on") end
  ns.Print("quiet presses %s", M:Settings().quiet and "on" or "off")
end)

function M:OnEnable()
  -- the voice follows the switch from the first login
  self:On("PLAYER_ENTERING_WORLD", function(mod, _, isLogin) if isLogin then mod:SetVoice(not mod:Settings().quiet) end end)
end

function M:Activity()
  return string.format("quiet presses %s; keys: Nameplates, Vendor, Status, Next Step", self:Settings().quiet and "on" or "off")
end

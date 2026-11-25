-- Intelligence/OraclePage.lua  (OI05-17: Oracle and Forge on the Gear page)
-- A "What if?" section on the Gear page (through Hub:AddSection, like
-- GearROI's), in plain words first and the detail after:
--   * Your damage estimate: the Forge's range over a one-minute fight from your
--     own tooltips, what makes it a range, and what isn't modelled
--   * Try an upgrade: save how you are now, try the top upgrade on that copy
--     (and its gold), and compare the two with the Oracle: known differences,
--     what can't be told, and "refresh" when you changed since saving
-- Buttons: Save now, Try top upgrade, Refresh, Copy details, Reset. They
-- only change these in-memory copies; nothing is equipped, bought or saved.

local _, ns = ...
local P = { state = {} }
ns.OraclePage = P

local function money(c) return ns.Prices and ns.Prices.Money(c) or tostring(c) end
local function kind()
  local cls = ns.PlayerClass and ns.PlayerClass()
  return (cls == "HUNTER") and "ranged" or "melee"
end

function P.ForgeLines(rep)
  if not rep then return "Not while you're in combat.", {} end
  local d = rep.damage
  local short
  if d then
    short = string.format("About %d to %d damage per second over a minute (an estimate from your tooltips).", math.floor(d.lo + 0.5), math.floor(d.hi + 0.5))
  elseif rep.healing then
    short = string.format("About %d healing per second over a minute (an estimate).", math.floor(rep.healing.perSecond + 0.5))
  else
    short = "No estimate yet: none of your spells shows a number in its tooltip."
  end
  local detail = {}
  for _, w in ipairs(d and d.why or {}) do detail[#detail + 1] = "Range because: " .. w .. "." end
  for _, n in ipairs(rep.partial or {}) do detail[#detail + 1] = "Partly: " .. n .. "." end
  detail[#detail + 1] = "Not modelled: " .. table.concat(rep.notModelled or {}, ", ") .. "."
  return short, detail
end

function P.CompareLines(cmp)
  if not cmp then return "Save how you are now, then try an upgrade to compare.", {} end
  if cmp.stale then return "You changed since saving: " .. cmp.stale .. ".", {} end
  local detail = {}
  for _, d in ipairs(cmp.dims) do
    if d.a ~= d.b then
      local a = d.name == "gold" and money(d.a) or tostring(d.a)
      local b = d.name == "gold" and money(d.b) or tostring(d.b)
      detail[#detail + 1] = string.format("%s: %s -> %s%s", d.name, a, b, d.unit and d.name ~= "gold" and (" (" .. d.unit .. ")") or "")
    end
  end
  for _, u in ipairs(cmp.unknown) do detail[#detail + 1] = "Can't tell: " .. u .. "." end
  local short = #cmp.notes > 0 and ("Trying it: " .. table.concat(cmp.notes, ", ") .. ".") or "No clear difference Outrider can measure."
  return short, detail
end

function P.Save()
  local S = ns.Scenario
  P.state.base = S.Base()
  P.state.now = S.Branch(P.state.base, {})
  P.state.try = nil
  return true
end

-- the top upgrade from GearROI on the saved copy (its price spent if known and affordable)
function P.TryTop()
  local S, R = ns.Scenario, ns.GearROI
  if not P.state.base then P.Save() end
  local list = R and R.Mine and R:Mine() or {}
  local top = list[1]
  if not (top and top.itemID and top.slot) then return nil, "no upgrade to try" end
  local o = { gear = { [top.slot] = top.itemID } }
  if top.price and top.price <= (P.state.base.copper or 0) then o.spend = math.floor(top.price) end
  local sc, why = S.Branch(P.state.base, o, { "trying " .. tostring(top.name) })
  if not sc then return nil, why end
  P.state.try, P.state.tryName = sc, top.name
  return sc
end

function P.Compare()
  if not (P.state.now and P.state.try) then return nil end
  local S = ns.Scenario
  local worn = {}
  for slot, id in pairs(P.state.base.gear or {}) do worn[slot] = id end
  return ns.Oracle.Compare(P.state.now, P.state.try, { liveHash = S.Hash(S.Base()), worn = worn })
end

function P.Reset() P.state = {} end

function P.ExportText()
  local lines = { "Outrider What if? (" .. ns.Forge.VERSION .. ", " .. ns.Oracle.VERSION .. ")" }
  local short, detail = P.ForgeLines(ns.Forge.Run(ns.Forge.Live(kind())))
  lines[#lines + 1] = short
  for _, d in ipairs(detail) do lines[#lines + 1] = "  " .. d end
  short, detail = P.CompareLines(P.Compare())
  lines[#lines + 1] = short
  for _, d in ipairs(detail) do lines[#lines + 1] = "  " .. d end
  return table.concat(lines, "\n")
end

function P.Cards(refresh)
  local function again() if refresh then refresh() end end
  local out = {}
  local ok, rep = pcall(function() return ns.Forge.Run(ns.Forge.Live(kind())) end)
  local short, detail = P.ForgeLines(ok and rep or nil)
  local pick = ns.Modes and ns.Modes.Pick or function(s, d) return s .. (#d > 0 and (" " .. table.concat(d, " ")) or "") end
  out[#out + 1] = { title = "Your damage estimate", line = pick(short, detail, { "forge " .. ns.Forge.VERSION }),
    actions = { { "Copy details", function() ns.UI:TextDialog("What if?", P.ExportText(), "copy") end, "Copy the estimate and its assumptions." } } }
  local cmp = P.Compare()
  short, detail = P.CompareLines(cmp)
  local actions = {
    { "Save now", function() P.Save() again() end, "Save a copy of how you are now (gear, gold, level)." },
    { "Try top upgrade", function() local _, why = P.TryTop() if why then ns.Print("%s", why) end again() end,
      "Put the top upgrade on the saved copy and compare. Nothing is equipped or bought." },
  }
  if cmp and cmp.stale then
    actions[#actions + 1] = { "Refresh", function() P.Save() P.TryTop() again() end, "Save again from how you are now." }
  end
  actions[#actions + 1] = { "Reset", function() P.Reset() again() end, "Forget the saved copy." }
  out[#out + 1] = { title = P.state.tryName and ("Try " .. tostring(P.state.tryName)) or "Try an upgrade",
    line = pick(short, detail, { "oracle " .. ns.Oracle.VERSION }), actions = actions }
  return out
end

ns.Hub:AddSection("gear", { key = "whatif", title = "What if?", icon = "INV_Misc_Book_09",
  note = "Estimates from your own tooltips and gear scores. They are not promises; what isn't known is said.",
  cards = function(refresh) return P.Cards(refresh) end })

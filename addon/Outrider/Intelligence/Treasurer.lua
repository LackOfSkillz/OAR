-- Intelligence/Treasurer.lua  (OI05-14: budget model)
-- What your gold is already kept for, in whole copper, and whether a planned
-- spend fits in the rest. Each reserve names its source; one with no known
-- cost is listed as unknown, never guessed:
--   training    class-training options seen at your trainer for your next
--               levels (Spellbook's trainer record, "cost may change")
--   riding      the leveling guide's riding fact, until you reach its level
--   gear        the largest gold reserve your active goals set
--   profession  the priced part of the supply plan's shopping list (Supply);
--               unpriced items are counted, not valued
--   repair      unknown unless you set it
-- Your own amount for a category (char.treasurer.reserves[cat]) replaces the
-- estimate and says "set by you". Wallets: every character's gold Alts saw,
-- with when; gold on other characters isn't counted as yours to spend here
-- (it needs mailing). Only the reserve is modelled: no advice on what to buy.

local _, ns = ...
local C = ns.Compat
local T = { CATS = { "training", "riding", "gear", "profession", "repair" }, LOOKAHEAD = 2 }
ns.Treasurer = T

local function int(v) v = tonumber(v) return v and math.floor(v) or nil end

function T.Store()
  local c = ns.db.char
  c.treasurer = ns.KeepTable(c.treasurer, "Treasurer:char.treasurer") or {}
  c.treasurer.reserves = ns.KeepTable(c.treasurer.reserves, "Treasurer:reserves") or {}
  return c.treasurer
end

-- copper = nil clears your amount (the estimate comes back)
function T.Set(cat, copper)
  local ok = false
  for _, c in ipairs(T.CATS) do if c == cat then ok = true end end
  if not ok then return false, "unknown category" end
  if copper ~= nil and not (int(copper) and int(copper) >= 0) then return false, "copper must be 0 or more" end
  T.Store().reserves[cat] = int(copper)
  return true
end

function T.Wallets()
  local out = {}
  local A = ns.Alts
  for key, a in pairs(A and A.alts or {}) do
    if type(a) == "table" and tonumber(a.money) then out[#out + 1] = { char = key, copper = int(a.money), at = a.t, me = key == ns.db.key } end
  end
  local live = int(C.Readable(C.Call("GetMoney")))
  local found = false
  for _, w in ipairs(out) do if w.me then found = true if live then w.copper, w.at = live, time() end end end
  if not found and live then out[#out + 1] = { char = ns.db.key, copper = live, at = time(), me = true } end
  table.sort(out, function(a, b) if a.me ~= b.me then return a.me end return a.char < b.char end)
  return out
end

-- the estimate for each category: { copper or nil, source, unknown }
function T.Estimates()
  local est = {}
  local level = int(C.Readable(C.Call("UnitLevel", "player"))) or 1
  local SB = ns.Spellbook
  if SB and SB.TrainingAt then
    local sum, n = 0, 0
    for l = level, level + T.LOOKAHEAD do
      for _, r in ipairs(SB:TrainingAt(l)) do if int(r.cost) then sum, n = sum + int(r.cost), n + 1 end end
    end
    est.training = n > 0 and { copper = sum, source = n .. " trainer options seen for your next levels (cost may change)" }
      or { unknown = "no trainer costs seen for your next levels yet" }
  end
  for _, fact in ipairs(ns.Leveling and ns.Leveling.FACTS or {}) do
    if fact.id == "riding-apprentice" then
      local g = tonumber(tostring(fact.text):match("for (%d+) gold"))
      if g then est.riding = { copper = g * 10000, source = "leveling guide: riding at " .. tostring(fact.minLevel) } end
    end
  end
  est.riding = est.riding or { unknown = "riding cost not in your guide data" }
  local res = 0
  for _, g in ipairs(ns.NexusGoals and ns.NexusGoals:Active() or {}) do res = math.max(res, int(g.reserveCopper) or 0) end
  est.gear = res > 0 and { copper = res, source = "your goals' reserve" } or { copper = 0, source = "no goal reserves gold" }
  local S = ns.Supply
  if S and S.Plan then
    local ok, plan = pcall(S.Plan)
    if ok and plan then
      local sum, unpriced = 0, 0
      for _, row in ipairs(plan.shoppingList or {}) do
        if row.total then sum = sum + row.total else unpriced = unpriced + 1 end
      end
      est.profession = { copper = sum, source = "supply plan shopping list", unpriced = unpriced > 0 and unpriced or nil }
    end
  end
  est.profession = est.profession or { unknown = "no supply plan" }
  est.repair = { unknown = "repair cost isn't known: set your own amount" }
  return est
end

function T.Budget(have)
  have = int(have) or int(C.Readable(C.Call("GetMoney"))) or 0
  local est, mine = T.Estimates(), T.Store().reserves
  local out = { have = have, rows = {}, held = 0, unknown = {} }
  for _, cat in ipairs(T.CATS) do
    local e = est[cat] or { unknown = "not estimated" }
    local row = { cat = cat }
    if mine[cat] then row.copper, row.source = mine[cat], "set by you"
    elseif e.copper then row.copper, row.source, row.unpriced = e.copper, e.source, e.unpriced
    else row.unknown = e.unknown out.unknown[#out.unknown + 1] = cat end
    out.held = out.held + (row.copper or 0)
    out.rows[#out.rows + 1] = row
  end
  -- the riding reserve only while you're below its level
  for _, fact in ipairs(ns.Leveling and ns.Leveling.FACTS or {}) do
    if fact.id == "riding-apprentice" and (int(C.Readable(C.Call("UnitLevel", "player"))) or 1) > (fact.minLevel or 0) + 10 then
      for _, row in ipairs(out.rows) do
        if row.cat == "riding" and row.source ~= "set by you" and row.copper then out.held = out.held - row.copper row.copper, row.source = 0, "past the riding level" end
      end
    end
  end
  out.free = have - out.held
  out.short = out.free < 0 and -out.free or nil
  return out
end

-- does a planned spend fit in what isn't kept? (no advice on what to buy)
function T.Fits(spend, have)
  spend = int(spend)
  if not (spend and spend >= 0) then return nil, "spend must be copper, 0 or more" end
  local b = T.Budget(have)
  local after = b.free - spend
  return { fits = after >= 0, after = after, short = after < 0 and -after or nil, unknown = b.unknown, budget = b }
end

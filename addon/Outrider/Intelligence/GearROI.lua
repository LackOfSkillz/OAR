-- Intelligence/GearROI.lua  (OI04-05 .. OI04-08)
-- Is a gear upgrade worth getting? Built on what Outrider already knows:
-- GearScore (role-weighted score against what you wear, usability), Nearby
-- (where an item comes from: drop, quest, vendor, object, crafted; alts'
-- items through Handoffs), Travel (trip times), XP pace (SessionXP) and the
-- goals' gold reserve. Pure functions over candidates; no store of its own.
--
-- OI04-05 baseline: each candidate gets its improvement (GearScore's % for
--   YOUR role weights: a role score, never a DPS claim), its slot, whether it
--   can be equipped now (class, armour/weapon type, level), how it binds, and
--   its source type: guaranteed (quest reward, vendor, crafted, alt, a listing)
--   or chance (a drop, an object).
-- OI04-06 time and risk: the trip (Travel) plus the activity (a quest: your
--   own quest time when known, else Journey's; a vendor or alt: a minute; a
--   drop: unknown unless a drop chance is given). With a chance p: the
--   expected tries 1/p and P(at least one in n) = 1 - (1-p)^n, assuming
--   independent rolls (stated); in a group of g, p/g for an item others can
--   roll on (stated). No drop ever gets a guaranteed time.
-- OI04-07 replacement horizon: the next eligible upgrade for the same slot
--   from known sources, and when you reach its level at your XP pace
--   (levels per hour from your sessions). That is the item's useful life;
--   unknown pace gives a range or "unknown". A future item is never treated as
--   owned (it only bounds the useful life), and an item never replaces itself.
-- OI04-08 utility: (improvement x useful hours) per hour spent getting it,
--   where gold counts as hours at your gold rate, or the candidate is out when
--   it costs more than you can spend above the reserve. Unknown time or life
--   gives no number and ranks after the known ones. Units are named.

local _, ns = ...
local C = ns.Compat
local R = { GUARANTEED = { quest = true, vendor = true, crafted = true, alt = true, auction = true, handoff = true },
  CHANCE = { drop = true, object = true }, SIMPLE_SECONDS = 60, DEFAULT_LIFE_LEVELS = 5 }
ns.GearROI = R

-- OI04-05: one candidate, normalized
function R.Baseline(c, opts)
  opts = opts or {}
  if type(c) ~= "table" or not tonumber(c.itemID) then return nil, "no item" end
  local kind = tostring(c.kind or c.source or "?")
  local out = { itemID = tonumber(c.itemID), name = c.name, pct = tonumber(c.pct), kind = kind, where = c.where,
    reqLevel = tonumber(c.reqLevel), price = tonumber(c.price or c.costCopper) }
  out.sourceType = R.GUARANTEED[kind] and "guaranteed" or R.CHANCE[kind] and "chance" or "unknown"
  local cmp = opts.compare or (ns.GearScore and ns.GearScore.Compare and ns.GearScore:Compare("item:" .. out.itemID))
  if type(cmp) == "table" then
    out.pct = out.pct or cmp.pct
    out.slot = cmp.slot
    out.usableNow = cmp.why == nil
    out.usableAt = cmp.future
    out.notUsable = cmp.why
  end
  local info = opts.info or C.ItemInfo(out.itemID)
  if info then out.bind = info.bindType == 1 and "on pickup" or info.bindType == 2 and "on equip" or info.bindType == 3 and "on use" or "none" end
  out.scoreNote = "role score from your stat weights, not a DPS figure"
  return out
end

-- OI04-06: acquisition time (seconds or nil) and chance facts
function R.Acquisition(b, opts)
  opts = opts or {}
  local a = { notes = {} }
  local trip = tonumber(opts.trip)
  if trip == nil and b.where and b.where.mapID and ns.Travel and ns.Travel.Point then
    local ok, t = pcall(function() return ns.Travel:TimeTo(ns.Travel:Prepare(), ns.Travel.Point(b.where.mapID, b.where.x, b.where.y)) end)
    if ok then trip = tonumber(t) end
  end
  a.trip = trip
  local act
  if b.kind == "quest" then act = tonumber(opts.questSeconds) or (ns.Journey and ns.Journey.QUEST_TIME) or 300
  elseif b.kind == "vendor" or b.kind == "alt" or b.kind == "handoff" or b.kind == "auction" then act = R.SIMPLE_SECONDS
  elseif b.kind == "crafted" then act = tonumber(opts.craftSeconds)
  elseif R.CHANCE[b.kind] then
    local p = tonumber(opts.dropChance)
    if p and p > 0 and p <= 1 then
      local g = math.max(1, tonumber(opts.groupSize) or 1)
      if g > 1 and not opts.personalLoot then p = p / g a.notes[#a.notes + 1] = "shared with your group: chance divided by " .. g end
      a.chance = p
      a.expectedTries = 1 / p
      a.notes[#a.notes + 1] = "assumes each try is an independent roll"
      if tonumber(opts.trySeconds) then act = a.expectedTries * opts.trySeconds a.timeIsExpected = true end
    elseif p == 0 then
      a.chance = 0
      a.notes[#a.notes + 1] = "it doesn't drop for you"
      a.impossible = true
    else
      a.notes[#a.notes + 1] = "drop chance unknown: no time can be given"
    end
    if opts.onlyWhileOnQuest then a.notes[#a.notes + 1] = "drops only while you have its quest" a.conditional = true end
    if opts.needsGroup and not opts.groupAvailable then a.notes[#a.notes + 1] = "needs a group: whether you'll find one is unknown" end
  end
  if trip and act and not a.impossible then a.seconds = trip + act end
  return a
end
function R.ChanceWithin(p, tries)
  if not (p and p > 0) then return 0 end
  return 1 - (1 - p) ^ tries
end

-- OI04-07: the next upgrade for the same slot, and when it becomes usable
function R.Replacement(b, pool, level, pace)
  local best
  for _, o in ipairs(pool or {}) do
    if o.itemID ~= b.itemID and o.slot == b.slot and (o.pct or 0) > (b.pct or 0) and (o.reqLevel or 0) > level then
      if not best or (o.reqLevel or 0) < (best.reqLevel or 0) then best = o end
    end
  end
  local out = { next = best }
  local levels = best and (best.reqLevel - level) or R.DEFAULT_LIFE_LEVELS
  out.levels = levels
  out.basis = best and "next known upgrade" or "no known upgrade: a typical span"
  if pace and pace > 0 then
    out.hours = levels / pace
    if not best then out.lo, out.hi = out.hours * 0.5, out.hours * 1.5 end
  else
    out.unknown = "your levelling pace isn't known yet"
  end
  return out
end

-- your levels per hour, from complete XP sessions (nil when unknown)
function R.Pace(sessions, xpPerLevel)
  local xp, secs = 0, 0
  for _, s in ipairs(sessions or {}) do
    if s.final == true and s.xpVerified == true and (tonumber(s.durationSeconds) or 0) >= 600 then
      xp, secs = xp + (s.xpEarned or 0), secs + s.durationSeconds
    end
  end
  if secs < 1800 or not (xpPerLevel and xpPerLevel > 0) then return nil end
  return (xp / xpPerLevel) / (secs / 3600)
end

-- OI04-08: utility, or nil and why; opts.spendable copper, opts.goldPerHour
function R.Utility(b, acq, rep, opts)
  opts = opts or {}
  if b.notUsable and not b.usableAt then return nil, "you can't use it: " .. tostring(b.notUsable) end
  if acq.impossible then return nil, "it can't drop for you" end
  local price = b.price or 0
  if price > 0 and opts.spendable and price > opts.spendable then return nil, "costs more than you can spend above your reserve" end
  if not acq.seconds then return nil, "time to get it unknown" end
  if not rep.hours then return nil, "how long you'd use it is unknown" end
  local hoursSpent = acq.seconds / 3600
  if price > 0 then
    if opts.goldPerHour and opts.goldPerHour > 0 then hoursSpent = hoursSpent + price / opts.goldPerHour
    else return nil, "costs gold and your gold rate is unknown" end
  end
  local gain = (b.pct or 0) / 100 * rep.hours
  return gain / math.max(hoursSpent, 1 / 60), "upgrade-hours (percent of your current item, times hours used) per hour spent"
end

-- rank candidates: known utilities first, best first; unknowns after, with why
function R.Rank(list)
  table.sort(list, function(a, b)
    if (a.utility ~= nil) ~= (b.utility ~= nil) then return a.utility ~= nil end
    if a.utility and b.utility and a.utility ~= b.utility then return a.utility > b.utility end
    return (a.pct or 0) > (b.pct or 0)
  end)
  return list
end

-- this character: Nearby's candidates, evaluated
function R:Mine()
  local N = ns.Nearby
  if not (N and N.Candidates) then return {} end
  local ok, cands = pcall(N.Candidates, N)
  if not ok or type(cands) ~= "table" then return {} end
  local level = tonumber(C.Readable(C.Call("UnitLevel", "player"))) or 1
  local maxXP = tonumber(C.Readable(C.Call("UnitXPMax", "player")))
  local pace = R.Pace(ns.SessionXP and ns.SessionXP.Merged and ns.SessionXP:Merged() or {}, maxXP)
  local copper = tonumber(C.Readable(C.Call("GetMoney"))) or 0
  local reserve = 0
  for _, g in ipairs(ns.NexusGoals and ns.NexusGoals:Active() or {}) do reserve = math.max(reserve, g.reserveCopper or 0) end
  local goldRate
  local L = ns.Ledger
  if L and L.Merged and ns.Forecasts and ns.Forecasts.Gold then
    local g = ns.Forecasts.Gold(L.Merged())
    goldRate = g and g.perHour > 0 and g.perHour or nil
  end
  local base = {}
  for _, c in ipairs(cands) do local b = R.Baseline(c) if b then base[#base + 1] = b end end
  for _, b in ipairs(base) do
    b.acq = R.Acquisition(b)
    b.rep = R.Replacement(b, base, level, pace)
    b.utility, b.utilityWhy = R.Utility(b, b.acq, b.rep, { spendable = copper - reserve, goldPerHour = goldRate })
  end
  return R.Rank(base)
end

-- ------------------------------------------------------------ Gear page (OI04-09)
-- "Worth getting?": each candidate against what you wear, with its cost, time,
-- chance, useful life, other options for the slot and the evidence. Buttons:
-- the existing Set waypoint, Keep on top and Hide this one (per character).
-- There is no buy button: buying stays in the auction house's own confirm
-- flow (GearShop / AHBuy). Works with no price and no companion.
function R.Store()
  local c = ns.db.char
  c.gearROI = ns.KeepTable(c.gearROI, "GearROI:char.gearROI") or {}
  c.gearROI.pinned = ns.KeepTable(c.gearROI.pinned, "GearROI:pinned") or {}
  c.gearROI.hidden = ns.KeepTable(c.gearROI.hidden, "GearROI:hidden") or {}
  return c.gearROI
end
local function hrs(h) if not h then return nil end return h < 1 and (math.floor(h * 60 + 0.5) .. " min") or string.format("%.1f h", h) end
local function mins(s) if not s then return nil end return s < 90 and (math.floor(s + 0.5) .. " s") or (math.floor(s / 60 + 0.5) .. " min") end

function R.Cards(list, refresh)
  local st = R.Store()
  local shown = {}
  for _, b in ipairs(list or {}) do if not st.hidden[b.itemID] then shown[#shown + 1] = b end end
  table.sort(shown, function(a, b)
    local pa, pb = st.pinned[a.itemID] and 1 or 0, st.pinned[b.itemID] and 1 or 0
    if pa ~= pb then return pa > pb end
    return false
  end)
  local out = {}
  for i, b in ipairs(shown) do
    if i > 5 then break end
    local tags = { { string.format("+%d%% vs what you wear", math.floor((b.pct or 0) + 0.5)), "good" },
      { b.sourceType == "chance" and "a chance (drop)" or b.sourceType == "guaranteed" and "guaranteed" or "source unclear", b.sourceType == "chance" and "warn" or "plain" } }
    if b.price and b.price > 0 then tags[#tags + 1] = { ns.Prices and ns.Prices.Money(b.price) or tostring(b.price), "gold" }
    elseif b.kind == "vendor" or b.kind == "auction" then tags[#tags + 1] = { "price unknown", "warn" }
    else tags[#tags + 1] = { "no gold", "plain" } end
    tags[#tags + 1] = { b.acq and b.acq.seconds and ("about " .. mins(b.acq.seconds)) or "time unknown", "plain" }
    tags[#tags + 1] = { b.rep and b.rep.hours and ("useful ~" .. hrs(b.rep.hours)) or "useful life unknown", "plain" }
    if st.pinned[b.itemID] then tags[#tags + 1] = { "kept on top", "gold" } end
    local parts = {}
    if b.utility then parts[#parts + 1] = string.format("Worth %.1f %s.", b.utility, b.utilityWhy or "")
    elseif b.utilityWhy then parts[#parts + 1] = "Not ranked: " .. b.utilityWhy .. "." end
    for _, n in ipairs(b.acq and b.acq.notes or {}) do parts[#parts + 1] = n .. "." end
    if b.rep and b.rep.next then parts[#parts + 1] = "Next upgrade for this slot: " .. tostring(b.rep.next.name) .. " at level " .. tostring(b.rep.next.reqLevel) .. "."
    elseif b.rep and b.rep.unknown then parts[#parts + 1] = b.rep.unknown .. "." end
    local alts = {}
    for _, o in ipairs(list) do if o ~= b and o.slot == b.slot and #alts < 2 then alts[#alts + 1] = tostring(o.name) end end
    if #alts > 0 then parts[#parts + 1] = "Other options for this slot: " .. table.concat(alts, ", ") .. "." end
    parts[#parts + 1] = "(" .. b.scoreNote .. ")"
    local actions = {}
    local w = b.where
    if type(w) == "table" and w.mapID and w.x then
      actions[#actions + 1] = { "Set waypoint", function() ns.Waypoints:Set(w.mapID, w.x, w.y, tostring(b.name)) end, "Sets the arrow to where you get it." }
    end
    local id = b.itemID
    actions[#actions + 1] = { st.pinned[id] and "Unpin" or "Keep on top", function() st.pinned[id] = not st.pinned[id] or nil if refresh then refresh() end end,
      "Keep this one at the top of the list." }
    actions[#actions + 1] = { "Hide this one", function() st.hidden[id] = time() if refresh then refresh() end end,
      "Hide this suggestion for this character." }
    out[#out + 1] = { itemID = id, title = tostring(b.name), tags = tags, line = table.concat(parts, " "), actions = actions, highlight = i == 1 }
  end
  return out
end

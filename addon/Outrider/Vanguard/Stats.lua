-- Vanguard/Stats.lua
-- VG02-02: gear stats from what a profile shows, kept apart from what the
-- game says directly. Each worn item's stats come from the game's item stat
-- API (GearScore.Stats, C_Item.GetItemStats); they are added up per stat as a
-- range { lo, hi }:
--   * a known item adds its stats to both ends;
--   * an empty slot adds nothing (known zero);
--   * a slot we couldn't read (pending, unreadable, unavailable) or an item
--     whose stats didn't come back makes the top end open (hi = nil): the
--     real total is at least lo, maybe more;
--   * an enchant's bonus isn't in the item stats: a known flat enchant from
--     the researched table (Data/VanguardFacts.lua, unverified) is added;
--     any other enchant opens the top end.
-- Derived values are labeled "derived" and never written over an observation.

local _, ns = ...
local C = ns.Compat
ns.Vanguard = ns.Vanguard or {}
local S = { VERSION = 1 }
ns.Vanguard.Stats = S

local function readNum(v)
  v = C.Readable(v)
  if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
end

-- default reader: the game's item stats for a link (a table, or nil)
function S.ItemStats(link)
  if not link then return nil end
  if ns.GearScore and ns.GearScore.Stats then
    local t = ns.GearScore.Stats(link)
    if type(t) == "table" and next(t) ~= nil then return t end
    return nil
  end
end

-- profile: a Vanguard MemberProfile. reader(link) -> stat table or nil.
function S.Derive(profile, reader)
  reader = reader or S.ItemStats
  local out = { version = S.VERSION, source = "derived", rev = profile and profile.rev, totals = {}, open = {},
    slots = {}, enchants = { known = 0, none = 0 }, statsUnread = 0 }
  local totals = out.totals
  local function add(token, v)
    local t = totals[token]
    if not t then t = { lo = 0, hi = 0 } totals[token] = t end
    t.lo = t.lo + v
    if t.hi then t.hi = t.hi + v end
  end
  for _, s in ipairs(profile and profile.slots or {}) do
    local row = { slot = s.slot, state = s.state }
    out.slots[#out.slots + 1] = row
    if s.state == "known" then
      local stats = reader(s.link or s.itemId)
      if type(stats) == "table" then
        row.stats = {}
        for token, v in pairs(stats) do
          local n = readNum(v)
          if n and type(token) == "string" then
            row.stats[token] = n
            add(token, n)
          end
        end
      else
        row.unread = true
        out.statsUnread = out.statsUnread + 1
        out.open[#out.open + 1] = s.slot
      end
      if s.enchant then
        out.enchants.known = out.enchants.known + 1
        row.enchant = s.enchant
        local e = ns.Vanguard.Facts and ns.Vanguard.Facts.Enchant(s.enchant)
        if e and type(e.stats) == "table" and next(e.stats) and not e.proc then
          -- a researched flat bonus (Data/VanguardFacts.lua): counted, labeled
          row.enchantStats = e.stats
          for token, v in pairs(e.stats) do if type(v) == "number" then add(token, v) end end
          out.enchants.counted = (out.enchants.counted or 0) + 1
        else
          out.open[#out.open + 1] = s.slot
        end
      elseif row.stats then
        out.enchants.none = out.enchants.none + 1
      end
    elseif s.state ~= "empty" then
      out.open[#out.open + 1] = s.slot
    end
  end
  out.complete = #out.open == 0
  -- any open slot opens every total, since we can't say which stats it holds
  if not out.complete then for _, t in pairs(totals) do t.hi = nil end end
  return out
end

-- range of one indicator from derived stats: { lo, hi } (hi nil = open)
function S.Range(derived, ind)
  if ind.slot then
    for _, row in ipairs(derived.slots) do
      if row.slot == ind.slot then
        if row.state == "empty" then return { lo = 0, hi = 0, empty = true } end
        if row.stats then
          local v = row.stats[ind.stat] or 0
          return { lo = v, hi = v }
        end
        return { lo = 0, hi = nil }
      end
    end
    return { lo = 0, hi = nil }
  end
  local lo, hi = 0, 0
  for _, token in ipairs(ind.stats or { ind.stat }) do
    local t = derived.totals[token]
    if t then
      lo = lo + t.lo
      if hi and t.hi then hi = hi + t.hi else hi = nil end
    elseif not derived.complete then
      hi = nil
    end
  end
  return { lo = lo, hi = hi }
end

function S.RangeText(r, unit)
  if not r then return "unknown" end
  local function f(n) return (n == math.floor(n)) and tostring(n) or string.format("%.1f", n) end
  if r.empty then return "empty slot" end
  if r.hi == nil then return "at least " .. f(r.lo) .. (unit == "dps" and " dps" or "") end
  if r.hi == r.lo then return f(r.lo) .. (unit == "dps" and " dps" or "") end
  return f(r.lo) .. " to " .. f(r.hi)
end

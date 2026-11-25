-- Intelligence/Supply.lua  (OI05-12 supply graph, OI05-13 reservations and transfers)
-- The full allocator the early Quartermaster (OI04-11) pointed at. Pure core:
--   Expand(goals, makes, stock, me) walks each goal's item through the
--   recipes you know (makes[itemID] = { key, name, makes, reagents }) into a
--   dependency graph: what your own bags and bank cover, what an alt could
--   mail you, what you'd craft (intermediates before what needs them) and
--   what's left to buy.
--     - one shared pool: a unit is allocated once, across all goals
--     - crafts round up (ceil(need / per craft)); the extra goes back in the
--       pool for the next need
--     - a recipe loop (A needs B needs A) is reported as a cycle and not
--       expanded further
--     - an alt on another realm or faction can't mail you: excluded with the
--       reason; a count older than STALE_DAYS is flagged; whether an alt's
--       item is soulbound isn't recorded, so each transfer says to check
--   Goals in order: an explicit override first, then priority (lower first),
--   then when it was made.
--   Reservations: account-wide goals (ns.db.global.supply.reservations), each
--   { id, goal, itemID, count, priority, override, char, at }; releasing one
--   marks it released (kept, never deleted). Plan() adds your craft queue as
--   a goal (priority 50) and returns transfers, a shopping list with prices
--   where known, and the crafting sequence. Advice only: Outrider never mails,
--   crafts or buys.

local _, ns = ...
local S = { STALE_DAYS = 7, MAX_DEPTH = 8, QUEUE_PRIORITY = 50 }
ns.Supply = S

local function realm(key) return type(key) == "string" and key:match("%-(.+)$") or nil end

-- the recipes this character knows that say what they make
function S.Makes()
  local out = {}
  for prof, p in pairs(ns.db and ns.db.char.professions or {}) do
    for id, r in pairs(type(p) == "table" and p.recipes or {}) do
      if type(r) == "table" and tonumber(r.product) and r.reagents and next(r.reagents) and r.learned ~= false then
        local pid = tonumber(r.product)
        if not out[pid] then
          out[pid] = { key = prof .. ":" .. tostring(id), prof = prof, name = r.name, makes = tonumber(r.makes) or 1,
            makesKnown = tonumber(r.makes) ~= nil, reagents = r.reagents }
        end
      end
    end
  end
  return out
end

-- stock for these items: mine (bags, bank, mail) and each alt with realm, faction, age
function S.Stock(ids)
  local inv = ns.db.global.inventory or {}
  local chars = ns.db.raw and ns.db.raw.chars or {}
  local out = {}
  for id in pairs(ids) do
    local s = { mine = 0, alts = {} }
    for key, data in pairs(inv) do
      local n = 0
      for _, place in ipairs({ "bags", "bank", "mail" }) do n = n + (type(data[place]) == "table" and tonumber(data[place][id]) or 0) end
      if n > 0 then
        if key == ns.db.key then s.mine = s.mine + n
        else
          local meta = type(chars[key]) == "table" and chars[key].meta or {}
          s.alts[#s.alts + 1] = { char = key, count = n, at = tonumber(data.at), realm = realm(key), faction = meta.faction }
        end
      end
    end
    table.sort(s.alts, function(a, b) if a.count ~= b.count then return a.count > b.count end return a.char < b.char end)
    out[id] = s
  end
  return out
end

local function order(goals)
  local list = {}
  for i, g in ipairs(goals) do list[i] = g g._i = i end
  table.sort(list, function(a, b)
    if (a.override and 1 or 0) ~= (b.override and 1 or 0) then return a.override == true end
    if (a.priority or 100) ~= (b.priority or 100) then return (a.priority or 100) < (b.priority or 100) end
    if (a.at or 0) ~= (b.at or 0) then return (a.at or 0) < (b.at or 0) end
    return a._i < b._i
  end)
  return list
end

-- me = { realm, faction }; now for staleness
function S.Expand(goals, makes, stock, me, now)
  me, now, makes = me or {}, now or time(), makes or {}
  local pool = {}
  for id, s in pairs(stock or {}) do
    pool[id] = { mine = s.mine or 0, alts = {} }
    for i, a in ipairs(s.alts or {}) do pool[id].alts[i] = { char = a.char, count = a.count or 0, at = a.at, realm = a.realm, faction = a.faction } end
  end
  local out = { goals = {}, transfers = {}, shopping = {}, sequence = {}, cycles = {}, excluded = {}, notes = {} }
  local tKey, excludedSeen = {}, {}
  local function slot(id) pool[id] = pool[id] or { mine = 0, alts = {} } return pool[id] end

  local function need(id, count, path, depth, g)
    local s = slot(id)
    local mine = math.min(count, s.mine)
    s.mine = s.mine - mine
    local rem = count - mine
    for _, a in ipairs(s.alts) do
      if rem <= 0 then break end
      local why = (me.realm and a.realm and a.realm ~= me.realm and "another realm")
        or (me.faction and a.faction and a.faction ~= me.faction and "the other faction") or nil
      if why then
        if not excludedSeen[a.char .. why] then excludedSeen[a.char .. why] = true out.excluded[#out.excluded + 1] = { char = a.char, why = why } end
      elseif a.count > 0 then
        local take = math.min(rem, a.count)
        a.count, rem = a.count - take, rem - take
        local k = a.char .. "|" .. id
        local t = tKey[k]
        if not t then
          t = { from = a.char, itemID = id, count = 0, stale = a.at and (now - a.at) > S.STALE_DAYS * 86400 or nil,
            check = "check it isn't soulbound, then mail it yourself" }
          tKey[k] = t
          out.transfers[#out.transfers + 1] = t
        end
        t.count = t.count + take
        g.fromAlts = g.fromAlts + take
      end
    end
    if id == g.itemID then g.fromMine = g.fromMine + mine end
    if rem <= 0 then return end
    local r = makes[id]
    if r and path[id] then
      out.cycles[#out.cycles + 1] = { itemID = id, goal = g.goal }
    elseif r and depth < S.MAX_DEPTH then
      local crafts = math.ceil(rem / r.makes)
      local extra = crafts * r.makes - rem
      path[id] = true
      for reagent, per in pairs(r.reagents) do need(tonumber(reagent) or reagent, per * crafts, path, depth + 1, g) end
      path[id] = nil
      out.sequence[#out.sequence + 1] = { key = r.key, name = r.name, itemID = id, crafts = crafts, goal = g.goal,
        yieldUnknown = not r.makesKnown or nil }
      if extra > 0 then s.mine = s.mine + extra end
      g.crafted = g.crafted + (id == g.itemID and rem or 0)
      return
    end
    out.shopping[id] = (out.shopping[id] or 0) + rem
    g.buy = g.buy + rem
  end

  for _, goal in ipairs(order(goals or {})) do
    local g = { goal = goal.goal, itemID = goal.itemID, count = math.floor(goal.count or 0), fromMine = 0, fromAlts = 0,
      crafted = 0, buy = 0, id = goal.id }
    if g.count > 0 then need(goal.itemID, g.count, {}, 0, g) end
    out.goals[#out.goals + 1] = g
  end
  if #out.transfers > 0 then out.notes[#out.notes + 1] = "whether an alt's item is soulbound isn't recorded: check before mailing" end
  return out
end

-- reservations
function S.Store()
  local g = ns.db.global
  g.supply = ns.KeepTable(g.supply, "Supply:global.supply") or {}
  g.supply.reservations = ns.KeepTable(g.supply.reservations, "Supply:reservations") or {}
  return g.supply
end

function S.Reserve(goal, itemID, count, priority, override)
  itemID, count = tonumber(itemID), tonumber(count)
  if not (type(goal) == "string" and goal ~= "" and itemID and count and count > 0) then return nil, "goal, item and a count above 0" end
  local st = S.Store()
  st.next = (st.next or 0) + 1
  local r = { id = st.next, goal = goal:sub(1, 60), itemID = itemID, count = math.floor(count), priority = tonumber(priority) or 100,
    override = override == true or nil, char = ns.db.key, at = time() }
  st.reservations[#st.reservations + 1] = r
  return r
end

function S.Release(id)
  for _, r in ipairs(S.Store().reservations) do
    if r.id == id and not r.released then r.released = time() return true end
  end
  return false
end

function S.Active()
  local out = {}
  for _, r in ipairs(S.Store().reservations) do if not r.released then out[#out + 1] = r end end
  return out
end

function S.Plan()
  local goals = {}
  for _, r in ipairs(S.Active()) do goals[#goals + 1] = r end
  local makes = S.Makes()
  local CQ = ns.Modules:Get("CraftQueue")
  if CQ and CQ.enabled and CQ.Settings then
    for key, n in pairs(CQ:Settings().queue or {}) do
      local r = CQ.Find and CQ:Find(key)
      if r then
        for item, per in pairs(r.reagents) do
          goals[#goals + 1] = { goal = "your craft queue", itemID = tonumber(item), count = per * n, priority = S.QUEUE_PRIORITY }
        end
      end
    end
  end
  local ids = {}
  local function mark(id, depth)
    if ids[id] or depth > S.MAX_DEPTH then return end
    ids[id] = true
    local r = makes[id]
    if r then for reagent in pairs(r.reagents) do mark(tonumber(reagent), depth + 1) end end
  end
  for _, g in ipairs(goals) do mark(g.itemID, 0) end
  local meta = ns.db.char.meta or {}
  local res = S.Expand(goals, makes, S.Stock(ids), { realm = realm(ns.db.key), faction = meta.faction })
  local list = {}
  for id, n in pairs(res.shopping) do
    local price = ns.Prices and ns.Prices.Get and (ns.Prices:Get(id)) or nil
    list[#list + 1] = { itemID = id, count = n, each = tonumber(price), total = tonumber(price) and math.floor(price * n) or nil }
  end
  table.sort(list, function(a, b) return a.itemID < b.itemID end)
  res.shoppingList = list
  return res
end

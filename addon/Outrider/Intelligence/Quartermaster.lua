-- Intelligence/Quartermaster.lua  (OI04-11: early reservations)
-- What you're keeping, and for what: materials your craft queue needs, items
-- and gold you hold on purpose, and the gold your goals reserve. Shown as
-- indicators (an item's tooltip says "Held: 5 for your craft queue", gear
-- advice only spends gold that isn't held); nothing is blocked or moved, and
-- selling or mailing a held item stays your choice (a full allocator comes
-- later, OI05).
--   Holds: craft queue needs (CraftQueue:Needed), explicit item holds
--     (char.quartermaster.items[itemID] = { count, purpose }), the goals'
--     reserve, and an explicit gold hold (char.quartermaster.gold).
--   Allocate(holds, stock) is pure: each unit is counted once, across all
--     holds, from your own bags and bank first, then your alts (saved
--     inventories, with how old each count is); a count older than STALE_DAYS
--     is flagged stale. What a hold can't cover is "short".

local _, ns = ...
local Q = { STALE_DAYS = 7 }
ns.Quartermaster = Q

function Q.Store()
  local c = ns.db.char
  c.quartermaster = ns.KeepTable(c.quartermaster, "Quartermaster:char.quartermaster") or {}
  c.quartermaster.items = ns.KeepTable(c.quartermaster.items, "Quartermaster:items") or {}
  return c.quartermaster
end

-- every hold: { itemID, count, purpose } in priority order (explicit first)
function Q.Holds()
  local out = {}
  for id, h in pairs(Q.Store().items) do
    if tonumber(id) and type(h) == "table" and tonumber(h.count) and h.count > 0 then
      out[#out + 1] = { itemID = tonumber(id), count = math.floor(h.count), purpose = tostring(h.purpose or "kept by you"), explicit = true }
    end
  end
  local CQ = ns.Modules:Get("CraftQueue")
  if CQ and CQ.enabled and CQ.Needed then
    local ok, need = pcall(CQ.Needed, CQ)
    for id, n in pairs(ok and type(need) == "table" and need or {}) do
      if tonumber(id) and n > 0 then out[#out + 1] = { itemID = tonumber(id), count = n, purpose = "your craft queue" } end
    end
  end
  table.sort(out, function(a, b)
    if (a.explicit and 1 or 0) ~= (b.explicit and 1 or 0) then return a.explicit == true end
    return a.itemID < b.itemID
  end)
  return out
end

-- stock = { [itemID] = { mine = n, alts = { {char, count, at} } } }; now for staleness
function Q.Allocate(holds, stock, now)
  now = now or time()
  local left = {}
  for id, s in pairs(stock or {}) do
    left[id] = { mine = s.mine or 0, alts = {} }
    for i, a in ipairs(s.alts or {}) do left[id].alts[i] = { char = a.char, count = a.count or 0, at = a.at } end
  end
  local out = {}
  for _, h in ipairs(holds or {}) do
    local s = left[h.itemID] or { mine = 0, alts = {} }
    left[h.itemID] = s
    local need = h.count
    local fromMine = math.min(need, s.mine)
    s.mine = s.mine - fromMine
    need = need - fromMine
    local fromAlts, stale = {}, false
    for _, a in ipairs(s.alts) do
      if need <= 0 then break end
      local take = math.min(need, a.count)
      if take > 0 then
        a.count = a.count - take
        need = need - take
        local old = a.at and (now - a.at) > Q.STALE_DAYS * 86400
        if old then stale = true end
        fromAlts[#fromAlts + 1] = { char = a.char, count = take, stale = old or nil }
      end
    end
    out[#out + 1] = { itemID = h.itemID, purpose = h.purpose, count = h.count, fromMine = fromMine, fromAlts = fromAlts,
      short = need, stale = stale or nil }
  end
  return out, left
end

-- live stock from the account-wide inventory (Inventory module)
function Q.Stock(ids)
  local inv = ns.db.global.inventory or {}
  local me = ns.db.key
  local out = {}
  for id in pairs(ids) do
    local s = { mine = 0, alts = {} }
    for key, data in pairs(inv) do
      local n = 0
      for _, place in ipairs({ "bags", "bank", "mail" }) do n = n + (data[place] and tonumber(data[place][id]) or 0) end
      if n > 0 then
        if key == me then s.mine = s.mine + n else s.alts[#s.alts + 1] = { char = key, count = n, at = tonumber(data.at) } end
      end
    end
    table.sort(s.alts, function(a, b) return a.count > b.count end)
    out[id] = s
  end
  return out
end

function Q.Current()
  local holds = Q.Holds()
  local ids = {}
  for _, h in ipairs(holds) do ids[h.itemID] = true end
  return Q.Allocate(holds, Q.Stock(ids))
end

-- the tooltip line for an item, or nil
function Q.Line(itemID)
  local list = Q.Current()
  local parts, stale = {}, false
  for _, a in ipairs(list) do
    if a.itemID == itemID then
      parts[#parts + 1] = string.format("%d for %s%s", a.count, a.purpose, a.short > 0 and string.format(" (%d short)", a.short) or "")
      if a.stale then stale = true end
    end
  end
  if #parts == 0 then return nil end
  return "Held: " .. table.concat(parts, "; ") .. (stale and " (an alt's count is over a week old)" or "")
end

-- gold held: the goals' reserve plus an explicit hold
function Q.GoldHeld()
  local r = 0
  for _, g in ipairs(ns.NexusGoals and ns.NexusGoals:Active() or {}) do r = math.max(r, g.reserveCopper or 0) end
  local g = Q.Store().gold
  return r + (type(g) == "table" and tonumber(g.copper) or 0)
end

function Q.HoldItem(itemID, count, purpose)
  if not (tonumber(itemID) and tonumber(count)) then return false end
  Q.Store().items[tonumber(itemID)] = count > 0 and { count = math.floor(count), purpose = purpose } or nil
  return true
end

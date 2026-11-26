-- VG01-10: Group check under load. A 40-player raid, gear details arriving
-- late, 100 canceled scans and 200 roster changes: timers, requests, queue
-- and cache stay bounded, and no answer lands on the wrong member.
local T, mock = ...

local function set(game, k, v) game.base[k] = v rawset(game.env, k, v) end

local function raid(n)
  local units = {}
  for i = 1, n do
    units["raid" .. i] = { name = "R" .. i, player = true, guid = string.format("Player-1-%08d", i), level = 60,
      class = ({ "WARRIOR", "PRIEST", "MAGE", "ROGUE", "DRUID" })[(i % 5) + 1], subgroup = math.floor((i - 1) / 5) + 1 }
  end
  return units
end

local function start(n)
  local game = mock.new({ class = "HUNTER", level = 60 })
  game.units = raid(n or 40)
  local ns = game:loadAddon()
  game:login()
  game.inRaid = true
  game.asked = {}
  set(game, "GetNumGroupMembers", function() local c = 0 for k in pairs(game.units) do if k:match("^raid") then c = c + 1 end end return c end)
  set(game, "UnitIsUnit", function(a, b) return a == b or (b == "player" and a == "raid1") end)
  set(game, "GetRaidRosterInfo", function(i) local d = game.units["raid" .. i] if d then return d.name, 0, d.subgroup end end)
  set(game, "UnitGroupRolesAssigned", function() return "NONE" end)
  set(game, "CanInspect", function(u) return game.units[u] ~= nil end)
  set(game, "UnitIsConnected", function() return true end)
  set(game, "NotifyInspect", function(u) game.asked[#game.asked + 1] = u end)
  -- every item is new to the client: details arrive later
  set(game, "GetInventoryItemLink", function(u, slot)
    local d = game.units[u]
    if d and (slot == 1 or slot == 16) then return string.format("|Hitem:%d::::::::60:::::|h[Item %d]|h", 5000 + slot, slot) end
  end)
  game.items = {}
  ns.Modules:SetEnabled("Vanguard", true)
  return game, ns, ns.VanguardModule
end

-- answer whatever the broker is waiting on, the way the server would
local function serve(game, ns, steps)
  for _ = 1, steps do
    local cur = ns.InspectBroker.cur
    if cur then game:fire("INSPECT_READY", cur.guid) end
    game:advance(ns.InspectBroker.GAP + 0.05)
  end
end

T.describe("vanguard under load (VG01-10)", function()
  T.it("a 40-player raid scan finishes with one request at a time and bounded timers", function()
    local game, ns, M = start(40)
    local before = ns.Timer.count
    local scan = M:Scan()
    T.eq(scan.total, 39, "you plus 39 inspected")
    local maxTimers = 0
    for _ = 1, 45 do
      local cur = ns.InspectBroker.cur
      if cur then game:fire("INSPECT_READY", cur.guid) end
      game:advance(ns.InspectBroker.GAP + 0.05)
      maxTimers = math.max(maxTimers, ns.Timer.count - before)
    end
    T.eq(scan.state, "done")
    T.eq(scan.done, 39)
    T.eq(#game.asked, 39, "each member asked exactly once")
    T.ok(maxTimers <= 4, "at most a few timers at once, got " .. maxTimers)
    T.ok(ns.InspectBroker.stats.maxQueue <= ns.InspectBroker.QUEUE_MAX)
    T.ok(ns.Vanguard.Cache:Count() <= ns.Vanguard.Cache.MAX)
    -- each profile belongs to the member it was read from
    for key, p in pairs(ns.Vanguard.Cache.entries) do T.eq(p.key, key) end
    -- late item details: pending until the client has them, then filled in
    local p = ns.Vanguard.Cache:Get("Player-1-00000007")
    T.eq(p.count.pending, 2)
    game.items[5001] = { name = "Item 1", quality = 3, ilvl = 58 }
    game.items[5016] = { name = "Item 16", quality = 4, ilvl = 62 }
    game:fire("GET_ITEM_INFO_RECEIVED", 5001, true)
    game:advance(0.6)
    T.eq(p.count.pending, 0, "filled in when the game says the item arrived")
    T.eq(p.itemLevel.value, 60)
    for _, h in ipairs(ns.Events.handlers.GET_ITEM_INFO_RECEIVED or {}) do
      T.ok(h.owner ~= M, "stops listening once nothing is loading")
    end
    game:advance(60)
    T.ok(ns.Timer.count - before <= 1, "nothing keeps running afterwards")
    T.ok(ns.InspectBroker:Idle())
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("100 canceled scans leave no requests, timers or queue behind", function()
    local game, ns, M = start(10)
    local before = ns.Timer.count
    for i = 1, 100 do
      M:Scan()
      if i % 3 == 0 then game:advance(0.5) end
      M:Cancel("test " .. i)
    end
    T.ok(ns.InspectBroker:Idle())
    T.eq(ns.InspectBroker.listening, false)
    game:advance(30)
    T.ok(ns.Timer.count - before <= 1, "timers bounded, got " .. (ns.Timer.count - before))
    T.ok(#game.asked <= 100, "at most one request per started scan")
    -- a late answer for any of them stores nothing
    for i = 2, 10 do game:fire("INSPECT_READY", string.format("Player-1-%08d", i)) end
    T.eq(ns.Vanguard.Cache:Count(), 1, "only your own profile")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("200 roster changes during scans: never a stale member, never more than the group", function()
    local game, ns, M = start(20)
    local before = ns.Timer.count
    local nextId = 1000
    for i = 1, 200 do
      if i % 10 == 1 then M:Scan() end
      -- someone leaves and someone new joins in the same raid slot
      local slot = "raid" .. ((i % 19) + 2)
      nextId = nextId + 1
      game.units[slot] = { name = "N" .. nextId, player = true, guid = string.format("Player-1-%08d", nextId), level = 60, class = "MAGE", subgroup = 1 }
      game:fire("GROUP_ROSTER_UPDATE")
      serve(game, ns, 1)
    end
    serve(game, ns, 25)
    T.ok(ns.InspectBroker:Idle())
    local snap = M.snap
    for key, p in pairs(ns.Vanguard.Cache.entries) do
      T.ok(snap.byKey[key], "cached member is still in the group: " .. key)
      T.eq(p.key, key)
    end
    T.ok(ns.Vanguard.Cache:Count() <= snap.size)
    T.ok(ns.InspectBroker.stats.maxQueue <= ns.InspectBroker.QUEUE_MAX)
    game:advance(60)
    T.ok(ns.Timer.count - before <= 1, "timers bounded, got " .. (ns.Timer.count - before))
    T.eq(#ns.Errors.list, 0)
  end)
end)

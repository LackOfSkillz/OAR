-- Vanguard VG06: release audits as tests. Restricted APIs and events,
-- secrets, what reaches saved data with every Vanguard feature used, the
-- data packs untouched, performance budgets on the mock, and a clean
-- lifecycle (no handlers or timers left when it's off).
local T, mock = ...

local function set(game, k, v) game.base[k] = v rawset(game.env, k, v) end

local function read(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local FILES = { "Modules/Vanguard.lua", "Core/InspectBroker.lua", "Vanguard/Observation.lua", "Vanguard/Roster.lua",
  "Vanguard/Profile.lua", "Vanguard/Cache.lua", "Vanguard/Roles.lua", "Vanguard/Stats.lua", "Vanguard/Adequacy.lua",
  "Vanguard/Utility.lua", "Vanguard/Prep.lua", "Vanguard/Catalog.lua", "Vanguard/Access.lua", "Vanguard/Readiness.lua",
  "Vanguard/Assess.lua", "Vanguard/Plan.lua", "Vanguard/WhatIf.lua", "Vanguard/Share.lua", "Vanguard/Runs.lua",
  "Vanguard/Forecast.lua" }

local function raid(n)
  local units = {}
  for i = 1, n do
    units["raid" .. i] = { name = "R" .. i, player = true, guid = string.format("Player-1-%08d", i), level = 60,
      class = ({ "WARRIOR", "PRIEST", "MAGE", "ROGUE", "DRUID", "HUNTER", "PALADIN", "SHAMAN", "WARLOCK" })[(i % 9) + 1],
      subgroup = math.floor((i - 1) / 5) + 1, role = (i % 9 == 0) and "TANK" or "NONE" }
  end
  return units
end

local function start(n)
  local game = mock.new({ class = "HUNTER", level = 60 })
  game.units = raid(n or 40)
  local ns = game:loadAddon()
  game:login()
  game.inRaid = true
  set(game, "GetNumGroupMembers", function() local c = 0 for k in pairs(game.units) do if k:match("^raid") then c = c + 1 end end return c end)
  set(game, "UnitIsUnit", function(a, b) return a == b or (b == "player" and a == "raid1") end)
  set(game, "GetRaidRosterInfo", function(i) local d = game.units["raid" .. i] if d then return d.name, 0, d.subgroup end end)
  set(game, "UnitGroupRolesAssigned", function(u) local d = game.units[u] return d and d.role or "NONE" end)
  set(game, "CanInspect", function(u) return game.units[u] ~= nil end)
  set(game, "UnitIsConnected", function() return true end)
  set(game, "NotifyInspect", function() end)
  set(game, "GetInventoryItemLink", function(u, slot)
    local d = game.units[u]
    if d and (slot == 1 or slot == 16) then return string.format("|Hitem:%d::::::::60:::::|h[Item %d]|h", 5000 + slot, slot) end
  end)
  game.items = { [5001] = { name = "Item 1", quality = 3, ilvl = 58 }, [5016] = { name = "Item 16", quality = 4, ilvl = 62 } }
  game.itemStats = { [5001] = { ITEM_MOD_STAMINA_SHORT = 20 }, [5016] = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 40 } }
  ns.Modules:SetEnabled("Vanguard", true)
  return game, ns, ns.Vanguard, ns.VanguardModule
end

T.describe("vanguard release audits (VG06)", function()
  T.it("no restricted events or APIs anywhere in Vanguard's code", function()
    for _, f in ipairs(FILES) do
      local s = read("addon/Outrider/" .. f)
      T.ok(s, "read " .. f)
      if s then
        T.ok(not s:find("COMBAT_LOG_EVENT"), f .. ": no combat log")
        T.ok(not s:find("CombatLogGetCurrentEventInfo"), f .. ": no combat log reads")
        for _, api in ipairs({ "CastSpell", "TargetUnit", "InviteUnit", "UninviteUnit", "SetRaidSubgroup", "SwapRaidSubgroup",
          "SendChatMessage", "UseAction", "RunMacro", "SetRaidTarget", "ConvertToRaid", "PromoteToLeader" }) do
          T.ok(not s:find(api .. "%s*%("), f .. ": no " .. api)
        end
      end
    end
  end)

  T.it("every Vanguard feature used, debug on: saved data holds no names, GUIDs or other players' gear", function()
    local game, ns, V, M = start(10)
    ns.Slash:Run("debug on")
    M:Scan()
    for _ = 1, 15 do
      local cur = ns.InspectBroker.cur
      if cur then game:fire("INSPECT_READY", cur.guid) end
      game:advance(ns.InspectBroker.GAP + 0.05)
    end
    M:SetRole("Player-1-00000003", "HEALER")
    ns.Slash:Run("prep add bring a cloak")
    ns.Slash:Run("vgboss Ragnaros dispel_magic")
    M:Settings().instance = "Molten Core"
    M:Assessment("Molten Core")
    M:ReportText("Molten Core", true)
    M:Hypo(true)
    M:HypoOptimize()
    V.Share.Receive({ v = 1, seq = 100, exp = 600, role = "TANK" }, "R2", "RAID", game.env.time())
    set(game, "IsInInstance", function() return true, "raid" end)
    set(game, "GetInstanceInfo", function() return "Molten Core" end)
    M:RunCheck(1000)
    V.Runs.EncounterStart(V.Runs.Store(), 663, "Lucifron", 1100)
    V.Runs.EncounterEnd(V.Runs.Store(), 663, "Lucifron", 1, 1200)
    ns.db.global.census = nil -- Census is a separate, older feature (D27 scope note)
    local blob = game:logout()
    for i = 2, 10 do
      T.eq(blob:find(string.format("Player-1-%08d", i), 1, true), nil, "no GUID " .. i)
      T.eq(blob:find("\"R" .. i .. "\"", 1, true), nil, "no name " .. i)
      T.eq(blob:find("R" .. i .. "-", 1, true), nil, "no name-realm " .. i)
    end
    T.eq(blob:find("Item 16", 1, true), nil, "no inspected item names")
    T.eq(blob:find("Hitem:5016", 1, true), nil, "no inspected links")
    T.ok(blob:find("bring a cloak", 1, true), "your own checklist item is saved (yours)")
    T.ok(blob:find("Lucifron", 1, true), "your own run is saved (a boss name, not a player)")
  end)

  T.it("the data packs are read, never changed", function()
    local _, ns, V, M = start(5)
    local before = {}
    for _, e in ipairs(ns.Data:All("dungeon")) do before[e.name] = e.min .. ":" .. tostring(e.max) .. ":" .. tostring(e.size) .. ":" .. tostring(e.verified) end
    local spells = 0
    for _, book in pairs(ns.SpellInfo) do if type(book) == "table" then for _ in pairs(book) do spells = spells + 1 end end end
    V.Catalog.Reset()
    V.Catalog.Get()
    M:Assessment("Molten Core")
    V.Utility.Coverage(M.snap.members)
    for _, e in ipairs(ns.Data:All("dungeon")) do
      T.eq(e.min .. ":" .. tostring(e.max) .. ":" .. tostring(e.size) .. ":" .. tostring(e.verified), before[e.name], e.name)
    end
    local after = 0
    for _, book in pairs(ns.SpellInfo) do if type(book) == "table" then for _ in pairs(book) do after = after + 1 end end end
    T.eq(after, spells)
  end)

  T.it("performance on the mock: 40 members assessed well under budget, page draws stay bounded", function()
    local game, ns, V, M = start(40)
    M:Scan()
    for _ = 1, 45 do
      local cur = ns.InspectBroker.cur
      if cur then game:fire("INSPECT_READY", cur.guid) end
      game:advance(ns.InspectBroker.GAP + 0.05)
    end
    local times = {}
    for i = 1, 20 do
      local t0 = os.clock()
      M:Assessment("Molten Core")
      times[i] = os.clock() - t0
    end
    table.sort(times)
    local p95 = times[19]
    T.ok(p95 < 0.1, string.format("p95 %.4f s for 40 members (budget 0.1 s off-game)", p95))
    local t1 = os.clock()
    for _ = 1, 10 do M:Rows() V.Adequacy.Assess(M.snap.members[2], ns.Vanguard.Cache:Get(M.snap.members[2].key), "DAMAGER") end
    T.ok(os.clock() - t1 < 0.5)
    local timers = ns.Timer.count
    for _ = 1, 50 do ns.Hub:Refresh() end
    T.ok(ns.Timer.count - timers <= 2, "drawing doesn't pile up timers")
  end)

  T.it("lifecycle: turning it off leaves no handler, timer, request or shared state", function()
    local game, ns, V, M = start(10)
    M:Scan()
    game:advance(1)
    M:Settings().sharePrep = true
    V.Share.Receive({ v = 1, seq = 5, exp = 600, role = "TANK" }, "R2", "RAID", game.env.time())
    ns.Modules:SetEnabled("Vanguard", false)
    for ev, list in pairs(ns.Events.handlers) do
      for _, h in ipairs(list) do T.ok(h.owner ~= M, "handler left on " .. ev) end
    end
    T.eq(M.timers, nil)
    T.ok(ns.InspectBroker:Idle())
    T.eq(next(V.Share.peers), nil)
    T.eq(ns.Vanguard.Cache:Count(), 0)
    T.eq(M.hypo, nil)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("secrets from the game are refused before any comparison, everywhere Vanguard reads", function()
    local game, ns, V, M = start(5)
    local SECRET = { __secret = true }
    set(game, "UnitLevel", function() return SECRET end)
    set(game, "UnitClass", function() return SECRET, SECRET end)
    M:ReadRoster()
    for _, m in ipairs(M.snap.members) do
      T.ok(m.level.status ~= "known")
      T.ok(m.class.status ~= "known")
    end
    local a = M:Assessment("Molten Core")
    T.ok(a)
    T.eq(V.Utility.Coverage(M.snap.members).interrupt.state, "unknown")
    T.eq(#ns.Errors.list, 0)
  end)
end)

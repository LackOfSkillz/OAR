-- Vanguard VG00-04..06: what one installation can read about its group, an
-- inspected player and a boss encounter. Capability facts only; no names,
-- realms, GUIDs or gear links of other players are kept.
local T, mock = ...

local function set(game, k, v) game.base[k] = v rawset(game.env, k, v) end

local SECRET = { __secret = true }

local function start()
  local game = mock.new({ class = "HUNTER", level = 30 })
  game.units = {
    party1 = { name = "Khreos", realm = "Nightslayer", player = true, guid = "Player-1-0000BEEF", level = 29, class = "WARRIOR", role = "TANK", near = true },
    party2 = { name = "Mirae", player = true, guid = "Player-1-0000CAFE", level = 31, class = "PRIEST", role = "HEALER" },
  }
  local ns = game:loadAddon()
  game:login()
  set(game, "UnitGroupRolesAssigned", function(u) local d = game.units[u] return d and d.role or "NONE" end)
  set(game, "CanInspect", function(u) local d = game.units[u] return d and d.canInspect ~= false end)
  set(game, "UnitIsConnected", function(u) return game.units[u] ~= nil end)
  set(game, "UnitIsUnit", function(a, b) return a == b end)
  set(game, "CheckInteractDistance", function(u) local d = game.units[u] return d and d.near or false end)
  game.inspects = 0
  set(game, "NotifyInspect", function() game.inspects = game.inspects + 1 end)
  return game, ns
end

-- every string anywhere in a value
local function strings(v, out)
  out = out or {}
  if type(v) == "string" then out[#out + 1] = v
  elseif type(v) == "table" then for k, x in pairs(v) do strings(k, out) strings(x, out) end end
  return out
end

local function leaks(sample)
  for _, s in ipairs(strings(sample)) do
    for _, bad in ipairs({ "Khreos", "Mirae", "Nightslayer", "BEEF", "CAFE", "|Hitem", "Big Axe" }) do
      if s:find(bad, 1, true) then return s end
    end
  end
end

local function samples(ns, kind)
  local out = {}
  for _, s in ipairs(ns.db.global.probeGroup or {}) do if s.kind == kind then out[#out + 1] = s end end
  return out
end

T.describe("vanguard probe (VG00)", function()
  T.it("a group change records which roster facts are readable, with no names or GUIDs", function()
    local game, ns = start()
    game:fire("GROUP_ROSTER_UPDATE")
    game:advance(4)
    local r = samples(ns, "roster")
    T.eq(#r, 1)
    r = r[1]
    T.eq(r.group, "party")
    T.eq(r.size, 3)
    T.eq(r.roles.TANK, 1)
    T.eq(r.roles.HEALER, 1)
    T.eq(r.classes.WARRIOR, 1)
    T.eq(r.fields.UnitGUID.yes, 2)
    T.eq(r.fields.inspectRange["in range"], 1)
    T.eq(r.fields.inspectRange["out of range"], 1)
    T.eq(leaks(r), nil, "nothing identifying kept")
    -- the same size again: no second sample
    game:fire("GROUP_ROSTER_UPDATE")
    game:advance(4)
    T.eq(#samples(ns, "roster"), 1)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("waits for combat to end, and records a secret as secret", function()
    local game, ns = start()
    set(game, "CanInspect", function() return SECRET end)
    game:setCombat(true)
    game:fire("GROUP_ROSTER_UPDATE")
    game:advance(10)
    T.eq(#samples(ns, "roster"), 0, "nothing in combat")
    game:setCombat(false)
    game:advance(6)
    local r = samples(ns, "roster")[1]
    T.ok(r, "sampled after combat")
    T.eq(r.fields.CanInspect.secret, 2)
    T.eq(r.inCombat, false)
  end)

  T.it("a hover inspect records what the slots and talent APIs returned, once per player", function()
    local game, ns = start()
    game.units.mouseover = game.units.party1
    set(game, "GetInventoryItemLink", function(u, slot)
      if u ~= "mouseover" then return nil end
      if slot == 16 then return "|cffa335ee|Hitem:100::::::::20:::::|h[Big Axe]|h|r" end
      if slot == 1 then return "|cff0070dd|Hitem:101::::::::20:::::|h[Hat]|h|r" end
    end)
    set(game, "GetInventoryItemID", function(u, slot) if u == "mouseover" and slot == 3 then return 555 end end)
    set(game, "C_Item", setmetatable({ GetDetailedItemLevelInfo = function() return 25 end }, { __index = game.base.C_Item }))
    set(game, "GetInspectSpecialization", function() return 0 end)
    set(game, "GetNumTalentTabs", nil) -- missing on Forever (probe 2026-11-25)
    ns.PlayerInfo:Lines("mouseover")
    T.eq(game.inspects, 1)
    game:fire("INSPECT_READY", "Player-1-0000BEEF")
    local s = samples(ns, "inspect")
    T.eq(#s, 1)
    s = s[1]
    T.eq(s.source, "tooltip hover")
    T.eq(s.slots.link, 2)
    T.eq(s.slots.id, 1, "an item ID without a link is told apart")
    T.eq(s.slots.none, #ns.Probe.SLOTS - 3)
    T.eq(s.slots.itemLevels, 2)
    T.eq(s.talents.spec, "0")
    T.eq(s.talents.classicTabs, "nil", "missing API is shown as missing, not as zero talents")
    T.eq(s.class, "WARRIOR")
    T.eq(leaks(s), nil, "no gear links or names kept")
    -- a second inspect of the same player is not sampled again
    game:fire("INSPECT_READY", "Player-1-0000BEEF")
    T.eq(#samples(ns, "inspect"), 1)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("an inspect from Blizzard's window is sampled through the target; never in combat", function()
    local game, ns = start()
    game.units.target = game.units.party2
    set(game, "GetInventoryItemLink", function(u) if u == "player" then return "|Hitem:1|h[x]|h" end end)
    game:setCombat(true)
    game:fire("INSPECT_READY", "Player-1-0000CAFE")
    T.eq(#samples(ns, "inspect"), 0)
    game:setCombat(false)
    game:fire("INSPECT_READY", "Player-1-0000CAFE")
    local s = samples(ns, "inspect")[1]
    T.ok(s)
    T.eq(s.source, "inspect window")
    T.eq(s.slots.link, 0)
    T.eq(leaks(s), nil)
  end)

  T.it("boss events record id, size and result; a missing field stays unknown", function()
    local game, ns = start()
    game.instance = { name = "The Deadmines", map = 36 }
    game:fire("ENCOUNTER_START", 1144, "Rhahk'Zor", 1, 5)
    game:fire("ENCOUNTER_END", 1144, "Rhahk'Zor", 1, 5, 1)
    game:fire("ENCOUNTER_END", 1145, "Sneed", 1, 5)
    local e = samples(ns, "encounter")
    T.eq(#e, 3)
    T.eq(e[1].event, "ENCOUNTER_START")
    T.eq(e[2].id, 1144)
    T.eq(e[2].success, "1")
    T.eq(e[3].success, "nil", "no result is not a wipe")
    T.eq(e[2].instance.name, "The Deadmines")
    T.eq(e[2].group, "party")
  end)

  T.it("older samples move to the archive; none are lost", function()
    local _, ns = start()
    for i = 1, ns.Probe.GROUP_KEEP + 3 do ns.Probe:Encounter("ENCOUNTER_END", i, "Boss " .. i, 1, 5, 1) end
    T.eq(#ns.db.global.probeGroup, ns.Probe.GROUP_KEEP)
    T.eq(ns.db.global.probeGroup[1].id, 4, "newest kept")
    T.eq(#ns.Archive:Rows("probeGroup"), 3)
  end)

  T.it("the probe lists the group, inspect and encounter APIs and events", function()
    local _, ns = start()
    local apis, events = {}, {}
    for _, row in ipairs(ns.Probe.APIS) do apis[row[1]] = true end
    for _, e in ipairs(ns.Probe.EVENTS) do events[e] = true end
    for _, a in ipairs({ "CanInspect", "NotifyInspect", "GetRaidRosterInfo", "UnitGroupRolesAssigned", "GetInspectSpecialization", "C_Traits.GenerateInspectImportString" }) do
      T.ok(apis[a], a)
    end
    for _, e in ipairs({ "INSPECT_READY", "ENCOUNTER_END", "GROUP_ROSTER_UPDATE", "READY_CHECK" }) do T.ok(events[e], e) end
    local p = ns.Probe:Run()
    T.ok(p.constants["Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID"] ~= nil)
  end)
end)

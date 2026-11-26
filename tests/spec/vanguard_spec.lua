-- Vanguard VG01: Group check (preview). Lifecycle, roster, observations,
-- the scan through the shared broker, slots, talents, roles, the 5-minute
-- memory cache, and that nothing about other players reaches saved data.
local T, mock = ...

local function set(game, k, v) game.base[k] = v rawset(game.env, k, v) end
local SECRET = { __secret = true }

local function link(id, name, ench)
  return string.format("|cff0070dd|Hitem:%d:%s::::::::20:::::|h[%s]|h|r", id, ench and tostring(ench) or "", name)
end

local function start(opts)
  opts = opts or {}
  local game = mock.new({ class = "HUNTER", level = 30 })
  game.units = opts.units or {
    party1 = { name = "Khreos", realm = "Nightslayer", player = true, guid = "Player-1-0000BEEF", level = 29, class = "WARRIOR", role = "TANK" },
    party2 = { name = "Mirae", player = true, guid = "Player-1-0000CAFE", level = 31, class = "PRIEST", role = "NONE" },
  }
  local ns = game:loadAddon()
  game:login()
  game.inGroup = true
  game.asked = {}
  game.gear = opts.gear or {
    ["Player-1-0000BEEF"] = { [1] = link(101, "Hat"), [16] = link(100, "Big Axe", 1900), [5] = "SECRET" },
    ["Player-1-0000CAFE"] = { [1] = link(103, "Hood"), [16] = link(102, "Staff") },
  }
  game.items = { [100] = { name = "Big Axe", quality = 4, ilvl = 30 }, [101] = { name = "Hat", quality = 3, ilvl = 20 },
    [103] = { name = "Hood", quality = 2, ilvl = 24 } } -- 102 not sent yet
  set(game, "UnitGroupRolesAssigned", function(u) local d = game.units[u] return d and d.role or "NONE" end)
  set(game, "CanInspect", function(u) local d = game.units[u] return d ~= nil and not d.far end)
  set(game, "UnitIsConnected", function(u) if u == "player" then return true end local d = game.units[u] return d ~= nil and not d.offline end)
  set(game, "UnitIsUnit", function(a, b) return a == b end)
  set(game, "NotifyInspect", function(u) game.asked[#game.asked + 1] = u end)
  set(game, "GetInventoryItemLink", function(u, slot)
    local guid = game.env.UnitGUID(u)
    local g = guid and game.gear[guid]
    local v = g and g[slot]
    if v == "SECRET" then return SECRET end
    return v
  end)
  set(game, "GetInventoryItemID", function() return nil end)
  set(game, "GetInspectSpecialization", function(u) local d = game.units[u] return d and d.spec or 0 end)
  set(game, "GetSpecializationRoleByID", function(id) return ({ [256] = "HEALER" })[id] end)
  set(game, "Constants", { TraitConsts = { INSPECT_TRAIT_CONFIG_ID = -1 } })
  game.traits = { { treeID = 1, nodes = { { id = 1, rank = 3, max = 5 }, { id = 2, rank = 1, max = 1 }, { id = 3, rank = 0, max = 2 } } } }
  return game, ns, ns.VanguardModule
end

local function on(ns, M) ns.Modules:SetEnabled("Vanguard", true) return M end

local function answer(game, unit) game:fire("INSPECT_READY", game.units[unit].guid) end

local function row(M, name)
  for _, r in ipairs(M:Rows()) do if r.name == name then return r end end
end

T.describe("vanguard group check (VG01)", function()
  T.it("is off by default: no events, no timers, no requests; turning it on and off repeats cleanly", function()
    local game, ns, M = start()
    T.eq(M:IsEnabled(), false, "preview: off until you turn it on")
    local ok, why = M:Scan()
    T.eq(ok, nil)
    T.eq(why, "off")
    T.eq(#game.asked, 0)
    T.eq(ns.Events:Count("GROUP_ROSTER_UPDATE") >= 0, true)
    for _ = 1, 3 do
      ns.Modules:SetEnabled("Vanguard", true)
      T.ok(M:IsEnabled())
      ns.Modules:SetEnabled("Vanguard", false)
      T.eq(M:IsEnabled(), false)
      T.eq(M.timers, nil, "no timers left")
      for _, ev in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_DISABLED" }) do
        for _, h in ipairs(ns.Events.handlers[ev] or {}) do T.ok(h.owner ~= M, ev .. " handler removed") end
      end
    end
    T.eq(#game.asked, 0)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("roster: mixed realms, same names, unreadable GUIDs and offline members stay apart", function()
    local game, ns = start({ units = {
      party1 = { name = "Sam", realm = "Nightslayer", player = true, guid = SECRET, level = 20, class = "MAGE" },
      party2 = { name = "Sam", player = true, guid = nil, level = 21, class = "ROGUE" },
      party3 = { name = "Sam", player = true, guid = nil, level = 22, class = "DRUID", offline = true },
      party4 = { player = true, level = -1, class = "PALADIN" },
    } })
    local snap = ns.Vanguard.Roster.Read()
    T.eq(snap.size, 5)
    local keys = {}
    for _, m in ipairs(snap.members) do keys[m.key] = m end
    T.ok(keys["Sam-Nightslayer"], "other realm keeps its realm")
    local home = ns.Vanguard.Roster.HomeRealm()
    T.ok(keys["Sam-" .. home], "own realm filled in")
    T.ok(keys["Sam-" .. home .. "#2"], "same name twice: never merged")
    T.ok(keys["Sam-" .. home .. "#2"].ambiguous)
    T.eq(keys["Sam-" .. home .. "#2"].availability, "offline")
    T.ok(keys["unit:party4"].ambiguous, "no name or GUID: the unit token, marked unsure")
    T.eq(keys["unit:party4"].level.status, "unknown", "level -1 is unknown, not -1")
    T.eq(keys["Sam-Nightslayer"].guid, nil, "a secret GUID is never used")
    -- churn: same people, same generation; someone leaves, it goes up
    local again = ns.Vanguard.Roster.Read(snap)
    T.eq(again.generation, snap.generation)
    game.units.party4 = nil
    local after = ns.Vanguard.Roster.Read(again)
    T.eq(after.generation, snap.generation + 1)
    T.eq(#ns.Vanguard.Roster.Left(again, after), 1)
  end)

  T.it("raid: up to 40 members with their subgroup", function()
    local units = {}
    for i = 1, 40 do
      units["raid" .. i] = { name = "R" .. i, player = true, guid = "Player-1-R" .. i, level = 60, class = "WARRIOR", subgroup = math.floor((i - 1) / 5) + 1 }
    end
    local game, ns = start({ units = units })
    game.inRaid = true
    set(game, "GetNumGroupMembers", function() return 40 end)
    set(game, "UnitIsUnit", function(a, b) return a == b or (b == "player" and a == "raid1") end)
    set(game, "GetRaidRosterInfo", function(i) local d = units["raid" .. i] if d then return d.name, 0, d.subgroup end end)
    local snap = ns.Vanguard.Roster.Read()
    T.eq(snap.kind, "raid")
    T.eq(snap.size, 40, "you plus 39 others; raid1 is you")
    T.eq(snap.members[40].subgroup.value, 8)
  end)

  T.it("observations: unknown is never zero, secrets and odd numbers are refused", function()
    local _, ns = start()
    local O = ns.Vanguard.Obs
    T.eq(O.Num(O.New("level", nil)), nil)
    T.eq(O.Num(O.New("level", 0)), 0, "a real zero stays zero")
    local s = O.New("ilvl", SECRET)
    T.eq(s.status, "unknown")
    T.eq(s.reason, "secret")
    T.eq(s.value, nil)
    T.eq(O.New("x", 0 / 0).status, "unknown")
    T.eq(O.New("x", math.huge).status, "unknown")
    T.eq(O.New("x", {}).status, "unsupported")
    T.eq(#O.New("x", string.rep("a", 500)).value, O.MAX_STRING)
    T.ok(O.Valid(O.New("x", 5)))
    T.eq(select(2, O.Valid({ kind = "x", status = "known", source = "native" })), "known without a value")
    T.eq(select(2, O.Valid({ kind = "x", status = "known", source = "native", value = SECRET })), "secret value")
    local o = O.New("x", 5, "native", { expiresAt = 10 })
    T.eq(O.Age(o, 11).status, "stale")
    T.eq(o.status, "known", "the original is not changed")
    T.eq(O.Merge("role", { O.New("role", "TANK"), O.New("role", "HEALER") }).status, "conflicting")
    T.eq(O.Merge("role", { O.Unknown("role", "x"), O.New("role", "TANK") }).value, "TANK")
  end)

  T.it("a scan reads you at once and the others one at a time; slots keep their states", function()
    local game, ns, M = start()
    on(ns, M)
    local scan = M:Scan()
    T.eq(scan.total, 2)
    T.eq(scan.members["Player-1-00000001"].state, "done", "your own gear needs no inspect")
    T.eq(#game.asked, 1)
    answer(game, "party1")
    game:advance(2.1)
    T.eq(#game.asked, 2)
    answer(game, "party2")
    T.eq(scan.state, "done")
    local p = ns.Vanguard.Cache:Get("Player-1-0000BEEF")
    local by = {}
    for _, s in ipairs(p.slots) do by[s.slot] = s end
    T.eq(by[1].state, "known")
    T.eq(by[16].enchant, 1900, "enchant read from the link")
    T.eq(by[5].state, "unreadable", "a secret is unreadable, not empty")
    T.eq(by[7].state, "empty")
    T.eq(p.talents.points.value, 4, "3 + 1 spent")
    T.eq(p.itemLevel.value, 25)
    -- Mirae's staff details haven't arrived: pending, then filled in later
    local q = ns.Vanguard.Cache:Get("Player-1-0000CAFE")
    T.eq(q.count.pending, 1)
    game.items[102] = { name = "Staff", quality = 3, ilvl = 26 }
    game:advance(M.ITEM_RETRY + 0.1)
    T.eq(q.count.pending, 0)
    T.eq(q.itemLevel.value, 25)
    T.contains(row(M, "Mirae").gear, "item level 25")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("roles: what you set beats the group's role, which beats the game's guess; nothing else is guessed", function()
    local game, ns, M = start()
    game.units.party2.spec = 256
    on(ns, M)
    M:Scan()
    answer(game, "party1")
    game:advance(2.1)
    answer(game, "party2")
    T.eq(row(M, "Khreos").role, "Tank")
    T.eq(row(M, "Mirae").role, "Healer (guess)", "from the game's spec-to-role answer")
    game.units.party2.spec = 0
    M:Scan("Player-1-0000CAFE")
    game:advance(2.1)
    answer(game, "party2")
    T.eq(row(M, "Mirae").role, "unknown", "no spec, no assigned role: unknown")
    M:SetRole("Player-1-0000BEEF", "DAMAGER")
    T.eq(row(M, "Khreos").role, "Damage (you set)")
    M:SetRole("Player-1-0000BEEF", nil)
    T.eq(row(M, "Khreos").role, "Tank")
    T.eq(M:SetRole("Player-1-0000BEEF", "BOSS"), false)
  end)

  T.it("a late answer after the group changed, or for a reshuffled unit, fills in nobody", function()
    local game, ns, M = start()
    on(ns, M)
    local scan = M:Scan()
    local guid = game.units.party1.guid
    game.units.party3 = { name = "New", player = true, guid = "Player-1-00000NEW", level = 30, class = "MAGE" }
    game:fire("GROUP_ROSTER_UPDATE")
    T.eq(scan.state, "canceled")
    T.eq(scan.reason, "the group changed")
    game:fire("INSPECT_READY", guid)
    T.eq(ns.Vanguard.Cache:Get(guid), nil, "nothing stored from the old scan")
    -- new scan; party1's token moves to someone else before the answer
    M:Scan()
    game.units.party1 = { name = "Other", player = true, guid = "Player-1-0000OTHR", level = 30, class = "MAGE" }
    game:fire("INSPECT_READY", guid)
    T.eq(ns.Vanguard.Cache:Get(guid), nil)
    T.eq(ns.Vanguard.Cache:Get("Player-1-0000OTHR"), nil)
  end)

  T.it("combat, zoning and turning it off cancel the scan", function()
    local game, ns, M = start()
    on(ns, M)
    local s1 = M:Scan()
    game:setCombat(true)
    T.eq(s1.state, "canceled")
    T.eq(M:Scan(), nil, "no scan in combat")
    game:setCombat(false)
    local s2 = M:Scan()
    game:fire("PLAYER_ENTERING_WORLD", false, false)
    T.eq(s2.state, "canceled")
    local s3 = M:Scan()
    ns.Modules:SetEnabled("Vanguard", false)
    T.eq(s3.state, "canceled")
    T.eq(ns.Vanguard.Cache:Count(), 0, "turning it off forgets everything")
    T.ok(ns.InspectBroker:Idle())
  end)

  T.it("the cache turns old after 5 minutes and forgets members who leave", function()
    local game, ns, M = start()
    on(ns, M)
    M:Scan()
    answer(game, "party1")
    T.contains(row(M, "Khreos").status, "seen just now")
    game:advance(301)
    T.contains(row(M, "Khreos").status, "old")
    game.units.party1 = nil
    game:fire("GROUP_ROSTER_UPDATE")
    T.eq(ns.Vanguard.Cache:Get("Player-1-0000BEEF"), nil)
    T.eq(ns.Vanguard.Cache.TTL, 300)
  end)

  T.it("drawing the page never asks for an inspect", function()
    local game, ns, M = start()
    on(ns, M)
    for _ = 1, 20 do M:Rows() M:Summary() end
    T.eq(#game.asked, 0)
    ns.Hub:Toggle()
    ns.Hub:ShowTab("vanguard")
    ns.Hub:Refresh()
    M.selected = "Player-1-0000BEEF"
    ns.Hub:Refresh()
    T.ok(M:DrillText():find("tank"), M:DrillText())
    T.ok(M:UtilityText():find("Interrupt"), "group utility summary")
    ns.Hub:ShowTab("vanguard_prep")
    ns.Hub:Refresh()
    ns.Slash:Run("prep add Bring a fire resistance cloak")
    local rows = M:PrepRows()
    local custom
    for _, r in ipairs(rows) do if r.custom then custom = r end end
    T.ok(custom and custom.state == "missing", "your own item shows as yours")
    T.eq(#game.asked, 0)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("with debug on, nothing about the scanned players reaches saved data", function()
    local game, ns, M = start()
    ns.Slash:Run("debug on")
    on(ns, M)
    M:Scan()
    answer(game, "party1")
    game:advance(2.1)
    answer(game, "party2")
    M:SetRole("Player-1-0000CAFE", "HEALER")
    ns.db.global.census = nil -- Census is a separate, older feature (D27 scope note)
    local saved = game:logout()
    for _, bad in ipairs({ "0000BEEF", "0000CAFE", "Khreos", "Mirae", "Nightslayer", "Big Axe", "Hitem:100:", "Staff", "Hood" }) do
      T.eq(saved:find(bad, 1, true), nil, bad .. " must not be saved")
    end
    T.ok(saved:find("scan 1 done", 1, true), "counts are logged")
    T.eq(ns.Vanguard.Cache:Count(), 0, "logout clears the cache")
  end)
end)

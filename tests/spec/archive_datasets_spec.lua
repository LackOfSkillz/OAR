-- OI01-R11: behaviour tests for the datasets that only had the static contract.
-- Each drives the module's real recording code; where it needs live client
-- state, a small controlled fixture stands in (a fake unit, a stubbed session
-- list), named in the test. Checks per dataset: the archived row is the oldest
-- one (content), identity (path, keys, scope, character), count (working +
-- archived = recorded), and that it survives logout and the next load.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts or { mapID = 1412, x = 0.1, y = 0.5 })
  local ns = game:loadAddon()
  game:login()
  return game, ns
end
local function rows(ns, ds) return ns.Archive:Rows(ds) end
local function check(ns, ds, path, scope, keys)
  local e = rows(ns, ds)[1]
  T.ok(e, ds .. " archived")
  T.eq(e.path, path, ds .. " path")
  T.eq(e.scope, scope or "account", ds .. " scope")
  T.eq(e.char, ns.db.key, ds .. " character")
  for k, v in pairs(keys or {}) do T.eq(e.keys and e.keys[k], v, ds .. " key " .. k) end
  return e
end

T.describe("archived datasets (behaviour)", function()
  T.it("dungeon runs: the oldest run past KEEP_RUNS", function()
    local game, ns = session()
    local A = ns.Alts
    local keep = A.KEEP_RUNS
    A.KEEP_RUNS = 1
    for i = 1, 3 do
      A.run = { start = 1000 * i, money = 0, map = 36, name = "Run " .. i }
      A:EndRun(1000 * i + 600)
    end
    A.KEEP_RUNS = keep
    local e = check(ns, "dungeonRuns", "global.runs")
    T.eq(e.row.name, "Run 1")
    T.eq(#A.runs + #rows(ns, "dungeonRuns"), 3)
  end)

  T.it("trail: dots past 800 per map keep their mapID", function()
    local game, ns = session()
    local Tr = ns.Modules:Get("Trail")
    local max = Tr.MAX
    Tr.MAX = 2
    for i = 1, 4 do game.opts.x = 0.1 + i * 0.1 Tr.last = nil Tr:Sample() end
    Tr.MAX = max
    local e = check(ns, "trail", "global.trails[mapID]", nil, { mapID = 1412 })
    T.eq(e.row.x, 0.2)
    T.eq(#Tr.db[1412] + #rows(ns, "trail"), 4)
  end)

  T.it("spawn log: fixture unit and spot; rows keep their spot", function()
    local game, ns = session()
    local S = ns.Modules:Get("SpawnLog")
    S.SpotHere = function() return 9001 end -- fixture: a known rare spot here
    local max = S.MAX
    S.MAX = 1
    game.units = game.units or {}
    for i = 1, 3 do
      game.units.target = { name = "Mob" .. i, guid = "Creature-0-1-2-3-" .. (500 + i) .. "-0000000" .. i }
      S:Note("target")
    end
    S.MAX = max
    local e = check(ns, "spawnLog", "global.spawnLogs[spot]", nil, { spot = 9001 })
    T.eq(e.row.name, "Mob1")
  end)

  T.it("fights: fixture meter sessions; the oldest fight row", function()
    local _, ns = session()
    local F = ns.Modules:Get("FightMeter")
    local n = 0
    F.Sessions = function() n = n + 1 return { { sessionID = n, name = "Fight " .. n } } end -- fixture
    F.Read = function(_, id) return { id = id, dps = id * 10 } end -- fixture
    local max = F.MAX_HISTORY
    F.MAX_HISTORY = 1
    F:Capture() F:Capture() F:Capture()
    F.MAX_HISTORY = max
    local e = check(ns, "fights", "char.fights", "char")
    T.eq(e.row.dps, 10)
  end)

  T.it("XP sessions: an interrupted record joins history; the oldest is archived", function()
    local _, ns = session()
    local X = ns.SessionXP
    local store = X:Store()
    for i = 1, 3 do store.history[#store.history + 1] = { sessionId = "s" .. i, final = true } end
    local max = X.MAX_HISTORY
    X.MAX_HISTORY = 2
    store.current = { sessionId = "s4", final = false }
    X:Start()
    X.MAX_HISTORY = max
    local e = check(ns, "xpSessions", "char.xp60.history", "char")
    T.eq(e.row.sessionId, "s1")
  end)

  T.it("sales ledger: auctions that disappeared, oldest archived past 100", function()
    local game, ns = session()
    local H = ns.Modules:Get("AuctionHelper")
    local ledger = H:SalesLedger()
    for i = 1, 100 do ledger[i] = { auctionID = i, t = i } end
    H.previousAuctions = { [777] = { auctionID = 777, itemID = 2318, amount = 1 } }
    game.owned = {}
    H:RecordOwned()
    local e = check(ns, "salesLedger", "char.auctionSales", "char")
    T.eq(e.row.auctionID, 1)
    T.eq(#H:SalesLedger(), 100)
  end)

  T.it("pets seen: fixture pet unit; oldest past 50", function()
    local game, ns = session()
    local B = ns.Modules:Get("BeastInfo")
    game.units = game.units or {}
    for i = 1, 51 do
      game.units.pet = { guid = "Pet-0-1-2-3-4-" .. i }
      B:NotePet("pet", "Cat", 10, 2.0, 3000 + i)
    end
    local e = check(ns, "petsSeen", "global.petsSeen")
    T.eq(e.row.npcID, 3001)
  end)

  T.it("gold ledger: sessions past 30", function()
    local _, ns = session()
    local L = ns.Modules:Get("Ledger")
    ns.db.char.ledger = {}
    for i = 1, 30 do ns.db.char.ledger[i] = { start = i } end
    L:OnLogout()
    local e = check(ns, "goldLedger", "char.ledger", "char")
    T.eq(e.row.start, 1)
  end)

  T.it("rare cast gaps: fixture rare unit; gaps keep npcID and spell", function()
    local game, ns = session()
    local R = ns.Modules:Get("RareProfile")
    R.RareOn = function() return 61 end -- fixture: the target is a rare with a profile
    R:Profile(61, "Thuros")
    local max = R.MAX_GAPS
    R.MAX_GAPS = 1
    for _ = 1, 4 do
      game:advance(10)
      R:OnSpell("UNIT_SPELLCAST_SUCCEEDED", "target", nil, 75) -- Auto Shot, in the test spellbook
    end
    R.MAX_GAPS = max
    local e = check(ns, "rareCastGaps", "global.rareProfiles[npcID].spells[spell].gaps", nil, { npcID = 61 })
    T.ok(e.keys.spell, "spell name kept")
  end)

  T.it("fishing sessions and catches per skill point", function()
    local _, ns = session()
    local L = ns.FishingLog
    local keep = L.KEEP_SESSIONS
    L.KEEP_SESSIONS = 1
    local stats = L.Stats
    L.Stats = function(s) return { catches = s.catches, vendor = 0, auction = 0, gained = 0, fish = {} } end -- fixture
    L:Archive({ start = 1, secs = 60, catches = 5, casts = 6 })
    L:Archive({ start = 2, secs = 60, catches = 7, casts = 8 })
    L.Stats, L.KEEP_SESSIONS = stats, keep
    local e = check(ns, "fishSessions", "global.fishLog.sessions")
    T.eq(e.row.start, 1)
    local G = ns.FishingGuide
    local kp = G.KEEP_POINTS
    G.KEEP_POINTS = 1
    for i = 1, 3 do G:Char().since = i G:OnSkill(nil, "Your skill in Fishing has increased") end
    G.KEEP_POINTS = kp
    local p = check(ns, "fishCatchesPerPoint", "char.fishSkill.per", "char")
    T.eq(p.row, 1)
  end)

  T.it("recent discoveries: past 300 the oldest is archived (fixture units)", function()
    local game, ns = session()
    local D = ns.Modules:Get("Discovery")
    game.units = game.units or {}
    for i = 1, 301 do
      game.units.target = { name = "Npc" .. i, guid = "Creature-0-1-2-3-" .. (20000 + i) .. "-00000001" }
      D:Capture("target", "target")
    end
    local e = check(ns, "discoveredRecent", "global.discovered.recent")
    T.eq(e.row.name, "Npc1")
  end)

  T.it("next-session dismissals: the old map is archived before it is replaced", function()
    local _, ns = session()
    local N = ns.Modules:Get("NextSession")
    local d = {}
    for i = 1, 21 do d["s" .. i] = "dismiss" end
    N:Settings().dismissed = d
    N.Plan = function() return { basedOnSessionId = "s99" } end -- fixture: a current plan
    N:Feedback("dismiss")
    local e = check(ns, "nextSessionDismissed", "char.modules.NextSession.settings.dismissed", "char")
    T.eq(e.row.s1, "dismiss")
  end)

  T.it("archived rows from these datasets survive logout and the next load", function()
    local game, ns = session()
    local G = ns.FishingGuide
    G.KEEP_POINTS = 1
    for i = 1, 3 do G:Char().since = i G:OnSkill(nil, "Fishing went up") end
    G.KEEP_POINTS = 10
    local saved = game:logout()
    local _, ns2 = session({ savedVariables = saved, mapID = 1412, x = 0.1, y = 0.5 })
    T.ok(#ns2.Archive:Rows("fishCatchesPerPoint") >= 1)
  end)
end)

T.describe("clears and resets keep what they clear (OI01-R07)", function()
  T.it("trail clear, census reset, route delete, radar clear and instance delete are archived", function()
    local game, ns = session()
    ns.db.global.trails[1412] = { { x = 0.1, y = 0.1, t = 1 } }
    ns.Modules:Get("Trail"):Clear(1412)
    T.eq(rows(ns, "trailCleared")[1].keys.mapID, 1412)
    local C = ns.Census
    C:Realm().players["Someone"] = { t = 1 }
    game:slash("census reset")
    T.ok(rows(ns, "censusCleared")[1].row.players["Someone"], "census archived on reset")
    local R = ns.Routes
    local r = R:New(1412, "Test route")
    R:Delete(r.id)
    T.eq(rows(ns, "routesDeleted")[1].row.name, "Test route")
    ns.db.char.radarFeedback = { c1 = { verdict = "useful", t = 1 } }
    ns.OpportunityRadar:ClearFeedback()
    T.eq(rows(ns, "radarFeedbackCleared")[1].row.c1.verdict, "useful")
    local A = ns.Alts
    A.inst = { { t = 1, name = "Deadmines" } }
    A:DeleteEntry(1)
    T.eq(rows(ns, "instances")[1].row.name, "Deadmines")
  end)

  T.it("a damaged Outrider_DB root is kept and survives the next load (OI01-R08)", function()
    local game, ns = session({ savedVariables = 'Outrider_DB = "corrupt file"\n', mapID = 1412, x = 0.1, y = 0.5 })
    local kept = ns.db.global.archiveDamaged[1]
    T.eq(kept.path, "Outrider_DB")
    T.eq(kept.value, "corrupt file")
    local saved = game:logout()
    local _, ns2 = session({ savedVariables = saved, mapID = 1412, x = 0.1, y = 0.5 })
    T.eq(ns2.db.global.archiveDamaged[1].value, "corrupt file")
  end)

  T.it("archived entries are snapshots: editing the source later can't change history (OI01-R09)", function()
    local _, ns = session()
    local list = { { price = 100, tags = { "a" } }, { price = 200 } }
    local src = list[1]
    ns.Archive:Shift("demo", list, { path = "x", keys = { k = 1 } })
    src.price = 999
    src.tags[1] = "changed"
    local e = ns.Archive:Rows("demo")[1]
    T.eq(e.row.price, 100)
    T.eq(e.row.tags[1], "a")
  end)

  T.it("previously saved damaged values are always kept, however many there are (OI01-R12)", function()
    local _, ns = session()
    for i = 1, 600 do ns.Archive:KeepDamaged("saved:p" .. i, i) end
    T.eq(#ns.db.global.archiveDamaged, 600, "no cap on saved values")
    T.eq(ns.db.global.archiveDamagedOverflow, nil)
    -- a saved store holding a wrong-type value after that: still kept before the fresh table
    ns.db.global.trails = "broken trails"
    local Tr = ns.Modules:Get("Trail")
    Tr:OnInitialize()
    local found
    for _, d in ipairs(ns.db.global.archiveDamaged) do if d.value == "broken trails" then found = d end end
    T.ok(found, "the 601st damaged saved value is kept too")
  end)

end)

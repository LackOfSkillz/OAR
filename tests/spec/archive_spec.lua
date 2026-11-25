-- Data preservation (owner override 2026-11-24, review OI01-R01..R05).
-- Every collected-data store that keeps a working size moves its oldest rows to
-- ns.Archive. These tests check, per store: nothing is lost (working + archived
-- = everything recorded), the archived row is the original table, and the
-- entry records where it came from (path, parent keys, scope, character) so it
-- can be put back. Items, NPCs and maps are test data.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  game.items = { [2318] = { name = "Light Leather", sell = 15 } }
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

-- the archived entries of a dataset, and a check of one entry's identity
local function rows(ns, dataset) return ns.Archive:Rows(dataset) end
local function identity(ns, e, path, keys, scope)
  T.eq(e.path, path, "path")
  T.eq(e.scope, scope or "account", "scope")
  T.eq(e.char, ns.db.key, "character")
  T.ok(type(e.at) == "number", "time archived")
  T.ok(type(e.id) == "string" and e.id:find(":", 1, true), "stable entry id")
  for k, v in pairs(keys or {}) do T.eq(e.keys and e.keys[k], v, "key " .. k) end
end

T.describe("archive contract", function()
  T.it("moves a row only after the archive holds it; entry keeps path, keys, scope, character", function()
    local _, ns = session()
    local list = { { a = 1 }, { a = 2 }, { a = 3 } }
    local first = list[1]
    T.ok(ns.Archive:Shift("demo", list, { path = "global.demo[npcID]", keys = { npcID = 7 } }))
    local e = rows(ns, "demo")[1]
    T.ok(e.row ~= first and e.row.a == first.a, "an equal snapshot, not the live table (OI01-R09)")
    identity(ns, e, "global.demo[npcID]", { npcID = 7 })
    T.eq(#list, 2)
    T.ok(ns.Archive:Pop("demo", list, { path = "global.demo", scope = "char" }))
    T.eq(rows(ns, "demo")[2].row.a, 3)
    T.eq(rows(ns, "demo")[2].scope, "char")
  end)

  T.it("a failed archive write leaves the row in place and the trim loop stops (failure injection)", function()
    local _, ns = session()
    local put = ns.Archive.Put
    ns.Archive.Put = function() return false, "disk full (injected)" end
    local list = { { a = 1 }, { a = 2 }, { a = 3 } }
    local n = 0
    while #list > 1 and ns.Archive:Shift("demo", list, { path = "x" }) do n = n + 1 end
    T.eq(n, 0)
    T.eq(#list, 3, "nothing removed")
    ns.Archive.Put = function() error("boom (injected)") end
    local ok = ns.Archive:Shift("demo", list, { path = "x" })
    T.eq(ok, false)
    T.eq(#list, 3, "an error inside the archive also keeps the row")
    ns.Archive.Put = put
    -- a real module store under the same failure keeps everything
    ns.Archive.Put = function() return false, "injected" end
    for i = 1, 20 do ns.Prices.db[2318] = ns.Prices.db[2318] or {} end
    local h = { { 1, 10 }, { 2, 11 } }
    ns.Prices.db[2318] = h
    ns.Prices.DAYS = 0
    ns.Prices:Record(2318, 9)
    T.eq(#h >= 2, true, "old daily lows kept when the archive can't take them")
    ns.Archive.Put = put
    ns.Prices.DAYS = 14
  end)

  T.it("a damaged saved archive is kept aside, unchanged, never overwritten", function()
    local _, ns = session()
    ns.db.global.archive = "junk from an old build"
    T.ok(ns.Archive:Put("demo", { a = 1 }, { path = "x" }))
    T.eq(ns.db.global.archiveDamaged[1].value, "junk from an old build")
    T.eq(ns.db.global.archiveDamaged[1].path, "archive")
    ns.db.global.archive.sets.demo = 42
    T.ok(ns.Archive:Put("demo", { a = 2 }, { path = "x" }))
    T.eq(ns.db.global.archiveDamaged[2].value, 42)
    T.eq(ns.db.global.archiveDamaged[2].path, "archive.sets.demo")
    T.eq(#rows(ns, "demo"), 1)
    -- even a damaged damaged-list is wrapped, not dropped
    ns.db.global.archiveDamaged = "also junk"
    ns.Archive:KeepDamaged("p", 1)
    T.eq(ns.db.global.archiveDamaged[1].value, "also junk")
    T.eq(ns.db.global.archiveDamaged[2].value, 1)
  end)

  T.it("the v1 archive written earlier the same day is kept whole when the v2 store starts", function()
    local _, ns = session()
    ns.db.global.archive = { ["prices@Torrant"] = { { id = 1, row = { 1, 2 } } } }
    ns.Archive:Put("demo", { a = 1 }, { path = "x" })
    local kept = ns.db.global.archiveDamaged[1]
    T.eq(kept.path, "archive")
    T.eq(kept.value["prices@Torrant"][1].id, 1)
  end)

  T.it("entries survive logout and the next load (persistence) and stay per character", function()
    local game, ns = session()
    ns.Archive:Put("demo", { a = 1 }, { path = "x", scope = "char" })
    local me = ns.db.key
    local saved = game:logout()
    local game2 = mock.new({ savedVariables = saved, name = "Lumen", class = "PRIEST", race = "Undead" })
    local ns2 = game2:loadAddon()
    game2:login()
    T.ok(ns2.db.key ~= me, "another character logged in")
    T.eq(#ns2.Archive:Rows("demo"), 1)
    T.eq(#ns2.Archive:Rows("demo", me), 1)
    T.eq(#ns2.Archive:Rows("demo", ns2.db.key), 0, "character filter: none from the priest")
  end)

  T.it("Restore hands every entry back with enough identity to rebuild the store", function()
    local _, ns = session()
    local S = ns.Sightings
    S.CAP = 2
    for i = 1, 5 do S:Record(9001, { t = i, state = "seen", mapID = 1412, x = 0.1, y = 0.2 }) end
    S.CAP = 200
    T.eq(#S.db[9001], 2)
    local rebuilt = {}
    ns.Archive:Restore("sightings", function(e)
      local id = e.keys.npcID
      rebuilt[id] = rebuilt[id] or {}
      table.insert(rebuilt[id], e.row)
    end)
    for _, r in ipairs(S.db[9001]) do table.insert(rebuilt[9001], r) end
    T.eq(#rebuilt[9001], 5, "every sighting back")
    for i = 1, 5 do T.eq(rebuilt[9001][i].t, i, "in order") end
  end)
end)

T.describe("every collected store archives with identity (nothing lost)", function()
  T.it("prices: daily lows past 14 days, keyed by itemID", function()
    local game, ns = session()
    game.now = 86400 * 20000
    ns.Prices:Record(2318, 500)
    game.now = game.now + 86400 * 20
    ns.Prices:Record(2318, 450)
    local e = rows(ns, "prices")[1]
    T.eq(e.row[2], 500)
    identity(ns, e, "global.prices[itemID]", { itemID = 2318 })
    T.eq(#ns.Prices.db[2318] + #rows(ns, "prices"), 2)
  end)

  T.it("price history: rows past the cap and the age limit, and whole untracked items", function()
    local game, ns = session()
    local PH = ns.PriceHistory
    PH:Watch(2318, "manual")
    local t0 = 86400 * 20000
    PH:Seen(2318, 100, 5, t0)
    PH:Seen(2318, 110, 5, t0 + 121 * 86400)
    local e = rows(ns, "priceHistory")[1]
    T.eq(e.row[2], 100)
    identity(ns, e, "global.priceLog.items[itemID]", { itemID = 2318 })
    local cap = PH.MAX_ROWS
    PH.MAX_ROWS = 1
    PH:Seen(2318, 120, 5, t0 + 122 * 86400)
    PH.MAX_ROWS = cap
    T.eq(#rows(ns, "priceHistory"), 2)
    PH:Unwatch(2318)
    PH:Prune(t0 + 300 * 86400)
    T.eq(PH.store.items[2318], nil)
    local whole = rows(ns, "priceHistoryItems")[1]
    identity(ns, whole, "global.priceLog.items[itemID]", { itemID = 2318 })
    T.eq(whole.row[1][2], 120, "the whole remaining list")
  end)

  T.it("sightings and respawn observations, keyed by npcID", function()
    local _, ns = session()
    local S = ns.Sightings
    S.CAP, S.OBS_CAP = 2, 2
    for i = 1, 4 do S:Record(9001, { t = i, state = "seen", mapID = 1412 }) end
    for i = 1, 4 do S:Learn(9001, 600 + i, 1) end
    S.CAP, S.OBS_CAP = 200, 50
    identity(ns, rows(ns, "sightings")[1], "global.sightings[npcID]", { npcID = 9001 })
    T.eq(#rows(ns, "sightings") + #S.db[9001], 4)
    identity(ns, rows(ns, "sightingObservations")[1], "global.respawnObs[npcID]", { npcID = 9001 })
    T.eq(rows(ns, "sightingObservations")[1].row, 601)
  end)

  T.it("quest diary, per character", function()
    local _, ns = session()
    local Q = ns.Modules:Get("QuestInfo")
    local cap = Q.HISTORY_CAP
    Q.HISTORY_CAP = 2
    for i = 1, 4 do Q:Record(100 + i, "took") end
    Q.HISTORY_CAP = cap
    local e = rows(ns, "questDiary")[1]
    identity(ns, e, "global.questHistory[character]", { character = ns.db.key }, "char")
    T.eq(e.row.id, 101)
  end)

  T.it("chat archive and per-person whispers (only when the player turned them on)", function()
    local _, ns = session()
    local Ch = ns.Modules:Get("Chat")
    local a, p = Ch.ARCHIVE_MAX, Ch.PER_PERSON_MAX
    Ch.ARCHIVE_MAX, Ch.PER_PERSON_MAX = 2, 2
    for i = 1, 4 do Ch:RememberLine("CHAT_MSG_WHISPER", "hello " .. i, "Bob") end
    Ch.ARCHIVE_MAX, Ch.PER_PERSON_MAX = a, p
    T.eq(rows(ns, "chat")[1].row.text, "hello 1")
    identity(ns, rows(ns, "chat")[1], "global.chatArchive", {})
    identity(ns, rows(ns, "chatByPerson")[1], "global.whisperArchive[who]", { who = "bob" })
  end)

  T.it("feedback reports, advisor feedback, layer history, node states, deaths, economy outcomes", function()
    local _, ns = session()
    local F = ns.Modules:Get("Feedback")
    local fm = F.MAX
    F.MAX = 1
    F:Make("idea", "one", "first idea")
    F:Make("idea", "two", "second idea")
    F.MAX = fm
    identity(ns, rows(ns, "feedback")[1], "global.feedback", {})
    T.eq(rows(ns, "feedback")[1].row.title, "one")

    local A = ns.Modules:Get("Advisor")
    local ak = A.FEEDBACK_KEEP
    A.FEEDBACK_KEEP = 1
    A:Feedback({ candidateId = "c1" }, "up")
    A:Feedback({ candidateId = "c2" }, "down")
    A.FEEDBACK_KEEP = ak
    identity(ns, rows(ns, "adviceFeedback")[1], "char.adviceFeedback", {}, "char")

    local L = ns.Modules:Get("Layers")
    local lh = L.HISTORY_MAX
    L.HISTORY_MAX = 1
    L.mapID = 1412
    L:Remember(11, "seen")
    L:Remember(12, "seen")
    L.HISTORY_MAX = lh
    identity(ns, rows(ns, "layerHistory")[1], "char.modules.Layers.settings.history", {}, "char")

    local LL = ns.LootLog
    local sm = LL.STATE_MAX
    LL.STATE_MAX = 2
    LL:MarkNode("herb", 1412, 0.10, 0.10, "picked")
    LL:MarkNode("herb", 1412, 0.30, 0.30, "picked")
    LL:MarkNode("herb", 1412, 0.50, 0.50, "picked")
    LL.STATE_MAX = sm
    identity(ns, rows(ns, "nodeState")[1], "global.nodeState", {})
    T.eq(rows(ns, "nodeState")[1].row.x, 0.10)

    local N = ns.Modules:Get("Nearest")
    ns.db.global.deathHistory = {}
    for i = 1, 101 do N.deathLog = { t = i } N:FinishDeathLog() end
    identity(ns, rows(ns, "deaths")[1], "global.deathHistory", {})
    T.eq(rows(ns, "deaths")[1].row.t, 1)

    local E = ns.IntelEconomy
    T.ok(E and E.RecordOutcome, "economy outcome recorder present")
    do
      local char = {}
      for i = 1, 101 do E.RecordOutcome(char, { kind = "vendor", itemID = i, netCopper = 1, confirmed = true }) end
      identity(ns, rows(ns, "economyOutcomes")[1], "char.intelEconomyOutcomes", {}, "char")
    end
  end)

  T.it("fishing notable catches", function()
    local _, ns = session()
    local L = ns.FishingLog
    local k = L.KEEP_NOTABLE
    L.KEEP_NOTABLE = 1
    L:Notable(6303, "Raw Slitherskin Mackerel", "new")
    L:Notable(6289, "Raw Longjaw Mud Snapper", "new")
    L.KEEP_NOTABLE = k
    T.eq(#rows(ns, "fishNotable"), 1)
    identity(ns, rows(ns, "fishNotable")[1], "global.fishLog.notable", {})
  end)

  T.it("every archive call in the addon is fail-safe and names its path (static contract)", function()
    -- each call site must (a) pass a ctx table with a path, and (b) sit in a loop or
    -- if condition, so a failed write keeps the row and stops the trim.
    local sites, bad = 0, {}
    for _, file in ipairs(mock.listLua("addon/Outrider")) do
      local rel = mock.relpath(file, "addon/")
      if not rel:find("Core/Archive.lua", 1, true) then
        local fh = io.open(file, "r")
        local n = 0
        for line in fh:lines() do
          n = n + 1
          if line:find("ns%.Archive:[SPM]%a+%(") and not line:find("^%s*%-%-") then
            sites = sites + 1
            if not line:find("path%s*=") then bad[#bad + 1] = rel .. ":" .. n .. " no path" end
            -- MigrateStore keeps the old store and stages new rows when the
            -- archive write fails (review OI-FR15): fail-safe by construction
            if not (line:find("while .* and ns%.Archive") or line:find("if .*ns%.Archive") or line:find("ns%.Archive:MigrateStore%(")) then bad[#bad + 1] = rel .. ":" .. n .. " not fail-safe" end
          end
        end
        fh:close()
      end
    end
    T.ok(sites >= 28, "all archive call sites found (" .. sites .. ")")
    T.same(bad, {})
    -- and every dataset named in code is listed in the machine-readable audit
    local fh = io.open("docs/quality/data_preservation_audit.json", "r")
    T.ok(fh, "docs/quality/data_preservation_audit.json exists")
    local audit = fh and fh:read("*a") or ""
    if fh then fh:close() end
    local missing = {}
    for _, file in ipairs(mock.listLua("addon/Outrider")) do
      local f2 = io.open(file, "r")
      local text = f2:read("*a")
      f2:close()
      for ds in text:gmatch('ns%.Archive:%a+%("([%w_]+)"') do
        if not audit:find('"dataset": "' .. ds .. '"', 1, true) then missing[#missing + 1] = ds end
      end
    end
    T.same(missing, {})
  end)
end)

T.describe("retention audit fixes (review OI01-R03, R04)", function()
  T.it("census: players and profession sightings past 30 days are archived with realm and name", function()
    local game, ns = session()
    local C = ns.Census
    local r = C:Realm()
    r.players["Oldtimer"] = { t = 1, level = 20 }
    r.players["Fresh"] = { t = game.now or time(), level = 30 }
    r.profs["Oldtimer"] = { Mining = 1 }
    C:Prune()
    T.eq(r.players["Oldtimer"], nil)
    T.ok(r.players["Fresh"], "recent players stay")
    local e = rows(ns, "censusPlayers")[1]
    identity(ns, e, "global.census[realm].players[name]", { realm = ns.Census.RealmKey(), name = "Oldtimer" })
    T.eq(e.row.level, 20)
    local pr = rows(ns, "censusProfs")[1]
    T.eq(pr.keys.prof, "Mining")
    T.eq(pr.row, 1)
  end)

  T.it("auction search history, mail recipients: the overflow is archived", function()
    local _, ns = session()
    local A = ns.AuctionSearch
    local cap = A.HISTORY
    A.HISTORY = 2
    for _, t in ipairs({ "linen", "wool", "silk" }) do A:Remember(t) end
    A.HISTORY = cap
    T.eq(rows(ns, "ahSearchHistory")[1].row, "linen")
    local M = ns.Mailbox
    local rc = M.RECENT
    M.RECENT = 1
    M:Remember("Alice") M:Remember("Bob")
    M.RECENT = rc
    T.eq(rows(ns, "mailRecent")[1].row, "Alice")
  end)

  T.it("price watch eviction and a whole whisper partner are archived before removal", function()
    local _, ns = session()
    local PH = ns.PriceHistory
    PH.MAX_WATCH = 1
    PH:Watch(1, "search")
    PH:Watch(2, "search")
    PH.MAX_WATCH = 300
    local e = rows(ns, "priceWatch")[1]
    T.eq(e.keys.itemID, 1)
    T.eq(e.row.why, "search")
    local Ch = ns.Modules:Get("Chat")
    for i = 1, 32 do Ch:RememberLine("CHAT_MSG_WHISPER", "hi", "P" .. i) end
    local whole
    for _, x in ipairs(rows(ns, "chatByPerson")) do if x.keys.whole then whole = x end end
    T.ok(whole and type(whole.row) == "table" and whole.row[1].text == "hi", "the evicted person's history kept whole")
  end)

  T.it("schema changes keep the old store (XP60, intelligence profile)", function()
    local _, ns = session()
    ns.db.char.xp60 = { schema = -1, history = { { sessionId = "old1" } } }
    ns.SessionXP:Store()
    T.eq(rows(ns, "xp60OldSchema")[1].row.history[1].sessionId, "old1")
    ns.db.char.intelligenceProfile = { schema = -1, role = "tank", extra = "kept" }
    ns.ClassProfiles.State()
    local old = rows(ns, "profileOldSchema")[1]
    T.eq(old.row.extra, "kept")
    T.eq(ns.db.char.intelligenceProfile.role, "tank", "the role carries over as before")
  end)

  T.it("damaged saved values are kept: a broken DB root, a bad layer row, a blank profession", function()
    local _, ns = session({ savedVariables = 'Outrider_DB = { global = "oops", chars = 5 }\n' })

    local found = {}
    for _, d in ipairs(ns.db.global.archiveDamaged or {}) do found[tostring(d.value)] = d.path end
    T.eq(found["oops"], "DB:db.global")
    T.eq(found["5"], "DB:db.chars")
    local L = ns.Modules:Get("Layers")
    L:Settings().history = { "junk row" }
    L.mapID = 1412
    L:Remember(5, "seen")
    found = {}
    for _, d in ipairs(ns.db.global.archiveDamaged) do found[tostring(d.value)] = d.path end
    T.ok(found["junk row"], "bad layer row kept")
  end)

  T.it("lockouts past a day and the map tab's two-click clear are archived", function()
    local game, ns = session()
    local A = ns.Alts
    A.inst = A.inst or {}
    table.insert(A.inst, { t = 1, name = "Wailing Caverns" })
    A:Prune()
    T.eq(rows(ns, "instances")[1].row.name, "Wailing Caverns")
    ns.db.global.pois = { p1 = { name = "Mailbox" } }
    local T2 = ns.Modules:Get("MapTab")
    if T2 and T2.ClearAll then
      T2:ClearAll()
      T.eq(rows(ns, "clearedPlaces")[1].row.p1.name, "Mailbox")
    end
  end)
end)

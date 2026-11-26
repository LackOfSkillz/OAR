-- Vanguard VG05: run records from the game's own events, reload and rejoin,
-- duplicates, the archive instead of deletion, queries over old runs, the
-- assessment kept as it was, Wilson rates, and a forecast that abstains.
local T, mock = ...

local function set(game, k, v) game.base[k] = v rawset(game.env, k, v) end

local function start()
  local game = mock.new({ class = "HUNTER", level = 20 })
  game.units = {
    party1 = { name = "Khreos", player = true, guid = "Player-1-0000BEEF", level = 20, class = "WARRIOR", role = "TANK" },
    party2 = { name = "Mirae", player = true, guid = "Player-1-0000CAFE", level = 20, class = "PRIEST", role = "HEALER" },
  }
  local ns = game:loadAddon()
  game:login()
  game.inGroup = true
  set(game, "UnitGroupRolesAssigned", function(u) local d = game.units[u] return d and d.role or "NONE" end)
  set(game, "UnitIsConnected", function() return true end)
  set(game, "UnitIsUnit", function(a, b) return a == b end)
  ns.DungeonGuide.ByName = function() return { ["The Deadmines"] = { bosses = { { 644, "Rhahk'Zor", 19, nil, {} },
    { 639, "Edwin VanCleef", 21, nil, {} } }, items = {} } } end
  -- the pack's two bosses define "completed" here; researched facts are tested elsewhere
  ns.VanguardFacts = { bosses = {}, access = {}, raids = {}, prices = {}, enchants = {} }
  ns.Vanguard.Facts.Reset()
  ns.Vanguard.Catalog.Reset()
  game.instance = nil
  set(game, "IsInInstance", function() if game.instance then return true, "party" end return false, "none" end)
  set(game, "GetInstanceInfo", function() return game.instance end)
  ns.Modules:SetEnabled("Vanguard", true)
  return game, ns, ns.Vanguard, ns.VanguardModule
end

local function enter(game, M, name, t) game.instance = name M:RunCheck(t) end
local function leave(game, M, t) game.instance = nil M:RunCheck(t) end

T.describe("vanguard run history and forecasts (VG05)", function()
  T.it("a run from the game's events: kills, a wipe, completed only when every boss in the data died", function()
    local game, ns, V, M = start()
    local store = V.Runs.Store()
    enter(game, M, "The Deadmines", 1000)
    T.ok(store.open, "started")
    T.ok(store.open.assessment, "readiness kept from the start")
    local before = store.open.assessment.low
    V.Runs.EncounterStart(store, 644, "Rhahk'Zor", 1100)
    V.Runs.EncounterEnd(store, 644, "Rhahk'Zor", 1, 1160)
    V.Runs.EncounterEnd(store, 644, "Rhahk'Zor", 1, 1162) -- the game sent it twice
    V.Runs.EncounterStart(store, 639, "Edwin VanCleef", 1500)
    V.Runs.EncounterEnd(store, 639, "Edwin VanCleef", 0, 1560)
    V.Runs.EncounterStart(store, 639, "Edwin VanCleef", 1700)
    V.Runs.EncounterEnd(store, 639, "Edwin VanCleef", 1, 1790)
    leave(game, M, 1800)
    leave(game, M, 1800 + V.Runs.REJOIN)
    local run = store.runs[#store.runs]
    T.eq(run.outcome, "completed")
    T.eq(#run.attempts, 3, "the duplicate end was ignored")
    T.eq(run.attempts[2].result, "wipe", "the game said it failed")
    T.eq(run.assessment.low, before, "the outcome never changed the assessment")
    -- no names or GUIDs in what is saved
    local Serialize = ns.Serialize or ns.Codec
    local blob = ""
    local function walk(t) for k, v in pairs(t) do blob = blob .. tostring(k) .. "=" .. (type(v) == "table" and "" or tostring(v)) .. ";" if type(v) == "table" then walk(v) end end end
    walk(run)
    T.ok(not blob:find("Khreos") and not blob:find("Mirae") and not blob:find("Player%-1"), "no names or GUIDs")
    T.eq(run.features.tank, 1)
    T.eq(run.features.classes.PRIEST, 1)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("leaving with some kills is incomplete, with none abandoned; rejoining in time is the same run", function()
    local game, _, V, M = start()
    local store = V.Runs.Store()
    enter(game, M, "The Deadmines", 1000)
    V.Runs.EncounterStart(store, 644, "Rhahk'Zor", 1100)
    V.Runs.EncounterEnd(store, 644, "Rhahk'Zor", 1, 1160)
    leave(game, M, 1200)
    enter(game, M, "The Deadmines", 1300) -- back within REJOIN
    T.eq(#store.runs, 0, "same run")
    leave(game, M, 1400)
    leave(game, M, 1400 + V.Runs.REJOIN)
    T.eq(store.runs[1].outcome, "incomplete", "one of two bosses")
    enter(game, M, "The Deadmines", 5000)
    leave(game, M, 5100)
    leave(game, M, 5100 + V.Runs.REJOIN)
    T.eq(store.runs[2].outcome, "abandoned")
  end)

  T.it("a reload or disconnect mid-fight is unknown, never a wipe", function()
    local game, _, V, M = start()
    local store = V.Runs.Store()
    enter(game, M, "The Deadmines", 1000)
    V.Runs.EncounterStart(store, 644, "Rhahk'Zor", 1100)
    -- the client went away; next login much later, outside
    M.resumed = nil
    game.instance = nil
    M:RunCheck(1100 + V.Runs.REJOIN + 5)
    local run = store.runs[1]
    T.eq(run.outcome, "unknown")
    T.ok(run.censorReason:find("lost track"))
    T.eq(run.attempts[1].result, "unknown", "not counted as a wipe")
    -- a quick reload inside continues the run
    enter(game, M, "The Deadmines", 9000)
    V.Runs.EncounterStart(store, 644, "Rhahk'Zor", 9100)
    M.resumed = nil
    M:RunCheck(9130)
    T.ok(store.open and store.open.startedAt == 9000, "continued after a quick reload")
  end)

  T.it("roster changes are counted; nothing about who changed", function()
    local game, _, V, M = start()
    local store = V.Runs.Store()
    enter(game, M, "The Deadmines", 1000)
    game.units.party3 = { name = "Zed", player = true, guid = "Player-1-0000F00D", level = 20, class = "MAGE" }
    game:fire("GROUP_ROSTER_UPDATE")
    T.eq(store.open.rosterChanges, 1)
  end)

  T.it("over the cap, the oldest runs move to the archive; nothing is lost and old runs stay findable", function()
    local _, ns, V = start()
    local store = V.Runs.Store()
    local n = V.Runs.CAP + 15
    for i = 1, n do
      V.Runs.Enter(store, "The Deadmines", { bosses = 2 }, i * 100)
      V.Runs.Close(store, "left", i * 100 + 50)
    end
    T.eq(#store.runs, V.Runs.CAP)
    T.eq(#ns.Archive:Rows("vanguardRuns"), 15, "the rest are archived")
    local all = V.Runs.All(store)
    T.eq(#all, n, "every run is still there to read")
    T.eq(all[1].startedAt, 100, "the oldest first")
    -- archive refuses: the run stays in the active list
    local put = ns.Archive.Put
    ns.Archive.Put = function() return false, "disk full" end
    V.Runs.Enter(store, "The Deadmines", { bosses = 2 }, 999999)
    V.Runs.Close(store, "left", 1000000)
    T.eq(#store.runs, V.Runs.CAP + 1, "kept, not dropped")
    ns.Archive.Put = put
  end)

  T.it("a damaged or newer saved store is never overwritten", function()
    local _, ns, V = start()
    ns.db.char.vanguardRuns = "garbage"
    local s = V.Runs.Store()
    T.ok(s and type(s.runs) == "table")
    local damaged = ns.db.global.archiveDamaged
    T.ok(damaged and #damaged >= 1, "the bad value was kept aside")
    ns.db.char.vanguardRuns = { v = 99, runs = { { instance = "future" } } }
    local s2, why = V.Runs.Store()
    T.eq(s2, nil)
    T.ok(why:find("newer"))
    T.eq(ns.db.char.vanguardRuns.runs[1].instance, "future", "left exactly as it was")
  end)

  T.it("rates: Wilson interval by hand, unknowns counted apart, sparse data abstains", function()
    local _, _, V = start()
    local F = V.Forecast
    local lo, hi, p = F.Wilson(8, 10)
    T.eq(p, 0.8)
    T.ok(math.abs(lo - 0.4902) < 0.001, "lower " .. lo)
    T.ok(math.abs(hi - 0.9433) < 0.001, "upper " .. hi)
    T.eq(F.Wilson(0, 0), nil)
    T.eq(F.Wilson(3, 2), nil)
    local runs = {}
    for i = 1, 8 do runs[#runs + 1] = { instance = "X", outcome = "completed", startedAt = 0, endedAt = 600 + i * 60,
      attempts = { { encounterId = "1", result = "kill" } } } end
    runs[#runs + 1] = { instance = "X", outcome = "incomplete", attempts = { { encounterId = "1", result = "wipe" }, { encounterId = "1", result = "wipe" } } }
    runs[#runs + 1] = { instance = "X", outcome = "unknown", censorReason = "lost", attempts = { { encounterId = "1", result = "unknown" } } }
    local r = F.Rates(runs, { instance = "X" })
    T.eq(r.kills, 8)
    T.eq(r.wipes, 2)
    T.eq(r.unknown, 1, "unknown fights are not folded in")
    T.eq(r.censoredRuns, 1)
    T.ok(math.abs(r.low - 0.4902) < 0.001)
    T.eq(r.completedRuns, 8)
    T.ok(r.timeMedian >= 600 and r.timeP25 <= r.timeMedian and r.timeMedian <= r.timeP75)
    local sparse = F.Rates({ { instance = "Y", attempts = { { result = "kill" } } } }, { instance = "Y" })
    T.eq(sparse.rate, nil)
    T.ok(sparse.abstain:find("need 5"))
    T.eq(F.Quantile({ 1, 2, 3, 4 }, 0.5), 2.5)
  end)

  T.it("forecast: abstains without an approved real model; synthetic or thin evidence never shows a number", function()
    local _, _, V = start()
    local F = V.Forecast
    local f = F.Predict("full_clear")
    T.eq(f.estimate, nil)
    T.ok(f.abstainReason:find("no approved model"))
    T.ok(F.Predict("win_odds").abstainReason:find("unknown target"))
    local good = { version = "t1", target = "eventual_kill", build = "b", trainingCount = 400, validationCount = 80, holdoutPositives = 30,
      holdoutNegatives = 20, brier = 0.15, baselineBrier = 0.22, approved = true, approvedBy = "independent reviewer" }
    T.ok(F.Eligible(good, { build = "b", coverage = 0.9 }))
    local syn = {}
    for k, v in pairs(good) do syn[k] = v end
    syn.synthetic = true
    T.eq((F.Eligible(syn)), false)
    local thin = {}
    for k, v in pairs(good) do thin[k] = v end
    thin.trainingCount = 199
    T.eq((F.Eligible(thin)), false)
    T.eq((F.Eligible(good, { build = "other" })), false, "another game build")
    T.eq((F.Eligible(good, { coverage = 0.5 })), false, "too much unknown")
    local worse = {}
    for k, v in pairs(good) do worse[k] = v end
    worse.brier = 0.3
    T.eq((F.Eligible(worse)), false, "worse than the base rate")
    -- even an eligible model shows nothing in this build
    F.model = good
    local p = F.Predict("eventual_kill", nil, { build = "b" })
    T.eq(p.estimate, nil)
    T.ok(p.abstainReason:find("not enabled"))
    F.model = nil
    -- calibration helpers
    local b, n = F.Brier({ 0.9, 0.1, 0.8 }, { 1, 0, 0 })
    T.eq(n, 3)
    T.ok(math.abs(b - (0.01 + 0.01 + 0.64) / 3) < 1e-9)
    local rel = F.Reliability({ 0.05, 0.95, 0.92 }, { 0, 1, 0 }, 10)
    T.eq(rel[1].n, 1)
    T.eq(rel[10].n, 2)
    T.eq(rel[10].observed, 0.5)
  end)

  T.it("the Runs page shows past results, no forecast number, and the readiness kept from the start", function()
    local game, ns, V, M = start()
    local store = V.Runs.Store()
    enter(game, M, "The Deadmines", 1000)
    V.Runs.EncounterStart(store, 644, "Rhahk'Zor", 1100)
    V.Runs.EncounterEnd(store, 644, "Rhahk'Zor", 1, 1160)
    leave(game, M, 1200)
    leave(game, M, 1200 + V.Runs.REJOIN)
    local rows = M:RunRows()
    T.eq(rows[1].outcome, "incomplete")
    T.ok(rows[1].readiness ~= "not assessed")
    M:Settings().instance = "The Deadmines"
    local text = M:RatesText()
    T.ok(text:find("No rate yet"), text)
    T.ok(text:find("Forecast: none"))
    T.ok(not text:lower():find("chance"))
    ns.Hub:Toggle()
    ns.Hub:ShowTab("vanguard_runs")
    ns.Hub:Refresh()
    ns.Slash:Run("vgruns")
    -- Group check off: nothing is recorded
    ns.Modules:SetEnabled("Vanguard", false)
    local count = #store.runs
    game.instance = "The Deadmines"
    game:fire("ZONE_CHANGED_NEW_AREA")
    T.eq(store.open, nil)
    T.eq(#store.runs, count)
    T.eq(#ns.Errors.list, 0)
  end)
end)

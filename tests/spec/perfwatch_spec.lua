-- The always-on performance watch (Modules/PerfWatch.lua; Gary, 2026-11-25:
-- a one-second lag while travelling with minimap dots was only found by a
-- player; "collect our data constantly during gameplay").
local T, mock = ...

local function session()
  local game = mock.new({ class = "SHAMAN", level = 2 })
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game:advance(2)
  return game, ns, ns.PerfWatch
end

local function logText(game)
  local L = rawget(game.env, "Outrider_Log")
  local t = {}
  for _, l in ipairs(L and L.lines or {}) do t[#t + 1] = "[" .. tostring(l.m) .. "] " .. tostring(l.x) end
  return table.concat(t, " | ")
end

-- a handler that takes `ms` of the game's time, owned by `name`
local function slowHandler(game, ns, name, event, ms)
  ns.Events:On(event, { name = name }, function() game.clock = game.clock + ms / 1000 end)
end

T.describe("always-on performance watch", function()
  T.it("is on from login without pressing anything, and times every handler", function()
    local game, ns, W = session()
    T.ok(W.enabled and W.on, "watching from login")
    T.ok(ns.timing, "the dispatch times handlers")
    slowHandler(game, ns, "Cheap", "OTR_TEST_CHEAP", 1)
    ns.Events:Fire("OTR_TEST_CHEAP")
    local parts = W:Summary().parts
    local found
    for _, p in ipairs(parts) do if p.name == "Cheap" then found = p end end
    T.ok(found and found.n == 1, "the run is counted per part")
    T.eq(W.cur.spikes, 0, "1 ms is not a spike")
  end)

  T.it("a slow moment while moving is kept with what ran and where (the minimap dots case)", function()
    local game, ns, W = session()
    game.moving = true
    slowHandler(game, ns, "MinimapPins", "OTR_TEST_MOVING", 1000)
    ns.Events:Fire("OTR_TEST_MOVING")
    local list = ns.db.global.perfSlow
    local r = list[#list]
    T.eq(r.kind, "spike")
    T.eq(r.where, "MinimapPins:OTR_TEST_MOVING")
    T.ok(r.ms >= 999, "about a second")
    T.ok(r.moving, "moving is recorded")
    T.contains(ns.PerfPage.SlowRows()[1].text, "MinimapPins")
    T.contains(ns.PerfPage.SlowRows()[1].text, "moving")
    -- it reaches the log for Claude, once per place
    T.contains(logText(game), "slow moment: MinimapPins:OTR_TEST_MOVING")
    ns.Events:Fire("OTR_TEST_MOVING")
    T.eq(list[#list].n, 2, "the same place again soon counts up one row")
  end)

  T.it("a game freeze is kept with how much of it was Outrider's", function()
    local game, ns, W = session()
    game:advance(W.LOADING_S + 1) -- past the login loading screen
    game.clock = game.clock + 1.5 -- the game stalls 1.5 s, Outrider ran nothing
    game:advance(0.6)
    local list = ns.db.global.perfSlow
    local r = list[#list]
    T.eq(r.kind, "hitch")
    T.ok(r.ms >= 1000)
    T.ok((r.ours or 0) < 50, "not Outrider's")
    T.contains(ns.PerfPage.SlowRows()[1].text, "not Outrider")
    T.eq(W.cur.ours, 0)
  end)

  T.it("a freeze caused by an Outrider timer is marked as ours", function()
    local game, ns, W = session()
    game:advance(W.LOADING_S + 1)
    ns.Timer.After(0.1, function() game.clock = game.clock + 1.2 end, "heavy")
    game:advance(1)
    T.eq(W.cur.ours, 1, "the freeze is ours")
    local hitch
    for _, r in ipairs(ns.db.global.perfSlow) do if r.kind == "hitch" then hitch = r end end
    T.ok(hitch and hitch.ours >= 1000)
  end)

  T.it("loading screens don't count as freezes", function()
    local game, ns, W = session()
    game:fire("LOADING_SCREEN_ENABLED")
    game.clock = game.clock + 5
    game:advance(0.6)
    game:fire("LOADING_SCREEN_DISABLED")
    game:advance(1)
    T.eq(W.cur.hitches, 0)
  end)

  T.it("logout saves the session once, minute rows included; past the cap old ones are archived", function()
    local game, ns, W = session()
    game:advance(130)
    game:fire("PLAYER_LOGOUT")
    local list = ns.db.global.perfWatch
    T.eq(#list, 1)
    T.ok(#list[1].minutes >= 2, "a row per minute")
    T.ok(list[1].seconds >= 130)
    T.contains(logText(game), "[PerfWatch] session (logout)")
    game:fire("PLAYER_LOGOUT")
    T.eq(#list, 1, "saved once")
    for i = 1, W.SESSIONS + 1 do list[#list + 1] = { startedAt = i, pct = 0.1, minutes = {} } end
    W.saved = false
    W:Save("test")
    T.eq(#list, W.SESSIONS)
    T.ok(#ns.Archive:Rows("perfWatch") >= 2, "older sessions archived, not dropped")
  end)

  T.it("switched off, nothing is timed; the page says so", function()
    local _, ns, W = session()
    ns.Modules:SetEnabled("PerfWatch", false)
    T.ok(not W.on)
    T.eq(ns.timing, nil, "no timing without a check or the watch")
    T.eq(#ns.db.global.perfWatch, 1, "the session so far was saved")
  end)
end)

T.describe("memory made, by part", function()
  T.it("the watch counts the memory each part makes, and the page lists the biggest makers", function()
    local game, ns, W = session()
    local keep = {}
    ns.Events:On("OTR_TEST_ALLOC", { name = "Hungry" }, function()
      for i = 1, 3000 do keep[#keep + 1] = { i, "row " .. i } end
    end)
    ns.Events:On("OTR_TEST_ALLOC", { name = "Lean" }, function() end)
    -- a collection mid-handler would read low (by design): keep it out of this measurement
    collectgarbage("collect")
    collectgarbage("stop")
    ns.Events:Fire("OTR_TEST_ALLOC")
    collectgarbage("restart")
    local by = {}
    for _, p in ipairs(W:Summary().parts) do by[p.name] = p end
    T.ok(by.Hungry.kb > 100, "the allocating part is charged: " .. by.Hungry.kb)
    T.ok(by.Lean.kb < 1)
    T.eq(ns.PerfPage.Churn()[1].label, "Hungry")
    game:fire("PLAYER_LOGOUT")
    local row = ns.db.global.perfWatch[#ns.db.global.perfWatch]
    T.eq(row.churn[1].name, "Hungry", "saved with the session")
    T.ok(row.kb > 100)
  end)
end)

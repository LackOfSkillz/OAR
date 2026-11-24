-- OI03-01: play session boundaries shared by the recorders (SessionXP, Ledger).
local T, mock = ...

local function boot(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  return game, ns
end
-- a first login
local function login(opts)
  local game, ns = boot(opts)
  game:login()
  return game, ns
end
-- the same character again after the saved file was written: a /reload
-- (isReloadingUi) or a fresh login (isInitialLogin)
local function again(saved, reload, opts)
  opts = opts or {}
  opts.savedVariables = saved
  local game, ns = boot(opts)
  game:fire("ADDON_LOADED", "Outrider")
  game:fire("PLAYER_LOGIN")
  game:fire("PLAYER_ENTERING_WORLD", not reload, reload and true or false)
  return game, ns
end
-- the saved file without a logout event (a crash or a disconnect)
local function crashed(game)
  local out = {}
  for name in (game.tocMeta.SavedVariables or ""):gmatch("[%w_]+") do
    local v = rawget(game.env, name)
    if v ~= nil then out[#out + 1] = name .. " = " .. mock.serialize(v) end
  end
  return table.concat(out, "\n") .. "\n"
end

T.describe("play session boundaries (OI03-01)", function()
  T.it("the decision table: reload continues, logout and interruption end, zoning changes nothing", function()
    local _, ns = login()
    local D = ns.PlaySession.Decide
    T.eq(select(1, D("closing", false, true)), "reload")
    T.eq(select(2, D("closing", true, false)), "logout")
    T.eq(select(2, D("open", true, false)), "interrupted")
    T.eq(select(1, D("open", false, false)), "zone")
    T.eq(select(1, D(nil, true, false)), "new")
  end)

  T.it("a reload keeps the session and starts segment 2; a later logout and login start a new one", function()
    local game, ns = login()
    local id = ns.PlaySession:Id()
    T.ok(id)
    local g2, ns2 = again(game:logout(), true)
    T.eq(ns2.PlaySession:Id(), id)
    T.eq(ns2.PlaySession:Segment(), 2)
    T.eq(ns2.PlaySession:Current().lastEnd.reason, "reload")
    local g3, ns3 = again(g2:logout(), false)
    T.ok(ns3.PlaySession:Id() ~= id)
    T.eq(ns3.PlaySession:Current().lastEnd.reason, "logout")
  end)

  T.it("a login with no logout before it marks the last session interrupted", function()
    local game, ns = login()
    local _, ns2 = again(crashed(game), false)
    T.eq(ns2.PlaySession:Current().lastEnd.reason, "interrupted")
  end)

  T.it("XP: a reload is not a completed session, nothing is counted twice, and the segments merge", function()
    local game, ns = login()
    ns.Modules:SetEnabled("SessionXP", true)
    local X = ns.SessionXP
    X.current.durationSeconds = 900
    X.current.xpEarned = 3000
    local _, ns2 = again(game:logout(), true)
    ns2.Modules:SetEnabled("SessionXP", true)
    local hist = ns2.SessionXP:Store().history
    T.eq(#hist, 1, "one segment saved")
    T.eq(hist[1].endReason, "reload")
    T.eq(hist[1].final, false, "a reload is not a completed session")
    T.eq(ns2.SessionXP.current.playSessionId, hist[1].playSessionId)
    T.eq(ns2.SessionXP.current.segment, 2)
    ns2.SessionXP.current.durationSeconds = 600
    ns2.SessionXP.current.xpEarned = 2000
    ns2.SessionXP:Checkpoint(true)
    local merged = ns2.SessionXP:Merged()
    T.eq(#merged, 1, "one play session")
    T.eq(merged[1].segments, 2)
    T.eq(merged[1].xpEarned, 5000)
    T.eq(merged[1].final, true)
    T.eq(hist[1].xpEarned, 3000, "the saved segment itself is unchanged")
  end)

  T.it("XP: a disconnect gives an incomplete, interrupted record, never a completed one", function()
    local game, ns = login()
    ns.Modules:SetEnabled("SessionXP", true)
    ns.SessionXP.current.durationSeconds = 300
    local _, ns2 = again(crashed(game), false)
    ns2.Modules:SetEnabled("SessionXP", true)
    local hist = ns2.SessionXP:Store().history
    T.eq(#hist, 1)
    T.eq(hist[1].final, false)
    T.eq(hist[1].endReason, "interrupted")
    T.ok(hist[1].flags.incomplete)
  end)

  T.it("XP: the same turn-in reported twice counts once", function()
    local game, ns = login()
    ns.Modules:SetEnabled("SessionXP", true)
    game:fire("QUEST_TURNED_IN", 123, 500)
    game:fire("QUEST_TURNED_IN", 123, 500)
    T.eq(#ns.SessionXP.current.questsTurnedIn, 1)
  end)

  T.it("Gold: a reload's ledger rows are one session for the per-hour forecast", function()
    local game, ns = login()
    local L = ns.Ledger
    L.start, L.startMoney, L.money = game.now - 1800, 0, 5000
    local g2, ns2 = again(game:logout(), true)
    local L2 = ns2.Ledger
    L2.start, L2.startMoney, L2.money = g2.now - 1800, 0, 7000
    local _, ns3 = again(g2:logout(), false)
    local rows = ns3.db.char.ledger
    T.eq(#rows, 2, "both segments are kept")
    T.eq(rows[1].endReason, "reload")
    T.eq(rows[2].endReason, "logout")
    local merged = ns3.Ledger.Merged(rows)
    T.eq(#merged, 1)
    T.eq(merged[1].net, 12000)
  end)

  T.it("two characters keep their own sessions", function()
    local game, ns = login({ name = "Alpha" })
    local a = ns.PlaySession:Id()
    local _, nsB = again(game:logout(), false, { name = "Beta" })
    T.ok(nsB.PlaySession:Id() ~= a)
    T.eq(nsB.PlaySession:Current().lastEnd, nil, "Beta's first session has no previous one")
  end)

  T.it("clearing the XP history archives it first (data preservation)", function()
    local game, ns = login()
    ns.Modules:SetEnabled("SessionXP", true)
    ns.SessionXP:Checkpoint(true)
    game:slash("xp60 clear")
    T.ok(#ns.Archive:Rows("xpSessionsCleared") >= 1, "kept in the archive")
  end)
end)

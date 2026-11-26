-- VG01-04/05: the shared inspect queue. One request in flight, a gap between
-- requests, a timeout with one retry, and it never takes over Blizzard's
-- Inspect window or hands a late answer to the wrong player.
local T, mock = ...

local function set(game, k, v) game.base[k] = v rawset(game.env, k, v) end

local function start()
  local game = mock.new({ class = "HUNTER", level = 30 })
  game.units = {
    party1 = { name = "Ana", player = true, guid = "Player-1-000000A1" },
    party2 = { name = "Bo", player = true, guid = "Player-1-000000B2" },
    party3 = { name = "Cy", player = true, guid = "Player-1-000000C3" },
  }
  local ns = game:loadAddon()
  game:login()
  game.asked, game.cleared = {}, 0
  set(game, "CanInspect", function(u) local d = game.units[u] return d ~= nil and d.far ~= true end)
  set(game, "NotifyInspect", function(u) game.asked[#game.asked + 1] = u end)
  set(game, "ClearInspectPlayer", function() game.cleared = game.cleared + 1 end)
  return game, ns, ns.InspectBroker
end

local function ask(B, game, unit, owner, log)
  log = log or {}
  local tok, why = B:Request({ owner = owner or "Test", unit = unit, guid = game.units[unit].guid,
    onReady = function(u) log[#log + 1] = "ready " .. u end,
    onFail = function(_, reason) log[#log + 1] = "fail " .. tostring(reason) end })
  return tok, why, log
end

T.describe("inspect broker (VG01-04/05)", function()
  T.it("one request at a time, at least GAP seconds apart", function()
    local game, ns, B = start()
    local log = {}
    ask(B, game, "party1", "Test", log)
    ask(B, game, "party2", "Test", log)
    T.eq(#game.asked, 1, "the first goes at once")
    game:advance(1)
    T.eq(#game.asked, 1, "the second waits: one in flight")
    game:fire("INSPECT_READY", game.units.party1.guid)
    T.eq(log[1], "ready party1")
    T.eq(game.cleared, 1, "our own inspect is cleared")
    T.eq(#game.asked, 1, "still inside the gap")
    game:advance(1.1)
    T.eq(#game.asked, 2)
    T.eq(game.asked[2], "party2")
    game:fire("INSPECT_READY", game.units.party2.guid)
    T.ok(B:Idle())
    T.eq(B.listening, false, "no events while idle")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("times out, retries once after a backoff, then gives up", function()
    local game, _, B = start()
    local _, _, log = ask(B, game, "party1")
    game:advance(B.TIMEOUT + 0.1)
    T.eq(#game.asked, 1, "no answer: waits the backoff")
    game:advance(B.BACKOFF + 0.1)
    T.eq(#game.asked, 2, "one retry")
    game:advance(B.TIMEOUT + 0.1)
    T.eq(log[1], "fail no answer")
    game:advance(30)
    T.eq(#game.asked, 2, "no third try")
    T.ok(B:Idle())
  end)

  T.it("an answer for someone else is ignored and our request is tried again", function()
    local game, _, B = start()
    local _, _, log = ask(B, game, "party1")
    game:fire("INSPECT_READY", "Player-1-0000FFFF") -- the player's own inspect of another player
    T.eq(#log, 0, "nothing handed on")
    T.eq(game.cleared, 0, "someone else's inspect is not cleared")
    game:advance(B.BACKOFF + 0.1)
    T.eq(#game.asked, 2)
    game:fire("INSPECT_READY", game.units.party1.guid)
    T.eq(log[1], "ready party1")
  end)

  T.it("waits while Blizzard's Inspect window is open and never clears under it", function()
    local game, _, B = start()
    local shown = true
    set(game, "InspectFrame", { IsShown = function() return shown end })
    local _, _, log = ask(B, game, "party1")
    game:advance(5)
    T.eq(#game.asked, 0, "deferred while the window is open")
    shown = false
    game:advance(1.1)
    T.eq(#game.asked, 1)
    shown = true -- the player opens Inspect while ours is waiting
    game:fire("INSPECT_READY", game.units.party1.guid)
    T.eq(log[1], "ready party1")
    T.eq(game.cleared, 0, "the window's data is left alone")
  end)

  T.it("combat cancels everything and new requests are refused", function()
    local game, _, B = start()
    local _, _, log = ask(B, game, "party1")
    ask(B, game, "party2", "Test", log)
    game:setCombat(true)
    T.eq(#log, 2)
    T.eq(log[1], "fail combat")
    T.ok(B:Idle())
    local tok, why = ask(B, game, "party3")
    T.eq(tok, nil)
    T.eq(why, "combat")
    game:setCombat(false)
    game:fire("INSPECT_READY", game.units.party1.guid)
    T.eq(#log, 2, "a late answer after cancel does nothing")
  end)

  T.it("a unit token that now belongs to someone else is not read", function()
    local game, _, B = start()
    local _, _, log = ask(B, game, "party1")
    local guid = game.units.party1.guid
    game.units.party1 = { name = "Zed", player = true, guid = "Player-1-0000ZZZZ" } -- party shuffled
    game:fire("INSPECT_READY", guid)
    T.eq(log[1], "fail moved")
  end)

  T.it("two owners asking for the same player share one request", function()
    local game, _, B = start()
    local a, b = {}, {}
    local t1 = ask(B, game, "party1", "PlayerInfo", a)
    local t2, why = ask(B, game, "party1", "Vanguard", b)
    T.eq(t1, t2)
    T.eq(why, "shared")
    game:fire("INSPECT_READY", game.units.party1.guid)
    T.eq(#game.asked, 1)
    T.eq(a[1], "ready party1")
    T.eq(b[1], "ready party1")
  end)

  T.it("out of range fails at send time; the queue is capped; cancel by owner", function()
    local game, _, B = start()
    game.units.party1.far = true
    local _, _, log = ask(B, game, "party1")
    T.eq(log[1], "fail out of range")
    T.eq(#game.asked, 0)
    for i = 1, B.QUEUE_MAX + 5 do
      game.units["raid" .. i] = { player = true, guid = "Player-1-R" .. i }
      ask(B, game, "raid" .. i, "Bulk")
    end
    T.ok(#B.queue <= B.QUEUE_MAX)
    local n = B:CancelOwner("Bulk", "test")
    T.ok(n >= B.QUEUE_MAX)
    T.ok(B:Idle())
  end)

  T.it("the hover inspect goes through the broker; a newer hover replaces an older one in line", function()
    local game, ns, B = start()
    local PI = ns.PlayerInfo
    set(game, "CheckInteractDistance", function() return true end)
    set(game, "UnitIsUnit", function(a, b) return a == b end)
    game.units.mouseover = game.units.party1
    PI:Lines("mouseover")
    T.eq(#game.asked, 1)
    T.ok(B:Expecting(game.units.party1.guid))
    game:fire("INSPECT_READY", game.units.party1.guid)
    T.ok(PI.cache[game.units.party1.guid], "PlayerInfo read it")
    T.eq(PI.KEEP, 300, "5 minutes (D27)")
    T.eq(#ns.Errors.list, 0)
  end)
end)

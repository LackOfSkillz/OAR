-- OI03-03: activity timing from observable signals.
local T, mock = ...

local function session()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("Outcomes", true)
  return game, ns, ns.ActivityTimeline
end
local function sum(t) local n = 0 for _, v in pairs(t) do n = n + v end return n end
local function checkContiguous(rec)
  for i = 2, #rec.parts do
    if rec.parts[i].from ~= rec.parts[i - 1].to then return false, i end
    if rec.parts[i].from >= rec.parts[i].to then return false, i end
  end
  return true
end

T.describe("activity timing (OI03-03)", function()
  T.it("the label order: recovery, dungeon, crafting, travel, quest, inactive, unclassified", function()
    local _, ns, A = session()
    local now = 1000
    T.eq(A.Label({ dead = true, instance = true, now = now }), "recovery")
    T.eq(A.Label({ instance = true, crafting = true, now = now }), "dungeon")
    T.eq(A.Label({ crafting = true, taxi = true, now = now }), "crafting")
    T.eq(A.Label({ taxi = true, lastQuestAt = now, now = now }), "travel")
    T.eq(A.Label({ lastQuestAt = now - 10, now = now }), "quest")
    T.eq(A.Label({ lastQuestAt = now - A.QUEST_GAP - 1, lastActiveAt = now, now = now }), "unclassified")
    T.eq(A.Label({ afk = true, now = now }), "inactive")
    T.eq(A.Label({ lastActiveAt = now - A.IDLE - 1, now = now }), "inactive")
  end)

  T.it("a played stretch: segments never overlap and add up to the wall time", function()
    local game, ns, A = session()
    local start = A.rec.from
    game:fire("PLAYER_STARTED_MOVING") game:advance(60)
    game:fire("QUEST_ACCEPTED", 5) game:advance(120)
    game:fire("QUEST_WATCH_UPDATE", 1) game:advance(100)
    game.env.UnitOnTaxi = function() return true end
    game:fire("PLAYER_CONTROL_LOST") game:advance(200)
    game.env.UnitOnTaxi = function() return false end
    game:fire("PLAYER_CONTROL_GAINED") game:advance(30)
    game:fire("TRADE_SKILL_SHOW") game:advance(90)
    game:fire("TRADE_SKILL_CLOSE") game:advance(10)
    game:fire("PLAYER_DEAD") game:advance(40)
    game:fire("PLAYER_UNGHOST") game:advance(20)
    A:Close()
    local rec = A.rec
    T.ok(checkContiguous(rec), "contiguous")
    T.eq(sum(rec.totals), rec.to - start, "adds up to the wall time")
    T.eq(rec.totals.travel, 200)
    T.eq(rec.totals.crafting, 90)
    T.eq(rec.totals.recovery, 40)
    T.ok((rec.totals.quest or 0) >= 220, "quest time from the quest events")
    -- 60 s moving before any quest (walking is not "travel"), plus the 30 s after the
    -- flight: by then the last quest event was more than QUEST_GAP ago
    T.eq(rec.totals.unclassified, 90, "moving around is not called travel or quest")
  end)

  T.it("a quiet stretch is inactive from the last observed moment, and AFK is inactive", function()
    local game, ns, A = session()
    game:fire("PLAYER_STARTED_MOVING")
    game:advance(A.IDLE + 200)
    A:Update()
    game:fire("PLAYER_STARTED_MOVING")
    game:advance(10)
    A:Close()
    T.eq(A.rec.totals.inactive, A.IDLE + 200, "the whole quiet stretch")
    T.ok(checkContiguous(A.rec))
    local g2, ns2, A2 = session()
    g2.env.UnitIsAFK = function() return true end
    g2:fire("PLAYER_FLAGS_CHANGED", "player")
    g2:advance(50)
    A2:Close()
    T.eq(A2.rec.totals.inactive, 50)
  end)

  T.it("a dungeon from the instance check, and unclassified when nothing says what", function()
    local game, ns, A = session()
    game.instance = { name = "Deadmines", kind = "party", map = 36 }
    game:fire("ZONE_CHANGED_NEW_AREA") game:advance(300)
    game.instance = nil
    game:fire("ZONE_CHANGED_NEW_AREA") game:advance(50)
    A:Close()
    T.eq(A.rec.totals.dungeon, 300)
    T.eq(A.rec.totals.unclassified, 50)
  end)

  T.it("totals include the open segment and still match the wall time", function()
    local game, ns, A = session()
    game:fire("QUEST_ACCEPTED", 1)
    game:advance(45)
    local totals, total = A:Totals()
    T.eq(total, game.now - A.rec.from)
    T.eq(totals.quest, 45)
  end)

  T.it("a record per play session segment, stamped with it; the 21st archives the oldest", function()
    local game, ns, A = session()
    T.eq(A.rec.playSessionId, ns.PlaySession:Id())
    local list = A:Records(ns.Outcomes:Store())
    for _ = 1, A.MAX_RECORDS + 1 do A:Start(ns.Outcomes) end
    T.eq(#list, A.MAX_RECORDS)
    T.ok(#ns.Archive:Rows("activitySessions") >= 1)
  end)

  T.it("no combat log and no screen capture anywhere in the timeline", function()
    local fh = assert(io.open("addon/Outrider/Intelligence/ActivityTimeline.lua"))
    local src = fh:read("*a")
    fh:close()
    local code = src:gsub("%-%-[^\n]*", "")
    T.ok(not code:find("COMBAT_LOG"), "no combat log")
    T.ok(not code:find("Screenshot"), "no screenshots")
  end)
end)

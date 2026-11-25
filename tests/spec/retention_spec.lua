-- OI03-15: retention and privacy controls for the outcome recorder.
local T, mock = ...

local function session(on)
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  if on ~= false then ns.Modules:SetEnabled("Outcomes", true) end
  return game, ns, ns.Outcomes
end
local function count(ns) local s = ns.db.char.outcomes return s and s.events and #s.events or 0 end

T.describe("retention and privacy controls (OI03-15)", function()
  T.it("opt-in: off by default, and switched off it records nothing new from any source", function()
    local game, ns, O = session(false)
    T.eq(O.enabled, false)
    local function play()
      game:fire("QUEST_ACCEPTED", 1) game:fire("PLAYER_LEVEL_UP", 5) game:fire("PLAYER_DEAD")
      game.money = 777 game:fire("PLAYER_MONEY")
      ns.Waypoints:Set(1412, 0.5, 0.5, "x") ns.Waypoints:Clear("arrived")
      game:fire("MAIL_INBOX_UPDATE")
      game:advance(120)
    end
    play()
    T.eq(count(ns), 0)
    ns.Modules:SetEnabled("Outcomes", true)
    game:advance(30)
    game:fire("PLAYER_LEVEL_UP", 6)
    local n = count(ns)
    T.ok(n >= 1)
    ns.Modules:SetEnabled("Outcomes", false)
    local trips = #(ns.db.char.outcomes.travel or {})
    local parts = ns.db.char.outcomes.activity and #ns.db.char.outcomes.activity or 0
    play()
    T.eq(count(ns), n, "no new events after switching off")
    T.eq(#(ns.db.char.outcomes.travel or {}), trips, "no new trips")
    T.eq(ns.db.char.outcomes.activity and #ns.db.char.outcomes.activity or 0, parts, "no new timeline records")
  end)

  T.it("retention caps are per character, adjustable within bounds, and overflow goes to the archive", function()
    local game, ns, O = session()
    O:Settings().keep = { events = 150 }
    T.eq(O:Cap("events"), 150)
    O:Settings().keep = { events = 5 }
    T.eq(O:Cap("events"), 100, "never below the lower bound")
    O:Settings().keep = { events = 99999 }
    T.eq(O:Cap("events"), 2000, "never above the upper bound")
    O:Settings().keep = { events = 120 }
    for i = 1, 130 do O:Record("zone_entered", { subject = "map:" .. i }) end
    T.eq(#O:Store().events, 120)
    T.ok(#ns.Archive:Rows("outcomeEvents") >= 10, "the oldest are archived, not dropped")
    O:Settings().keep = { chronicle = 100 }
    for i = 1, 105 do ns.Chronicle:Add(O, "zone", "z" .. i, "Zone " .. i, game.now + i) end
    T.eq(#ns.Chronicle:Entries(O), 100)
  end)

  T.it("Start fresh archives everything first and restarts the working state", function()
    local game, ns, O = session()
    game:fire("PLAYER_LEVEL_UP", 9)
    ns.Waypoints:Set(1412, 0.5, 0.5, "x")
    local A = ns.AfterAction
    local ok, why = A.StartFresh()
    T.eq(ok, false) T.eq(why, "armed", "the first click only asks")
    T.ok(count(ns) >= 1, "nothing changed yet")
    ok = A.StartFresh()
    T.ok(ok)
    T.eq(count(ns), 0)
    local kept = ns.Archive:Rows("outcomesReset")[1].row
    T.ok(#kept.events >= 1, "the old record is in the archive")
    T.eq(ns.TravelTimes.trip, nil, "the open trip started over")
    T.eq(ns.ActivityTimeline.rec.playSessionId, ns.PlaySession:Id(), "a new timeline record")
  end)

  T.it("a second click after ten seconds asks again", function()
    local game, ns = session()
    game:fire("PLAYER_LEVEL_UP", 9)
    ns.AfterAction.StartFresh()
    game:advance(11)
    local ok, why = ns.AfterAction.StartFresh()
    T.eq(ok, false) T.eq(why, "armed")
  end)

  T.it("export gives the records as a data code that reads back the same; nothing is sent", function()
    local game, ns, O = session()
    game:fire("PLAYER_LEVEL_UP", 9)
    local before = #game.chat
    local text = O:ExportText()
    T.ok(text:find("^Outrider outcome records: %d+ events"))
    local code = text:match("\n(.+)$")
    local back = ns.Serialize.Import(code)
    T.eq(back.events[1].kind, "level_up")
    T.eq(#game.chat, before, "exporting says nothing in chat and sends nothing")
  end)

  T.it("no provider needed: the report and evidence work with no companion and no advice file", function()
    local game, ns = session()
    game.env.Outrider_Advice = nil
    game:fire("PLAYER_LEVEL_UP", 9)
    local rep = ns.AfterAction.Report(ns.PlaySession:Id())
    T.ok(rep and rep.gold)
    T.ok(ns.AfterAction.EvidenceText(ns.AfterAction.MyEvidence()):find("AfterAction measurement report"))
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("migration: a store from another schema is archived whole before a new one starts", function()
    local game, ns, O = session(false)
    ns.db.char.outcomes = { schema = 0, events = { { kind = "old" } } }
    O:Store()
    T.eq(ns.db.char.outcomes.schema, O.SCHEMA)
    T.eq(ns.Archive:Rows("outcomeEvents")[1].row.events[1].kind, "old")
  end)

  T.it("the page's new controls have tooltips", function()
    local game, ns = session()
    ns.Hub:Build():Show()
    ns.Hub:ShowTab("afteraction")
    local missing = {}
    for label in pairs(ns.UI.untipped or {}) do missing[#missing + 1] = label end
    T.eq(#missing, 0, table.concat(missing, ", "))
  end)
end)

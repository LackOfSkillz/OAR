-- OI03-02: observed outcome events.
local T, mock = ...

local function session()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("Outcomes", true)
  return game, ns, ns.Outcomes
end
local function last(O) local ev = O:Store().events return ev[#ev] end

T.describe("outcome events (OI03-02)", function()
  T.it("off by default (opt-in); records nothing until switched on", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    T.eq(ns.Outcomes.enabled, false)
    game:fire("QUEST_TURNED_IN", 5, 100)
    T.eq(#(ns.db.char.outcomes and ns.db.char.outcomes.events or {}), 0)
  end)

  T.it("quests: accepted, completed with its XP, abandoned only without a turn-in", function()
    local game, ns, O = session()
    game:fire("QUEST_ACCEPTED", 7)
    T.eq(last(O).kind, "quest_accepted") T.eq(last(O).subject, "quest:7")
    game:fire("QUEST_TURNED_IN", 7, 450)
    local ev = O:Store().events
    T.eq(ev[#ev - 1].kind, "quest_completed")
    T.eq(ev[#ev].kind, "xp_gain") T.eq(ev[#ev].amount, 450)
    game:fire("QUEST_REMOVED", 7)
    game:advance(2)
    T.ok(last(O).kind ~= "quest_abandoned", "removed after a turn-in is not abandoned")
    game:fire("QUEST_REMOVED", 8)
    game:advance(2)
    T.eq(last(O).kind, "quest_abandoned") T.eq(last(O).subject, "quest:8")
  end)

  T.it("dedups by meaning: the same happening twice is one record; a real repeat later is two", function()
    local game, ns, O = session()
    game:fire("QUEST_ACCEPTED", 9)
    game:fire("QUEST_ACCEPTED", 9)
    local n = #O:Store().events
    T.eq(n, 1)
    game:advance(30)
    game:fire("QUEST_ACCEPTED", 9)
    T.eq(#O:Store().events, 2)
  end)

  T.it("money in and out, with the open window as context", function()
    local game, ns, O = session()
    local m = 1000
    game.env.GetMoney = function() return m end
    O.money = 1000
    game:fire("MERCHANT_SHOW")
    m = 700
    game:fire("PLAYER_MONEY")
    T.eq(last(O).kind, "money_out") T.eq(last(O).amount, 300) T.eq(last(O).context, "vendor spend")
    game:fire("MERCHANT_CLOSED")
    m = 900
    game:fire("PLAYER_MONEY")
    T.eq(last(O).kind, "money_in") T.eq(last(O).amount, 200) T.eq(last(O).context, "loot and quests")
  end)

  T.it("missing or secret values are left out and named, never guessed", function()
    local game, ns, O = session()
    game.env.GetInventoryItemID = function() return nil end
    game:fire("PLAYER_EQUIPMENT_CHANGED", 5, false)
    T.eq(last(O).subject, nil)
    T.eq(last(O).unknownFields[1], "subject")
    local secret = setmetatable({}, { __secret = true })
    local real = ns.Compat.IsSecret
    ns.Compat.IsSecret = function(v) return v == secret or real(v) end
    local rec = O:Record("money_in", { amount = secret })
    ns.Compat.IsSecret = real
    T.eq(rec.amount, nil)
    T.eq(rec.unknownFields[1], "amount")
  end)

  T.it("another character's record is refused; a future one too", function()
    local game, ns, O = session()
    local rec, why = O:Record("death", { characterKey = "char:someone-else" })
    T.eq(rec, nil) T.eq(why, "other character")
    rec, why = O:Record("death", { at = game.now + 3600 })
    T.eq(why, "future")
  end)

  T.it("late records are marked and never attributed", function()
    local game, ns, O = session()
    O.lastActed = { planId = "plan:1", stepId = "opp:q", at = game.now - 100, subjects = { ["quest:3"] = true } }
    local rec = O:Record("quest_completed", { subject = "quest:3", at = game.now - 90 - O.LATE })
    T.ok(rec.late)
    T.eq(rec.attribution, "unknown")
  end)

  T.it("attribution: likely only after Go on a step about the same thing, inside the window; never direct", function()
    local game, ns, O = session()
    local N = ns.NexusCore
    N:Settings().on = true
    local S = ns.WhatNow.SOURCES
    for k in pairs(S) do S[k] = function() return {} end end
    S.quests = function() return { { key = "quest:Q", kind = "quest", title = "Q", benefit = 0.9, confidence = 0.8, seconds = 60,
      label = "observed", questID = 42, mapID = 1, go = function() end } } end
    local cur = N:Replan("x")
    T.ok(N:Act(cur.result.plan.steps[1]))
    game:fire("QUEST_TURNED_IN", 42, 0)
    local rec = O:Store().events[#O:Store().events]
    T.eq(rec.attribution, "likely")
    T.eq(rec.stepId, cur.result.plan.steps[1])
    game:fire("QUEST_TURNED_IN", 43, 0)
    T.eq(last(O).attribution, "unknown", "a different quest")
    game:advance(O.ATTRIBUTION_WINDOW + 60)
    game:fire("QUEST_ACCEPTED", 42)
    T.eq(last(O).attribution, "unknown", "outside the window")
    for _, e in ipairs(O:Store().events) do T.ok(e.attribution ~= "direct") end
  end)

  T.it("death and recovery; a release as a ghost is not a recovery", function()
    local game, ns, O = session()
    game:fire("PLAYER_DEAD")
    T.eq(last(O).kind, "death")
    game.env.UnitIsGhost = function() return true end
    game:fire("PLAYER_ALIVE")
    T.eq(last(O).kind, "death", "released as a ghost")
    game:fire("PLAYER_UNGHOST")
    T.eq(last(O).kind, "recovery")
  end)

  T.it("every record is a valid v4 OutcomeEvent bound to this play session", function()
    local game, ns, O = session()
    game:fire("PLAYER_LEVEL_UP", 13)
    game:fire("ZONE_CHANGED_NEW_AREA")
    for _, e in ipairs(O:Store().events) do
      T.ok(ns.Nexus.Validate("OutcomeEvent", e))
      T.eq(e.sessionId, ns.PlaySession:Id())
    end
  end)

  T.it("the 501st record archives the oldest, nothing is lost", function()
    local game, ns, O = session()
    for i = 1, O:Cap("events") + 1 do O:Record("zone_entered", { subject = "map:" .. i }) end
    T.eq(#O:Store().events, O:Cap("events"))
    T.ok(#ns.Archive:Rows("outcomeEvents") >= 1)
  end)
end)

T.describe("fail-safe schema migration (review OI-FR03)", function()
  local function broken(ns)
    local put, keep = ns.Archive.Put, ns.Archive.KeepDamaged
    ns.Archive.Put = function() return false, "injected" end
    ns.Archive.KeepDamaged = function() error("injected") end
    return function() ns.Archive.Put, ns.Archive.KeepDamaged = put, keep end
  end

  T.it("outcomes: when the old store can't be kept, it stays saved untouched", function()
    local _, ns, O = session()
    local old = { schema = 0, events = { { kind = "quest_completed", subject = "quest:1" } } }
    ns.db.char.outcomes = old
    local undo = broken(ns)
    local s = O:Store()
    T.eq(ns.db.char.outcomes, old, "original still saved")
    T.eq(old.schema, 0) T.eq(#old.events, 1)
    T.ok(s.recovery, "working on an unsaved copy")
    T.ok(O:Activity():find("could not be archived", 1, true))
    undo()
    O.scratch = nil
    local s2 = O:Store()
    T.ok(ns.db.char.outcomes ~= old and s2.schema == O.SCHEMA, "replaced once it can be kept")
    local found = false
    for _, e in ipairs(ns.Archive:Rows("outcomeEvents")) do if e.row and e.row.schema == 0 then found = true end end
    T.ok(found, "old store in the archive")
  end)

  T.it("XP history and the class profile follow the same rule", function()
    local _, ns = session()
    local oldXp = { schema = 0, history = { { xp = 5 } } }
    ns.db.char.xp60 = oldXp
    local oldProf = { schema = -1, role = "dps", note = "keep me" }
    ns.db.char.intelligenceProfile = oldProf
    local undo = broken(ns)
    T.ok(ns.SessionXP:Store().recovery)
    T.eq(ns.db.char.xp60, oldXp)
    local P = ns.ClassProfiles
    local st = P.State and P.State() or nil
    T.eq(ns.db.char.intelligenceProfile, oldProf, "profile left as it was")
    if st then T.ok(st.recovery) T.eq(st.role, "dps") end
    undo()
  end)
end)

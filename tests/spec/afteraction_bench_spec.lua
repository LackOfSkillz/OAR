-- OI03-14: the measurement harness is repeatable, discloses its counts and claims nothing.
local T, mock = ...
package.path = "./tests/lib/?.lua;" .. package.path
local F = require("afteraction_fixture")

local function session()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("AfterAction measurement harness (OI03-14)", function()
  T.it("the same fixture gives the same report, byte for byte", function()
    local _, ns = session()
    local a = ns.AfterAction.EvidenceText(ns.AfterAction.Evidence(F.Build(42)))
    local _, ns2 = session()
    local b = ns2.AfterAction.EvidenceText(ns2.AfterAction.Evidence(F.Build(42)))
    T.eq(a, b)
    T.ok(a ~= ns.AfterAction.EvidenceText(ns.AfterAction.Evidence(F.Build(7))), "another seed, another report")
  end)

  T.it("held-out: both estimates scored on the same later samples, with the counts", function()
    local _, ns = session()
    local ev = ns.AfterAction.Evidence(F.Build(42))
    T.eq(ev.quests.samples, 40, "only complete quests are samples")
    T.eq(ev.quests.train + ev.quests.test, 40)
    T.ok(ev.quests.priorMedianAbsError and ev.quests.personalMedianAbsError)
    T.ok(ev.quests.personalMedianAbsError < ev.quests.priorMedianAbsError, "the fixture's quests run longer than 300 s")
  end)

  T.it("routes are paired; a route walked once and a flight are not compared", function()
    local _, ns = session()
    local ev = ns.AfterAction.Evidence(F.Build(42))
    T.eq(ev.routes.unmatched, 1)
    for _, r in ipairs(ev.routes.paired) do T.ok(r.trips >= 2) T.ok(r.route ~= "1>9", "the flight is not a walking route") end
  end)

  T.it("sessions are compared only when matched; otherwise it says not compared", function()
    local _, ns = session()
    local ev = ns.AfterAction.Evidence(F.Build(42))
    T.eq(#ev.sessions.compared, 1)
    T.eq(ev.sessions.compared[1].withPlan, 4) T.eq(ev.sessions.compared[1].withoutPlan, 4)
    local few = F.Build(42)
    for i = 4, 8 do few.sessions[i].levelStart = 50 end
    local ev2 = ns.AfterAction.Evidence(few)
    T.eq(#ev2.sessions.compared, 0)
    T.ok(ev2.sessions.note:find("Not compared"))
  end)

  T.it("no causal claims anywhere in the report, and nothing that identifies a player", function()
    local _, ns = session()
    local text = ns.AfterAction.EvidenceText(ns.AfterAction.Evidence(F.Build(42))):lower()
    for _, w in ipairs({ "improv", "because", "thanks to", "caused", "boost" }) do T.ok(not text:find(w, 1, true), w) end
    T.ok(text:find("not proof", 1, true), "the attribution caveat is stated")
    local ev = ns.AfterAction.Evidence(F.Build(42))
    local function walk(v)
      if type(v) == "table" then for k, x in pairs(v) do T.ok(k ~= "name" and k ~= "characterKey" and k ~= "at", tostring(k)) walk(x) end end
    end
    walk(ev)
  end)

  T.it("the committed report is what the tool writes today", function()
    local _, ns = session()
    local fh = io.open("docs/quality/afteraction_bench.md")
    T.ok(fh, "report present")
    local committed = fh:read("*a"):gsub("\r", "")
    fh:close()
    T.eq(committed, ns.AfterAction.EvidenceText(ns.AfterAction.Evidence(F.Build(42))))
  end)
end)

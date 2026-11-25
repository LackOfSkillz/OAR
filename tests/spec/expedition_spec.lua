-- OI07-01..10: modes, lessons, curriculum, delivery, practice, mentor bundles, troubleshooter, confidence, recovery, challenges.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts or { level = 20, class = "HUNTER" })
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("experience modes (OI07-01)", function()
  T.it("the same facts in every mode; only how much is said changes", function()
    local _, ns = session()
    local M = ns.Modes
    T.eq(M.Pick("Short.", { "a", "b", "c" }, { "e" }, "beginner"), "Short.")
    T.eq(M.Pick("Short.", { "a", "b", "c" }, { "e" }, "experienced"), "Short. a b")
    T.eq(M.Pick("Short.", { "a", "b", "c" }, { "e" }, "advanced"), "Short. a b c Evidence: e")
    T.ok(M.Set("advanced")) T.eq(M.Current(), "advanced")
    T.no(M.Set("expert"))
    ns.OraclePage.Save()
    local adv = ns.OraclePage.Cards()[1].line
    M.Set("beginner")
    local beg = ns.OraclePage.Cards()[1].line
    T.ok(#beg < #adv, "beginner says less")
    T.ok(adv:find("Evidence"))
  end)
end)

T.describe("lessons (OI07-02..05)", function()
  T.it("every lesson meets the contract and every class has the four topics", function()
    local _, ns = session()
    local X = ns.Expedition
    local topics = {}
    for _, l in ipairs(X.LESSONS) do
      T.eq(X.Check(l), nil, l.id)
      topics[l.class] = topics[l.class] or {}
      topics[l.class][l.topic] = true
      T.ok(l.source:find("unverified") or l.source:find("tests"), l.id .. " says where it's from")
    end
    for _, class in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }) do
      for _, t in ipairs(X.TOPICS) do T.ok(topics[class] and topics[class][t], class .. " " .. t) end
    end
    T.eq(X.Check({ id = "bad", class = "HUNTER", topic = "fundamentals", needs = {}, source = "x" }), "bad id")
  end)

  T.it("a lesson whose spell you don't know is skipped; class, role and level fit", function()
    local _, ns = session()
    local X = ns.Expedition
    ns.Spellbook.spells = {}
    local ids = {}
    for _, l in ipairs(X.Eligible({ class = "HUNTER", level = 20 })) do ids[l.id] = true end
    T.ok(ids["hunter.group.1@1"], "no spell needed")
    T.no(ids["hunter.fundamentals.1@1"], "Auto Shot unknown: skipped")
    ns.Spellbook.spells["auto shot"] = { name = "Auto Shot" }
    ids = {}
    for _, l in ipairs(X.Eligible({ class = "HUNTER", level = 20 })) do ids[l.id] = true end
    T.ok(ids["hunter.fundamentals.1@1"])
    ids = {}
    for _, l in ipairs(X.Eligible({ class = "PRIEST", role = "dps", level = 20 })) do ids[l.id] = true end
    T.no(ids["priest.group.1@1"], "the healer lesson isn't for a damage priest")
  end)

  T.it("offered out of combat only; skip, off and reset work; topics you choose come first", function()
    local game, ns = session()
    local X = ns.Expedition
    X.SetTopics({ "group" })
    local first = X.Offer(1)[1]
    T.eq(first.topic, "group")
    X.Skip(first.id)
    T.ok(X.Offer(5)[1].id ~= first.id)
    game.combat = true
    T.eq(select(2, X.Offer()), "not in combat")
    game.combat = false
    X.SetOn(false)
    T.eq(select(2, X.Offer()), "lessons are off")
    X.SetOn(true)
    X.Reset()
    T.eq(X.Offer(1)[1].id, first.id, "reset brings it back")
  end)

  T.it("practice compares like with like only; without fights it's practice in words", function()
    local _, ns = session()
    local X = ns.Expedition
    local l = X.LESSONS[1]
    T.ok(X.Practice(l).check.verdict:find("practice only"))
    local fights = { { dps = 50, build = "b", duration = 60 }, { dps = 52, build = "b", duration = 60 }, { dps = 51, build = "b", duration = 60 } }
    local p = X.Practice(l, fights, { estimate = { lo = 40, hi = 60 }, build = "b", fight = 60 })
    T.eq(p.check.inside, true)
    T.eq(X.Answer("hunter.fundamentals.1@1", 2), true)
    T.eq(select(2, X.Answer("hunter.utility.1@1", 1)), "this lesson has no question")
    local src = io.open("addon/Outrider/Intelligence/Expedition.lua"):read("*a")
    for _, bad in ipairs({ "CastSpell", "RunMacro", "UseAction", "SecureCmd" }) do T.ok(not src:find(bad, 1, true), bad) end
  end)
end)

T.describe("mentor bundles (OI07-06)", function()
  T.it("preview lists what fits and what doesn't; nothing is installed without accepting that preview", function()
    local _, ns = session()
    local PS = ns.PlanShare
    T.eq(select(2, PS.ExportBundle({ steps = { "a" } })), "a bundle needs a license")
    local text = PS.ExportBundle({ title = "Mulgore", license = "CC-BY", steps = { "quest:1" },
      lessons = { "hunter.group.1@1", "mage.group.1@1" }, route = { { mapID = 1412, x = 0.5, y = 0.5, name = "Camp" }, { mapID = 1412, x = 5, y = 1 } } })
    local pv = PS.PreviewBundle(text)
    T.eq(#pv.fits.lessons, 1) T.eq(#pv.fits.route, 1) T.ok(pv.fits.plan)
    T.eq(#pv.left, 2)
    T.no(PS.AcceptBundle(pv, "x"))
    T.eq(ns.Expedition.Store().assigned, nil)
    T.ok(PS.AcceptBundle(pv, pv.token))
    T.eq(ns.Expedition.Store().assigned["hunter.group.1@1"].license, "CC-BY")
    T.eq(PS.Store().routes[1].points[1].name, "Camp")
    T.eq(ns.Expedition.Offer(1)[1].id, "hunter.group.1@1", "an assigned lesson comes first")
    T.eq(select(2, PS.PreviewBundle(ns.Serialize.Export({ v = 1, kind = "bundle" }))), "no license: not installed")
  end)
end)

T.describe("troubleshooter, confidence, recovery and challenges (OI07-07..10)", function()
  T.it("each finding has a reason and a manual remedy; a failing check says it couldn't check; export hides names", function()
    local _, ns = session()
    local TS = ns.Troubleshooter
    ns.db.global.probe = { apis = { ["C_Foo.Bar"] = false, ["C_Ok.Yes"] = true } }
    ns.World.quarantine.badpack = { why = "no license" }
    local r = TS.Run()
    local codes = {}
    for _, x in ipairs(r) do codes[x.code] = x T.ok(x.remedy, x.code) end
    T.ok(codes.unsupported_api and codes.unsupported_api.text:find("C_Foo.Bar"))
    T.ok(codes.missing_pack and codes.missing_pack.text:find("badpack"))
    ns.MacroLibrary:Settings().installed.Fight = { body = "/cast Arcane Shot(Rank 2)" }
    T.ok(table.concat((function() local t = {} for _, x in ipairs(TS.Run()) do t[#t + 1] = x.code end return t end)(), ","):find("macro_rank"))
    ns.Data.All = function() error("boom") end
    local broken = TS.Run()
    local couldnt = false
    for _, x in ipairs(broken) do if x.couldnt then couldnt = true end end
    T.ok(couldnt, "a broken check isn't reported as fine")
    T.ok(not TS.Export(broken):find("Torrant"))
  end)

  T.it("Verified needs evidence; the badge is a word with when and where", function()
    local _, ns = session()
    local CF = ns.Confidence
    T.eq(CF.Level({ verified = true }), "community", "no evidence: not verified")
    T.eq(CF.Level({ verified = true, verifiedOn = { date = "2026-11-11" } }), "verified")
    T.ok(CF.Text({ verified = true, verifiedOn = { date = "2026-11-11", build = "70862" }, source = "Gary" }):find("%[Verified%] seen 2026%-11%-11, build 70862 %(Gary%)"))
    T.eq(CF.Text({}), "[Unknown]")
    T.ok(CF.Text({ source = "x", flavor = "classic" }):find("Classic"))
    T.ok(CF.Estimate("about 50", "your fights", 3):find("estimate from your fights, 3 records"))
  end)

  T.it("after a game update or on another character, nothing is claimed done", function()
    local game, ns = session()
    local R = ns.NexusRecovery
    game.questsDone = { [100] = true }
    local saved = { at = 0, steps = { { id = "q", title = "Wolves", questID = 100 } }, build = "60000", char = ns.db.key }
    game.env.C_QuestLog = game.env.C_QuestLog or {}
    game.env.C_QuestLog.IsQuestFlaggedCompleted = function(id) return id == 100 end
    local r = R.Check(saved, 100)
    T.eq(r.steps[1].status, "check")
    T.ok(r.patched)
    saved.char = "Someone-Else"
    T.eq(R.Check(saved, 100), nil)
  end)

  T.it("challenges: unknown visits are never done; dismiss and reset; just for fun", function()
    local _, ns = session()
    local CH = ns.Challenges
    ns.Data:Register("zoneguide", "spec", { { name = "Testlands", lo = 15, hi = 25, source = "spec", verified = false } })
    local list = CH.List({ level = 20, faction = "Horde" })
    local visit
    for _, c in ipairs(list) do if c.id == "visit:Testlands" then visit = c end end
    T.eq(visit.state, "unknown", "the outcome recorder is off by default")
    CH.Dismiss("visit:Testlands")
    for _, c in ipairs(CH.List({ level = 20 })) do T.ok(c.id ~= "visit:Testlands") end
    CH.Reset()
    local back = false
    for _, c in ipairs(CH.List({ level = 20 })) do if c.id == "visit:Testlands" then back = true end end
    T.ok(back)
    T.ok(CH.Cards()[1].line:find("no timer"))
    T.eq(#ns.Errors.list, 0)
  end)
end)

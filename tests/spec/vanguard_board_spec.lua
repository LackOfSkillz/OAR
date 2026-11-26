-- Vanguard VG03: encounter catalog, access graph, readiness math, boss
-- matrix, improvement plan, Nexus adapter, report, context invalidation and
-- the standalone scenario (one Outrider, no peers, no desktop, no internet).
local T, mock = ...

local function set(game, k, v) game.base[k] = v rawset(game.env, k, v) end

local function start(units)
  local game = mock.new({ class = "HUNTER", level = 20 })
  game.units = units or {
    party1 = { name = "Khreos", player = true, guid = "Player-1-0000BEEF", level = 20, class = "WARRIOR", role = "TANK" },
    party2 = { name = "Mirae", player = true, guid = "Player-1-0000CAFE", level = 17, class = "PRIEST", role = "HEALER" },
    party3 = { name = "Zed", player = true, guid = "Player-1-0000F00D", level = 21, class = "MAGE", role = "NONE" },
  }
  local ns = game:loadAddon()
  game:login()
  game.inGroup = true
  game.asked = {}
  set(game, "UnitGroupRolesAssigned", function(u) local d = game.units[u] return d and d.role or "NONE" end)
  set(game, "CanInspect", function(u) return game.units[u] ~= nil end)
  set(game, "UnitIsConnected", function() return true end)
  set(game, "UnitIsUnit", function(a, b) return a == b end)
  set(game, "NotifyInspect", function(u) game.asked[#game.asked + 1] = u end)
  -- a small dungeon pack for the catalog
  ns.DungeonGuide.ByName = function() return { ["The Deadmines"] = { bosses = { { 644, "Rhahk'Zor", 19, nil, {} },
    { 639, "Edwin VanCleef", 21, nil, {} } }, items = {} } } end
  -- these tests check the template logic alone; researched facts have their own spec
  ns.VanguardFacts = { bosses = {}, access = {}, raids = {}, prices = {}, enchants = {} }
  ns.Vanguard.Facts.Reset()
  ns.Vanguard.Catalog.Reset()
  ns.Modules:SetEnabled("Vanguard", true)
  return game, ns, ns.Vanguard, ns.VanguardModule
end

local function res(score, id)
  for _, r in ipairs(score.results or score) do if r.id == id then return r end end
end

T.describe("vanguard encounter assessment (VG03)", function()
  T.it("catalog: places from the data, reference not verified, raids without an invented makeup", function()
    local _, ns, V = start()
    local cat = V.Catalog.Get()
    T.ok(#cat.list > 20, "every dungeon and raid in the data")
    local dm = V.Catalog.Find("The Deadmines")
    T.eq(dm.availability, "reference")
    T.eq(#dm.encounters, 2)
    T.eq(dm.encounters[2].level, 21)
    local found = {}
    for _, r in ipairs(dm.requirements) do found[r.id] = r T.ok(r.verification ~= "verified", "nothing claims verified") end
    T.ok(found.tank and found.healer and found.interrupt)
    local ony = V.Catalog.Find("Onyxia's Lair")
    for _, r in ipairs(ony.requirements) do T.ok(r.category ~= "role", "no role template for a raid") end
    local joined = table.concat(ony.unknowns, "; ")
    T.ok(joined:find("raid makeup"), joined)
    T.ok(joined:find("boss mechanics"))
    T.ok(table.concat(V.Catalog.Find("Scholomance").unknowns, ";"):find("bosses"), "no pack bosses: said so")
    T.ok(cat.version:find("^1%."))
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("access graph: AND/OR, unknown is not denied, loops end as unknown", function()
    local _, _, V = start()
    local A = V.Access
    local env = { level = 30, quest = function(id) if id == 1 then return true elseif id == 2 then return false end end,
      item = function(id) return id == 7 and 1 or 0 end, manual = function() return nil end }
    local g = {
      root = { kind = "all", children = { "lvl", "either" } },
      lvl = { kind = "level", value = 25 },
      either = { kind = "any", children = { "q2", "key" } },
      q2 = { kind = "quest", value = 2 }, key = { kind = "item", value = 7 },
    }
    T.eq((A.Eval(g, "root", env)), "met", "level and (quest or key)")
    g.key.value = 8
    T.eq((A.Eval(g, "root", env)), "unmet", "neither the quest nor the key")
    g.q2.value = 3
    T.eq((A.Eval(g, "root", env)), "unknown", "quest state unreadable: unknown, not denied")
    local loop = { a = { kind = "all", children = { "b" } }, b = { kind = "ref", value = "a" } }
    local s, why = A.Eval(loop, "a", env)
    T.eq(s, "unknown")
    T.ok(why:find("loop"), why)
    T.eq((A.Eval({ root = { kind = "any", children = { "x" } } }, "root", env)), "unknown", "missing node")
    T.eq((A.Check(V.Catalog.Find("The Deadmines"), {})), "met", "level 20 for an 18+ place, no key known to be needed")
    T.eq((A.Check(V.Catalog.Find("Scholomance"), {})), "unmet", "level 20 for a 55+ place")
    T.eq((A.Check(V.Catalog.Find("Scholomance"), { access = { Scholomance = true } })), "unmet", "your access answer doesn't skip the level")
  end)

  T.it("readiness math: all unknown never gives a score, ranges, coverage, critical gates, monotonic and deterministic", function()
    local _, _, V = start()
    local R = V.Readiness
    local unknown = R.Score({ { id = "a", weight = 3, l = 0, u = 1 }, { id = "b", weight = 1, l = 0, u = 1 } })
    T.eq(unknown.point, nil)
    T.eq(unknown.state, "unknown")
    T.eq(unknown.low, 0)
    T.eq(unknown.high, 100)
    local part = R.Score({ { id = "a", weight = 3, l = 1, u = 1 }, { id = "b", weight = 1, l = 0, u = 1 } })
    T.eq(part.coverage, 0.75)
    T.eq(part.state, "range", "75% known is under the 80% line: a range")
    T.eq(part.low, 75)
    T.eq(part.high, 100)
    T.eq(part.knownOnly, 100)
    local full = R.Score({ { id = "a", weight = 3, l = 1, u = 1 }, { id = "b", weight = 1, l = 0, u = 0 } })
    T.eq(full.point, 75)
    -- monotonic: improving one requirement never lowers anything
    local better = R.Score({ { id = "a", weight = 3, l = 1, u = 1 }, { id = "b", weight = 1, l = 0.5, u = 0.5 } })
    T.ok(better.point > full.point)
    -- deterministic
    T.eq(R.Score({ { id = "a", weight = 2, l = 0.3, u = 0.6 } }).low, R.Score({ { id = "a", weight = 2, l = 0.3, u = 0.6 } }).low)
    -- critical: confirmed missing blocks; unknown is not established; met is observed
    T.eq(R.Score({ { id = "k", weight = 1, critical = true, l = 0, u = 0 }, { id = "z", weight = 9, l = 1, u = 1 } }).gate, "blocked",
      "a high average can't hide a missing critical")
    T.eq(R.Score({ { id = "k", weight = 1, critical = true, l = 0, u = 1 } }).gate, "not established")
    T.eq(R.Score({ { id = "k", weight = 1, critical = true, l = 1, u = 1 } }).gate, "prerequisites observed")
    -- bad inputs: zero weight, NaN, out of range
    local bad = R.Score({ { id = "x", weight = 0, l = 1, u = 1 }, { id = "y", weight = 0 / 0, l = 1, u = 1 }, { id = "z", weight = 1, l = -3, u = 7 } })
    T.eq(bad.totalWeight, 1)
    T.eq(bad.low, 0)
    T.eq(bad.high, 100)
    T.eq(R.Score({}).state, "no requirements")
    T.ok(R.Text(part):find("75 to 100"))
  end)

  T.it("assessment: roles, levels, utility, per-boss risks from the boss level, your own boss rules", function()
    local game, ns, V, M = start()
    local a = M:Assessment("The Deadmines")
    T.ok(a, "built")
    T.eq(res(a, "tank").l, 1)
    T.eq(res(a, "healer").l, 1)
    local dmg = res(a, "damage")
    T.ok(dmg.u > dmg.l, "unknown roles widen the damage count")
    T.eq(res(a, "size").l, 0.8, "4 of 5")
    T.ok(res(a, "level").l < 1, "one member below the place's level 18")
    T.eq(#a.bosses, 2)
    local van = a.bosses[2]
    local joined = table.concat(van.risks, "; ")
    T.ok(joined:find("level 21"), "members below the boss's level: " .. joined)
    T.eq(van.mechanics, "unknown (not in the data)")
    -- your own rule for one boss only
    ns.Slash:Run("vgboss Rhahk'Zor dispel_poison")
    local b = M:Assessment("The Deadmines")
    T.eq(b.bosses[1].mine, 1)
    T.eq(b.bosses[2].mine, 0, "the other boss is unchanged")
    T.ok(res(b.bosses[1].results, "boss:dispel_poison"), "the rule is there")
    T.eq(res(b.bosses[1].results, "boss:dispel_poison").verification, "manual")
    -- no probability anywhere
    for _, r in ipairs(a.results) do T.ok(not tostring(r.text):find("%%"), "no percent chance in " .. r.text) end
    T.eq(#game.asked, 0, "assessing sends no inspect")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("access answers become a critical gate; unknown access stays out", function()
    local _, _, _, M = start()
    local a = M:Assessment("The Deadmines")
    T.eq(res(a, "access"), nil, "no answer: no access requirement")
    M:Settings().access["The Deadmines"] = false
    local b = M:Assessment("The Deadmines")
    T.eq(b.score.gate, "blocked")
    M:Settings().access["The Deadmines"] = true
    local c = M:Assessment("The Deadmines")
    T.ok(c.score.gate ~= "blocked")
  end)

  T.it("context invalidation: a group, role or answer change makes the old one unusable at once", function()
    local game, _, V, M = start()
    local a = M:Assessment("The Deadmines")
    T.ok((V.Assess.Valid(a, M:AssessKey("The Deadmines"))))
    M:SetRole("Player-1-0000F00D", "DAMAGER")
    T.eq((V.Assess.Valid(a, M:AssessKey("The Deadmines"))), false, "role changed")
    local b = M:Assessment("The Deadmines")
    game.units.party3 = nil
    game:fire("GROUP_ROSTER_UPDATE")
    T.eq((V.Assess.Valid(b, M:AssessKey("The Deadmines"))), false, "group changed")
    local c = M:Assessment("The Deadmines")
    M:Settings().access["The Deadmines"] = true
    T.eq((V.Assess.Valid(c, M:AssessKey("The Deadmines"))), false, "your answer changed")
    -- an assessment that used a profile expires with it
    M:Scan()
    local d = M:Assessment("The Deadmines")
    T.eq(d.expiresAt ~= nil, true, "your own profile was read")
    T.eq((V.Assess.Valid(d, M:AssessKey("The Deadmines"), d.expiresAt + 1)), false, "old gear readings")
    T.ok(M:Assessment("The Deadmines") ~= d, "a fresh one is built, never the old")
  end)

  T.it("plan: your actions ranked, unknown cost never free, reserve protected, enchant waits, peers get text only", function()
    local _, ns, V = start()
    local prep = {
      { id = "repair", state = "missing", action = "repair", text = "Repair: 20%" },
      { id = "food", state = "missing", action = "food", have = 2, want = 10, text = "Food" },
      { id = "bags", state = "missing", action = "bags", text = "2 free" },
      { id = "enchant:8", state = "missing", action = "enchant", slot = 8, text = "No enchant: feet" },
      { id = "ammo", state = "missing", action = "ammo", have = 100, want = 1000, costCopper = 5000, text = "Ammo" },
      { id = "ok", state = "ok", action = "food", text = "fine" },
    }
    ns.Treasurer.Fits = function(spend) return { fits = spend < 1000 } end
    local acts, advice = V.Plan.Actions(prep, { results = { { id = "healer", category = "role", rule = "healers", text = "0 of 1", l = 0, u = 0 } } },
      { upgrades = { [8] = true } })
    T.eq(acts[1].id, "repair", "critical first")
    local by = {}
    for i, a in ipairs(acts) do by[a.id] = a a.pos = i end
    T.eq(by.food.costUnknown, true, "price unknown, never free")
    T.eq(by.food.title, "Buy food: 8 more")
    T.eq(by.bags.costCopper, 0)
    T.eq(by.ammo.overReserve, true, "5000 copper would dip into the reserve")
    T.eq(by["enchant:8"].waits, true, "boots could be replaced: decide first")
    T.ok(by.ammo.pos > by.food.pos and by["enchant:8"].pos > by.food.pos, "reserve and waiting ranked last")
    T.eq(by.ok, nil)
    T.eq(#advice, 1)
    T.ok(advice[1]:find("nothing is sent"), advice[1])
  end)

  T.it("Nexus: the plan's candidates pass the real adapter; off means none", function()
    local game, ns, V, M = start()
    game.durability = { [1] = { 5, 100 } }
    local cands = V.Plan.Candidates()
    T.ok(#cands >= 1, "repair at least")
    local adapted = 0
    for _, c in ipairs(cands) do
      local rec, why = ns.NexusAdapters.Adapt("vanguard", c, 1)
      T.ok(rec, "adapts: " .. tostring(why))
      if rec then
        adapted = adapted + 1
        T.eq(rec.intent, "panel")
        if c.costCopper == nil then T.eq(rec.costUnknown, true, "unknown cost reaches the planner as unknown") end
      end
    end
    T.ok(adapted > 0)
    -- in the planner's full collection
    local list = ns.NexusAdapters:All(1)
    local found = false
    for _, o in ipairs(list) do if o.opportunityId:find("^opp:vanguard:vg:") then found = true end end
    T.ok(found, "collected by Adapters:All")
    ns.Modules:SetEnabled("Vanguard", false)
    T.eq(#V.Plan.Candidates(), 0, "Group check off: no candidates")
    -- an invalid candidate is rejected, not forced into shape
    T.eq((ns.NexusAdapters.Adapt("vanguard", { key = "vg:x", kind = "errand", title = "", benefit = 1 }, 1)), nil)
  end)

  T.it("report: you press Copy; names left out unless you ask", function()
    local _, ns, _, M = start()
    local text = M:ReportText("The Deadmines", false)
    T.ok(text:find("The Deadmines"))
    T.ok(not text:find("Khreos") and not text:find("Mirae"), "no names by default")
    T.ok(not text:lower():find("chance"), "no chance of winning")
    local named = M:ReportText("The Deadmines", true)
    T.ok(named:find("Khreos"), "names only when you ask")
    local shown
    ns.UI.TextDialog = function(_, title, body) shown = body end
    M:CopyReport(false)
    T.ok(shown and not shown:find("Khreos"))
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("standalone: roster only, then a partial inspect, with no peers, desktop or internet", function()
    local game, ns, V, M = start()
    -- roster only: useful and honest
    local a = M:Assessment("The Deadmines")
    T.ok(a.score.state ~= "no requirements")
    T.ok(table.concat(a.unknowns, ";"):find("not scanned"), "says who wasn't scanned")
    -- a partial inspect: one answers, one is out of range
    game.units.party3.far = true
    set(game, "CanInspect", function(u) local d = game.units[u] return d ~= nil and not d.far end)
    M:Scan()
    game:fire("INSPECT_READY", "Player-1-0000BEEF")
    game:advance(2.1)
    game:fire("INSPECT_READY", "Player-1-0000CAFE")
    game:advance(30)
    local b = M:Assessment("The Deadmines")
    T.ok(b.contextKey ~= a.contextKey, "new readings, new context")
    T.ok(table.concat(b.unknowns, ";"):find("1 member"), table.concat(b.unknowns, ";"))
    ns.Hub:Toggle()
    ns.Hub:ShowTab("vanguard_board")
    ns.Hub:Refresh()
    T.eq(ns.Comm.outbox and #ns.Comm.outbox or 0, 0, "nothing sent to anyone")
    T.eq(#ns.Errors.list, 0)
  end)
end)

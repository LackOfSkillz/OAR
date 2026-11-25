-- OI05-01 scenario contract and OI05-02 Oracle comparisons.
local T, mock = ...

local function session()
  local game = mock.new({ level = 20, class = "HUNTER" })
  local ns = game:loadAddon()
  game:login()
  game.money = 100000
  return game, ns, ns.Scenario, ns.Oracle
end

T.describe("scenario contract (OI05-01)", function()
  T.it("a branch leaves the live character untouched (same hash before and after)", function()
    local _, ns, S = session()
    local before = S.Hash(S.Base())
    local base = S.Base()
    local sc = S.Branch(base, { spend = 50000, gear = { [16] = 1234 }, role = "pet" })
    T.ok(sc)
    T.eq(S.Hash(S.Base()), before, "live state unchanged")
    T.eq(S.Hash(base), before, "the base copy unchanged")
    T.eq(sc.state.copper, 50000)
    T.eq(sc.state.gear[16], 1234)
  end)

  T.it("a scenario is frozen: changing it is refused", function()
    local _, _, S = session()
    local sc = S.Branch(S.Base(), {})
    T.ok(not pcall(function() sc.state.copper = 1 end))
  end)

  T.it("invalid hypotheticals are refused with the reason", function()
    local _, _, S = session()
    local base = S.Base()
    T.eq(select(2, S.Branch(base, { level = 70 })), "level must be 1 to 60")
    T.eq(select(2, S.Branch(base, { gear = { [25] = 1 } })), "gear slot must be 1 to 19")
    T.eq(select(2, S.Branch(base, { gear = { [5] = -3 } })), "gear item must be an item id")
    T.eq(select(2, S.Branch(base, { role = "healer" })), "your class can't play healer")
    T.eq(select(2, S.Branch(base, { spend = 999999 })), "spending must be 0 to the gold you have")
    T.ok(select(2, S.Branch(base, { talents = { [1] = 20 } })):find("more than level 20 has"))
    T.eq(select(2, S.Branch(base, { professions = { Cooking = 999 } })), "profession skill must be 0 to 450")
  end)

  T.it("version, base hash, overrides and assumptions are carried", function()
    local _, _, S = session()
    local base = S.Base()
    local sc = S.Branch(base, { level = 21 }, { "rested XP ignored" })
    T.eq(sc.version, S.VERSION) T.eq(sc.baseHash, S.Hash(base))
    T.eq(sc.overrides.level, 21)
    local a = S.Raw(sc).assumptions
    T.eq(a[#a], "rested XP ignored")
  end)
end)

T.describe("Oracle comparisons (OI05-02)", function()
  T.it("known dimensions get deltas; unknown ones are listed, not filled in", function()
    local _, ns, S, O = session()
    ns.GearScore.Compare = function(_, link) if link == "item:1234" then return { pct = 12.4 } end end
    local base = S.Base()
    local a = S.Branch(base, {})
    local b = S.Branch(base, { spend = 30000, gear = { [16] = 1234, [17] = 999 }, talents = { [1] = 5 } })
    local r = O.Compare(a, b)
    local d = {}
    for _, x in ipairs(r.dims) do d[x.name] = x end
    T.eq(d.gold.delta, -30000)
    T.eq(d["gear slot 16"].delta, 12, "whole numbers, no fabricated precision")
    local unk = table.concat(r.unknown, "|")
    T.ok(unk:find("gear slot 17") and unk:find("talent change") and unk:find("plan for each"), unk)
  end)

  T.it("a stale or mismatched base asks for a refresh", function()
    local game, ns, S, O = session()
    local base = S.Base()
    local a, b = S.Branch(base, {}), S.Branch(base, { spend = 1 })
    game.money = 5
    local r = O.Compare(a, b, { liveHash = S.Hash(S.Base()) })
    T.ok(r.stale and r.stale:find("refresh"))
    local other = S.Branch(S.Base(), {})
    T.ok(O.Compare(a, other).stale)
  end)

  T.it("with a current plan, each scenario's plan value is compared (relative, not a promise); offline", function()
    local game, ns, S, O = session()
    local N = ns.NexusCore
    N:Settings().on = true
    local Src = ns.WhatNow.SOURCES
    for k in pairs(Src) do Src[k] = function() return {} end end
    Src.gear = function() return { { key = "gear:Bow", kind = "gear", title = "Buy Bow", benefit = 0.9, confidence = 0.8, seconds = 100,
      label = "observed", costCopper = 60000 } } end
    N:Replan("x")
    game.env.Outrider_Advice = nil
    local base = S.Base()
    local r = O.Compare(S.Branch(base, {}), S.Branch(base, { spend = 90000 }))
    local plan
    for _, x in ipairs(r.dims) do if x.name == "plan value" then plan = x end end
    T.ok(plan and plan.unit:find("not a promise"))
    T.ok(plan.delta < 0, "less gold: the bow no longer fits")
    T.eq(#ns.Errors.list, 0)
  end)
end)

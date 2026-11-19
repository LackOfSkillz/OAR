-- Fixes from Gary's page tour (2026-11-19).
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("tour fixes 2026-11-19", function()
  T.it("fishing: the zone you're in first, the other faction's home zones left out", function()
    local _, ns = session()
    local F = ns.FishingGuide
    local tier = { zones = { "Dun Morogh", "Durotar", "Elwynn Forest", "Mulgore", "Teldrassil", "Tirisfal Glades", "Zephras Isle" } }
    T.eq(F.ZoneFaction("Durotar"), "Horde")
    T.eq(F.ZoneFaction("Zephras Isle"), nil, "both factions fish there")
    local z = F.ZonesFor(tier, "Zephras Isle", "Alliance")
    T.eq(z[1], "Zephras Isle")
    T.same(z, { "Zephras Isle", "Dun Morogh", "Elwynn Forest", "Teldrassil" })
  end)

  T.it("status counts only this build's errors; older ones stay listed", function()
    local _, ns = session()
    ns.Errors.list, ns.Errors.byKey = {}, {}
    table.insert(ns.Errors.list, { where = "lua:old", msg = "fixed long ago", count = 369, build = "older-build" })
    table.insert(ns.Errors.list, { where = "lua:older", msg = "no build tag", count = 3 })
    T.eq(ns.Errors:Fresh(), 0)
    ns.Errors:Record("test", "new one")
    T.eq(ns.Errors:Fresh(), 1)
    T.eq(#ns.Errors.list, 3)
  end)

  T.it("an item's source text has no item name or upgrade size in it", function()
    local _, ns = session()
    local c = { name = "Worn Ranger's Dagger", pct = 120, kind = "drop", where = { who = "Slydris" } }
    T.eq(ns.Nearby.Source(c), "dropped by Slydris")
    T.contains(ns.Nearby.Describe(c), "Worn Ranger's Dagger")
  end)

  T.it("stripping a colour code keeps the next word whole", function()
    local s = ("|cffbbbbbbdropped by Slydris|r"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    T.eq(s, "dropped by Slydris")
  end)

  T.it("measured loot rate says whose loot it is", function()
    local _, ns = session()
    T.contains(ns.MoneyGuide.RateText({ rate = 4486, measured = true }), "all your characters")
    T.contains(ns.MoneyGuide.RateText({ rate = 4486 }), "guide, unverified")
  end)

  T.it("map reveal drops the old dark tint", function()
    local _, ns = session()
    local s = ns.MapReveal:Settings()
    s.tint = 0.55
    ns.MapReveal:Refresh()
    T.eq(s.tint, nil)
  end)
end)

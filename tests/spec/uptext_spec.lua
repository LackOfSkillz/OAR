-- Upgrade wording (2026-11-18 tour: "+285%" wasn't believable).
local T, mock = ...

T.describe("upgrade wording", function()
  T.it("past +100% says big upgrade; GearQuest sources never show raw tokens", function()
    local game = mock.new({ class = "HUNTER", level = 20 })
    local ns = game:loadAddon()
    game:login()
    T.eq(ns.GearScore.UpText(285), "big upgrade")
    T.eq(ns.GearScore.UpText(100), "big upgrade")
    T.eq(ns.GearScore.UpText(24.4), "+24%")
    T.eq(ns.GearQuestBridge.SOURCE.boss_drop, "boss drop")
    local line = ns.Nearby.Describe({ name = "Hood", pct = 12, kind = "gearquest", via = "crafted" })
    T.no(line:find("?", 1, true), "no placeholder")
  end)
end)

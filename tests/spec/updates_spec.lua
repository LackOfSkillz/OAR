-- Update notices for family builds: age reminder once a day, newer build seen from another user.
local T, mock = ...

T.describe("update notices", function()
  T.it("a family build two weeks old reminds once a day; a newer build from someone pops once", function()
    local game = mock.new({ now = 1794600000 + 20 * 86400 })
    local ns = game:loadAddon()
    ns.build = "v0.3.0-family-20261113-1500"
    game:login()
    ns.Updates:CheckAge()
    T.contains(game:chatText(), "Update Outrider")
    local _, n = game:chatText():gsub("Update Outrider", "")
    ns.Updates:CheckAge()
    local _, n2 = game:chatText():gsub("Update Outrider", "")
    T.eq(n2, n, "not twice in a day")
    ns.Updates:OnComm(nil, "KIT", { build = "v0.3.0-family-20261120-0900" }, "Lily-Realm")
    T.ok(ns.Updates.told)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("developer builds say nothing", function()
    local game = mock.new()
    local ns = game:loadAddon()
    ns.build = "20261114-151333-aa8a79b+"
    game:login()
    ns.Updates:CheckAge()
    T.ok(not game:chatText():find("Update Outrider", 1, true))
  end)
end)

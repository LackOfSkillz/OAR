-- Town errand list (P8-06).
local T, mock = ...

T.describe("errands", function()
  T.it("lists repair and trainer, toasts once on entering a town", function()
    local game = mock.new({ level = 24 })
    local ns = game:loadAddon()
    game:login()
    game.durability = { [1] = { 20, 50 }, [5] = { 80, 80 } }
    local kinds = {}
    for _, e in ipairs(ns.Errands:List()) do kinds[e.kind] = e.text end
    T.contains(kinds.repair, "40%")
    T.contains(kinds.trainer, "level 24")
    game.resting = true
    game:fire("PLAYER_UPDATE_RESTING")
    T.eq(ns.Toast:Count(), 1)
    T.contains(ns.Toast.visible[1].title:GetText(), "errands in town")
    game:fire("PLAYER_UPDATE_RESTING")
    T.eq(ns.Toast:Count(), 1, "quiet for 10 minutes")
    game:fire("TRAINER_SHOW")
    game.durability = nil
    for _, e in ipairs(ns.Errands:List()) do T.no(e.kind == "trainer" or e.kind == "repair") end
    game:slash("errands")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("nothing outside towns", function()
    local game = mock.new({ level = 24 })
    local ns = game:loadAddon()
    game:login()
    game:fire("PLAYER_UPDATE_RESTING")
    T.eq(ns.Toast:Count(), 0)
  end)
end)

-- Shared knowledge for family installs: fills gaps, never overwrites, lists not doubled.
local T, mock = ...

T.describe("shared knowledge", function()
  T.it("merges once per version, keeps the account's own data, copies lists only into empty ones", function()
    local game = mock.new()
    game.base.Outrider_DataShared = { version = "v1", data = {
      discovered = { npcs = { [100] = { name = "Shared Wolf" }, [200] = { name = "Shared Name" } } },
      nodes = { { kind = "herb", x = 0.1, y = 0.2 } },
      prices = { [765] = { 10, 12 } },
    } }
    rawset(game.env, "Outrider_DataShared", game.base.Outrider_DataShared)
    local ns = game:loadAddon()
    game:login()
    local g = ns.db.global
    T.eq(g.discovered.npcs[100].name, "Shared Wolf")
    T.eq(#g.nodes, 1)
    T.eq(g.sharedImported, "v1")
    -- second run: already imported
    g.discovered.npcs[200].name = "My Own Name"
    T.eq(ns.SharedData:Import(), 0)
    T.eq(g.discovered.npcs[200].name, "My Own Name")
    -- a new version never overwrites and never doubles a list
    game.env.Outrider_DataShared.version = "v2"
    game.env.Outrider_DataShared.data.discovered.npcs[200] = { name = "Changed" }
    ns.SharedData:Import()
    T.eq(g.discovered.npcs[200].name, "My Own Name")
    T.eq(#g.nodes, 1)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("does nothing without the shared data addon", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    T.eq(ns.db.global.sharedImported, nil)
    T.eq(#ns.Errors.list, 0)
  end)
end)

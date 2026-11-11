-- Gear sets (P6-09).
local T, mock = ...

T.describe("gear sets", function()
  T.it("saves what is worn and puts it back, never in combat", function()
    local game = mock.new()
    game.worn = { [1] = 501, [16] = 502 }
    local ns = game:loadAddon()
    game:login()
    game:slash("gear save Fishing")
    game.worn = { [1] = 601, [16] = 602 }
    game.combat = true
    game:slash("gear fishing")
    T.eq(game.worn[1], 601)
    game.combat = false
    game:slash("gear fishing")
    T.eq(game.worn[1], 501)
    T.eq(game.worn[16], 502)
    T.contains(game:chatText(), "equipped 'fishing'")
    T.eq(#ns.Errors.list, 0)
  end)
end)

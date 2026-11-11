-- TameHelper macro writer (P2-08, macro part).
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("tame macro", function()
  T.it("updates an existing macro by name and keeps its icon", function()
    local game, ns = session({ macros = { { name = "Mystmane", icon = 132164, body = "#showtooltip Mystmane\n/cast Tame Beast", perChar = true } } })
    game:slash("tamemacro Mystmane")
    local m = game.macros[1]
    T.eq(m.icon, 132164)
    T.contains(m.body, "/targetexact Mystmane")
    T.contains(m.body, "/cast [nocombat] Concussive Shot")
    T.contains(m.body, "/castsequence [combat] reset=combat Tame Beast, Wing Clip")
    T.ok(#m.body <= 255)
    T.eq(#game.macros, 1)
    T.contains(game:chatText(), "updated macro 'Mystmane'")
  end)

  T.it("creates a per-character macro when none exists", function()
    local game = session()
    game:slash("tamemacro Ghost Howl")
    T.eq(game.macros[1].name, "Ghost Howl")
    T.ok(game.macros[1].perChar)
    T.contains(game.macros[1].body, "/targetexact Ghost Howl")
  end)

  T.it("refuses in combat and for other classes, without errors", function()
    local game, ns = session()
    game.combat = true
    game:slash("tamemacro Mystmane")
    T.eq(#game.macros, 0)
    T.contains(game:chatText(), "not in combat")
    local g2 = mock.new({ class = "PRIEST" })
    local ns2 = g2:loadAddon()
    g2:login()
    g2:slash("tamemacro Mystmane")
    T.eq(#g2.macros, 0)
    T.eq(#ns.Errors.list + #ns2.Errors.list, 0)
  end)
end)

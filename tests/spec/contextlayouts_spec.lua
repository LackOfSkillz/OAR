-- Context layouts (P7-09): off until assigned, switches only out of combat.
local T, mock = ...

local function session()
  local game = mock.new()
  game.env.C_EditMode = {
    GetLayouts = function() return { activeLayout = game.active or 1,
      layouts = { { layoutName = "Questing" }, { layoutName = "Town" } } } end,
    SetActiveLayout = function(i) game.active = i end,
  }
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.ContextLayouts
end

T.describe("context layouts", function()
  T.it("does nothing until a layout is assigned", function()
    local game, ns, L = session()
    game.resting = true
    game:fire("PLAYER_UPDATE_RESTING")
    T.eq(L.context, "city")
    T.eq(game.active, nil)
  end)

  T.it("switches to the assigned layout per situation, never in combat", function()
    local game, ns, L = session()
    game:slash("layout city Town")
    game:slash("layout questing Questing")
    T.eq(game.active, 3, "presets first, then Questing = 3")
    game.resting = true
    game:fire("PLAYER_UPDATE_RESTING")
    T.eq(game.active, 4, "Town")
    game:fire("AUCTION_HOUSE_SHOW")
    T.eq(L.context, "auction")
    game:fire("AUCTION_HOUSE_CLOSED")
    game.resting = false
    game.combat = true
    game:fire("PLAYER_UPDATE_RESTING")
    T.eq(game.active, 4, "no switch in combat")
    game.combat = false
    game:fire("PLAYER_REGEN_ENABLED")
    T.eq(game.active, 3, "switched after the fight")
    game:slash("layout city Nope")
    T.contains(game:chatText(), "no Edit Mode layout called 'Nope'")
    T.eq(#ns.Errors.list, 0)
  end)
end)

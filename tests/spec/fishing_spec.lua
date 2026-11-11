-- Fishing on one key (P5-11).
local T, mock = ...

local function session()
  local game = mock.new({ cvars = { Sound_SFXVolume = "0.5", Sound_MusicVolume = "0.4", Sound_AmbienceVolume = "0.6" } })
  game.spells[#game.spells + 1] = { name = "Fishing", id = 7620 }
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  return game, ns
end

T.describe("fishing", function()
  T.it("off until a key is chosen; pole on binds the key to the cast button", function()
    local game, ns = session()
    game.pole = true
    game:fire("PLAYER_EQUIPMENT_CHANGED")
    T.ok(ns.Fishing.on)
    T.eq(game.overrides, nil, "no key chosen yet")
    game:slash("fishkey f")
    T.contains(game.overrides.F, "CLICK Outrider_SecureButton")
    T.eq(ns.Fishing.button:GetAttribute("macrotext"), "/cast Fishing")
  end)

  T.it("bobber out: the key interacts; channel over: back to casting", function()
    local game, ns = session()
    game:slash("fishkey F")
    game.pole = true
    game:fire("PLAYER_EQUIPMENT_CHANGED")
    game:fire("UNIT_SPELLCAST_CHANNEL_START", "player", "g", 7620)
    T.eq(game.overrides.F, "INTERACTTARGET")
    game:fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "g", 7620)
    T.contains(game.overrides.F, "CLICK")
  end)

  T.it("loud splash while fishing, old volumes restored after; nothing protected in combat", function()
    local game, ns = session()
    game:slash("fishkey F")
    game.pole = true
    game:fire("PLAYER_EQUIPMENT_CHANGED")
    T.eq(game.opts.cvars.Sound_SFXVolume, "1.0")
    game.pole = false
    game:fire("PLAYER_EQUIPMENT_CHANGED")
    T.eq(game.opts.cvars.Sound_SFXVolume, "0.5")
    T.eq(game.opts.cvars.Sound_MusicVolume, "0.4")
    T.same(game.overrides, {})
    T.eq(#game.blocked, 0)
    T.eq(#ns.Errors.list, 0)
  end)
end)

-- Mana potion on Alt + Heal / Ctrl + Recover and the low mana cue (Gary,
-- 2026-11-22: "only take mana potions if mana is below a certain level"). A
-- macro can't see mana, so Outrider shows a cue and Gary presses the key.
local T, mock = ...

local function druid(level, bags)
  local game = mock.new({ class = "DRUID", level = level, race = "NightElf" })
  game.spells = { { name = "Wrath", id = 1 }, { name = "Healing Touch", id = 2 }, { name = "Rejuvenation", id = 3 } }
  game.items = {
    [11] = { name = "Minor Mana Potion", sell = 5, reqLevel = 5 },
    [12] = { name = "Lesser Mana Potion", sell = 30, reqLevel = 14 },
    [13] = { name = "Minor Healing Potion", sell = 3 },
  }
  game.bags = { [0] = bags }
  game.units = game.units or {}
  game.units.player = { focus = 100, focusMax = 100 }
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game:advance(3)
  return game, ns
end

T.describe("mana care", function()
  T.it("puts the best mana potion you can use on Alt + Heal", function()
    local _, ns = druid(10, { 11, 12, 13 })
    T.eq(ns.ManaCare:Potion(), "Minor Mana Potion", "the Lesser one needs level 14")
    local heal = ns.HunterFight:Body("heal")
    T.contains(heal, "/use [mod:alt] Minor Mana Potion")
    local _, ns20 = druid(20, { 11, 12 })
    T.eq(ns20.ManaCare:Potion(), "Lesser Mana Potion")
  end)

  T.it("no mana potion: nothing on Alt", function()
    local _, ns = druid(10, { 13 })
    T.eq(ns.ManaCare:Potion(), nil)
    T.ok(not ns.HunterFight:Body("heal"):find("mod:alt", 1, true))
  end)

  T.it("the Recover key drinks it on Ctrl", function()
    local _, ns = druid(10, { 11, 13 })
    local rec
    for _, e in ipairs(ns.ComboKeys:Entries()) do if e.name == "Recover" then rec = e end end
    T.ok(rec, "Recover key")
    T.contains(rec.body, "/use [mod:ctrl] Minor Mana Potion")
  end)

  T.it("cues once per fight under 30% mana, only in a fight", function()
    local game, ns = druid(10, { 11 })
    local MC = ns.ManaCare
    game.units.player.focus = 20
    game:fire("UNIT_POWER_UPDATE", "player", "MANA")
    T.ok(not MC.cued, "out of combat: no cue")
    game.combat = true
    game:fire("UNIT_POWER_UPDATE", "player", "MANA")
    T.ok(MC.cued, "cued")
    T.contains(MC.frame.text:GetText(), "Mana 20%: Alt + Heal drinks Minor Mana Potion")
    game.units.player.focus = 50
    game.combat = false
    game:fire("PLAYER_REGEN_ENABLED")
    T.ok(not MC.cued, "ready again for the next fight")
    game.combat = true
    game:fire("UNIT_POWER_UPDATE", "player", "MANA")
    T.ok(not MC.cued, "50% is fine")
    T.eq(#ns.Errors.list, 0)
  end)
end)

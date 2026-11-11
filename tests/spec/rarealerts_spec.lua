-- RareAlerts (P2-04). Unit data is test data only.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game.units = {}
  return game, ns
end

local function rare(id, name, extra)
  local u = { guid = "Creature-0-5250-0-777-" .. id .. "-00001ABC", name = name, level = 20,
              classification = "rare", creatureType = "Beast", family = "Cat" }
  for k, v in pairs(extra or {}) do u[k] = v end
  return u
end

T.describe("rare alerts", function()
  T.it("a living rare shows a toast with sound and a Target button", function()
    local game, ns = session()
    game.units.mouseover = rare(80001, "Spec Rare")
    game:fire("UPDATE_MOUSEOVER_UNIT")
    T.eq(ns.Toast:Count(), 1)
    local f = ns.Toast.visible[1]
    T.eq(f.title:GetText(), "Rare: Spec Rare")
    T.contains(f.text:GetText(), "Level 20")
    T.eq(f.secure:GetAttribute("macrotext"), "/targetexact Spec Rare")
    T.eq(#game.sounds, 1)
    f.secure:Click()
    T.same(game.macrosRun, { "/targetexact Spec Rare" })
  end)

  T.it("dead rares don't alert", function()
    local game, ns = session()
    game.units.target = rare(80001, "Spec Rare", { dead = true })
    game:fire("PLAYER_TARGET_CHANGED")
    T.eq(ns.Toast:Count(), 0)
  end)

  T.it("per-NPC cooldown of 5 minutes", function()
    local game, ns = session()
    game.units.target = rare(80001, "Spec Rare")
    game:fire("PLAYER_TARGET_CHANGED")
    game:advance(61)
    game:fire("PLAYER_TARGET_CHANGED")
    T.eq(#game.sounds, 1, "RareScan re-fired after 60 s but the alert is on cooldown")
    game:advance(300)
    game:fire("PLAYER_TARGET_CHANGED")
    T.eq(#game.sounds, 2)
  end)

  T.it("watch mode only alerts for watched rares", function()
    local game, ns = session()
    ns.Modules:Get("RareAlerts"):Settings().mode = "watch"
    game.units.target = rare(80001, "Spec Rare")
    game:fire("PLAYER_TARGET_CHANGED")
    T.eq(ns.Toast:Count(), 0)
    game:slash("watch Other Rare")
    game.units.target = rare(80002, "Other Rare")
    game:fire("PLAYER_TARGET_CHANGED")
    T.eq(ns.Toast:Count(), 1)
  end)

  T.it("in combat the toast shows, nothing protected is touched, the button works after", function()
    local game, ns = session()
    game:setCombat(true)
    game.units.target = rare(80001, "Spec Rare")
    game:fire("PLAYER_TARGET_CHANGED")
    T.eq(ns.Toast:Count(), 1)
    T.eq(#game.blocked, 0)
    game:setCombat(false)
    T.eq(ns.Toast.visible[1].secure:GetAttribute("macrotext"), "/targetexact Spec Rare")
  end)

  T.it("steps aside when RareScanner is installed", function()
    local game, ns = session({ addons = { "RareScanner" } })
    T.no(ns.Modules:Get("RareAlerts").enabled)
  end)
end)

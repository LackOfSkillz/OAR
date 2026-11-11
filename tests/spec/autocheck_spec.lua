-- AutoCheck: Phase 0/1 data collected without typing.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  game.units = {}
  return game, ns
end

local function mob(id)
  return { guid = "Creature-0-5250-0-777-" .. id .. "-00001ABC", name = "Mob", level = 10, classification = "normal" }
end

T.describe("autocheck", function()
  T.it("runs the API probe by itself 10 s after login, once per build", function()
    local game, ns = session()
    T.eq(ns.db.global.probe, nil)
    game:advance(11)
    T.ok(ns.db.global.probe)
    T.eq(ns.db.global.probe.addonBuild, ns.build)
    local sv = game:logout()
    local g2 = mock.new({ savedVariables = sv })
    local ns2 = g2:loadAddon()
    g2:login()
    local at = ns2.db.global.probe.at
    g2:advance(11)
    T.eq(ns2.db.global.probe.at, at, "same build: not probed again")
  end)

  T.it("waits for combat to end before probing", function()
    local game, ns = session()
    game.combat = true
    game:advance(11)
    T.eq(ns.db.global.probe, nil)
    game.combat = false
    game:advance(6)
    T.ok(ns.db.global.probe)
  end)

  T.it("in combat: samples units, then the combat queue runs when the fight ends", function()
    local game, ns = session()
    game:advance(11)
    game.units.target = mob(70001)
    game:setCombat(true)
    game:fire("PLAYER_TARGET_CHANGED")
    game:advance(1.5)
    local samples = ns.db.global.probeUnits
    local inCombat = 0
    for _, s in ipairs(samples) do if s.inCombat then inCombat = inCombat + 1 end end
    T.eq(inCombat, 2, "one sample 1 s in, one on the target change")
    game:setCombat(false)
    local found = false
    for _, line in ipairs(ns.Log:Tail(20)) do if ns.Log:FormatLine(line):find("combat queue ran after combat 1", 1, true) then found = true end end
    T.ok(found)
    T.eq(#ns.Errors.list, 0)
    T.eq(#game.blocked, 0)
  end)

  T.it("queues the test button swap in combat when the button exists", function()
    local game, ns = session()
    game:slash("selftest button")
    local b = ns.SecureButtons.test
    game:setCombat(true)
    T.eq(b:GetAttribute("macrotext"), "/wave")
    game:setCombat(false)
    T.eq(b:GetAttribute("macrotext"), "/cheer")
    T.eq(#game.blocked, 0)
  end)

  T.it("stops after 3 combats per session", function()
    local game, ns = session()
    for _ = 1, 5 do game:setCombat(true) game:advance(1.5) game:setCombat(false) end
    T.eq(ns.Modules:Get("AutoCheck").combats, 3)
  end)
end)

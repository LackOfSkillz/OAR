-- tests/lib/contract_session.lua
-- One fixed fake-client session for the cross-language contract fixtures
-- (spec 12.4): a made-up character, a fixed clock and a known repair vendor,
-- so the /ride ask snapshot is the same every time. Used by
-- tools/contract_fixtures.lua (writes the snapshot code) and
-- tests/spec/contract_spec.lua (pastes the companion's answer back).
local mock = require("wowmock")

return function()
  local game = mock.new({ name = "Fixturehero", realm = "Testrealm", level = 24, ammo = 1000, now = 1794740000 })
  local ns = game:loadAddon()
  game:login()
  game.durability = { [1] = { 4, 50 } }
  ns.db.global.pois = { r = { kind = "repair", name = "Test Smith", mapID = 1412, x = 0.47, y = 0.38 } }
  ns.db.char.askQuestion = "I have 30 minutes"
  ns.db.char.askMinutes = 30
  local W = ns.WhatNow
  W.SOURCES.contract = function()
    return {
      { key = "gather:Peacebloom", kind = "gather", title = "Gather Peacebloom", benefit = 0.6, confidence = 1,
        label = "observed", target = { mapID = 1412, x = 0.4012345678901234, y = 0.5 } },
      { key = "profession:Alchemy", kind = "profession", title = "Train Alchemy (+4 expected)", benefit = 0.5,
        confidence = 0.85, label = "observed", panel = "professions" },
    }
  end
  table.insert(W.ORDER, "contract")
  ns.Snapshot:Collect(true)
  table.remove(W.ORDER)
  return game, ns
end

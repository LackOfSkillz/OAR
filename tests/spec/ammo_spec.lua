-- Ammo warnings (P2-11).
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game:advance(1)
  return game, ns
end

T.describe("ammo", function()
  T.it("logs the count at login", function()
    local game, ns = session({ ammo = 800 })
    local found = false
    for _, l in ipairs(ns.Log:Tail(30)) do if ns.Log:FormatLine(l):find("ammo at login: 800", 1, true) then found = true end end
    T.ok(found)
    T.eq(ns.Toast:Count(), 0)
  end)

  T.it("warns once under 200 and once more under 50", function()
    local game, ns = session({ ammo = 800 })
    game.ammo = 150
    game:fire("BAG_UPDATE_DELAYED") game:advance(1)
    T.eq(ns.Toast:Count(), 1)
    game.ammo = 120
    game:fire("BAG_UPDATE_DELAYED") game:advance(1)
    T.eq(ns.Toast:Count(), 1, "no repeat")
    game.ammo = 40
    game:fire("BAG_UPDATE_DELAYED") game:advance(1)
    T.eq(ns.Toast:Count(), 2)
    T.contains(ns.Toast.visible[2].title:GetText(), "almost out")
  end)

  T.it("no warning when no ammo is equipped at all (e.g. a gun-less build or no ammo slot)", function()
    local game, ns = session()
    game:fire("BAG_UPDATE_DELAYED") game:advance(1)
    T.eq(ns.Toast:Count(), 0)
  end)
end)

-- Hitches the always-on watch found in game (2026-11-25): a zone change cost
-- Nearby 78 ms and RareMacros 74 ms. These pin the fixes.
local T, mock = ...

local function session(class)
  local game = mock.new({ class = class, level = 10 })
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game:advance(1)
  return game, ns
end

T.describe("zone change hitches", function()
  T.it("RareMacros never builds the whole macro library; other classes skip it", function()
    for _, class in ipairs({ "SHAMAN", "HUNTER" }) do
      local game, ns = session(class)
      local L = ns.MacroLibrary
      local orig, n = L.Entries, 0
      L.Entries = function(...) n = n + 1 return orig(...) end
      ns.RareMacros:Refresh("zone")
      game:fire("ZONE_CHANGED_NEW_AREA")
      L.Entries = orig
      T.eq(n, 0, class .. ": no full library build on a zone change")
      T.eq(#ns.Errors.list, 0)
    end
  end)

  T.it("Nearby scores an item once until gear, level or talents change", function()
    local game, ns = session("WARRIOR")
    local G = ns.GearScore
    local orig, n = G.Compare, 0
    G.Compare = function(self, link) n = n + 1 return { pct = 5, link = link } end
    local N = ns.Nearby
    N:Compare(2504)
    N:Compare(2504)
    T.eq(n, 1, "the second ask is cached")
    game:fire("PLAYER_EQUIPMENT_CHANGED", 16)
    N:Compare(2504)
    T.eq(n, 2, "new gear: scored again")
    game:advance(N.CACHE_S + 1)
    N:Compare(2504)
    T.eq(n, 3, "and at most a minute old")
    G.Compare = function() n = n + 1 return nil end
    N:ForgetScores()
    N:Compare(7)
    N:Compare(7)
    T.eq(n, 5, "no answer (details not loaded) is not cached")
    G.Compare = orig
  end)
end)

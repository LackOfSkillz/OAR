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

T.describe("minimap while moving", function()
  T.it("map pins don't recount every saved place on each call, and still see new places", function()
    local game, ns = session("WARRIOR")
    local P = ns.MapPins
    local pois = ns.db.global.pois
    pois["npc-1-vendor"] = { id = "npc-1-vendor", kind = "vendor", mapID = 1412, x = 0.4, y = 0.5, name = "Smith", verified = false }
    P:Invalidate()
    local first = P:PinsFor(1412)
    -- a place added without an event: the cached list is kept for a while...
    pois["npc-2-bank"] = { id = "npc-2-bank", kind = "bank", mapID = 1412, x = 0.2, y = 0.2, name = "Banker", verified = false }
    T.eq(P:PinsFor(1412), first, "no recount on every call")
    -- ...and picked up within COUNT_S
    game:advance(P.COUNT_S + 1)
    local found
    for _, p in ipairs(P:PinsFor(1412)) do if p.name == "Banker" then found = p end end
    T.ok(found, "the new place shows within " .. P.COUNT_S .. " s")
    -- with the event it shows at once
    pois["npc-3-inn"] = { id = "npc-3-inn", kind = "innkeeper", mapID = 1412, x = 0.3, y = 0.3, name = "Inn", verified = false }
    ns.Events:Fire("OTR_POI_ADDED")
    local inn
    for _, p in ipairs(P:PinsFor(1412)) do if p.name == "Inn" then inn = p end end
    T.ok(inn, "an added place shows at once")
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("moving makes little garbage", function()
  T.it("a minimap update reuses its working tables", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    ns.Modules:SetEnabled("AutoCheck", false)
    for i = 1, 20 do
      ns.db.global.pois["npc-" .. i .. "-vendor"] = { id = "npc-" .. i .. "-vendor", kind = "vendor", mapID = 1412,
        x = 0.50 + i * 0.001, y = 0.37, name = "Smith " .. i, verified = false }
    end
    ns.MapPins:Invalidate()
    local M = ns.Modules:Get("MinimapPins")
    M:Update() M:Update() -- dots and pools made once
    collectgarbage("collect")
    collectgarbage("stop")
    local k0 = collectgarbage("count")
    for _ = 1, 50 do M:Update() end
    local perUpdate = (collectgarbage("count") - k0) / 50
    collectgarbage("restart")
    T.ok(#M.used > 5, "dots are shown")
    -- 12 KB an update before; part of what is left is the mock frames recording points
    T.ok(perUpdate < 5, string.format("%.2f KB made per update", perUpdate))
  end)

  T.it("the route's pins are kept until the route changes", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    local P = ns.Path
    P.dots = { { walked = true, wx = 1, wy = 1 } }
    P.target = { title = "Tower" }
    local a = P:Pins(100)
    T.eq(P:Pins(100), a, "same dots: the same list")
    P.dots = { { walked = true, wx = 2, wy = 2 } }
    T.ok(P:Pins(100) ~= a, "a new search: rebuilt")
  end)
end)

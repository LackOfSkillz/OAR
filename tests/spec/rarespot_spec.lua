-- Rare spots Gary reported (Data/Rares.lua poi kind rare_spot), Gary 2026-11-20.
local T, mock = ...

T.describe("reported rare spots", function()
  T.it("a reported spot shows as a rare pin, and a real rare seen there replaces it", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    local function spot()
      ns.MapPins:Invalidate()
      for _, p in ipairs(ns.MapPins:BuildPins(2521)) do if p.id == "rarespot-2521-akir-camp" then return p end end
    end
    local p = spot()
    T.ok(p, "reported spot drawn")
    T.eq(p.kind, "rare")
    local found
    for _, q in ipairs(ns.MapPins:BuildPins(2521)) do if q.npcID == 259398 then found = q end end
    T.ok(found, "Galemender Delanea from the pack")
    ns.db.global.sightings = ns.db.global.sightings or {}
    ns.db.global.sightings[999001] = { { mapID = 2521, x = 0.61, y = 0.52, state = "alive", t = game.env.time() } }
    T.eq(spot(), nil, "a real rare seen nearby takes its place")
    T.eq(#ns.Errors.list, 0)
  end)
end)

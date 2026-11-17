-- Rares from the creature pack show on the world map. Test data.
local T, mock = ...

T.describe("rare pins", function()
  T.it("rares and rare elites from the creature pack get map pins; ordinary creatures don't", function()
    local game = mock.new({ mapID = 1412 })
    game.base.Outrider_DataMobs = { source = "test", maps = { [1412] = {
      { 701, "Slydris", 6, 6, 2, { 0.49, 0.52, 0.50, 0.48, 0.52, 0.52 } },
      { 702, "Plain Wolf", 5, 6, 0, { 0.40, 0.40 } },
    } } }
    rawset(game.env, "Outrider_DataMobs", game.base.Outrider_DataMobs)
    local ns = game:loadAddon()
    game:login()
    local found, wolf, spots = nil, nil, 0
    for _, p in ipairs(ns.MapPins:BuildPins(1412)) do
      if p.npcID == 701 then found = found or p spots = spots + 1 end
      if p.npcID == 702 then wolf = p end
    end
    T.ok(found, "Slydris pinned")
    T.contains(found.name, "rare elite, level 6")
    T.eq(spots, 3, "a pin at each of its 3 spawn spots")
    T.eq(wolf, nil)
  end)

  T.it("a rare you've already seen still shows every spawn spot from the pack", function()
    local game = mock.new({ mapID = 1412 })
    game.base.Outrider_DataMobs = { source = "test", maps = { [1412] = {
      { 703, "Den Test", 12, 13, 4, { 0.52, 0.41, 0.58, 0.29, 0.62, 0.38, 0.59, 0.44 } },
    } } }
    rawset(game.env, "Outrider_DataMobs", game.base.Outrider_DataMobs)
    local ns = game:loadAddon()
    game:login()
    ns.db.global.sightings = { [703] = { { mapID = 1412, x = 0.599, y = 0.344, t = 1 } } }
    local spots = 0
    for _, p in ipairs(ns.MapPins:BuildPins(1412)) do
      if p.npcID == 703 then spots = spots + 1 end
    end
    T.eq(spots, 5, "the sighting plus all 4 spawn spots")
  end)
end)

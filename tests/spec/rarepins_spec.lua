-- Rares from the creature pack show on the world map. Test data.
local T, mock = ...

T.describe("rare pins", function()
  T.it("rares and rare elites from the creature pack get map pins; ordinary creatures don't", function()
    local game = mock.new({ mapID = 1412 })
    game.base.Outrider_DataMobs = { source = "test", maps = { [1412] = {
      { 701, "Slydris", 6, 6, 2, { 0.49, 0.52 } },
      { 702, "Plain Wolf", 5, 6, 0, { 0.40, 0.40 } },
    } } }
    rawset(game.env, "Outrider_DataMobs", game.base.Outrider_DataMobs)
    local ns = game:loadAddon()
    game:login()
    local found, wolf
    for _, p in ipairs(ns.MapPins:BuildPins(1412)) do
      if p.npcID == 701 then found = p end
      if p.npcID == 702 then wolf = p end
    end
    T.ok(found, "Slydris pinned")
    T.contains(found.name, "rare elite, level 6")
    T.eq(wolf, nil)
  end)
end)

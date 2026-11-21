-- GearQuest bridge (P6-07). A tiny fake stands in for GearQuest's global table.
local T, mock = ...

local function session(withGQ, broken)
  local game = mock.new({ mapID = 1412, x = 0.5, y = 0.5 })
  game.items = { [400] = { name = "Old Cloak", equipLoc = "INVTYPE_CLOAK" }, [601] = { name = "GQ Cloak", equipLoc = "INVTYPE_CLOAK" } }
  game.itemStats = { [400] = { ITEM_MOD_AGILITY_SHORT = 2 }, [601] = { ITEM_MOD_AGILITY_SHORT = 7 } }
  game.worn = { [15] = 400 }
  if withGQ then
    local GQ = { Data = {}, Compare = {}, Map = {} }
    function GQ.Data:GetSlotsForClass() return { "Back" } end
    function GQ.Data:GetCandidatesForSlot(slot)
      if broken then error("changed") end
      return { { itemId = 601, slot = slot } }
    end
    function GQ.Compare:RankEntries(list) return { { entry = list[1] } } end
    function GQ.Data:GetItemFact() return { name = "GQ Cloak", sourceType = "vendor", npc = "Varia Hardhide", zone = "Thunder Bluff" } end
    function GQ.Data:NearestCoordinateSpot() return { map = "Thunder Bluff", x = 40.5, y = 60.0 } end
    function GQ.Map:ZoneMap() return 1456 end
    game.env.GearQuest = GQ
  end
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("gearquest bridge", function()
  T.it("GearQuest's pick shows in the Gear list with its source and a waypoint spot", function()
    local _, ns = session(true)
    local list = ns.Nearby:Candidates()
    T.eq(list[1].kind, "gearquest")
    T.eq(list[1].where.mapID, 1456)
    T.eq(list[1].where.x, 0.405)
    T.contains(ns.Nearby.Describe(list[1]), "Sold by Varia Hardhide, Thunder Bluff")
    T.ok(not ns.Nearby.Describe(list[1]):find("GearQuest"), "no other addon named on screen")
  end)

  T.it("without GearQuest, or if it changes, nothing breaks", function()
    local _, ns = session(false)
    T.eq(#ns.GearQuestBridge:Picks(), 0)
    local _, ns2 = session(true, true)
    T.eq(#ns2.GearQuestBridge:Picks(), 0)
    T.contains(ns2.GearQuestBridge:Activity(), "paused this session")
    T.contains(ns.GearQuestBridge:Activity(), "works on its own")
    T.eq(#ns2.Errors.list, 0)
  end)
end)

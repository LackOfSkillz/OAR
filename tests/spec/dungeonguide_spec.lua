-- Dungeon guide: ready-for, upgrades per dungeon for this class, next tier.
local T, mock = ...

local function session()
  local game = mock.new({ level = 18 })
  game.items = {
    [301] = { name = "Worn Vest", equipLoc = "INVTYPE_CHEST", class = 4, subclass = 2 },
    [5191] = { name = "Cruel Barb", equipLoc = "INVTYPE_WEAPON", class = 2, subclass = 7, reqLevel = 19 },
    [5193] = { name = "Cape of the Brotherhood", equipLoc = "INVTYPE_CLOAK", class = 4, subclass = 1, reqLevel = 17 },
    [5194] = { name = "Robe of Mages", equipLoc = "INVTYPE_ROBE", class = 4, subclass = 1, reqLevel = 17 },
    [6900] = { name = "Deep Leather Vest", equipLoc = "INVTYPE_CHEST", class = 4, subclass = 2, reqLevel = 25 },
  }
  game.itemStats = { [301] = { ITEM_MOD_AGILITY_SHORT = 2 }, [5191] = { ITEM_MOD_AGILITY_SHORT = 5 },
    [5193] = { ITEM_MOD_AGILITY_SHORT = 3 }, [5194] = { ITEM_MOD_AGILITY_SHORT = 30 }, [6900] = { ITEM_MOD_AGILITY_SHORT = 9 } }
  game.worn = { [5] = 301 }
  game.knownSpells = { [201] = true, [264] = true }
  game.base.Outrider_DataDungeons = { source = "test", dungeons = {
    [1581] = { name = "The Deadmines", map = 1436, x = 0.425, y = 0.717, bosses = {
      { 639, "Edwin VanCleef", 21, 1, { 5191, 5193, 5194 } } },
      items = { [5191] = { "Cruel Barb", 19, 24, 2, 7 }, [5193] = { "Cape of the Brotherhood", 17, 22, 4, 1 },
        [5194] = { "Robe of Mages", 17, 22, 4, 1 } } },
    [719] = { name = "Blackfathom Deeps", map = 1440, x = 0.145, y = 0.142, bosses = {
      { 4887, "Ghamoo-ra", 25, 1, { 6900 } } }, items = { [6900] = { "Deep Leather Vest", 25, 30, 4, 2 } } },
  } }
  rawset(game.env, "Outrider_DataDungeons", game.base.Outrider_DataDungeons)
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("dungeon guide", function()
  T.it("ranks ready dungeons with this class's upgrades and finds the next tier", function()
    local game, ns = session()
    local D = ns.DungeonGuide
    local rank = D:Rank()
    T.eq(rank[1].name, "The Deadmines")
    T.eq(rank[1].status, "ready")
    local names = {}
    for _, u in ipairs(rank[1].ups) do names[u.name] = u end
    T.ok(names["Cape of the Brotherhood"], "cloaks are for everyone")
    T.eq(names["Robe of Mages"], nil, "no cloth robe for a hunter")
    T.ok(names["Cruel Barb"] and names["Cruel Barb"].later, "level 19 sword: an upgrade a level from now")
    local nxt = D:NextTier(rank)
    T.eq(nxt.name, "Blackfathom Deeps")
    T.eq(nxt.laterCount, 1)
    T.contains(D.UpgradeLine(nxt.ups, 3, true), "Deep Leather Vest")
    D:Go(rank[1])
    T.contains(ns.Waypoints.current.title, "The Deadmines")
    game:slash("")
    ns.Hub.frame.tabBar:Select("dungeons")
    T.eq(#ns.Errors.list, 0)
  end)
end)

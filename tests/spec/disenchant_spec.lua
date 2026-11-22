-- Disenchant value and whole-stack price on item tooltips (Gary, 2026-11-22:
-- match Auctionator).
local T, mock = ...

T.describe("tooltip extras for selling", function()
  T.it("green armor and weapons get a disenchant estimate from material prices", function()
    local game = mock.new({ level = 20 })
    game.items = {
      [7001] = { name = "Bloody Bracers", quality = 2, ilvl = 18, class = 4, equipLoc = "INVTYPE_WRIST" },
      [7005] = { name = "Gnarled Staff", quality = 2, ilvl = 18, class = 2, equipLoc = "INVTYPE_2HWEAPON" },
      [7006] = { name = "Plain Shirt", quality = 1, ilvl = 18, class = 4 },
      [2589] = { name = "Linen Cloth", quality = 1, ilvl = 5 },
    }
    local ns = game:loadAddon()
    game:login()
    local D = ns.Disenchant
    local armor = D.Outcomes(7001)
    T.ok(armor, "green armor can be disenchanted")
    T.eq(armor[1][1], 10940, "Strange Dust")
    T.eq(armor[1][2], 0.75)
    local weapon = D.Outcomes(7005)
    T.eq(weapon[2][2], 0.75, "weapons give essence more often")
    T.eq(D.Outcomes(7006), nil, "white items can't")
    T.eq(D.Outcomes(2589), nil, "cloth isn't gear")
    T.eq(D.Value(7001), nil, "no material prices: no line")
    ns.Prices:Record(10940, 100) -- Strange Dust 1s
    ns.Prices:Record(10939, 1000) -- Greater Magic Essence 10s
    ns.Prices:Record(10978, 400) -- Small Glimmering Shard 4s
    local v, all = D.Value(7001)
    -- 0.75*2.5*100 + 0.20*1.5*1000 + 0.05*1*400 = 187.5 + 300 + 20
    T.eq(v, 508)
    T.ok(all)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a bag stack's tooltip adds the price of the whole stack", function()
    local game = mock.new({ level = 20 })
    game.items = { [2589] = { name = "Linen Cloth", quality = 1 } }
    game.bags = { [0] = { [3] = 2589 } }
    game.counts = { [0] = { [3] = 20 } }
    local ns = game:loadAddon()
    game:login()
    local owner = { GetBagID = function() return 0 end, GetID = function() return 3 end }
    T.eq(ns.Prices.StackCount({ GetOwner = function() return owner end }), 20)
    T.eq(ns.Prices.StackCount({ GetOwner = function() return {} end }), nil, "not a bag slot")
  end)
end)

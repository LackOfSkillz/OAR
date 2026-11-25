-- OI04-10: Foresight triggers.
local T, mock = ...

local function session()
  local game = mock.new({ level = 36 })
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.Foresight
end
local function ids(list) local t = {} for _, x in ipairs(list) do t[x.id] = x end return t end

T.describe("Foresight triggers (OI04-10)", function()
  T.it("a trainer visit on your route is raised with its saving; off route without one", function()
    local _, _, F = session()
    local on = ids(F.Evaluate({ level = 11, etaMinutes = { [12] = 20 }, trainer = { level = 12, mapID = 5, trip = 300 }, routeMaps = { [5] = true } }))
    T.ok(on["trainer:12"].onRoute) T.eq(on["trainer:12"].saving, 300)
    local off = ids(F.Evaluate({ level = 11, etaMinutes = { [12] = 20 }, trainer = { level = 12, mapID = 9, trip = 300 }, routeMaps = { [5] = true } }))
    T.eq(off["trainer:12"].onRoute, nil, "not on your way: no saving claimed")
    T.eq(off["trainer:12"].saving, nil)
  end)

  T.it("false positives: too far ahead or unknown timing is not an alert", function()
    local _, _, F = session()
    local far = F.Evaluate({ level = 11, etaMinutes = { [12] = 300 }, trainer = { level = 12 } })
    T.eq(#far, 0, "five hours away is not 'coming up'")
    local unknown, withheld = F.Evaluate({ level = 11, etaMinutes = {}, trainer = { level = 12 }, questsAt = { [12] = 3 } })
    T.eq(#unknown, 0)
    T.eq(#withheld, 2, "both withheld with a reason")
    T.ok(withheld[1].why:find("unknown"))
  end)

  T.it("riding: short or enough, counting the reserve; unknown cost or gold is withheld", function()
    local _, _, F = session()
    local short = F.Evaluate({ level = 37, riding = { level = 40, cost = 1000000 }, copper = 900000, reserve = 200000 })
    T.ok(short[1].title:find("short"))
    local enough = F.Evaluate({ level = 37, riding = { level = 40, cost = 1000000 }, copper = 1500000 })
    T.ok(enough[1].title:find("enough"))
    local _, held = F.Evaluate({ level = 37, riding = { level = 40 }, copper = 1500000 })
    T.eq(held[1].id, "riding")
    T.eq(#F.Evaluate({ level = 20, riding = { level = 40, cost = 1 }, copper = 0 }), 0, "too early for riding")
  end)

  T.it("quests opening soon, materials, dungeons and alts' upgrades; ranked by importance", function()
    local _, _, F = session()
    local list = F.Evaluate({ level = 20, etaMinutes = { [21] = 30 }, questsAt = { [21] = 4 }, shopping = 3,
      dungeonsSoon = { { name = "Shadowfang Keep", levels = 2 } }, altUpgrades = { { holder = "Lumen-Forever", name = "Ring" } } })
    local t = ids(list)
    T.ok(t["quests:21"] and t["materials"] and t["dungeon:Shadowfang Keep"] and t["alt:Lumen-Forever:Ring"])
    for i = 2, #list do T.ok(list[i].importance <= list[i - 1].importance) end
  end)

  T.it("the live facts read cleanly; riding cost comes from the cited levelling facts", function()
    local game = mock.new({ level = 36, guides = true }) -- the cited guide facts loaded
    local ns = game:loadAddon()
    game:login()
    local F = ns.Foresight
    local f = F.Facts()
    T.eq(f.riding.level, 40) T.eq(f.riding.cost, 1000000)
    local list = F.Evaluate(f)
    T.eq(type(list), "table")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("never accepts a quest or acts", function()
    local fh = assert(io.open("addon/Outrider/Intelligence/Foresight.lua"))
    local code = fh:read("*a"):gsub("%-%-[^\n]*", "")
    fh:close()
    for _, bad in ipairs({ "AcceptQuest", "CompleteQuest", "BuyMerchantItem", "CastSpell", "PlaceAuctionBid" }) do T.ok(not code:find(bad), bad) end
  end)
end)

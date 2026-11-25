-- OI04-14: dungeon decision improvements.
local T, mock = ...

local function session()
  local game = mock.new({ level = 20 })
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.DungeonDecision
end

T.describe("dungeon decision (OI04-14)", function()
  T.it("ranks by quests, possible gear and level fit; gear is never called guaranteed", function()
    local _, _, D = session()
    local list = D.Rank({
      { name = "Wailing Caverns", lo = 17, hi = 24, todo = 4, pickups = 4, gearCount = 2, gearValue = 30 },
      { name = "Deadmines", lo = 17, hi = 26, todo = 1, pickups = 1, gearCount = 0, gearValue = 0 },
    }, 20, false)
    T.eq(list[1].name, "Wailing Caverns")
    local text = table.concat(list[1].lines, " ")
    T.ok(text:find("possible, not guaranteed") and text:find("pick up 4 before you go"), text)
    T.ok(text:find("whether you'll find one is unknown"), "no group assumption")
    T.ok(text:find("reputation: no data"))
  end)

  T.it("a solo session puts dungeons last, with the reason", function()
    local _, _, D = session()
    local list = D.Rank({ { name = "A", lo = 18, hi = 24, todo = 5, gearValue = 50 } }, 20, true)
    T.ok(list[1].solo) T.ok(table.concat(list[1].lines, " "):find("solo session"))
  end)

  T.it("the Dungeons page gains the section and keeps its existing rows", function()
    local _, ns, D = session()
    ns.Hub:Build():Show()
    ns.Hub:ShowTab("dungeons")
    T.eq(#ns.Errors.list, 0)
    T.eq(type(D.Cards()), "table")
    ns.Hub:ShowTab("dungeonquests")
    T.eq(#ns.Errors.list, 0, "the dungeon quests page still builds")
  end)
end)

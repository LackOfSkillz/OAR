-- Info bar (gap analysis 2026-11-17).
local T, mock = ...

local function start(opts)
  local game = mock.new(opts or { class = "HUNTER", level = 20 })
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.InfoBar
end

T.describe("info bar", function()
  T.it("shows gold, bags, durability, ammo, XP with rested, clock and latency", function()
    local game, ns, M = start()
    game.money = 123456
    game.durability = { [1] = { 10, 100 }, [5] = { 100, 100 } }
    game.xp, game.xpMax, game.rested = 500, 1000, 250
    game.latency = 87
    T.contains(M:Text("gold"), "12g")
    T.contains(M:Text("dura"), "%")
    T.contains(M:Text("xp"), "XP 50%")
    T.contains(M:Text("xp"), "+25% rested")
    T.contains(M:Text("net"), "87 ms")
    T.ok(M:Text("clock"))
    T.contains(M:Text("layer"), "Layer —")
    T.ok(M.frame and M.frame:IsShown())
    M:Update()
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("durability warns on the worst item", function()
    local game, ns, M = start()
    game.durability = { [1] = { 5, 100 }, [5] = { 100, 100 }, [7] = { 100, 100 } }
    local all, low = M.Durability()
    T.ok(all > 60)
    T.eq(math.floor(low), 5)
    T.contains(M:Text("dura"), "|cffff5050")
  end)

  T.it("parts switch off; the whole bar switches off; no ammo for non-hunters", function()
    local game, ns, M = start({ class = "MAGE", level = 20 })
    T.eq(M:Text("ammo"), nil)
    M:Settings().gold = false
    T.eq(M:Text("gold"), nil)
    game:slash("bar off")
    T.ok(not M.frame:IsShown())
    game:slash("bar on")
    T.ok(M.frame:IsShown())
  end)

  T.it("clicks open pages and bags; tooltips build", function()
    local game, ns, M = start()
    M:Click("bags")
    T.eq(game.bagsToggled, 1)
    M:Click("gold")
    T.eq(ns.Hub.current, "money")
    local lines = {}
    local tt = { AddLine = function(_, t) lines[#lines + 1] = t end, AddDoubleLine = function(_, a, b) lines[#lines + 1] = a .. b end }
    for _, id in ipairs(M.ORDER) do M:Tip(id, tt) end
    T.ok(#lines > 8)
    T.eq(#ns.Errors.list, 0)
  end)
end)

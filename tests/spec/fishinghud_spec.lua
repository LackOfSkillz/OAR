-- Fishing HUD: 4 lines while the pole is on, lure on the fish key, too-hard
-- warning, stop-fishing summary, rare catch sound, pool pins.
local T, mock = ...

local function session(opts)
  opts = opts or {}
  opts.mapID = opts.mapID or 1412
  opts.now = opts.now or 1794700000
  local game = mock.new(opts)
  game.items = game.items or {}
  game.items[6303] = { name = "Raw Slitherskin Mackerel", quality = 1, sell = 1 }
  game.items[6289] = { name = "Raw Longjaw Mud Snapper", quality = 1, sell = 2 }
  game.items[6358] = { name = "Oily Blackmouth", quality = 1, sell = 4 }
  game.items[6529] = { name = "Shiny Bauble", quality = 1 }
  game.items[5523] = { name = "Small Barnacled Clam", quality = 2 }
  local ns = game:loadAddon()
  game:login()
  ns.Fishing.PoleEquipped = function() return game.pole == true end
  return game, ns
end

local function lines(ns) return table.concat(ns.FishingHUD:Lines(), "\n") end

T.describe("fishing hud", function()
  T.it("shows only with the pole, with skill, lure, what bites here and the session", function()
    local game, ns = session()
    local H = ns.FishingHUD
    H:Update()
    T.ok(not H.shown, "no pole, no HUD")
    ns.db.global.fishing[1412] = { [6303] = 7, [6289] = 3 }
    game.pole = true
    H:Update()
    T.ok(H.shown, "pole on, HUD on")
    T.contains(lines(ns), "No lure")
    T.contains(lines(ns), "Here: Slitherskin Mackerel 70%")
    game.lureMs = 372000
    T.contains(lines(ns), "Lure 6:12")
    ns.Events:Fire("OTR_LOOT", "fish", { { id = 6303, count = 1, name = "Raw Slitherskin Mackerel" } })
    T.contains(lines(ns), "1 fish")
    game.pole = false
    H:Update()
    T.ok(not H.shown)
    T.contains(game:chatText(), "Fishing: 1 catches")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a quest objective for a fish you catch becomes the goal", function()
    local game, ns = session()
    ns.db.global.fishing[1412] = { [6358] = 2 }
    game.questLog = { { title = "Oily Business", questID = 900, isHeader = false } }
    game.questObjectives = { [900] = { { text = "2/6 Oily Blackmouth", type = "item", numFulfilled = 2, numRequired = 6, finished = false } } }
    game.pole = true
    ns.FishingHUD:Update()
    T.contains(lines(ns), "Goal: Oily Blackmouth 2/6 (Oily Business)")
  end)

  T.it("too many fish getting away says the water is too hard, once", function()
    local game, ns = session()
    local H = ns.FishingHUD
    game.pole = true
    H:Update()
    for _ = 1, 10 do H.session.casts[1412] = (H.session.casts[1412] or 0) + 1 end
    for _ = 1, 3 do game:fire("UI_ERROR_MESSAGE", 0, "Your fish got away!") end
    T.contains(lines(ns), "3 of 10 got away")
    local _, n = game:chatText():gsub("too low for this water", "")
    T.eq(n, 1)
  end)

  T.it("a green catch plays the rare sound; a pool tooltip pins the pool", function()
    local game, ns = session()
    game.pole = true
    ns.FishingHUD:Update()
    ns.Events:Fire("OTR_LOOT", "fish", { { id = 5523, count = 1, name = "Small Barnacled Clam" } })
    local log = ""
    for _, l in ipairs(ns.Log:Tail(30)) do log = log .. ns.Log:FormatLine(l) .. "\n" end
    T.contains(log, "rare catch Small Barnacled Clam")
    ns.FishingHUD:OnPoolTooltip("Oily Blackmouth School")
    local pool
    for _, n in ipairs(ns.LootLog:NodesFor(1412)) do if n.kind == "pool" then pool = n end end
    T.ok(pool and pool.name == "Oily Blackmouth School", "pool pinned")
    ns.FishingHUD:OnPoolTooltip("Copper Vein")
    T.eq(#ns.LootLog:NodesFor(1412), 1, "not a pool")
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("fish key lure", function()
  T.it("puts a lure on when none is active, casts once one is on", function()
    local game, ns = session()
    game.bags = { [0] = { [1] = 6529 } }
    local F = ns.Fishing
    T.eq((F:Body()), "/use Shiny Bauble\n/use 16")
    game.lureMs = 600000
    T.eq(F:Body(), "/cast Fishing")
    game.lureMs = nil
    F:CheckLure("Shiny Bauble")
    T.eq(F:Body(), "/cast Fishing", "a lure that didn't take is skipped")
    T.contains(game:chatText(), "didn't go on")
  end)
end)

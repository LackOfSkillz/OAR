-- FarmLab: dungeon runs and farm timers with coin, received loot at vendor and
-- auction prices, costs, gold per hour per farm, rare drops and export.
local T, mock = ...

local function start(now)
  local game = mock.new({ class = "HUNTER", level = 20, now = now or 1795000000 })
  local ns = game:loadAddon()
  game:login()
  game.items = game.items or {}
  game.items[2589] = { name = "Linen Cloth", quality = 1, sell = 13 }
  game.items[2592] = { name = "Wool Cloth", quality = 1, sell = 33 }
  game.items[5195] = { name = "Gold-flecked Gloves", quality = 2, sell = 800 }
  ns.Prices.Get = function(_, id)
    local it = game.items[id]
    local ah = ({ [2589] = 50, [2592] = 200 })[id]
    return ah, ah and "TSM" or nil, it and it.sell
  end
  return game, ns, ns.FarmLab
end

local function loot(game, id, n)
  local link = "|cffffffff|Hitem:" .. id .. "::::::::20:::::|h[x]|h|r"
  game:fire("CHAT_MSG_LOOT", n and n > 1 and ("You receive loot: " .. link .. "x" .. n .. ".") or ("You receive loot: " .. link .. "."))
end

local function dungeonRun(game, name, map, mins, fn)
  game.instance = { name = name, map = map }
  game:fire("PLAYER_ENTERING_WORLD", false, false)
  if fn then fn() end
  game.now = game.now + mins * 60
  game.instance = nil
  game:fire("PLAYER_ENTERING_WORLD", false, false)
end

T.describe("farmlab", function()
  T.it("reads loot and coin lines", function()
    local _, _, M = start()
    T.eq(select(1, M.ParseLoot("You receive loot: |Hitem:2589:|h[Linen Cloth]|h.")), 2589)
    T.eq(select(2, M.ParseLoot("You receive loot: |Hitem:2589:|h[Linen Cloth]|hx5.")), 5)
    T.eq(M.ParseLoot("Bob receives loot: |Hitem:2589:|h[Linen Cloth]|h."), nil)
    T.eq(M.ParseCoin("You loot 1 Gold, 2 Silver, 3 Copper"), 10203)
    T.eq(M.ParseCoin("Your share of the loot is 45 Copper."), 45)
  end)

  T.it("a dungeon run books coin, received items with prices, and costs", function()
    local game, ns, M = start()
    game.money = 10000
    dungeonRun(game, "The Deadmines", 36, 30, function()
      T.ok(M:Active(), "the dungeon started a run by itself")
      game:fire("CHAT_MSG_MONEY", "You loot 2 Silver, 50 Copper")
      loot(game, 2589, 10)
      loot(game, 2592, 2)
      loot(game, 5195)
      -- someone else's loot doesn't count
      game:fire("CHAT_MSG_LOOT", "Bob receives loot: |Hitem:2589:|h[Linen Cloth]|hx20.")
      game:fire("MERCHANT_SHOW")
      game.money = game.money - 300
      game:fire("PLAYER_MONEY")
      game:fire("MERCHANT_CLOSED")
    end)
    T.ok(M:Active() and M:Active().leftAt, "waiting in case you go back in")
    game.now = game.now + M.SAME_RUN + 5
    M:Expire()
    local r = M.store.runs[1]
    T.eq(r.name, "The Deadmines")
    local v = M.Value(r)
    T.eq(v.coin, 250)
    T.eq(r.items[2589].n, 10)
    T.eq(v.vendor, 10 * 13 + 2 * 33 + 800)
    T.eq(v.ah, 10 * 50 + 2 * 200 + 800) -- the gloves have no auction price: vendor
    T.eq(v.spent, 300)
    T.eq(v.metric.ah, 250 + math.floor(50 * 0.95) * 10 + math.floor(200 * 0.95) * 2 + 800 - 300)
    T.eq(math.floor(v.secs / 60), 30)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("going back into the same dungeon continues the run without counting the time outside", function()
    local game, _, M = start()
    dungeonRun(game, "Wailing Caverns", 43, 20, function() loot(game, 2589, 3) end)
    game.now = game.now + 300
    dungeonRun(game, "Wailing Caverns", 43, 10, function() loot(game, 2589, 2) end)
    T.eq(#M.store.runs, 0)
    M:Finish("test")
    local r = M.store.runs[1]
    T.eq(r.items[2589].n, 5)
    T.eq(math.floor(M.Value(r).secs / 60), 30)
  end)

  T.it("a manual farm timer, and a peek into a dungeon isn't kept", function()
    local game, _, M = start()
    dungeonRun(game, "Ragefire Chasm", 389, 0.5)
    M:Expire(game.now + M.SAME_RUN + 1)
    T.eq(#M.store.runs, 0, "a 30 second peek with no loot")
    game.zone = "Mulgore"
    M:StartManual("Wolves")
    loot(game, 2589, 4)
    game.now = game.now + 1800
    M:Stop()
    T.eq(M.store.runs[1].name, "Wolves")
    T.eq(M.store.runs[1].kind, "manual")
    T.eq(M.PerHour(M.Value(M.store.runs[1]).vendor, 1800), 4 * 13 * 2)
  end)

  T.it("ranks farms by the middle run, shows spread, rare drops and today's prices", function()
    local game, ns, M = start()
    for i = 1, 3 do
      dungeonRun(game, "Shadowfang Keep", 33, 60, function() loot(game, 2592, 10) if i == 1 then loot(game, 5195) end end)
      M:Finish("test")
      game.now = game.now + 4000
    end
    for _ = 1, 3 do
      dungeonRun(game, "The Deadmines", 36, 60, function() loot(game, 2589, 10) end)
      M:Finish("test")
      game.now = game.now + 4000
    end
    local places = M:Places("ah", "char", false)
    T.eq(places[1].name, "Shadowfang Keep")
    T.eq(places[1].runs, 3)
    T.eq(places[2].steady, "steady")
    local drops = M:Drops("char")
    T.eq(drops[1].id, 5195)
    T.eq(drops[1].runsWith, 1)
    T.eq(drops[1].of, 3)
    -- linen gets expensive: today's prices put the Deadmines first
    ns.Prices.Get = function(_, id)
      local it = game.items[id]
      local ah = ({ [2589] = 5000, [2592] = 200 })[id]
      return ah, "TSM", it and it.sell
    end
    T.eq(M:Places("ah", "char", true)[1].name, "The Deadmines")
    T.eq(M:Places("ah", "char", false)[1].name, "Shadowfang Keep", "prices when looted are kept")
    T.eq(M:Characters("ah")[1].runs, 6)
  end)

  T.it("exports CSV and JSON", function()
    local game, _, M = start()
    M:StartManual("Linen farm, Barrens")
    loot(game, 2589, 2)
    game.now = game.now + 600
    M:Stop()
    local csv = M:ExportCSV("all")
    T.ok(csv:find('"Linen farm, Barrens"', 1, true), "comma in a name is quoted")
    T.ok(csv:find("1,2589,Linen Cloth,1,2,13,50,TSM", 1, true), "item row")
    local js = M:ExportJSON("all")
    T.ok(js:find('"place":"Linen farm, Barrens"', 1, true))
    T.ok(js:find('"count":2', 1, true))
  end)

  T.it("a farm timer survives a reload; an old one closes at its last activity", function()
    local game, ns, M = start()
    M:StartManual("Wolves")
    loot(game, 2589, 1)
    local last = M:Active().last
    game:fire("PLAYER_LOGOUT")
    game.now = game.now + 60
    game:fire("PLAYER_ENTERING_WORLD", false, true)
    T.ok(M:Active(), "kept after a reload")
    game.now = game.now + M.RESUME + 100
    game:fire("PLAYER_ENTERING_WORLD", true, false)
    T.eq(M:Active(), nil)
    T.ok(M.store.runs[1].stop >= last and M.store.runs[1].stop < game.now - M.RESUME)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("counts items taken from the loot window when no chat line comes, and never twice", function()
    local game, _, M = start()
    M:StartManual("Wolves")
    local function window(items)
      game.loot = items
      game:fire("LOOT_OPENED")
      for i = 1, #items do game:fire("LOOT_SLOT_CLEARED", i) end
      game:fire("LOOT_CLOSED")
    end
    -- only the loot window (the chat line didn't parse on this client)
    window({ { id = 2589, name = "Linen Cloth", count = 2 } })
    T.eq(M:Active().items[2589].n, 2)
    -- chat line and loot window for the same drop: counted once
    window({ { id = 2589, name = "Linen Cloth", count = 3 } })
    loot(game, 2589, 3)
    T.eq(M:Active().items[2589].n, 5)
    -- the chat line first, then the window: still once
    loot(game, 2592, 1)
    window({ { id = 2592, name = "Wool Cloth", count = 1 } })
    T.eq(M:Active().items[2592].n, 1)
    -- a second, separate drop later is a new drop
    game.clock = (game.clock or 0) + 10
    window({ { id = 2592, name = "Wool Cloth", count = 1 } })
    T.eq(M:Active().items[2592].n, 2)
  end)
end)

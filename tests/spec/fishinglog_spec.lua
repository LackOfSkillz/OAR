-- Fishing session in full, spots, records, wanted list, lures (Gary,
-- 2026-11-23: match OneCast or better).
local T, mock = ...

local function start(opts)
  opts = opts or {}
  opts.mapID = opts.mapID or 1446
  opts.now = opts.now or 1794700000
  opts.spells = opts.spells or { { name = "Fishing", id = 7620 } }
  local game = mock.new(opts)
  game.items = {
    [13422] = { name = "Stonescale Eel", quality = 1, sell = 10 },
    [13760] = { name = "Raw Sunscale Salmon", quality = 1, sell = 6 },
    [21071] = { name = "Raw Sagefish", quality = 1, sell = 2 },
    [6529] = { name = "Shiny Bauble", quality = 1 },
    [13874] = { name = "Heavy Crate", quality = 2, sell = 0 },
  }
  game.subzone = "Lake Mennar"
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.FishingLog
end

local function cast(game) game:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", 7620) end
local function catch(ns, id, name, n) ns.Events:Fire("OTR_LOOT", "fish", { { id = id, name = name, count = n or 1 } }) end

T.describe("fishing log", function()
  T.it("works out fish, vendor and auction gold per hour, catch rate and getaways", function()
    local game, ns, L = start()
    ns.Prices:Record(13422, 100) -- Stonescale Eel at the AH: 1s
    for i = 1, 10 do
      cast(game)
      game.now = game.now + 30
      if i <= 8 then catch(ns, i <= 6 and 13422 or 21071, i <= 6 and "Stonescale Eel" or "Raw Sagefish") end
    end
    game:fire("UI_ERROR_MESSAGE", 0, "Your fish got away!")
    local st = L.Stats(L:Current())
    T.eq(st.catches, 8)
    T.eq(st.casts, 10)
    T.eq(st.escapes, 1)
    T.eq(st.vendor, 6 * 10 + 2 * 2, "vendor price of everything")
    T.eq(st.auction, 6 * 95 + 2 * 2, "auction after the 5% cut; vendor where there's no AH price")
    T.ok(st.fishHr > 90 and st.fishHr < 110, "8 fish in ~270s is about 100 an hour: " .. tostring(st.fishHr))
    T.eq(st.fish[1].name, "Stonescale Eel")
    T.eq(st.fish[1].n, 6)
    T.eq(st.fish[1].share, 0.75)
    local report = table.concat(L:Report(), "\n")
    T.contains(report, "8 caught of 10 casts, 1 got away")
    T.contains(report, "fish/hr")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("fish per hour with and without a lure, and the skill gained", function()
    local game, ns, L = start()
    ns.Fishing.LureActive = function() return game.lureOn == true end
    game.lureOn = true
    for _ = 1, 6 do cast(game) game.now = game.now + 30 catch(ns, 21071, "Raw Sagefish") end
    game.lureOn = false
    for _ = 1, 4 do cast(game) game.now = game.now + 60 catch(ns, 21071, "Raw Sagefish") end
    game:fire("CHAT_MSG_SKILL", "Your skill in Fishing has increased to 226.")
    game:fire("CHAT_MSG_SKILL", "Your skill in Fishing has increased to 227.")
    local st = L.Stats(L:Current())
    T.ok(st.lureHr > st.bareHr, "faster with the lure")
    T.eq(st.gained, 2)
    T.contains(table.concat(L:Report(), "\n"), "With a lure")
  end)

  T.it("a session survives a short break, a long one goes into the history", function()
    local game, ns, L = start()
    cast(game) catch(ns, 13422, "Stonescale Eel")
    game.now = game.now + 600
    cast(game) catch(ns, 13422, "Stonescale Eel")
    T.eq(L:Current().catches, 2, "10 minutes away: same session")
    game.now = game.now + 3600
    T.eq(L:Current(), nil, "an hour away: the session is over")
    cast(game)
    T.eq(#L.data.sessions, 1)
    T.eq(L.data.sessions[1].catches, 2)
    T.eq(L.data.best.catches.v, 2)
  end)

  T.it("ranks this zone's spots and says where a fish bites best", function()
    local game, ns, L = start()
    for _ = 1, 6 do cast(game) game.now = game.now + 20 catch(ns, 13422, "Stonescale Eel") end
    game.subzone = "Bay of Storms"
    for i = 1, 6 do cast(game) game.now = game.now + 60 if i <= 2 then catch(ns, 13422, "Stonescale Eel") else catch(ns, 13760, "Raw Sunscale Salmon") end end
    local spots = L:SpotsHere(1446)
    T.eq(spots[1].name, "Lake Mennar", "faster catching first")
    T.ok(spots[1].ranked)
    local where = L:WhereBites(13422)
    T.eq(where[1].name, "Lake Mennar")
    T.eq(where[1].share, 1)
    T.ok(L:GoSpot(spots[1].spot), "an arrow back to the spot")
  end)

  T.it("the first catch of a fish is new for the collection, once; old catches aren't", function()
    local game, ns, L = start()
    ns.db.global.fishLog.first[21071] = { t = 0 }
    catch(ns, 21071, "Raw Sagefish")
    T.ok(not game:chatText():find("new for your collection", 1, true), "caught before: not new")
    catch(ns, 13760, "Raw Sunscale Salmon")
    catch(ns, 13422, "Stonescale Eel")
    local _, n = game:chatText():gsub("new for your collection", "")
    T.eq(n, 1, "one chat line per session")
    T.eq(L.data.notable[1].name, "Stonescale Eel")
    T.eq(L.data.notable[1].why, "new")
    catch(ns, 13874, "Heavy Crate")
    catch(ns, 13874, "Heavy Crate")
    T.eq(L.data.notable[1].why, "rare", "a green catch is notable")
  end)

  T.it("the wanted list counts from the bags and alerts on a catch", function()
    local game, ns, L = start()
    T.ok(not L:Want(nil, 5))
    catch(ns, 13422, "Stonescale Eel")
    ns.Slash:Run("fishwant Stonescale Eel 3")
    local w = L:Wanted()
    T.eq(#w, 1)
    T.eq(w[1].want, 3)
    game.counts = { [13422] = 2 }
    T.eq(L:Wanted()[1].have, 2)
    catch(ns, 13422, "Stonescale Eel")
    local log = ""
    for _, l in ipairs(ns.Log:Tail(20)) do log = log .. ns.Log:FormatLine(l) .. "\n" end
    T.contains(log, "wanted catch Stonescale Eel 3/3")
    ns.Slash:Run("fishwant remove Stonescale Eel")
    T.eq(#L:Wanted(), 0)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("lures left in the bags, low under 5, shown on the HUD", function()
    local game, ns, L = start()
    game.bags = { [0] = { [1] = 6529 } }
    game.counts = { [0] = { [1] = 3 } }
    local stock = L:Lures()
    T.eq(stock.name, "Shiny Bauble")
    T.eq(stock.count, 3)
    T.ok(stock.low)
    ns.Fishing.PoleEquipped = function() return true end
    ns.FishingHUD:Update()
    T.contains(table.concat(ns.FishingHUD:Lines(), "\n"), "3 left")
  end)

  T.it("the Fishing page shows the session, spots, wanted list and records without errors", function()
    local game, ns, L = start()
    for _ = 1, 6 do cast(game) game.now = game.now + 30 catch(ns, 13422, "Stonescale Eel") end
    L:Want(13422, 20, "Stonescale Eel")
    ns.Hub:Toggle()
    ns.Hub:ShowTab("fishing")
    T.eq(#ns.Errors.list, 0)
  end)
end)

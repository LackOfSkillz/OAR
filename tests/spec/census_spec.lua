-- Census: who's playing (2026-11-17).
local T, mock = ...

local function who(name, level, class, race, guild)
  return { fullName = name, fullGuildName = guild or "", level = level, raceStr = race or "Orc",
    classStr = class:sub(1, 1) .. class:sub(2):lower(), area = "Orgrimmar", filename = class }
end

local function start()
  local game = mock.new({ class = "HUNTER", level = 20 })
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.Census
end

T.describe("census", function()
  T.it("counts players seen around you, once each, with level, class, race and guild", function()
    local game, ns, M = start()
    game.units = { mouseover = { name = "Grom", level = 34, class = "WARRIOR", race = "Orc", player = true, guild = "Horde Kings", faction = "Horde" } }
    game:fire("UPDATE_MOUSEOVER_UNIT")
    game.units.target = game.units.mouseover
    game:fire("PLAYER_TARGET_CHANGED")
    game.units.nameplate1 = { name = "Kobold", level = 5, class = "WARRIOR", player = false }
    game:fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local s = M:Stats()
    T.eq(s.total, 1)
    T.eq(s.top[1].l, 34)
    T.eq(s.top[1].g, "Horde Kings")
    T.eq(s.classes[1].key, "WARRIOR")
    T.eq(s.races[1].key, "Orc")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("never counts you, and switching it off stops counting", function()
    local game, ns, M = start()
    game.units = { mouseover = { name = ns.Compat.Call("UnitName", "player"), level = 20, class = "HUNTER", player = true } }
    game:fire("UPDATE_MOUSEOVER_UNIT")
    T.eq(M:Stats().total, 0)
    M:Settings().passive = false
    game.units.mouseover = { name = "Thrall", level = 60, class = "SHAMAN", player = true }
    game:fire("UPDATE_MOUSEOVER_UNIT")
    T.eq(M:Stats().total, 0)
  end)

  T.it("one press sends one /who search; full results split, the count finishes", function()
    local game, ns, M = start()
    game.now = 1000
    local sent = M:SearchNext()
    T.eq(sent, "1-10")
    T.eq(#game.whoSent, 1)
    -- a second press before the answer waits
    local again, why = M:SearchNext()
    T.eq(again, nil)
    T.contains(why, "waiting")
    -- 1-10 comes back full: 50 shown of 80
    local res = {}
    for i = 1, 50 do res[i] = who("Low" .. i, 1 + (i % 10), i % 2 == 0 and "WARRIOR" or "HUNTER", i % 3 == 0 and "Troll" or "Orc") end
    game.whoResults, game.whoTotal = res, 80
    game:fire("WHO_LIST_UPDATE")
    T.eq(M:Stats().total, 50)
    T.eq(M.sweep.queue[1].lo, 1)
    T.eq(M.sweep.queue[1].hi, 5)
    T.eq(M.sweep.queue[2].lo, 6)
    -- nothing goes out on its own: only presses send
    game:advance(30)
    T.eq(#game.whoSent, 1)
    -- press through the rest with small answers
    game.whoResults, game.whoTotal = { who("Mid", 25, "MAGE", "Undead") }, nil
    local guard = 0
    while M:Left() > 0 and guard < 40 do
      game.now = game.now + 10
      T.ok(M:SearchNext())
      game:fire("WHO_LIST_UPDATE")
      guard = guard + 1
    end
    T.eq(M:Left(), 0)
    T.ok(M:Realm().lastSweep)
    T.contains(game:chatText(), "census done")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a single full level splits by class", function()
    local game, ns, M = start()
    game.now = 1000
    M.sweep = { queue = { { lo = 60, hi = 60 } }, done = 0, capped = 0, found = 0 }
    M:SearchNext()
    local res = {}
    for i = 1, 50 do res[i] = who("Max" .. i, 60, "ROGUE") end
    game.whoResults, game.whoTotal = res, 50
    game:fire("WHO_LIST_UPDATE")
    T.ok(M:Left() >= 8)
    T.ok(M.sweep.queue[1].class)
    T.contains(M.Filter(M.sweep.queue[1]), 'c-"')
  end)

  T.it("counts professions only from profession links in chat", function()
    local game, ns, M = start()
    local link = "|cffffd000|Htrade:Player-1-000000AA:2259:171|h[Alchemy]|h|r"
    game:fire("CHAT_MSG_CHANNEL", "LF work " .. link, "Brewer-Realm", "", "", "", "", 0, 2, "Trade", 0, 1, "Player-1-000000AA")
    game:fire("CHAT_MSG_CHANNEL", "selling stuff", "Other-Realm", "", "", "", "", 0, 2, "Trade", 0, 2, "Player-1-000000BB")
    local s = M:Stats()
    T.eq(s.withProf, 1)
    T.eq(s.profs[1].key, "Alchemy")
    T.eq(#M.ParseTrade("[Not a link]"), 0)
  end)

  T.it("drops players not seen for 30 days; the advisor snapshot has counts, never names", function()
    local game, ns, M = start()
    game.now = 100000000
    M:Add("Old-Realm", { l = 10, c = "MAGE" }, "seen")
    game.now = game.now + 86400 * 31
    M:Add("New-Realm", { l = 40, c = "PRIEST" }, "seen")
    T.eq(M:Prune(), 1)
    local snap = M:Snapshot()
    T.eq(snap.players, 1)
    T.eq(snap.highest, 40)
    local text = ns.Serialize and ns.Serialize.Encode and ns.Serialize.Encode(snap) or ""
    T.eq(tostring(text):find("New", 1, true), nil)
  end)

  T.it("the page and command work", function()
    local game, ns, M = start()
    M:Add("Grom-Realm", { l = 34, c = "WARRIOR", r = "Orc" }, "seen")
    ns.Hub:Toggle()
    ns.Hub:ShowTab("census")
    game:slash("census")
    T.contains(game:chatText(), "most common level 34")
    game:slash("census reset")
    T.eq(M:Stats().total, 0)
    T.eq(#ns.Errors.list, 0)
  end)
end)

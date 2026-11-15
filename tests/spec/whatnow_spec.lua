-- Pathfinder Lite: What now? (scoring, goals, picking, fail soft, the page).
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

local function cand(kind, name, benefit, extra)
  local c = { key = kind .. ":" .. name, kind = kind, title = name, benefit = benefit, confidence = 1 }
  for k, v in pairs(extra or {}) do c[k] = v end
  return c
end

T.describe("what now", function()
  T.it("the goal changes the order for the same candidates", function()
    local _, ns = session()
    local W = ns.WhatNow
    local cands = function() return { cand("quest", "Wolves", 0.8), cand("gold", "Skin boars", 0.8), cand("gear", "Sword", 0.8) } end
    T.eq(W.Pick(cands(), "level")[1].kind, "quest")
    T.eq(W.Pick(cands(), "gold")[1].kind, "gold")
    T.eq(W.Pick(cands(), "gear")[1].kind, "gear")
  end)

  T.it("far, unsure steps score lower; urgent errands come first", function()
    local _, ns = session()
    local W = ns.WhatNow
    local near = cand("quest", "Near", 0.8, { seconds = 60 })
    local far = cand("quest", "Far", 0.8, { seconds = 1800 })
    local unsure = cand("quest", "Unsure", 0.8, { seconds = 60, confidence = 0.3 })
    T.ok(W.Score(near, "level") > W.Score(far, "level"))
    T.ok(W.Score(near, "level") > W.Score(unsure, "level"))
    local list = W.Pick({ near, cand("errand", "Repair", 0.2, { urgent = true }) }, "level")
    T.eq(list[1].title, "Repair")
  end)

  T.it("picks 3 to 5, at most 2 of a kind, and the next of a kind becomes the alternative", function()
    local _, ns = session()
    local W = ns.WhatNow
    local cands = {}
    for i = 1, 6 do cands[#cands + 1] = cand("quest", "Q" .. i, 1 - i / 10) end
    cands[#cands + 1] = cand("gear", "Sword", 0.5)
    cands[#cands + 1] = cand("errand", "Repair", 0.4)
    local list = W.Pick(cands, "level")
    T.ok(#list >= 3 and #list <= 5)
    local quests = 0
    for _, c in ipairs(list) do if c.kind == "quest" then quests = quests + 1 end end
    T.eq(quests, 2)
    T.eq(list[1].title, "Q1")
    T.eq(list[1].alt.text, "Q3")
    -- only one kind available: still at least 3
    local only = {}
    for i = 1, 4 do only[#only + 1] = cand("quest", "Q" .. i, 0.5) end
    T.eq(#W.Pick(only, "mix"), 3)
  end)

  T.it("not useful hides a step for a day; repeats are counted", function()
    local game, ns = session({ ammo = 1000 })
    local W = ns.WhatNow
    W.SOURCES.spec = function() return { cand("quest", "Wolves", 0.9), cand("gear", "Sword", 0.5), cand("gold", "Skin", 0.4) } end
    table.insert(W.ORDER, "spec")
    local list = W:List(true)
    T.eq(list[1].title, "Wolves")
    W:Skip(list[1])
    T.no(W:List(true)[1].title == "Wolves")
    game:advance(86401)
    T.eq(W:List(true)[1].title, "Wolves")
    T.ok(W:Store().shown["quest:Wolves"] >= 2)
    table.remove(W.ORDER)
  end)

  T.it("a failing source is skipped and logged, never an error", function()
    local _, ns = session()
    local W = ns.WhatNow
    W.SOURCES.broken = function() error("boom") end
    table.insert(W.ORDER, "broken")
    local list = W:List(true)
    T.ok(type(list) == "table")
    T.eq(W.failed[#W.failed], "broken")
    table.remove(W.ORDER)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("real sources: broken gear is the urgent first step, with what, why and where", function()
    local game, ns = session({ level = 24, ammo = 1000 })
    game.durability = { [1] = { 2, 50 }, [5] = { 80, 80 } }
    local list = ns.WhatNow:List(true)
    T.eq(list[1].kind, "errand")
    T.contains(list[1].title, "Repair")
    T.ok(list[1].why ~= nil and list[1].where ~= nil)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("quests: battleground quests left out, hard quests count for less", function()
    local _, ns = session({ ammo = 1000 })
    local W = ns.WhatNow
    T.ok(W.PVP("Fight for Warsong Gulch", "x"))
    T.ok(W.PVP("Supplies", "Horde Warbringer"))
    T.no(W.PVP("Cave Mushrooms", "Barithras Moonshade"))
    T.ok(W.PVP("Winter's Presents", "Wonderform Operator"))
    T.ok(W.PVP("New Year Celebrations!", "x"))
    local real = ns.Journey.XPList
    ns.Journey.XPList = function() return {
      { name = "Warsong", giver = "Brigadier General", level = 19, xp = 1700, rate = 400, diff = "orange", seconds = 60 },
      { name = "Hard", giver = "A", level = 19, xp = 1700, rate = 330, diff = "orange", seconds = 60 },
      { name = "Fits", giver = "B", level = 16, xp = 1300, rate = 280, diff = "yellow", seconds = 60 },
    } end
    local list = W.SOURCES.quests()
    ns.Journey.XPList = real
    T.eq(list[1].key, "quest:Fits")
    T.contains(list[2].why, "hard fights")
    -- none of them is in this zone: the last step says to look around
    T.eq(#list, 3)
    T.eq(list[3].key, "quest:look-around")
  end)

  T.it("gear: one step per slot, the second item for a slot is its alternative", function()
    local game, ns = session({ ammo = 1000 })
    game.items = game.items or {}
    game.items[9001] = { name = "Polished Shortbow", equipLoc = "INVTYPE_RANGED", class = 2, subclass = 2 }
    game.items[9002] = { name = "Worn Shortbow", equipLoc = "INVTYPE_RANGED", class = 2, subclass = 2 }
    game.items[9003] = { name = "Rusty Sword", equipLoc = "INVTYPE_WEAPON", class = 2, subclass = 7 }
    local real = ns.Journey.GearList
    ns.Journey.GearList = function() return {
      { name = "Polished Shortbow", itemID = 9001, pct = 40, seconds = 60, mapID = 1412 },
      { name = "Worn Shortbow", itemID = 9002, pct = 35, seconds = 60, mapID = 1412 },
      { name = "Rusty Sword", itemID = 9003, pct = 20, seconds = 60, mapID = 1412 },
    } end
    local list = ns.WhatNow.SOURCES.gear()
    ns.Journey.GearList = real
    T.eq(#list, 2)
    T.eq(list[1].title, "Get Polished Shortbow")
    T.contains(list[1].alt.text, "Worn Shortbow")
    T.eq(list[2].title, "Get Rusty Sword")
  end)

  T.it("gear with no real level requirement goes by item level", function()
    local _, ns = session()
    local fits = ns.Nearby.LevelFits
    T.no(fits({ "Furbolg Medicine Pouch", 0, 52 }, 1))
    T.no(fits({ "Surfer Shoes", 1, 25 }, 1))
    T.ok(fits({ "Starter Shirt", 0, 5 }, 1))
    T.ok(fits({ "Blade", 14, 20 }, 15))
    T.no(fits({ "Big Blade", 20, 25 }, 15))
  end)

  T.it("the trainer errand finds a trainer of your own class", function()
    local game, ns = session({ ammo = 1000 })
    local W = ns.Waypoints
    ns.db.global.pois = {
      a = { kind = "trainer", title = "Priest Trainer", name = "Priesty", mapID = 1412, x = 0.46, y = 0.37 },
      b = { kind = "trainer", title = "Hunter Trainer", name = "Huntress", mapID = 1412, x = 0.47, y = 0.38 },
      c = { kind = "trainer", title = "Cook", name = "Cooky", mapID = 1412, x = 0.461, y = 0.371 },
    }
    local p = ns.Nearest:Find("class_trainer")
    T.eq(p and p.name, "Huntress")
    T.eq(ns.Nearest:Find("trainer").name, "Priesty")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("every goal is logged the first time the page lists steps, then on new zones at most every 10 minutes", function()
    local game, ns = session({ ammo = 1000 })
    T.eq(ns.WhatNow.loggedAt, nil)
    game:fire("ZONE_CHANGED_NEW_AREA")
    T.eq(ns.WhatNow.loggedAt, nil)
    ns.WhatNow:List(true)
    local logged = ns.WhatNow.loggedAt
    T.ok(logged ~= nil)
    game:fire("ZONE_CHANGED_NEW_AREA")
    T.eq(ns.WhatNow.loggedAt, logged)
    game:advance(601)
    game:fire("ZONE_CHANGED_NEW_AREA")
    T.ok(ns.WhatNow.loggedAt > logged)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("goal is per character and set by /ride now; the page builds", function()
    local game, ns = session()
    game:slash("now gold")
    T.eq(ns.WhatNow:Goal(), "gold")
    game:slash("now nonsense")
    T.eq(ns.WhatNow:Goal(), "gold")
    T.contains(game:chatText(), "goals:")
    ns.Hub:Build():Show()
    ns.Hub:ShowTab("whatnow")
    T.eq(ns.Hub.current, "whatnow")
    local page = ns.Hub.byId.whatnow.panel
    T.eq(#page.chips, 6)
    for _, chip in ipairs(page.chips) do T.eq(chip.on, chip.goal == "gold") end
    T.ok(page.cards[1]:IsShown())
    T.ok((page.cards[1].title.__text or "") ~= "")
    T.eq(page.errands.head.__text, "Errands")
    T.eq(page.session.rows[1][1].__text, "XP gained")
    T.eq(page.snap.rows[1][1].__text, "XP")
    T.ok(page.cards[1].tag.label.__text == "Recommended")
    ns.Hub:ShowTab("home")
    local home = ns.Hub.byId.home.panel
    T.contains(home.heading.__text, "Welcome back")
    T.ok((home.next.title.__text or "") ~= "")
    ns.Hub:ShowTab("whatnow")
    page.chips[1]:Click()
    T.eq(ns.WhatNow:Goal(), "level")
    T.ok(page.chips[1].on)
    T.eq(#ns.Errors.list, 0)
  end)
end)

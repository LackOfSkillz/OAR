-- Herbalism helper: Find Herbs reminder, pin nodes you mouse over. Names are test data.
local T, mock = ...

local function session(tracking)
  local game = mock.new()
  game.prof = { name = "Herbalism", skill = 4, max = 75, line = 182, recipes = {} }
  game.tracking = tracking
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game:advance(6)
  return game, ns
end

local function objectHook(game)
  for _, h in ipairs(game.tooltipHooks or {}) do if h.kind == 33 then return h.fn end end
end

local function said(game, text)
  local n = 0
  for _, l in ipairs(game.chat) do if l:find(text, 1, true) then n = n + 1 end end
  return n
end

T.describe("herb helper", function()
  T.it("notes once in the Feed (not chat) when Find Herbs is off, and logs the tracking list", function()
    local game, ns = session({ { name = "Find Herbs", active = false }, { name = "Track Beasts", active = true } })
    local function inFeed()
      local n = 0
      for _, e in ipairs(ns.Feed.list) do if e.title == "Find Herbs is off" then n = n + (e.count or 1) end end
      return n
    end
    T.eq(inFeed(), 1)
    T.eq(said(game, "Find Herbs is off"), 0, "login chat stays quiet")
    game:fire("PLAYER_ENTERING_WORLD", false, true)
    game:advance(6)
    T.eq(inFeed(), 1, "once per session")
    local logged
    for _, l in ipairs(ns.Log:Tail(40)) do
      if ns.Log:FormatLine(l):find("minimap tracking: Find Herbs, Track Beasts (on)", 1, true) then logged = true end
    end
    T.ok(logged)
  end)

  T.it("quiet when Find Herbs is on", function()
    local game = session({ { name = "Find Herbs", active = true } })
    T.eq(said(game, "is off"), 0)
  end)

  T.it("mousing over a herb pins it once; other objects are only logged", function()
    local game, ns = session({})
    local hook = objectHook(game)
    T.ok(hook, "object tooltip hooked")
    local before = #ns.db.global.nodes
    hook(game.env.GameTooltip, { lines = { { leftText = "Silverleaf" }, { leftText = "Herbalism" } } })
    hook(game.env.GameTooltip, { lines = { { leftText = "Silverleaf" }, { leftText = "Herbalism" } } })
    hook(game.env.GameTooltip, { lines = { { leftText = "Mailbox" } } })
    T.eq(#ns.db.global.nodes, before + 1)
    local n = ns.db.global.nodes[#ns.db.global.nodes]
    T.eq(n.name, "Silverleaf")
    T.eq(n.kind, "herb")
    T.ok(n.seenOnly and n.verified == false)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("guide hints: skill line on the herb node, zones on the herb item, /ride herbs lists them", function()
    local game, ns = session({})
    ns.db.char.professions.Herbalism = { skill = 4, max = 75, recipes = {} }
    local text, color = ns.HerbHelper:SkillLine("Earthroot")
    T.eq(text, "Herbalism 15 needed (you have 4)")
    T.eq(color, "bad")
    T.eq(ns.HerbHelper:SkillLine("Peacebloom"), nil, "no skill stated by the guides")
    local lines = ns.HerbHelper:ItemLines("Mageroyal")
    T.contains(lines[1][1], "Grows in: Silverpine Forest")
    local e = ns.Data:Get("herb", "Earthroot")
    T.eq(e.verified, false)
    game:slash("herbs")
    local listed
    for _, l in ipairs(game.chat) do if l:find("Khadgar's Whisker 185", 1, true) then listed = true end end
    T.ok(listed)
    T.eq(#ns.Errors.list, 0)
  end)
  T.it("reminds once per character per day, not on every reload or login (it came back x38)", function()
    local game, ns = session({ { name = "Find Herbs", active = false } })
    local H = ns.HerbHelper
    for _ = 1, 5 do H.reminded = nil H:CheckTracking() end
    local n = 0
    for _, e in ipairs(ns.Feed.list) do if e.title == "Find Herbs is off" then n = n + (e.count or 1) end end
    T.eq(n, 1, "the same day: once")
    game:advance(86400 + 60)
    H:CheckTracking()
    n = 0
    for _, e in ipairs(ns.Feed.list) do if e.title == "Find Herbs is off" then n = n + (e.count or 1) end end
    T.eq(n, 2, "the next day: once more")
  end)

  T.it("another character's notice is its own entry with its own name, never merged under the first", function()
    local game, ns = session({ { name = "Find Herbs", active = false } })
    local first = ns.Feed.list[1]
    T.eq(first.who, ns.db.key)
    local me = ns.db.key
    ns.db.key = "Sheer-Mcluvin"
    ns.Feed:Add(nil, { title = first.title, text = first.text })
    ns.db.key = me
    T.eq(ns.Feed.list[1].who, "Sheer-Mcluvin")
    T.eq(ns.Feed.list[2].who, me)
    T.eq(ns.Feed.list[2].count or 1, 1, "the other character's count is untouched")
  end)

  T.it("Turn on switches Find Herbs on from the feed card, and says so when the client refuses", function()
    local game, ns = session({ { name = "Find Herbs", active = false }, { name = "Track Beasts", active = true } })
    ns.Hub:Build():Show()
    ns.Hub:ShowTab("feed")
    local ok, why = ns.HerbHelper:TurnOn("Find Herbs")
    T.ok(ok, why) T.eq(game.tracking[1].active, true)
    ok, why = ns.HerbHelper:TurnOn("Find Herbs")
    T.ok(why:find("already on"))
    game.tracking[1].active = false
    game.trackingLocked = true
    ok, why = ns.HerbHelper:TurnOn("Find Herbs")
    T.eq(ok, false) T.ok(why:find("Herb button"), why)
    T.ok(ns.Feed.ACTIONS.tracking, "the feed knows the Turn on button")
    T.eq(ns.Feed.list[1].action, "tracking") T.eq(ns.Feed.list[1].arg, "Find Herbs")
    local missing = {}
    for label in pairs(ns.UI.untipped or {}) do missing[#missing + 1] = label end
    T.eq(#missing, 0, table.concat(missing, ", "))
    T.eq(#ns.Errors.list, 0)
  end)
end)

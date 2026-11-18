-- Quest chains, breadcrumbs, reputation, filters, sounds, chat links,
-- history, paths, the tracker and party counts (2026-11-17). Test data.
local T, mock = ...

local function set(game, k, v) game.base[k] = v rawset(game.env, k, v) end

local function start()
  local game = mock.new({ class = "HUNTER", level = 20, inGroup = true })
  local pack = { source = "test",
    quests = {
      [10] = { "First Steps", 10, {} }, [11] = { "Second Steps", 12, { { "npc", 500, "Escort Bob" } } },
      [12] = { "Last Steps", 14, {} }, [20] = { "Go Talk", 18, {} }, [21] = { "The Real Quest", 20, {} },
      [30] = { "Fair Fun", 15, {} }, [31] = { "Fish Fry", 15, {} },
    },
    info = {
      [10] = { n = 11 }, [11] = { n = 12, rep = { 72, 250 } }, [20] = { bf = 21 }, [21] = { bc = { 20 } },
      [30] = { s = -364, r = 1 }, [31] = { s = -101 },
    },
    paths = { [500] = { [1412] = { 0.1, 0.1, 0.2, 0.2, 0.3, 0.3 } } },
    npcs = { [500] = { "Bob", { [1412] = { 0.1, 0.1 } } } },
    objects = {}, items = {}, starters = {},
  }
  game.base.Outrider_DataQuests = pack
  rawset(game.env, "Outrider_DataQuests", pack)
  game.questLog = {
    { title = "Mulgore", isHeader = true },
    { title = "Second Steps", questID = 11, level = 12 },
  }
  game.questObjectives = { [11] = { { text = "Bob escorted: 0/1", finished = false } } }
  local ns = game:loadAddon()
  game:login()
  set(game, "GetFactionInfoByID", function(id) return id == 72 and "Stormwind" or nil end)
  return game, ns, ns.QuestInfo
end

T.describe("quest details", function()
  T.it("chains, reputation, breadcrumbs and categories", function()
    local game, ns, M = start()
    local part, len, nxt = M:Chain(11)
    T.eq(part, 2) T.eq(len, 3) T.eq(nxt, 12)
    local s = table.concat(M:Lines(11), "\n")
    T.contains(s, "Part 2 of 3 · next: Last Steps")
    T.contains(s, "Reputation: +250 Stormwind")
    T.contains(table.concat(M:Lines(20), "\n"), "Leads to: The Real Quest")
    T.contains(table.concat(M:Lines(30), "\n"), "Darkmoon Faire, repeatable")
  end)

  T.it("warns once about a skipped breadcrumb and keeps a dated history", function()
    local game, ns, M = start()
    game:fire("QUEST_ACCEPTED", 5, 21)
    game:fire("QUEST_ACCEPTED", 5, 21)
    local chat = game:chatText()
    T.contains(chat, "without its breadcrumb quest Go Talk")
    local _, n = chat:gsub("without its breadcrumb", "")
    T.eq(n, 1)
    game:fire("QUEST_TURNED_IN", 21)
    game:fire("QUEST_REMOVED", 21)
    game:fire("QUEST_ACCEPTED", 6, 10)
    game:fire("QUEST_REMOVED", 10)
    local h = table.concat(M:HistoryLines(10), "\n")
    T.contains(h, "abandoned First Steps")
    T.contains(h, "handed in The Real Quest")
    T.eq(h:find("abandoned The Real Quest", 1, true), nil)
  end)

  T.it("quest givers hide event and other-profession quests unless switched on", function()
    local game, ns, M = start()
    T.eq(M:Keep(30), false, "Darkmoon hidden")
    T.eq(M:Keep(31), false, "no Fishing")
    ns.db.char.professions = { Fishing = { skill = 1 } }
    T.eq(M:Keep(31), true)
    M:Settings().showEvent = true
    T.eq(M:Keep(30), true)
    T.eq(M:Tag(30), "Darkmoon Faire, repeatable")
  end)

  T.it("quest links in chat show their level; sounds use the game's SOUNDKIT", function()
    local game, ns, M = start()
    T.eq(M.LevelLinks("get |cffffff00|Hquest:21:20|h[The Real Quest]|h|r now"), "get |cffffff00|Hquest:21:20|h[[20] The Real Quest]|h|r now")
    T.eq(M.LevelLinks("plain"), "plain")
    set(game, "SOUNDKIT", { IG_QUEST_LIST_COMPLETE = 878 })
    local played
    set(game, "PlaySound", function(id) played = id end)
    ns.Events:Fire("OTR_QUEST_READY", 11)
    T.eq(played, 878)
  end)

  T.it("escort NPC paths on the map for your quests", function()
    local game, ns, M = start()
    local pins = M:PathPins(1412)
    T.eq(#pins, 3)
    T.contains(pins[1].name, "Bob walks here (Second Steps)")
  end)

  T.it("the tracker lists quests by zone with party progress, and builds without errors", function()
    local game, ns, M = start()
    game.units = { party1 = { name = "Oni", player = true } }
    set(game, "IsInRaid", function() return false end)
    ns.PartyQuests:Scan()
    ns.Events:Fire("OTR_COMM", "QSTAT", { done = {}, prog = { [11] = { "Bob escorted: 1/1" } } }, "Oni-Airwolf", "PARTY")
    local lines = ns.QuestTracker:Lines()
    local all = {}
    for _, l in ipairs(lines) do all[#all + 1] = l.text end
    local s = table.concat(all, "\n")
    T.contains(s, "Mulgore (1)")
    T.contains(s, "[12] Second Steps")
    T.contains(s, "Bob escorted: 0/1")
    T.contains(s, "Oni 1/1")
    ns.QuestTracker:Refresh()
    T.ok(ns.QuestTracker.frame:IsShown())
    T.eq(#ns.Errors.list, 0)
  end)
end)

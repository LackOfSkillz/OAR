-- Party quest announcements and "everyone is done" (2026-11-17).
local T, mock = ...

local function set(game, k, v) game.base[k] = v rawset(game.env, k, v) end

local function start()
  local game = mock.new({ class = "HUNTER", level = 20, inGroup = true })
  game.units = { party1 = { name = "Oni", player = true } }
  game.questLog = { { questID = 100, title = "Solomon's Law", isComplete = false } }
  game.questObjectives = { [100] = { { text = "Shadowhide Pendant: 9/10", finished = false } } }
  local ns = game:loadAddon()
  game:login()
  set(game, "IsInRaid", function() return false end)
  game.said = {}
  set(game, "SendChatMessage", function(text, channel) game.said[#game.said + 1] = channel .. ": " .. text end)
  set(game, "GetQuestLink", function(id) return "|cffffff00|Hquest:" .. id .. ":23|h[Solomon's Law]|h|r" end)
  game.base.C_QuestLog.IsUnitOnQuest = function(unit, id) return unit == "party1" and id == 100 end
  return game, ns, ns.PartyQuests
end

local function finish(game)
  game.questLog[1].isComplete = true
  game.questObjectives[100][1] = { text = "Shadowhide Pendant: 10/10", finished = true }
end

T.describe("party quests", function()
  T.it("announces your objectives and a finished quest to the party, once each", function()
    local game, ns, M = start()
    M:Scan()
    T.eq(#game.said, 0, "nothing on the first look")
    finish(game)
    M:Scan()
    game:advance(1.5)
    M:Scan()
    game:advance(1.5)
    local all = table.concat(game.said, "\n")
    T.contains(all, "PARTY: Outrider: Shadowhide Pendant: 10/10 for |cffffff00|Hquest:100")
    T.contains(all, "Outrider: Quest ready to hand in:")
    T.eq(#game.said, 2, "each once: " .. all)
    game:fire("QUEST_TURNED_IN", 100)
    game:advance(1.5)
    T.contains(table.concat(game.said, "\n"), "Outrider: Quest completed:")
  end)

  T.it("says everyone is done when a Questie user in the party finishes the same quest", function()
    local game, ns, M = start()
    M:Scan()
    finish(game)
    M:Scan()
    game:advance(3)
    T.eq(table.concat(game.said, "\n"):find("Everyone", 1, true), nil, "Oni hasn't finished yet")
    game:fire("CHAT_MSG_PARTY", "{rt1} Questie: Shadowhide Pendant: 10/10 for |cffffff00|Hquest:100:23|h[Solomon's Law]|h|r!", "Oni-Airwolf")
    game:advance(3)
    T.contains(table.concat(game.said, "\n"), "Outrider: Everyone is done with")
  end)

  T.it("reads Questie's lines and an Outrider user's QSTAT", function()
    local game, ns, M = start()
    local id, what = M.ParseQuestie("{rt1} Questie: Quest Completed: |cffffff00|Hquest:55:10|h[Dry Times]|h|r")
    T.eq(id, 55)
    T.eq(what, "done")
    T.eq(M.ParseQuestie("{rt1} Questie: Quest Accepted: |cffffff00|Hquest:55:10|h[Dry Times]|h|r"), nil)
    T.eq(M.Key("Shadowhide Pendant: 10/10"), "shadowhide pendant")
    M:Scan()
    finish(game)
    M:Scan()
    game:advance(3)
    -- (Oni sorts before us by name, so Oni's Outrider would speak; use Zed)
    game.units.party1.name = "Zed"
    ns.Events:Fire("OTR_COMM", "QSTAT", { done = { 100 } }, "Zed-Airwolf", "PARTY")
    game:advance(3)
    T.contains(table.concat(game.said, "\n"), "Everyone is done with")
  end)

  T.it("steps aside for your own announcements when Questie is loaded", function()
    local game, ns, M = start()
    set(game, "IsAddOnLoaded", function(name) return name == "Questie" end)
    if game.base.C_AddOns then game.base.C_AddOns.IsAddOnLoaded = function(name) return name == "Questie" end end
    M:Scan()
    finish(game)
    M:Scan()
    game:advance(3)
    T.eq(table.concat(game.said, "\n"):find("Shadowhide", 1, true), nil)
  end)
end)

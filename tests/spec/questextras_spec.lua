-- Quest marks on nameplates and quest XP (gap analysis 2026-11-17).
local T, mock = ...

local function start()
  local game = mock.new({ class = "HUNTER", level = 20 })
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.QuestExtras
end

T.describe("quest extras", function()
  T.it("marks a quest mob's nameplate with what's left, not other mobs or finished ones", function()
    local game, ns, M = start()
    game.units = {
      nameplate1 = { name = "Prairie Wolf", level = 5, objectives = { " - Prairie Wolf slain: 3/8" } },
      nameplate2 = { name = "Kodo", level = 5 },
      nameplate3 = { name = "Plainstrider", level = 5, objectives = { " - Plainstrider slain: 8/8" } },
    }
    for i = 1, 3 do game:fire("NAME_PLATE_UNIT_ADDED", "nameplate" .. i) end
    T.ok(M.active.nameplate1)
    T.contains(M.active.nameplate1.text:GetText(), "3/8")
    T.eq(M.active.nameplate2, nil)
    T.eq(M.active.nameplate3, nil)
    game:fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    T.eq(M.active.nameplate1, nil)
    M:Settings().plates = false
    game:fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    T.eq(M.active.nameplate1, nil)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("adds up the XP of the quests in your log for the info bar", function()
    local game, ns, M = start()
    game.questLog = { { title = "Zone", isHeader = true }, { title = "A", questID = 11 }, { title = "B", questID = 12 } }
    game.questXP = { [11] = 300, [12] = 200 }
    T.eq(M:LogXP(), 500)
    game.xp, game.xpMax = 100, 1000
    T.contains(ns.InfoBar:Text("xp"), "+50% quests")
  end)
end)

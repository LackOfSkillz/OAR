-- Scroll window and focused quest state (DEEP-10).
local T, mock = ...
local function session()
  local game = mock.new()
  game.questLog = { { title = "Mulgore", isHeader = true } }
  for i = 1, 39 do
    game.questLog[#game.questLog + 1] = { title = "Quest " .. i, questID = i + 9000, level = 20 }
  end
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  return game, ns, ns.QuestTracker
end

T.describe("quest tracker scroll and focus", function()
  T.it("shows a window into the full log and scrolls to final entries", function()
    local game, ns, M = session()
    M:Refresh()
    T.eq(#M.frame.rows, M.MAX_ROWS)
    T.contains(M.frame.title:GetText(), "1-20/40")
    M:Scroll(500)
    T.eq(M:Settings().scrollOffset, 20)
    T.contains(M.frame.title:GetText(), "21-40/40")
    T.contains(M.frame.rows[20].text:GetText(), "Quest 39")
    T.eq(M.frame.rows[20].IsShown(M.frame.rows[20]), true)
    M:Scroll(-500)
    T.eq(M:Settings().scrollOffset, 0)
    T.eq(#ns.Errors.list, 0)
  end)
  T.it("focus dims other quest rows and unfocus restores alpha", function()
    local game, ns, M = session()
    T.ok(M:Focus(9005))
    T.eq(M:Settings().focus, 9005)
    T.eq(M.frame.rows[2]:GetAlpha(), 0.45)
    T.ok(M:Focus(9005))
    T.eq(M:Settings().focus, nil)
    T.eq(M.frame.rows[2]:GetAlpha(), 1)
    T.eq(M:Focus(8888888), false)
    game:slash("tracker focus 9007")
    T.eq(M:Settings().focus, 9007)
    game:slash("tracker unfocus")
    T.eq(M:Settings().focus, nil)
    T.eq(#ns.Errors.list, 0)
  end)
end)

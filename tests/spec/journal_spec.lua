-- Journal page (gallery idea from Questie's Journey, 2026-11-18). Quests are test data.
local T, mock = ...

T.describe("journal", function()
  T.it("lists quest history newest first, counts it, and shows the picked entry", function()
    local game = mock.new({ class = "HUNTER", level = 20 })
    local ns = game:loadAddon()
    game:login()
    local Q = ns.QuestInfo
    Q:Record(101, "took")
    Q:Record(101, "handed in")
    Q:Record(102, "abandoned")
    local st = Q:JournalStats()
    T.eq(st.today, 1)
    T.eq(st.total, 1)
    T.eq(st.abandoned, 1)
    ns.Hub:Toggle()
    ns.Hub:ShowTab("journal")
    local p = ns.Hub.byId.journal.panel
    T.eq(#p.list.items, 3)
    T.eq(p.list.items[1].what, "abandoned", "newest first")
    T.contains(p.what:GetText(), "Gave up", "the picked entry, in plain words")
    T.eq(p.stats.tiles[1].value:GetText(), "1")
    T.eq(#ns.Errors.list, 0)
  end)
end)

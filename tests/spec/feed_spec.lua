-- Notification feed (P7-11).
local T, mock = ...

T.describe("feed", function()
  T.it("keeps every toast, newest first, capped at 50, with unread count", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    for i = 1, 55 do ns.Toast:Show({ title = "note " .. i, text = "body" }) end
    T.eq(#ns.Feed.list, 50)
    T.eq(ns.Feed.list[1].title, "note 55")
    T.eq(ns.Feed:Unread(), 50)
    game.now = game.now + 5
    game:slash("feed")
    T.eq(ns.Feed:Unread(), 0)
    T.contains(game:chatText(), "note 55")
    ns.Toast:Show({ title = "later" })
    T.eq(ns.Feed:Unread(), 1)
    T.eq(#ns.Errors.list, 0)
  end)
end)

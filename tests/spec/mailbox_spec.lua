-- Mailbox collect (P5-10).
local T, mock = ...

T.describe("mailbox", function()
  T.it("one thing per click, COD mail untouched", function()
    local game = mock.new()
    game.inbox = { { money = 500 }, { cod = 100, items = { 2318 } }, { items = { 2589, 2589 } } }
    local ns = game:loadAddon()
    game:login()
    game:fire("MAIL_SHOW")
    local b = ns.Mailbox.button
    T.contains(b.label:GetText(), "Collect (2 mail)")
    for _ = 1, 3 do b.__scripts.OnClick(b) end
    T.eq(game.inbox[1].money, 0)
    T.eq(next(game.inbox[3].items), nil)
    T.eq(game.inbox[2].items[1], 2318, "COD kept")
    T.eq(b.__scripts.OnClick(b), nil)
    T.eq(#ns.Errors.list, 0)
  end)
end)

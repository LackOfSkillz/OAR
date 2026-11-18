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
    T.contains(b.label:GetText(), "Collect (2 mail: ")
    T.contains(b.label:GetText(), "2 items")
    for _ = 1, 3 do b.__scripts.OnClick(b) end
    T.eq(game.inbox[1].money, 0)
    T.eq(next(game.inbox[3].items), nil)
    T.eq(game.inbox[2].items[1], 2318, "COD kept")
    T.eq(b.__scripts.OnClick(b), nil)
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("mailbox filters and space protection", function()
  T.it("filters auction mail without touching COD or unrelated mail", function()
    local game = mock.new()
    game.inbox = {
      { sender = "Auction House", subject = "Auction sold", money = 100 },
      { sender = "Auction House", subject = "Auction won", items = { 2589 } },
      { sender = "Auction House", subject = "Auction expired", items = { 1113 } },
      { sender = "Friend", subject = "Hello", items = { 117 } },
    }
    local ns = game:loadAddon()
    game:login()
    game:fire("MAIL_SHOW")
    game:slash("mail sold")
    T.eq(#ns.Mailbox:Collectable(), 1)
    T.eq(ns.Mailbox:Collectable()[1].kind, "sold")
    game:slash("mail won")
    T.eq(ns.Mailbox:Collectable()[1].index, 2)
    game:slash("mail expired")
    T.eq(ns.Mailbox:Collectable()[1].index, 3)
    game:slash("mail all")
    T.eq(#ns.Mailbox:Collectable(), 4)
  end)

  T.it("reserves free bag slots and Shift-click prefers an attachment", function()
    local game = mock.new()
    game.inbox = { { money = 100, items = { 2589 } } }
    local ns = game:loadAddon()
    game:login()
    game:fire("MAIL_SHOW")
    game:slash("mail free 16")
    game.shift = true
    ns.Mailbox.button.__scripts.OnClick(ns.Mailbox.button)
    T.eq(game.inbox[1].money, 0, "can collect gold without space")
    T.eq(game.inbox[1].items[1], 2589, "attachment remains due to slot reserve")
    game:slash("mail free 0")
    ns.Mailbox.button.__scripts.OnClick(ns.Mailbox.button)
    T.eq(game.inbox[1].items[1], nil, "Shift-click takes attachment with space")
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("mailbox extras", function()
  T.it("send-to lists your characters on this realm and recent recipients; a click fills To:", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    local realm = ns.db.key:match("%-(.+)$")
    ns.db.raw.chars["Lumen-" .. realm] = { meta = { class = "PRIEST" } }
    ns.db.raw.chars["Faraway-OtherRealm"] = { meta = { class = "MAGE" } }
    ns.Mailbox:Remember("Friendly")
    local names = {}
    for _, c in ipairs(ns.Mailbox:Contacts()) do names[#names + 1] = c.name end
    T.eq(table.concat(names, ","), "Lumen,Friendly")
    local box = game.base.CreateFrame("EditBox")
    rawset(game.env, "SendMailNameEditBox", box)
    T.ok(ns.Mailbox:FillTo("Lumen"))
    T.eq(box:GetText(), "Lumen")
  end)

  T.it("remembers expiring mail and warns at login", function()
    local game = mock.new()
    game.inbox = { { money = 500, days = 2 }, { items = { 2589 }, days = 20 } }
    local ns = game:loadAddon()
    game:login()
    game:fire("MAIL_SHOW")
    local e = ns.Mailbox:Expiring()
    T.eq(#e, 1)
    T.eq(e[1].n, 2)
    ns.Mailbox:WarnExpiring()
    T.contains(game:chatText(), "expires soon")
  end)
end)

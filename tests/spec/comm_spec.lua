-- Comm layer (P8-01) and version check (P8-02).
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("comm", function()
  T.it("sends nothing by default", function()
    local game = session({ inGuild = true })
    T.eq(game.sent, nil)
  end)

  T.it("a long message is chunked and reassembled on the other side", function()
    local game, ns = session()
    local big = {}
    for i = 1, 60 do big[i] = "item number " .. i end
    T.ok(ns.Comm:Send("RARE", { list = big }, "GUILD"))
    T.ok(#game.sent > 1)
    local g2, ns2 = session({ name = "Other" })
    local got
    ns2.Events:On("OTR_COMM", { name = "spec" }, function(_, kind, data, sender) got = { kind, data, sender } end)
    for _, m in ipairs(game.sent) do g2:fire("CHAT_MSG_ADDON", m.prefix, m.msg, "GUILD", "Torrant") end
    T.eq(got[1], "RARE")
    T.eq(got[2].list[60], "item number 60")
    T.eq(got[3], "Torrant")
  end)

  T.it("refuses CHANNEL/SAY, ignores own and unknown or newer messages", function()
    local game, ns = session()
    T.no(ns.Comm:Send("HELLO", {}, "CHANNEL"))
    local fired = 0
    ns.Events:On("OTR_COMM", { name = "spec" }, function() fired = fired + 1 end)
    game:fire("CHAT_MSG_ADDON", "Outrider", ns.Comm:Encode("HELLO", { version = "9.9" }), "GUILD", "Torrant")
    game:fire("CHAT_MSG_ADDON", "Outrider", "v1|EVIL|xx", "GUILD", "Bob")
    game:fire("CHAT_MSG_ADDON", "Outrider", "v9|HELLO|xx", "GUILD", "Bob")
    T.eq(fired, 0)
  end)

  T.it("version hello on: sends once at login, tells you once about a newer version", function()
    local game, ns = session({ inGuild = true })
    game:slash("share hello on")
    T.eq(game.sent[1].channel, "GUILD")
    game:fire("CHAT_MSG_ADDON", "Outrider", ns.Comm:Encode("HELLO", { version = "9.0.0" }), "GUILD", "Guildie")
    game:fire("CHAT_MSG_ADDON", "Outrider", ns.Comm:Encode("HELLO", { version = "9.1.0" }), "GUILD", "Guildie2")
    local _, n = game:chatText():gsub("has a newer Outrider", "")
    T.eq(n, 1)
    T.ok(ns.Comm.Newer("0.10.0", "0.2.0"))
    T.eq(#ns.Errors.list, 0)
  end)
end)

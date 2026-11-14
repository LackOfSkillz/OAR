-- Location sharing (P8-04): off by default, guild only, never from instances.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("location share", function()
  T.it("sends nothing until switched on, then a position every 30 s while moving", function()
    local game, ns = session({ inGuild = true, mapID = 1412, x = 0.5, y = 0.5 })
    game:advance(60)
    T.eq(game.sent, nil, "off by default")
    game:slash("share location on")
    T.eq(#game.sent, 1)
    T.eq(game.sent[1].channel, "GUILD")
    game:advance(31)
    T.eq(#game.sent, 1, "did not move: waits for the 2 minute keepalive")
    game.opts.x = 0.52
    game:advance(30)
    T.eq(#game.sent, 2)
    T.contains(game:chatText(), "Nothing is sent from dungeons")
    game:slash("share location off")
    T.eq(#game.sent, 3, "one 'gone' note")
    game:advance(120)
    T.eq(#game.sent, 3)
    T.eq(ns.Timer.Pending(), 0)
  end)

  T.it("a guildmate's dot shows on the map with class color and goes away on 'gone' or after 150 s", function()
    local game, ns = session({ inGuild = true, mapID = 1412, x = 0.5, y = 0.5 })
    game:slash("share location on")
    local g2, ns2 = session({ name = "Lumen", mapID = 1412 })
    g2:fire("CHAT_MSG_ADDON", "Outrider", game.sent[1].msg, "GUILD", "Torrant-Forever")
    local pin
    for _, p in ipairs(ns2.MapPins:PinsFor(1412)) do if p.kind == "guildmate" then pin = p end end
    T.eq(pin.name, "Torrant")
    T.same(pin.ringColor, { 0.67, 0.83, 0.45 })
    g2:fire("CHAT_MSG_ADDON", "Outrider", game.sent[1].msg, "WHISPER", "Torrant-Forever")
    g2.now = g2.now + 151
    local left = 0
    for _, p in ipairs(ns2.MapPins:PinsFor(1412)) do if p.kind == "guildmate" then left = left + 1 end end
    T.eq(left, 0, "expired")
    T.eq(#ns2.Errors.list, 0)
  end)

  T.it("never sends from an instance", function()
    local game, ns = session({ inGuild = true, inInstance = true })
    game:slash("share location on")
    T.eq(game.sent, nil)
  end)
end)

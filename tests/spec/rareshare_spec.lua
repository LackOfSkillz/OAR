-- Rare sightings sharing (P8-03).
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

local function seen(ns, extra, game)
  local info = { npcID = 5807, name = "The Rake", mapID = 1412, x = 0.4, y = 0.5, layer = 321, dead = false, t = game.now }
  for k, v in pairs(extra or {}) do info[k] = v end
  ns.Events:Fire("OTR_RARE_SEEN", info)
end

T.describe("rareshare", function()
  T.it("sends nothing until switched on, then once per rare per minute", function()
    local game, ns = session({ inGuild = true })
    seen(ns, nil, game)
    T.eq(game.sent, nil)
    game:slash("share rares guild on")
    seen(ns, nil, game) seen(ns, nil, game)
    T.eq(#game.sent, 1)
    T.eq(game.sent[1].channel, "GUILD")
    seen(ns, { layer = false, npcID = 99 }, game) -- instance: no layer, not shared
    T.eq(#game.sent, 1)
  end)

  T.it("receiver records the sighting and toasts watched rares with the layer", function()
    local game, ns = session({ inGuild = true })
    game:slash("share rares guild on")
    seen(ns, nil, game)
    local g2, ns2 = session({ name = "Lumen" })
    g2:slash("watch The Rake")
    ns2.Layers.current = 321
    g2:fire("CHAT_MSG_ADDON", "Outrider", game.sent[1].msg, "GUILD", "Torrant-Forever")
    local list = ns2.Sightings.db[5807]
    T.eq(list[#list].by, "Torrant-Forever")
    T.eq(list[#list].how, "guild")
    T.eq(ns2.Toast:Count(), 1)
    T.contains(ns2.Toast.visible[1].title:GetText(), "Torrant saw The Rake")
    T.contains(ns2.Toast.visible[1].text:GetText(), "your layer")
    T.eq(#ns2.Errors.list, 0)
  end)

  T.it("drops whispers and impossible data", function()
    local game, ns = session()
    local now = game.now
    T.eq(ns.RareShare.Reject({ npcID = 1, t = now + 3600, state = "alive" }, now), "time")
    T.eq(ns.RareShare.Reject({ npcID = 1, t = now, x = 3, y = 0.5, state = "alive" }, now), "coords")
    T.eq(ns.RareShare.Reject({ npcID = 1, t = now, state = "alive" }, now), nil)
    local before = ns.Sightings.db[7] and #ns.Sightings.db[7] or 0
    ns.Events:Fire("OTR_COMM", "RARE", { npcID = 7, t = now, state = "alive" }, "Bob", "WHISPER")
    T.eq(ns.Sightings.db[7] and #ns.Sightings.db[7] or 0, before)
  end)
end)

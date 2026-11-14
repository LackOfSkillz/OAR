-- Gathering and fishing sharing (P8-05).
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("gathershare", function()
  T.it("a node gathered by one player appears for the other", function()
    local game, ns = session({ inGuild = true })
    ns.LootLog:AddNode("herb", 1412, 0.5, 0.5, "Peacebloom")
    T.eq(game.sent, nil, "off by default")
    game:slash("share nodes on")
    ns.LootLog:AddNode("ore", 1412, 0.3, 0.3, "Copper Ore")
    ns.LootLog:AddNode("ore", 1412, 0.3, 0.3, "Copper Ore") -- same node again: not re-sent
    T.eq(#game.sent, 1)
    local g2, ns2 = session({ name = "Lumen" })
    g2:fire("CHAT_MSG_ADDON", "Outrider", game.sent[1].msg, "GUILD", "Torrant-Forever")
    local nodes = ns2.LootLog:NodesFor(1412)
    T.eq(#nodes, 1)
    T.eq(nodes[1].sharedBy, "Torrant-Forever")
    T.eq(nodes[1].name, "Copper Ore")
    g2:fire("CHAT_MSG_ADDON", "Outrider", game.sent[1].msg, "PARTY", "Bob")
    T.eq(#ns2.LootLog:NodesFor(1412), 1, "party is not accepted, and duplicates merge")
    T.eq(#ns2.Errors.list, 0)
  end)

  T.it("rate limit and bad data", function()
    local game, ns = session({ inGuild = true })
    game:slash("share nodes on")
    for i = 1, 10 do ns.LootLog:AddNode("herb", 1412, i / 20, 0.9, "Silverleaf") end
    T.eq(#game.sent, 6)
    T.eq(ns.GatherShare.Reject({ kind = "gold", mapID = 1, x = 0.1, y = 0.1 }), "kind")
    T.eq(ns.GatherShare.Reject({ kind = "fish", mapID = 1, x = 2, y = 0.1 }), "coords")
  end)
end)

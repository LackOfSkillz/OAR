-- Rares tab and watchlist (P2-05). IDs are test data.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game.units = {}
  return game, ns
end

T.describe("rares tab", function()
  T.it("lists rares seen in this zone with their window, and the hub tab order holds", function()
    local game, ns = session()
    game.units.target = { guid = "Creature-0-5250-0-777-7101-00000001", name = "Zone Rare", classification = "rare", level = 20 }
    game:fire("PLAYER_TARGET_CHANGED")
    game:slash("")
    ns.Hub.frame.tabBar:Select("rares")
    local p = ns.Hub.byId.rares.panel
    local items = p.list:VisibleItems()
    T.eq(#items, 1)
    T.eq(items[1].name, "Zone Rare")
    T.contains(p.list.rowFrames[1].text:GetText(), "alive, seen 0 min ago")
    T.same(ns.Hub.frame.tabBar.order, { "home", "whatnow", "journey", "map", "waypoints", "rares", "rarealerts", "dungeons", "class", "gear", "gearsets", "professions", "crafting", "macros", "money", "errands", "forecasts", "feed", "chat", "sharing", "settings", "modules", "characters", "advisor", "overview", "tools", "commands" })
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("other zones show only with All zones", function()
    local game, ns = session()
    ns.Data:Register("rare", "spec", { { npcID = 7102, name = "Far Rare", mapID = 9999, verified = false } })
    game:slash("")
    ns.Hub.frame.tabBar:Select("rares")
    local p = ns.Hub.byId.rares.panel
    T.eq(#p.list:VisibleItems(), 0)
    T.ok(p.empty:IsShown())
    ns.RaresTab.scope = "all"
    p:Refresh()
    T.eq(p.list:VisibleItems()[1].name, "Far Rare")
  end)

  T.it("the Watch button toggles the per-character watchlist", function()
    local game, ns = session()
    ns.Data:Register("rare", "spec", { { npcID = 7103, name = "Watch Me", mapID = 1412, verified = false } })
    game:slash("")
    ns.Hub.frame.tabBar:Select("rares")
    local row = ns.Hub.byId.rares.panel.list.rowFrames[1]
    row.watch.__scripts.OnClick(row.watch)
    T.ok(ns.Modules:Get("RareScan"):IsWatched(7103))
    T.eq(row.watch.label:GetText(), "Watching")
  end)
end)

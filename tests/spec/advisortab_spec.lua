-- Advisor tab and /ride ask (P9-02). Advice is a hand-written test file.
local T, mock = ...

local function session(withAdvice)
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  local snap = ns.Snapshot:Collect()
  if withAdvice then
    game.env.Outrider_Advice = { schema = 1, forCharacter = ns.db.key, answersSnapshot = snap.takenAt, items = {
      { title = "Hunt Mystmane", why = "Its window is open", action = "waypoint", confidence = "verified",
        args = { mapID = 1412, x = 0.6, y = 0.34 } },
      { title = "Track The Hunt Begins", why = "Close to done", action = "track_quest", confidence = "inferred", args = { questID = 747 } },
      { title = "Look at gear", why = "Two upgrades nearby", action = "open_panel", confidence = "inferred", args = { panel = "gear" } },
      { title = "See the bow", why = "Best ranged pick", action = "show_item", confidence = "community", args = { itemID = 2504 } },
      { title = "Cast something", why = "never allowed", action = "cast", args = { spell = "Fireball" } },
    } }
  end
  return game, ns
end

T.describe("advisor tab", function()
  T.it("lists only whitelisted advice and each button does its harmless action", function()
    local game, ns = session(true)
    game.env.C_QuestLog.AddQuestWatch = function(id) game.watched = id end
    game.env.ItemRefTooltip = game.env.CreateFrame("GameTooltip", "ItemRefTooltip", game.env.UIParent)
    local items = ns.Advisor:Items()
    T.eq(#items, 4, "the cast item is dropped")
    T.ok(ns.Advisor:Perform(items[1]))
    T.eq(ns.Waypoints.current.title, "Hunt Mystmane")
    ns.Advisor:Perform(items[2])
    T.eq(game.watched, 747)
    ns.Advisor:Perform(items[3])
    T.eq(ns.Hub.current, "gear")
    T.ok((ns.Advisor:Perform(items[4])))
    T.no((ns.Advisor:Perform({ action = "cast", args = {} })))
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("explains why there is no advice; /ride ask snapshots and reloads, never in combat", function()
    local game, ns = session(false)
    ns.Hub:Build():Show()
    ns.Hub:ShowTab("advisor")
    T.contains(ns.Hub.byId.advisor.panel.head:GetText(), "No advice yet")
    game.combat = true
    game:slash("ask reload")
    T.eq(game.reloads, 0)
    game.combat = false
    game:slash("ask reload")
    T.eq(game.reloads, 1)
  end)
end)

T.describe("advisor across reloads", function()
  T.it("advice stays valid after the logout snapshot, and goes stale after a new /ride ask", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    local asked = ns.Snapshot:Collect(true)
    game.env.Outrider_Advice = { schema = 1, forCharacter = ns.db.key, answersSnapshot = asked.askedAt, items = {
      { title = "Look at gear", action = "open_panel", args = { panel = "gear" } } } }
    game.now = game.now + 30
    local logout = ns.Snapshot:Collect() -- what PLAYER_LOGOUT does on /reload
    T.ok(logout.takenAt > asked.takenAt)
    T.eq(logout.askedAt, asked.askedAt)
    local items, why = ns.Advice:Load()
    T.eq(#items, 1, tostring(why))
    game.now = game.now + 30
    ns.Snapshot:Collect(true)
    local _, why2 = ns.Advice:Load()
    T.eq(why2, "advice is stale")
  end)
end)

T.describe("advisor ask flow", function()
  T.it("the logout right after /ride ask keeps the asked snapshot; a hint shows after the reload", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    game:slash("ask reload")
    local asked = game.env.Outrider_Snapshots[ns.db.key]
    game.now = game.now + 2
    game:fire("PLAYER_LOGOUT")
    T.eq(game.env.Outrider_Snapshots[ns.db.key], asked, "not overwritten by the logout snapshot")
    game:fire("PLAYER_ENTERING_WORLD", false, true)
    T.contains(game:chatText(), "Ask Claude for advice")
  end)

  T.it("old snapshots without askedAt accept advice for a recent logout refresh", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    game.env.Outrider_Snapshots = { [ns.db.key] = { takenAt = 1000 + 60 } }
    game.env.Outrider_Advice = { schema = 1, forCharacter = ns.db.key, answersSnapshot = 1000, items = {
      { title = "x", action = "open_panel", args = { panel = "gear" } } } }
    local items = ns.Advice:Load()
    T.eq(#items, 1)
    game.env.Outrider_Snapshots[ns.db.key].takenAt = 1000 + 7 * 3600
    local _, why = ns.Advice:Load()
    T.eq(why, "advice is stale")
  end)
end)

T.describe("advisor without reload", function()
  T.it("/ride ask shows a snapshot code; a pasted advice code shows at once, no reload", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    game:slash("ask")
    T.eq(game.reloads, 0, "no reload")
    local code = ns.UI.dialog.edit:GetText()
    local back = ns.Serialize.Import(code)
    T.eq(back.kind, "snapshot")
    T.eq(back.character, ns.db.key)
    local advice = { kind = "advice", schema = 1, forCharacter = ns.db.key, answersSnapshot = back.snapshot.askedAt,
      items = { { title = "Look at gear", why = "x", action = "open_panel", args = { panel = "gear" } },
                { title = "Cast", action = "cast", args = {} } } }
    local n, why = ns.Advice:Paste(ns.Serialize.Export(advice))
    T.eq(n, 1, tostring(why))
    T.eq(#(ns.Advice:Load()), 1)
    T.eq(select(2, ns.Advice:Paste("garbage")), "not an Outrider export string")
    advice.kind = "snapshot"
    T.eq(select(2, ns.Advice:Paste(ns.Serialize.Export(advice))), "that code is not advice")
    T.eq(#ns.Errors.list, 0)
  end)
end)

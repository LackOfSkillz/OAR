-- Phase 9 groundwork: snapshot shape and the advice whitelist.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("snapshot", function()
  T.it("collects plain data for the current character", function()
    local game, ns = session()
    game:slash("snap")
    local s = game.env.OAR_Snapshots["Torrant-Forever"]
    T.eq(s.schema, 1)
    T.eq(s.class, "HUNTER")
    T.eq(s.where.mapID, 1412)
    T.eq(s.gear[18], 2504)
    T.ok(s.modules.Welcome, "modules contribute")
    T.eq(game.reloads, 0, "snap never reloads by itself")
    T.contains(game:logout(), "OAR_Snapshots")
  end)
end)

T.describe("advice loader", function()
  local function withAdvice(advice)
    local game, ns = session()
    ns.Snapshot:Collect()
    local taken = game.env.OAR_Snapshots["Torrant-Forever"].takenAt
    game.env.OAR_Advice = advice(taken)
    return ns.Advice:Load()
  end

  T.it("keeps whitelisted, well-formed items", function()
    local items, why = withAdvice(function(taken)
      return { schema = 1, forCharacter = "Torrant-Forever", answersSnapshot = taken, items = {
        { title = "Go tame The Rake", why = "best early cat", action = "waypoint", args = { mapID = 1412, x = 0.5, y = 0.4 } },
        { title = "Cast spells for me", action = "cast", args = { spell = "Tame Beast" } },
        { title = "Bad coords", action = "waypoint", args = { mapID = 1412, x = 5, y = 0.4 } },
        { title = 42, action = "show_item", args = { itemID = 1 } },
        { title = "Look at this bow", action = "show_item", args = { itemID = 2504, extra = "dropped" } },
      } }
    end)
    T.eq(why, "ok")
    T.eq(#items, 2)
    T.eq(items[1].action, "waypoint")
    T.eq(items[2].args.extra, nil, "unknown args dropped")
  end)

  T.it("ignores advice for another character or an old snapshot", function()
    local items, why = withAdvice(function(taken)
      return { schema = 1, forCharacter = "Someone-Else", answersSnapshot = taken, items = { { title = "x", action = "show_item", args = { itemID = 1 } } } }
    end)
    T.eq(#items, 0)
    T.contains(why, "another character")
    items, why = withAdvice(function(taken)
      return { schema = 1, forCharacter = "Torrant-Forever", answersSnapshot = taken - 1, items = {} }
    end)
    T.eq(#items, 0)
    T.contains(why, "stale")
  end)

  T.it("the shipped Advice.lua is empty", function()
    local _, ns = session()
    local items, why = ns.Advice:Load()
    T.eq(#items, 0)
    T.eq(why, "no advice file")
  end)
end)

T.describe("data registry", function()
  T.it("accepts valid entries and reports bad ones", function()
    local _, ns = session()
    local n, errs = ns.Data:Register("rare", "test", {
      { npcID = 1, name = "Good", mapID = 1412, verified = false },
      { npcID = "2", name = "Bad id", mapID = 1412, verified = false },
      { npcID = 3, name = "Bad xy", mapID = 1412, x = 2, y = 0.5, verified = false },
    })
    T.eq(n, 1)
    T.eq(#errs, 2)
    T.eq(ns.Data:Get("rare", 1).name, "Good")
  end)

  T.it("rejects macros over 255 characters", function()
    local _, ns = session()
    local n = ns.Data:Register("macro", "test", {
      { id = "long", name = "Long", class = "ALL", body = string.rep("x", 256), verified = false },
    })
    T.eq(n, 0)
  end)
end)

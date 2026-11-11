-- Fixes from the external review: migration safety, resets, combat queue, advice validation.
local T, mock = ...

local function session(opts, define)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  if define then define(ns) end
  game:login()
  return game, ns
end

T.describe("schema safety", function()
  local saved = 'OAR_DB = { schema = 99, global = { loads = 7, keep = "me" }, chars = {} }\n'

  T.it("a file from a newer OAR is left untouched (safe mode)", function()
    local game, ns = session({ savedVariables = saved })
    T.ok(ns.DB.safeMode, "safe mode on")
    T.contains(ns.DB:SavedVariablesStatus(), "SAFE MODE")
    T.contains(game:chatText(), "safe mode")
    ns.db.global.debug = true                 -- writes go to the temporary DB
    local text = game:logout()
    T.contains(text, '["keep"] = "me"')
    T.contains(text, '["loads"] = 7', "loads counter not bumped on disk")
    T.contains(text, '["schema"] = 99')
    T.no(text:find('["debug"] = true', 1, true), "temporary settings not saved")
  end)

  T.it("a failing migration step does not damage the original", function()
    local old = 'OAR_DB = { schema = 0, global = { loads = 3, keep = "me" }, chars = {} }\n'
    local game = mock.new({ savedVariables = old })
    local ns = game:loadAddon()
    ns.DB.migrations[0] = function(db) db.global.keep = "half-done" error("boom") end
    game:login()
    T.ok(ns.DB.safeMode)
    T.contains(ns.DB.safeMode, "boom")
    local text = game:logout()
    T.contains(text, '["keep"] = "me"', "original survived the half-run step")
  end)

  T.it("a missing migration step is refused, not skipped", function()
    local old = 'OAR_DB = { schema = 0, global = {}, chars = {} }\n'
    local _, ns = session({ savedVariables = old })
    T.contains(ns.DB.safeMode or "", "no migration from schema 0")
  end)

  T.it("a working migration upgrades and saves", function()
    local old = 'OAR_DB = { schema = 0, global = { oldName = 5 }, chars = {} }\n'
    local game = mock.new({ savedVariables = old })
    local ns = game:loadAddon()
    ns.DB.migrations[0] = function(db) db.global.newName = db.global.oldName db.global.oldName = nil end
    game:login()
    T.no(ns.DB.safeMode)
    T.eq(ns.db.global.newName, 5)
    T.contains(game:logout(), '["schema"] = 1')
  end)
end)

T.describe("resets", function()
  T.it("reset char rebinds the live settings immediately", function()
    local game, ns = session()
    ns.db.char.hub.x = 500
    local before = ns.db.char
    game:slash("reset char confirm")
    T.eq(game.reloads, 1)
    T.ok(ns.db.char ~= before, "live table replaced")
    T.eq(ns.db.char.hub.x, 0)
    T.eq(ns.db.raw.chars[ns.db.key], ns.db.char)
  end)

  T.it("reset all writes nothing back", function()
    local game = mock.new()
    game:loadAddon()
    game:login()
    game:slash("reset all confirm")
    T.no(game:logout():find("OAR_DB", 1, true))
  end)
end)

T.describe("combat queue", function()
  T.it("a toggle queued in combat applies the latest wanted state", function()
    local game, ns = session({}, function(ns)
      local m = ns:NewModule("Flip", {})
      function m:OnEnable() self.on = true end
      function m:OnDisable() self.on = false end
    end)
    game:setCombat(true)
    ns.Modules:SetEnabled("Flip", false)
    ns.DB:ModuleState("Flip").enabled = true   -- e.g. a profile import before combat ends
    game:setCombat(false)
    T.ok(ns.Modules:Get("Flip").on, "re-read state wins over the captured one")
  end)

  T.it("is capped and jobs can be cancelled", function()
    local game, ns = session()
    game:setCombat(true)
    for i = 1, ns.Combat.MAX + 20 do ns.Combat:Run("job" .. i, function() end) end
    T.eq(ns.Combat:Pending(), ns.Combat.MAX)
    local ran = false
    ns.Combat:Run("cancel me", function() ran = true end, "k1")
    T.ok(ns.Combat:Cancel("k1"))
    game:setCombat(false)
    T.no(ran)
  end)
end)

T.describe("advice validation", function()
  local function load(items)
    local game, ns = session()
    ns.Snapshot:Collect()
    local taken = game.env.OAR_Snapshots["Torrant-Forever"].takenAt
    game.env.OAR_Advice = { schema = 1, forCharacter = "Torrant-Forever", answersSnapshot = taken, items = items }
    return (ns.Advice:Load())
  end

  T.it("rejects fractional, huge or NaN numbers and unknown panels", function()
    local items = load({
      { title = "frac id", action = "show_item", args = { itemID = 2.5 } },
      { title = "huge id", action = "show_item", args = { itemID = 2 ^ 40 } },
      { title = "nan x", action = "waypoint", args = { mapID = 1412, x = 0 / 0, y = 0.5 } },
      { title = "bad panel", action = "open_panel", args = { panel = "SpellBookFrame" } },
      { title = "good panel", action = "open_panel", args = { panel = "rares" } },
    })
    T.eq(#items, 1)
    T.eq(items[1].args.panel, "rares")
  end)

  T.it("strips UI escape codes and defaults confidence to unknown", function()
    local items = load({
      { title = "|cffff0000Click|r |Hitem:1|h[me]|h", why = "a\nb", action = "show_item", args = { itemID = 1 } },
      { title = "sure thing", action = "show_item", args = { itemID = 2 }, confidence = "verified" },
      { title = "made up", action = "show_item", args = { itemID = 3 }, confidence = "trust me" },
    })
    T.no(items[1].title:find("|", 1, true), "no escape sequences left")
    T.eq(items[1].confidence, "unknown")
    T.eq(items[2].confidence, "verified")
    T.eq(items[3].confidence, "unknown")
  end)
end)

T.describe("data provenance", function()
  T.it("checks the confidence field", function()
    local _, ns = session()
    local n, errs = ns.Data:Register("rare", "prov", {
      { npcID = 10, name = "A", mapID = 1, verified = false, confidence = "community" },
      { npcID = 11, name = "B", mapID = 1, verified = false, confidence = "pinky promise" },
      { npcID = 12, name = "C", mapID = 1, verified = true, confidence = "inferred" },
    })
    T.eq(n, 1)
    T.eq(#errs, 2)
  end)
end)

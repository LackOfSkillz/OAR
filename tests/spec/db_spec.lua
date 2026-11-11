-- SavedVariables: survive a "restart", stay separate per character.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("db", function()
  T.it("first load cannot know yet whether settings read back", function()
    local _, ns = session()
    local sv, loads = ns.DB:SavedVariablesStatus()
    T.eq(loads, 1)
    T.contains(sv, "unknown")
  end)

  T.it("settings survive logout and the next load (gate G1 at unit level)", function()
    local g1, ns1 = session()
    ns1.db.char.modules.Welcome.settings.custom = "kept"
    ns1.db.global.debug = true
    local saved = g1:logout()

    local _, ns2 = session({ savedVariables = saved })
    T.eq(ns2.db.global.loads, 2)
    T.eq(ns2.DB:SavedVariablesStatus(), "yes")
    T.eq(ns2.db.char.modules.Welcome.settings.custom, "kept")
    T.eq(ns2.db.global.debug, true)
    T.eq(ns2.db.char.meta.logins, 2)
  end)

  T.it("keeps characters separate and knows their class", function()
    local g1, ns1 = session({ name = "Torrant", class = "HUNTER" })
    ns1.db.char.hub.x = 111
    local saved = g1:logout()
    local g2, ns2 = session({ savedVariables = saved, name = "Lumen", class = "PRIEST", race = "Undead" })
    T.eq(ns2.db.key, "Lumen-Forever")
    T.eq(ns2.db.char.hub.x, 0, "priest gets its own defaults")
    T.eq(ns2.db.char.meta.class, "PRIEST")
    T.eq(ns2.db.raw.chars["Torrant-Forever"].hub.x, 111, "hunter untouched")
    local chars = ns2.DB:Characters()
    T.eq(#chars, 2)
    T.ok(g2)
  end)

  T.it("survives a damaged SavedVariables file", function()
    local _, ns = session({ savedVariables = 'Outrider_DB = { global = "oops", chars = 5 }\nOutrider_Log = 7\n' })
    T.eq(type(ns.db.global), "table")
    T.eq(type(ns.db.char), "table")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("records lastSave at logout and trims session history", function()
    local saved
    for _ = 1, 20 do
      local g, ns = session({ savedVariables = saved })
      T.ok(ns)
      saved = g:logout()
    end
    local _, ns = session({ savedVariables = saved })
    T.ok(#ns.db.global.sessions <= ns.DB.MAX_SESSIONS, "session list trimmed")
    T.ok(ns.DB.previousSave and ns.DB.previousSave.session, "lastSave carried over")
  end)
end)

local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("profiles", function()
  T.it("exports on one character and imports on another", function()
    local g1, ns1 = session({ name = "Torrant", class = "HUNTER" })
    ns1.db.char.modules.Welcome.settings.custom = 42
    ns1.db.char.hub.x = 300
    local s = ns1.Profiles:Export()
    local saved = g1:logout()

    local _, ns2 = session({ savedVariables = saved, name = "Ember", class = "MAGE" })
    local ok, err = ns2.Profiles:Import(s)
    T.ok(ok, err)
    T.eq(ns2.db.char.modules.Welcome.settings.custom, 42)
    T.eq(ns2.db.char.hub.x, 300)
    T.eq(ns2.db.char.meta.class, "MAGE", "metadata is never copied")
  end)

  T.it("copies from another saved character", function()
    local g1, ns1 = session({ name = "Torrant" })
    ns1.db.char.hub.y = -50
    local saved = g1:logout()
    local _, ns2 = session({ savedVariables = saved, name = "Lumen", class = "PRIEST" })
    T.ok(ns2.Profiles:CopyFrom("Torrant-Forever"))
    T.eq(ns2.db.char.hub.y, -50)
    local ok = ns2.Profiles:CopyFrom("Lumen-Forever")
    T.no(ok, "copying onto yourself is refused")
  end)

  T.it("refuses strings that are not OAR profiles", function()
    local _, ns = session()
    local wrongKind = ns.Serialize.Export({ kind = "something-else", v = 1, data = {} })
    T.no((ns.Profiles:Import(wrongKind)))
    local newer = ns.Serialize.Export({ kind = "oar-profile", v = 99, data = {} })
    T.no((ns.Profiles:Import(newer)))
    local sneaky = ns.Serialize.Export({ kind = "oar-profile", v = 1, data = { meta = { class = "WARRIOR" } } })
    T.no((ns.Profiles:Import(sneaky)), "unexpected fields refused")
    T.no((ns.Profiles:Import("garbage")))
  end)
end)

-- Macro library and installer (P4-03, P4-04). Spellbook data is the mock's.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  return game, ns, ns.MacroLibrary
end

local function entry(ns, id)
  for _, e in ipairs(ns.Data:All("macro")) do if e.id == id then return e end end
end

T.describe("macro library", function()
  T.it("lists hunter + general macros with states from the spellbook and level", function()
    local game, ns, L = session()
    local names = {}
    for _, e in ipairs(L:Entries()) do names[e.id] = L:State(e) end
    T.eq(names["hunter-autoshot"], "ready")
    T.eq(names["hunter-aimed-multi"], "needs Aimed Shot")
    T.ok(names["all-mount"] ~= nil, "general macros show for every class")
  end)

  T.it("installs a per-character macro, tracks it, and shows installed", function()
    local game, ns, L = session()
    local e = entry(ns, "hunter-autoshot")
    T.ok(L:Install(e))
    T.eq(game.macros[1].name, "AutoShot")
    T.ok(game.macros[1].perChar)
    T.eq(L:State(e), "installed")
  end)

  T.it("never overwrites a macro Gary made with the same name", function()
    local game, ns, L = session({ macros = { { name = "AutoShot", icon = 1, body = "/say mine", perChar = true } } })
    local ok, msg = L:Install(entry(ns, "hunter-autoshot"))
    T.no(ok)
    T.contains(msg, "didn't make")
    T.eq(game.macros[1].body, "/say mine")
  end)

  T.it("refuses in combat and when slots are full", function()
    local game, ns, L = session()
    game.combat = true
    T.no(L:Install(entry(ns, "hunter-autoshot")))
    game.combat = false
    for i = 1, 18 do game.macros[i] = { name = "m" .. i, body = "", perChar = true } end
    local ok, msg = L:Install(entry(ns, "hunter-autoshot"))
    T.no(ok)
    T.contains(msg, "no free character macro slot")
  end)

  T.it("the tame macro fills its target from the watchlist; Remove deletes only ours", function()
    local game, ns, L = session()
    game:slash("watch Mystmane")
    local e = entry(ns, "hunter-tame-rare")
    T.eq(L:State(e), "ready")
    T.ok(L:Install(e))
    T.contains(game.macros[1].body, "/targetexact Mystmane")
    T.ok(L:Remove(e))
    T.eq(#game.macros, 0)
  end)

  T.it("the Macros tab shows the list and installs on click", function()
    local game, ns = session()
    game:slash("")
    ns.Hub.frame.tabBar:Select("macros")
    local p = ns.Hub.byId.macros.panel
    p:ShowEntry(entry(ns, "hunter-autoshot"))
    T.contains(p.detail.explain:GetText(), "Cast Auto Shot (a second press won't stop it)")
    p.detail.install.__scripts.OnClick(p.detail.install)
    T.eq(game.macros[1].name, "AutoShot")
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("macro export and import", function()
  T.it("round trip: export on one hunter, import on another, text filled locally", function()
    local game, ns, L = session()
    T.ok(L:Install(entry(ns, "hunter-autoshot")))
    local s = L:Export()
    T.contains(s, "OTR1:")
    local g2 = mock.new({ name = "Alt", savedVariables = game:logout() })
    local ns2 = g2:loadAddon()
    g2:login()
    local n, skipped = ns2.MacroLibrary:Import(s)
    T.eq(n, 1)
    T.eq(#skipped, 0)
    T.eq(g2.macros[#g2.macros].name, "AutoShot")
  end)

  T.it("a priest importing hunter macros skips them; broken strings are refused", function()
    local game, ns, L = session()
    L:Install(entry(ns, "hunter-autoshot"))
    local s = L:Export()
    local g2 = mock.new({ name = "Zeil", class = "PRIEST" })
    local ns2 = g2:loadAddon()
    g2:login()
    local n, skipped = ns2.MacroLibrary:Import(s)
    T.eq(n, 0)
    T.contains(skipped[1], "not for this class")
    T.no(ns2.MacroLibrary:Import(s:sub(1, #s - 5)))
  end)
end)

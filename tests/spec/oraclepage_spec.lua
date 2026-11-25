-- OI05-17 Oracle and Forge on the Gear page; Hub section registry fix.
local T, mock = ...

local function session()
  local game = mock.new({ level = 20, class = "HUNTER" })
  local ns = game:loadAddon()
  game:login()
  game.money = 50000
  return game, ns, ns.OraclePage
end

T.describe("What if? on the Gear page (OI05-17)", function()
  T.it("both Gear page sections are registered by key (the old AddSection alias no longer hides them)", function()
    local _, ns = session()
    T.ok(ns.Nearby.Section("worth") and ns.Nearby.Section("worth").cards)
    T.ok(ns.Nearby.Section("whatif") and ns.Nearby.Section("whatif").cards)
    local t = ns.Hub:AddSection("Legacy", function() end)
    T.eq(t.id, "legacy", "the old (title, build) shape still adds a tab")
  end)

  T.it("cards give a plain summary first, then the detail; every button has a tooltip", function()
    local _, ns, P = session()
    ns.Modes.Set("advanced")
    local cards = P.Cards()
    T.eq(cards[1].title, "Your damage estimate")
    T.ok(cards[1].line:find("Not modelled"), "advanced: the detail (OI07-01)")
    ns.Modes.Set("beginner")
    T.ok(not P.Cards()[1].line:find("Not modelled"), "beginner: the plain line only")
    ns.Modes.Set("advanced")
    T.ok(cards[2].line:find("Save how you are now"))
    for _, c in ipairs(cards) do for _, a in ipairs(c.actions) do T.ok(type(a[3]) == "string" and #a[3] > 0, a[1]) end end
  end)

  T.it("trying an upgrade compares copies and leaves the live character untouched", function()
    local _, ns, P = session()
    ns.GearROI.Mine = function() return { { itemID = 1234, slot = 16, name = "Bow", price = 20000 } } end
    ns.GearScore.Compare = function(_, link) if link == "item:1234" then return { pct = 8 } end end
    local S = ns.Scenario
    local before = S.Hash(S.Base())
    P.Save()
    T.ok(P.TryTop())
    local short, detail = P.CompareLines(P.Compare())
    T.ok(short:find("costs") and short:find("gear slot 16"), short)
    T.ok(#detail > 0)
    T.eq(S.Hash(S.Base()), before, "nothing equipped or spent")
  end)

  T.it("a stale saved copy says so and offers Refresh; Reset forgets it", function()
    local game, ns, P = session()
    ns.GearROI.Mine = function() return { { itemID = 1234, slot = 16, name = "Bow" } } end
    P.Save() P.TryTop()
    game.money = 10
    local cards = P.Cards()
    T.ok(cards[2].line:find("changed since saving"), cards[2].line)
    local labels = {}
    for _, a in ipairs(cards[2].actions) do labels[a[1]] = true end
    T.ok(labels.Refresh)
    P.Reset()
    T.ok(P.Cards()[2].line:find("Save how you are now"))
  end)

  T.it("no upgrade to try, combat and the export all fail soft", function()
    local game, ns, P = session()
    ns.GearROI.Mine = function() return {} end
    T.eq(select(2, P.TryTop()), "no upgrade to try")
    T.eq(P.ForgeLines(nil), "Not while you're in combat.")
    T.ok(P.ExportText():find("forge%-1"))
    game.combat = true
    T.ok(P.Cards()[1].line:find("combat"))
    T.eq(#ns.Errors.list, 0)
  end)
end)

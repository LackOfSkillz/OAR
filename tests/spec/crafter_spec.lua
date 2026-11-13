-- One-press profession macros (Cook / Brew / Herb). Recipe data is test data.
local T, mock = ...

local function session(prof, opts)
  local game = mock.new(opts)
  game.prof = prof
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game:advance(3)
  game.tradeOpen = true -- window already open (the opening press has its own test)
  return game, ns
end

local function cooking()
  return { name = "Cooking", skill = 30, max = 75, line = 777, recipes = {
    [101] = { name = "Charred Wolf Meat", diff = 3, have = 6, reagents = { [1] = 1 } },
    [102] = { name = "Roasted Boar Meat", diff = 1, have = 2, reagents = { [2] = 1 } },
    [103] = { name = "Spiced Wolf Meat", diff = 0, have = 0, reagents = { [1] = 1, [3] = 1 } },
  } }
end

local function macro(game, name)
  for _, m in ipairs(game.macros) do if m.name == name then return m end end
end

local function said(game, text)
  for _, l in ipairs(game.chat) do if l:find(text, 1, true) then return true end end
end

T.describe("crafter", function()
  T.it("/ride make creates a macro only for professions the character has", function()
    local game, ns = session(cooking())
    game:slash("make")
    local m = macro(game, "Cook")
    T.ok(m and m.perChar, "Cook macro, per character")
    T.eq(m.body, "#showtooltip Cooking\n/ride make Cooking")
    T.eq(macro(game, "Brew"), nil)
    T.eq(ns.MacroEngine.Errors(m.body), 0)
    local listed
    for _, e in ipairs(ns.MacroLibrary:Entries()) do if e.name == "Cook" then listed = true end end
    T.ok(listed, "listed in the Macros tab")
  end)

  T.it("first press opens the window, next press makes the best skill-up recipe you have everything for", function()
    local game, ns = session(cooking())
    game.tradeOpen = false
    T.eq(ns.Crafter:Make("Cooking"), "opened", "first press opens the window")
    T.ok(said(game, "Cooking window opened: press again to make"))
    T.eq(ns.Crafter:Make("Cooking"), "made")
    T.eq(#game.crafted, 1)
    T.eq(game.crafted[1].id, 102, "yellow Roasted Boar beats grey Charred Wolf; orange Spiced Wolf has no spice")
    T.eq(game.crafted[1].n, 2, "all you can make, like Create All")
    T.ok(said(game, "making 2 x Roasted Boar Meat"))
  end)

  T.it("when the window can't load at once, the press only opens it", function()
    local game, ns = session(cooking(), { })
    game.noAutoOpen = true
    game.tradeOpen = false
    T.eq(ns.Crafter:Make("Cooking"), "opened")
    T.eq(game.crafted, nil)
    game.tradeOpen = true
    T.eq(ns.Crafter:Make("Cooking"), "made")
  end)

  T.it("grey recipes are made when nothing better is possible", function()
    local p = cooking()
    p.recipes[102].have = 0
    local game, ns = session(p)
    ns.Crafter:Make("Cooking")
    T.eq(game.crafted[1].id, 101)
  end)

  T.it("does nothing while casting, in combat, or with nothing to make; logs refusals", function()
    local p = cooking()
    for _, r in pairs(p.recipes) do r.have = 0 end
    local game, ns = session(p)
    T.eq(ns.Crafter:Make("Cooking"), "nothing")
    T.ok(said(game, "Cooking: nothing to make yet. Spiced Wolf Meat needs"))
    game.casting = "Roasted Boar Meat"
    T.eq(ns.Crafter:Make("Cooking"), "busy")
    game.casting = nil
    game:setCombat(true)
    T.eq(ns.Crafter:Make("Cooking"), "combat")
    game:setCombat(false)
    p.recipes[102].have = 1
    ns.Crafter:Make("Cooking")
    game:fire("UI_ERROR_MESSAGE", 50, "Requires Cooking Fire")
    local found
    for _, l in ipairs(ns.Log:Tail(10)) do
      if ns.Log:FormatLine(l):find("make Cooking refused: Requires Cooking Fire (Roasted Boar Meat)", 1, true) then found = true end
    end
    T.ok(found, "refusal logged")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("Cooking missing from GetProfessions still gets its macro once its window was opened", function()
    local game, ns = session(cooking())
    game.prof = nil -- GetProfessions now lists nothing
    ns.db.char.professions = { Cooking = { skill = 6, max = 75, line = 777, recipes = { [1] = {} } } }
    game:slash("make")
    T.ok(macro(game, "Cook"), "Cook made from the recorded profession")
  end)

  T.it("says which reagent is missing for the closest recipe", function()
    local p = { name = "Alchemy", skill = 1, max = 75, line = 171, recipes = {
      [201] = { name = "Minor Healing Potion", diff = 0, have = 0, reagents = { [10] = 1, [11] = 1 } } } }
    local game, ns = session(p)
    game.items = { [10] = { name = "Peacebloom" }, [11] = { name = "Empty Vial" } }
    game.counts = { [10] = 3 }
    T.eq(ns.Crafter:Make("Alchemy"), "nothing")
    T.ok(said(game, "Minor Healing Potion needs Empty Vial x1 (you have 0)"))
  end)

  T.it("a profession that only gathers says so", function()
    local game, ns = session({ name = "Herbalism", skill = 4, max = 75, line = 778, recipes = {
      [301] = { name = "Peacebloom", gather = true, reagents = {} } } })
    T.eq(ns.Crafter:Make("Herbalism"), "nothing")
    T.ok(said(game, "Herbalism has no recipes to make (it only gathers)"))
  end)

  T.it("a profession with no recipes says so", function()
    local game, ns = session({ name = "Herbalism", skill = 4, max = 75, line = 778, recipes = {} })
    game:slash("make")
    T.ok(macro(game, "Herb"))
    T.eq(ns.Crafter:Make("Herbalism"), "nothing")
    T.ok(said(game, "Herbalism has no recipes to make"))
  end)
end)

T.describe("crafter herb button", function()
  T.it("Herb turns on Find Herbs, and an old Herb macro Outrider made is updated at login", function()
    local game = mock.new({ macros = { { name = "Herb", icon = "x", body = "#showtooltip Herbalism\n/ride make Herbalism", perChar = true } } })
    game.prof = { name = "Herbalism", skill = 4, max = 75, line = 778, recipes = {} }
    local ns = game:loadAddon()
    game:login()
    ns.MacroLibrary:Settings().installed.Herb = { id = "craft-herbalism", body = "#showtooltip Herbalism\n/ride make Herbalism", t = 0 }
    game:fire("PLAYER_ENTERING_WORLD", false, true)
    game:advance(1)
    T.eq(game.macros[1].body, "#showtooltip Find Herbs\n/cast !Find Herbs")
  end)

  T.it("leaves a Herb macro Gary edited alone", function()
    local game = mock.new({ macros = { { name = "Herb", icon = "x", body = "/cast Find Herbs\n/say hi", perChar = true } } })
    game.prof = { name = "Herbalism", skill = 4, max = 75, line = 778, recipes = {} }
    local ns = game:loadAddon()
    game:login()
    ns.MacroLibrary:Settings().installed.Herb = { id = "craft-herbalism", body = "#showtooltip Herbalism\n/ride make Herbalism", t = 0 }
    game:fire("PLAYER_ENTERING_WORLD", false, true)
    game:advance(1)
    T.eq(game.macros[1].body, "/cast Find Herbs\n/say hi")
  end)
end)

T.describe("macro text compare", function()
  T.it("a trailing newline or CR from the game still counts as the same text", function()
    local game = mock.new()
    local ns = game:loadAddon()
    T.ok(ns.MacroEngine.Same("a\nb", "a\r\nb\n"))
    T.ok(not ns.MacroEngine.Same("a\nb", "a\nc"))
  end)
end)

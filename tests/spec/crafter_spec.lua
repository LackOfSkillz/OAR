-- One-press profession macros (Cook / Brew / Herb). Recipe data is test data.
local T, mock = ...

local function session(prof, opts)
  local game = mock.new(opts)
  game.prof = prof
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game:advance(3)
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
    T.eq(ns.Crafter:Make("Cooking"), "made", "OpenTradeSkill is immediate here")
    T.eq(#game.crafted, 1)
    T.eq(game.crafted[1].id, 102, "yellow Roasted Boar beats grey Charred Wolf; orange Spiced Wolf has no spice")
    T.eq(game.crafted[1].n, 2, "all you can make, like Create All")
    T.ok(said(game, "making 2 x Roasted Boar Meat"))
  end)

  T.it("when the window can't load at once, the press only opens it", function()
    local game, ns = session(cooking(), { })
    game.noAutoOpen = true
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
    T.ok(said(game, "nothing you have every ingredient for"))
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

  T.it("a profession with no recipes says so", function()
    local game, ns = session({ name = "Herbalism", skill = 4, max = 75, line = 778, recipes = {} })
    game:slash("make")
    T.ok(macro(game, "Herb"))
    T.eq(ns.Crafter:Make("Herbalism"), "nothing")
    T.ok(said(game, "Herbalism has no recipes to make"))
  end)
end)

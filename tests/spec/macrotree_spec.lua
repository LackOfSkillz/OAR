-- The Macros page as a skill tree (Gary, 2026-11-19).
local T, mock = ...

local function rogue(level, spells)
  local game = mock.new({ class = "ROGUE", level = level or 6 })
  game.spells = {}
  for i, n in ipairs(spells or { "Sinister Strike", "Eviscerate", "Stealth", "Backstab", "Pick Pocket", "Gouge", "Throw" }) do
    game.spells[i] = { name = n, id = 500 + i }
  end
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("macro tree", function()
  T.it("reads the spells a macro casts", function()
    local _, ns = rogue()
    local MT = ns.MacroTree
    T.same(MT.SpellsIn("#showtooltip\n/cast [stealth] Ambush; Backstab\n/startattack"), { "Ambush", "Backstab" })
    T.same(MT.SpellsIn("/castsequence reset=target Sinister Strike,Sinister Strike,Eviscerate"), { "Sinister Strike", "Eviscerate" })
    T.same(MT.SpellsIn("/cast [nocombat] !Aspect of the Hawk\n/use 13"), { "Aspect of the Hawk" })
  end)

  T.it("places macros by level band and talent tree from the learn table", function()
    local _, ns = rogue()
    local MT = ns.MacroTree
    T.eq(MT.Band(6), 1) T.eq(MT.Band(12), 2) T.eq(MT.Band(60), 6)
    T.eq(MT.LevelOf({ "Kick" }), 12)
    T.eq(MT.LevelOf({ "Kick" }, 20), 20, "a macro's own level wins")
    T.eq(MT.TreeOf({ "Cold Blood" }), "assassination")
    T.eq(MT.TreeOf({ "Kick" }, { "combat", "control" }), nil, "the 'combat' tag is not the Combat tree")
    local grid, cols = MT:Grid("pve")
    T.same(cols, { "every", "assassination", "combat", "subtlety" })
    local kickBand
    for b, row in ipairs(grid) do
      for _, it in ipairs(row[1]) do if it.id == "rogue-kick" then kickBand = b end end
    end
    T.eq(kickBand, 2, "Kick sits in 11-20, every rogue")
  end)

  T.it("your keys are the fight keys; extra keys sit in the tree", function()
    local _, ns = rogue()
    local names = {}
    for _, k in ipairs(ns.MacroTree:Keys()) do names[#names + 1] = k.name end
    T.contains(table.concat(names, ","), "Fight")
    T.contains(table.concat(names, ","), "Strike")
  end)

  T.it("picking up writes the macro, then puts it on the cursor; locked and in-combat refuse", function()
    local game, ns = rogue(8, { "Sinister Strike", "Eviscerate", "Stealth", "Gouge", "Evasion", "Sprint" })
    local MT = ns.MacroTree
    local evasion, kick
    for _, it in ipairs(MT:Items("pve")) do
      if it.id == "rogue-evasion" then evasion = it end
      if it.id == "rogue-kick" then kick = it end
    end
    T.ok(evasion and kick)
    local ok, why = MT:PickUp(kick)
    T.eq(ok, false) T.contains(why, "level 12")
    game.combat = true
    ok = MT:PickUp(evasion)
    T.eq(ok, false, "not in combat")
    game.combat = false
    T.ok(MT:PickUp(evasion))
    T.eq(game.macros[#game.macros].name, "Evasion")
    T.ok(game.cursorMacro)
  end)

  T.it("the page draws keys, the grid and a detail panel that explains every line", function()
    local game, ns = rogue()
    game:slash("")
    -- through the sidebar, as a player clicks it (2026-11-19: a page method
    -- named Show replaced the frame's Show, so the page stayed hidden in game)
    ns.Hub.frame.tabBar:Select("macros")
    local p = ns.Hub.byId.macros.panel
    T.ok(p:IsShown(), "the page is on screen")
    T.ok(p.count > 0, "icons in the tree")
    T.contains(p.who:GetText(), "levelling build")
    T.contains(p.keys.flow:GetText(), "press by press")
    p:ShowItem(p.keys.btns[1].item)
    T.contains(p.detail.text:GetText(), "When to press")
    T.contains(p.detail.text:GetText(), "Line by line")
    p.pvp.__scripts.OnClick(p.pvp)
    T.eq(p.mode, "pvp")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("explains stealth and weapon conditions in words", function()
    local _, ns = rogue()
    local s = ns.MacroEngine.ExplainLine("/cast [nocombat,nostealth] Stealth;[stealth,equipped:Daggers] Backstab")
    T.contains(s, "you are not stealthed")
    T.contains(s, "you have a dagger equipped")
  end)
  T.it("tidy-up: columns fit their icons, new is a dot, the macro shows line by line, no dev notes", function()
    local game, ns = rogue()
    local MT = ns.MacroTree
    -- one band: every has 20 icons, three builds have 1, 0 and 2
    local grid = { { {}, {}, {}, {} } }
    for i = 1, 20 do grid[1][1][i] = i end
    grid[1][2][1] = 1 grid[1][4] = { 1, 2 }
    local xs, w = MT.ColumnWidths(grid, 4, 1000, 40)
    T.eq(w[2], MT.MIN_COL, "a near-empty build column keeps just its name's room")
    T.eq(w[1] + w[2] + w[3] + w[4], 1000, "fills the width")
    T.ok(w[1] >= 400, "every column gets the rest")
    T.eq(xs[2], w[1])
    local _, roomy = MT.ColumnWidths(grid, 4, 2000, 40)
    T.ok(roomy[1] >= 812, "every column fits all 20 in one line when there's room")
    game:slash("")
    ns.Hub.frame.tabBar:Select("macros")
    local p = ns.Hub.byId.macros.panel
    local dots = 0
    for _, b in ipairs(p.tree.pool) do
      if b:IsShown() then
        T.ok(b.badge:GetText() == "" or tonumber(b.badge:GetText()), "badge is a level number or empty")
        if b.dot:IsShown() then dots = dots + 1 end
      end
    end
    T.ok(dots > 0, "new macros carry the gold dot")
    p:ShowItem(p.keys.btns[1].item)
    local text = p.detail.text:GetText()
    T.contains(text, "The macro")
    T.ok(not text:find("  |  ", 1, true), "macro lines are not run together")
    T.ok(not text:find("2026%-"), "no dated developer notes")
    T.eq(#ns.Errors.list, 0)
  end)
end)

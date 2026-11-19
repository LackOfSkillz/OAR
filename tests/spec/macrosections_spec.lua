-- Macros page: this class only, ordered by build and level (Gary, 2026-11-18).
local T, mock = ...

local function points(n) return { { name = "t", tier = 1, column = 1, rank = n, max = n } } end

T.describe("macros page sections", function()
  T.it("a Beast Mastery hunter sees recommended first, later-level ones next, other builds last, and nothing of other classes", function()
    local game = mock.new({ class = "HUNTER", level = 20 })
    game.spells = { { name = "Auto Shot", id = 1 }, { name = "Arcane Shot", id = 2 }, { name = "Serpent Sting", id = 3 } }
    game.talents = { { name = "Beast Mastery", talents = points(11) }, { name = "Marksmanship", talents = points(0) }, { name = "Survival", talents = points(0) } }
    local ns = game:loadAddon()
    game:login()
    local L = ns.MacroLibrary
    local list, spec = L:Sections()
    T.eq(spec, "bm")
    T.eq(list[1].header, "Recommended for you")
    local section, where = nil, {}
    for _, e in ipairs(list) do
      if e.header then section = e.header else where[e.id] = section end
      if not e.header then T.ok(e.class == "HUNTER" or e.class == "ALL", "only hunter macros: " .. tostring(e.id)) end
    end
    T.eq(where["hunter-hawk-arcane"], "Not yet (level or spell to learn)", "a level 25 BM macro waits")
    local sawOther = false
    for id, sec in pairs(where) do if sec == "Other builds of your class" then sawOther = true end end
    T.ok(sawOther, "Marksmanship or Survival macros sit under other builds")
    ns.Hub:Toggle()
    ns.Hub:ShowTab("macros")
    T.contains(ns.Hub.byId.macros.panel.who:GetText(), "Beast Mastery")
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("better-fit suggestions on the Macros page", function()
  T.it("a hand-written macro that misses the rotation shows first, side by side; Keep mine silences it until it changes", function()
    local game = mock.new({ class = "WARLOCK", level = 30 })
    game.spells = {}
    for i, n in ipairs({ "Shadow Bolt", "Corruption", "Immolate", "Drain Life", "Life Tap", "Demon Skin", "Bane of Agony" }) do
      game.spells[i] = { name = n, id = 100 + i }
    end
    game.macros = { { name = "MyNuke", icon = 1, body = "/cast Shadow Bolt\n/cast Drain Life" } }
    local ns = game:loadAddon()
    game:login()
    local FP = ns.FightPlan
    FP:Check("test")
    T.eq(#FP.findings, 1)
    local list = ns.MacroLibrary:Sections()
    T.eq(list[1].header, "Your macros: a better fit is available")
    T.eq(list[2].name, "MyNuke")
    ns.Hub:Toggle()
    ns.Hub:ShowTab("macros")
    local p = ns.Hub.byId.macros.panel
    p:ShowEntry(list[2])
    T.contains(p.detail.body:GetText(), "Yours:")
    T.contains(p.detail.explain:GetText(), "Problem: Drain Life")
    FP:KeepMine("MyNuke", game.macros[1].body)
    FP:Check("again")
    T.eq(#FP.findings, 0, "kept: not mentioned again")
    game.macros[1].body = "/cast Shadow Bolt\n/cast Drain Life\n/cast Life Tap"
    FP:Check("changed")
    T.eq(#FP.findings, 1, "changing it brings the check back")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("Outrider's own fight keys explain every line with the plan's reason", function()
    local game = mock.new({ class = "HUNTER", level = 20 })
    game.spells = { { name = "Auto Shot", id = 1 }, { name = "Arcane Shot", id = 2 }, { name = "Serpent Sting", id = 3 }, { name = "Hunter's Mark", id = 4 } }
    game.items = { [2504] = { name = "Worn Shortbow", equipLoc = "INVTYPE_RANGED", class = 2, subclass = 2 } }
    game.worn = { [18] = 2504 }
    local ns = game:loadAddon()
    game:login()
    local fight
    for _, e in ipairs(ns.MacroLibrary:Entries()) do if e.kind == "ranged" then fight = e end end
    T.ok(fight and next(fight.whys), "the Fight key carries its reasons")
  end)
end)

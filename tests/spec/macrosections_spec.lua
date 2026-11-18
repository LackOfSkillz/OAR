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

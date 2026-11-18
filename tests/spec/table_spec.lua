-- Sortable table widget (premium rebuild 2026-11-18).
local T, mock = ...

T.describe("sortable table", function()
  T.it("sorts by the chosen column, reverses on a second click, and lines cells up", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    local cols = {
      { key = "n", label = "Name", width = 0, sort = function(x) return x.n end, text = function(x) return x.n end },
      { key = "l", label = "Lvl", width = 50, align = "RIGHT", sort = function(x) return x.l end, text = function(x) return x.l end },
    }
    local t = ns.UI:Table(ns.Hub:Build(), cols, { rows = 5, sortKey = "l", desc = true })
    t:SetWidth(500)
    t:SetItems({ { n = "Ann", l = 12 }, { n = "Bo", l = 30 }, { n = "Cy", l = 5 } })
    T.eq(t.list.items[1].n, "Bo", "highest level first")
    T.contains(t.headCells[2].text:GetText(), "LVL")
    t.headCells[2].__scripts.OnClick(t.headCells[2])
    T.eq(t.list.items[1].n, "Cy", "second click reverses")
    t.headCells[1].__scripts.OnClick(t.headCells[1])
    T.eq(t.list.items[1].n, "Ann", "by name, A first")
    T.eq(t.list.rowFrames[1].cells[2]:GetText(), "12")
    T.eq(#ns.Errors.list, 0)
  end)
end)

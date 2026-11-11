-- Widget kit additions (P1-07).
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("widgets", function()
  T.it("ScrollList shows only as many rows as it has and scrolls within bounds", function()
    local game, ns = session()
    local items = {}
    for i = 1, 50 do items[i] = i end
    local list = ns.UI:ScrollList(game.env.UIParent, { rows = 5 })
    list:SetItems(items)
    T.same(list:VisibleItems(), { 1, 2, 3, 4, 5 })
    list.__scripts.OnMouseWheel(list, -1)
    T.same(list:VisibleItems(), { 4, 5, 6, 7, 8 })
    list:SetOffset(999)
    T.same(list:VisibleItems(), { 46, 47, 48, 49, 50 })
    list.__scripts.OnMouseWheel(list, 100)
    T.eq(list.offset, 0)
    list:SetItems({ "a", "b" })
    T.same(list:VisibleItems(), { "a", "b" })
  end)

  T.it("ScrollList click passes the item, a failing render is recorded", function()
    local game, ns = session()
    local got
    local list = ns.UI:ScrollList(game.env.UIParent, { rows = 3, onClick = function(item) got = item end,
      render = function(row, item) if item == "bad" then error("render broke") end row.text:SetText(item) end })
    list:SetItems({ "x", "bad", "z" })
    list.rowFrames[3].__scripts.OnClick(list.rowFrames[3], "LeftButton")
    T.eq(got, "z")
    T.eq(#ns.Errors.list, 1)
  end)

  T.it("Tabs select calls back and falls back to the first tab for unknown ids", function()
    local game, ns = session()
    local sel
    local tabs = ns.UI:Tabs(game.env.UIParent, { { "a", "A" }, { "b", "B" } }, function(id) sel = id end)
    tabs:Select("b")
    T.eq(sel, "b")
    tabs:Select("nope")
    T.eq(sel, "a")
  end)

  T.it("Dropdown shows the current label and sets the chosen value", function()
    local game, ns = session()
    local v = "b"
    local dd = ns.UI:Dropdown(game.env.UIParent, 150, { { "a", "Alpha" }, { "b", "Beta" } },
      function() return v end, function(x) v = x end)
    T.contains(dd.label:GetText(), "Beta")
    dd:Open()
    T.ok(dd.menu:IsShown())
    dd.menu.items[1].__scripts.OnClick(dd.menu.items[1])
    T.eq(v, "a")
    T.no(dd.menu:IsShown())
    T.contains(dd.label:GetText(), "Alpha")
  end)

  T.it("Slider snaps to its step and saves", function()
    local game, ns = session()
    local v = 10
    local s = ns.UI:Slider(game.env.UIParent, "Vol", 0, 100, 5, function() return v end, function(x) v = x end, "%d")
    s.slider:SetValue(47)
    T.eq(v, 45)
    T.eq(s.value:GetText(), "45")
  end)

  T.it("SearchBox filters once per burst of typing, with the final text", function()
    local game, ns = session()
    local calls = {}
    local box = ns.UI:SearchBox(game.env.UIParent, 200, "Find", function(t) calls[#calls + 1] = t end)
    for _, t in ipairs({ "r", "ra", "rak", "rake" }) do box:SetText(t) game:advance(0.02) end
    game:advance(0.5)
    T.eq(calls[#calls], "rake")
    T.ok(#calls <= 2)
  end)

  T.it("/ride selftest widgets opens the test window without errors", function()
    local game, ns = session()
    game:slash("selftest widgets")
    T.ok(ns.UI.widgetTest:IsShown())
    ns.UI.widgetTest.search:SetText("1")
    game:advance(0.5)
    T.eq(ns.UI.widgetTest.list:VisibleItems()[1], "Row 1")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("class accent setting recolors the theme at login", function()
    local game, ns = session({ class = "MAGE" })
    ns.db.char.classAccent = true
    local sv = game:logout()
    local g2 = mock.new({ savedVariables = sv, class = "MAGE" })
    local ns2 = g2:loadAddon()
    g2:login()
    local r = ns2.Theme:Color("accent")
    T.eq(r, 0.25)
  end)
end)

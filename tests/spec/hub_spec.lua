-- Hub with tabs (P1-08).
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("hub", function()
  T.it("opens on Overview with the four core tabs, every tab builds without errors", function()
    local game, ns = session()
    game:slash("")
    local f = ns.Hub.frame
    T.ok(f:IsShown())
    T.eq(ns.Hub.current, "overview")
    T.same(f.tabBar.order, { "overview", "modules", "characters", "rares", "macros", "gear", "map", "crafting", "errands", "feed", "forecasts", "advisor", "tools" })
    for _, id in ipairs(f.tabBar.order) do f.tabBar:Select(id) T.eq(ns.Hub.current, id) end
    T.eq(#ns.Errors.list, 0)
    T.contains(ns.Hub.byId.overview.panel.who:GetText(), "Torrant")
  end)

  T.it("the Esc key closes it (named frame in UISpecialFrames)", function()
    local game, ns = session()
    game:slash("")
    local found = false
    for _, n in ipairs(game.env.UISpecialFrames) do if n == "Outrider_Hub" then found = true end end
    T.ok(found)
  end)

  T.it("modules can add a tab before or after the hub is built", function()
    local game, ns = session()
    ns.Hub:AddTab("rares", "Rares", function(p) p.built = true end, 40)
    game:slash("")
    ns.Hub:AddTab("pet", "Pet", function(p) p.built = true end, 50)
    local order = ns.Hub.frame.tabBar.order
    T.same(order, { "overview", "modules", "characters", "rares", "macros", "gear", "map", "crafting", "errands", "feed", "forecasts", "advisor", "pet", "tools" })
    ns.Hub.frame.tabBar:Select("pet")
    T.ok(ns.Hub.byId.pet.panel.built)
  end)

  T.it("remembers the last tab per character across a reload", function()
    local game, ns = session()
    game:slash("")
    ns.Hub.frame.tabBar:Select("tools")
    local sv = game:logout()
    local g2 = mock.new({ savedVariables = sv })
    local ns2 = g2:loadAddon()
    g2:login()
    -- the hub was left open, so login reopens it on the same tab
    T.ok(ns2.Hub.frame and ns2.Hub.frame:IsShown())
    T.eq(ns2.Hub.current, "tools")
  end)

  T.it("Characters tab lists every known character, current one marked", function()
    local game, ns = session()
    local sv = game:logout()
    local g2 = mock.new({ savedVariables = sv, name = "Zeil", class = "PRIEST" })
    local ns2 = g2:loadAddon()
    g2:login()
    g2:slash("")
    ns2.Hub.frame.tabBar:Select("characters")
    local items = ns2.Hub.byId.characters.panel.list:VisibleItems()
    T.eq(#items, 2)
    local rows = ns2.Hub.byId.characters.panel.list.rowFrames
    local text = rows[1].text:GetText() .. rows[2].text:GetText()
    T.contains(text, "Zeil-Forever  (you)")
    T.contains(text, "Torrant-Forever")
  end)

  T.it("a failing module tab is contained", function()
    local game, ns = session()
    ns.Hub:AddTab("broken", "Broken", function() error("tab broke") end)
    game:slash("")
    ns.Hub.frame.tabBar:Select("broken")
    T.eq(#ns.Errors.list, 1)
    ns.Hub.frame.tabBar:Select("overview")
    T.eq(ns.Hub.current, "overview")
  end)
end)

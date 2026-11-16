-- Expedition look on every hub page (2026-11-15): a title strip on pages that
-- don't draw their own heading, and form sections in cards.
local T, mock = ...

local function session()
  local game = mock.new({ ammo = 1000 })
  local ns = game:loadAddon()
  game:login()
  game:slash("")
  return game, ns
end

T.describe("page look", function()
  T.it("every page but Home and What now? gets a title strip", function()
    local _, ns = session()
    for _, t in ipairs(ns.Hub.tabs) do
      if ns.Hub:Visible(t) then
        ns.Hub:ShowTab(t.id)
        local p = t.panel
        if ns.Hub.OWN_HEADING[t.id] then
          T.eq(p.hubTitle, nil, t.id)
        else
          T.ok(p.hubTitle, "title strip on " .. t.id)
          T.ok((p.hubTitle:GetText() or "") ~= "", "title text on " .. t.id)
        end
      end
    end
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a form page's first heading becomes the title; later headings open cards", function()
    local _, ns = session()
    ns.Hub:ShowTab("money")
    local p = ns.Hub.byId.money.panel
    T.eq(p.hubTitle:GetText(), "Money")
    local cards = p.form.cards or {}
    T.ok(#cards >= 3, "money sections in cards")
    T.eq(cards[1].title:GetText(), "Best ways to earn at level " .. (ns.Compat.Call("UnitLevel", "player") or 1))
  end)

  T.it("rows straight after the title sit in an untitled card", function()
    local game, ns = session()
    local parent = game.env.CreateFrame("Frame")
    parent.hubTitle = ns.UI.Display(parent, "page", "text")
    local form = ns.UI:Form(parent, { { "header", "Page" }, { "note", "intro" }, { "header", "Section" }, { "note", "x" } })
    T.eq(parent.hubTitle:GetText(), "Page")
    T.eq(#form.cards, 2)
    T.eq(form.cards[1].title, nil)
    T.eq(form.cards[2].title:GetText(), "Section")
    T.ok(form.cards[1]:GetHeight() > 0)
  end)
end)

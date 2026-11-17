-- Premium blocks: cards with item chips and buttons, status tiles, and their
-- heights in the form layout.
local T, mock = ...

T.describe("premium cards and tiles", function()
  T.it("cards show title, tags, chips and buttons; tiles mark good and bad; form rows take their height", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    local UI = ns.UI
    local parent = game.env.CreateFrame("Frame")
    local clicked
    local list = UI:CardList(parent)
    list:SetItems({ { title = "The Deadmines", tags = { { "Levels 17-26", "plain" } }, line = "7 upgrades",
      chips = { { itemID = 5, text = "+100% Belt" } }, actions = { { "Go to the entrance", function() clicked = true end } } } })
    local c = list.cards[1]
    T.eq(c.title:GetText(), "The Deadmines")
    T.eq(c.chips[1].text:GetText(), "+100% Belt")
    c.buttons[1]:Click()
    T.ok(clicked)
    T.ok(list:LayoutHeight() > 90)
    local tiles = UI:StatusTiles(parent)
    tiles:SetItems({ { ok = true, text = "Gear in good repair" }, { ok = false, text = "No drink" }, { ok = false, text = "Ammo" } })
    T.eq(tiles.tiles[2].mark:GetText(), "!")
    T.ok(tiles:LayoutHeight() > 90, "two rows of tiles")
    local items = { { title = "A" } }
    local form = UI:Form(parent, { { "header", "Section" }, { "cards", function() return items end }, { "note", "after" } })
    local h1 = form.content.height
    items[2] = { title = "B" }
    form:Refresh()
    T.ok(form.content.height > h1 + 90, "a second card pushes the rows below it down")
    T.eq(#ns.Errors.list, 0)
  end)
end)

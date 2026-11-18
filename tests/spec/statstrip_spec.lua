-- Premium plan S3: the hero stat strip on the main pages builds without errors.
local T, mock = ...

T.describe("stat strips", function()
  T.it("Quests, My characters, Census, Fishing and Feed open with a filled stat strip and no errors", function()
    local game = mock.new({ class = "HUNTER", level = 20 })
    local ns = game:loadAddon()
    game:login()
    ns.Hub:Toggle()
    for _, id in ipairs({ "quests", "alts", "census", "fishing", "feed" }) do
      ns.Hub:ShowTab(id)
      T.eq(ns.Hub.current, id)
    end
    T.eq(#ns.Errors.list, 0, "every strip built")
    local strip = ns.UI:StatStrip(ns.Hub.frame)
    strip:SetWidth(800)
    strip:SetItems({ { cap = "a", value = "1" }, { cap = "b", value = "2", fill = 0.5 } })
    T.eq(strip.tiles[1].value:GetText(), "1")
    T.eq(strip.tiles[1].cap:GetText(), "A", "captions in capitals")
    T.ok(strip.tiles[2].track:IsShown(), "a fill shows the bar")
  end)
end)

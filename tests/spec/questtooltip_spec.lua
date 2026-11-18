-- Questie-style quest pin tooltips (gallery idea, 2026-11-18).
local T, mock = ...

T.describe("quest pin tooltips", function()
  T.it("groups quests under each quest NPC on the spot, with level colour and state", function()
    local game = mock.new({ class = "HUNTER", level = 15 })
    local ns = game:loadAddon()
    game:login()
    local tt = game.env.GameTooltip
    tt:ClearLines()
    local drew = ns.MapPins.QuestTooltip(tt, {
      kind = "quest_giver", name = "Barkeep Daniels",
      quests = { { name = "Dry Times", level = 15, diff = "yellow" } },
      more = {
        { kind = "quest_giver", name = "Darcy", quests = { { name = "A Free Lunch", level = 15, diff = "yellow" } } },
        { kind = "turnin", name = "Turn in: The Defias Brotherhood", title = "Hand in The Defias Brotherhood to Wiley the Black" },
        { kind = "vendor", name = "Some Vendor" },
      },
    })
    T.ok(drew)
    local text = table.concat(tt.__lines or {}, "\n")
    for _, want in ipairs({ "Barkeep Daniels", "[15] Dry Times", "Available", "Darcy", "A Free Lunch",
      "Wiley the Black", "The Defias Brotherhood", "Complete" }) do
      T.contains(text, want)
    end
    T.no(text:find("Some Vendor", 1, true), "non-quest pins stay out")
    T.eq(#ns.Errors.list, 0)
  end)
end)

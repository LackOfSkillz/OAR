-- Every hub page shows when its sidebar button is clicked (2026-11-19: the
-- Macros page defined p:Show for its own use, which hid the frame's Show).
local T, mock = ...

T.describe("hub pages", function()
  T.it("every sidebar page is on screen after a click, for every class", function()
    for _, cls in ipairs({ "ROGUE", "HUNTER", "PRIEST", "WARRIOR" }) do
      local game = mock.new({ class = cls, level = 20 })
      local ns = game:loadAddon()
      game:login()
      game:slash("")
      local bar = ns.Hub.frame.tabBar
      for id in pairs(bar.buttons) do
        bar:Select(id)
        local t = ns.Hub.byId[id]
        T.ok(t and t.panel and t.panel:IsShown(), cls .. ": page " .. tostring(id) .. " is shown")
      end
    end
  end)
end)

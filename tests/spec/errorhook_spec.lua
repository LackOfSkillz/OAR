-- Errors outside ns.Safe (frame scripts, other addons) are recorded, then passed on (2026-11-19).
local T, mock = ...

T.describe("global error hook", function()
  T.it("records a frame-script or other-addon error under its folder and still hands it to the old handler", function()
    local game = mock.new({ class = "ROGUE", level = 4 })
    local passed = {}
    game.errorhandler = function(e) passed[#passed + 1] = e end
    local ns = game:loadAddon()
    game:login()
    local h = game.env.geterrorhandler()
    h("Interface/AddOns/GearQuestForever/Core.lua:12: attempt to index a nil value")
    h("Interface/AddOns/GearQuestForever/Core.lua:12: attempt to index a nil value")
    h("Interface\\AddOns\\Outrider\\UI\\Hub.lua:40: boom")
    T.eq(#passed, 3, "the old handler still gets every error")
    local gq, ours
    for _, e in ipairs(ns.Errors.list) do
      if e.where == "lua:GearQuestForever" then gq = e end
      if e.where == "lua:Outrider" then ours = e end
    end
    T.ok(gq and gq.count == 2, "counted, not listed twice")
    T.ok(ours, "an Outrider frame-script error is caught too (Windows path)")
  end)
end)

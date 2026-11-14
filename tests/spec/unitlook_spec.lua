-- Unit frame and bar look (P7-06): cosmetic only, reversible.
local T, mock = ...

T.describe("unit look", function()
  T.it("flattens health bars, fades bar art, colors players by class, restores when off", function()
    local game = mock.new()
    local env = game.env
    local colored = {}
    env.UnitFrameHealthBar_Update = function() end
    local ns = game:loadAddon()
    local bar = env.CreateFrame("StatusBar", "TargetFrameHealthBar", env.UIParent)
    bar.SetStatusBarColor = function(self, r, g, b) colored[#colored + 1] = { r, g, b } end
    local cap = env.CreateFrame("Frame", "MainMenuBarLeftEndCap", env.UIParent)
    game:login()
    T.eq(cap:GetAlpha(), 0, "gryphon faded")
    T.ok(ns.UnitLook.textured[bar] ~= nil, "bar restyled")
    game.units = { target = { name = "Lumen", player = true, class = "HUNTER" } }
    env.UnitFrameHealthBar_Update(bar, "target")
    T.same(colored[1], { 0.67, 0.83, 0.45 }, "hunter green")
    game.units.target.player = false
    env.UnitFrameHealthBar_Update(bar, "target")
    T.eq(#colored, 1, "mobs keep Blizzard colors")
    ns.Modules:SetEnabled("UnitLook", false)
    T.eq(cap:GetAlpha(), 1, "restored")
    T.eq(#ns.Errors.list, 0)
  end)
end)

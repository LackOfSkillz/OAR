-- Probe: Edit Mode survey (P7-03). Frames and layouts are test data.
local T, mock = ...


T.describe("edit mode survey", function()
  T.it("records layouts, system frames and which frames Edit Mode covers", function()
    local game = mock.new()
    game.env.C_EditMode = { GetLayouts = function() return { activeLayout = 1, layouts = {
      { layoutName = "Modern", layoutType = 0 }, { layoutName = "Classic", layoutType = 0 } } } end }
    local ns = game:loadAddon()
    game:login()
    local player = game.env.CreateFrame("Frame", "PlayerFrame", game.env.UIParent)
    game.env.CreateFrame("Frame", "LootFrame", game.env.UIParent)
    game.env.EditModeManagerFrame = { registeredSystemFrames = { player } }
    local em = ns.Probe:EditMode()
    T.eq(#em.layouts, 2)
    T.eq(em.layouts[2].name, "Classic")
    T.same(em.systems, { "PlayerFrame" })
    T.contains(em.frames.PlayerFrame, "edit mode")
    T.contains(em.frames.LootFrame, "not in edit mode")
    T.no(em.api.SetActiveLayout)
    T.eq(#ns.Errors.list, 0)
  end)
end)

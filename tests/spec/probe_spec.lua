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

T.describe("damage meter capture", function()
  T.it("logs each call's shape or error; secrets stay 'secret'; never throws", function()
    local game = mock.new()
    game.env.Enum.DamageMeterType = { DamageDone = 0 }
    game.env.Enum.DamageMeterSessionType = { Current = 1 }
    game.env.C_DamageMeter = {
      IsDamageMeterAvailable = function() return true end,
      GetAvailableCombatSessions = function() return { { sessionID = 4, name = "Fight" } } end,
      GetCombatSessionFromType = function() return { durationSeconds = 12, combatSources = { { name = "Me", totalAmount = { __secret = true } } } } end,
      GetCombatSessionSourceFromType = function() error("bad argument #3") end,
    }
    local ns = game:loadAddon()
    game:login()
    ns.Probe:DamageMeter("test")
    local text = {}
    for _, l in ipairs(ns.Log:Tail(40)) do text[#text + 1] = ns.Log:FormatLine(l) end
    text = table.concat(text, "\n")
    T.contains(text, "dm IsDamageMeterAvailable() -> true")
    T.contains(text, "name=\"Fight\"")
    T.contains(text, "sessionID=4")
    T.eq(ns.Probe.Shape({ a = { __secret = true } }), "{a=secret}")
    T.contains(text, "dm GetCombatSessionFromID(newest 4, DamageDone): missing")
    T.eq(#ns.Errors.list, 0)
  end)
end)

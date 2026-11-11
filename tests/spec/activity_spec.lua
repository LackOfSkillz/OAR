-- Every module says what it is doing (hub Modules tab), plus one login line.
local T, mock = ...

T.describe("activity lines", function()
  T.it("every enabled module returns an activity line without errors", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    for _, s in ipairs(ns.Modules:Status()) do
      if s.enabled then T.ok(type(s.activity) == "string" and s.activity ~= "", "activity for " .. s.name) end
    end
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("the Modules tab shows them", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    game:slash("")
    ns.Hub.frame.tabBar:Select("modules")
    local text = ""
    for _, row in ipairs(ns.Hub.byId.modules.panel.rows) do text = text .. tostring(row.note:GetText()) end
    T.contains(text, "NPCs known")
    T.contains(text, "waiting for a rare")
  end)

  T.it("one chat line at login says Outrider is on", function()
    local game = mock.new()
    game:loadAddon()
    game:login()
    T.contains(game:chatText(), "features on. /ride shows what each is doing.")
  end)
end)

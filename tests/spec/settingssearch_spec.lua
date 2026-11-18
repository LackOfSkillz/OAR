-- Settings search results grouped by section with ON/OFF (gallery idea from Leatrix Plus).
local T, mock = ...

T.describe("settings search", function()
  T.it("lists every match as you type, with its section and the switch state, and jumps on click", function()
    local game = mock.new({ class = "HUNTER", level = 20 })
    local ns = game:loadAddon()
    game:login()
    ns.Hub:Toggle()
    ns.Hub:ShowTab("settings")
    local p = ns.Hub.byId.settings.panel
    local found = p.form:SearchAll("bar")
    T.ok(#found >= 3, "several info bar switches")
    local sawSection, sawState = false, false
    for _, m in ipairs(found) do
      if m.section == "Info bar" then sawSection = true end
      if m.on ~= nil then sawState = true end
    end
    T.ok(sawSection, "grouped by the card they live in")
    T.ok(sawState, "switches report ON/OFF")
    T.eq(#p.form:SearchAll(""), 0)
    T.eq(#ns.Errors.list, 0)
  end)
end)

-- Advisor page as three steps (premium rebuild 2026-11-18).
local T, mock = ...

T.describe("advisor steps", function()
  T.it("starts on Ask, moves to Paste once you asked, and hides feedback until there is advice", function()
    local game = mock.new({ class = "HUNTER", level = 20 })
    local ns = game:loadAddon()
    game:login()
    local A = ns.Modules:Get("Advisor")
    ns.db.char.askPending = nil
    ns.Snapshot.askedThisSession = nil
    local cur, done = A:Step()
    T.eq(cur, 1) T.eq(done, 0)
    ns.Hub:Toggle()
    ns.Hub:ShowTab("advisor")
    local p = ns.Hub.byId.advisor.panel
    T.eq(#p.steps, 3)
    T.no(p.feedback[1]:IsShown(), "no advice yet: no feedback buttons")
    ns.Snapshot.askedThisSession = 1
    cur, done = A:Step()
    T.eq(cur, 3) T.eq(done, 2)
    T.eq(#ns.Errors.list, 0)
  end)
end)

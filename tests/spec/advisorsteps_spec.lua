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

T.describe("advisor: AI Advisor switch", function()
  T.it("hidden without the XP recorder; with it, the switch turns recording and the next-hour plan on and off", function()
    local game = mock.new({ class = "HUNTER", level = 20 })
    local ns = game:loadAddon()
    game:login()
    local A = ns.Modules:Get("Advisor")
    ns.Hub:Toggle()
    ns.Hub:ShowTab("advisor")
    local p = ns.Hub.byId.advisor.panel
    if not ns.SessionXP then
      T.no(p.coach:IsShown(), "no recorder installed: no switch")
      -- stand-ins with the same shape as Intelligence/SessionXP and NextSession
      local opened = 0
      ns.SessionXP = ns:NewModule("SessionXP", { title = "t", defaultEnabled = false })
      function ns.SessionXP:Activity() return "0 recorded, idle" end
      ns.NextSession = ns:NewModule("NextSession", { title = "t", defaultEnabled = false })
      function ns.NextSession:Activity() return "no fresh briefing" end
      function ns.NextSession:Open() opened = opened + 1 end
      ns.SessionXP.opened = function() return opened end
    end
    T.no(A:CoachOn())
    p:Refresh()
    T.ok(p.coach:IsShown())
    T.no(p.coach.plan:IsShown(), "off: no plan button")
    p.coach.switch:Click()
    T.ok(A:CoachOn(), "the switch turns the recorder on")
    T.ok(ns.NextSession.enabled, "and the next-hour plan")
    T.ok(p.coach.plan:IsShown())
    T.contains(p.coach.note:GetText(), "Recording")
    p.coach.plan:Click()
    if ns.SessionXP.opened then T.eq(ns.SessionXP.opened(), 1) end
    p.coach.switch:Click()
    T.no(A:CoachOn())
    T.eq(#ns.Errors.list, 0)
  end)
end)

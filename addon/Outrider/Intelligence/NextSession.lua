-- Intelligence/NextSession.lua: quiet opt-in display of precomputed offline XP60 plan.
-- No live AI calls; no game automation; no accepted untrusted waypoint.
local _, ns = ...
local M = ns:NewModule("NextSession", {
  title = "Next-session XP plan", phase = "P9", order = 99,
  defaultEnabled = true, defaults = { dismissed = {}, hidden = false },
})
ns.NextSession = M

function M:Plan()
  local _, reason, answer = ns.Advice:Load()
  if reason == "ok" and answer and answer.nextSession then
    local dismissed = self:Settings().dismissed
    if type(dismissed) == "table" and dismissed[answer.basedOnSessionId] then
      return nil, "dismissed"
    end
    return answer, "ok"
  end
  return nil, reason or "no next-session plan"
end

function M:Feedback(verdict)
  if verdict ~= "already_know" and verdict ~= "not_interested" and
      verdict ~= "useful" and verdict ~= "wrong" and
      verdict ~= "dismiss" then return false end
  local a = self:Plan()
  if not a then return false end
  local d = self:Settings().dismissed
  if type(d) ~= "table" then d = {} self:Settings().dismissed = d end
  if verdict == "dismiss" or verdict == "wrong" or
     verdict == "already_know" or verdict == "not_interested" then
    d[a.basedOnSessionId] = verdict
    local n = 0
    for _ in pairs(d) do n = n + 1 end
    if n > 20 then self:Settings().dismissed = { [a.basedOnSessionId] = verdict } end
  end
  if verdict == "useful" then
    ns.db.char.xp60PlanUseful = true
  end
  return true
end

function M:Open()
  if not self.enabled then ns.Print("Next-session plans are disabled.") return end
  if ns.Compat.InCombat() then return end
  local answer, reason = self:Plan()
  if not self.window then
    local p = ns.UI:Window("Outrider_XP60Plan", "Next 60 minutes - XP focus", 520, 360, self:Settings())
    p.head = ns.UI.Text(p.content, "large", "text")
    p.head:SetPoint("TOPLEFT", 8, -10)
    p.head:SetWidth(480)
    p.details = ns.UI.Text(p.content, "small", "body")
    p.details:SetPoint("TOPLEFT", 8, -46)
    p.details:SetWidth(470)
    p.details:SetJustifyH("LEFT")
    p.dismiss = ns.UI:Button(p.content, "Dismiss this plan", 140, function()
      M:Feedback("dismiss")
      M:Render()
    end)
    p.dismiss:SetPoint("BOTTOMLEFT", 8, 8)
    p.known = ns.UI:Button(p.content, "Already know", 110, function()
      M:Feedback("already_know")
      M:Render()
    end)
    p.known:SetPoint("LEFT", p.dismiss, "RIGHT", 8, 0)
    p.notInterested = ns.UI:Button(p.content, "Not interested", 118, function()
      M:Feedback("not_interested")
      M:Render()
    end)
    p.notInterested:SetPoint("LEFT", p.known, "RIGHT", 8, 0)
    p.useful = ns.UI:Button(p.content, "Useful", 72, function()
      M:Feedback("useful")
      ns.Print("Feedback saved. Outrider will compare the next session's results.")
    end)
    p.useful:SetPoint("LEFT", p.notInterested, "RIGHT", 8, 0)
    self.window = p
  end
  self:Render(answer, reason)
  self.window:Show()
end

function M:Render(answer, reason)
  if not self.window then return end
  if not answer then answer, reason = self:Plan() end
  if not answer then
    self.window.head:SetText("No fresh XP plan")
    self.window.details:SetText("Keep your current route. " .. tostring(reason or "No offline analysis yet."))
    self.window.dismiss:SetShown(false)
    self.window.known:SetShown(false)
    self.window.notInterested:SetShown(false)
    self.window.useful:SetShown(false)
    return
  end
  local rows = {}
  if answer.planStatus == "tentative" then
    rows[#rows + 1] = "Tentative: Classic-derived route timing and XP are unverified."
  end
  rows[#rows + 1] = answer.summary or "Continue your current route."
  if answer.baselineXPPerHour then
    rows[#rows + 1] = string.format("Last measured XP: %d per wall-clock hour.", answer.baselineXPPerHour)
  end
  local plan = type(answer.plan) == "table" and answer.plan or {}
  if #plan > 0 then
    for i, s in ipairs(plan) do
      rows[#rows + 1] = string.format("%02d-%02d min: %s", math.floor(s.startsAt / 60),
        math.ceil(s.endsAt / 60), s.title)
    end
  else
    rows[#rows + 1] = "No defensible numerical improvement from the available evidence."
    for i, suggestion in ipairs(answer.suggestions or {}) do
      rows[#rows + 1] = string.format("Review %d: %s", i, suggestion.title)
    end
  end
  for _, l in ipairs(answer.limits or {}) do rows[#rows + 1] = "Note: " .. l end
  self.window.head:SetText(answer.headline or "Your next 60 minutes")
  self.window.details:SetText(table.concat(rows, "\n"))
  self.window.dismiss:SetShown(true)
  self.window.known:SetShown(true)
  self.window.notInterested:SetShown(true)
  self.window.useful:SetShown(true)
end

function M:OnEnable()
  -- No modal window, no timer, no automatic navigation.
  local plan = self:Plan()
  if plan then ns.Print("Your next 60-minute XP briefing is ready: /ride nextsession") end
end
function M:Activity()
  local p = self:Plan()
  return p and "offline XP briefing ready" or "no fresh briefing"
end
ns.AddCommand("nextsession", "open the offline 60-minute XP briefing", function()
  M:Open()
end)

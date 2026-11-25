-- Intelligence/NextSession.lua: quiet opt-in display of precomputed offline XP60 plan.
-- No live AI calls; no game automation; no accepted untrusted waypoint.
local _, ns = ...
local M = ns:NewModule("NextSession", {
  title = "Next-session XP plan", phase = "P9", order = 99,
  defaultEnabled = true, defaults = { dismissed = {}, hidden = false },
})
ns.NextSession = M

-- OI03-12: an offline plan meets what Outrider knows now. Steps the planner
-- can see are not doable now (other faction, a prerequisite missing, over
-- budget...) are marked and kept out of the time line; your own quest times
-- (Estimator) add a note when the plan looks optimistic for you. Read only:
-- the plan itself was already checked by the advice loader (policy, character,
-- session, build, level, expiry, time budget, no actions).
local function sanitize(s) return (tostring(s):gsub("[^%w_:%.@%-]", "_")) end
function M.Annotate(answer)
  local N = ns.NexusCore
  local cur = N and N.current
  if cur and cur.graph then
    local byLegacy = {}
    for id, node in pairs(cur.graph.nodes) do byLegacy[node.opp.legacyCandidateId] = id end
    local inPlan = {}
    for _, s in ipairs(cur.result and cur.result.plan and cur.result.plan.steps or {}) do inPlan[s] = true end
    local kept = {}
    for _, step in ipairs(answer.plan or {}) do
      local id = byLegacy[sanitize(step.candidateId)]
      local why = id and (cur.graph.invalid[id] or (cur.rejected and cur.rejected[id]))
      if why then
        answer.limits[#answer.limits + 1] = string.format("%s can't be done now: %s.", tostring(step.title), tostring(why))
      else
        step.inYourPlan = id and inPlan[id] or nil
        kept[#kept + 1] = step
      end
    end
    answer.plan = kept
  end
  local E, Q = ns.Estimator, ns.QuestTimes
  if E and Q then
    local level = tonumber(ns.Compat.Readable(ns.Compat.Call("UnitLevel", "player"))) or 1
    local key = "L" .. (math.floor((level - 1) / 5) * 5 + 1) .. "|solo"
    local m = E.Fit(E.QuestSamples(Q:Mine()), {})[key]
    if m and m.basis == "observed" and m.value then
      answer.limits[#answer.limits + 1] = string.format("Your quests take about %d min (%d done).", math.floor(m.value / 60 + 0.5), m.n)
      local total, n = 0, 0
      for _, s in ipairs(answer.plan or {}) do total, n = total + (s.minutes or 0), n + 1 end
      if n > 0 and (total / n) * 60 < m.value * 0.67 then
        answer.limits[#answer.limits + 1] = "This plan may be optimistic for you: you may finish fewer steps."
      end
    end
  end
  return answer
end

-- with no offline plan: a few ideas from Outrider itself (the planner when it
-- is on, else What now?), labelled as ideas
function M.LocalIdeas()
  local N = ns.NexusCore
  local picks = N and N.Ready and N:Ready() and N:Picks(3) or (ns.WhatNow and ns.WhatNow.enabled and ns.WhatNow:List()) or {}
  local out = {}
  for i, p in ipairs(picks) do if i <= 3 then out[#out + 1] = tostring(p.title) end end
  return out
end

function M:Plan()
  local _, reason, answer = ns.Advice:Load()
  if reason == "ok" and answer and answer.nextSession then
    local dismissed = self:Settings().dismissed
    if type(dismissed) == "table" and dismissed[answer.basedOnSessionId] then
      return nil, "dismissed"
    end
    answer.limits = answer.limits or {}
    return M.Annotate(answer), "ok"
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
  if type(d) ~= "table" then ns.KeepBad(d, "NextSession:d") d = {} self:Settings().dismissed = d end
  if verdict == "dismiss" or verdict == "wrong" or
     verdict == "already_know" or verdict == "not_interested" then
    d[a.basedOnSessionId] = verdict
    local n = 0
    for _ in pairs(d) do n = n + 1 end
    if n > 20 and ns.Archive:Put("nextSessionDismissed", d, { path = "char.modules.NextSession.settings.dismissed", scope = "char" }) then
      self:Settings().dismissed = { [a.basedOnSessionId] = verdict }
    end
  end
  if verdict == "already_know" or verdict == "not_interested" or
      verdict == "wrong" then
    local saved = ns.db.char.xp60Suppressed
    if type(saved) ~= "table" then ns.KeepBad(saved, "NextSession:saved") saved = {} ns.db.char.xp60Suppressed = saved end
    local level = ns.Compat.Readable(ns.Compat.Call("UnitLevel", "player")) or 0
    local function remember(id)
      if type(id) == "string" and #id > 0 and #id <= 100 then
        saved[id] = { verdict = verdict, at = time(), level = level }
      end
    end
    for _, c in ipairs(a.suggestions or {}) do remember(c.candidateId) end
    for _, c in ipairs(a.plan or {}) do remember(c.candidateId) end
    local count = 0
    for _ in pairs(saved) do count = count + 1 end
    if count > 80 then
      -- Strictly bounded and per-character, never global blacklisting. The
      -- old list is archived first (owner data preservation), else kept.
      if ns.Archive:Put("xp60Suppressed", saved, { path = "char.xp60Suppressed", scope = "char" }) then
        ns.db.char.xp60Suppressed = {}
      end
    end
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
    local ideas = M.LocalIdeas()
    self.window.details:SetText("Keep your current route. " .. tostring(reason or "No offline analysis yet.") ..
      (#ideas > 0 and ("\nIdeas from Outrider (not a plan): " .. table.concat(ideas, "; ") .. ".") or ""))
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

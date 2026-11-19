-- Modules/Advisor.lua  (P9-02 /ride ask and the Advisor tab)
-- /ride ask (out of combat): takes a fresh snapshot and shows it as a code
-- to copy (Ctrl+C); Claude answers with an advice code that Gary pastes with
-- the tab's "Paste advice" button. No reload (Gary, 2026-11-11). The older
-- disk route stays: /ride ask reload, then Advice.lua after a /reload.
-- Advisor hub tab: the items ns.Advice:Load() accepted (whitelisted actions
-- only), each with title, why, confidence and a "Do it" button. Buttons only
-- do harmless, non-protected things:
--   waypoint    -> Outrider waypoint
--   track_quest -> add the quest to the objective tracker
--   open_panel  -> open a hub tab
--   show_item   -> show the item's tooltip
-- When there is no advice the tab says why (no file, stale, other character).

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local M = ns:NewModule("Advisor", {
  title = "Advisor (suggestions from your companion app)",
  phase = "P9",
  order = 100,
  defaults = {},
})
ns.Advisor = M

M.PANEL_TAB = { hub = "overview", rares = "rares", pet = "pet", macros = "macros", gear = "gear",
  professions = "crafting", map = "map" }

function M:Items()
  local items, why, answer = ns.Advice:Load()
  self.reason, self.answer = why, answer
  return items, why, answer
end

-- Performs one cleaned advice item; returns ok, message.
function M:Perform(item)
  if type(item) ~= "table" or not ns.Advice.ALLOWED[item.action] then return false, "not allowed" end
  local a = item.args or {}
  if item.action == "waypoint" then
    ns.Waypoints:Set(a.mapID, a.x, a.y, item.title)
    return true, "waypoint set"
  elseif item.action == "track_quest" then
    if C.InCombat() then return false, "not in combat" end
    local ok = pcall(C_QuestLog.AddQuestWatch, a.questID)
    return ok, ok and "quest tracked" or "could not track that quest"
  elseif item.action == "open_panel" then
    local tab = M.PANEL_TAB[a.panel]
    if not tab then return false, "unknown panel" end
    ns.Hub:Build():Show()
    ns.Hub:ShowTab(tab)
    return true, "opened " .. a.panel
  elseif item.action == "show_item" then
    local tip = rawget(_G, "ItemRefTooltip")
    if not tip then return false, "no item window" end
    pcall(ShowUIPanel, tip)
    local ok = pcall(tip.SetHyperlink, tip, "item:" .. a.itemID)
    return ok, ok and "item shown" or "item not cached yet"
  end
  return false, "not allowed"
end

-- Source chips (spec 8.3): text and colour, never colour alone; this is
-- where the data came from, not how sure a model is.
M.CHIP = { observed = { "Observed", "66dd77" }, verified = { "Verified", "66dd77" }, community = { "Community", "d4a84a" },
  inferred = { "Estimated", "8fb3ff" }, unknown = { "Unknown", "8f96a6" } }
M.CHIP_TEXT = {
  observed = "Observed: seen in your game",
  verified = "Verified on WoW Forever",
  community = "Community data (Classic sources); may differ on Forever",
  inferred = "Estimated from other data",
  unknown = "Unknown: no source to back it",
}
function M.Chip(conf)
  local c = M.CHIP[conf] or M.CHIP.unknown
  return string.format("|cff%s[%s]|r", c[2], c[1])
end

function M:IsDone(candidateId)
  if not candidateId then return false end
  for _, f in ipairs(type(ns.db.char.adviceFeedback) == "table" and ns.db.char.adviceFeedback or {}) do
    if f.id == candidateId and f.v == "done" then return true end
  end
  return false
end

-- "Snapshot 12 min old" (spec 8.1 status: no fake spinners, there is no live link)
function M:Status()
  local snaps = rawget(_G, "Outrider_Snapshots")
  local snap = type(snaps) == "table" and snaps[ns.db.key]
  if not snap then return "No snapshot yet" end
  local age = math.max(0, time() - (snap.askedAt or snap.takenAt or time()))
  local mins = math.floor(age / 60)
  local t = mins < 1 and "Snapshot just taken" or (mins < 120 and string.format("Snapshot %d min old", mins)
    or string.format("Snapshot %d h old", math.floor(mins / 60)))
  if mins >= 60 then t = t .. ": Ask again for fresh steps" end
  return t
end

M.ONBOARD = "How it works: 1. type a question (and minutes) above and click Ask; 2. press Ctrl+C and give the code to "
  .. "Claude or the companion (ask command); 3. click Paste advice and press Ctrl+V. Your character's name is never sent, "
  .. "and nothing is done for you: every card is a click."

M.REASON_TEXT = {
  ["no advice file"] = "No advice yet. " .. M.ONBOARD,
  ["advice is stale"] = "The advice answers an older snapshot. Click Ask again.",
  ["advice is for another character"] = "That advice is for another character.",
  ["wrong schema"] = "The advice file is from another version and was ignored.",
}

-- Feedback on a card (AI03-05): useful / wrong data / done. Wrong data and
-- done also hide the step from What now? for a day. Local only; the next
-- snapshot carries the recent ones so the companion can take them into account.
M.FEEDBACK = { { "useful", "Useful" }, { "wrong", "Wrong data" }, { "done", "Done" } }
M.FEEDBACK_KEEP = 30
function M:Feedback(item, verdict)
  if type(item) ~= "table" or not item.candidateId then return false, "click a suggestion first" end
  local list = ns.db.char.adviceFeedback
  if type(list) ~= "table" then list = {} ns.db.char.adviceFeedback = list end
  list[#list + 1] = { id = item.candidateId, v = verdict, t = time() }
  while #list > M.FEEDBACK_KEEP do table.remove(list, 1) end
  if (verdict == "wrong" or verdict == "done") and ns.WhatNow then ns.WhatNow:Skip({ key = item.candidateId }) end
  self:Info("advice feedback %s: %s", tostring(item.candidateId), verdict)
  return true, verdict == "useful" and "Noted: useful." or (verdict == "done" and "Marked done; hidden from What now? for a day."
    or "Marked as wrong data; hidden for a day.")
end

-- One line under the answer: the compare (A vs B) or the plan with times.
function M.PlanLine(answer)
  if answer.compare then
    local a, b = answer.compare[1], answer.compare[2]
    local function one(r) return string.format("%s (~%s min, %s%s)", r.title, tostring(r.minutes or "?"), r.label,
      r.group and ", needs a group" or "") end
    return "Compare: " .. one(a) .. "  vs  " .. one(b)
  end
  if answer.plan and #answer.plan > 0 then
    local parts = {}
    for i, r in ipairs(answer.plan) do parts[#parts + 1] = string.format("%d. %s ~%s min", i, r.title, tostring(r.minutes or "?")) end
    local head = answer.planMinutes and string.format("Plan, about %d min%s: ", answer.planMinutes,
      answer.budget and (" of " .. answer.budget) or "") or "Plan: "
    return head .. table.concat(parts, "  ")
  end
  return ""
end

-- "45", "45 min", "1h" -> minutes (5..600), or nil
function M.Minutes(text)
  text = tostring(text or ""):lower()
  local h = tonumber(text:match("^%s*(%d+%.?%d*)%s*h"))
  local n = h and h * 60 or tonumber(text:match("^%s*(%d+)"))
  if not n then return nil end
  return math.max(5, math.min(600, math.floor(n + 0.5)))
end

function M:Activity()
  local items, why = self:Items()
  if #items > 0 then return #items .. " suggestions in the Advisor tab" end
  return M.REASON_TEXT[why] or tostring(why)
end

-- Which of the three steps you're on (premium rebuild 2026-11-18): 1 ask,
-- 2 copy the snapshot to your AI, 3 paste its advice. done = how many are done.
function M:Step()
  local items, _, answer = self:Items()
  if answer or #items > 0 then return 3, 3 end
  local asked = ns.Snapshot and ns.Snapshot.askedThisSession or ns.db.char.askPending
  if asked then return 3, 2 end
  return 1, 0
end

-- The AI Advisor switch drives the XP session recorder (SessionXP) and the
-- next-hour briefing (NextSession) together. Both are optional modules: when
-- they aren't installed the switch is hidden.
function M:HasCoach() return ns.SessionXP ~= nil end
function M:CoachOn()
  local s = ns.SessionXP
  return s ~= nil and s.enabled and true or false
end
function M:SetCoach(on)
  on = on and true or false
  if not ns.SessionXP then return false end
  ns.Modules:SetEnabled("SessionXP", on)
  if ns.NextSession then ns.Modules:SetEnabled("NextSession", on) end
  self:Info("AI Advisor %s", on and "on" or "off")
  return true
end
function M:CoachNote()
  if not self:CoachOn() then
    return "Off. Turn it on and Outrider keeps a private log of your XP, quests and zones, then plans your next hour after you log out."
  end
  local parts = {}
  local ok, rec = pcall(function() return ns.SessionXP:Activity() end)
  if ok and rec then parts[#parts + 1] = "Recording: " .. tostring(rec) end
  if ns.NextSession then
    local ok2, plan = pcall(function() return ns.NextSession:Activity() end)
    if ok2 and plan then parts[#parts + 1] = tostring(plan) end
  end
  return table.concat(parts, "  ||  ")
end
function M:OpenPlan()
  if ns.NextSession and ns.NextSession.Open then ns.Safe("advisor:nextsession", ns.NextSession.Open, ns.NextSession) end
end

ns.Hub:AddTab("advisor", "Advisor", function(p)
  -- the three steps as a strip of numbered tiles
  p.steps = {}
  local STEPS = { { "Ask", "Type a question, then Ask" }, { "Copy", "Copy the code into your AI" }, { "Paste", "Paste its advice back" } }
  for i, st in ipairs(STEPS) do
    local t = CreateFrame("Frame", nil, p, ns.Theme:BackdropTemplate())
    t:SetHeight(44)
    t.num = UI.Display(t, "page", "goldText")
    t.num:SetPoint("LEFT", 12, 0)
    t.num:SetText(tostring(i))
    t.title = UI.Text(t, "large", "text")
    t.title:SetPoint("TOPLEFT", 44, -7)
    t.title:SetText(st[1])
    t.hint = UI.Text(t, "small", "muted")
    t.hint:SetPoint("TOPLEFT", t.title, "BOTTOMLEFT", 0, -2)
    t.hint:SetText(st[2])
    p.steps[i] = t
  end
  local function placeSteps()
    local w = (p:GetWidth() or 900) - 4
    local tw = math.floor((w - 20) / 3)
    for i, t in ipairs(p.steps) do
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", (i - 1) * (tw + 10), 0)
      t:SetWidth(tw)
    end
  end
  placeSteps()
  if p.HookScript then p:HookScript("OnSizeChanged", placeSteps) end
  -- AI Advisor switch (Gary, 2026-11-19): turns the private session recorder
  -- and next-hour plan on or off here instead of /ride xp60 and
  -- /ride nextsession. Only shown when those modules are installed.
  p.coach = CreateFrame("Frame", nil, p)
  p.coach:SetHeight(28)
  p.coach:SetPoint("TOPLEFT", 0, -54)
  p.coach:SetPoint("RIGHT", p, "RIGHT", -4, 0)
  p.coach.switch = UI:Check(p.coach, "AI Advisor", function() return M:CoachOn() end,
    function(on) M:SetCoach(on) if p.Refresh then p:Refresh() end end)
  p.coach.switch:SetPoint("LEFT", 0, 0)
  p.coach.switch:SetWidth(150)
  p.coach.plan = UI:PrimaryButton(p.coach, "Next hour plan", 130, function() M:OpenPlan() end)
  p.coach.plan:SetPoint("LEFT", p.coach.switch, "RIGHT", 8, 0)
  p.coach.note = UI.Text(p.coach, "small", "muted")
  p.coach.note:SetPoint("LEFT", p.coach.plan, "RIGHT", 10, 0)
  p.coach.note:SetPoint("RIGHT", p.coach, "RIGHT", 0, 0)
  p.coach.note:SetJustifyH("LEFT")
  -- your question and time (AI03): they go into the snapshot, so the
  -- companion answers what you asked in game
  p.q = UI:SearchBox(p, 360, "Your question, e.g. what should I do next?")
  p.q:SetPoint("TOPLEFT", 0, M:HasCoach() and -90 or -56)
  p.q:SetText(ns.db.char.askQuestion or "")
  p.q:HookScript("OnTextChanged", function(box) ns.db.char.askQuestion = (box:GetText() or ""):sub(1, 200) end)
  p.mins = UI:SearchBox(p, 70, "minutes")
  p.mins:SetPoint("LEFT", p.q, "RIGHT", 6, 0)
  p.mins:SetText(ns.db.char.askMinutes and tostring(ns.db.char.askMinutes) or "")
  p.mins:HookScript("OnTextChanged", function(box) ns.db.char.askMinutes = M.Minutes(box:GetText()) end)
  p.askTop = UI:PrimaryButton(p, "Ask", 80, function() ns.Snapshot:AskAdvisor() end)
  p.askTop:SetPoint("LEFT", p.mins, "RIGHT", 6, 0)
  p.status = UI.Text(p, "small", "muted")
  p.status:SetPoint("LEFT", p.askTop, "RIGHT", 10, 0)
  -- the answer (schema 2): headline, summary and what it couldn't check
  p.answer = UI:Card(p, true)
  p.answer:SetPoint("TOPLEFT", p.q, "BOTTOMLEFT", 0, -10)
  p.answer:SetHeight(124)
  p.answer:SetPoint("RIGHT", p, "RIGHT", -4, 0)
  p.answer.headline = UI.Display(p.answer, "card", "text")
  p.answer.headline:SetPoint("TOPLEFT", 12, -10)
  p.answer.headline:SetPoint("RIGHT", p.answer, "RIGHT", -12, 0)
  p.answer.summary = UI.Text(p.answer, "normal", "body")
  p.answer.summary:SetPoint("TOPLEFT", 12, -34)
  p.answer.summary:SetPoint("RIGHT", p.answer, "RIGHT", -12, 0)
  p.answer.summary:SetJustifyH("LEFT") p.answer.summary:SetJustifyV("TOP")
  p.answer.summary:SetHeight(44)
  p.answer.plan = UI.Text(p.answer, "small", "goldText")
  p.answer.plan:SetPoint("TOPLEFT", 12, -82)
  p.answer.plan:SetPoint("RIGHT", p.answer, "RIGHT", -12, 0)
  p.answer.plan:SetJustifyH("LEFT")
  p.answer.limits = UI.Text(p.answer, "small", "muted")
  p.answer.limits:SetPoint("TOPLEFT", 12, -100)
  p.answer.limits:SetPoint("RIGHT", p.answer, "RIGHT", -12, 0)
  p.answer.limits:SetJustifyH("LEFT")
  p.head = UI.Text(p, "small", "muted")
  p.head:SetPoint("TOPLEFT", p.answer, "BOTTOMLEFT", 0, -8)
  p.head:SetPoint("RIGHT", p, "RIGHT", -4, 0) p.head:SetJustifyH("LEFT")
  p.list = UI:ScrollList(p, {
    rows = 8, rowHeight = 40,
    render = function(row, item)
      local done = M:IsDone(item.candidateId)
      row.text:SetText((done and "|cff66dd77[done]|r " or "") .. item.title .. "  " .. M.Chip(item.confidence)
        .. "\n|cffbbbbbb" .. item.why .. "|r")
    end,
    build = function(row)
      -- hover: the evidence behind the card (AI03-03)
      row:SetScript("OnEnter", function(self)
        local tip, item = rawget(_G, "GameTooltip"), self.item
        if not (tip and item) then return end
        tip:SetOwner(self, "ANCHOR_RIGHT")
        tip:AddLine(item.title, 1, 0.82, 0.3)
        if item.why ~= "" then tip:AddLine(item.why, 0.85, 0.85, 0.85, true) end
        tip:AddLine("Source: " .. (M.CHIP_TEXT[item.confidence] or item.confidence), 0.7, 0.7, 0.7, true)
        if item.candidateId then tip:AddLine("Outrider step: " .. item.candidateId, 0.5, 0.5, 0.5) end
        tip:AddLine("Click to do it. Nothing happens on its own.", 0.5, 0.5, 0.5)
        tip:Show()
      end)
      row:SetScript("OnLeave", function() local tip = rawget(_G, "GameTooltip") if tip then tip:Hide() end end)
    end,
    onClick = function(item)
      p.selected = item
      local ok, msg = M:Perform(item)
      M:Info("advice '%s' -> %s", item.title, tostring(msg))
      p.head:SetText((ok and "" or "|cffff6060") .. tostring(msg))
    end,
  })
  p.list:SetPoint("TOPLEFT", p.head, "BOTTOMLEFT", 0, -8)
  p.list:SetPoint("RIGHT", p, "RIGHT", -4, 0)
  M.page = p
  p.paste = UI:Button(p, "Paste advice", 120, function() M:OpenPaste() end)
  p.paste:SetPoint("TOPLEFT", p.list, "BOTTOMLEFT", 0, -8)
  p.ask = UI:Button(p, "Ask (copy snapshot)", 150, function() ns.Snapshot:AskAdvisor() end)
  p.ask:SetPoint("LEFT", p.paste, "RIGHT", 8, 0)
  -- feedback on the card you last clicked (AI03-05), kept on this PC
  local prev = p.ask
  p.feedback = {}
  for _, f in ipairs(M.FEEDBACK) do
    local b = UI:Button(p, f[2], 96, function()
      local ok, msg = M:Feedback(p.selected, f[1])
      p.head:SetText((ok and "" or "|cffff6060") .. msg)
    end)
    b:SetPoint("LEFT", prev, "RIGHT", 8, 0)
    prev = b
    p.feedback[#p.feedback + 1] = b
  end
  function p:Refresh()
    local items, why, answer = M:Items()
    self.coach:SetShown(M:HasCoach())
    if M:HasCoach() then
      self.coach.switch:Refresh()
      local on = M:CoachOn()
      self.coach.plan:SetShown(on and ns.NextSession ~= nil)
      self.coach.note:SetText(M:CoachNote())
    end
    -- steps: done ones green, the current one gold, the rest quiet
    local cur, done = M:Step()
    for i, t in ipairs(self.steps) do
      local state = i <= done and "good" or i == cur and "gold" or "border"
      ns.Theme:ApplyPanel(t, i == cur and "goldSoft" or "raised", state)
      t.num:SetTextColor(ns.Theme:Color(i <= done and "good" or i == cur and "goldText" or "muted"))
    end
    -- feedback only means something once there is advice to rate
    for _, b in ipairs(self.feedback) do b:SetShown(#items > 0) end
    if answer then
      self.answer:Show()
      self.answer.headline:SetText(answer.headline or "")
      self.answer.summary:SetText(answer.summary or "")
      local line = M.PlanLine(answer)
      local total, done = 0, 0
      for _, r in ipairs(answer.plan or {}) do total = total + 1 if M:IsDone(r.candidateId) then done = done + 1 end end
      if total > 0 and not answer.compare then line = line .. string.format("   |cff8f96a6(%d of %d done)|r", done, total) end
      self.answer.plan:SetText(line)
      local lim = table.concat(answer.limits or {}, "  |  ")
      self.answer.limits:SetText(lim ~= "" and ("Not checked: " .. lim) or "")
      self.head:ClearAllPoints()
      self.head:SetPoint("TOPLEFT", self.answer, "BOTTOMLEFT", 0, -8)
    else
      self.answer:Hide()
      self.head:ClearAllPoints()
      self.head:SetPoint("TOPLEFT", self.q, "BOTTOMLEFT", 0, -10)
    end
    self.list:SetItems(items)
    if self.status then self.status:SetText(M:Status()) end
    self.head:SetText(#items > 0 and "Click a suggestion to do it. Nothing happens on its own."
      or (M.REASON_TEXT[why] or tostring(why)))
  end
end, 50)

-- Paste box (button or the Paste key): Ctrl+V applies it at once, no Accept
-- click. Then the Advisor tab opens so the answer is in front of Gary.
function M:Paste(text)
  local n, why = ns.Advice:Paste(text)
  if n == 0 then return false, M.REASON_TEXT[why] or why end
  self:Info("pasted advice: %d suggestions", n)
  if ns.Hub and ns.Hub.ShowTab then pcall(ns.Hub.ShowTab, ns.Hub, "advisor") end
  if self.page and self.page.Refresh then self.page:Refresh() end
  return true
end

function M:OpenPaste()
  return UI:TextDialog("Paste advice", "", "paste", function(text) return M:Paste(text) end, true)
end

-- Key bindings (Bindings.xml, Key Bindings > AddOns > Outrider). A key press
-- by Gary opens a box; nothing else happens until he copies or pastes.
_G.BINDING_NAME_OUTRIDER_ASK = "Ask: copy a snapshot for your advisor"
_G.BINDING_NAME_OUTRIDER_PASTE = "Paste advice"
function M:AskKey()
  if C.InCombat() then ns.Print("not in combat") return end
  ns.Snapshot:AskAdvisor()
end

ns.AddCommand("paste", "open the Paste advice box (Ctrl+V applies it)", function() M:OpenPaste() end)

ns.AddCommand("ask", "[reload]  snapshot for your advisor: shows a code to copy (or 'reload' to save it to disk)", function(arg)
  if C.InCombat() then ns.Print("not in combat") return end
  ns.Snapshot:AskAdvisor(arg == "reload" and "reload" or nil)
end)

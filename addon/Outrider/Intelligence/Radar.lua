-- Intelligence 2.0 initial user-invoked offline Radar.
-- Deliberately no events polling game in background, no external model, no bridge.
local _, ns = ...
local M = ns:NewModule("OpportunityRadar", {
  title = "Opportunity Radar (offline coach)", phase = "P9", order = 105,
  defaultEnabled = false, defaults = { quiet = true, enabledHud = false, scale = 1, muted = {}, timeBudget = 45 },
})
ns.OpportunityRadar = M
local E, O = ns.IntelEvidence, ns.IntelOpportunity
local function state()
  local c = ns.db.char
  if type(c.radarFeedback) ~= "table" then ns.KeepBad(c.radarFeedback, "Radar:c.radarFeedback") c.radarFeedback = {} end
  return c.radarFeedback
end
local function visible(c, now)
  local f = state()[c.key]
  return not (f and f.untilAt and now < f.untilAt)
end
function M:Feedback(card, verdict, reason)
  if not (card and type(card.candidateId) == "string" and O:Valid(card)) then return false end
  if verdict ~= "useful" and verdict ~= "wrong" and verdict ~= "done" and verdict ~= "snooze" and verdict ~= "dismiss" then return false end
  local store, now = state(), time()
  if not store[card.candidateId] and self:FeedbackCount() >= 80 then
    local oldest, stamp
    for k, v in pairs(store) do
      if not stamp or v.t < stamp then oldest, stamp = k, v.t end
    end
    if not ns.Archive:Put("radarFeedback", store[oldest], { path = "char.radarFeedback[candidateId]", keys = { candidateId = oldest }, scope = "char" }) then return false end
    store[oldest] = nil
  end
  reason = type(reason) == "string" and reason:gsub("|", ""):gsub("[%z\1-\31]", " "):sub(1, 120) or nil
  store[card.candidateId] = { verdict = verdict, t = now, reason = reason,
    untilAt = (verdict == "dismiss" or verdict == "wrong" or verdict == "done") and (now + 86400)
      or verdict == "snooze" and (now + 900) or nil }
  -- Existing WhatNow skip is retained for wrong/dismiss outcomes.
  if verdict == "wrong" or verdict == "dismiss" then ns.WhatNow:Skip({key = card.candidateId}) end
  self.dirty = true
  return true
end
function M:SetTimeBudget(minutes)
  minutes = tonumber(minutes)
  if minutes ~= 30 and minutes ~= 45 and minutes ~= 60 then return false end
  self:Settings().timeBudget = minutes
  return true
end
function M:FeedbackHistory()
  local out = {}
  for id, f in pairs(state()) do
    if type(id) == "string" and type(f) == "table" then
      out[#out + 1] = { candidateId = id, verdict = f.verdict, at = f.t,
        reason = f.reason }
    end
  end
  table.sort(out, function(a, b) return (a.at or 0) > (b.at or 0) end)
  for i = #out, 81, -1 do out[i] = nil end
  return out
end
function M:Mute(kind, on)
  if type(kind) ~= "string" or #kind < 1 or #kind > 40 or kind:find("[%c|]") then return false end
  self:Settings().muted[kind] = on and true or nil
  self.dirty = true
  return true
end
function M:ClearFeedback()
  local old = ns.db.char.radarFeedback
  if type(old) == "table" and next(old) ~= nil and not ns.Archive:Put("radarFeedbackCleared", old, { path = "char.radarFeedback", scope = "char" }) then return false end
  ns.db.char.radarFeedback = {}
  self.dirty = true
  -- Keep WhatNow's independently authored skip history.
end
function M:GoCard(card)
  if not self.enabled or ns.Compat.InCombat() or not O:Valid(card) or
      not (card._candidate and card._candidate.go) then return false end
  return ns.WhatNow:Go(card._candidate)
end
function M:FeedbackCount()
  local n = 0
  for _ in pairs(state()) do n = n + 1 end
  return n
end
function M:Refresh()
  if not self.enabled then return {} end
  if ns.Compat.InCombat() then self.dirty = true return self.cards or {} end
  self.dirty = false
  self.recomputeCount = (self.recomputeCount or 0) + 1
  E:Clear("WhatNow")
  E:Register("WhatNow", "ready")
  local profile = ns.ClassProfiles.Current()
  local now, cards = time(), {}
  -- with the planner on, Radar shows the plan's steps in the plan's order
  -- (one source of recommendations, OI02-R08); off, its own ranking
  local N = ns.NexusCore
  local nexus = N and N:Ready()
  local candidates = nexus and (N:Picks() or {}) or ns.WhatNow:Candidates()
  for _, c in ipairs(candidates) do
    if visible(c, now) and not self:Settings().muted[c.kind] and
      ns.ClassProfiles.Allows(profile.class, profile.role, c.roleHint) then
      local label = c.label or "inferred"
      if label == "observed" or label == "verified" or label == "community" or label == "inferred" then
        local category = c.kind == "quest" and "quest" or c.kind == "gear" and "gear"
          or c.kind == "errand" and "errand" or "generic"
        local ev = E:Record("WhatNow", c.key, category,
          { benefit = c.benefit, confidence = c.confidence, kind = c.kind },
          label)
        local card = O:FromWhatNow(c, profile, ev)
        if card then
          local verdict = state()[card.candidateId]
          -- Small local preference bonus only after an explicit useful vote.
          -- Never promote stale, ineligible or unverified candidates.
          if verdict and verdict.verdict == "useful" then card.score = card.score + 0.02 end
          cards[#cards + 1] = card
        end
      end
    end
  end
  self.cardsKey = nexus and ("nexus|" .. N:ContextKey()) or "radar"
  if nexus then
    for i = #cards, 4, -1 do cards[i] = nil end
    self.cards, self.refreshedAt = cards, now
  else
    self.cards, self.refreshedAt = O:Top(cards, 3), now
  end
  return self.cards
end
function M:Cards()
  if not self.enabled then return {} end
  if ns.Compat.InCombat() then return {} end
  local N = ns.NexusCore
  local key = (N and N:Ready()) and ("nexus|" .. N:ContextKey()) or "radar"
  if self.dirty or not self.cards or self.cardsKey ~= key or time() - (self.refreshedAt or 0) > 30 then
    self.cardsKey = key
    return self:Refresh()
  end
  -- A card can expire before our normal refresh interval. Never show stale actions.
  for _, card in ipairs(self.cards) do
    if not O:Valid(card) then return self:Refresh() end
  end
  return self.cards
end
-- Coalesce native game events into a single update; no background polling.
M.EVENT_CATEGORY = {
  BAG_UPDATE_DELAYED = "bag", PLAYER_EQUIPMENT_CHANGED = "gear",
  QUEST_LOG_UPDATE = "quest", QUEST_TURNED_IN = "quest",
  PLAYER_LEVEL_UP = "generic", ZONE_CHANGED_NEW_AREA = "location",
  PLAYER_TALENT_UPDATE = "talent", ACTIVE_TALENT_GROUP_CHANGED = "talent",
  AUCTION_HOUSE_CLOSED = "auction",
}
function M:Signal(category)
  if not self.enabled then return end
  self.dirty = true
  if category then E:Invalidate(category) end
  if ns.Compat.InCombat() then return end
  if self.pending then return end
  self.pending = ns.Timer.After(2, function()
    self.pending = nil
    if not self.enabled then return end
    if ns.Compat.InCombat() then return end
    self:Refresh()
    if self.window and self.window:IsShown() then self:Render() end
  end, "I2 radar coalesced refresh")
end
function M:Open()
  if not self.enabled then ns.Print("Opportunity Radar is off. Enable it under Outrider features.") return end
  if ns.Compat.InCombat() then return end
  if not self.window then
    local p = ns.UI:Window("Outrider_OpportunityRadar", "Opportunity Radar", 460, 300, self:Settings())
    p.rows = {}
    for i = 1, 3 do
      local row = {}
      row.label = ns.UI.Text(p.content, "small", "body")
      row.label:SetPoint("TOPLEFT", 6, -8 - (i - 1) * 80)
      row.label:SetWidth(430)
      row.label:SetJustifyH("LEFT")
      local x = 6
      local function control(name, label, w, cb)
        local b = ns.UI:Button(p.content, label, w, cb)
        b:SetPoint("TOPLEFT", x, -35 - (i - 1) * 80)
        x = x + w + 5
        row[name] = b
      end
      local function verdict(action)
        if row.card then
          M:Feedback(row.card, action)
          M:Render()
        end
      end
      control("why", "Why?", 48, function()
        local c = row.card
        if c then ns.Print("%s: %s [%s, %s]", c.title, c.why, c.label,
          c.evidenceId or "no evidence") end
      end)
      control("go", "Go", 38, function() M:GoCard(row.card) end)
      control("later", "Later", 48, function() verdict("snooze") end)
      control("useful", "Useful", 53, function() verdict("useful") end)
      control("wrong", "Wrong", 51, function() verdict("wrong") end)
      control("done", "Done", 45, function() verdict("done") end)
      control("dismiss", "Dismiss", 62, function() verdict("dismiss") end)
      control("mute", "Mute", 50, function()
        if row.card then M:Mute(row.card.kind, true) M:Render() end
      end)
      p.rows[i] = row
    end
    self.window = p
  end
  self:Render()
  self.window:Show()
end
function M:Render()
  if not self.window then return end
  local cards = self:Cards()
  for i, row in ipairs(self.window.rows) do
    local c = cards[i]
    row.card = c
    row.label:SetText(c and string.format("%d. %s [%s] - %s", i, c.title, c.label, c.where)
      or (i == 1 and "No verified opportunities available." or ""))
    row.why:SetShown(c ~= nil)
    row.go:SetShown(c ~= nil and c._candidate.go ~= nil)
    row.later:SetShown(c ~= nil)
    row.useful:SetShown(c ~= nil)
    row.wrong:SetShown(c ~= nil)
    row.done:SetShown(c ~= nil)
    row.dismiss:SetShown(c ~= nil)
    row.mute:SetShown(c ~= nil)
  end
end
function M:OnEnable()
  self.cards = nil
  self.dirty = true
  -- Event registration is strictly opt-in; the disabled module uses no timers.
  for name, category in pairs(self.EVENT_CATEGORY) do
    local categoryForEvent = category
    self:On(name, function(mod) mod:Signal(categoryForEvent) end)
  end
  self:On("OTR_INTELLIGENCE_PROFILE_CHANGED", function(mod) mod:Signal("talent") end)
  self:On("PLAYER_REGEN_ENABLED", function(mod)
    if mod.dirty then mod:Signal() end
  end)
end
function M:OnDisable()
  if self.pending then self.pending:Cancel() self.pending = nil end
  self.dirty = false
  E:Clear("WhatNow")
  self.cards = nil
  if self.window then self.window:Hide() end
end
function M:Activity()
  return "offline only; " .. tostring(#(self.cards or {})) .. " suggestions"
end
ns.AddCommand("radar", "show | time 30|45|60 | feedback | reset | unmute <kind>  offline coach", function(arg)
  arg = type(arg) == "string" and arg:lower():match("^%s*(.-)%s*$") or ""
  local mins = arg:match("^time%s+(%d+)$")
  if mins then
    ns.Print(M:SetTimeBudget(mins) and ("Coach planning budget: " .. mins .. " minutes")
      or "Use time 30, 45 or 60.")
  elseif arg == "feedback" then
    local history = M:FeedbackHistory()
    local totals = {}
    for _, item in ipairs(history) do totals[item.verdict] = (totals[item.verdict] or 0) + 1 end
    ns.Print("Coach feedback: %d stored (useful %d, wrong %d, done %d, later %d, dismissed %d)",
      #history, totals.useful or 0, totals.wrong or 0, totals.done or 0,
      totals.snooze or 0, totals.dismiss or 0)
  elseif arg == "reset" then
    M:ClearFeedback()
    ns.Print("Coach feedback reset; independent What now? skips remain unchanged.")
  elseif arg:match("^unmute%s+") then
    local kind = arg:match("^unmute%s+(%S+)$")
    ns.Print(kind and M:Mute(kind, false) and ("Coach unmuted: " .. kind)
      or "Usage: /ride radar unmute <category>")
  elseif arg == "" or arg == "show" then M:Open()
  else ns.Print("Usage: /ride radar show|time 30|45|60|feedback|reset|unmute <category>") end
end)

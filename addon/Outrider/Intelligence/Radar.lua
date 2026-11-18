-- Intelligence 2.0 initial user-invoked offline Radar.
-- Deliberately no events polling game in background, no external model, no bridge.
local _, ns = ...
local M = ns:NewModule("OpportunityRadar", {
  title = "Opportunity Radar (offline coach)", phase = "P9", order = 105,
  defaultEnabled = false, defaults = { quiet = true, enabledHud = false, scale = 1, muted = {} },
})
ns.OpportunityRadar = M
local E, O = ns.IntelEvidence, ns.IntelOpportunity
local function state()
  local c = ns.db.char
  if type(c.radarFeedback) ~= "table" then c.radarFeedback = {} end
  return c.radarFeedback
end
local function visible(c, now)
  local f = state()[c.key]
  return not (f and f.untilAt and now < f.untilAt)
end
function M:Feedback(card, verdict)
  if not (card and type(card.candidateId) == "string" and O:Valid(card)) then return false end
  if verdict ~= "useful" and verdict ~= "wrong" and verdict ~= "done" and verdict ~= "snooze" and verdict ~= "dismiss" then return false end
  local store, now = state(), time()
  if not store[card.candidateId] and self:FeedbackCount() >= 80 then
    local oldest, stamp
    for k, v in pairs(store) do
      if not stamp or v.t < stamp then oldest, stamp = k, v.t end
    end
    store[oldest] = nil
  end
  store[card.candidateId] = { verdict = verdict, t = now,
    untilAt = (verdict == "dismiss" or verdict == "wrong" or verdict == "done") and (now + 86400)
      or verdict == "snooze" and (now + 900) or nil }
  -- Existing WhatNow skip is retained for wrong/dismiss outcomes.
  if verdict == "wrong" or verdict == "dismiss" then ns.WhatNow:Skip({key = card.candidateId}) end
  self.dirty = true
  return true
end
function M:Mute(kind, on)
  if type(kind) ~= "string" or #kind < 1 or #kind > 40 or kind:find("[%c|]") then return false end
  self:Settings().muted[kind] = on and true or nil
  self.dirty = true
  return true
end
function M:ClearFeedback()
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
  E:Clear()
  E:Register("WhatNow", "ready")
  local profile = ns.ClassProfiles.Current()
  local now, cards = time(), {}
  local candidates = ns.WhatNow:Candidates()
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
        if card then cards[#cards + 1] = card end
      end
    end
  end
  self.cards, self.refreshedAt = O:Top(cards, 3), now
  return self.cards
end
function M:Cards()
  if not self.enabled then return {} end
  if ns.Compat.InCombat() then return {} end
  if self.dirty or not self.cards or time() - (self.refreshedAt or 0) > 30 then return self:Refresh() end
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
  E:Clear()
  self.cards = nil
  if self.window then self.window:Hide() end
end
function M:Activity()
  return "offline only; " .. tostring(#(self.cards or {})) .. " suggestions"
end
ns.AddCommand("radar", "show the offline Opportunity Radar (feature is off by default)", function() M:Open() end)

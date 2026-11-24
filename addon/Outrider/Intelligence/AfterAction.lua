-- Intelligence/AfterAction.lua  (OI03-11)
-- Home > After action: how a play session actually went, from what Outrider
-- recorded. Every number comes straight from its source and adds up:
--   XP per hour  the XP recorder's merged session (SessionXP), wall-clock hours
--   gold         the outcome recorder's money events for that session
--                (EconomyOutcomes.Summary: realized, transfers apart,
--                confirmed sales; the loot value estimate shown apart)
--   time         the activity timeline's totals for that session's segments
--   milestones   the chronicle's entries in that session
--   estimates    how long quests and walking trips take you (Estimator),
--                with the range and the sample count, or "not enough yet"
--   compared     only with your own earlier sessions, as plain numbers: no
--                claim that anything made you faster
--   next time    ideas from the planner or What now?, labelled as ideas
-- Partial sessions say so (in progress, cut short by a reload, logout or
-- disconnect, XP not readable). "Show an example" fills the page with
-- clearly labelled example data, for screenshots and first looks.

local _, ns = ...
local P = { MIN_PAST = 3 }
ns.AfterAction = P

local function median(t)
  table.sort(t)
  local n = #t
  if n == 0 then return nil end
  return n % 2 == 1 and t[(n + 1) / 2] or (t[n / 2] + t[n / 2 + 1]) / 2
end
local function minutes(s) if not s then return "?" end return s < 90 and (math.floor(s + 0.5) .. " s") or (math.floor(s / 60 + 0.5) .. " min") end
local function money(c) return ns.Prices and ns.Prices.Money(math.abs(c or 0)) or tostring(c) end

-- the XP part: { xpPerHour, xp, seconds, labels = {...} } or { why }
function P.XP(psId, merged)
  local s
  for _, m in ipairs(merged or {}) do if m.playSessionId == psId then s = m end end
  if not s then return { why = "no XP record for this session (the XP recorder is opt-in)" } end
  local labels = {}
  local current = ns.PlaySession and ns.PlaySession:Id() == psId
  if current and s.final ~= true then labels[#labels + 1] = "in progress" end
  if s.endReason == "interrupted" then labels[#labels + 1] = "cut short (no logout seen)" end
  local f = s.flags or {}
  if f.xpUnknown or s.xpVerified == false then labels[#labels + 1] = "XP not fully readable" end
  if f.clockUnknown then labels[#labels + 1] = "time not fully readable" end
  if (s.segments or 1) > 1 then labels[#labels + 1] = string.format("%d parts (reloads)", s.segments) end
  local secs = tonumber(s.durationSeconds) or 0
  return { xp = s.xpEarned, seconds = secs, xpPerHour = secs >= 60 and (s.xpEarned or 0) * 3600 / secs or nil, labels = labels }
end

function P.Activity(psId, records, live)
  local totals, sum = {}, 0
  for _, r in ipairs(records or {}) do
    if r.playSessionId == psId then
      local t = r.totals or {}
      if live and live.rec == r then t = live.totals end
      for k, v in pairs(t) do totals[k] = (totals[k] or 0) + v sum = sum + v end
    end
  end
  return totals, sum
end

function P.Report(psId)
  local rep = { sessionId = psId }
  local X = ns.SessionXP
  rep.xp = P.XP(psId, X and X.Merged and X:Merged() or {})
  local O = ns.Outcomes
  local store = O and O:Store() or {}
  local events = {}
  for _, e in ipairs(store.events or {}) do if e.sessionId == psId then events[#events + 1] = e end end
  local sales = {}
  for _, s in ipairs(store.sales or {}) do if s.playSessionId == psId then sales[#sales + 1] = s end end
  local current = ns.PlaySession and ns.PlaySession:Id() == psId
  local estimate = current and ns.LootLog and ns.LootLog.SessionValue and ns.LootLog:SessionValue() or nil
  rep.gold = ns.EconomyOutcomes and ns.EconomyOutcomes.Summary(events, sales, { estimatedLoot = estimate }) or {}
  local A = ns.ActivityTimeline
  local live
  if current and A and A.rec then local t = A:Totals() live = { rec = A.rec, totals = t } end
  rep.activity, rep.played = P.Activity(psId, store.activity, live)
  rep.deaths = 0
  for _, e in ipairs(events) do if e.kind == "death" then rep.deaths = rep.deaths + 1 end end
  -- milestones in this session
  rep.milestones = {}
  local first, last
  for _, e in ipairs(events) do first = math.min(first or e.at, e.at) last = math.max(last or e.at, e.at) end
  for _, e in ipairs(store.chronicle or {}) do
    if first and e.at >= first and e.at <= last then rep.milestones[#rep.milestones + 1] = e.text end
  end
  -- how long things take you
  local E = ns.Estimator
  if E and ns.QuestTimes then
    local _, gameBuild = ns.Compat.Call("GetBuildInfo")
    local models = E.Fit(E.QuestSamples(ns.QuestTimes:Mine()), { build = ns.Compat.Readable(gameBuild), prior = ns.Journey and ns.Journey.QUEST_TIME })
    local level = tonumber(ns.Compat.Readable(ns.Compat.Call("UnitLevel", "player"))) or 1
    local key = "L" .. (math.floor((level - 1) / 5) * 5 + 1) .. "|solo"
    rep.questTime = E.Predict(models, key, { prior = ns.Journey and ns.Journey.QUEST_TIME })
  end
  if E and ns.TravelTimes then
    rep.walking = E.FitOne(E.TravelSamples(ns.TravelTimes:List(store)), {})
  end
  -- compared with your own earlier sessions, numbers only
  local past = {}
  for _, m in ipairs(X and X.Merged and X:Merged() or {}) do
    if m.playSessionId ~= psId and m.final == true and m.xpVerified == true and (tonumber(m.durationSeconds) or 0) >= 600 then
      past[#past + 1] = m.xpEarned * 3600 / m.durationSeconds
    end
  end
  rep.pastSessions = #past
  rep.pastMedianXPh = #past >= P.MIN_PAST and median(past) or nil
  -- ideas for next time
  rep.ideas = {}
  local N = ns.NexusCore
  local picks = N and N.Ready and N:Ready() and N:Picks(3) or (ns.WhatNow and ns.WhatNow.enabled and ns.WhatNow:List()) or {}
  for i, p in ipairs(picks) do if i <= 3 then rep.ideas[#rep.ideas + 1] = tostring(p.title) end end
  return rep
end

function P.Demo()
  return { demo = true, sessionId = "example", xp = { xp = 18400, seconds = 5400, xpPerHour = 12267, labels = { "example data" } },
    gold = { realizedNet = 25400, transfers = 0, confirmedSales = 2, knownFees = 300, salesWithUnknownFee = 0, estimatedLoot = 41000 },
    activity = { quest = 2700, travel = 900, unclassified = 1200, inactive = 600 }, played = 5400, deaths = 1,
    milestones = { "Reached level 23", "Turned in The Defias Brotherhood", "First visit to Westfall" },
    questTime = { value = 640, lo = 300, hi = 1100, n = 14, basis = "observed" },
    walking = { value = 1.3, lo = 1.0, hi = 1.8, n = 9, basis = "observed" },
    pastSessions = 6, pastMedianXPh = 10800, ideas = { "Pick up The Coast Isn't Clear", "Repair at Sentinel Hill" } }
end

-- the lines the page shows (pure, testable)
function P.Lines(rep)
  local L = {}
  local x = rep.xp or {}
  L.stats = {
    { cap = "XP PER HOUR (WALL CLOCK)", value = x.xpPerHour and tostring(math.floor(x.xpPerHour + 0.5)) or "-", note = x.why or (tostring(x.xp or 0) .. " XP") },
    { cap = "GOLD (REAL)", value = (rep.gold.realizedNet or 0) < 0 and ("-" .. money(rep.gold.realizedNet)) or money(rep.gold.realizedNet), color = "gold",
      note = (rep.gold.transfers or 0) ~= 0 and ("transfers apart: " .. money(rep.gold.transfers)) or "no transfers" },
    { cap = "TIME PLAYED", value = minutes(rep.played), note = string.format("%d death%s", rep.deaths or 0, rep.deaths == 1 and "" or "s") },
  }
  L.labels = (x.labels and #x.labels > 0) and ("This session: " .. table.concat(x.labels, ", ") .. ".") or nil
  L.bars = {}
  local total = 0
  for _, v in pairs(rep.activity or {}) do total = total + v end
  local order = { "quest", "travel", "dungeon", "crafting", "recovery", "unclassified", "inactive" }
  for _, k in ipairs(order) do
    local v = rep.activity and rep.activity[k]
    if v and v > 0 then L.bars[#L.bars + 1] = { label = k, fill = total > 0 and v / total or 0, text = minutes(v) } end
  end
  local g = rep.gold
  L.gold = string.format("Confirmed sales: %d (auction cut %s%s).%s", g.confirmedSales or 0, money(g.knownFees or 0),
    (g.salesWithUnknownFee or 0) > 0 and (", " .. g.salesWithUnknownFee .. " with an unknown cut") or "",
    g.estimatedLoot and ("  Loot value (an estimate, not gold you have): " .. money(g.estimatedLoot) .. ".") or "")
  local q = rep.questTime
  L.quest = q and q.value and string.format("A quest takes you about %s (%s to %s, %d sample%s, %s)", minutes(q.value), minutes(q.lo), minutes(q.hi),
    q.n or 0, q.n == 1 and "" or "s", q.basis == "prior" and "Outrider's default: not enough of yours yet" or q.basis) or "Not enough finished quests yet to say how long they take you."
  local w = rep.walking
  L.walk = w and w.value and string.format("Walking trips take %.1fx the planned time (%.1f to %.1f, %d trips).", w.value, w.lo, w.hi, w.n or 0)
    or "Not enough walking trips yet to compare with the planner."
  L.compare = rep.pastMedianXPh and x.xpPerHour and string.format("Your earlier sessions: %d XP an hour (median of %d). This one: %d.",
    math.floor(rep.pastMedianXPh + 0.5), rep.pastSessions, math.floor(x.xpPerHour + 0.5))
    or string.format("Not enough earlier sessions to compare (%d of %d).", rep.pastSessions or 0, P.MIN_PAST)
  L.milestones = #(rep.milestones or {}) > 0 and table.concat(rep.milestones, "\n") or "No milestones recorded this session."
  L.ideas = #(rep.ideas or {}) > 0 and ("Ideas for next time (not a prediction): " .. table.concat(rep.ideas, "; ") .. ".") or "No ideas yet: open What now? once."
  return L
end

-- ------------------------------------------------------------ page
P.showDemo = false
ns.Hub:AddTab("afteraction", "After action", function(p)
  local function refresh() p:Refresh() end
  local function rep() return P.showDemo and P.Demo() or P.Report(ns.PlaySession and ns.PlaySession:Id()) end
  local function lines() return P.Lines(rep()) end
  ns.UI:FormPage(p, {
    { "header", "After action" },
    { "note", "How your session really went, from what Outrider recorded. 1. Switch recording on. 2. Play. 3. Come back here." },
    { "check", "Record outcomes (private, opt-in)", function() return ns.Outcomes and ns.Outcomes.enabled end,
      function(on) ns.Modules:SetEnabled("Outcomes", on) refresh() end, "kept on this PC only" },
    { "note", function() return P.showDemo and "|cffffc84dExample data: not your play.|r" or "" end },
    { "stats", function() return lines().stats end },
    { "note", function() return lines().labels or "" end },
    { "header", "Where the time went" },
    { "bars", function() return lines().bars end },
    { "note", function() return lines().gold end },
    { "header", "How long things take you" },
    { "note", function() local l = lines() return l.quest .. "\n" .. l.walk .. "\n" .. l.compare end },
    { "header", "Milestones" },
    { "note", function() return lines().milestones end },
    { "note", function() return lines().ideas end },
    { "buttons", { { "Export the chronicle", function()
        local O = ns.Outcomes
        ns.UI:TextDialog("Chronicle", O and ns.Chronicle:Export(O) or "", "copy")
      end, 170 },
      { "Show an example", function() P.showDemo = not P.showDemo refresh() end, 150 } }, plain = true },
  })
end, 1.6)

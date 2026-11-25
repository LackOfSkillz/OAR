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
  -- archived records count too (review OI-FR02): a session's rows may have
  -- moved to the archive since
  local AR = ns.Archive
  local events = AR:WithActive("outcomeEvents", store.events, { where = function(e) return e.sessionId == psId end })
  local sales = AR:WithActive("confirmedSales", store.sales, { where = function(s) return s.playSessionId == psId end })
  local current = ns.PlaySession and ns.PlaySession:Id() == psId
  local estimate = current and ns.LootLog and ns.LootLog.SessionValue and ns.LootLog:SessionValue() or nil
  rep.gold = ns.EconomyOutcomes and ns.EconomyOutcomes.Summary(events, sales, { estimatedLoot = estimate }) or {}
  local A = ns.ActivityTimeline
  local live
  if current and A and A.rec then local t = A:Totals() live = { rec = A.rec, totals = t } end
  rep.activity, rep.played = P.Activity(psId, AR:WithActive("activitySessions", store.activity), live)
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
    rep.walking = E.FitOne(E.TravelSamples(ns.TravelTimes:History(store)), {})
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

-- ------------------------------------------------------------ evidence (OI03-14)
-- A sanitized, repeatable summary for measuring how well Outrider's own
-- figures match what you did. No names, no character keys, no times: counts,
-- medians and map ids only, the same input always giving the same output.
--   quests     held-out comparison of Journey's fixed estimate (prior only)
--              with your personal estimator on the same later samples
--   routes     walking trips paired by route (from map > to map): actual
--              time against the planner's estimate; routes walked once are
--              listed as unmatched, not compared
--   outcomes   counts by kind; completions after a Go are "likely", never proof
--   sessions   sessions with and without a planner-attributed outcome are
--              compared only when matched on level band and game build, with
--              at least MIN_MATCHED of each; otherwise "not compared"
P.MIN_MATCHED = 3
local function med(t) local c = {} for i, v in ipairs(t) do c[i] = v end return median(c) end
function P.Evidence(input)
  input = input or {}
  local out = { schema = 1, fixture = input.fixture or nil }
  local E = ns.Estimator
  -- quests: prior only vs personal, same held-out split
  local qs = E and E.QuestSamples(input.quests) or {}
  table.sort(qs, function(a, b) if a.at ~= b.at then return (a.at or 0) < (b.at or 0) end return a.value < b.value end)
  local prior = input.prior or 300
  local cut = math.floor(#qs * (E and E.TRAIN or 0.7))
  local test, train = {}, {}
  for i, x in ipairs(qs) do if i <= cut then train[#train + 1] = x else test[#test + 1] = x end end
  local q = { samples = #qs, train = #train, test = #test }
  if E and #test >= E.MIN then
    local models = E.Fit(train, { prior = prior, now = train[#train] and train[#train].at })
    local pe, me = {}, {}
    for _, x in ipairs(test) do
      pe[#pe + 1] = math.abs(x.value - prior)
      local m = E.Predict(models, x.key, { prior = prior })
      if m.value then me[#me + 1] = math.abs(x.value - m.value) end
    end
    q.priorMedianAbsError, q.personalMedianAbsError = med(pe), med(me)
    q.note = "same later samples for both; lower is closer"
  else
    q.note = "not enough later samples to compare"
  end
  out.quests = q
  -- routes
  local routes, matched, unmatched = {}, {}, 0
  for _, t in ipairs(input.trips or {}) do
    if t.walking and t.seconds and t.estimate and t.fromMap and t.toMap then
      local k = tostring(t.fromMap) .. ">" .. tostring(t.toMap)
      routes[k] = routes[k] or { actual = {}, estimate = {} }
      table.insert(routes[k].actual, t.seconds)
      table.insert(routes[k].estimate, t.estimate)
    end
  end
  local keys = {}
  for k in pairs(routes) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local r = routes[k]
    if #r.actual >= 2 then
      matched[#matched + 1] = { route = k, trips = #r.actual, medianActual = med(r.actual), medianEstimate = med(r.estimate),
        ratio = med(r.actual) / math.max(1, med(r.estimate)) }
    else
      unmatched = unmatched + 1
    end
  end
  out.routes = { paired = matched, unmatched = unmatched, note = "routes walked once are not compared" }
  -- outcomes
  local kinds, likely, unknown = {}, 0, 0
  for _, e in ipairs(input.events or {}) do
    kinds[e.kind] = (kinds[e.kind] or 0) + 1
    if e.attribution == "likely" then likely = likely + 1 else unknown = unknown + 1 end
  end
  out.outcomes = { byKind = kinds, likely = likely, unknown = unknown, note = "Likely means it followed a Go on a plan step about the same thing; that is not proof the plan led to it" }
  -- sessions: matched comparison only
  local used = {}
  for _, e in ipairs(input.events or {}) do if e.attribution == "likely" and e.sessionId then used[e.sessionId] = true end end
  local groups = {}
  for _, m in ipairs(input.sessions or {}) do
    if m.final == true and m.xpVerified == true and (tonumber(m.durationSeconds) or 0) >= 600 then
      local band = m.levelStart and (math.floor((m.levelStart - 1) / 5) * 5 + 1) or "?"
      local k = tostring(band) .. "|" .. tostring(m.build)
      groups[k] = groups[k] or { with = {}, without = {} }
      local rate = m.xpEarned * 3600 / m.durationSeconds
      if used[m.playSessionId] then table.insert(groups[k].with, rate) else table.insert(groups[k].without, rate) end
    end
  end
  local compared = {}
  local gk = {}
  for k in pairs(groups) do gk[#gk + 1] = k end
  table.sort(gk)
  for _, k in ipairs(gk) do
    local g = groups[k]
    if #g.with >= P.MIN_MATCHED and #g.without >= P.MIN_MATCHED then
      compared[#compared + 1] = { stratum = k, withPlan = #g.with, withoutPlan = #g.without,
        medianWith = med(g.with), medianWithout = med(g.without) }
    end
  end
  out.sessions = { compared = compared,
    note = #compared > 0 and "A difference between matched groups is an observation, not proof of cause"
      or "Not compared: not enough matched sessions with and without the planner" }
  return out
end

-- this character's evidence, from the live stores
function P.MyEvidence()
  local O = ns.Outcomes
  local store = O and O:Store() or {}
  return P.Evidence({ quests = ns.QuestTimes and ns.QuestTimes:Mine() or {}, trips = ns.TravelTimes and ns.TravelTimes:History(store) or store.travel or {},
    events = store.events or {}, sessions = ns.SessionXP and ns.SessionXP:Merged() or {},
    prior = ns.Journey and ns.Journey.QUEST_TIME })
end

-- the evidence as Markdown text (same input, same text), for the export
-- button, the bench tool and the tests
function P.EvidenceText(ev)
  local L = { "# AfterAction measurement report (OI03-14)", "",
    ev.fixture and "Fixture data from a fixed seed, not anyone's play. Same fixture, same report." or "Your own records, without names or times.", "" }
  local q = ev.quests
  L[#L + 1] = "## Quest times: Journey's fixed estimate vs your personal estimate"
  L[#L + 1] = ""
  L[#L + 1] = string.format("Samples %d (trained on %d earlier, tested on %d later).", q.samples, q.train, q.test)
  if q.priorMedianAbsError then
    L[#L + 1] = string.format("Median absolute error: fixed estimate %.0f s, personal estimate %.0f s (%s).", q.priorMedianAbsError, q.personalMedianAbsError, q.note)
  else
    L[#L + 1] = "Not compared: " .. q.note .. "."
  end
  L[#L + 1] = ""
  L[#L + 1] = "## Walking routes: planner estimate vs actual"
  L[#L + 1] = ""
  L[#L + 1] = "| Route | Trips | Median actual s | Median estimate s | Actual / estimate |"
  L[#L + 1] = "|---|---|---|---|---|"
  for _, r in ipairs(ev.routes.paired) do
    L[#L + 1] = string.format("| %s | %d | %.0f | %.0f | %.2f |", r.route, r.trips, r.medianActual, r.medianEstimate, r.ratio)
  end
  L[#L + 1] = ""
  L[#L + 1] = string.format("Unmatched routes (walked once, not compared): %d.", ev.routes.unmatched)
  L[#L + 1] = ""
  L[#L + 1] = "## Outcomes"
  L[#L + 1] = ""
  local kinds = {}
  for k, n in pairs(ev.outcomes.byKind) do kinds[#kinds + 1] = k .. " " .. n end
  table.sort(kinds)
  L[#L + 1] = "By kind: " .. table.concat(kinds, ", ") .. "."
  L[#L + 1] = string.format("Attributed likely: %d; unknown: %d. %s.", ev.outcomes.likely, ev.outcomes.unknown, ev.outcomes.note)
  L[#L + 1] = ""
  L[#L + 1] = "## Sessions with and without the planner"
  L[#L + 1] = ""
  for _, c in ipairs(ev.sessions.compared) do
    L[#L + 1] = string.format("- Level band and build %s: with %d sessions, median %.0f XP/h; without %d, median %.0f XP/h.", c.stratum, c.withPlan, c.medianWith, c.withoutPlan, c.medianWithout)
  end
  L[#L + 1] = ev.sessions.note .. "."
  return table.concat(L, "\n") .. "\n"
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

-- Start fresh asks for a second click within ten seconds, then archives
-- this character's records and begins new ones (Outcomes:StartFresh)
P.ARM_SECONDS = 10
function P.StartFresh()
  local now = time()
  if not (P.armedAt and now - P.armedAt <= P.ARM_SECONDS) then
    P.armedAt = now
    ns.Print("Click Start fresh again within %d seconds: your records go to the archive and new ones begin.", P.ARM_SECONDS)
    return false, "armed"
  end
  P.armedAt = nil
  local ok, why = ns.Outcomes:StartFresh()
  ns.Print(ok and "Started fresh. Your old records are kept in the archive." or ("Not reset: " .. tostring(why)))
  return ok, why
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
      { "Export evidence", function() ns.UI:TextDialog("AfterAction evidence", P.EvidenceText(P.MyEvidence()), "copy") end, 150 },
      { "Export my records", function() if ns.Outcomes then ns.UI:TextDialog("My outcome records", ns.Outcomes:ExportText(), "copy") end end, 150 },
      { "Start fresh (archived)", function() P.StartFresh() refresh() end, 170 },
      { "Show an example", function() P.showDemo = not P.showDemo refresh() end, 150 } }, plain = true },
  })
end, 1.6)

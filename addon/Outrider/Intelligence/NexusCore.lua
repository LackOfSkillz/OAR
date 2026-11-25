-- Intelligence/NexusCore.lua  (OI02-11)
-- The Nexus module: state -> opportunities -> graph -> scores -> plan, kept
-- current without getting in the way.
--   * Off by default (blueprint: new functionality behind a flag until accepted).
--   * Re-plans on meaningful events, debounced (DEBOUNCE s), never in combat:
--     a request in combat waits for PLAYER_REGEN_ENABLED.
--   * Every plan records the state revision it was built on; IsStale() says
--     when the state moved on (new gear, gold, place...) or the plan aged out.
--   * The player steers it: Pin (do this step first), Skip (leave it out),
--     Pause and Resume (no re-planning while paused). Saved per character.
--   * Execution boundary: planning never acts. Act(stepId) is the only way a
--     step does anything, it is called from the player's click, and it only
--     runs the producer's own permitted intent (set a waypoint, open a page).
-- Nothing here casts, targets, buys, crafts or moves.

local _, ns = ...
local M = ns:NewModule("Nexus", {
  title = "Nexus planner (development)",
  phase = "P9",
  order = 96,
  defaults = { on = false, pinned = nil, skipped = {}, paused = false },
})
ns.NexusCore = M

M.DEBOUNCE = 2
M.MAX_AGE = 600

function M:Ready() return self.enabled and self:Settings().on end

function M:Context()
  local S, P = ns.NexusState, ns.ClassProfiles
  local gold = S:Get("gold")
  local loc = S:Get("location")
  local st = P and P.StateV4 and P.StateV4() or nil
  local goals = ns.NexusGoals:Active()
  local reserve
  for _, g in ipairs(goals) do if g.reserveCopper then reserve = math.max(reserve or 0, g.reserveCopper) end end
  -- skipping a step is not completing it (OI02-R09): skipped steps are left
  -- out of the pool, and anything that needs them says so
  -- your feedback as a small nudge (Intelligence/Preferences.lua), unless switched off
  local NP, prefs = ns.NexusPreferences, nil
  if NP then
    local ps = NP.Settings(self)
    if ps.on ~= false then prefs = NP.Adjustments(NP.Sources(), ps) end
  end
  -- the session you plan for (OI04-01): time budget, solo or group
  local hz = ns.NexusHorizon and ns.NexusHorizon.Context(self) or {}
  return { budgetSeconds = hz.budgetSeconds, solo = hz.solo, stopRest = hz.stopRest, closing = hz.closing,
    sessionLeft = hz.sessionLeft, reserve = hz.reserve, horizon = hz.horizon,
    preferences = prefs, copper = gold and gold.value, reserveCopper = reserve, mapID = loc and loc.value.mapID,
    faction = st and st.faction ~= "unknown" and st.faction or nil, revision = S:Revision(), now = time() }, goals
end

-- The planning context (OI02-R12): everything a plan depends on besides the
-- world itself. Computed from the data each time, so no change can be missed:
-- the character state revision, the planner switch, every goal's status,
-- priority, objective and reserve, the pin, and the skipped steps. A plan made
-- under another key is stale at once, even before the debounced re-plan runs
-- and even while paused (a paused plan stays on screen, marked stale).
function M:ContextKey()
  local s = self:Settings()
  local parts = { tostring(ns.NexusState:Revision()), s.on and "on" or "off", "pin=" .. tostring(s.pinned) }
  local skipped = {}
  for id in pairs(s.skipped or {}) do skipped[#skipped + 1] = id end
  table.sort(skipped)
  parts[#parts + 1] = "skip=" .. table.concat(skipped, ",")
  local hz = type(s.horizon) == "table" and s.horizon or {}
  parts[#parts + 1] = "horizon=" .. tostring(hz.minutes) .. ":" .. tostring(hz.group) .. ":" .. tostring(hz.stopRest)
  local pr = type(s.prefs) == "table" and s.prefs or {}
  parts[#parts + 1] = "prefs=" .. tostring(pr.on ~= false) .. ":" .. tostring(pr.since)
  local goals = {}
  for _, g in ipairs(ns.NexusGoals:All()) do
    goals[#goals + 1] = table.concat({ tostring(g.goalId), tostring(g.status), tostring(g.priority), tostring(g.objective),
      tostring(g.reserveCopper or 0), tostring(g.target or ""), tostring(g.deadline or "") }, ":")
  end
  table.sort(goals)
  parts[#parts + 1] = "goals=" .. table.concat(goals, ";")
  -- the goals the planner actually uses: with every saved goal paused or
  -- archived (or none saved) that is the implicit What now? goal (OI02-R17)
  local active = {}
  for _, g in ipairs(ns.NexusGoals:Active()) do
    active[#active + 1] = (g.implicit and "implicit:" or "") .. tostring(g.objective) .. ":" .. tostring(g.priority)
  end
  parts[#parts + 1] = "active=" .. table.concat(active, ",")
  return table.concat(parts, "|")
end

-- The key a page's cache of plan picks must match (OI02-R16): the planning
-- context plus the plan generation, so a new plan is never hidden by a cache.
function M:CacheKey() return "nexus|" .. self:ContextKey() .. "|" .. tostring(self.replans or 0) end

-- Is a pick (or a page's copy of one) still usable for display? Checks the
-- plan step itself: plan current, still in it, not skipped or left out, the
-- opportunity's own expiry and its evidence (OI02-R16).
function M:StillShown(id, now) return (self:CheckAct(id, now, { display = true })) end

-- Build a plan now (pure apart from reading state). Returns the stored result.
function M:Replan(why)
  if not self:Ready() then return nil end
  if ns.Compat.InCombat() then self.wanted = why or "combat" return nil end
  if self:Settings().paused then return self.current end
  local ctx, goals = self:Context()
  local contextKey = self:ContextKey()
  local opps, excluded, unavailable, runtime
  if ctx.closing and ns.SessionEnd then
    -- closing time (OI04-03): only the closing steps, within the time left
    opps, excluded, unavailable, runtime = ns.NexusAdapters:Collect({}, ctx.revision, ctx.now,
      { closure = function() return ns.SessionEnd.Candidates(ctx.horizon) end })
  else
    opps, excluded, unavailable, runtime = ns.NexusAdapters:All(ctx.revision, ctx.now)
  end
  local skipped = self:Settings().skipped or {}
  local kept = {}
  for _, o in ipairs(opps) do if not skipped[o.opportunityId] then kept[#kept + 1] = o end end
  local meta = ns.NexusAdapters.MetaAll(runtime)
  local graph = ns.NexusGraph.Build(kept, meta, ctx)
  local ranked, rejected = ns.NexusScore.Rank(graph, goals, ctx)
  -- the pin is a planner input that must pass every constraint (OI02-R01)
  local res = ns.NexusPlanner.Plan(graph, ranked, ctx, { pin = self:Settings().pinned })
  for id, why in pairs(res.unplannable or {}) do if not rejected[id] then rejected[id] = why end end
  if ctx.closing then
    res.closing = true
    if not res.plan then res.why, res.code = "not enough time left for anything: a good moment to stop", "session_over" end
  end
  self.current = { result = res, revision = ctx.revision, contextKey = contextKey, at = ctx.now, runtime = runtime, graph = graph,
    ranked = ranked, rejected = rejected, excluded = excluded, unavailable = unavailable, why = why }
  self.replans = (self.replans or 0) + 1
  ns.Events:Fire("OTR_NEXUS_PLAN", why)
  return self.current
end

function M:IsStale(now)
  local c = self.current
  if not c then return true, "no plan yet" end
  if c.revision ~= ns.NexusState:Revision() then return true, "your character changed since this plan" end
  if c.contextKey ~= self:ContextKey() then return true, "your goals or plan settings changed since this plan" end
  if (now or time()) - c.at > M.MAX_AGE then return true, "this plan is old" end
  return false
end

-- debounced request: many events in a burst make one re-plan
function M:Request(why)
  if not self:Ready() then return end
  if ns.Compat.InCombat() then self.wanted = why return end
  -- trailing debounce: the first request starts the wait, later ones join it
  self.pendingWhy = why
  if self.pending then return end
  self.pending = self:After(M.DEBOUNCE, function(mod)
    mod.pending = nil
    if mod:Ready() then mod:Replan(mod.pendingWhy) end
  end, "nexus:replan")
end

function M:Pin(id) self:Settings().pinned = id self:Request("pin") end
function M:Unpin() self:Settings().pinned = nil self:Request("unpin") end
function M:Skip(id) self:Settings().skipped[id] = true self:Request("skip") end
function M:Unskip(id) self:Settings().skipped[id] = nil self:Request("unskip") end
function M:Pause() self:Settings().paused = true end
-- the planner switch: the old plan is dropped either way (OI02-R12)
function M:SetOn(on)
  self:Settings().on = on and true or false
  self.current = nil
  local radar = ns.Modules:Get("OpportunityRadar")
  if radar then radar.dirty = true end
  if on then self:Replan("switched on") end
end
function M:Resume() self:Settings().paused = false self:Request("resume") end

-- The player's click on a step: the producer's own intent, nothing else.
-- Every check must pass (OI02-R05): the planner is on, not in combat, the plan
-- is current, the step is one of its steps, it isn't skipped or left out, its
-- opportunity hasn't expired, its evidence still resolves (same character and
-- build, not stale), and only the declared intent runs: a waypoint through the
-- producer's go(), a page through the Hub. Intent "none" does nothing.
-- opts.display: the checks for showing a step (combat and intent aren't about
-- showing it); Act always runs every check.
function M:CheckAct(id, now, opts)
  now = now or time()
  local display = opts and opts.display
  if not self:Ready() then return false, "the planner is off" end
  if not display and ns.Compat.InCombat() then return false, "not in combat" end
  local c = self.current
  local res = c and c.result
  if not (res and res.plan) then return false, "there is no plan" end
  local stale, why = self:IsStale(now)
  if stale then return false, why end
  local inPlan = false
  for _, s in ipairs(res.plan.steps) do if s == id then inPlan = true break end end
  if not inPlan then return false, "that step isn't in the current plan" end
  if (self:Settings().skipped or {})[id] then return false, "you skipped that step" end
  if c.rejected and c.rejected[id] then return false, "that step was left out: " .. tostring(c.rejected[id]) end
  local node = c.graph and c.graph.nodes[id]
  local cand = c.runtime and c.runtime[id]
  if not (node and cand) then return false, "that step isn't in the current plan" end
  if now > node.opp.expiresAt then return false, "that step's information is out of date: press Re-plan" end
  for _, ev in ipairs(node.opp.evidenceIds) do
    local row, evWhy = ns.IntelEvidence:Get(ev, now)
    if not row then return false, "its evidence is " .. tostring(evWhy) .. ": press Re-plan" end
  end
  local intent = node.opp.intent
  if display then return true, intent, cand end
  if intent == "waypoint" and type(cand.go) ~= "function" then return false, "nothing to show for this step" end
  if intent == "panel" and not (cand.panel and ns.Hub) then return false, "nothing to open for this step" end
  if intent == "none" then return false, "this step has nothing to open" end
  return true, intent, cand
end

function M:Act(id)
  local ok, intent, cand = self:CheckAct(id)
  if not ok then return false, intent end
  -- tell listeners what the player chose (Intelligence/Outcomes.lua uses it
  -- for attribution); runtime only, never saved
  local res = self.current.result
  local node = self.current.graph and self.current.graph.nodes[id]
  ns.Events:Fire("OTR_NEXUS_ACTED", { planId = res.plan.planId, stepId = id, at = time(), title = node and node.opp.title,
    questID = tonumber(cand.questID), itemID = tonumber(cand.itemID), mapID = tonumber(cand.mapID) })
  if intent == "waypoint" then
    local fine, err = pcall(cand.go)
    if not fine then return false, tostring(err) end
    return true, "waypoint"
  end
  ns.Hub:Build():Show()
  ns.Hub:ShowTab(cand.panel)
  return true, "panel"
end

-- ------------------------------------------------------------ one source of picks (OI02-R08)
-- With the planner on, What now?, the Home cards and Radar all show the plan's
-- steps (this list), so the player never sees two rankings. Each pick is a copy
-- of the producer's own candidate (its go() for the click) with the plan's
-- order and score; off, every page keeps its baseline. Re-plans only when there
-- is no current plan or it went stale, never in combat or while paused.
function M:Picks(n)
  if not self:Ready() then return nil end
  if not ns.Compat.InCombat() and not self:Settings().paused and self:IsStale() then self:Replan("picks") end
  local c = self.current
  local res = c and c.result
  local out = {}
  if not (res and res.plan) then return out end
  local scores = {}
  for _, r in ipairs(c.ranked or {}) do scores[r.id] = r.score end
  local now = time()
  local unconfirmed = {}
  for _, id in ipairs(res.unconfirmed or {}) do unconfirmed[id] = true end
  for i, id in ipairs(res.plan.steps) do
    if n and #out >= n then break end
    local cand = c.runtime[id]
    -- only steps that are still usable are shown (stale, expired, skipped or
    -- left-out steps disappear at once, before any re-plan)
    if cand and self:CheckAct(id, now, { display = true }) then
      -- the producer's own callbacks never leave the planner (OI02-R10): the
      -- copy's go() is the validated Act, and producer alternatives are dropped
      local copy = {}
      for k, v in pairs(cand) do if k ~= "go" and k ~= "alt" then copy[k] = v end end
      copy.go = function() return M:Act(id) end
      copy.score, copy.nexusId, copy.nexusStep, copy.provider = scores[id] or 0, id, i, "nexus"
      copy.expiresAt = c.graph.nodes[id].opp.expiresAt -- the opportunity's own expiry, for every page
      if unconfirmed[id] then
        copy.priceUnknown = true
        copy.caveat = "Price unknown: check it before you buy. The plan doesn't count it as gold spent."
      end
      out[#out + 1] = copy
    end
  end
  return out
end

-- ------------------------------------------------------------ troubleshooting (OI02-13)
-- What's holding the plan back: { {code, text, remedy, kind = "error"|"limit"|"info"} }.
-- "error" means Outrider couldn't read something (a fault), "limit" means the
-- plan is constrained by real facts (gold, faction, prerequisites), "info" is
-- context. No character names, realms or exact gold amounts appear here.
local REASON = {
  ["over budget"] = { "over_budget", "costs more than you can spend above your gold reserve", "lower the reserve on your goal, or earn gold first" },
  ["cost with no gold reading"] = { "gold_unknown", "has a cost but your gold isn't known yet", "open your bags once so Outrider reads your gold" },
  cycle = { "prerequisite_cycle", "its prerequisites loop back on themselves (data problem)", "skip it; please report it" },
  ["cost unknown"] = { "cost_unknown", "its gold cost isn't known and you set a gold reserve", "visit the vendor once so Outrider sees the price, or remove the reserve" },
}
local function reasonFor(why)
  why = tostring(why)
  if REASON[why] then return REASON[why] end
  if why:find("^faction") then return { "wrong_faction", "is for the other faction", nil } end
  if why:find("^unmet prerequisite") then return { "missing_prerequisite", "needs something you haven't done yet", "do its first step, or skip it" } end
  if why:find("prerequisites can.t be planned") then return { "prerequisites_unplannable", "needs steps that can't be planned (missing, a loop, or too deep)", "do its first step, or skip it" } end
  if why:find("^needs ") then return { "blocked_by_prerequisite", "depends on a step that can't be done", nil } end
  return { "other", why, nil }
end

function M:Diagnose()
  local out = {}
  local function add(kind, code, text, remedy) out[#out + 1] = { kind = kind, code = code, text = text, remedy = remedy } end
  if not self:Settings().on then add("info", "off", "The planner is switched off.", "switch it on on the Plan page") return out end
  local c = self.current
  if not c then add("info", "no_plan_yet", "No plan has been made yet.", "press Re-plan") return out end
  local stale, why = self:IsStale()
  if stale then add("info", "stale", why .. ".", "press Re-plan") end
  local pin = c.result and c.result.pin
  if pin and not pin.ok then add("limit", pin.code or "pin_infeasible", "Your pinned step can't go first: " .. tostring(pin.why) .. ".", "unpin it, or do what it needs first") end
  for _, name in ipairs(c.unavailable or {}) do
    add("error", "source_unavailable", "Couldn't read suggestions from " .. name .. ".", "it may be switched off on the Modules page")
  end
  local total = #(ns.NexusAdapters.PROGRESSION) + #(ns.NexusAdapters.RESOURCES) + 3
  if #(c.unavailable or {}) >= total then add("error", "all_sources_failed", "No source of suggestions could be read: this is a fault, not a lack of things to do.", "type /ride errors and report it") end
  local counts = {}
  for id, why in pairs(c.rejected or {}) do
    local r = reasonFor(why)
    local key = r[1]
    counts[key] = counts[key] or { n = 0, r = r, ex = id }
    counts[key].n = counts[key].n + 1
  end
  local keys = {}
  for k in pairs(counts) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local e = counts[k]
    add("limit", k, string.format("%d step%s left out: %s.", e.n, e.n == 1 and "" or "s", e.r[2]), e.r[3])
  end
  local unsure = 0
  for _, r in ipairs(c.ranked or {}) do
    local n = c.graph.nodes[r.id]
    if n.travelUnknown or not n.opp.costSeconds or n.opp.confidence == "inferred" or n.opp.confidence == "unknown" then unsure = unsure + 1 end
  end
  local missing = {}
  for _, r in ipairs(c.ranked or {}) do
    for _, u in ipairs(c.graph.nodes[r.id].meta.unknown or {}) do if u ~= "excludes" then missing[u] = (missing[u] or 0) + 1 end end
  end
  local mk = {}
  for k in pairs(missing) do mk[#mk + 1] = k end
  table.sort(mk)
  if #mk > 0 then
    local parts = {}
    for _, k in ipairs(mk) do parts[#parts + 1] = string.format("%s for %d", k, missing[k]) end
    add("info", "metadata_unknown", "Some steps lack details (" .. table.concat(parts, ", ") .. "); the plan treats them as unknown, not free.", nil)
  end
  if unsure > 0 then add("info", "uncertain_estimates", string.format("%d step%s rest on guesses (time, travel or a doubtful source); they score lower.", unsure, unsure == 1 and "" or "s"), nil) end
  for _, p in ipairs(ns.NexusGoals:Check(time(), { copper = (ns.NexusState:Get("gold") or {}).value, level = (ns.NexusState:Get("level") or {}).value })) do
    add("limit", "goal_" .. p.code, p.text, nil)
  end
  local res = c.result
  if res and not res.plan then
    local hasError = false
    for _, d in ipairs(out) do if d.kind == "error" then hasError = true end end
    add(hasError and "error" or "info", res.code or "no_plan",
      hasError and "There is no plan because something couldn't be read (see above)." or ("No plan: " .. tostring(res.why) .. "."), nil)
  end
  return out
end

function M:OnEnable()
  for event in pairs(ns.NexusState.EVENTS) do self:On(event, function(mod) mod:Request(event) end) end
  self:On("OTR_NEXUS_GOALS_CHANGED", function(mod) mod:Request("goals") end)
  self:On("PLAYER_REGEN_ENABLED", function(mod)
    if mod.wanted then local w = mod.wanted mod.wanted = nil mod:Request(w) end
  end)
  self:On("PLAYER_LOGOUT", function(mod)
    -- keep a summary to check against when you come back (OI03-13)
    if ns.NexusRecovery then ns.NexusRecovery.Save(mod) end
    mod.current, mod.wanted = nil, nil
  end)
  self:On("OTR_PLAYSESSION", function(mod, _, kind)
    if ns.NexusRecovery then ns.NexusRecovery.OnLogin(mod, kind) end
  end)
end

function M:OnDisable()
  self.pending = nil -- its module-owned timer is cancelled with the module
  self.current, self.wanted = nil, nil
end

function M:Activity()
  if not self:Settings().on then return "off (development planner)" end
  local c = self.current
  if not c then return "no plan yet" end
  local res = c.result
  return res.plan and string.format("%d steps planned", #res.plan.steps) or ("no plan: " .. tostring(res.why))
end

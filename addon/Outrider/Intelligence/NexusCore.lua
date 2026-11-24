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
  local done = {}
  for id in pairs(self:Settings().skipped or {}) do done[id] = true end
  return { copper = gold and gold.value, reserveCopper = reserve, mapID = loc and loc.value.mapID,
    faction = st and st.faction ~= "unknown" and st.faction or nil, revision = S:Revision(), now = time() }, goals
end

-- meta for the graph from the producers' own candidates
local function metaFor(runtime)
  local meta = {}
  for id, c in pairs(runtime or {}) do
    local q = ns.NexusAdapters.QuestKey(c)
    meta[id] = { mapID = tonumber(c.mapID), overlap = q and ("quest:" .. q) or nil }
  end
  return meta
end

-- Build a plan now (pure apart from reading state). Returns the stored result.
function M:Replan(why)
  if not self:Ready() then return nil end
  if ns.Compat.InCombat() then self.wanted = why or "combat" return nil end
  if self:Settings().paused then return self.current end
  local ctx, goals = self:Context()
  local opps, excluded, unavailable, runtime = ns.NexusAdapters:All(ctx.revision, ctx.now)
  local skipped = self:Settings().skipped or {}
  local kept = {}
  for _, o in ipairs(opps) do if not skipped[o.opportunityId] then kept[#kept + 1] = o end end
  local graph = ns.NexusGraph.Build(kept, metaFor(runtime), ctx)
  local ranked, rejected = ns.NexusScore.Rank(graph, goals, ctx)
  local res = ns.NexusPlanner.Plan(graph, ranked, ctx)
  -- a pinned step that is still valid goes first
  local pin = self:Settings().pinned
  if res.plan and pin and graph.nodes[pin] and not graph.invalid[pin] then
    local steps = { pin }
    for _, s in ipairs(res.plan.steps) do if s ~= pin and #steps < 8 then steps[#steps + 1] = s end end
    res.plan.steps = steps
  end
  self.current = { result = res, revision = ctx.revision, at = ctx.now, runtime = runtime, graph = graph,
    ranked = ranked, rejected = rejected, excluded = excluded, unavailable = unavailable, why = why }
  self.replans = (self.replans or 0) + 1
  ns.Events:Fire("OTR_NEXUS_PLAN", why)
  return self.current
end

function M:IsStale(now)
  local c = self.current
  if not c then return true, "no plan yet" end
  if c.revision ~= ns.NexusState:Revision() then return true, "your character changed since this plan" end
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
function M:Resume() self:Settings().paused = false self:Request("resume") end

-- The player's click on a step: the producer's own intent, nothing else.
function M:Act(id)
  local c = self.current
  local cand = c and c.runtime and c.runtime[id]
  if not cand then return false, "that step isn't in the current plan" end
  local stale, why = self:IsStale()
  if stale then return false, why end
  if type(cand.go) == "function" then
    local ok, err = pcall(cand.go)
    if not ok then return false, tostring(err) end
    return true, "waypoint"
  end
  if cand.panel and ns.Hub then
    ns.Hub:Build():Show()
    ns.Hub:ShowTab(cand.panel)
    return true, "panel"
  end
  return false, "nothing to open for this step"
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
}
local function reasonFor(why)
  why = tostring(why)
  if REASON[why] then return REASON[why] end
  if why:find("^faction") then return { "wrong_faction", "is for the other faction", nil } end
  if why:find("^unmet prerequisite") then return { "missing_prerequisite", "needs something you haven't done yet", "do its first step, or skip it" } end
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
  self:On("PLAYER_LOGOUT", function(mod) mod.current, mod.wanted = nil, nil end)
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

-- Intelligence/Preferences.lua  (OI03-10)
-- What your feedback says you like, as a small, bounded nudge to the
-- planner's scores. No store of its own for votes: it reads the feedback
-- Outrider already keeps, one vote per suggestion, and works it out on demand.
--   useful     Radar "useful"
--   wrong      Radar "wrong", What now? "Not useful" (skip)
--   completed  Radar "done", or an outcome the recorder attributed as
--              "likely" to a plan step you chose (never "direct": a likely
--              completion is a hint, not proof)
--   neutral    Radar "dismiss" / "snooze": "not now" is not a judgement
--   ignored    shown but not acted on (What now?'s shown counts): reported,
--              and it counts for nothing; ignoring is not doing badly
-- One suggestion is one vote however many times it was clicked (the latest
-- verdict wins), so duplicates can't amplify anything.
-- Per kind of step (quest, gear, gold...): (useful + completed - wrong)
-- divided by (votes + SMOOTH), times MAX_ADJ, clamped to +-MAX_ADJ. MAX_ADJ is
-- small next to a goal's weight, so your explicit goals always dominate.
-- Settings (in the planner's): prefs.on = false opts out (no nudge at all);
-- Reset() starts counting from now (votes before are ignored, not deleted);
-- Undo() goes back to the previous starting point. Explain(kind) says where
-- a nudge came from.

local _, ns = ...
local P = { MAX_ADJ = 0.05, SMOOTH = 5 }
ns.NexusPreferences = P

-- the kind of step a candidate key or a plan step id is about
local PREFIX = { quest = "quest", dq = "dungeon", dungeon = "dungeon", errand = "errand", gold = "gold", deal = "gold",
  gather = "gather", profession = "profession", gear = "gear", handoff = "gear", rare = "rare", route = "travel" }
function P.KindOf(key)
  key = tostring(key or "")
  local legacy = key:match("^opp:[^:]+:(.+)$") or key
  return PREFIX[legacy:match("^([%a]+):") or ""]
end
local function legacyKey(key) key = tostring(key or "") return key:match("^opp:[^:]+:(.+)$") or key end

-- every vote, one per suggestion, the latest winning: { [key] = { verdict, t, source } }
function P.Votes(src, since)
  local votes = {}
  local function vote(key, verdict, t, source)
    key = legacyKey(key)
    t = tonumber(t) or 0
    if since and t < since then return end
    local v = votes[key]
    if not v or t >= v.t then votes[key] = { verdict = verdict, t = t, source = source } end
  end
  for key, f in pairs(src.radar or {}) do
    if type(f) == "table" then
      local verdict = f.verdict == "done" and "completed" or (f.verdict == "useful" or f.verdict == "wrong") and f.verdict or "neutral"
      vote(key, verdict, f.t, "radar")
    end
  end
  for key, t in pairs(src.skip or {}) do vote(key, "wrong", t, "whatnow") end
  for _, e in ipairs(src.outcomes or {}) do
    if e.attribution == "likely" and e.stepId and e.kind == "quest_completed" then vote(e.stepId, "completed", e.at, "outcome") end
  end
  return votes
end

function P.Adjustments(src, opts)
  opts = opts or {}
  if opts.on == false then return {}, {} end
  local counts = {}
  local votes = P.Votes(src, opts.since)
  for key, v in pairs(votes) do
    local kind = P.KindOf(key)
    if kind then
      local c = counts[kind] or { useful = 0, wrong = 0, completed = 0, neutral = 0, ignored = 0 }
      c[v.verdict] = (c[v.verdict] or 0) + 1
      counts[kind] = c
    end
  end
  for key, n in pairs(src.shown or {}) do
    local kind = P.KindOf(key)
    local voted = votes[legacyKey(key)]
    if kind and not voted and tonumber(n) then
      counts[kind] = counts[kind] or { useful = 0, wrong = 0, completed = 0, neutral = 0, ignored = 0 }
      counts[kind].ignored = counts[kind].ignored + 1
    end
  end
  local adj = {}
  for kind, c in pairs(counts) do
    local n = c.useful + c.wrong + c.completed
    local raw = (c.useful + c.completed - c.wrong) / (n + P.SMOOTH)
    local a = math.max(-P.MAX_ADJ, math.min(P.MAX_ADJ, raw * P.MAX_ADJ * 2))
    if n > 0 then adj[kind] = a end
    c.adjustment = n > 0 and a or 0
  end
  return adj, counts
end

-- ------------------------------------------------------------ live sources
function P.Sources()
  local src = {}
  local c = ns.db and ns.db.char or {}
  src.radar = type(c.radarFeedback) == "table" and c.radarFeedback or {}
  local W = ns.WhatNow
  local st = W and W.Store and W:Store()
  src.skip = st and st.skip or {}
  src.shown = st and st.shown or {}
  local O = ns.Outcomes
  src.outcomes = O and O.Store and O:Store().events or {}
  return src
end

function P.Settings(planner)
  local s = planner:Settings()
  s.prefs = type(s.prefs) == "table" and s.prefs or { on = true }
  return s.prefs
end
function P.Reset(planner)
  local s = P.Settings(planner)
  s.sincePrev, s.since = s.since or false, time()
end
function P.Undo(planner)
  local s = P.Settings(planner)
  if s.sincePrev == nil then return false end
  s.since = s.sincePrev or nil
  s.sincePrev = nil
  return true
end

function P.Explain(kind, counts)
  local c = counts and counts[kind]
  if not c then return "no feedback on these yet" end
  return string.format("%d useful, %d done, %d not useful, %d not now, %d shown and passed over: %+.3f",
    c.useful, c.completed, c.wrong, c.neutral, c.ignored, c.adjustment or 0)
end

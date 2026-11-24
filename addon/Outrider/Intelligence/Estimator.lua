-- Intelligence/Estimator.lua  (OI03-09)
-- Personal estimates from your own observations, with honest uncertainty.
-- Pure functions over samples; no store of its own.
--
-- A sample: { value = number, at = time, build = game build, key = stratum }.
-- Fit(samples, opts) per stratum:
--   * patch changes: only samples from the current game build count; with too
--     few of those, older builds are used with the interval widened (basis
--     "older build"), and with none at all it falls back;
--   * recency: samples from the last RECENT days are preferred when there are
--     at least MIN of them;
--   * outliers: values further than OUTLIER x MAD (median absolute deviation)
--     from the median are set aside; if more than a tenth were set aside, the
--     interval is widened;
--   * sparse: fewer than MIN samples falls back to the prior (opts.prior,
--     e.g. Journey's 300 s) with a wide interval; with MIN or more the
--     estimate is shrunk toward the prior by SHRINK pseudo-samples
--     (conservative: a few odd quests don't move it far);
--   * the interval is the observed p10..p90 (or the prior's band).
-- Evaluate(samples, opts): held-out calibration in time order: the model is
-- fitted on the earlier TRAIN share and scored on the later samples only, so
-- no test sample can leak into training. Reports the median absolute error,
-- the median relative error and how often the real value fell inside the
-- interval (coverage), with the counts; too few test samples says so.

local _, ns = ...
local E = { MIN = 5, RECENT = 30, OUTLIER = 5, SHRINK = 5, TRAIN = 0.7, PRIOR_BAND = 0.5, WIDEN = 1.5 }
ns.Estimator = E

local function sortedValues(list)
  local v = {}
  for i, s in ipairs(list) do v[i] = s.value end
  table.sort(v)
  return v
end
local function quantile(sorted, q)
  if #sorted == 0 then return nil end
  local pos = 1 + (#sorted - 1) * q
  local lo, hi = math.floor(pos), math.ceil(pos)
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo)
end
local function median(sorted) return quantile(sorted, 0.5) end

-- one stratum
function E.FitOne(samples, opts)
  opts = opts or {}
  local now, build, prior = opts.now or time(), opts.build, opts.prior
  local usable = {}
  for _, s in ipairs(samples or {}) do
    if type(s) == "table" and tonumber(s.value) and s.value == s.value then usable[#usable + 1] = s end
  end
  local basis = "observed"
  local pool = {}
  if build then
    for _, s in ipairs(usable) do if s.build == build then pool[#pool + 1] = s end end
    if #pool < E.MIN and #usable >= E.MIN then pool, basis = usable, "older build" end
  else
    pool = usable
  end
  -- prefer recent samples when there are enough of them
  local recent = {}
  for _, s in ipairs(pool) do if s.at and now - s.at <= E.RECENT * 86400 then recent[#recent + 1] = s end end
  if #recent >= E.MIN then pool = recent end
  local fallback = function(why)
    if not prior then return { basis = "none", n = #pool, why = why } end
    return { value = prior, lo = prior * (1 - E.PRIOR_BAND), hi = prior * (1 + E.PRIOR_BAND), basis = "prior", n = #pool, why = why }
  end
  if #pool < E.MIN then return fallback(#pool == 0 and "no samples" or ("only " .. #pool .. " samples")) end
  -- set outliers aside (MAD)
  local v = sortedValues(pool)
  local m = median(v)
  local dev = {}
  for i, x in ipairs(v) do dev[i] = math.abs(x - m) end
  table.sort(dev)
  local mad = median(dev)
  local kept = {}
  for _, x in ipairs(v) do
    if mad == 0 or math.abs(x - m) <= E.OUTLIER * mad then kept[#kept + 1] = x end
  end
  local dropped = #v - #kept
  if #kept < E.MIN then return fallback("too many outliers") end
  local med = median(kept)
  local lo, hi = quantile(kept, 0.1), quantile(kept, 0.9)
  local value = med
  if prior then value = (#kept * med + E.SHRINK * prior) / (#kept + E.SHRINK) end
  local widen = 1
  if basis == "older build" then widen = widen * E.WIDEN end
  if dropped > #v / 10 then widen = widen * E.WIDEN end
  if widen > 1 then
    lo = value - (value - lo) * widen
    hi = value + (hi - value) * widen
  end
  if lo > value then lo = value end
  if hi < value then hi = value end
  return { value = value, lo = math.max(0, lo), hi = hi, basis = basis, n = #kept, outliers = dropped, median = med }
end

-- samples grouped by s.key -> { [key] = model }
function E.Fit(samples, opts)
  local groups = {}
  for _, s in ipairs(samples or {}) do
    local k = s.key or "all"
    groups[k] = groups[k] or {}
    table.insert(groups[k], s)
  end
  local out = {}
  for k, list in pairs(groups) do out[k] = E.FitOne(list, opts) end
  return out
end

function E.Predict(models, key, opts)
  local m = models and models[key]
  if m and m.value then return m end
  return E.FitOne({}, opts) -- the fallback, with its reason
end

-- held-out calibration in time order
function E.Evaluate(samples, opts)
  opts = opts or {}
  local list = {}
  for _, s in ipairs(samples or {}) do if tonumber(s.value) and tonumber(s.at) then list[#list + 1] = s end end
  table.sort(list, function(a, b) return a.at < b.at end)
  local cut = math.floor(#list * E.TRAIN)
  local train, test = {}, {}
  for i, s in ipairs(list) do if i <= cut then train[#train + 1] = s else test[#test + 1] = s end end
  local trainedUntil = train[#train] and train[#train].at or nil
  local fitOpts = { build = opts.build, prior = opts.prior, now = trainedUntil or opts.now }
  local models = E.Fit(train, fitOpts)
  if #test < E.MIN then
    return { n = #test, trainN = #train, enough = false, why = "not enough later samples to test against" }
  end
  local abs, rel, inside, scored = {}, {}, 0, 0
  for _, s in ipairs(test) do
    local m = E.Predict(models, s.key or "all", fitOpts)
    if m.value then
      scored = scored + 1
      abs[#abs + 1] = math.abs(s.value - m.value)
      if s.value ~= 0 then rel[#rel + 1] = math.abs(s.value - m.value) / math.abs(s.value) end
      if s.value >= m.lo and s.value <= m.hi then inside = inside + 1 end
    end
  end
  table.sort(abs) table.sort(rel)
  return { n = #test, trainN = #train, scored = scored, enough = scored >= E.MIN,
    medianAbsError = median(abs), medianRelError = median(rel), coverage = scored > 0 and inside / scored or nil,
    trainedUntil = trainedUntil }
end

-- ------------------------------------------------------------ adapters
-- quest durations (QuestTimes "complete" samples), by level band and solo/group
function E.QuestSamples(qsamples)
  local out = {}
  for _, s in ipairs(qsamples or {}) do
    if s.kind == "complete" and s.seconds then
      local band = s.level and (math.floor((s.level - 1) / 5) * 5 + 1) or "?"
      out[#out + 1] = { value = s.seconds, at = s.endedAt, build = s.build, key = "L" .. tostring(band) .. (s.grouped and "|group" or "|solo") }
    end
  end
  return out
end
-- travel: how much longer (or shorter) real walking trips take than the
-- planner's estimate (actual / estimate), from walking samples only
function E.TravelSamples(trips)
  local out = {}
  for _, t in ipairs(trips or {}) do
    if t.walking and t.seconds and t.estimate and t.estimate > 0 then
      out[#out + 1] = { value = t.seconds / t.estimate, at = t.endedAt, build = t.build, key = "walk" }
    end
  end
  return out
end

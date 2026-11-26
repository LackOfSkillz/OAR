-- Vanguard/Forecast.lua
-- VG05-06..10: what the history says, and the gate in front of any forecast.
--
-- Descriptive rates (VG05-06): for one place or boss, kills out of attempts
-- with a known result (kill or wipe), with a 95% Wilson interval and the
-- sample size; unknown and censored attempts are counted and shown, never
-- folded in. Fewer than MIN_RATE known results: the counts only, no rate.
-- Time quantiles use completed runs only (selection said so).
--
-- Forecasts (VG05-07/08): a forecast needs an approved model whose evidence
-- meets the pre-registered plan (docs/vanguard/VG05-07_FORECAST_PLAN.md):
-- at least 200 independent real labelled runs for the target, 50 held out,
-- 10 of each outcome in the holdout, a Brier score no worse than the
-- prevalence baseline, the same game build, and an independent approval. No
-- model ships: Forecast.Predict always abstains, with the reason. A model
-- marked synthetic can never authorize a displayed number. No language
-- model makes numbers. A readiness index is never shown as win odds.
-- Calibration tools (VG05-09) are pure functions for the offline review.

local _, ns = ...
ns.Vanguard = ns.Vanguard or {}
local V = ns.Vanguard
local F = { VERSION = 1, MIN_RATE = 5, Z = 1.959964 }
V.Forecast = F

F.FLOORS = { training = 200, validation = 50, perClass = 10 }
F.TARGETS = { first_attempt_kill = true, eventual_kill = true, full_clear = true }

function F.Wilson(k, n, z)
  z = z or F.Z
  if type(k) ~= "number" or type(n) ~= "number" or n <= 0 or k < 0 or k > n then return nil end
  local p = k / n
  local z2 = z * z
  local den = 1 + z2 / n
  local centre = (p + z2 / (2 * n)) / den
  local half = (z * math.sqrt(p * (1 - p) / n + z2 / (4 * n * n))) / den
  return math.max(0, centre - half), math.min(1, centre + half), p
end

-- quantile of a sorted copy (linear interpolation)
function F.Quantile(values, q)
  local s = {}
  for _, v in ipairs(values or {}) do if type(v) == "number" and v == v then s[#s + 1] = v end end
  if #s == 0 then return nil end
  table.sort(s)
  local pos = 1 + (#s - 1) * q
  local lo = math.floor(pos)
  local hi = math.min(#s, lo + 1)
  return s[lo] + (s[hi] - s[lo]) * (pos - lo)
end

-- runs: RunRecords. filter: { instance, encounterId }
function F.Rates(runs, filter)
  filter = filter or {}
  local kills, wipes, unknown, censoredRuns, times = 0, 0, 0, 0, {}
  local nRuns = 0
  for _, r in ipairs(runs or {}) do
    if type(r) == "table" and (not filter.instance or r.instance == filter.instance) then
      nRuns = nRuns + 1
      if r.outcome == "unknown" then censoredRuns = censoredRuns + 1 end
      if r.outcome == "completed" and r.endedAt and r.startedAt then times[#times + 1] = r.endedAt - r.startedAt end
      for _, a in ipairs(r.attempts or {}) do
        if not filter.encounterId or a.encounterId == filter.encounterId then
          if a.result == "kill" then kills = kills + 1 elseif a.result == "wipe" then wipes = wipes + 1 else unknown = unknown + 1 end
        end
      end
    end
  end
  local n = kills + wipes
  local out = { runs = nRuns, kills = kills, wipes = wipes, unknown = unknown, censoredRuns = censoredRuns, known = n,
    completedRuns = #times }
  if n >= F.MIN_RATE then
    out.low, out.high, out.rate = F.Wilson(kills, n)
  else
    out.abstain = string.format("only %d attempt(s) with a known result (need %d for a rate)", n, F.MIN_RATE)
  end
  if #times >= F.MIN_RATE then
    out.timeMedian, out.timeP25, out.timeP75 = F.Quantile(times, 0.5), F.Quantile(times, 0.25), F.Quantile(times, 0.75)
  end
  return out
end

-- VG05-08: the model contract and gate. model = { version, target, build,
--   trainingCount, validationCount, holdoutPositives, holdoutNegatives,
--   brier, baselineBrier, approved, approvedBy, synthetic, coefficients }
function F.Eligible(model, ctx)
  ctx = ctx or {}
  if type(model) ~= "table" then return false, "no approved model (needs real labelled runs; see the forecast plan)" end
  if model.synthetic then return false, "trained on synthetic data: can't show numbers" end
  if not F.TARGETS[model.target] then return false, "unknown target" end
  if model.approved ~= true or type(model.approvedBy) ~= "string" then return false, "not approved by an independent review" end
  if (model.trainingCount or 0) < F.FLOORS.training then return false, "too few training runs" end
  if (model.validationCount or 0) < F.FLOORS.validation then return false, "too few held-out runs" end
  if (model.holdoutPositives or 0) < F.FLOORS.perClass or (model.holdoutNegatives or 0) < F.FLOORS.perClass then
    return false, "too few of each outcome in the holdout"
  end
  if type(model.brier) ~= "number" or type(model.baselineBrier) ~= "number" or model.brier > model.baselineBrier then
    return false, "not better calibrated than the base rate"
  end
  if ctx.build and model.build ~= ctx.build then return false, "made for another game build" end
  if ctx.coverage and ctx.coverage < 0.8 then return false, "too much of the group unknown" end
  return true
end

F.model = nil -- none shipped
function F.Predict(target, features, ctx)
  local ok, why = F.Eligible(F.model, ctx)
  local out = { version = F.VERSION, target = target, modelVersion = F.model and F.model.version or nil }
  if not F.TARGETS[target] then out.abstainReason = "unknown target" return out end
  if not ok then out.abstainReason = why return out end
  -- an approved model would be applied here (logistic on aggregate features)
  out.abstainReason = "model application not enabled in this build"
  return out
end

-- VG05-09 offline evaluation helpers (pure)
function F.Brier(preds, outcomes)
  local s, n = 0, 0
  for i, p in ipairs(preds or {}) do
    local y = outcomes[i]
    if type(p) == "number" and (y == 0 or y == 1) then s, n = s + (p - y) ^ 2, n + 1 end
  end
  if n == 0 then return nil end
  return s / n, n
end

function F.Reliability(preds, outcomes, bins)
  bins = bins or 10
  local out = {}
  for b = 1, bins do out[b] = { n = 0, meanP = 0, observed = 0 } end
  for i, p in ipairs(preds or {}) do
    local y = outcomes[i]
    if type(p) == "number" and p >= 0 and p <= 1 and (y == 0 or y == 1) then
      local b = math.min(bins, math.floor(p * bins) + 1)
      local t = out[b]
      t.n, t.meanP, t.observed = t.n + 1, t.meanP + p, t.observed + y
    end
  end
  for _, t in ipairs(out) do if t.n > 0 then t.meanP, t.observed = t.meanP / t.n, t.observed / t.n end end
  return out
end

# VG05-07: Forecast validation plan (pre-registered)

Date: 2026-11-26. Status: **pre-registered, not started.** No model has been fitted, and none may be fitted until an independent reviewer signs off on this plan (VG05-07 acceptance). Outrider ships no forecast model; `Vanguard/Forecast.lua` abstains.

## Targets (separate models, never multiplied together)

| Target | Definition | Horizon |
|---|---|---|
| `first_attempt_kill` | The first ENCOUNTER_START for a boss in a run ends with the game's success flag | that attempt |
| `eventual_kill` | Any attempt on that boss in the same run ends with success | the run (rejoin within 10 minutes is the same run) |
| `full_clear` | Every boss listed for the place in the installed data is killed in the run | the run |

A boss kill is not a full clear. Unknown attempts (reload, disconnect, no end event) and censored runs are excluded from labels and reported as counts.

## Features (aggregate only, D27)

Group size; tank, healer, damage and unknown-role counts; class counts; level minimum and maximum; readiness range low and high and coverage at run start (copied before the outcome); place; boss; difficulty; game build. No names, GUIDs, gear links or per-member data.

## Minimum cohort (per target and place cohort)

- At least 200 independent labelled runs for training, from real play (no synthetic data counts).
- At least 50 held-out runs, with at least 10 of each outcome in the holdout.
- Sparse or skewed cohorts (one outcome above 95%), a changed game build, or a changed catalog version: abstain.

## Split and leakage

Chronological split: train on older runs, evaluate on newer. Grouped by run (all attempts of a run on one side) and by character where several characters contribute. The readiness copied at run start is the only assessment feature; nothing recorded after the pull is used.

## Metrics and pass rule

- Brier score no worse than the prevalence baseline (always predicting the training base rate), with a bootstrap interval.
- Reliability diagram with sample counts per bin (`Forecast.Reliability`), calibration slope and intercept with intervals.
- Discrimination (AUC) reported, not used to pass.
- Coverage and abstention rate; drift by build and by month.
- Candidate models: prevalence baseline, a simple role-and-level logistic model, then a regularized logistic model on the aggregate features. The simplest model that passes is preferred.

## Approval

An independent reviewer approves the exact model version, its training data hashes and these metrics before any number is shown in game (`Forecast.Eligible` requires `approved = true` and `approvedBy`). A language model never produces the numbers. Training and evaluation run offline (VG07, separately authorized), not in the addon.

## Current status (VG05-09)

**Blocked: no real labelled data.** Run recording starts with this build and only while Group check is on. Until the floors above are met, the Runs page shows past results with Wilson intervals (at least 5 known fights) and says "Forecast: none".

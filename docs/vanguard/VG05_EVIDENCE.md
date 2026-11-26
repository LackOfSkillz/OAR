# VG05: Historical learning and forecasting (evidence)

Date: 2026-11-26. Built after VG04 under D28 (gates batched into one final review). The commit that adds this file is the candidate.

Status: **code and unit tests done; live checks pending; VG05-09 blocked (no real labelled data), as the spec expects.** No forecast is shown: the addon abstains.

## What was built

| Task | Where | What it does |
|---|---|---|
| VG05-01 Run and attempt contract | `Vanguard/Runs.lua` | `RunRecord` v1 and `Attempt` (fields in the file header). Outcomes: completed (every boss in the installed data killed, at least one listed), incomplete (left with kills), abandoned (left with none), unknown (lost track: reload, logout, disconnect) with a censor reason. Attempts: kill, wipe (the game's own failure flag), unknown. Features are counts and classes only: no names or GUIDs (D27). |
| VG05-02 Outcome adapter | `Runs.lua` + `Modules/Vanguard.lua` | Instance entry and exit (`IsInInstance`, `GetInstanceInfo`) and `ENCOUNTER_START` / `ENCOUNTER_END`; no combat log. Back inside within 10 minutes is the same run; a repeated end event within 5 seconds is ignored; a new pull with no end leaves the old attempt unknown; a reload is resumed if quick and closed as unknown otherwise; roster changes during a run are counted. Recording happens only while Group check is on. |
| VG05-03 Immutable history and recovery | `Runs.lua`, `Core/Archive.lua` | Saved per character in `char.vanguardRuns` (versioned). Over 200 active runs, the oldest move to the Archive (`vanguardRuns`), confirmed before removal; if the archive refuses, the run stays. A damaged saved value goes to `archiveDamaged`, never overwritten; a store from a newer Outrider is left exactly as it is and not used. |
| VG05-04 Historical query and report | `Runs.All` | Archived and active runs together through `Archive:WithActive` (bounded at 2,000, newest kept), oldest first, so older runs stay findable. The Runs page lists them; `/ride vgruns` prints counts. |
| VG05-05 AfterAction feedback | `Modules/Vanguard.lua` | The readiness range, coverage and must-have state at run start are copied into the run before any outcome; the outcome never changes them. The page shows them side by side and says a comparison shows a pattern, not a cause. |
| VG05-06 Descriptive historical rates | `Vanguard/Forecast.lua` | Kills out of fights with a known result, 95% Wilson interval and counts; unknown fights and censored runs counted apart; fewer than 5 known results: counts only. Time quantiles (median, middle half) from completed runs only. |
| VG05-07 Forecast validation plan | `docs/vanguard/VG05-07_FORECAST_PLAN.md` | Pre-registered targets (first-attempt kill, eventual kill, full clear: separate, never multiplied), aggregate features, minimum cohorts, chronological run-grouped split, Brier against the base rate, reliability, approval. Not started: needs independent sign-off before any fitting. |
| VG05-08 Forecast gate and model contract | `Forecast.Eligible`, `Forecast.Predict` | A model must be real (not synthetic), approved by an independent reviewer, meet the floors (200 training, 50 held out, 10 of each outcome), beat the base rate, match the build, and the group must be at least 80% known. No model ships; `Predict` abstains with the reason; even an eligible model shows nothing in this build. |
| VG05-09 Calibration evaluation | `Forecast.Brier`, `Forecast.Reliability` | Offline helpers with hand-checked fixtures. **Blocked: no real labelled runs yet** (recording starts with this build). Marked blocked, not failed. |
| VG05-10 Forecast UI and feedback | Runs page | Shows the target-free "Forecast: none" with the reason, past results with their range, and the readiness kept from the start; no readiness number is ever called a chance. |

## Tests

`tests/spec/vanguard_runs_spec.lua` (9 tests): a completed run with a duplicate end ignored, a wipe from the game's flag, the assessment unchanged by the outcome, no names or GUIDs saved, counts and classes kept; incomplete, abandoned and rejoin; reload mid-fight is unknown (never a wipe) and a quick reload continues; roster changes counted; 215 runs: 200 active, 15 archived, all 215 readable, oldest first, and an archive refusal keeps the run; a damaged store kept aside, a newer store left alone; Wilson interval 8 of 10 = 0.490 to 0.943 by hand, unknowns apart, sparse abstains, quantiles; forecast abstains, synthetic, thin, other build, low coverage and worse-than-base-rate all refused, Brier and reliability fixtures; the Runs page, no "chance" wording, and nothing recorded with Group check off.

## Data preservation

New dataset `char.vanguardRuns` (your own runs, anonymous). Nothing existing is changed or shrunk. Overflow goes to the Archive; nothing is deleted.

## Live checks still needed (L10, L11)

1. A dungeon run with Group check on: kills, a wipe, leave, rejoin within 10 minutes, reload inside.
2. A long history with backup and restore (`tools/backup-sv.ps1`): every run still there.

## Known limits

- Only the bosses in the installed dungeon pack define "completed"; a place without pack bosses never counts as completed.
- Difficulty is recorded as "normal" (no difficulty read yet).

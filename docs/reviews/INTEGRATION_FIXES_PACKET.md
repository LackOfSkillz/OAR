# Outrider resubmission: integration and release-hardening fixes (OI-FR01 to FR13)

## Implementation submission (Claude)

- **Responds to:** ChatGPT's consolidated review of Phases 3 to 8 (REVIEW_CHANGES on `ab5aa0e`).
- **Branch:** `LackOfSkillz/OAR`, `ai/outrider-personal-intelligence`. Not merged into `main`, not published.
- **Base:** `ab5aa0e`. **Candidate SHA:** `2df79f6` (the fixes) plus this packet commit.
- **Scope:** fixes only. No new features, no rewrites. Every fix has a regression test, and each new test was checked to fail on the old code where that could be shown.

## The failed CI run (45541037441)

It was not a code failure. GitHub never started the job. Its annotation reads: *"The job was not started because recent account payments have failed or your spending limit needs to be increased."* The job ran for 3 seconds and produced no log. The owner has to fix the GitHub billing or spending limit before CI can run on the candidate. Until then, the evidence is the full suite run from a clean clone (below).

## Findings and fixes

| ID | Fix | Files | Regression test |
|---|---|---|---|
| FR01 trail regression | **Cause:** the game keeps 800 points per map and archives older ones; `tools/export_trails.lua` read only the live list, so 183 map-1420 points shipped at `f25a5ba` dropped out. **Fix:** the exporter now merges. The shipped points stay first, in their original order, then archived (`trail`, `trailCleared`) and live points are added. The 183 points are restored (9,790 points on 28 maps). **New gate:** `tools/preservation_check.py` checks every data file against `docs/quality/preservation_base.txt` (`7f4ab21`): every trail point and every record id must still be present. It runs in `tools/test.ps1`, and CI now fetches full history. The shipped format is a point cloud ("walked ground" dots), with no route order or segments to break. | `tools/export_trails.lua`, `tools/preservation_check.py`, `tools/test.ps1`, CI workflow, `addon/Outrider_Data_Trails/Data.lua` | `companion/tests/test_preservation.py` (merge keeps shipped, archived and cleared points; the gate passes). The gate fails on the old file: "map 1420 lost 183 of 800 points". |
| FR02 archived knowledge | `Archive:WithActive(dataset, active, opts)` returns this character's archived rows (oldest first), then the active list. It is bounded (5,000 rows) and cached while both lists keep their length. Used by QuestTimes (the diary), TravelTimes (new `History`), Pathfinder, Preferences and the AfterAction report (events, sales, activity, trips). | `Core/Archive.lua` and the five readers | `tests/spec/archivehistory_spec.lua`: a quest taken before the diary cap still pairs with its hand-in; an archived death appears in the session report and in preferences; other characters are excluded; the cache follows moves. |
| FR03 fail-safe migration | `Archive:Preserve` returns true only if the archive or the damaged-data list confirmed the value. Outcomes, SessionXP and Profiles leave the original saved and work on an unsaved copy otherwise. Outcomes reports it in its Activity line. | `Core/Archive.lua`, `Outcomes.lua`, `SessionXP.lua`, `Profiles.lua` | `outcomes_spec.lua` failure injection: the original is still saved, untouched, and is archived once that works. |
| FR04 learning loop | `QuestTimes:Personal(level, grouped)` gives the estimator's time once there are enough samples. It is shrunk toward Journey's 300 s; sparse history gives nothing, and older builds widen the band. WhatNow's quest steps use it as the task time (`estimateBasis = personal_observed`), so Nexus step costs and time-limited plans change. The diary is never written. | `QuestTimes.lua`, `Modules/WhatNow.lua` | `tests/spec/questlearning_spec.lua` end to end: 12 slow quests make the step dearer and fewer quests fit an hour; 3 quests change nothing. Fails without the WhatNow change. |
| FR05 session clock | Saved length, group and rest settings are the preference; `startedAt` is the running clock. A migrated time gets a clock. A clock in the future is ignored. Choosing the same length again keeps a running clock but starts a new one once the old one ran out. A new **Start a new session** button. A login after the time ran out restarts the clock; a reload keeps it. The context key carries the clock, closing time and "plan over the time left", so an infeasible plan is stale. | `Horizon.lua`, `NexusCore.lua`, `NexusPage.lua`, `UI/Tips.lua` | `horizon_spec.lua`, four new cases. |
| FR06 state dominance | Each (steps, map) pair keeps up to 4 states that no other state beats on value, time and gold together. Under a time budget, a quarter of the beam goes to the quickest states. Shared travel only follows a step whose map is known; this one was found by the benchmark. | `Planner.lua` | `nexus_planner_spec.lua`: an exhaustive solver over *ordered* sequences with the planner's own step times (40 random cases), plus a hand-built case that **fails on the old dedup**. |
| FR07 Forge | Kept as is. Its card is tagged **Experimental**. Every gap (rage, energy, combo points, procs, haste, spell-changing talents, target mechanics, Talents page) is tracked in `docs/FORGE_GAPS.md` with what closing it needs. No precise figure is claimed. | `OraclePage.lua`, `docs/FORGE_GAPS.md` | `oraclepage_spec.lua` (unchanged, green) |
| FR08 Fellowship goals | Goals are shared as `objective:target` from real NexusGoals records, never the per-client `goalId`. | `Fellowship.lua` | `fellowship_spec.lua`: real goals give `level:30`; the payload passes our own checks. |
| FR09 revocation | A valid revoke from a group member is honoured before the rate limit. Peers expire after 10 minutes without news. | `Fellowship.lua` | `fellowship_spec.lua`: a revoke 3 s after a share is honoured; TTL expiry. The live two-client test is still owner-pending. |
| FR10 identities and raids | Members are keyed `Name-Realm`, shown bare on your own realm. raid1 to raid40 are listed in a raid, and unshared members show as "not shared". Nothing is inferred. | `Fellowship.lua`, `tests/lib/wowmock.lua` (UnitName returns the realm) | `fellowship_spec.lua`: the same name on two realms gives two members; an unshared raid member 12 is listed. |
| FR11 provenance | Every manifest and registration is appended to the saved `global.worldProvenance.log`. Every quarantined version (with its entries) is kept per name across reloads. A rejected import never displaces the pack in use under that name: it is recorded and the pack is marked protected. A usable newer version archives the old one first, or is refused. | `World.lua`, `data_preservation_audit.json` | `world_spec.lua` FR11 case; the `archive_spec` static contract. |
| FR12 Passport parity | Both readers check the task, the id (`c` + 8 hex), the build, the time (in the future beyond 5 min is refused; stale) and the age. They keep only allowed fields of the right type and size; the rest are listed as dropped. | `Passport.lua`, `passport.py` | Shared fixtures `companion/tests/fixtures/passport_contract.json` (15 cases and 2 texts), run by `passport_spec.lua` and `test_passport_contract.py` with identical answers. |
| FR13 release gate | Tracked below. CI is blocked by billing (owner). | this packet | the clean-clone suite |

## Release gate status (FR13)

| Requirement | Status |
|---|---|
| Exact-SHA GitHub CI | **Blocked:** GitHub billing/spending limit (owner). The local clean-clone suite is green (below). |
| Reproducible local zip | Done (OI08-14): two builds gave the same SHA-256. |
| Reproducible CurseForge packaging | Not built: `tools/curseforge.ps1` still uses its own zip step. Tracked; no upload without the owner. |
| Clean-machine companion install | Pending (owner, a second PC). |
| Real provider round trip | Pending (owner key). |
| Live WoW testing | Pending: everything after OI03-01 is mock-tested only. |
| Backup restore | Covered by `tools/backup-sv.ps1 -Restore`. A live drill is pending, with the game closed. |
| Competitive evaluation | Partial: Outrider's own 25 questions only; competitors not scored, so no comparative claim. |
| Phase 1 and 2 findings | All accepted earlier; their regression tests are in the suite. |
| Voice, XP60 auto-install | Off. Not built and not enabled without the owner. |
| Name and legal scope (OI08-13) | Owner. |

## Full suite at the candidate

Run from a fresh `git clone` at `2df79f6` with `tools/test.ps1 -RequirePython` (exit 0):

- **Lua specs:** 1,471 passed, 0 failed, 0 syntax errors (1,451 at `ab5aa0e`).
- **Companion tests:** passed, including the new `test_preservation.py` and `test_passport_contract.py`.
- **Quality:** 22 findings, 0 new.
- **Dependencies:** 48 private reads, 0 new.
- **Security:** 0 violations.
- **Preservation:** all 30 data files keep everything from `7f4ab21`.

An earlier clean run at `420ab83` failed the quality gate on two new findings: an unused import, and `Planner.Plan` at 181 lines. Both were fixed in `2df79f6`, not baselined.

## Not done or not claimed

- No live evidence for any of these fixes. Fellowship revocation needs two real clients.
- Archive files moved off the saved variables (ARCHIVE_GROWTH) are not read by `WithActive`.
- Forge stays experimental.
- No merge, no publish, no new features.

## Independent review (ChatGPT fills)

| Finding ID | Severity | Evidence | Status |
|---|---|---|---|
| | | | |

Decision: `REVIEW_CHANGES` / `REVIEW_ACCEPTED` (scope stated) / `BLOCKED`.

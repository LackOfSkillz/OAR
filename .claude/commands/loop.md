# /loop — Outrider gap-closure implementation cycle

Use this command only in the checked-out `LackOfSkillz/OAR` repository. This command is a repeatable *local Claude Code workflow*; a chat response alone does not keep running after it ends.

## Mission
Work through `docs/GAP_ANALYSIS_DEEP_2026-11-18.md`, the raw option-by-option `docs/GAP_RESEARCH_RAW_2026-11-18.md`, and `docs/COMPETITIVE_PARITY_ROADMAP_2026-11-18.md` until all **eligible** feature gaps have passed the agreed three acceptance levels: **Works**, **Matches**, **Surpasses**. Preserve a clearly documented `CAN'T`/restricted/unsupported state for prohibited features. Do not claim features are done just because they compile.

## Loop (repeat while unblocked, within the current interactive session)
1. **Synchronize:** checkout `p1-foundation`, fetch/pull and inspect current working tree. Do not reset, discard uncommitted work, or merge into `main`. Read `CLAUDE.md`, `docs/GAP_LOOP_STATUS_2026-11-18.md`, the deep gap analysis and any dependent source/tests. Check for newly pushed work and reconcile it before edits.
2. **Validate previous iteration:** run `powershell -NoProfile -ExecutionPolicy Bypass -File tools/test.ps1 -RequirePython`. Also inspect the GitHub Actions gate when available. Fix failures and run affected tests before writing more features. Never bypass or skip red tests for a deploy.
3. **Pick:** select the highest-ranked unverified item with dependencies met. Prefer small coherent slices (1–3 closely related tasks). Consult raw competitor option rows and mark exact acceptance `Works`/`Matches`/`Surpasses` evidence required. Do not rebuild features that already exist. Explicitly flag unverifiable private data packs or in-game API assumptions.
4. **Implement:** one owner per frame and `ns.Compat`/secret-value checking; unit-test all calculations, edge cases and API fallbacks; add necessary mock APIs; preserve existing save data and migration. Never introduce autoplay, external screen/memory hooks, combat log reading, protected actions without player input, or external network requests.
5. **Test:** rerun focused and full tests. Run static checks and new mocks. If local WoW is available, deploy exclusively via `tools/deploy.ps1` after green tests, collect logs/errors/screenshots through documented tools, and verify behavior with competitor disabled and then enabled. Without live evidence mark `IMPLEMENTED / NEEDS IN-GAME GATE`, not `WORKS`.
6. **Record:** update the status ledger with task IDs, dependencies, source file paths, commit SHA, tests, in-game observation, and actual acceptance level. Update HelpData/USER_GUIDE, CHANGELOG, and relevant probes when appropriate. Commit the smallest coherent set to `p1-foundation`. Recheck head and test results before next task.
7. **Repeat** for the next eligible item. Do not ask for permission on routine implementation details covered by existing rules. Stop and report only when requiring gameplay/manual approval, an unavailable dependency, a policy/licensing decision, failing tests that cannot be resolved, or the current execution session ends.

## Order and dependencies
- First validate quick wins **#1 XP pace**, **#2 layer bar/history**, **#3 actual corpse arrow**. Source changes landed via GitHub connector on 2026-11-18 but have not run the full local test suite or passed in-game gates.
- Next cheap wins: **#4 sell lists and never-sell**, **#5 vendor restock with a gold reserve**, **#6 persistent waypoint queue** (prerequisite for **#21 rare routes**), **#7 cursor coordinates**, **#8 tooltips**, **#9 aspect/Growl alerts**, then #10–15.
- Probe in parallel, without inventing results: **#16 Auto Shot timer**, **#17 threat including pet**, **#25 C_DamageMeter**, pet happiness source, and **C_DeathInfo.GetCorpseMapPosition**.
- Then **#18 graveyard map**, **#19 dungeon quests**, **#21 rare route**, **#22 zone leveling guidance**, and the big builds **#33 step-by-step leveling**, **#34 unified bags**, **#35 dungeon journal**, before the lower-impact expansions.
- After five core big gaps, build the **Switch to Outrider importer** as an isolated desktop application/data migration capability: read-only source SavedVariables, preview/dry-run, permission-aware imports, reversible backups, licensing checks, no automatic disabling of other addons.
- Finally complete the full 107-item broader roadmap, resolving duplicates and truly client-ineligible options via evidence instead of counting them as failures.

## Acceptance and progress semantics
- `NOT STARTED`: no code.
- `IMPLEMENTED / UNTESTED`: code and tests written but not executed, or tests not proven.
- `TESTS GREEN / NEEDS GAME`: full suite passes but real client not yet verified.
- `WORKS`: independent real-game behavior, screenshots/logs, no taint, competitor disabled.
- `MATCHES`: all relevant raw competitor-option rows accounted for, in-game comparison proven.
- `SURPASSES`: an evidence-backed, measured Outrider advantage over specialist tools.
- `BLOCKED/CAN'T`: prohibited by the project rules or verified unavailable API, with reason/source.

A failed or absent CI result is **not** proof of success. Each invocation should produce honest tangible commits, not an endless verbal promise. Protect `main`.

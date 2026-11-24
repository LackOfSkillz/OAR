# Outrider independent phase review packet: Phase 1 (Production stabilization)

## Implementation submission (Claude)

- **Phase / task IDs:** OI01-01 to OI01-15, gate OI01-GATE.
- **Repository and branch:** LackOfSkillz/OAR, `ai/outrider-personal-intelligence`. **Not pushed yet**
  (pushing needs Gary's OK), so no CI run exists for this branch.
- **Base SHA:** `22c76ca4dee229306dc98c82b4543230f4cb4a55` (p1-foundation when the branch was cut).
- **Candidate SHA:** the commit that adds this packet (one docs-only commit after `8de1ffa`). The reviewer should take the
  exact SHA from `git log -1` on the pushed branch.
- **Diff:** `git diff 22c76ca..<candidate>`: 184 files, about +9000 / -4200 lines. Most of it is moved code
  (three file splits) and the comment-only rewrite (120 files, 464 lines in and out).
- **CI:** none yet for this branch. The workflow triggers on `ai/**` and runs `tools/test.ps1 -RequirePython`.
  The last CI is green at 272ae1b (run 45320432631).
- **Client:** WoW Forever 1.60.1 (TOC interface 16001). **No live evidence was collected in Phase 1.**
- **Scope excluded:** Luacheck and Ruff (downloads wait on the owner's OK); breaking up the 541-line
  Macros page builder; the in-game competitor and nine-class matrices.
- **Crosswalk:** TASKS.md, I2 and XP60 items are cross-referenced in OI01-01 and are not ticked. I2-09 stays
  blocked. XP60 stays an unverified developer beta.
- **Owner decisions in force:**
  - [Data preservation override](../../blueprint/OWNER_DIRECTIVE_DATA_PRESERVATION.md) (2026-11-24): blueprint provenance
    instructions are withdrawn; no data is removed or redacted.
  - Retention option 3: collected data archives instead of being deleted; logs keep caps; newer data may replace outdated data.
  - Branch approval and the live-wait rule (2026-11-24).

### Acceptance evidence table

| Task | Acceptance criterion | Changed files / symbols | Tests / fixtures | Command, exit, counts | Live evidence | Status / limits |
|---|---|---|---|---|---|---|
| OI01-01 | SHA, CI, reuse map, stale claims corrected | docs only | n/a | inventory | n/a | MOCK_GREEN |
| OI01-02 | policy table cites decisions | docs only | n/a | n/a | n/a | MOCK_GREEN; 2 owner items (D25 hidden channel, XP60 watcher) |
| OI01-03 | fresh baseline passes, main unchanged | docs | fixture hashes recorded | test.ps1 -RequirePython exit 0, 1010 + companion | n/a | MOCK_GREEN |
| OI01-04 | sanitized live measurements | Core/Perf.lua Runtime/Remember, Core/Boot.lua timings | perf_spec (+1) | green | **missing** | **LIVE_PENDING** |
| OI01-05 | provenance manifest | docs/PROVENANCE.md, tools/common.ps1 (ships ATT MIT text) | local zip build checked | n/a | n/a | MOCK_GREEN; superseded by owner directive (record only) |
| OI01-06 | tools in CI, baseline, real coverage | tools/quality.py, tests/run_tests.lua coverage hook, test.ps1 gate | quality selftest | 23 then 22 findings baselined; 90.7% measured line coverage | n/a | MOCK_GREEN; Luacheck/Ruff pending OK |
| OI01-07 | comment-only, facts kept | 120 Lua files comments; tools/comment_only.py | token-stream equality vs base | 120 files, 0 code changes | n/a | MOCK_GREEN |
| OI01-08 | page ids and nav unchanged | UI/Pages.lua into UI/Pages/*.lua | hub, tips, boot specs; tab-order dump | byte-identical tab list | in-game look pending | MOCK_GREEN |
| OI01-09 | macro behaviour unchanged | MacroTree, MacroTreeModel, MacroTreePage | 7 macro specs, 44 cases | green | drag in game pending | MOCK_GREEN |
| OI01-10 | query, stale, confirm, close pass | GearShop, GearShopRank, GearShopView | gearshop_spec 16 | green | AH check pending | MOCK_GREEN |
| OI01-11 | refused event is unavailable; disable cleans up | Core/Events.lua, Core/Modules.lua (After/Ticker/CancelTimers), LagCheck, FishingRing | eventsemantics_spec 5 | green | n/a | MOCK_GREEN |
| OI01-12 | rejects new cycles or private coupling | tools/deps.py, deps baseline, gate | `--check` in test.ps1 | 32 pairs / 48 private reads baselined, 0 new | n/a | MOCK_GREEN |
| OI01-13 | negative fixtures caught; limits stated | tools/security_check.py; FishBook Share copy box | selftest plus repo check | 0 violations | n/a | MOCK_GREEN |
| OI01-14 | data preserved; rollback documented; backup | Core/Archive.lua, 27 stores | archive_spec 6, db_spec, safety_spec | green | SV backup 20261124-083048 | MOCK_GREEN |
| OI01-15 | journeys pass, blockers listed, competitor matrix | FishingRing yieldsTo | full suite | 1022 passed, 0 failed; companion, quality, deps, security clean | **list for Gary** | MOCK_GREEN + LIVE_PENDING items |

Per-task detail: `docs/reviews/phase1/OI01-xx.md`. Tracker: `docs/blueprint/TRACKER.md`.

### Defects found and fixed in Phase 1

- P1 (policy): the FishBook Share button, added earlier on 2026-11-24, reached `SendChatMessage`
  through a string lookup and slipped past the old regex check. Fixed: it is now a copy box, and the
  new token check catches string lookups.
- P2: failed event registration was reported as success (OI01-11).
- P2: LagCheck and the fishing ring's flyout kept a ticker running after the module was disabled (OI01-11).
- P2: the fishing ring did not step aside for FishingBuddy, ForeverFishing or FishFry (OI01-15).

### Known risks and open items

- **The archive grows the SavedVariables file over time** (by design, owner decision). The perf report now
  records `archiveRows`, so growth can be watched.
- PartyQuests sends quest-progress lines to PARTY chat on quest events (setting on by default). It is
  allowed and reviewed; Gary may want it off by default.
- Owner decisions: the D25 hidden-channel test (keep or remove), downloading Luacheck and Ruff,
  pushing the branch for CI.
- Live: OI01-04 measurements, and the in-game checks in OI01-15.

### Rollback

Each task is one commit. `git revert <sha>` undoes it. SavedVariables backup: `tools/backup-sv.ps1 -Restore 20261124-083048`
(game closed). The archive only adds data; reverting Core/Archive.lua leaves archived rows in the file, unused.

## Independent review (ChatGPT fills after Gary submits branch/SHA)

| Finding ID | Severity (P0-P3) | File/symbol and evidence | Requirement violated | Required correction | Regression test | Status |
|---|---|---|---|---|---|---|
| | | | | | | |

Decision: `REVIEW_CHANGES` / `REVIEW_ACCEPTED` (scope stated) / `BLOCKED`.

## Product owner decision (Gary)

- Live evidence approved / outstanding:
- Policy decisions (D25 hidden channel; Luacheck and Ruff downloads; PartyQuests default):
- Approve Phase 2 / request revisions / defer with the feature disabled:
- Push and CI approval:

---

## Resubmission 1: response to ChatGPT review REVIEW_CHANGES (reviewed candidate 8a61733)

The earlier review record above is kept unchanged. Phase 2 has not started; nothing is merged or published.

| Finding | Severity | Correction | Evidence |
|---|---|---|---|
| OI01-R01 identity | High | Archive contract v2: an entry is `{id, path, keys, scope, char, at, row}`. Every call site passes its logical saved path and parent keys: itemID (prices, price history, watch, auction posts), npcID (sightings, respawn obs, rare casts with spell), mapID (trail), spot (spawn log), who (whispers), realm and name (census), character (quest diary), candidateId, macro name, and so on. `row` is the original table. `Archive:Restore` hands entries back for rebuilding. | `archive_spec`: identity checked per dataset; Restore rebuilds all 5 sightings in order |
| OI01-R02 fail-safe | High | `Move/Shift/Pop`: Put, then confirm the write, and only then `table.remove`. Errors are caught. On failure the row stays, it is reported once per dataset, and the result is false. Every trim is `while #x > CAP and Archive:Shift(...) do end` or `if ... and Archive:Put(...) then remove`, so a failure stops the loop. | Failure injection: Put returning false and Put throwing both keep all rows; a real store (Prices) under failure keeps its rows; a static test checks that every call site is fail-safe and names a path |
| OI01-R03 audit | High | A repo-wide audit (267 findings in 8 classes) covers the reviewer's Alts runs case and 11 more automatic losses, all now archived: census players and professions, AH search history, mail recipients, catches per skill point, whole whisper partners, price watch eviction, radar feedback, next-session dismissals, XP60 schema reset, plus judgment calls (profile schema, old trainer rows, previous macro bodies, lockouts). | `docs/quality/data_preservation_audit.json` (42 datasets, each with mechanism, destination and tests; 267 findings with a resolution each); `archive_spec` "retention audit fixes" |
| OI01-R04 malformed | Moderate | `ns.KeepBad` / `ns.KeepTable` (Core/Init.lua) keep any damaged saved value, unchanged, with where it was found, in `global.archiveDamaged` before a fresh table is used. Values met before the saved data is ready are buffered and flushed after DB init. This is applied at 156 saved-data sites, including the DB roots, ApplyDefaults and every module store. Sites holding fresh API results were left alone. A damaged archive, a damaged archive set and even a damaged damaged-list are all kept. The old test that expected replacement now expects preservation. | `archive_spec` damaged-archive cases; "damaged saved values are kept" (DB root "oops", chars 5, a bad layer row) |
| OI01-R05 tests | High | `archive_spec` went from 6 to 20 cases, plus a static contract: every archive call site is fail-safe and names a path, and every dataset in code is listed in the audit JSON. Covered: identity per dataset, failure injection, malformed recovery, logout and reload persistence with a second character (isolation filter), counts (working + archived = recorded), Restore reconstruction, the player's two-click clear now archived. Existing `safety_spec` covers migration rollback (failing or missing step leaves the original untouched). | Full suite 1036 passed, 0 failed |
| OI01-R06 growth | Moderate | [docs/ARCHIVE_GROWTH.md](../../ARCHIVE_GROWTH.md): estimated growth per dataset (full-scan daily auction lows are the largest, up to ~0.75 MB per scanning day after day 14), memory and load-time effects, self-collected measurement (`perfRuns[].runtime.archiveRows`, boot ms, SV size), a proposed warn-only budget, and a lossless off-load design (companion copies, verifies, acknowledges through the D16 data file; Outrider removes only acknowledged ids). Not built; needs owner approval. Stable entry ids were added now for it. | doc |

Limits that remain:
- **Behaviour drivers:** 17 of the 42 datasets are covered by the static contract and code review instead of a per-dataset behaviour test, because their recorders need live unit, auction or instance state: dungeon runs, trail, spawn log, fights, XP sessions, ledgers, posts, pets, discoveries, rare cast gaps, fish sessions, catches per point, radar, next session, trainer rows, macro bodies.
- **Backup restore:** `tools/backup-sv.ps1 -Restore` needs the game closed and was not exercised in CI.
- **Live client:** all live checks are still outstanding.

---

## Resubmission 2: response to ChatGPT resubmission review (reviewed 5813e9f, REVIEW_CHANGES)

Targeted fixes only; no broad refactor. The earlier records above are kept. The commit
`2cb89ca` (Path performance: search once per destination, sliced across frames) landed between the
reviews, after a lag check in game; it is a separate fix and is included in this candidate.

| Finding | Correction | Evidence |
|---|---|---|
| OI01-R07 Critical, resets | `DB:ResetChar`/`ResetAll` no longer delete anything. They reset **settings only**: module defaults that are plain values or filled-in tables, the window position and module on/off. Empty-table defaults are data containers (layer history, seen lists, words) and stay, like everything undeclared. The old settings are archived first (`settingsReset`); if that fails, nothing changes. `ResetAll` no longer sets `Outrider_DB = nil`. The command text now says "settings back to defaults (collected data and the archive are kept)". Player clears of collected knowledge archive what they clear: census reset, trail clear, route delete, radar Clear feedback, instance entry delete, and the map tab's two-click clear (from resubmission 1). Edits of the player's own preferences (lists, words, gear sets, macros, layouts, talent picks) are unchanged and listed in the audit. | `safety_spec` "reset all puts settings back...": prices, fights, data inside module settings, the archive and undeclared module data survive reset, logout and reload; old settings archived. `archive_datasets_spec` "trail clear, census reset, route delete, radar clear and instance delete are archived" |
| OI01-R08 High, malformed root | A non-table `Outrider_DB` is kept through `ns.KeepBad` (buffered before DB init, flushed into `global.archiveDamaged` after). | `archive_datasets_spec` "a damaged Outrider_DB root is kept and survives the next load" |
| OI01-R09 Moderate, immutability | `Archive:Put` stores a deep copy of the row and keys (a snapshot). Later edits to the source can't change history. | `archive_datasets_spec` "archived entries are snapshots" (nested table too); contract test updated |
| OI01-R10 Moderate, untrusted input | 29 keep sites on values that were never saved were reverted to plain validation (reject, don't keep): shipped data packs, a pasted advice code, an imported profile, macro import strings, party messages, game API results (owned auctions, vignettes, map exploration, quest objectives, C_DamageMeter). 138 sites remain, all on SavedVariables values. `archiveDamaged` is capped at 500 entries; beyond that values are only counted (`archiveDamagedOverflow`) and nothing kept is removed. | `archive_datasets_spec` bounded-damaged test; policy in the audit JSON (`keep_bad_policy`) |
| OI01-R11 Moderate, behaviour coverage | New `archive_datasets_spec.lua` (17 cases). It drives the real recorders, with small named fixtures (a fake unit, a stubbed meter session list, a stubbed spot) where live client state is needed. Covered: dungeon runs, trail, spawn log, fights, XP sessions, sales ledger, pets seen, gold ledger, rare cast gaps, fish sessions, catches per point, next-session dismissals, recent discoveries; persistence across logout and load. **43 of 47 datasets now have behaviour tests.** The other 4 (`auctionPosts`, `radarFeedback` overflow, `trainingOldFormat`, `macroPrevBodies`) need auction-house posting, opportunity cards or the macro API that the mock can't fake honestly. They keep the static contract and are marked `live_pending` in the audit. | `docs/quality/data_preservation_audit.json`: 47 datasets with `behaviour_tested` and `live_pending` flags |

Full suite at the candidate: 1055 passed, 0 failed; companion passed; quality 0 new; deps 0 new;
security 0 violations. Outstanding live-client requirements: OI01-04 runtime row, the in-game checks
listed in OI01-15, the 4 live_pending datasets, and the Path stutter re-check.

---

## Resubmission 3: response to ChatGPT resubmission-2 review (reviewed da058c0, REVIEW_CHANGES, limited)

Targeted corrections only; the architecture is unchanged.

| Finding | Correction | Evidence |
|---|---|---|
| OI01-R12 High, damaged-data cap | The 500-entry cap and the overflow counter are removed. `Archive:KeepDamaged` always keeps a previously saved value. Before the saved data is ready it waits in the pending list and is flushed after DB init, so it never returns false. Only saved values reach it (R10: incoming messages, packs, pasted codes and API results are rejected by their callers). The acceptance test that allowed a value to be dropped is replaced. | `archive_datasets_spec` "previously saved damaged values are always kept, however many there are": 600 kept, plus a damaged saved store after that is still kept |
| OI01-R13 Route cache | The signature is a trail revision: the trail module's counter (raised on every new dot and every clear) plus each map's size, oldest and newest dot. A change at the per-map cap (count unchanged, oldest dot archived, newest added) or data replaced by an import starts a new search. The world-dot cache per map is also rebuilt when its first or last dot changes, not only its length. Path uses the player's breadcrumbs, the shipped trails and the patrol pack, not player-drawn routes, so route edits don't affect it. | `path_spec` "a trail change at the per-map cap, or a clear, makes a new search" |
| OI01-R14 Route performance | Building the network is now sliced too: phase "gather" walks the sources inside the box with a budget check every 256 points, then heapify (O(n) instead of n pushes), then the search with a budget check every 16 heap pops (was 64). On a destination change the old dots are cleared at once, so a way to the previous destination is never shown while the new search runs; the same destination keeps its dots while it refreshes. The next-frame slice uses a module-owned timer (`Module:After`), so disabling Path cancels it and drops the pending search. | `path_spec`: "changing destination never shows the old way while the new search runs", "gathering the network is sliced too, and disabling cancels the pending slice"; plus the earlier slicing-equivalence and re-use tests |

Measured off-game (Lua 5.1 through lupa on the dev PC, a 4000-node synthetic network): full search
25 ms, now spread over 4 ms slices; a re-plan while walking 0.26 ms (was 67 ms before `2cb89ca`).
**The in-game stutter reduction is still not measured** and stays on the live list (lag check with a
destination set).

Full suite: 1058 passed, 0 failed; companion passed; quality, deps and security clean.

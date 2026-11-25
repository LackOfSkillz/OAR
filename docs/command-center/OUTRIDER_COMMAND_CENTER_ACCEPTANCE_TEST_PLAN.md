# Outrider Command Center: acceptance test plan

**Status: PLANNING ONLY.** This plan defines what each review gate (G0 to G8) must show and who produces the evidence. Task IDs are from the implementation backlog; requirement IDs are from the engineering spec.

## 1. Rules for evidence

1. **Synthetic is synthetic.** Fixture, mock and stand-in results prove logic. They are never reported as live or owner-PC evidence. Every evidence table has a "Source" column: `CI/fixture`, `owner PC`, or `owner in game`.
2. **Fresh clone.** Every gate packet includes a full-suite run from a fresh clone at the exact gate SHA (`tools/test.ps1 -RequirePython`), with its exit code and counts.
3. **Fail closed.** A check that cannot run counts as failed, not passed. This is the FR17 rule, applied to every gate tool.
4. **Self-collecting.** Owner steps are plain actions: open the app, play, log out, say done. Command Center and the addon log what Claude needs. The owner never types debug commands mid-play.
5. **CI.** GitHub Actions runs the same suite. While CI is blocked (the billing limit at the time of writing), the packet says so and relies on the fresh-clone log.

## 2. Fixture corpus (OCC-00-07)

| Fixture | Contents | Used by |
|---|---|---|
| `occ/small_two_accounts` | 2 accounts, 3 realms, 9 characters (every class), 1 week | Most unit tests |
| `occ/three_years` | 1 account, 4 characters, 3 simulated years, all 72 datasets archived and active | Analytics, performance, parity |
| `occ/damaged` | Wrong types, an `archiveDamaged` list, an old-schema store plus a `*Staging` store, a truncated file, code-shaped content | Parser safety, preservation |
| `occ/revisions` | The same archive ids with changed rows across three files | Idempotency and revisions |
| `occ/large_20mb` | Generated at test time from a seed; not committed | Performance and the parser cap |
| `occ_contract.json` | The frozen SavedVariables, archive, Advice.lua and passport shapes | Lua spec and Python contract test |
| `occ_parity.json` | Shared inputs and expected AfterAction and Estimator outputs | Lua and Python parity tests |

Each fixture has a manifest of expected counts per dataset and per character. Names are invented, and a security check scans the fixtures for the owner's character names.

## 3. Gates

### G0: Foundation (OCC-00-08)

| Check | How | Source |
|---|---|---|
| Owner decisions D01-D09 recorded word for word | ADR files and DECISIONS.md | Owner |
| Reuse inventory matches the tree | OCC-00-01 file, spot-checked by the reviewer | CI |
| Contract tests fail on a temporary dataset rename | Demonstration log | CI |
| Security selftest catches the new negative fixtures | `security_check.py --selftest` | CI |
| Fixture manifests match a parse | `test_fixtures.py` | CI |
| Full suite from a fresh clone | Log | CI |

### G1: Desktop foundation (OCC-01-09)

| Check | How | Source |
|---|---|---|
| Single instance; loopback only; a request without the token gets 403; wrong Host or Origin gets 403 | `test_app.py` | CI |
| Settings migrate; the old companion still reads them | `test_settings.py` plus the existing companion tests | CI |
| The game folder is unchanged after discovery (tree hash) | `test_locate.py` | CI |
| No read while the game runs; unstable bytes are refused | `test_stable.py`; the existing XP60 delivery tests unchanged | CI |
| The 15 MCP tools are unchanged | `test_compat.py` | CI |
| The app window opens; the browser fallback works | Screenshot | Owner PC |

### G2: Knowledge Vault (OCC-02-11)

| Check | How | Source |
|---|---|---|
| Schema matches data contracts section 5 | `test_schema.py` | CI |
| Migrations back up first; a migration failing halfway leaves the vault unchanged | `test_migrate.py` | CI |
| Re-ingest adds 0 rows; a changed row becomes a new revision; every earlier revision kept | `test_ingest_archive.py` on `occ/revisions` | CI |
| 72/72 datasets registered; an unknown dataset is stored as generic | `test_datasets.py` | CI |
| 0 rows without provenance | SQL check in `test_provenance.py` | CI |
| Character isolation of the query API | `test_query.py` | CI |
| Backup, restore and compare; corruption detected with the broken file kept | `test_backup.py` | CI |
| Confirmations written only after read-back, only with the game closed; AdviceLoader ignores a malformed block | Python tests plus `advice_confirm_spec.lua` | CI |
| **Real ingest:** counts per dataset equal the addon's counts | The ingest report from the owner's file, read by Claude | Owner PC |
| OCC-02-09b only with written D05 approval: remove, rebuild from the vault, compare at 100% | Drill log | CI, then owner PC |

### G3: Analytics (OCC-03-09)

| Check | How | Source |
|---|---|---|
| Sessions rebuilt, archived segments included, inferred sessions flagged | `test_sessions.py` | CI |
| Progression, economy and world figures equal the manifest | Module tests | CI |
| 9 classes resolve; an unknown spec is shown as "unknown"; own class first | `test_profile.py` | CI |
| Trend explanations match the fixture's cause; too few samples says so | `test_trends.py` | CI |
| Parity with the Lua AfterAction report | `occ_parity` Lua spec and Python test | CI |
| The owner's own characters look right | Screenshot and the owner's words | Owner PC |

### G4: Planning (OCC-04-08)

| Check | How | Source |
|---|---|---|
| Goals round-trip as v4; invalid records refused | `test_goals.py` | CI |
| Planner golden outputs unchanged with the adapter | Existing planner tests plus `test_adapter.py` | CI |
| Estimator parity with Lua to 1e-9 | Parity tests | CI |
| Plan fits the budget; every step has evidence | `test_session_plan.py` | CI |
| Delivery refused while the game runs; the OTR1 code round-trips through `Serialize.lua` | Python and Lua tests | CI |
| Feedback: estimate error recorded once per plan | `test_feedback.py` | CI |
| **Real loop:** plan, paste the code, play, log out; Claude reads the feedback row | Ingest plus addon log | Owner in game |

### G5: AI (OCC-05-08)

| Check | How | Source |
|---|---|---|
| A made-up number is rejected; a wrong citation is rejected | Poisoned stand-in provider tests | CI |
| The envelope has opaque ids only and no social data; preview bytes equal sent bytes | `test_privacy_filter.py` | CI |
| Keys never in logs, the vault or responses | Scan test | CI |
| Every endpoint works with AI off, with zero sockets | `test_ai_off.py` plus the egress harness | CI |
| Eval thresholds: with no model, at least 23/25 deterministic answers are correct; with the valid stand-in, 25/25 citations are valid; with the poisoned stand-in, 0 accepted fabrications | `test_eval25.py` extension | CI |
| Optional real provider with the owner's key and consent | The exchange log row | Owner PC |

### G6: Presentation (OCC-06-09)

| Check | How | Source |
|---|---|---|
| Every route renders; keyboard reaches every control | `test_ui_routes.py` | CI |
| Every page has a purpose line and 1-2-3 steps | `test_ui_copy.py` | CI |
| Contrast is at least 4.5:1 for every token pair | Contrast script | CI |
| Chart values equal table values | `test_charts.py` | CI |
| No delete endpoint exists | Security test | CI |
| Screenshots of every screen at 100% and 150% | Packet | Dev only (D19) |
| One evening of real use; confusing points listed | The owner's notes | Owner PC |

### G7: Hardening (OCC-07-08)

| Check | How | Source |
|---|---|---|
| Local server attacks blocked (section 4) | `test_server_security.py` | CI |
| Egress: zero connections with AI off; only the previewed envelope with AI on | Egress harness (section 5) | CI |
| Recovery drills: 0 confirmed rows lost | Drill log (section 6) | CI |
| Performance budgets (section 7) | `occ-bench.py` | CI, then owner PC |
| Every vault and config version upgrades without loss | `test_upgrades.py` | CI |
| Value-for-value preservation from SavedVariables to the vault for 72/72 datasets, fail closed | `occ_preservation.py --require-content` | CI |

### G8: Release readiness (OCC-08-07)

| Check | How | Source |
|---|---|---|
| End to end on every fixture | `test_e2e.py` | CI |
| Install and uninstall in a temp profile; the vault survives | `test_package.py` | CI |
| Clean-machine install checklist (section 9) | The owner's report | Owner PC |
| Live: two evenings, two or more characters; figures equal the addon's | Claude's evidence report | Owner in game |
| Licensing: GPLv3 and third-party notices complete | License script | CI |
| All gate packets accepted | Review log | Reviewer |

## 4. Local server security tests (G1 and G7)

| Test | Expected result |
|---|---|
| A request with no token, or the wrong one | 403 |
| Host header other than `127.0.0.1:<port>` or `localhost:<port>` (DNS rebinding) | 403 |
| A cross-site Origin, or a state-changing request with a missing Origin | 403 |
| A state-changing request without the anti-CSRF header | 403 |
| `GET /static/../../config.json` (and encoded variants) | 404, and the file is not read |
| A body over the size limit | 413 |
| Bind address | 127.0.0.1 only, never 0.0.0.0 |

## 5. Egress test

**Harness:** monkeypatches `socket.socket.connect`, `socket.create_connection`, `http.client.HTTPConnection.connect` and `urllib.request.urlopen` to record every attempt. Loopback is allowed only for the app's own server.

| Run | Expected result |
|---|---|
| Full app run on fixtures with AI off: ingest, analytics, plan, coach, backup | 0 non-loopback attempts |
| With the stand-in cloud provider and consent on | Exactly one request per question, and its bytes equal the stored preview |
| Without consent | 0 attempts, and a clear message to the user |

## 6. Recovery drills (OCC-07-04)

| Drill | Expected result |
|---|---|
| Kill the process during an ingest transaction | The vault is unchanged. The next ingest completes. |
| Corrupt the vault file (overwrite bytes) | Detected at startup. The app opens read-only, the restore makes a new file, and the broken file is kept. |
| Disk full during a backup | The backup fails cleanly and the vault is unchanged. The user is told. |
| Damaged SavedVariables (truncated, or code-shaped) | The ingest run is marked failed and nothing is written. |
| Restore an old backup, then re-ingest | Everything confirmed since the backup returns from SavedVariables. Anything removed by off-load (09b) returns from the vault's own export. |
| Delete `config.json` | The app starts with defaults. The backed-up config is offered. |

**Pass condition for every drill:** the row-checksum set of confirmed rows before the drill is a subset of the set after it.

## 7. Performance protocol (QR-01)

- **Measurements:**
  - full ingest of `occ/large_20mb`
  - incremental ingest after one simulated session
  - opening each dashboard on `occ/three_years`
  - peak memory (via `tracemalloc` plus the process working set)
  - vault size
- **Method:** five runs, reporting the median and the worst. The CPU and Python version are recorded.
- **Two columns, never merged:** CI or dev PC, and owner PC. The QR-01 budgets are judged on the owner's PC.
- **If a budget is missed:** report the gap and add a fix task. The budget is never changed silently.

## 8. End-to-end scenario (OCC-08-01)

The scenario runs these steps in order, then repeats them for each fixture:

1. Locate
2. Stable read
3. Ingest
4. Re-ingest (no change)
5. Analytics
6. Plan
7. Clipboard delivery
8. Advice.lua delivery (game closed)
9. A simulated next session
10. Ingest
11. Feedback
12. Coach with AI off
13. Coach with the stand-in
14. Backup
15. Corrupt the vault
16. Restore
17. Compare

## 9. Clean-machine checklist (OCC-08-03, Owner)

1. A Windows 10 or 11 machine or VM without the repository or Python.
2. Unzip, then run Setup.cmd. Note any SmartScreen prompt.
3. Open Command Center. Note whether WebView2 was present, or the browser fallback was used.
4. Point it at a copied SavedVariables file (or the real game). It ingests.
5. Check that the Home screen shows the last session.
6. Uninstall. Check that the vault folder remains and the program folder is gone.
7. Report each step as pass or fail, with screenshots.

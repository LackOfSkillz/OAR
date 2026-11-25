# Outrider Command Center: implementation backlog

**78 microtasks across 9 phases (OCC-00 to OCC-08), including 9 review gates.**

| Phase | Tasks | Gate |
|---|---|---|
| OCC-00 | 8 | G0 |
| OCC-01 | 9 | G1 |
| OCC-02 | 12 | G2 |
| OCC-03 | 9 | G3 |
| OCC-04 | 8 | G4 |
| OCC-05 | 8 | G5 |
| OCC-06 | 9 | G6 |
| OCC-07 | 8 | G7 |
| OCC-08 | 7 | G8 |

**Status:** every task is NOT_STARTED. **No task may start until the owner has decided D01-D09** (engineering spec, section 9) **and the independent review accepts this package.** OCC-00 tasks that only write documents may start after the review. Tasks that write code start only once G0 passes.

Read this with `OUTRIDER_COMMAND_CENTER_ENGINEERING_SPEC.md` (requirement IDs FR-xx and QR-xx, capabilities Cxx, decisions Dxx) and the acceptance test plan (gates G0-G8).

## Common protocol (applies to every task)

| | |
|---|---|
| **Dependencies** | The default dependency is the task immediately before. A task may run in parallel only when this backlog says so or the reviewer allows it. |
| **Tests** | Unit tests for every piece of logic. The full suite (`tools/test.ps1 -RequirePython`) is green before every commit that touches code. Quality, deps, security and preservation gates show 0 new findings (QR-05). |
| **Boundaries** | No game automation, no writes to the game folder except Advice.lua with the game closed, and no deletion of collected data (security document, section 1). |
| **Paths** | New code lives under `companion/outrider_companion/command_center/` (D09), unless a task says it extends an existing file. |
| **Commits** | `OCC-xx-yy: <what>` on branch `occ-command-center` (D09). Never merged into `main` without the owner. |
| **Evidence** | Mock or synthetic numbers are never reported as live evidence. A task that needs the owner's PC or game is marked **Owner**. |

---

## OCC-00: Architecture, policy boundaries and repository foundation (8)

### [ ] OCC-00-01: Reuse inventory baseline

| | |
|---|---|
| **Objective** | Re-verify, at the start commit, the inventory in spec section 3, so no existing capability is rebuilt. |
| **Depends on** | Owner decisions D01-D09 and acceptance of this package |
| **Scope** | Read-only. Covers every module in `companion/outrider_companion/` and `intelligence/`, `Core/Archive.lua`, the 72-row `docs/quality/data_preservation_audit.json`, and the export codes (OTR1, OTRP1, OTRROUTE). |
| **Deliverables** | `docs/command-center/REUSE_INVENTORY.md`: start SHA, then one row per component with path, purpose, test file and a decision (reuse, extend or wrap). |
| **Tests** | None (documentation) |
| **Acceptance** | Every row in spec section 3 is confirmed or corrected with a path. Any component missing from the spec is added. |
| **Documentation** | Inventory file. The spec is corrected if it was wrong. |
| **Review gate** | G0 |

### [ ] OCC-00-02: Policy boundary register

| | |
|---|---|
| **Objective** | Turn the boundaries into a checkable register: each rule linked to the test or gate that enforces it. |
| **Depends on** | OCC-00-01 |
| **Scope** | D6, D16, D18, D20, D22, the data preservation override, CLAUDE.md rules 1-10, and the owner decisions D01-D09 once they are made. |
| **Deliverables** | The policy register table in the security document, section 1, with an "enforced by" column. |
| **Tests** | None yet. Each row names the test that will enforce it, which is written in OCC-07. |
| **Acceptance** | No rule without an enforcing test or gate, or an explicit "manual review" note. Conflicts are listed for the owner. |
| **Documentation** | Security document, section 1 |
| **Review gate** | G0 |

### [ ] OCC-00-03: Architecture decision records

| | |
|---|---|
| **Objective** | Record each owner decision, and each technical choice that follows from it, as an ADR. |
| **Depends on** | OCC-00-02 |
| **Scope** | ADR-01 to ADR-10 (architecture document, section 8): UI host, dependency policy (the D16 amendment), packaging, ingest trigger, off-load, social data, name, cloud default, code location, and SQLite through stdlib `sqlite3`. |
| **Deliverables** | `docs/command-center/adr/ADR-xx-*.md` with context, decision, consequences and owner date. `docs/DECISIONS.md` gets a D-entry for each owner decision. |
| **Tests** | None |
| **Acceptance** | Every ADR cites the owner's answer word for word. No ADR is marked decided without it. |
| **Documentation** | ADR files and DECISIONS.md |
| **Review gate** | G0 |

### [ ] OCC-00-04: Package layout and branch

| | |
|---|---|
| **Objective** | Create the empty package skeleton and branch so later tasks have a fixed home. |
| **Depends on** | OCC-00-03 |
| **Scope** | Branch `occ-command-center` from the accepted intelligence branch. Package `command_center/` with `__init__.py` and empty submodules: `app`, `ui`, `ingest`, `vault`, `analytics`, `planning`, `ai`, `reports`, `diag`. Extend `tools/test.ps1` to discover `companion/tests/command_center/test_*.py`. |
| **Deliverables** | The skeleton, one placeholder test, and the test.ps1 change |
| **Tests** | The placeholder test runs inside the full suite. quality.py and deps.py cover the new package. |
| **Acceptance** | Full suite green. `deps.py --check` shows the package imports nothing from the addon tree (QR-05). |
| **Documentation** | Architecture document, section 4, confirmed |
| **Review gate** | G0 |

### [ ] OCC-00-05: Contract freeze

| | |
|---|---|
| **Objective** | Freeze the inputs Command Center depends on so a change to the addon fails a test instead of the vault. |
| **Depends on** | OCC-00-04 |
| **Scope** | The SavedVariables top level (`Outrider_DB`, `Outrider_Log`, `Outrider_Snapshots`). The archive v2 entry shape (`Core/Archive.lua`: id, path, keys, scope, char, at, row). The 72 dataset names. The OTR1 and OTRP1 codes (`codes.py`, `passport.py`). The Advice.lua shape (`advice.py`). |
| **Deliverables** | `companion/tests/fixtures/occ_contract.json`, and a Lua spec plus a Python test that check the same fixture (the passport contract pattern) |
| **Tests** | `tests/spec/occ_contract_spec.lua` and `companion/tests/command_center/test_contract.py` |
| **Acceptance** | Renaming a dataset or changing the entry shape in the addon fails both tests (shown by a temporary change). Covers FR-02 and FR-03. |
| **Documentation** | Data contracts document, sections 2 and 3 |
| **Review gate** | G0 |

### [ ] OCC-00-06: Gate harness extension

| | |
|---|---|
| **Objective** | Make the existing gates cover the new package before any feature code exists. |
| **Depends on** | OCC-00-05 |
| **Scope** | `tools/security_check.py`: new rules for the command_center package. No `subprocess` with shell, no `eval` or `exec` of model text, no file writes outside the vault directory and Advice.lua, and no sockets except the loopback server and the provider layer. `tools/quality.py`: the package is in scope. |
| **Deliverables** | Rules plus negative fixtures for `--selftest` |
| **Tests** | `security_check.py --selftest` catches each new negative fixture. |
| **Acceptance** | Each new rule has a failing fixture and passes on the clean tree. Covers QR-05. |
| **Documentation** | Security document, section 6 (checklist) |
| **Review gate** | G0 |

### [ ] OCC-00-07: Synthetic SavedVariables fixture corpus

| | |
|---|---|
| **Objective** | A realistic, synthetic test corpus that every later phase uses. It contains no real player data. |
| **Depends on** | OCC-00-05 (can run in parallel with OCC-00-06) |
| **Scope** | A generator script `tools/occ_fixtures.py` (stdlib, seeded). It produces two WoW accounts, three realms and nine characters (every class, including both factions' classes). Each has archive v2 entries for all 72 datasets, play sessions over 3 simulated years, damaged values (wrong types, an `archiveDamaged` list), an old-schema store with a matching `*Staging` store, duplicate archive ids with changed rows, and one 20 MB file. Names are invented. |
| **Deliverables** | The generator, small checked-in fixtures under `companion/tests/fixtures/occ/`, and the large file generated at test time, not committed |
| **Tests** | `luadata.parse` reads every fixture. `tools/sv_dump.lua` reads the small ones. Each fixture has a manifest of expected counts. |
| **Acceptance** | The manifest counts match a parse. The generator is deterministic from its seed. No real character names appear (security check). Covers QR-04. |
| **Documentation** | Acceptance test plan, section 2 |
| **Review gate** | G0 |

### [ ] OCC-00-08: Gate G0, foundation review

| | |
|---|---|
| **Objective** | Independent review of the decisions, contracts, skeleton and fixtures before feature code. |
| **Depends on** | OCC-00-01 to OCC-00-07 |
| **Scope** | Review packet `docs/reviews/OCC_G0_PACKET.md`: SHAs, test evidence and open decisions |
| **Deliverables** | The packet, a fresh-clone full-suite log, and the reviewer's decision |
| **Tests** | Full suite from a fresh clone, exit 0 |
| **Acceptance** | Per the acceptance test plan, G0. The reviewer records REVIEW_ACCEPTED. |
| **Documentation** | Packet |
| **Review gate** | G0 (this task) |

---

## OCC-01: Desktop application framework and companion integration (9)

### [ ] OCC-01-01: Application shell and lifecycle

| | |
|---|---|
| **Objective** | One process that starts, runs a single instance, serves the UI on loopback and shuts down cleanly. |
| **Depends on** | G0 |
| **Scope** | `command_center/app.py`. A single-instance lock (named mutex through ctypes, or a lock file). A stdlib `http.server` bound to 127.0.0.1 on a random port. A per-launch 256-bit token. Checks the Host and Origin headers. Clean shutdown. |
| **Deliverables** | The app module and a `python -m outrider_companion.command_center` entry |
| **Tests** | A second instance hands off to the first. A request without the token gets 403. A wrong Host or Origin gets 403. The server binds only 127.0.0.1. |
| **Acceptance** | All tests pass. The egress check shows no listener on a non-loopback interface. Covers C01 and QR-03. |
| **Documentation** | Architecture document, section 3 |
| **Review gate** | G1 |

### [ ] OCC-01-02: UI host window

| | |
|---|---|
| **Objective** | Show the UI in a desktop window, per D01. |
| **Depends on** | OCC-01-01 |
| **Scope** | `command_center/ui/host.py`. With D01(a): a pywebview window on WebView2 that falls back to the default browser if WebView2 is missing. With D01(b): a tkinter host. Window size and position are remembered. |
| **Deliverables** | The host module and a static `ui/static/index.html` |
| **Tests** | The host chooses the right path when WebView2 is missing (simulated). Launching opens exactly one window. |
| **Acceptance** | On the owner's PC the window opens, and the browser fallback works when WebView2 is disabled (Owner check, batched into G1). Covers C01. |
| **Documentation** | UI/UX spec, section 2 |
| **Review gate** | G1 |

### [ ] OCC-01-03: Design tokens and component kit

| | |
|---|---|
| **Objective** | One visual system so every screen feels like one product. |
| **Depends on** | OCC-01-02 (can run in parallel with OCC-01-04) |
| **Scope** | `ui/static/tokens.css` takes its colours from the addon's `UI/Theme.lua` tokens. The dark and gold mood comes from the owner's concept art, as reference only. Components: card, stat tile, table, chart frame, status pill, empty state, purpose line, step list, and the evidence chip. |
| **Deliverables** | Tokens, components and a component gallery page (dev only) |
| **Tests** | Contrast check script: every text and background token pair is at least 4.5:1. Snapshot test of the gallery HTML. |
| **Acceptance** | The contrast check passes. The gallery renders in both hosts. Covers QR-06 and FR-14. |
| **Documentation** | UI/UX spec, section 3 |
| **Review gate** | G1 |

### [ ] OCC-01-04: Settings and configuration migration

| | |
|---|---|
| **Objective** | Command Center reads and extends the existing companion settings without breaking the current companion. |
| **Depends on** | OCC-01-01 |
| **Scope** | Extend the config loading in `store.py`. A new `commandCenter` block in `companion/config.json` holds the vault path, ingest trigger (D04) and backup schedule. Before the first change, the old file is copied to `companion/backups/<stamp>/`. Keys stay in Credential Manager (`keys.py`). |
| **Deliverables** | Config schema v2 with a migration and a settings API endpoint |
| **Tests** | An old config migrates, and the old companion still reads the migrated file. An unknown key is kept. A damaged config is kept aside and not overwritten. |
| **Acceptance** | The existing companion tests pass unchanged. No setting is lost (preservation override). Covers C01. |
| **Documentation** | Data contracts document, section 9 |
| **Review gate** | G1 |

### [ ] OCC-01-05: Game folder discovery (read-only)

| | |
|---|---|
| **Objective** | Find every WoW account's SavedVariables without asking the user to type paths. |
| **Depends on** | OCC-01-04 |
| **Scope** | Reuse `tools/local.json` (`wtfAccountDir`, `addonsDir`) and the `tools/find-wow.ps1` logic. List `WTF\Account\*\SavedVariables\Outrider.lua` across `_forever_` and other flavours. Open read-only only. |
| **Deliverables** | `ingest/locate.py` |
| **Tests** | A fake WoW tree with two accounts and two flavours. Nothing is created or modified in the tree (checked by hashing the tree before and after). |
| **Acceptance** | All files are found. The tree hash is unchanged. Covers C02 and FR-01. |
| **Documentation** | Architecture document, section 5 |
| **Review gate** | G1 |

### [ ] OCC-01-06: Game-closed detection and stable reads

| | |
|---|---|
| **Objective** | Read SavedVariables only when the game is closed and the file is complete. |
| **Depends on** | OCC-01-05 |
| **Scope** | Move the ctypes process check out of `next_session_delivery.py` into a shared `diag/gameproc.py` and use it from both places. The stable-bytes logic in `session_reader.py` (size, mtime and hash equal across two reads, a set interval apart) becomes a shared `ingest/stable.py`. |
| **Deliverables** | Two shared helpers. `next_session_delivery.py` and `session_reader.py` are refactored to use them, with no behaviour change. |
| **Tests** | The existing XP60 delivery tests pass unchanged. A file that changes between reads is refused. With the game running (simulated), the read is refused. |
| **Acceptance** | No read while the game runs. Existing tests green. Covers C03 and FR-01. |
| **Documentation** | Data contracts document, section 4 |
| **Review gate** | G1 |

### [ ] OCC-01-07: Local logging and diagnostics

| | |
|---|---|
| **Objective** | A local log and diagnostics page that let Claude and the owner see what happened, with no telemetry. |
| **Depends on** | OCC-01-01 |
| **Scope** | `diag/log.py`: rotating log files under the vault directory, with the rotated files archived rather than deleted. A crash handler writes a local report. A diagnostics endpoint shows the version, paths, vault size, last ingest and errors. API keys and tokens are redacted from logs. |
| **Deliverables** | The log module, the crash report and the diagnostics endpoint |
| **Tests** | A forced exception produces a report. A key-shaped string is redacted. No network call is made (egress test). |
| **Acceptance** | Reports are readable by a Claude tool script (`tools/occ-logs.ps1`). Covers C25. |
| **Documentation** | Architecture document, section 6 |
| **Review gate** | G1 |

### [ ] OCC-01-08: Existing companion surfaces keep working

| | |
|---|---|
| **Objective** | The MCP server, CLI and tkinter ask window keep working exactly as before alongside Command Center. |
| **Depends on** | OCC-01-04 to OCC-01-07 |
| **Scope** | `server.py` (15 tools), `cli.py`, `intelligence/window.py`, `ask.py`. A "Open Command Center" link in the ask window. No tool is removed or renamed. |
| **Deliverables** | The link and a compatibility test file |
| **Tests** | All existing companion tests pass unchanged. A test lists the 15 MCP tools and fails on any removal. |
| **Acceptance** | Byte-identical tool list. Existing tests green. Covers C01. |
| **Documentation** | Architecture document, section 7 (reuse map) |
| **Review gate** | G1 |

### [ ] OCC-01-09: Gate G1, desktop foundation review

| | |
|---|---|
| **Objective** | Review the shell, host, settings, reads and compatibility. |
| **Depends on** | OCC-01-01 to OCC-01-08 |
| **Scope** | Packet `OCC_G1_PACKET.md`. **Owner:** launch the app on the owner's PC and send a screenshot. |
| **Deliverables** | The packet, a fresh-clone log and the owner's screenshot |
| **Tests** | Full suite, plus the G1 list in the acceptance test plan |
| **Acceptance** | Per the acceptance test plan, G1 |
| **Documentation** | Packet |
| **Review gate** | G1 (this task) |

---

## OCC-02: Knowledge Vault: ingestion, indexing and preservation (12)

### [ ] OCC-02-01: Vault schema v1

| | |
|---|---|
| **Objective** | Create the SQLite database with the schema in the data contracts document. |
| **Depends on** | G1 |
| **Scope** | `vault/schema.py` with stdlib `sqlite3`, WAL mode, foreign keys on, and `PRAGMA user_version`. Tables: accounts, realms, characters, ingest_runs, sources, datasets, archive_entries, observations, provenance, sessions, plans, outcomes, ai_exchanges, meta. |
| **Deliverables** | The schema module, plus `vault/db.py` (open, transaction helper, read-only connection) |
| **Tests** | Create an empty vault. Every table, index and constraint exists. `integrity_check` returns ok. |
| **Acceptance** | The schema matches data contracts section 5 exactly (a test compares them). Covers C04. |
| **Documentation** | Data contracts document, section 5 |
| **Review gate** | G2 |

### [ ] OCC-02-02: Forward-only migrations with backup

| | |
|---|---|
| **Objective** | Schema changes never lose data. |
| **Depends on** | OCC-02-01 |
| **Scope** | `vault/migrate.py`. Before every migration it takes an online backup with the `sqlite3` backup API. Migrations are forward only. A column or table is never dropped: it is renamed to `_old_<v>` and kept. Everything runs in one transaction. |
| **Deliverables** | The migration runner and a v1-to-v2 sample migration in the test fixtures only |
| **Tests** | The migration produces a backup. A migration that fails halfway leaves the vault at v1, unchanged. Row counts and checksums are equal before and after. |
| **Acceptance** | No row is lost in any migration test (preservation override). Covers FR-06 and QR-02. |
| **Documentation** | Data contracts document, section 9 |
| **Review gate** | G2 |

### [ ] OCC-02-03: SavedVariables parse to staging

| | |
|---|---|
| **Objective** | Parse SavedVariables files, up to 20 MB and beyond, into a staging area safely. |
| **Depends on** | OCC-02-01 and OCC-01-06 |
| **Scope** | Extend `luadata.py`: make it iterative so deep nesting can't overflow, and make the 20 MB cap in `store.py` configurable for ingest (the default for the MCP path stays the same). Uses the stable read. Records the source in `sources` (path, size, mtime, sha256). |
| **Deliverables** | `ingest/parse.py` and the luadata extension |
| **Tests** | Every fixture parses. The 20 MB fixture parses within the QR-01 budget on CI hardware (recorded, not claimed for the owner's PC). Code-shaped input is refused. |
| **Acceptance** | The parser never executes anything (security test). Existing luadata tests are green. Covers C03 and FR-01. |
| **Documentation** | Data contracts document, section 4 |
| **Review gate** | G2 |

### [ ] OCC-02-04: Archive v2 entry ingest

| | |
|---|---|
| **Objective** | Copy every archive entry into the vault exactly once, keeping revisions. |
| **Depends on** | OCC-02-03 |
| **Scope** | `ingest/archive.py`. Reads `global.archive.sets[dataset]` entries (`Core/Archive.lua` v2). The key is (account, entry id). The checksum is sha256 of the canonical JSON of the row. A new id is inserted. The same id and checksum is skipped. The same id with a different checksum becomes a new revision, and the earlier one is kept. `archiveDamaged` values are stored as they are. |
| **Deliverables** | The archive ingest module |
| **Tests** | Re-ingesting adds 0 rows. A changed row becomes revision 2 and revision 1 is kept. The damaged list is ingested. Counts equal the fixture manifest. |
| **Acceptance** | Covers FR-02 and C04. Idempotency is proven on all fixtures. |
| **Documentation** | Data contracts document, section 6 |
| **Review gate** | G2 |

### [ ] OCC-02-05: Active dataset ingest, all 72 datasets

| | |
|---|---|
| **Objective** | Ingest the live (not yet archived) rows of every dataset, so the vault has the complete history. |
| **Depends on** | OCC-02-04 |
| **Scope** | `ingest/datasets.py`: a registry generated from `docs/quality/data_preservation_audit.json` (dataset to saved_path). Each dataset either has a typed mapping (data contracts, section 7) or goes to `observations` as generic JSON. Active rows have no archive id, so they get a derived key: source path, then index, then content hash. When the row later reaches the archive, it is linked to its archive entry by matching content hash. |
| **Deliverables** | The registry, the mappings and a coverage report |
| **Tests** | Every dataset in the audit JSON has a registry row (a test fails on a new, unmapped dataset). An unmapped test dataset is stored as generic JSON. An active row is linked to its archive entry after it moves. |
| **Acceptance** | 72 of 72 datasets covered. Nothing is skipped. Covers FR-03. |
| **Documentation** | Data contracts document, section 7 |
| **Review gate** | G2 |

### [ ] OCC-02-06: Provenance and lineage

| | |
|---|---|
| **Objective** | Every vault row can say where it came from. |
| **Depends on** | OCC-02-05 |
| **Scope** | A `provenance` row on every insert: ingest_run, source, dataset, saved_path, keys, character, captured_at, addon build (from the `Outrider_DB` build stamp) and revision. Lineage for derived rows (sessions, analytics) records the input row ids. |
| **Deliverables** | The provenance writer and the lineage helper |
| **Tests** | Every row in every table has provenance (a SQL check). A derived row's lineage resolves to source rows. |
| **Acceptance** | 0 rows without provenance. Covers FR-04 and C05. |
| **Documentation** | Data contracts document, section 5 |
| **Review gate** | G2 |

### [ ] OCC-02-07: Indexes and query API

| | |
|---|---|
| **Objective** | Fast, character-scoped queries over the full history. |
| **Depends on** | OCC-02-06 |
| **Scope** | `vault/query.py`: by character, play session, time range, dataset and keys (npcID, itemID, questID, mapID). Character scope is required unless `all_characters=True` is passed explicitly. Uses parameterised SQL only. |
| **Deliverables** | The query API and indexes |
| **Tests** | One character's query never returns another character's row. A 3-year fixture query stays within budget. SQL injection strings are treated as values. |
| **Acceptance** | Covers FR-05 and QR-01. Isolation is proven on the fixtures. This replaces the bounded `Archive:WithActive` working view for long history (review OI-FR16). |
| **Documentation** | Architecture document, section 5 |
| **Review gate** | G2 |

### [ ] OCC-02-08: Backup, restore and integrity

| | |
|---|---|
| **Objective** | The vault can always be restored, and corruption is caught. |
| **Depends on** | OCC-02-07 |
| **Scope** | `vault/backup.py`: scheduled online backups to `vault/backups/<stamp>.sqlite`. Old backups are never deleted automatically: the UI shows their size and the user may archive them elsewhere. `PRAGMA integrity_check` runs at startup. Restore goes into a new file, which is checked and then swapped in. The broken file is kept. |
| **Deliverables** | Backup, restore and check, plus UI endpoints |
| **Tests** | Back up, restore and compare row checksums. A corrupted file is detected, and the restore keeps the broken file aside. |
| **Acceptance** | Covers FR-06, QR-02 and C06. No confirmed row is lost in the restore drill. |
| **Documentation** | Data contracts document, section 9 |
| **Review gate** | G2 |

### [ ] OCC-02-09a: Off-load confirmations

| | |
|---|---|
| **Objective** | Tell the addon which archive entries are safely in the vault, without removing anything yet. |
| **Depends on** | OCC-02-08 |
| **Scope** | Steps 1 to 4 of the off-load protocol (data contracts, section 8). After ingest, every confirmed entry is read back from the vault and compared byte for byte with the source. Then a data-only `confirmed` table (id and checksum) is written into Advice.lua through `advice.py`, only with the game closed (OCC-01-06). The addon side only **reads and displays** the confirmed count. |
| **Deliverables** | The confirmation writer, the Advice.lua `confirmed` block, and the addon display (count only) in `Advisor/AdviceLoader.lua` |
| **Tests** | An entry whose read-back differs is not confirmed. Nothing is written while the game runs. AdviceLoader validates the block and ignores a malformed one. The Lua spec shows no SavedVariables row changes. |
| **Acceptance** | Covers FR-07 and C07. The addon changes nothing in its saved data because of this task. |
| **Documentation** | Data contracts document, section 8. `docs/ARCHIVE_GROWTH.md` is updated to say steps 1 to 4 are built. |
| **Review gate** | G2 |

### [ ] OCC-02-09b: Addon-side removal of confirmed entries (owner-gated)

| | |
|---|---|
| **Objective** | Let SavedVariables shrink by removing only the entries the vault has confirmed. |
| **Depends on** | OCC-02-09a, **plus separate owner approval (D05)** after the G2 recovery drill |
| **Scope** | `Core/Archive.lua`: at login, an entry is moved out only if its id **and** checksum are in the confirmed list. The addon recomputes the checksum the same way. Anything that doesn't match stays. Removal happens only after a fresh `tools/backup-sv.ps1` copy is detected (the addon can't run it, so the owner's backup or the companion's pre-write copy is required). |
| **Deliverables** | Removal code behind a setting that is off by default, specs, and a drill script |
| **Tests** | A wrong checksum keeps the entry. A missing vault keeps everything. A Lua checksum equals the Python checksum on shared fixtures. Drill: remove, rebuild from the vault, and compare. |
| **Acceptance** | The owner has approved in writing. The drill restores 100% of removed entries. Preservation gate green. Covers FR-07. |
| **Documentation** | ARCHIVE_GROWTH.md and DECISIONS.md (D05 recorded) |
| **Review gate** | G2. If approval comes later, a separate gate packet. |

### [ ] OCC-02-10: Data-pack reference ingest

| | |
|---|---|
| **Objective** | Make the shipped data packs (rares, macros, trails, leveling and so on) available for joins, marked as reference and not as the player's own data. |
| **Depends on** | OCC-02-07 (can run in parallel with 09a) |
| **Scope** | Reuse `tools/preservation_flatten.lua` through lupa (or a Python equivalent) to read `addon/Outrider/Data/*.lua` and `addon/Outrider_Data_*/*.lua` into `reference_*` tables, recording the pack, version and `verified` flag. Read-only. Unverified data stays marked unverified (rule 7). |
| **Deliverables** | The reference ingest and the pack version table |
| **Tests** | Every pack loads. The values match the flattener output. The `verified=false` flag is carried through. |
| **Acceptance** | Analytics can join an NPC id to its rare record. Nothing is marked verified that wasn't. Covers C13. |
| **Documentation** | Data contracts document, section 7 |
| **Review gate** | G2 |

### [ ] OCC-02-11: Gate G2, Knowledge Vault review

| | |
|---|---|
| **Objective** | Review the vault, ingest, provenance, backup and off-load confirmations. |
| **Depends on** | OCC-02-01 to OCC-02-08, OCC-02-09a and OCC-02-10. 09b only if approved. |
| **Scope** | Packet `OCC_G2_PACKET.md`. **Owner:** run an ingest of the real file on the owner's PC with the game closed. Claude reads the counts report. |
| **Deliverables** | The packet, a fresh-clone log, the ingest report and the recovery drill log |
| **Tests** | The G2 list in the acceptance test plan |
| **Acceptance** | Per the acceptance test plan, G2. Real ingest counts equal the addon's own counts for every dataset. |
| **Documentation** | Packet |
| **Review gate** | G2 (this task) |

---

## OCC-03: Character intelligence and historical analytics (9)

### [ ] OCC-03-01: Character registry and isolation

| | |
|---|---|
| **Objective** | One registry of accounts, realms and characters, with strict separation. |
| **Depends on** | G2 |
| **Scope** | `analytics/characters.py`. Keys are `Name-Realm` (`ns.CharKey`), under an account. The opaque id is `c` + Adler32(salt + "\|" + key), the same as `passport.py`, using the addon's `global.passport.salt`. A character's class, race, level, faction and spec come from the latest snapshot, with history kept. |
| **Deliverables** | The registry and an API |
| **Tests** | The same name on two realms gives two characters. The opaque id equals the addon's passport id on the shared fixture. Every analytic API refuses a call without a character scope, unless "all characters" is given explicitly. |
| **Acceptance** | Covers FR-05 and C08. Isolation is proven. |
| **Documentation** | Data contracts document, section 3 |
| **Review gate** | G3 |

### [ ] OCC-03-02: Session timeline reconstruction

| | |
|---|---|
| **Objective** | Rebuild each play session from all its rows, active and archived, wherever they are. |
| **Depends on** | OCC-03-01 |
| **Scope** | `analytics/sessions.py`. Groups activity sessions, xp segments, outcome events, travel trips, quest diary rows, deaths, fights and sales by `playSessionId`. Rows without one are grouped by time with a confidence flag. Reuses the addon's AfterAction logic, mirrored in Python with shared fixtures. |
| **Deliverables** | The sessions table and the timeline API |
| **Tests** | Every fixture session is rebuilt. An archived segment is included. Rows without an id are flagged as inferred. |
| **Acceptance** | Covers C10 and FR-08. |
| **Documentation** | Architecture document, section 5 |
| **Review gate** | G3 |

### [ ] OCC-03-03: Progression analytics

| | |
|---|---|
| **Objective** | XP per hour, levelling curves and time use across a character's full history. |
| **Depends on** | OCC-03-02 |
| **Scope** | Extend `xp_baseline.py` (comparable completed sessions) to read from the vault. Adds per-level curves, time-use shares (quest, travel, farm, profession, other) and rested effects. Only verified XP (`xpVerified`) counts toward rates. Everything else is shown as unverified. |
| **Deliverables** | The progression module and API |
| **Tests** | Known fixture sessions give known rates. Unverified XP is excluded from rates. The existing xp_baseline tests are green. |
| **Acceptance** | Covers C11 and FR-08. |
| **Documentation** | Architecture document, section 5 |
| **Review gate** | G3 |

### [ ] OCC-03-04: Economy analytics

| | |
|---|---|
| **Objective** | The gold ledger, sales, spending and price history over time. |
| **Depends on** | OCC-03-02 (can run in parallel with OCC-03-03) |
| **Scope** | `analytics/economy.py`, over goldLedger, salesLedger, confirmedSales, economyOutcomes, prices, priceHistory and auctionPosts. Net gold per session and per week, best sellers, and price trends per item, using the confirmed-sale rules the addon already applies. |
| **Deliverables** | The economy module and API |
| **Tests** | Ledger totals equal the fixture sums. An unconfirmed sale is not counted as income. |
| **Acceptance** | Covers C12 and FR-08. |
| **Documentation** | Architecture document, section 5 |
| **Review gate** | G3 |

### [ ] OCC-03-05: World knowledge analytics

| | |
|---|---|
| **Objective** | Rares, respawn observations, trails, nodes and fishing, joined to reference packs. |
| **Depends on** | OCC-03-02 and OCC-02-10 |
| **Scope** | `analytics/world.py`, over sightings, respawnObs, rareCastGaps, spawnLog, nodeState, trail, fishSessions and fishCatchesPerPoint. Observed respawn ranges come with a sample count. Pack values that aren't verified are labelled as such. |
| **Deliverables** | The world module and API |
| **Tests** | Respawn intervals come from fixture sightings. An unverified pack value is shown with its flag. |
| **Acceptance** | Covers C13. Rule 7 holds: no value is invented. |
| **Documentation** | Architecture document, section 5 |
| **Review gate** | G3 |

### [ ] OCC-03-06: Class, specialisation, race and level awareness

| | |
|---|---|
| **Objective** | Every view is scoped to the character's class and build, for every class. |
| **Depends on** | OCC-03-01 |
| **Scope** | `analytics/profile.py`. Detects the spec from the snapshot's talent data, reusing the addon's `Data/Talents.lua` and `TalentCards.lua` meanings through reference ingest. When the spec is unknown it is shown as "unknown". Content ordering follows the owner rule: own class and build first, other builds last. |
| **Deliverables** | The profile module and per-class fixture checks |
| **Tests** | Each of the 9 fixture classes resolves. An unknown spec is shown as "unknown", never guessed. The ordering rule is tested. |
| **Acceptance** | Covers C09 and FR-10. |
| **Documentation** | UI/UX spec, section 5 |
| **Review gate** | G3 |

### [ ] OCC-03-07: Trends and plain explanations

| | |
|---|---|
| **Objective** | Answer "why was I slower last week?" deterministically, with evidence. |
| **Depends on** | OCC-03-03 to OCC-03-06 |
| **Scope** | `analytics/trends.py`. Compares two windows (this week against last, or a session against its baseline) on rate, time use, deaths, travel and rested share. It ranks contributing factors with sample counts and confidence (as `Confidence.lua` does) and writes plain sentences from templates, not from a model. |
| **Deliverables** | The trends module and sentence templates |
| **Tests** | A fixture with more travel explains the slowdown as "more travel". Too few samples gives "not enough data yet". |
| **Acceptance** | Covers C14 and FR-08. No number is made up. |
| **Documentation** | UI/UX spec, section 4 (wording) |
| **Review gate** | G3 |

### [ ] OCC-03-08: Parity with the addon's figures

| | |
|---|---|
| **Objective** | Command Center's figures for a session match what the addon shows. |
| **Depends on** | OCC-03-07 |
| **Scope** | Shared fixtures run through the Lua AfterAction report (`tests/spec`) and the Python analytics. The figures compared are deaths, activity totals, XP, sales and quest times. Every allowed difference is listed with its reason. |
| **Deliverables** | `companion/tests/fixtures/occ_parity.json`, a Lua spec and a Python test |
| **Tests** | The parity tests |
| **Acceptance** | All compared figures are equal, or listed with a reason. Covers FR-09. |
| **Documentation** | Acceptance test plan, section 2 (parity fixtures) |
| **Review gate** | G3 |

### [ ] OCC-03-09: Gate G3, analytics review

| | |
|---|---|
| **Objective** | Review isolation, analytics, class awareness and parity. |
| **Depends on** | OCC-03-01 to OCC-03-08 |
| **Scope** | Packet. **Owner:** look at their own characters' figures and confirm they look right against their play (screenshot plus words). |
| **Deliverables** | The packet and a fresh-clone log |
| **Tests** | The G3 list in the acceptance test plan |
| **Acceptance** | Per the acceptance test plan, G3 |
| **Documentation** | Packet |
| **Review gate** | G3 (this task) |

---

## OCC-04: Progression, objectives and personalised session planning (8)

### [ ] OCC-04-01: Goals on the v4 contract

| | |
|---|---|
| **Objective** | Goals in Command Center use the same records as the addon's Nexus. |
| **Depends on** | G3 |
| **Scope** | Reuse `schemas_v4.py` (Goal, Opportunity, Plan, Outcome). Goals are created in the UI and stored in the vault `plans` and `goals` tables. Goals from the addon (`Goals.lua`) are ingested. GoalId is `objective:target`, the same as Fellowship. |
| **Deliverables** | The goals store and API |
| **Tests** | A v4 Goal round-trips through the vault. An addon goal ingests. An invalid record is refused by the v4 validator. |
| **Acceptance** | Covers C15 and FR-11. |
| **Documentation** | Data contracts document, section 5 |
| **Review gate** | G4 |

### [ ] OCC-04-02: Planner reuse on vault history

| | |
|---|---|
| **Objective** | Plan with the existing deterministic planners, fed by the full history. |
| **Depends on** | OCC-04-01 |
| **Scope** | `planner.py`, `xp60_planner.py` and `coach_v3.py` get a vault-backed input adapter. The planners themselves are not changed beyond the adapter. |
| **Deliverables** | `planning/adapter.py` |
| **Tests** | The same input gives the same plan as today (golden tests). Vault input produces a valid v4 Plan. |
| **Acceptance** | The existing planner tests are green. Covers C16 and FR-11. |
| **Documentation** | Architecture document, section 7 |
| **Review gate** | G4 |

### [ ] OCC-04-03: Personal estimates, matching the Lua Estimator

| | |
|---|---|
| **Objective** | Use the same shrinkage estimates as the addon, computed over all history. |
| **Depends on** | OCC-04-02 |
| **Scope** | A Python port of `Estimator.FitOne` (shrinkage toward the prior), checked against shared fixtures run through the Lua version. Covers quest time, travel time and activity duration. |
| **Deliverables** | `planning/estimator.py` and parity fixtures |
| **Tests** | Python and Lua outputs on shared fixtures are equal to 1e-9. With few samples the estimate falls back to the prior, as in Lua. |
| **Acceptance** | Parity proven. Covers FR-09. |
| **Documentation** | Acceptance test plan, section 2 (parity fixtures) |
| **Review gate** | G4 |

### [ ] OCC-04-04: Session plan builder

| | |
|---|---|
| **Objective** | "I have 90 minutes tonight": build a plan before logging in. |
| **Depends on** | OCC-04-03 |
| **Scope** | `planning/session.py`. Takes a time budget, a character and goals, and produces an ordered list of steps with estimated time, confidence and evidence ids. It reuses the planner's time budget logic. |
| **Deliverables** | The plan builder and API |
| **Tests** | The plan fits the budget. Every step has evidence. A missing estimate is shown as such. |
| **Acceptance** | Covers C16 and FR-08. |
| **Documentation** | UI/UX spec, section 4 (Planner) |
| **Review gate** | G4 |

### [ ] OCC-04-05: Choosing between characters

| | |
|---|---|
| **Objective** | "Which character should I play tonight?", answered with reasons. |
| **Depends on** | OCC-04-04 |
| **Scope** | `planning/choose.py`. Ranks the characters by goal progress, rested XP, time to their next milestone, and economy needs (a mount fund, say). The reasons are shown, and the user decides. |
| **Deliverables** | The ranker and API |
| **Tests** | Fixture characters rank in the expected order. A tie is shown as a tie. Every reason has evidence. |
| **Acceptance** | Covers C17. |
| **Documentation** | UI/UX spec, section 4 |
| **Review gate** | G4 |

### [ ] OCC-04-06: Plan delivery to the game

| | |
|---|---|
| **Objective** | Get the plan into the game without automation. |
| **Depends on** | OCC-04-04 |
| **Scope** | Two paths only. (1) An OTR1 advice code copied to the clipboard (`codes.py`, `clipboard.py`), which the player pastes. (2) Advice.lua written through `advice.py` only while the game is closed (OCC-01-06), using the 4 whitelisted actions. |
| **Deliverables** | Delivery endpoints and UI buttons |
| **Tests** | A write is refused while the game runs. The code round-trips through the addon's `Serialize.lua` on a shared fixture. Only whitelisted actions are written. |
| **Acceptance** | Covers C18, FR-11 and D18. No other write path exists (security test). |
| **Documentation** | Security document, section 1 |
| **Review gate** | G4 |

### [ ] OCC-04-07: Outcome feedback

| | |
|---|---|
| **Objective** | Compare the plan with what happened, and learn. |
| **Depends on** | OCC-04-06 |
| **Scope** | `planning/feedback.py`. After the next ingest, matches the delivered plan id to the session's outcomes (the addon's Outcomes and Nexus SessionEnd). It records the difference between estimated and actual time, and feeds the estimator with sample weights. |
| **Deliverables** | The feedback module and the `outcomes` rows |
| **Tests** | A fixture plan and session give the expected difference. Repeated ingest does not double count. |
| **Acceptance** | Covers C19. |
| **Documentation** | Architecture document, section 5 |
| **Review gate** | G4 |

### [ ] OCC-04-08: Gate G4, planning review

| | |
|---|---|
| **Objective** | Review planning, parity, delivery and feedback. |
| **Depends on** | OCC-04-01 to OCC-04-07 |
| **Scope** | Packet. **Owner:** plan a session in Command Center, paste the code in game, play, log out. Claude reads the feedback. |
| **Deliverables** | The packet, a fresh-clone log and the owner run log |
| **Tests** | The G4 list in the acceptance test plan |
| **Acceptance** | Per the acceptance test plan, G4 |
| **Documentation** | Packet |
| **Review gate** | G4 (this task) |

---

## OCC-05: Local and cloud AI integration, grounded recommendations (8)

### [ ] OCC-05-01: Provider layer reuse and configuration UI

| | |
|---|---|
| **Objective** | The existing providers, configured from Command Center. |
| **Depends on** | G4 |
| **Scope** | `providers.py` (local OpenAI-compatible, loopback only unless `allowRemote`), `cloud.py` (Anthropic, OpenAI, Gemini), and `doctor.py`. A settings screen to pick a provider, test it (a reachability check only when the user asks) and see its status. Cloud stays off by default (D08) and needs `cloudConsent`. |
| **Deliverables** | A provider settings API and screen |
| **Tests** | The existing provider tests are green. Turning cloud on without consent is refused. |
| **Acceptance** | Covers C20 and FR-13. |
| **Documentation** | `docs/AI_PRIVACY_AND_TRANSPORT.md` updated |
| **Review gate** | G5 |

### [ ] OCC-05-02: Retrieval grounding from the vault

| | |
|---|---|
| **Objective** | The model sees only relevant, cleaned evidence from the vault, each piece with an id. |
| **Depends on** | OCC-05-01 |
| **Scope** | Extend `context.py` (ContextEnvelope v2) with a vault retriever: analytics results and evidence rows chosen by the question type, each with an `evidence_id` (vault row id plus revision). The size is bounded, and names are replaced by opaque ids. |
| **Deliverables** | `ai/retrieve.py` and the envelope extension |
| **Tests** | The envelope contains only allowed fields. Every fact has an evidence id. No character name appears. |
| **Acceptance** | Covers C21 and C22. |
| **Documentation** | Data contracts document, section 5 (`ai_exchanges`) |
| **Review gate** | G5 |

### [ ] OCC-05-03: Answer validation, citations and confidence

| | |
|---|---|
| **Objective** | An answer that isn't backed by evidence isn't shown as fact. |
| **Depends on** | OCC-05-02 |
| **Scope** | Extend `orchestrator.py`, `schemas_v3.py` and `schemas_v4.py`. Every number in an answer must match an evidence value. Citations must be evidence ids from the envelope. Confidence comes from the evidence, not from the model. On failure the deterministic fallback is shown with a note. |
| **Deliverables** | The validator extension |
| **Tests** | A poisoned model's made-up number is rejected. A wrong citation is rejected. A valid answer passes. |
| **Acceptance** | Covers FR-12. |
| **Documentation** | Security document, section 3 |
| **Review gate** | G5 |

### [ ] OCC-05-04: Privacy filter and preview

| | |
|---|---|
| **Objective** | The user sees exactly what will leave the PC before it leaves. |
| **Depends on** | OCC-05-02 |
| **Scope** | Reuse the passport allow list and opaque id rules (`passport.py`). A preview screen shows the exact envelope. Social data (D06) and free text are never sent. Each exchange is stored in `ai_exchanges` (what was sent, what came back, the provider and tokens). |
| **Deliverables** | The filter, preview and exchange log |
| **Tests** | Chat rows never appear in an envelope. The preview bytes equal the sent bytes. |
| **Acceptance** | Covers C22 and QR-03. |
| **Documentation** | Security document, section 4 |
| **Review gate** | G5 |

### [ ] OCC-05-05: Budgets and key management

| | |
|---|---|
| **Objective** | Spending limits and keys handled safely from the UI. |
| **Depends on** | OCC-05-01 |
| **Scope** | `budget.py` (SpendGuard, `dailyTokenCap`) and `keys.py` (Credential Manager), with UI screens. A key is write-only from the UI: it is never shown back, only its status. |
| **Deliverables** | The budget and key screens |
| **Tests** | The cap blocks a call. A key never appears in logs, responses or the vault (scan test). |
| **Acceptance** | Covers C22. |
| **Documentation** | Security document, section 3 |
| **Review gate** | G5 |

### [ ] OCC-05-06: Everything works with AI off

| | |
|---|---|
| **Objective** | Prove that every screen works with no provider configured. |
| **Depends on** | OCC-05-03 |
| **Scope** | A test mode with no provider, run over every API endpoint and screen. The coach screen shows deterministic answers and how to add a provider. |
| **Deliverables** | The parity test |
| **Tests** | Every endpoint returns a useful answer with AI off. No socket is opened (egress test). |
| **Acceptance** | Covers FR-13 and spec section 2.5. |
| **Documentation** | UI/UX spec, section 6 |
| **Review gate** | G5 |

### [ ] OCC-05-07: Evaluation and vault-backed MCP tools

| | |
|---|---|
| **Objective** | Measure answer quality, and let the MCP path read the vault. |
| **Depends on** | OCC-05-03 to OCC-05-06 |
| **Scope** | Extend `test_eval25.py` and `test_contract_golden.py` with vault questions (history, trends, character choice). Add read-only MCP tools to `server.py` (for example `get_history` and `get_trends`) using the same filter. The existing 15 tools are unchanged. |
| **Deliverables** | Eval cases and the new MCP tools |
| **Tests** | Eval with no model, with a valid model and with a poisoned model (stand-ins). The MCP tool list contains the 15 originals plus the new ones. |
| **Acceptance** | Eval passes its thresholds (set in the acceptance test plan, section 3). Covers C21. |
| **Documentation** | `companion/README.md` |
| **Review gate** | G5 |

### [ ] OCC-05-08: Gate G5, AI review

| | |
|---|---|
| **Objective** | Review grounding, validation, privacy and AI-off parity. |
| **Depends on** | OCC-05-01 to OCC-05-07 |
| **Scope** | Packet. **Owner:** an optional real-provider test with the owner's own key and consent. |
| **Deliverables** | The packet, a fresh-clone log and the egress log |
| **Tests** | The G5 list in the acceptance test plan |
| **Acceptance** | Per the acceptance test plan, G5 |
| **Documentation** | Packet |
| **Review gate** | G5 (this task) |

---

## OCC-06: Unified dashboards, search and reporting (9)

### [ ] OCC-06-01: Information architecture and navigation

| | |
|---|---|
| **Objective** | One navigation with every screen in the UI/UX spec. |
| **Depends on** | G5 |
| **Scope** | A sidebar, a character switcher, routes for the 12 screens, and keyboard navigation. |
| **Deliverables** | The navigation shell |
| **Tests** | Every route renders. Keyboard-only navigation reaches every screen. |
| **Acceptance** | Covers FR-14 and QR-06. |
| **Documentation** | UI/UX spec, section 2 |
| **Review gate** | G6 |

### [ ] OCC-06-02: Home and the welcome-back report

| | |
|---|---|
| **Objective** | Opening the app shows the last session and what to do next. |
| **Depends on** | OCC-06-01 |
| **Scope** | Home screen: last session (duration, XP, gold, quests), "what we learned" (from trends) and "your next adventure" (from the plan builder). All from deterministic analytics. |
| **Deliverables** | The Home screen |
| **Tests** | Renders from fixtures. An empty vault shows the first-run steps. |
| **Acceptance** | Covers C24 and FR-14. |
| **Documentation** | UI/UX spec, section 4 |
| **Review gate** | G6 |

### [ ] OCC-06-03: Character pages

| | |
|---|---|
| **Objective** | Characters list and character detail, scoped by class and spec. |
| **Depends on** | OCC-06-01 |
| **Scope** | List: every character with class, level, realm and last played. Detail: profile, progression summary, gear snapshot, professions and goals, with own-class content first. |
| **Deliverables** | Two screens |
| **Tests** | 9 fixture characters render. Class-scoped ordering is checked. |
| **Acceptance** | Covers FR-10 and C08. |
| **Documentation** | UI/UX spec, section 4 |
| **Review gate** | G6 |

### [ ] OCC-06-04: Analytics dashboards

| | |
|---|---|
| **Objective** | Sessions, Progression, Economy and World screens with charts. |
| **Depends on** | OCC-06-01 |
| **Scope** | Charts rendered with inline SVG from a small local chart module (no CDN, offline). Each chart has a text summary and table view. |
| **Deliverables** | Four screens |
| **Tests** | Charts render from fixtures. Table values equal chart values. Works offline. |
| **Acceptance** | Covers C11-C13, C24 and QR-06. |
| **Documentation** | UI/UX spec, section 4 |
| **Review gate** | G6 |

### [ ] OCC-06-05: Planner screen

| | |
|---|---|
| **Objective** | Plan a session, choose a character and deliver the plan. |
| **Depends on** | OCC-06-01 |
| **Scope** | Time budget input, the character choice with reasons, plan steps with evidence chips, and the delivery buttons (copy code, write Advice.lua when the game is closed). |
| **Deliverables** | The Planner screen |
| **Tests** | The flow works end to end on fixtures. The write button is disabled while the game runs. |
| **Acceptance** | Covers C16-C18. |
| **Documentation** | UI/UX spec, section 4 |
| **Review gate** | G6 |

### [ ] OCC-06-06: Vault browser, search and provenance

| | |
|---|---|
| **Objective** | Find any recorded row and see where it came from. |
| **Depends on** | OCC-06-01 |
| **Scope** | Search by text, dataset, character, date and id. A row view shows provenance, lineage and all revisions. Read-only: nothing can be deleted from the UI. Includes the backup and restore controls. |
| **Deliverables** | The Vault screen |
| **Tests** | Search finds fixture rows. Provenance resolves. There is no delete endpoint (security test). |
| **Acceptance** | Covers C05, C06 and C23. |
| **Documentation** | UI/UX spec, section 4 |
| **Review gate** | G6 |

### [ ] OCC-06-07: Coach screen

| | |
|---|---|
| **Objective** | Ask questions about your characters, with citations. |
| **Depends on** | OCC-06-01 |
| **Scope** | A question box, the answer with evidence chips that link to the vault row, a confidence pill, the preview before sending (cloud), and AI-off mode. |
| **Deliverables** | The Coach screen |
| **Tests** | Citations link. The preview shows. AI-off mode works. |
| **Acceptance** | Covers C21, C22 and FR-12/13. |
| **Documentation** | UI/UX spec, section 4 |
| **Review gate** | G6 |

### [ ] OCC-06-08: Accessibility, plain language and empty states

| | |
|---|---|
| **Objective** | Every page passes the owner's plain-page rule and the accessibility bar. |
| **Depends on** | OCC-06-02 to OCC-06-07 |
| **Scope** | A purpose line and 1-2-3 steps on every page. Empty and error states. Scaling at 125% and 150%. Focus order. Colour plus text for every status. Readability check of the copy. |
| **Deliverables** | Fixes and a checklist record |
| **Tests** | An automated check that every page has a purpose line and steps. The contrast check. A scaling screenshot set (dev only). |
| **Acceptance** | Covers QR-06 and FR-14. |
| **Documentation** | UI/UX spec, sections 5-6 |
| **Review gate** | G6 |

### [ ] OCC-06-09: Gate G6, presentation review

| | |
|---|---|
| **Objective** | Review the product as a whole. |
| **Depends on** | OCC-06-01 to OCC-06-08 |
| **Scope** | Packet with screenshots of every screen. **Owner:** use it for one evening and say what is confusing. |
| **Deliverables** | The packet, screenshots and the owner's notes |
| **Tests** | The G6 list in the acceptance test plan |
| **Acceptance** | Per the acceptance test plan, G6 |
| **Documentation** | Packet |
| **Review gate** | G6 (this task) |

---

## OCC-07: Security, privacy, recovery and performance (8)

### [ ] OCC-07-01: Threat model update

| | |
|---|---|
| **Objective** | Update the threat model for the local web server, vault and AI gateway. |
| **Depends on** | G6 |
| **Scope** | `docs/intelligence/THREAT_MODEL.md`, plus security document section 2 kept in step with the built code |
| **Deliverables** | The updated threat model, with each threat mapped to a test |
| **Tests** | None (documentation) |
| **Acceptance** | Every threat has a mitigation and a test reference. |
| **Documentation** | The threat model |
| **Review gate** | G7 |

### [ ] OCC-07-02: Local server security tests

| | |
|---|---|
| **Objective** | Prove the loopback server can't be used by a web page or another user. |
| **Depends on** | OCC-07-01 |
| **Scope** | Tests for: a missing or wrong token, DNS rebinding (wrong Host), a cross-origin request, CSRF on state-changing endpoints, path traversal on static files, request size limits, and binding only to loopback. |
| **Deliverables** | `test_server_security.py` |
| **Tests** | As listed |
| **Acceptance** | All pass. Covers QR-03. |
| **Documentation** | Security document, section 2 |
| **Review gate** | G7 |

### [ ] OCC-07-03: Egress and privacy audit

| | |
|---|---|
| **Objective** | Prove what leaves the PC. |
| **Depends on** | OCC-07-01 |
| **Scope** | An egress test harness that wraps `socket.create_connection` and `urllib`. With AI off: zero outbound connections in a full app run over fixtures. With a stand-in cloud provider: only the previewed envelope is sent. A scan of the vault, logs and envelopes for names and keys. |
| **Deliverables** | The egress test and the privacy audit report |
| **Tests** | As listed |
| **Acceptance** | Covers QR-03 and rule 10. |
| **Documentation** | Security document, section 4 |
| **Review gate** | G7 |

### [ ] OCC-07-04: Recovery drills

| | |
|---|---|
| **Objective** | Show that every failure is recoverable without losing data. |
| **Depends on** | OCC-07-01 |
| **Scope** | Drills: a corrupt vault file, an ingest killed mid-run, a full disk during a backup, a damaged SavedVariables, a power loss simulated by killing the process during a write, and a restore from an old backup followed by re-ingest. |
| **Deliverables** | Drill scripts and a drill log |
| **Tests** | Each drill has an automated test that checks row checksums afterwards. |
| **Acceptance** | 0 confirmed rows lost in any drill. Covers QR-02 and C25. |
| **Documentation** | Acceptance test plan, section 6 |
| **Review gate** | G7 |

### [ ] OCC-07-05: Performance budgets

| | |
|---|---|
| **Objective** | Measure against QR-01 on CI hardware and on the owner's PC. |
| **Depends on** | OCC-07-01 |
| **Scope** | A benchmark script: full ingest of 20 MB, an incremental ingest, dashboard query times over 3 years of fixtures, memory use and vault size growth. **Owner:** run it on their own PC. |
| **Deliverables** | `tools/occ-bench.py` and a results table, with CI numbers and owner numbers kept apart |
| **Tests** | The benchmark runs. Regression thresholds are checked in CI. |
| **Acceptance** | QR-01 is met on the owner's PC, or the gap is reported with a plan. |
| **Documentation** | Acceptance test plan, section 7 |
| **Review gate** | G7 |

### [ ] OCC-07-06: Upgrade and migration tests

| | |
|---|---|
| **Objective** | Every vault version upgrades to the current one without loss. |
| **Depends on** | OCC-07-04 |
| **Scope** | A stored vault fixture for each schema version reached so far, and a config fixture for each config version. Each one is upgraded to current and compared. |
| **Deliverables** | Fixtures and tests |
| **Tests** | As listed |
| **Acceptance** | Row checksums are kept across all upgrades. Covers FR-06. |
| **Documentation** | Data contracts document, section 9 |
| **Review gate** | G7 |

### [ ] OCC-07-07: End-to-end data preservation audit

| | |
|---|---|
| **Objective** | Prove that nothing collected is lost anywhere between the addon and the vault. |
| **Depends on** | OCC-07-04 to OCC-07-06 |
| **Scope** | Extend `docs/quality/data_preservation_audit.json` with vault destinations for all 72 datasets. Extend `tools/preservation_check.py`, or add `occ_preservation.py`, to compare SavedVariables fixture values with vault values. |
| **Deliverables** | The audit extension and the checker |
| **Tests** | All 72 datasets, value for value, on fixtures |
| **Acceptance** | 0 values missing. Strict mode fails closed (the FR17 rule). |
| **Documentation** | Data contracts document, section 7 |
| **Review gate** | G7 |

### [ ] OCC-07-08: Gate G7, hardening review

| | |
|---|---|
| **Objective** | Review security, privacy, recovery and performance evidence. |
| **Depends on** | OCC-07-01 to OCC-07-07 |
| **Scope** | Packet |
| **Deliverables** | The packet, a fresh-clone log, the drill log, the egress log and benchmarks |
| **Tests** | The G7 list in the acceptance test plan |
| **Acceptance** | Per the acceptance test plan, G7 |
| **Documentation** | Packet |
| **Review gate** | G7 (this task) |

---

## OCC-08: Integration testing, installation, documentation and release readiness (7)

### [ ] OCC-08-01: End-to-end integration on the fixture corpus

| | |
|---|---|
| **Objective** | The whole pipeline in one test, from SavedVariables to the screens. |
| **Depends on** | G7 |
| **Scope** | Locate, then stable read, ingest, analytics, plan, deliver, feedback, coach (AI off and stand-in) and backup/restore, on every fixture. |
| **Deliverables** | `test_e2e.py` |
| **Tests** | As listed |
| **Acceptance** | Green from a fresh clone. |
| **Documentation** | Acceptance test plan, section 8 |
| **Review gate** | G8 |

### [ ] OCC-08-02: Installer and uninstall

| | |
|---|---|
| **Objective** | Install without admin rights, per D03. Uninstalling keeps the user's data. |
| **Depends on** | OCC-08-01 |
| **Scope** | Builds per D03 (for example PyInstaller one-folder, a zip and Setup.cmd). A Start menu shortcut, with an option, not a default. No auto-start. The uninstaller removes the program files and leaves the vault and backups in place with a note. Updates are manual (`docs/companion/PACKAGING.md`). |
| **Deliverables** | `tools/occ-package.ps1` and the install and uninstall scripts |
| **Tests** | Install and uninstall in a temp profile. The vault survives an uninstall. The package build is reproducible. |
| **Acceptance** | Covers C26. Nothing is written inside the WoW folder by the installer. |
| **Documentation** | PACKAGING.md updated |
| **Review gate** | G8 |

### [ ] OCC-08-03: Clean-machine install test (Owner)

| | |
|---|---|
| **Objective** | Prove the installer works on a Windows machine without the repository. |
| **Depends on** | OCC-08-02 |
| **Scope** | **Owner:** install on a clean Windows machine or VM, open the app, ingest, uninstall. Report SmartScreen and WebView2 behaviour. |
| **Deliverables** | The owner's report and screenshots |
| **Tests** | Manual checklist (acceptance test plan, section 9) |
| **Acceptance** | All checklist items pass, or each failure has a fix task. |
| **Documentation** | `docs/companion/RELEASE_TEST.md` |
| **Review gate** | G8 |

### [ ] OCC-08-04: Live validation with real characters (Owner)

| | |
|---|---|
| **Objective** | Real data, real play: check the numbers against reality. |
| **Depends on** | OCC-08-02 (can run in parallel with OCC-08-03) |
| **Scope** | **Owner:** two evenings on two or more characters (hunter, priest, mage), multiple realms if possible (Q4). Plan, play, log out, review. The log is self-collecting: no slash commands during play. |
| **Deliverables** | Claude's evidence report, built from the ingest and the logs |
| **Tests** | Session figures equal the addon's own figures for those sessions. |
| **Acceptance** | Covers FR-09. No errors in the addon or the app logs. |
| **Documentation** | `docs/companion/LIVE_BETA.md` |
| **Review gate** | G8 |

### [ ] OCC-08-05: User guide and help

| | |
|---|---|
| **Objective** | Plain guides for installing, using and recovering. |
| **Depends on** | OCC-08-01 |
| **Scope** | A Command Center section in `docs/USER_GUIDE.md`, an in-app Help page, and the recovery how-to (restore a backup). |
| **Deliverables** | The guides |
| **Tests** | The help page renders. Every screen is documented (a check script). |
| **Acceptance** | Passes the plain-page rule. |
| **Documentation** | As listed |
| **Review gate** | G8 |

### [ ] OCC-08-06: Release audit, licensing and release-candidate packet

| | |
|---|---|
| **Objective** | Everything needed for a release decision, in one place. |
| **Depends on** | OCC-08-03 to OCC-08-05 |
| **Scope** | GPLv3 notices (D20) and third-party notices for every bundled dependency. The name (D07). A security and privacy summary. Known limits. The release candidate build with its hashes. |
| **Deliverables** | `docs/reviews/OCC_RC_PACKET.md` |
| **Tests** | The license check script. Full suite from a fresh clone. |
| **Acceptance** | No unlicensed input. Every owner decision is recorded. |
| **Documentation** | Packet and CHANGELOG |
| **Review gate** | G8 |

### [ ] OCC-08-07: Gate G8, final release-readiness review

| | |
|---|---|
| **Objective** | The final independent review. Publishing still needs separate owner authorisation. |
| **Depends on** | OCC-08-01 to OCC-08-06 |
| **Scope** | The release-candidate packet, all gate packets and the owner's live evidence |
| **Deliverables** | The reviewer's decision |
| **Tests** | The G8 list in the acceptance test plan |
| **Acceptance** | REVIEW_ACCEPTED. Nothing is merged into `main` or published without the owner. |
| **Documentation** | Packet |
| **Review gate** | G8 (this task) |

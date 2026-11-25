# Outrider Command Center: architecture

**Status: PLANNING ONLY.** IDs follow `OUTRIDER_COMMAND_CENTER_ENGINEERING_SPEC.md` (spec):
- requirements: FR-xx (functional) and QR-xx (quality)
- capabilities: Cxx
- owner decisions: Dxx

Where a choice depends on an owner decision, this document shows the recommended option and names the decision.

## 1. Overview

```
 World of Warcraft (game client)
   Outrider addon: modules, observations, Nexus, Archive v2
        |  writes on logout or /reload only
        v
 WTF\Account\<acct>\SavedVariables\Outrider.lua          (read-only to us)
        |
        |  read only when the game is closed and the bytes are stable (FR-01)
        v
 +---------------------- Outrider Command Center (Windows, Python) ----------------------+
 |  Ingest  ->  Knowledge Vault (SQLite)  ->  Intelligence Engine  ->  Local API  ->  UI |
 |  locate      schema v1, WAL              analytics, trends          loopback        |
 |  stable      provenance, revisions       planning, estimator        + token         |
 |  parse       backups, integrity          choice, feedback                           |
 |                     ^                            |                                  |
 |                     |                     AI Gateway (optional; off by default)     |
 |                     |                     providers, privacy filter, budgets        |
 |  Delivery (advice only): OTR1 code to the clipboard, or Advice.lua with the game    |
 |  closed                                                                             |
 |  Existing surfaces stay: MCP server (stdio), CLI, tkinter ask window                |
 +---------------------------------------------------------------------------------------+
        |  the only write inside the game folder
        v
 Interface\AddOns\Outrider\Advisor\Advice.lua   (data only; read by AdviceLoader after /reload)
```

Every layer shares the same security, privacy, evidence and data-preservation contracts. They are defined in the security document and the data contracts document.

## 2. Principles

1. **Extend, don't rewrite.** The existing companion modules stay where they are and keep their tests. Command Center adds a package beside them (section 4) and calls into them. The reuse map is in section 7.
2. **Offline first.** Everything except the optional AI Gateway works with no network.
3. **One direction for game data.** Data flows from the game to the vault. The only way back is advice the player chooses to apply, never live control (D18).
4. **Deterministic core.** Analytics and plans are pure functions of the vault contents and the build. The AI explains them; it never replaces them.
5. **Append and revise, never overwrite.** The vault keeps every revision of every row (data contracts, section 6).

## 3. Process model

| Process | Started by | Role |
|---|---|---|
| Command Center app (`python -m outrider_companion.command_center`, or the packaged exe, D03) | The user | Holds a single-instance lock. Runs the ingest, the vault and the engine. Serves the UI on `127.0.0.1:<random port>` with a per-launch token. |
| UI host window | The app | A WebView2 window through pywebview (D01 a). The fallback is the default browser at the tokenised loopback URL. With D01 (b), a tkinter host instead. |
| Optional ingest watcher | The app, only if the user opted in (D04) | Polls the game process state and the SavedVariables mtime. Ingests after the game closes. Never touches the game. |
| MCP server (`companion/run.py`) | An MCP client (Claude Code) | Unchanged. Later gains read-only vault tools (OCC-05-07) that open the vault read-only. |
| CLI and tkinter ask window | The user | Unchanged |

**Concurrency.** The vault uses SQLite WAL. There is one writer: the app. All other readers open it read-only (`mode=ro` URI). If the app isn't running, the MCP server and the CLI still read the vault read-only. They never write it.

## 4. Package layout (D09 a)

```
companion/outrider_companion/
  (existing modules unchanged: server, store, luadata, codes, clipboard, advice, cli, intelligence/...)
  command_center/
    __init__.py, __main__.py
    app.py            lifecycle, single instance, loopback HTTP server, token, routes
    ui/host.py        window host (D01)
    ui/static/        index.html, tokens.css, components, charts (local, no CDN)
    ingest/locate.py  find SavedVariables (reuses tools/local.json)
    ingest/stable.py  stable-bytes read (from session_reader.py)
    ingest/parse.py   luadata-based parse into staging
    ingest/archive.py archive v2 entries, idempotent by id + checksum
    ingest/datasets.py  registry of the 72 datasets, typed mappings
    vault/db.py, schema.py, migrate.py, query.py, backup.py, offload.py
    analytics/characters.py, sessions.py, progression.py, economy.py, world.py, profile.py, trends.py
    planning/adapter.py, estimator.py, session.py, choose.py, feedback.py
    ai/retrieve.py    vault evidence into a ContextEnvelope (reuses context.py)
    reports/          welcome-back and session reports
    diag/gameproc.py  game-running check (moved out of next_session_delivery.py)
    diag/log.py       local logs, crash reports, redaction
companion/tests/command_center/test_*.py
```

**Vault location.** `%LOCALAPPDATA%\Outrider\CommandCenter\vault.sqlite` (configurable). It is outside the repository, outside the game folder and outside the program folder, so an uninstall or upgrade never touches it.

**Dependency direction.** `command_center` may import the existing companion modules. They must never import `command_center` back, which `deps.py --check` enforces.

## 5. Data flow

1. **Locate** (`ingest/locate.py`, OCC-01-05): finds the SavedVariables file for each account using `tools/local.json` and the WoW folder layout. Opens files read-only.
2. **Stable read** (OCC-01-06): checks that the game is not running (`diag/gameproc.py`) and that size, mtime and sha256 are equal across two reads. Otherwise it waits or gives up.
3. **Parse** (OCC-02-03): `luadata.parse` turns the file into staging (data only, never executed). A `sources` row records the file's hash.
4. **Ingest** (OCC-02-04/05/06): one transaction per run.
   - Archive entries go into `archive_entries` (by id and checksum, with revisions).
   - Active rows go into `observations` (typed or generic).
   - Every row gets a `provenance` row.
   - The `characters` table is updated.
5. **Derive** (OCC-03): `sessions` and analytics tables are rebuilt from the vault. Each derived row records its lineage. Derived data can always be recomputed; source rows are never changed.
6. **Query** (OCC-02-07): character-scoped API. "All characters" must be asked for explicitly. This replaces the addon's bounded `Archive:WithActive` view for long history (review OI-FR16).
7. **Plan** (OCC-04): the existing planners take input through a vault adapter. Plans are v4 records.
8. **Deliver** (OCC-04-06): an OTR1 code on the clipboard, or Advice.lua with the game closed.
9. **Confirm off-load** (OCC-02-09a): the confirmed ids and checksums go into Advice.lua. The addon only removes entries after D05 approval (OCC-02-09b).
10. **Feedback** (OCC-04-07): the next ingest compares the plan with the outcome.

## 6. Cross-cutting services

| Service | Where | Notes |
|---|---|---|
| Logging and diagnostics | `diag/log.py` | Local only. Keys and tokens are redacted. Rotated files are archived, not deleted. |
| Settings | `companion/config.json` `commandCenter` block | Backed up before migration (OCC-01-04) |
| Secrets | Windows Credential Manager (`keys.py`) | Never in config, the vault or logs |
| Evidence ids | Vault row id plus revision | Used by plans, analytics and AI citations |
| Opaque character ids | `c` + Adler32(salt + "\|" + `Name-Realm`) | Shown at the AI boundary only. Matches `passport.py`. |
| Game-folder write | `advice.py` only | Only while the game is closed, and only whitelisted actions (D16) |

## 7. Reuse map

| Existing component | Used by | Change |
|---|---|---|
| `luadata.py` | ingest/parse | Iterative parse; configurable size cap for ingest only |
| `store.py` | settings; MCP path | Config v2 block. The MCP default cap is unchanged. |
| `intelligence/session_reader.py` | ingest/stable | Stable-bytes logic extracted, with no behaviour change |
| `intelligence/next_session_delivery.py` | diag/gameproc | Process check extracted, with no behaviour change |
| `advice.py` | delivery, off-load confirmations | Gains a data-only `confirmed` block (OCC-02-09a) |
| `codes.py`, `clipboard.py` | delivery | None |
| `intelligence/passport.py` | the AI privacy filter | The allow list and opaque id rules are reused. |
| `server.py` | MCP | Read-only vault tools added. The 15 existing tools are unchanged. |
| `intelligence/providers.py`, `cloud.py`, `budget.py`, `keys.py`, `doctor.py` | AI Gateway | Settings UI added |
| `intelligence/context.py`, `schemas_v3.py`, `schemas_v4.py`, `orchestrator.py` | AI Gateway, planning | Vault retriever; number and citation validation |
| `intelligence/planner.py`, `xp60_planner.py`, `xp_baseline.py`, `coach_v3.py` | planning, analytics | A vault input adapter only |
| `cli.py` | reports | Vault-backed report commands added |
| `intelligence/window.py` | users of the ask window | An "Open Command Center" link only |
| Addon `Core/Archive.lua` | ingest source; off-load | Read as is. Removal is owner-gated (D05). |
| Addon `Advisor/AdviceLoader.lua` | off-load | Reads and shows the confirmed count (OCC-02-09a) |
| `tools/preservation_flatten.lua` | reference ingest | Reused to read data packs (OCC-02-10) |
| `tools/local.json`, `tools/find-wow.ps1` | locate | Reused |

## 8. Architecture decision records (to be written in OCC-00-03)

| ADR | Topic | Recommended | Decision |
|---|---|---|---|
| ADR-01 | UI host | WebView2 through pywebview, with the browser as fallback | D01 |
| ADR-02 | Dependency policy | Short pinned, hash-checked list | D02 (amends D16) |
| ADR-03 | Packaging | PyInstaller one-folder, zip and Setup.cmd, per user | D03 |
| ADR-04 | Ingest trigger | On open, plus an opt-in watcher after the game closes | D04 |
| ADR-05 | Off-load removal | Confirmations now; removal after a drill and approval | D05 |
| ADR-06 | Social data | Ingest only if the addon's opt-in is on; never sent to AI | D06 |
| ADR-07 | Name | "Outrider Command Center" | D07 |
| ADR-08 | Cloud AI default | Off. The owner picks the provider and cap. | D08 |
| ADR-09 | Code location | `command_center/` package in this repo, on branch `occ-command-center` | D09 |
| ADR-10 | Storage engine | SQLite through stdlib `sqlite3`, WAL, `user_version` migrations | Technical. Follows from D16. |
| ADR-11 | Charts | Inline SVG from a small local module, with no CDN and no JS framework | Technical. Offline first. |
| ADR-12 | Local API | stdlib `http.server`, JSON, token plus Host and Origin checks | Technical |

# Outrider Command Center: data contracts

**Status: PLANNING ONLY.** This document fixes the shapes that the addon, the companion and the Knowledge Vault agree on. Once implementation starts, `companion/tests/fixtures/occ_contract.json` (OCC-00-05) is the executable version of sections 2, 3 and 8, and the Lua and Python tests both check it.

## 1. Principles

1. **Preserve.** The vault never deletes, redacts or summarises a source row in place of the original. Corrections become new revisions, and every revision is kept.
2. **Provenance.** Every row can say which file, ingest run, dataset, saved path, character and addon build it came from (FR-04).
3. **Isolation.** Every row belongs to an account. Character-scoped rows also carry a character id. Queries are scoped by character unless the caller explicitly asks for all characters (FR-05).
4. **Idempotency.** Ingesting the same file again changes nothing (FR-02).

## 2. Input contract: SavedVariables

**Source file:** `WTF\Account\<account>\SavedVariables\Outrider.lua`, which is account-wide (D4). The top-level globals are:

| Global | What Command Center reads |
|---|---|
| `Outrider_DB` | `global` (account-wide stores and `archive`), `chars[Name-Realm]` (per-character stores), and the build stamp |
| `Outrider_Log` | Ingested into `observations` as the generic `log` dataset. It is used by diagnostics, not by analytics. |
| `Outrider_Snapshots[Name-Realm]` | The latest snapshot per character: class, race, level, talents, gear and professions |

**Archive v2** (`Core/Archive.lua`) is `Outrider_DB.global.archive = { v = 2, sets = { [dataset] = { entry, ... } } }`. Each entry has these fields:

| Field | Type | Meaning |
|---|---|---|
| `id` | string | `"<session>:<counter>"`. Stable, and unique per account. |
| `path` | string | The logical saved path the row came from |
| `keys` | table or nil | Identifying keys, such as `{ npcID = 123 }` or `{ mapID = 1420 }` |
| `scope` | `"account"` or `"char"` | |
| `char` | string | The `Name-Realm` key that was active when the row was archived |
| `at` | number | Epoch seconds when the row was archived |
| `row` | any | A snapshot of the original row |

`Outrider_DB.global.archiveDamaged` is a list of `{ path, value, at }`. These values are ingested exactly as they are.

**Rules:**
- An unknown top-level key or dataset is stored as generic JSON, never dropped.
- A file the parser refuses (code-shaped content, a truncated file) is recorded in `ingest_runs` as failed, and nothing is written.

## 3. Identity

| Entity | Key | Notes |
|---|---|---|
| Account | `account_name`, the folder name under `WTF\Account` | Stored locally only |
| Realm | The realm name with spaces removed, the same as `ns.CharKey` | |
| Character | `Name-Realm` (`ns.CharKey`, `Core/Init.lua`), unique within an account | The same name on two realms means two characters. |
| Opaque character id | `c` + lowercase hex Adler32(`salt` + `"\|"` + `Name-Realm`), where `salt` is `global.passport.salt` | Matches `^c[0-9a-f]{8}$`, the same as `passport.py` and `Passport.lua`. **This is the only character identifier that may cross the AI boundary.** |
| Archive entry | (`account_id`, `entry_id`) plus `revision` | |
| Active row | (`account_id`, `dataset`, `saved_path`, `position`, `content_sha256`) | Linked to its archive entry once it moves (data contracts, section 6) |
| Evidence id | `<table>:<row id>@<revision>` | Cited by plans, analytics and AI answers |
| Play session | `playSessionId` from the addon | Rows without one are grouped by time and flagged as `inferred` |

## 4. Ingest contract

1. **Locate.** Only `Outrider.lua` files under `WTF\Account\*\SavedVariables\` are considered. They are opened read-only.
2. **Game closed.** The read is refused while a WoW process is running (`diag/gameproc.py`, the process check moved out of `next_session_delivery.py`).
3. **Stable bytes.** Two reads at least 2 s apart must have equal size, mtime and sha256, the same logic as `session_reader.py`. Otherwise the ingest is retried later.
4. **Parse.** `luadata.parse`, data only. The size cap for ingest is configurable (default 256 MB). The MCP path keeps its 20 MB cap.
5. **Transaction.** One SQLite transaction per ingest run. On any error the run is rolled back and recorded as failed.
6. **Record.** Each run produces one `ingest_runs` row and one `sources` row (path, size, mtime, sha256, the addon build). Each inserted row gets one `provenance` row.

## 5. Vault schema v1 (SQLite, `PRAGMA user_version = 1`)

All tables are `STRICT`, `foreign_keys=ON` and `journal_mode=WAL`. Times are epoch seconds (INTEGER). JSON is stored as canonical text: sorted keys, no spaces, UTF-8.

```sql
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL) STRICT;
CREATE TABLE accounts (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE, flavor TEXT NOT NULL) STRICT;
CREATE TABLE realms (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE) STRICT;
CREATE TABLE characters (
  id INTEGER PRIMARY KEY, account_id INTEGER NOT NULL REFERENCES accounts(id),
  realm_id INTEGER NOT NULL REFERENCES realms(id), char_key TEXT NOT NULL,      -- Name-Realm
  opaque_id TEXT, class TEXT, race TEXT, faction TEXT, level INTEGER, spec TEXT,
  first_seen INTEGER, last_seen INTEGER, UNIQUE (account_id, char_key)) STRICT;
CREATE TABLE character_profile_history (
  id INTEGER PRIMARY KEY, character_id INTEGER NOT NULL REFERENCES characters(id),
  at INTEGER NOT NULL, snapshot_json TEXT NOT NULL, source_id INTEGER NOT NULL REFERENCES sources(id)) STRICT;
CREATE TABLE sources (
  id INTEGER PRIMARY KEY, account_id INTEGER NOT NULL REFERENCES accounts(id), path TEXT NOT NULL,
  size INTEGER NOT NULL, mtime INTEGER NOT NULL, sha256 TEXT NOT NULL, addon_build TEXT,
  UNIQUE (account_id, sha256)) STRICT;
CREATE TABLE ingest_runs (
  id INTEGER PRIMARY KEY, source_id INTEGER REFERENCES sources(id), started_at INTEGER NOT NULL,
  finished_at INTEGER, status TEXT NOT NULL CHECK (status IN ('ok','failed','skipped')),
  app_version TEXT NOT NULL, counts_json TEXT, error TEXT) STRICT;
CREATE TABLE datasets (
  name TEXT PRIMARY KEY, saved_path TEXT, scope TEXT, mapping TEXT NOT NULL,  -- typed table name or 'generic'
  grp TEXT NOT NULL, social INTEGER NOT NULL DEFAULT 0) STRICT;
CREATE TABLE archive_entries (
  id INTEGER PRIMARY KEY, account_id INTEGER NOT NULL REFERENCES accounts(id),
  dataset TEXT NOT NULL REFERENCES datasets(name), entry_id TEXT NOT NULL, revision INTEGER NOT NULL,
  path TEXT, keys_json TEXT, scope TEXT, char_key TEXT, archived_at INTEGER,
  row_json TEXT NOT NULL, row_sha256 TEXT NOT NULL, confirmed_at INTEGER,
  UNIQUE (account_id, entry_id, revision)) STRICT;
CREATE TABLE observations (                                     -- active (not yet archived) rows, generic or typed
  id INTEGER PRIMARY KEY, account_id INTEGER NOT NULL REFERENCES accounts(id),
  character_id INTEGER REFERENCES characters(id), dataset TEXT NOT NULL REFERENCES datasets(name),
  saved_path TEXT NOT NULL, position TEXT, keys_json TEXT, at INTEGER, play_session_id TEXT,
  row_json TEXT NOT NULL, row_sha256 TEXT NOT NULL, revision INTEGER NOT NULL DEFAULT 1,
  archive_entry_id INTEGER REFERENCES archive_entries(id),       -- set once the row reaches the archive
  UNIQUE (account_id, dataset, saved_path, position, row_sha256)) STRICT;
CREATE TABLE damaged_values (
  id INTEGER PRIMARY KEY, account_id INTEGER NOT NULL REFERENCES accounts(id),
  path TEXT, value_json TEXT NOT NULL, at INTEGER, value_sha256 TEXT NOT NULL,
  UNIQUE (account_id, path, at, value_sha256)) STRICT;
CREATE TABLE provenance (
  id INTEGER PRIMARY KEY, tbl TEXT NOT NULL, row_id INTEGER NOT NULL, ingest_run_id INTEGER NOT NULL REFERENCES ingest_runs(id),
  source_id INTEGER NOT NULL REFERENCES sources(id), dataset TEXT, saved_path TEXT, keys_json TEXT,
  char_key TEXT, captured_at INTEGER, addon_build TEXT, revision INTEGER NOT NULL,
  UNIQUE (tbl, row_id, revision)) STRICT;
CREATE TABLE lineage (derived_tbl TEXT NOT NULL, derived_id INTEGER NOT NULL, input_evidence TEXT NOT NULL) STRICT;
CREATE TABLE sessions (
  id INTEGER PRIMARY KEY, character_id INTEGER NOT NULL REFERENCES characters(id), play_session_id TEXT,
  started_at INTEGER, ended_at INTEGER, inferred INTEGER NOT NULL DEFAULT 0, summary_json TEXT NOT NULL,
  build TEXT NOT NULL) STRICT;                                     -- derived; rebuilt, never the only copy
CREATE TABLE goals (id INTEGER PRIMARY KEY, character_id INTEGER NOT NULL REFERENCES characters(id),
  goal_key TEXT NOT NULL, record_json TEXT NOT NULL, origin TEXT NOT NULL, created_at INTEGER NOT NULL) STRICT;
CREATE TABLE plans (id INTEGER PRIMARY KEY, character_id INTEGER NOT NULL REFERENCES characters(id),
  plan_id TEXT NOT NULL UNIQUE, record_json TEXT NOT NULL, created_at INTEGER NOT NULL,
  delivered_via TEXT CHECK (delivered_via IN ('clipboard','advice_file') OR delivered_via IS NULL),
  delivered_at INTEGER) STRICT;
CREATE TABLE outcomes (id INTEGER PRIMARY KEY, plan_id TEXT REFERENCES plans(plan_id), session_id INTEGER REFERENCES sessions(id),
  record_json TEXT NOT NULL, estimate_error_json TEXT, at INTEGER NOT NULL) STRICT;
CREATE TABLE ai_exchanges (id INTEGER PRIMARY KEY, at INTEGER NOT NULL, provider TEXT NOT NULL, model TEXT,
  envelope_json TEXT NOT NULL, response_json TEXT, accepted INTEGER NOT NULL, rejection TEXT,
  tokens_in INTEGER, tokens_out INTEGER) STRICT;                   -- what was sent, exactly as previewed
CREATE TABLE reference_packs (id INTEGER PRIMARY KEY, pack TEXT NOT NULL, file TEXT NOT NULL, version TEXT,
  sha256 TEXT NOT NULL, UNIQUE (file, sha256)) STRICT;
CREATE TABLE reference_values (pack_id INTEGER NOT NULL REFERENCES reference_packs(id), path TEXT NOT NULL,
  value TEXT, verified INTEGER) STRICT;                            -- flattened, as preservation_flatten.lua emits
```

**Indexes:**
- `archive_entries(account_id, dataset, char_key, archived_at)`
- `observations(account_id, character_id, dataset, at)`
- `observations(play_session_id)`
- `provenance(tbl, row_id)`
- `sessions(character_id, started_at)`
- `reference_values(path)`

**Typed views (not tables).** Each typed mapping in section 7 is a SQL view over `archive_entries` and `observations` that uses `json_extract`. Because they are views, a mapping mistake can never lose data: the original JSON is always the stored copy.

## 6. Idempotency and revisions

| Case | Result |
|---|---|
| Archive entry with the same (account, entry_id) and the same `row_sha256` as the latest revision | Skipped |
| Same id, different checksum | A new revision (n+1). Earlier revisions are kept, and both are visible in the vault browser. |
| Active row seen again unchanged | Skipped, by the unique key |
| Active row changed in place (a counter went up, say) | A new revision linked to the previous one by (dataset, saved_path, position) |
| Active row later found in the archive (same dataset, same `row_sha256`) | `observations.archive_entry_id` is set. Both rows are kept. |
| Canonical JSON | Lua tables are converted with array parts as JSON arrays (1..n with no holes) and everything else as objects with string keys, sorted. Numbers use the shortest round-trip form. `row_sha256` is sha256 of these bytes. **The Lua side (OCC-02-09b) must compute the same bytes**, and a shared fixture proves it. |

## 7. Dataset mapping (all 72 datasets in `docs/quality/data_preservation_audit.json`)

**Rules:**
- The registry (OCC-02-05) is generated from the audit JSON. A test fails when the audit has a dataset the registry lacks.
- "View" names a typed view. "generic" means the row is kept and searchable as JSON, with no typed view yet.
- Social datasets are flagged and handled per decision D06.

| Group | Dataset | Saved path | View |
|---|---|---|---|
| Economy | prices | global.prices[itemID] | v_prices |
| | priceHistory | global.priceLog.items[itemID] | v_price_history |
| | priceHistoryItems | global.priceLog.items[itemID] | v_price_history |
| | priceWatch | global.priceLog.watch[itemID] | generic |
| | ahSearchHistory | global.ahSearchHistory | generic |
| | auctionPosts | global.postHistory[itemID] | v_auction_posts |
| | salesLedger | char.auctionSales | v_sales |
| | confirmedSales | char.outcomes.sales | v_sales |
| | goldLedger | char.ledger | v_gold_ledger |
| | economyOutcomes | char.intelEconomyOutcomes | v_economy_outcomes |
| | mailRecent | global.mailRecent | generic |
| | treasurerReserves | char.treasurer.reserves | generic |
| | supplyReservations | global.supply.reservations | generic |
| World | sightings | global.sightings[npcID] | v_sightings |
| | sightingObservations | global.respawnObs[npcID] | v_respawn_obs |
| | rareCastGaps | global.rareProfiles[npcID].spells[spell].gaps | generic |
| | spawnLog | global.spawnLogs[spot] | v_spawn_log |
| | nodeState | global.nodeState | generic |
| | trail | global.trails[mapID] | v_trail_points |
| | trailCleared | global.trails[mapID] | v_trail_points |
| | discoveredRecent | global.discovered.recent | generic |
| | clearedPlaces | global.pois | generic |
| | clearedDiscovered | global.discovered | generic |
| | instances | global.instances | v_instances |
| | petsSeen | global.petsSeen | generic |
| | fishNotable | global.fishLog.notable | v_fishing |
| | fishSessions | global.fishLog.sessions | v_fishing |
| | fishCatchesPerPoint | char.fishSkill.per | generic |
| | worldProvenance | global.worldProvenance | generic |
| | worldPackReplaced | World.active (runtime) | generic |
| | routesDeleted | global.routes.list[id] | generic |
| Census | censusPlayers | global.census[realm].players[name] | generic |
| | censusProfs | global.census[realm].profs[name][prof] | generic |
| | censusCleared | global.census[realm] | generic |
| Play history | questDiary | global.questHistory[character] | v_quest_diary |
| | dungeonRuns | global.runs | v_dungeon_runs |
| | deaths | global.deathHistory | v_deaths |
| | fights | char.fights | v_fights |
| | xpSessions | char.xp60.history | v_xp_segments |
| | xpSessionsCleared | char.xp60 | v_xp_segments |
| | outcomeEvents | char.outcomes.events | v_outcome_events |
| | activitySessions | char.outcomes.activity | v_activity |
| | travelTrips | char.outcomes.travel | v_travel |
| | chronicleEntries | char.outcomes.chronicle | generic |
| | chronicleCleared | char.outcomes.chronicle | generic |
| | layerHistory | char.modules.Layers.settings.history | generic |
| | nexusLastPlan | char.modules.Nexus.settings.lastPlan | v_addon_plans |
| Social (D06) | chat | global.chatArchive | generic, social |
| | chatByPerson | global.whisperArchive[who] | generic, social |
| Feedback | feedback | global.feedback | generic |
| | adviceFeedback | char.adviceFeedback | generic |
| | radarFeedback | char.radarFeedback[candidateId] | generic |
| | radarFeedbackCleared | char.radarFeedback | generic |
| | nextSessionDismissed | char.modules.NextSession.settings.dismissed | generic |
| | xp60Suppressed | char.xp60Suppressed | generic |
| | challengesDismissed | char.challenges.dismissed | generic |
| Planning and sharing | expeditionProgress | char.expedition | generic |
| | planShareOffered | char.planshare.offered | generic |
| | planShareRoutes | char.planshare.routes | generic |
| | contributeQueue | global.contribute.queue | generic |
| | contributeBuilds | global.contribute.builds | generic |
| | contributeSeen | global.contribute.seen | generic |
| | macroPrevBodies | settings.installed[name].prev | generic |
| | trainingOldFormat | global.classTraining[key] | generic |
| Lifecycle | xp60OldSchema | char.xp60 | generic |
| | profileOldSchema | char.intelligenceProfile | generic |
| | outcomesReset | char.outcomes | generic |
| | settingsReset | chars[character] settings | generic |
| | outcomesStaging | char.outcomesStaging | generic |
| | xp60Staging | char.xp60Staging | generic |
| | intelligenceProfileStaging | char.intelligenceProfileStaging | generic |
| | passportSalt | global.passport.salt | used only to derive opaque ids, and never shown or sent |

**Reference data.** Shipped data packs (`addon/Outrider/Data/*.lua`, `addon/Outrider_Data_*/*.lua`) go into `reference_packs` and `reference_values` (OCC-02-10). They are never mixed with the player's own observations. Their `verified` flag is carried through unchanged (rule 7).

## 8. Off-load protocol (from `docs/ARCHIVE_GROWTH.md`, "Lossless off-load design")

1. After logout, Command Center reads `Outrider.lua` read-only (section 4).
2. It stores every archive entry it hasn't seen (section 6), in one committed transaction with WAL and a checkpoint.
3. It reads each newly stored entry back from the vault and compares its canonical bytes and `row_sha256` with the source.
4. Only then, and only while the game is closed, it writes a data-only `confirmed` block into Advice.lua through `advice.py`:

   ```lua
   Outrider_Advice = {
     -- existing advice fields unchanged
     confirmed = { v = 1, vault = "<vault uuid>", at = 1764000000,
       ids = { ["s123:45"] = "<row_sha256 hex>", ... } },
   }
   ```

   `AdviceLoader.lua` validates the block: correct types, hex of length 64, at most N ids per file with the rest in the next round. It shows the count. A malformed block is ignored.
5. **Owner-gated (D05, OCC-02-09b).** At the next login, the addon moves an entry out of SavedVariables only if its id **and** its recomputed checksum match, and only with the feature setting on. Anything else stays.
6. Outrider can show archived history through an existing paste-code path, or through a summary the companion writes into the same data file.

**Guarantees:**
- Without Command Center, or on any mismatch, everything stays in SavedVariables.
- `confirmed_at` is set in `archive_entries` when the confirmation is written.
- Entries are never removed from the vault.

## 9. Versioning, migrations, backups and configuration

| Topic | Contract |
|---|---|
| Schema version | `PRAGMA user_version`, plus `meta.schema_version` and `meta.vault_uuid` |
| Migrations | Forward only, in one transaction. A dropped column or table is renamed `_old_<v>` and kept. An online backup (`sqlite3` backup API) is taken first. |
| Backups | `<vault dir>/backups/<UTC stamp>.sqlite` before each migration and on the user's schedule. They are never auto-deleted; the UI shows total size. |
| Integrity | `PRAGMA integrity_check` at startup. On failure the app opens read-only, offers a restore into a new file, and keeps the broken file. |
| Config | `companion/config.json` gets a `commandCenter` block with schema `v`. The old file is copied to `companion/backups/<stamp>/` before any change. Unknown keys are kept. |
| Contract versions | `occ_contract.json` carries `v`. A breaking addon change bumps it and needs a migration task. |

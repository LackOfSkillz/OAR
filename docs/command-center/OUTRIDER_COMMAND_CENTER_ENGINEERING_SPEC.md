# Outrider Command Center: engineering specification

**Status:** PLANNING ONLY. No Command Center production code is authorised until the owner approves the decisions in section 9 and this package passes independent review (ChatGPT). Task namespace: `OCC-`.

**Companion documents (all in `docs/command-center/`):**

| Document | What it holds |
|---|---|
| `OUTRIDER_COMMAND_CENTER_ARCHITECTURE.md` | The components, how they connect, the reuse map |
| `OUTRIDER_COMMAND_CENTER_DATA_CONTRACTS.md` | The Knowledge Vault schema, ingest and off-load contracts, IDs |
| `OUTRIDER_COMMAND_CENTER_IMPLEMENTATION_BACKLOG.md` | 78 microtasks across OCC-00 to OCC-08, with 9 review gates |
| `OUTRIDER_COMMAND_CENTER_ACCEPTANCE_TEST_PLAN.md` | Tests and evidence for each gate |
| `OUTRIDER_COMMAND_CENTER_SECURITY_AND_COMPLIANCE.md` | Policy boundaries, threat model, privacy |
| `OUTRIDER_COMMAND_CENTER_UI_UX_SPEC.md` | Screens, design system, plain-language rules |
| `OUTRIDER_COMMAND_CENTER_DEPENDENCY_AND_RISK_REGISTER.md` | External dependencies, risks, mitigations |

**Sources:**
- ChatGPT's Command Center proposal (pasted by the owner, 2026-11-25).
- ChatGPT's round-2 review and authorisation (2026-11-25). Its recovered design summary called for 24 capabilities, 9 phases, 66 microtasks and 9 gates. These are targets, not limits. The original draft text is not in the repository.
- The owner's concept art for the install companion: a dark and gold dashboard, used as mood reference only.
- A read-only inventory of this repository taken at `6523212` (section 3).

## 1. Purpose

Outrider helps you play Warcraft. Command Center helps you understand and manage everything you do in it, away from the game.

It is an optional Windows desktop application. It keeps everything Outrider has ever learned in a local database (the **Knowledge Vault**). On top of that it offers:
- history and analytics across all your characters;
- planning for your next session before you log in;
- an optional AI coach that answers from your own recorded evidence.

It is built by extending the existing Python companion (`companion/`), not by replacing it.

The addon stays complete without it. Every intelligence feature that runs in game today (Nexus, AfterAction, Horizon, GearROI, Oracle, Fellowship) keeps working with no desktop app installed.

## 2. Non-negotiable boundaries

These are inherited from the repository and override anything else in this package. Details are in the security document.

1. **Advice only (D6, D18).** No game automation, no input injection, no screen or window capture, no reading of process memory, and no live bridge to the running client. Command Center reads saved files and writes advice; the player acts in game.
2. **Read the game folder, don't write it.** `WTF\` is read-only. The only file written inside the game folder is the data-only `Interface\AddOns\Outrider\Advisor\Advice.lua` (D16), and only while the game is closed.
3. **Data preservation override.** Nothing collected is ever deleted, redacted or summarised in place of the original. Every migration archives first. Rows may leave SavedVariables only by the verified off-load protocol (data contracts, section 8), whose removal step needs separate owner approval.
4. **Privacy (rule 10, D22).** Nothing leaves the PC by default. Cloud AI is opt-in per provider and previews what it sends. Character names are never sent to a cloud model; opaque ids are used instead, as the passport does.
5. **AI is optional.** Every analytic, report and plan works with no model configured. The model explains and converses; it never becomes the only source of a number.
6. **Never invent game data (rule 7).** Analytics show what was recorded, with its provenance and confidence. Gaps are shown as gaps.

## 3. What exists today (inventory at `6523212`)

| Area | Existing component | Reuse decision |
|---|---|---|
| SavedVariables parsing | `luadata.py` (safe, data-only parser and writer), `store.py` (re-parse on mtime change, 20 MB cap) | Reuse as the ingest parser. Extend it to stream larger files (OCC-02-03). |
| Completed-session reading | `intelligence/session_reader.py` (bounded, stable-bytes read) | Reuse for ingest timing and consistency |
| Game-closed detection | `next_session_delivery.py` (process check through ctypes) | Extract into a shared helper (OCC-01-06) |
| Advice write | `advice.py` (4 whitelisted actions, writes Advice.lua) | Reuse unchanged; the only game-folder write |
| Export codes | `codes.py` (OTR1), `intelligence/passport.py` (OTRP1, opaque ids) | Reuse; passport rules become the cloud privacy rule |
| MCP server | `server.py` (15 tools, stdio) | Keep working. Add vault-backed read tools later (OCC-05-07). |
| AI providers | `providers.py` (local OpenAI-compatible, loopback only), `cloud.py` (Anthropic, OpenAI, Gemini), `budget.py` (spend guard), `keys.py` (Credential Manager) | Reuse as the AI Gateway |
| Grounding and validation | `context.py` (ContextEnvelope v2), `schemas_v3.py`, `schemas_v4.py` (Nexus records), `orchestrator.py` (deterministic fallback) | Reuse; the vault becomes the retrieval source |
| Planning | `planner.py`, `xp60_planner.py`, `xp_baseline.py`, `coach_v3.py` | Reuse and feed with vault history |
| GUI | `intelligence/window.py` (tkinter ask window) | Kept for compatibility. The new UI host is an owner decision (D01). |
| Offline reports | `cli.py` (sessions, report, export, passport) | Reuse; vault-backed versions added |
| Storage | JSON only (`config.json`, `usage.json`); no SQLite | New: the Knowledge Vault (stdlib `sqlite3`) |
| Off-load design | `docs/ARCHIVE_GROWTH.md`, "Lossless off-load design" | Becomes the formal off-load contract |
| Addon archive | `Core/Archive.lua` v2 (entries with stable id, path, keys, scope, char, at, row); 72 datasets in `docs/quality/data_preservation_audit.json` | The ingest source of truth |
| Character keys | `Name-Realm` (`ns.CharKey`), opaque passport id `c` + Adler32(salt\|key) | Same keys in the vault; opaque ids at the AI boundary |
| Tests and gates | 15 companion test files, about 250 Lua specs, quality, deps, security and preservation gates | Extended to cover the new package |
| Packaging | Plan only (`docs/companion/PACKAGING.md`); no installer exists | OCC-08 builds it per decision D03 |

## 4. Capabilities

Planning target was 24; this plan has 26. Each maps to tasks in the backlog.

| ID | Capability | Phase |
|---|---|---|
| C01 | Desktop application shell: single instance, lifecycle, settings | OCC-01 |
| C02 | Game folder discovery and read-only access | OCC-01 |
| C03 | Safe ingest after the game closes (stable bytes, never while WoW writes) | OCC-01, OCC-02 |
| C04 | Knowledge Vault: local SQLite, versioned schema, forward-only migrations | OCC-02 |
| C05 | Provenance and lineage on every stored row | OCC-02 |
| C06 | Backup, restore and integrity checking of the vault | OCC-02 |
| C07 | Lossless off-load: verified confirmations back to the addon | OCC-02 |
| C08 | Accounts, realms and characters with strict data isolation | OCC-03 |
| C09 | Class, specialisation, race and level awareness for every class | OCC-03 |
| C10 | Session timeline reconstruction from all recorded history | OCC-03 |
| C11 | Progression analytics: XP per hour, levelling curves, time use | OCC-03 |
| C12 | Economy analytics: gold ledger, sales, price history | OCC-03 |
| C13 | World knowledge analytics: rares, trails, nodes, fishing | OCC-03 |
| C14 | Trend detection and plain explanations ("why slower than last week") | OCC-03 |
| C15 | Goals and objectives that match the addon's Nexus v4 records | OCC-04 |
| C16 | Offline session planning with a time budget | OCC-04 |
| C17 | Choosing between characters ("which one tonight") | OCC-04 |
| C18 | Plan delivery to the game (advice code, or Advice.lua with the game closed) | OCC-04 |
| C19 | Learning from outcomes: comparing plans with what happened | OCC-04 |
| C20 | Optional AI providers: local OpenAI-compatible and cloud | OCC-05 |
| C21 | Grounded answers with evidence citations and confidence | OCC-05 |
| C22 | Privacy controls: what leaves, preview, opaque ids, budgets | OCC-05, OCC-07 |
| C23 | Vault browser and search with a provenance view | OCC-06 |
| C24 | Dashboards and reports, including the "welcome back" session report | OCC-06 |
| C25 | Diagnostics, recovery drills and self-checks | OCC-07 |
| C26 | Installer, manual updates and an uninstall that keeps data | OCC-08 |

## 5. Functional requirements

Each requirement is cited by its tasks' acceptance criteria.

**Ingest and the vault**

| ID | Requirement |
|---|---|
| FR-01 | Ingest reads `WTF\Account\<acct>\SavedVariables\Outrider.lua` read-only. It only reads when the game is not running and the file's bytes are stable across two reads. |
| FR-02 | Ingest is idempotent. Archive entries are keyed by their stable `id` plus a content checksum. Re-ingesting the same file adds nothing. A changed row with the same id is kept as a new revision, never overwritten. |
| FR-03 | All 72 datasets in the preservation audit are mapped to a vault table or to the generic observation table. An unmapped dataset is stored whole as generic JSON, never skipped. |
| FR-04 | Every vault row records its provenance: source file, ingest run, dataset, saved path, keys, character, capture time and the addon build that wrote it. |
| FR-05 | Multiple WoW accounts, realms and characters are kept apart. Every query is scoped by character unless the user picks "all characters". |
| FR-06 | The vault is backed up before every migration and on a schedule the user sets. Restore is tested. An integrity check runs at startup. |
| FR-07 | Off-load confirmations are written to Advice.lua only after a byte-for-byte read-back of the stored entry. The addon-side removal is a separate, owner-approved task (OCC-02-09b). |

**Analytics and planning**

| ID | Requirement |
|---|---|
| FR-08 | Analytics are deterministic and reproducible from the vault alone. The same vault and build give the same numbers. |
| FR-09 | Where the addon already computes a figure (AfterAction totals, XP/hour, quest time estimates), Command Center's figure for the same session matches it, or the difference is explained. |
| FR-10 | Every class and specialisation is supported. Content is scoped to the character's class, build, race and level, and other builds come last (owner rule "class and build aware"). |
| FR-11 | Plans reuse the addon's v4 contracts (Goal, Opportunity, Plan, Outcome) and are delivered only through advice paths the player acts on. |

**AI**

| ID | Requirement |
|---|---|
| FR-12 | AI answers cite vault evidence ids. Numbers in an answer must come from evidence, otherwise the answer is rejected and the deterministic fallback is shown. |
| FR-13 | With no provider configured, every screen still works, and the coach screen explains how to add one. |

**Interface**

| ID | Requirement |
|---|---|
| FR-14 | The interface is a cohesive product: one window, one navigation, one design system. Every page has a plain purpose line and 1-2-3 steps (owner rule "pages an 8th grader gets"). |

## 6. Quality requirements

| ID | Requirement |
|---|---|
| QR-01 Performance | Ingesting a 20 MB SavedVariables file takes under 60 s on the owner's PC. Each later incremental ingest takes under 10 s. Dashboards open in under 1 s for 3 years of synthetic history. These are budgets to be measured (OCC-07-05), not claims. |
| QR-02 Reliability | An interrupted ingest leaves the vault unchanged: one transaction per run, with SQLite WAL. A corrupt vault is detected and restored from backup without losing a confirmed row. |
| QR-03 Privacy | The egress test proves zero outbound connections with AI off. With AI on, only the previewed envelope is sent. |
| QR-04 Testability | Every component has unit tests. The fixture corpus (OCC-00-07) covers multiple characters and realms, damaged values, every archived dataset and large files. |
| QR-05 Maintainability | The new code passes the existing quality, deps and security gates with zero new findings. |
| QR-06 Accessibility | The interface is keyboard navigable, readable at 125-150% scaling, uses colour plus text for status, and meets a contrast ratio of at least 4.5:1. |

## 7. Phases

Each phase ends with a review gate. The next phase starts only after its gate passes and the reviewer accepts it.

| Phase | Scope | Tasks |
|---|---|---|
| OCC-00 | Architecture, policy boundaries, owner decisions, contracts, fixtures, repository foundation | 8 |
| OCC-01 | Desktop application framework and companion integration | 9 |
| OCC-02 | Knowledge Vault: schema, ingest, provenance, indexing, backup, off-load | 12 |
| OCC-03 | Character intelligence and historical analytics | 9 |
| OCC-04 | Progression, objectives and personalised session planning | 8 |
| OCC-05 | Optional local and cloud AI, grounded recommendations | 8 |
| OCC-06 | Unified dashboards, search and reporting | 9 |
| OCC-07 | Security, privacy, recovery and performance hardening | 8 |
| OCC-08 | Integration testing, installation, documentation, release readiness | 7 |
| | **Total (9 of them review gates)** | **78** |

## 8. Assumptions

| ID | Assumption |
|---|---|
| A1 | Windows 10/11, 64-bit, with Python 3.10+ bundled or installed (packaging decision D03) |
| A2 | One PC. No sync between PCs, and no server of ours. |
| A3 | The SavedVariables file format stays as today (Lua table text). The vault reads the archive v2 entry shape. |
| A4 | The game client writes SavedVariables only on logout or `/reload`, so a file that is stable while the game is closed is complete. |
| A5 | Existing companion users keep `config.json`, keys in Credential Manager and the MCP server; Command Center migrates the settings in place. |
| A6 | All numbers in the spec are budgets until measured on the owner's PC. |

## 9. Decisions the owner must make before implementation

Recommendations are first. None of these is decided yet.

| ID | Decision | Options (recommendation first) |
|---|---|---|
| D01 | UI host | (a) **Recommended.** Python stdlib backend serving a local web UI on 127.0.0.1 with a per-launch token, shown in a WebView2 window through one pinned dependency (`pywebview`), with the default browser as fallback. (b) tkinter and ttk only, which keeps zero dependencies but limits polish. (c) Electron or Tauri, which is most polish but a second runtime and a large dependency surface. |
| D02 | Dependency policy (amends D16, "stdlib only") | (a) **Recommended.** Allow a short pinned, hash-checked list (pywebview, PyInstaller at build time only), reviewed in the risk register. (b) Keep stdlib only, which forces D01 (b). |
| D03 | Packaging | (a) **Recommended.** A PyInstaller one-folder build with a zip and Setup.cmd, per user, no admin rights, unsigned at first. (b) Embedded Python zip. (c) A signed MSI, which needs a code-signing certificate. |
| D04 | Ingest trigger | (a) **Recommended.** Ingest when Command Center opens, plus an opt-in "ingest after the game closes" watcher that only reads files (like the XP60 opt-in polling). (b) A manual button only. |
| D05 | Off-load removal (data contracts, section 8, step 5) | (a) **Recommended.** Build confirmations (OCC-02-09a) now, and keep removal (OCC-02-09b) behind a separate approval after a full drill. (b) Never remove; SavedVariables keeps growing. |
| D06 | Opt-in social data (chat, chatByPerson) in the vault | (a) **Recommended.** Ingest it only if the addon's opt-in is on, never send it to AI, and keep it out of search unless asked. (b) Exclude it. |
| D07 | Product name and branding | Keep "Outrider Command Center", or pick another. The name and legal scope of "Outrider" are already an open owner item. |
| D08 | Cloud AI default provider and budget | Off by default (recommended). The owner picks the provider and the daily token cap. |
| D09 | Where the code lives | (a) **Recommended.** `companion/outrider_companion/command_center/` in this repo, on branch `occ-command-center`. (b) A separate repository. |

## 10. Open questions

| ID | Question |
|---|---|
| Q1 | Should one vault hold every WoW account on the PC, or one vault per account? Recommended: one vault, isolated by account. |
| Q2 | Should the vault read Outrider data packs (rares, macros, trails) as reference data for joins, or only player-recorded data? Recommended: read them, marked `reference`. |
| Q3 | Should Command Center replace the tkinter ask window, or keep both during a transition? Recommended: keep both until OCC-08. |
| Q4 | Will the owner test with more than one realm or account? This determines whether the multi-realm live test (OCC-08-04) is possible. |

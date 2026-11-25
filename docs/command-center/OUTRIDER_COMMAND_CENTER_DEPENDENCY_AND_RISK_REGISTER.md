# Outrider Command Center: dependency and risk register

**Status: PLANNING ONLY.** This register is reviewed at every gate: each gate packet lists any risk whose status changed.

## 1. Dependencies

| ID | Dependency | Used for | Status | Licence | Notes |
|---|---|---|---|---|---|
| DEP-01 | Python 3.10+ (CPython, Windows x64) | Everything | Existing (the companion needs 3.10+) | PSF | Bundled by the packaging if D03 (a) |
| DEP-02 | `sqlite3` (stdlib, SQLite 3.37+ for STRICT tables) | Knowledge Vault | Stdlib | Public domain | Check the bundled SQLite version at startup. Without STRICT, a fallback schema with CHECK constraints is used. |
| DEP-03 | `http.server`, `json`, `hashlib`, `ctypes`, `zlib`, `tkinter` (stdlib) | Local API, hashing, process check, existing GUI | Stdlib | PSF | |
| DEP-04 | pywebview (pinned and hash-checked) | UI host window | **Proposed, D01/D02** | BSD-3-Clause | Uses the system's WebView2 runtime |
| DEP-05 | Microsoft Edge WebView2 Runtime | UI rendering | System component (present on Windows 11; usually on 10) | Microsoft runtime licence; not redistributed | Without it, the default browser is the fallback |
| DEP-06 | PyInstaller (build time only, pinned) | Packaging | **Proposed, D03** | GPLv2 with bootloader exception | Not shipped as a library. The bootloader exception allows bundling. |
| DEP-07 | lupa (dev and test only) | Reading data packs for reference ingest; preservation gates | Existing dev dependency | MIT | Not shipped. The runtime reference ingest needs a Python reader or a pre-flattened export (OCC-02-10 decides). |
| DEP-08 | Local OpenAI-compatible server (for example LM Studio or Ollama), the user's choice | Optional local AI | Existing provider support | User's | Loopback only unless `allowRemote` |
| DEP-09 | Cloud AI APIs (Anthropic, OpenAI, Gemini) | Optional cloud AI | Existing provider support | Provider terms | Opt-in, consent, budgets (D08) |
| DEP-10 | Windows Credential Manager | API keys | Existing (`keys.py`) | OS | |
| DEP-11 | The SavedVariables format and the Outrider addon contracts (archive v2, OTR1, OTRP1, Advice.lua) | Ingest, delivery | Ours | GPLv3 | Frozen by `occ_contract.json` (OCC-00-05) |
| DEP-12 | WoW Forever client behaviour: SavedVariables written on logout or reload only | Ingest timing | Assumed (A4) | n/a | Verified in P0-07 for the addon. Re-check with the stable-bytes test. |

**Dependency policy (if D02 is approved):**
- Every runtime dependency is pinned by version and hash in `companion/requirements-occ.txt`.
- Each is reviewed for licence and security at G0 and G8.
- Nothing is fetched at runtime.

## 2. Risks

**Scales:**
- Likelihood (L) and impact (I): 1 (low) to 3 (high).
- Score is L × I.
- "Owner" is who acts on the risk: C means Claude, G means Gary (the owner).

| ID | Risk | L | I | Score | Mitigation | Owner | Phase |
|---|---|---|---|---|---|---|---|
| R01 | An addon change alters the SavedVariables or archive shape and breaks ingest | 2 | 3 | 6 | Contract fixture checked by Lua and Python (OCC-00-05). Unknown shapes are stored as generic JSON, never dropped. | C | OCC-00, OCC-02 |
| R02 | SavedVariables grows so large that parsing is slow or runs out of memory | 2 | 2 | 4 | Iterative parser, configurable cap, a 20 MB benchmark. Off-load (09a/09b) lets the file shrink once approved. | C | OCC-02, OCC-07 |
| R03 | Data loss in a vault migration, ingest bug or restore | 1 | 3 | 3 | Backups before migrations, revisions, no delete endpoint, strict preservation gate, drills | C | OCC-02, OCC-07 |
| R04 | The off-load removal step deletes a row that isn't really safe | 1 | 3 | 3 | id plus checksum match, read-back verification, a drill, off by default, written owner approval (D05) | C, G | OCC-02 |
| R05 | Privacy leak to a cloud provider (names, chat, other players) | 1 | 3 | 3 | Allow-list filter, opaque ids, no social data, preview equals what is sent, egress tests | C | OCC-05, OCC-07 |
| R06 | A web page attacks the local API (CSRF, DNS rebinding) | 2 | 2 | 4 | Token, Host and Origin checks, anti-CSRF header, loopback bind, security tests | C | OCC-01, OCC-07 |
| R07 | WebView2 is missing or broken on a user's PC | 1 | 2 | 2 | Detected, with the browser fallback | C | OCC-01 |
| R08 | Windows SmartScreen or antivirus flags the unsigned PyInstaller build | 3 | 2 | 6 | README note, published SHA256, consider signing (D03 c), avoid one-file mode (less often flagged) | G (signing), C | OCC-08 |
| R09 | Scope creep: Command Center grows into a second addon and delays the addon's live validation | 2 | 2 | 4 | Gates; no phase starts before its gate; the addon's live checks stay first in the owner's queue | G | All |
| R10 | Client API or behaviour changes on WoW Forever (save timing, file location) | 2 | 2 | 4 | Stable-bytes reads, locate scans flavours, Diagnostics shows paths, the probe results are kept current | C | OCC-01 |
| R11 | A single tester means few characters, realms and accounts in live tests | 3 | 2 | 6 | Synthetic multi-account corpus; the owner's three characters; ask the owner whether there is a second realm (Q4) | G | OCC-08 |
| R12 | Analytics disagree with the in-game numbers, and trust is lost | 2 | 2 | 4 | Parity tests against the Lua AfterAction and Estimator; differences listed with reasons | C | OCC-03, OCC-04 |
| R13 | The model makes up advice that sounds authoritative | 2 | 2 | 4 | Number and citation validation, deterministic fallback, confidence from evidence, poisoned-model tests | C | OCC-05 |
| R14 | Changing the D16 dependency policy weakens the security posture | 1 | 2 | 2 | A short pinned list, hash checks, review at G0 and G8, no runtime fetch | G (D02), C | OCC-00 |
| R15 | The GitHub CI billing block persists, so there is no independent CI evidence | 3 | 1 | 3 | Fresh-clone logs in every packet; the owner restores CI billing | G | All |
| R16 | Large backups fill the disk, because they are never auto-deleted | 2 | 1 | 2 | The UI shows backup size; the user may move old backups elsewhere; a disk-full drill | C | OCC-02, OCC-07 |
| R17 | Name or legal conflict with "Outrider" or "Command Center" | 1 | 2 | 2 | Owner decision D07, together with the open naming item | G | OCC-00, OCC-08 |
| R18 | Playing while the watcher polls could be seen as a bridge | 1 | 3 | 3 | The watcher only reads the process list and the file mtime, never touches the game, and is opt-in (D04). Documented under the ToS boundary. | C, G | OCC-01 |
| R19 | Python and Lua canonical JSON or checksums differ, so off-load never confirms or confirms wrongly | 2 | 2 | 4 | A shared checksum fixture, tested in both languages before 09b | C | OCC-02 |
| R20 | Existing companion users (MCP, CLI, ask window) break | 1 | 2 | 2 | Compatibility tests; the 15 MCP tools are frozen; existing tests run unchanged | C | OCC-01 |

## 3. Highest risks

These are the risks scoring 6. They are reviewed at G0:

- **R01 (contract drift):** the contract freeze is the first technical task.
- **R08 (unsigned build flagged):** needs an owner decision on signing before OCC-08.
- **R11 (single tester):** plan the live tests around the owner's real characters, and state the coverage gap honestly.

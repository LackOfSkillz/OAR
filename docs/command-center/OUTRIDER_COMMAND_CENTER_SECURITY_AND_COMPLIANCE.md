# Outrider Command Center: security and compliance

**Status: PLANNING ONLY.** These rules come from the repository's existing decisions. Where this document and a repository decision disagree, the repository decision wins until the owner amends it.

## 1. Policy register

**Sources:** `CLAUDE.md` hard rules, `docs/DECISIONS.md`, and `docs/blueprint/OWNER_DIRECTIVE_DATA_PRESERVATION.md`. The "enforced by" column names the test or gate that will enforce each rule (OCC-00-02 checks this table against the tree).

| Rule | Source | What it means for Command Center | Enforced by |
|---|---|---|---|
| No game automation | CLAUDE.md rule 1, D6 | No keystrokes, clicks or input to the WoW client. Nothing fires game actions. | security_check rule (no SendInput, keyboard or mouse libraries); reviewer |
| Advice only | D18 | No screen or window capture, no reading of game memory, no runtime addon rewrites, and no side channels. Output is advice the player applies. | security_check (no ReadProcessMemory, capture APIs or OpenProcess with VM rights); review |
| Game folder is read-only except Advice.lua | CLAUDE.md rule 2, D16 | WTF is read-only. The only write is `Advisor\Advice.lua` through `advice.py`, with the game closed. | `test_locate.py` tree hash; the delivery refusal test; a security_check write-path rule |
| Fail soft | Rule 3 | A missing file or bad input turns a feature off. It never crashes the app or the addon. | Unit tests; the recovery drills |
| No combat log parsing | Rule 4 | Not applicable (no live client). The vault never derives features from combat log data. | Review |
| Quiet by default | Rule 6 | No notifications unless the user enables them. Auto-start is not the default. | UI review; installer test |
| Never invent game data | Rule 7 | Analytics show recorded data with provenance. Unverified pack values stay flagged. | `test_reference.py`; the trends "not enough data" test |
| Hook, don't replace | Rule 8 | The existing companion surfaces stay. The vault reads Outrider data only, not other addons' SavedVariables. | `test_compat.py`; locate scope test |
| Tests green before deploy | Rule 9 | Every gate has a fresh-clone run. Gate tools fail closed. | Gate packets |
| Privacy | Rule 10, D22 | Nothing leaves the PC by default. Cloud AI is opt-in, with consent and a preview, and uses opaque ids. | Egress test; privacy filter tests |
| Companion design | D16 | Reads files, one write (Advice.lua), off by default, no network by default. The stdlib-only clause is **amended only if D02 is approved**. | deps review; security_check |
| AI optional | D7, D22 | Deterministic core; AI explains | `test_ai_off.py` |
| Licence | D20, D21 | GPLv3. Bundled third-party components need compatible licences and notices. Data packs are public; the raw sources stay private. | Licence script (OCC-08-06) |
| Data preservation override | Owner directive, 2026-11-24 | Nothing collected is deleted, redacted or summarised in place of the original. Archive first. Vault revisions, never overwrites. No delete endpoint. Uninstall keeps the vault. | Preservation gates (strict, fail closed); `test_no_delete.py`; drills |
| Off-load removal | D05 (pending) | The addon removes rows only after confirmation and written owner approval | OCC-02-09b gate |
| No CurseForge or release without the owner | Owner (release cadence) | Nothing is published or merged into `main` without owner authorisation | Process; G8 |

## 2. Threat model

### Assets

- the vault (complete play history)
- API keys
- the SavedVariables files
- the integrity of the game install
- the player's account standing
- the privacy of the player and of other players (census, chat)

### Trust boundaries

1. Game files to Command Center: the parser.
2. Local web server to the UI: loopback HTTP.
3. Command Center to AI providers: the network.
4. Model output to the app: untrusted text.
5. Command Center to the game: Advice.lua.

| # | Threat | Mitigation | Test |
|---|---|---|---|
| T1 | A malicious or damaged SavedVariables file executes code | `luadata.parse` is data only, never `exec` or `load`. Iterative parse. Size cap. Code-shaped input is refused. | Parser fuzz tests; the `occ/damaged` fixture |
| T2 | A website the user visits calls the local API (CSRF, DNS rebinding) | Per-launch 256-bit token. Host and Origin allow-list. Anti-CSRF header on writes. Binds 127.0.0.1 only. | `test_server_security.py` |
| T3 | Another local user reads the vault or the token | The vault is in the user's `%LOCALAPPDATA%` (user-only ACL). The token is held in memory and passed only in the window URL. | ACL check test; review |
| T4 | Path traversal through the static file server | A fixed static root, resolved paths compared with the root, no symlink following | Traversal tests |
| T5 | Model output is executed or written as code | Model text is never passed to `eval`, `exec`, a shell, SQL or the file system. Advice items are validated against the 4 whitelisted actions (`advice.py`). | `test_security.py` regex rules plus AST rules |
| T6 | Made-up facts presented as truth | Number and citation validation. Deterministic fallback. Confidence comes from evidence. | Poisoned-model tests |
| T7 | Personal data sent to the cloud | The passport allow list, opaque ids, no social data or free text, preview equals what is sent, consent per provider | Egress and filter tests |
| T8 | Key leakage | Keys in Windows Credential Manager only. Redacted in logs. Never echoed by the UI. | Scan test |
| T9 | Data loss from a migration or bug | Backups before migrations. Revisions. No delete endpoint. Integrity check. Drills. | Drill suite; preservation gate |
| T10 | Writing to the game while it runs corrupts files, or looks like a bridge | The game-closed check before every write, plus a re-check immediately before the write | Delivery refusal test |
| T11 | A compromised dependency | Pinned, hash-checked dependencies (D02). Build-time-only tools are not shipped. The register is reviewed. | `deps` review; licence and hash check |
| T12 | SQL injection through search | Parameterised SQL only. No string-built queries. | Injection tests; a security_check rule |
| T13 | An unsigned installer is replaced by a tampered copy | SHA256 published with each release candidate; signing considered (D03 c) | RC packet |

## 3. Secure handling of model interaction

- **Inputs** are built only by `ai/retrieve.py` from vault rows, through the privacy filter (section 4).
- **Outputs** are parsed into a schema (`schemas_v3` or `schemas_v4`). Anything that doesn't validate is discarded, and the deterministic answer is shown with a note.
- **Every exchange** is logged locally in `ai_exchanges` (what was sent and what came back), so the user can audit it.
- **Spend** is capped by `budget.py` (`dailyTokenCap`). A blocked call is shown to the user, not retried silently.

## 4. Privacy

| Data | Stays local | May go to a local model (loopback) | May go to a cloud model (opt-in) |
|---|---|---|---|
| Character name, realm, account | Yes | No; opaque id only | No; opaque id only |
| Class, level, role, zone, goals, plan, gear slots, professions, gold band | Yes | Yes | Yes, as on the passport allow list |
| Session figures (XP, time use, deaths) | Yes | Yes | Yes, aggregated |
| Census of other players | Yes | No | No |
| Chat and whispers (opt-in in the addon, D06) | Only if the addon opt-in is on | No | No |
| API keys | Credential Manager | n/a | Sent only to that provider, as its auth header |
| Logs and diagnostics | Yes | No | No |

**Other rules:**
- There is no telemetry, crash upload or update check. Updates are manual.
- Before each cloud request the user sees the exact bytes. A per-provider "don't ask again" may be set; it is off by default.
- The vault can be exported by the user to a file they choose. Nothing is exported automatically.

## 5. Blizzard Terms of Service boundary

Command Center is game intelligence, not game automation (D18). It reads only files the game has finished writing, with the game closed. It writes only a data file that the addon reads after a `/reload`, and the player acts in game. It never:
- reads process memory
- captures the screen
- injects input
- hooks the client
- changes the addon's code at runtime
- talks to the running game

## 6. Compliance checklist (gate packets copy this)

- [ ] No new write path inside the game folder other than Advice.lua through `advice.py` (security_check)
- [ ] The game-closed check is present before every game-folder read for ingest and before every write
- [ ] No outbound network with AI off (egress test)
- [ ] Cloud requests only with consent; preview equals what is sent
- [ ] Opaque character ids only at the AI boundary
- [ ] No social data in any envelope
- [ ] No delete or redact endpoint; uninstall keeps the vault
- [ ] Migrations back up first; drills pass
- [ ] Preservation gates strict and green
- [ ] Keys never in logs, the vault or config
- [ ] Dependencies pinned and hash-checked; licences compatible with GPLv3; notices present
- [ ] Owner decisions cited for anything that amends D16 or D05

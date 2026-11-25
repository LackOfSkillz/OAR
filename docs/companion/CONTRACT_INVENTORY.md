# Companion contract inventory (OI08-01)

**One companion, one server, no separate state store.** Everything below already exists under `companion/outrider_companion/` (Python, standard library only) and the addon's `Advisor/` folder. Phase 8 reuses it: no second server, model bridge or database was added.

## Components and what they reuse

| Component | File | Role | Reused by |
|---|---|---|---|
| SavedVariables reader | `luadata.py`, `store.py` (20 MB cap), `intelligence/session_reader.py` (stable read, refuses a file changing while read) | Plain-data parse; never runs the file | every tool, XP60, `cli.py` (OI08-03) |
| OTR1 codec | `codes.py` (depth 32, 400 000 bytes) | Same format as `Core/Serialize.lua` (golden contract tests) | advice codes, passports (OI08-02) |
| MCP server | `server.py` (stdio, JSON-RPC) | The only server: 16 tools (reads, `write_advice`, the clipboard pair and plan export) | Claude Desktop or Claude Code |
| Advice writer | `advice.py` (schema 1, 12 items, 64 KB) | The only file write: data-only `Advisor/Advice.lua` | `write_advice`, XP60 delivery (policy-gated, OI08-05) |
| Clipboard | `clipboard.py` (2 MB cap) | The no-reload route | `read_clipboard_snapshot`, `advice_to_clipboard`, `plan_to_clipboard` |
| Context v2 | `intelligence/context.py` (schema 2, 20 candidates, 200-character texts) | Bounded evidence for a model | `ask.py`, `orchestrator.py` |
| Envelope v3 | `intelligence/schemas_v3.py` (schema 3, 50 KB, 12 opportunities, 3 picks) | Coach request and reply | `coach_v3.py` |
| Nexus v4 | `intelligence/schemas_v4.py` with `docs/contracts/nexus_v4.lua` and its fixtures | Plan transport; id and control-character checks | `plan_to_clipboard`, contract fixtures |
| Providers | `intelligence/providers.py` (800 tokens, 60 s, 256 KB response, loopback only by default, redirects refused, 30 s circuit breaker), `cloud.py` (Anthropic, 4000 tokens) | No provider is required; none falls back to another by itself | `orchestrator.py`, `ask.py` |
| Keys | `intelligence/keys.py` (Windows Credential Manager, `Outrider/` prefix) | Credentials never in files or logs | providers |
| Budget | `intelligence/budget.py` (100 000 tokens a day by default) | Spend limit | cloud calls |
| XP60 | `intelligence/xp60_planner.py`, `xp_baseline.py`, `next_session_delivery.py`, `xp60_cli.py` | Post-logout 60-minute plan; install only after the game exits **and** with the owner's policy approval (OI08-05) | `xp60_cli` |
| Addon side | `Advisor/Snapshot.lua`, `Advisor/AdviceLoader.lua`, `Advisor/Advice.lua` (data only), `Intelligence/Passport.lua` | Snapshot out, advice in, by copy and paste | `/ride ask`, the Advisor tab |

## Schema versions and migrations

| Contract | Current | Older accepted | Migration |
|---|---|---|---|
| Advice | 1 | none | none needed |
| Advice v2 (answer and cards) | 2 | 1 (still read) | `advice_v2_spec` |
| Context | 2 | none | context is rebuilt each time |
| Envelope | 3 | none | a new envelope per question |
| Nexus | 4 | none | contract fixtures (`tools/contract_fixtures.ps1`) |
| Passport | 1 (`OTRP1`) | none | new in OI08-02 |
| Snapshot | v2 (contract fixture `snapshot_v2`) | none | the fixture is regenerated at release because it carries the addon version |

## Transport limits

- **Text codes:** 400 000 bytes and depth 32 on both sides.
- **Advice:** 64 KB and 12 items.
- **Envelope:** 50 KB.
- **Passport:** 16 KB.
- **Clipboard:** 2 MB.
- **Addon messages:** 240-byte pieces, 32 pieces at most (`Modules/Comm.lua`).
- **Model output:** 800 tokens locally, 4000 in the cloud; responses capped at 256 KB.

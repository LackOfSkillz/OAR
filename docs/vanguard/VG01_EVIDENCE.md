# VG01: Native roster and inspection (evidence)

Date: 2026-11-26. Authorized by Gary on 2026-11-26, after ChatGPT's VG00 review accepted the phase and corrections R01/R02 were done. Baseline: `fefc7a8`. The commit that adds this file is the candidate.

Status: **code and unit tests done; live checks pending.** Nothing here has passed in game yet. The tests run against the mock, which does not count as a live pass (spec section 10).

## What was built

| Task | Where | What it does |
|---|---|---|
| VG01-01 Lifecycle | `Modules/Vanguard.lua` | A module that is off by default (`defaultEnabled = false`, a preview). While off it registers no events, starts no timers and sends no requests. Turning it off cancels the running scan and clears the cache. |
| VG01-02 Roster adapter | `Vanguard/Roster.lua` | One list shape for solo, party and raid (40 max). Each entry: unit, class, level, assigned role, subgroup (raid), connected, dead, availability. The key is the GUID if readable, else name-realm (your own realm is filled in), else the unit token marked ambiguous. Lookalikes are never merged: a second one gets `#2`. `generation` goes up only when the membership changes. |
| VG01-03 Observation schema | `Vanguard/Observation.lua` | Every fact records status (known, unknown, stale, conflicting, unsupported), source, time and optional expiry. Secrets are refused before any comparison. nil means unknown, never 0. Numbers must be finite, strings are capped at 80 characters, and tables are refused. Also: `Valid`, `Age` (expired facts become stale), `Merge` (sources that disagree make it conflicting). |
| VG01-04 Inspect broker | `Core/InspectBroker.lua` | One request in flight. At least 2 s between requests, an 8 s timeout, one retry after a 4 s backoff. The queue holds at most 40. Cancel by token or owner; cancel everything on combat, zoning or logout. Events are registered only while the broker is busy. Requests for the same player share one inspect. |
| VG01-05 Ownership and conflicts | broker + `PlayerInfo.lua` | It waits while Blizzard's Inspect window is open and never clears inspect data under it. An `INSPECT_READY` for anyone else is ignored, and our request is tried again later. A reply is handed on only if the unit token still holds the same GUID. Vanguard also checks the scan id, the roster generation and the member GUID. The tooltip hover inspect now uses the broker, so Outrider has only one inspect consumer. |
| VG01-06 Slot normalization | `Vanguard/Profile.lua` | Each slot is known, pending, empty, unreadable (secret) or unavailable (no API). The enchant ID comes from the link. Pending items are checked again on `GET_ITEM_INFO_RECEIVED` (listened to only while something is loading) and up to 5 times on a 2 s timer. Checks only reach profiles still in the cache. |
| VG01-07 Talents and roles | `Vanguard/Profile.lua` | Talents use only APIs seen working on Forever (probe 2026-11-26): `GetInspectSpecialization`, and the Traits tree for `INSPECT_TRAIT_CONFIG_ID`, where it adds up ranks. If any talent node is unreadable, the point total is unknown, not a partial sum. Roles rank as: manual (you) over assigned (the group) over tentative (`GetSpecializationRoleByID`, the game's own answer). Nothing else is guessed. |
| VG01-08 Transient cache | `Vanguard/Cache.lua` | Memory only. Entries last 5 minutes and then show as old. The cache holds at most 45. It drops members who leave and is cleared on logout or when the module is turned off. Logs hold counts only. |
| VG01-09 Scan interface | `Modules/Vanguard.lua` page | Dungeons > Group check (preview): Turn on/off, a stats strip (in the group, checked, scan progress), Scan group, Stop, Scan selected, Re-read group, set role, and a table with member, class, level, role, gear, talents and status. Drawing the page reads only the cache. |
| VG01-10 Integration and load | `tests/spec/vanguard_load_spec.lua` | A 40-player raid scan, late item data, 100 cancelled scans and 200 roster changes. |

## Tests (negative cases included)

- `tests/spec/inspect_broker_spec.lua` (9 tests): GAP spacing, one in flight, timeout and a single retry, an answer for someone else, the Inspect window open (defer, no clear), combat cancels and refuses new requests, a late answer after cancel, a reshuffled unit token, two owners sharing one request, out of range, the queue cap, cancel by owner, and hover inspect through the broker with KEEP = 300.
- `tests/spec/vanguard_spec.lua` (11 tests):
  - off by default with zero requests; on/off three times leaves no handlers or timers;
  - roster: mixed realms, same names, secret or missing GUIDs, offline, level -1, churn generation; raid of 40 with subgroups;
  - observations: unknown is not zero, real zero kept, secret, NaN, inf, table, string cap, Valid, Age, Merge;
  - scan: slot states, enchant, talent points, item level, pending then resolved;
  - roles: precedence, guess, unknown;
  - late answer after a group change or a reshuffled unit stores nothing;
  - combat, zoning and turning off cancel;
  - cache: 5-minute stale, leave drops;
  - drawing the page sends no inspect;
  - privacy: with debug on, the whole saved file has no GUIDs, names, realm or item names of scanned players (Census excluded per the D27 scope note); logout clears the cache.
- `tests/spec/vanguard_load_spec.lua` (3 tests): a 40-player scan, 39 requests (exactly one each), at most 4 timers at once, the queue within its cap, every profile matching its key, late item data filled in on the event, nothing still running afterwards; 100 cancels leave no queue, listener or timers, and late answers store nothing; 200 roster changes leave only current members in the cache.
- Existing `playerinfo_spec` and `vanguard_probe_spec` still pass with the broker.
- Full suite: run by `tools/deploy.ps1` (result in the gate packet).

## Data preservation

No saved dataset is changed, moved or shrunk. Vanguard writes nothing to SavedVariables except its module on/off state. Its log lines hold counts only. The tooltip inspect cache was memory-only before and still is; its lifetime went from 15 to 5 minutes (D27).

## Live checks still needed (L01–L05)

To be done in game, with self-collecting logs:
1. Party with non-users: turn on, scan, see rows fill in (L01).
2. A member far away or offline (L02).
3. Open Blizzard's Inspect window during a scan (L03).
4. Start a fight during a scan; someone leaves during a scan (L04).
5. A raid roster (L05).

The scan logs "scan N: X member(s) asked of Y" and "scan N done: A read, B not read, S s", with no names. Two new probe APIs (`GetSpecializationRoleByID`, `GetNormalizedRealmName`) are checked by the next `/ride probe`.

## Known limits

- Your own talents show "on the Talents page"; your own row reads only gear.
- There is no per-member TTL refresh on a gear change: rescan by hand (Scan selected).
- Raid unit order follows the game's raid index; there are no subgroup filters yet (VG02+ UI).

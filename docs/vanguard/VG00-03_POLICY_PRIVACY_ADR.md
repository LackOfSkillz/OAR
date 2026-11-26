# VG00-03: Policy and privacy decision record (ADR)

Date: 2026-11-26. Status: **accepted.** ChatGPT's VG00 review (2026-11-26) accepted it with corrections R01/R02, both done; Gary approved it and the three decisions below on 2026-11-26 and authorized VG01. Recorded as D27 in `docs/DECISIONS.md`.

## Context

Vanguard reads facts about other players (class, level, role, subgroup, inspected gear and talents) who have not installed Outrider and have not consented. Three binding rules meet here:

1. **D18 / CLAUDE.md hard rule 1:** advice only. No automation, no protected actions without a key press, no combat log, no screen or memory reading.
2. **Owner data-preservation override:** never delete or redact collected data; overflow is archived.
3. **Spec section 4:** no identifiable persistent profiles of non-consenting players.

They do not conflict if the line is drawn **at collection time**: what is never written cannot be lost, and what is written is kept forever.

## Decision

- **Non-consenting players' gear, talents, names, realms and GUIDs live only in memory** (the current-view cache) and are dropped on group leave, logout or reload. They are never written to SavedVariables, logs, snapshots, exports or Git. This is data minimisation by design. It is not deletion of collected data, because that data is never collected into permanent storage.
- **What is persisted is either your own character's data or anonymous run-level aggregates**, for example "5 players: 1 tank, 1 healer, 3 dps; 4 of 5 inspected; median item level 28; Deadmines, kill". Once written, these follow the preservation override: versioned, archived on overflow, never deleted.
- **Capability probes (VG00-04..06) record shapes and counts only.** They log no names, GUIDs or gear links of other players. A spec test checks every saved string for leaks.
- **Consenting peers (Fellowship, T2)** may share fields they preview and choose. Withdrawal stops display and use at once. Already-received shared data is invalidated for display, not destroyed. Any real deletion for privacy needs separate written owner authorisation.
- **Hostile input is not "collected data".** Malformed, oversized, spoofed or replayed packets are rejected and not kept (spec section 4).
- **Reports default to aggregates.** Names appear in a report only when the player explicitly selects them, and only through a copy box the player pastes themselves. Nothing is posted automatically.
- **Inspection is user-started.** Vanguard never inspects on a timer, on an event or in combat. The existing tooltip-hover inspect in PlayerInfo stays as it is (one request per hover) until VG01 moves it into one shared InspectBroker.

## Scope note: Census (found while fixing VG00-R02, 2026-11-26)

Outrider's older Census feature (Modules/Census.lua, since P8) already saves players seen nearby: name-realm, class, level, zone and time. It is used for the "Last seen" tooltip line, trade-chat professions and the realm census. It is not part of Vanguard, and under the preservation override it is kept as it is. D27 covers **what Vanguard and inspection add**: inspected gear, talents, specs, GUIDs and inspect log lines never reach saved data. A regression test checks this with debug mode on, across the whole saved file (`tests/spec/vanguard_probe_spec.lua`, "with debug on, nothing written to disk..."). It allows the name only inside Census, and only next to Census's simple sighting fields. Whether Census itself should change is a separate decision for Gary, not part of VG00.

## Implementation of the review corrections (2026-11-26)

- **VG00-R01:** `PlayerInfo:OnInspect` logged the inspected player's full name in debug mode. It now logs only "inspected a level N CLASS". Older log lines stay as they are (preservation override).
- **VG00-R02:** Vanguard probes keep only allowlisted values: numbers, booleans, a fixed word list (roles, classes, instance types), types with a size (`string(35)`, `table(54)`), and game-content names (boss and instance, capped at 60 characters). The generic `Probe.Shape` no longer writes any string value (it writes `string(n)`). That also covers the older damage-meter probe, whose session payloads can hold party members' names. Tests: every saved string in the probe samples; the whole saved file with debug on (GUID, realm, gear link, item name, talent import string and talent config name all absent); the damage-meter log carries no API string.

## Retention and consent matrix

| Data | Source | Where it lives | Kept how long | Consent | Removed by |
|---|---|---|---|---|---|
| Your own gear, talents, supplies | native | SavedVariables (char) | permanent, versioned | yours | never (archive on overflow) |
| Other player's class, level, role, subgroup | native roster | memory | while in group | none needed (visible to all) | leaving the group or reload |
| Other player's inspected gear and talents | native inspect | memory, TTL 5 min | current view only | not asked; not persisted | TTL, group leave, logout |
| Other player's name, GUID | native | memory only | current view | not persisted | as above |
| Peer-shared readiness (opt-in) | Fellowship | SavedVariables, scoped | until revoked or expired | explicit, previewed | revoke hides at once; data kept, flagged invalid |
| Run aggregates (composition, coverage, outcome) | derived | SavedVariables (global) | permanent | n/a, anonymous | never (archive) |
| Capability probe samples | probe | `global.probeGroup` (12), then archive | permanent | n/a, no identities | never |
| Your manual confirmations | you | SavedVariables (char) | permanent | yours | never |
| Rejected or malformed packets | network | not stored | none | n/a | dropped on receipt |

## Threat model (summary; full tests come in VG01/VG04/VG06)

| Threat | Mitigation |
|---|---|
| Spoofed sender or replayed packet | Comm sender check against the roster; generation, sequence and expiry; revocation can't be undone by a stale packet |
| Malformed or oversized packet or import | existing Comm size and rate limits; bounded strings and arrays; numbers must be finite; no code in imports |
| Late or mismatched `INSPECT_READY` | check GUID, roster epoch and request generation; ignore mismatches |
| Secret values | `issecretvalue` check before any compare, format or store; shown as unknown |
| Inspect taint or fighting the Inspect UI | never while `InspectFrame` is shown; `ClearInspectPlayer` only for our own request |
| Timer or queue leaks | one broker, bounded queue, cancel on combat, zoning, roster change or disable |
| Corrupted SavedVariables | `ns.KeepTable` / `Archive:KeepDamaged` (existing); fail closed |
| Public shaming | no rankings, no auto-posting; reports are aggregate by default |
| Cross-character leakage | per-character scope for own data; aggregates carry no names |
| Unsafe AI output | advice stays data-only (D16); no numbers from an LLM |

## Decisions (approved by Gary 2026-11-26, as ChatGPT's review recommended)

1. **Inspect cache lifetime:** 5 minutes, refreshed on a detected gear change, cleared on group leave, logout or reload; expired data shown as stale.
2. **Named run history with consenting friends:** Deferred until a separate consent design is approved.
3. **Should the tooltip-hover inspect stay automatic?** It inspects on hover today (PlayerInfo, setting on by default), which is a single request per hover, similar to GearScore Forever. Vanguard's own scans will be user-started only. Kept on by default with a setting to turn it off; every inspect goes through one shared InspectBroker (VG01-04).

## Consequences

- Vanguard history will never say "Bob wiped us". It can say "runs with no assigned tank were completed 2 of 7 times (Wilson range ...)".
- Once a player leaves the group, Vanguard can no longer show their gear.
- Probe evidence can be shared with the reviewer without exposing any player.

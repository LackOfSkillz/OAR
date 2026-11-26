# VG04: Roster optimization and optional sharing (evidence)

Date: 2026-11-26. Built after VG03 under D28 (gates batched into one final review). The commit that adds this file is the candidate.

Status: **code and unit tests done; live checks pending (VG04-08 is a live-only task and is outstanding).**

## What was built

| Task | Where | What it does |
|---|---|---|
| VG04-01 Hypothetical roster model | `Vanguard/WhatIf.lua` | `From` copies the live group into a model; every `Edit` (role, move, lock, bench, add a candidate class, drop a candidate) returns a new roster and leaves the old one and the live group untouched. Locked members can't move or be benched; real members can't be dropped, only benched; a candidate must be a class that has that role. |
| VG04-02 Subgroup optimizer | same | Deterministic local search (best swap or move each step), at most 200 steps and 20,000 evaluations, groups of 5, locks kept. Objective: party-wide effects (scope "party" in `Vanguard/Utility.lua`: Battle Shout, auras, Trueshot Aura) reaching each member, plus one healer per group. An exhaustive search (`WhatIf.Exhaustive`) is the reference for small rosters. |
| VG04-03 Encounter and alternatives ranking | same | Each single change (another role for a member, adding a healer, tank or damage dealer when there's room) is scored with the VG03 readiness engine against the chosen place, ranked by how much it raises the low and high ends. Wording never promises a clear; "nothing to try" says why (full group, single-role classes). |
| VG04-04 Assignment notes | `Modules/Vanguard.lua` | Your own notes per place and boss (`/ride vgnote <boss> | <who> | <task>`, 10 per boss, 60 characters), shown on the What-if page and copied with Copy notes. Nothing is posted, sent, marked or invited. |
| VG04-05 Fellowship protocol extension | `Vanguard/Share.lua` | Opt-in addon message `VPREP` v1 over PARTY or RAID: role, level, ready and Prep checklist counts, nothing else. Off by default; the exact fields are previewed before sending. Received packets are checked: group channel, sender in the group, version (a newer one is noted once), types and sizes, unknown fields refused. Old clients ignore the new type; members without Outrider keep the native-only view. |
| VG04-06 Consent and expiry | same + module | Sequence numbers go up per sender (time-based, so a reload doesn't reset them); a replayed or older packet is refused. A revoke is honoured at once, even right after an update, and a late update from before it can't bring the data back. Data expires after 15 minutes; leaving the group or turning Group check off forgets it. Stop sharing prep (or turning Group check off) sends a revoke. Memory only. |
| VG04-07 Mixed-source reconciliation | `Share.Reconcile`, `Vanguard:RoleOf` | Yours over the group's assigned role over what they shared over the game's guess. A shared role fills an unknown one; when it disagrees with the assigned role, the assigned role wins and the conflict is kept with its source and time. Nothing is overwritten silently; consent is never inferred. |
| VG04-08 Mixed installation live tests | — | **Outstanding: needs two Outrider users in one group and a raid.** See the live list below. |

UI: Dungeons > **What-if (preview)** (model table, edits, Find better groups, alternatives, notes, Copy notes); Group check gains Share my prep / Stop sharing prep with the field preview and what others shared.

## Tests

`tests/spec/vanguard_whatif_spec.lua` (9 tests): edits never touch the live group or the earlier roster, invalid edits refused; optimizer equals the exhaustive best on two fixtures and keeps locks; a 40-player optimization finishes within its bounds and is deterministic; alternatives ranked, adding a healer raises the low end, no promise words, a full single-role group explains why; notes saved as yours and nothing sent; protocol checks (unknown field, long expiry, big counts, bad role, NaN, newer version); receive (channel, membership, rate limit, replay, revoke at once, late packet after revoke, re-share, expiry, leaving); reconcile precedence and conflicts; your own sharing off by default, the payload passes our own checks with only the listed fields, Stop sends a revoke, a peer's role fills an unknown one and a disagreement is shown, turning off forgets peers and revokes.

## Data preservation

No saved dataset is changed or shrunk. New per-character settings: `sharePrep`, `assign` (your notes). Shared data from others is memory only.

## Live checks still needed (VG04-08, L07)

1. Two Outrider users in one party: Share my prep on one, see it on the other; Stop sharing: gone at once.
2. One sharer, three non-users: non-users keep the native view.
3. A raid roster: Find better groups on real subgroups.
4. Leave and rejoin while sharing; a manual Inspect during a scan with sharing on.

## Known limits

- The optimizer only knows party-scope effects in the utility registry; totems and other subgroup rules on Forever are not modeled.
- Candidates added in the model are fixed example classes (priest, warrior, mage) for each role.

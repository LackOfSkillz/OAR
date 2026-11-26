# VG03: Encounter assessment, Nexus and interface (evidence)

Date: 2026-11-26. Built after VG02 (`3ab8e19`) under D28 (gates batched into one final review). The commit that adds this file is the candidate.

Status: **code and unit tests done; live checks pending.** Mock results are not live passes.

## What was built

| Task | Where | What it does |
|---|---|---|
| VG03-01 Versioned encounter catalog | `Vanguard/Catalog.lua` | One entry per dungeon and raid in `Data/Dungeons.lua` (level range, size, raid flag; availability "reference", since `verified = false`), bosses and boss levels from the installed dungeon pack. Requirements: Outrider's 5-player template (tank, healer, three damage, levels in range, interrupt, resurrection), marked "template"; level and size marked "reference". Raids get no role template: their makeup on Forever is listed as unknown. Every entry lists "boss mechanics: not in any installed data". Version = `1.<places>.<bosses>`. Your own boss rules (`/ride vgboss`) are "manual". |
| VG03-02 Access dependency graph | `Vanguard/Access.lua` | AND/OR graph of level, quest flag, item, your own answer and references, memoized with a cycle guard and a depth cap. Unknown (unreadable quest flag or item count, no answer, missing node, loop) is never "denied". The installed data has no attunement chains, so a place gets its level range plus your access answer when you gave one. |
| VG03-03 Coverage and readiness engine | `Vanguard/Readiness.lua` | Spec section 8 math: weighted range from `[l, u]`, known-only index, coverage; a single number only at 80% coverage or more. Critical checks apart: confirmed missing = blocked (a high average can't hide it), unknown = not established, all met = prerequisites observed. Zero, NaN or out-of-range inputs are ignored or clamped. Pure, deterministic and monotonic. |
| VG03-04 Boss-specific risk matrix | `Vanguard/Assess.lua` | The group's results per requirement (roles counted with unknown roles widening the range, levels, size, utility from VG02 coverage, your access answer as a critical check), plus one row per boss: the same checks, your own rules for that boss, and members below the boss's level (from the pack). Risk tags explain; no probability anywhere. |
| VG03-05 Readiness improvement candidates | `Vanguard/Plan.lua` | Your actions from the Prep checklist (repair, food, drink, ammo, reagents, bag space, empty slot, enchant), ranked: critical first, readiness weight, known cheap before unknown, id. Group gaps are advice text only ("look for one; nothing is sent for you"). |
| VG03-06 Nexus adapters | `Vanguard/Plan.lua`, `Intelligence/Adapters.lua` | `Plan.Candidates()` gives WhatNow-shaped candidates that go through the existing `NexusAdapters.Adapt` validator, evidence and budget rules as the "vanguard" producer in `All` and `Resources`. Empty while Group check is off. Invalid candidates are rejected, not forced. Panel intent opens the Prep page. |
| VG03-07 GearROI and supply integration | `Vanguard/Plan.lua` | A price Outrider doesn't know stays unknown (`costUnknown`, never 0); a known cost that would dip into your gold reserve (`Treasurer.Fits`) is marked and ranked last; an enchant on a slot the chosen place could upgrade waits for that decision. |
| VG03-08 Overview and boss matrix UI | `Modules/Vanguard.lua` | Dungeons > **Boss matrix (preview)**: readiness, must-haves, risks, a checks table (state as text and colour, with source), a boss table, what would help most, unknowns and assumptions. The tables scroll, so 5 or 40 members use the same layout. |
| VG03-09 Personal checklist and report | same | Copy group report (no names) and Copy with names, shown in a copy box when you press them. Nothing is sent. The Prep checklist (VG02) is the reusable personal template. |
| VG03-10 Context invalidation | `Vanguard/Assess.lua` | Context key: group generation, place, catalog version, role changes, profile revisions, your access answers and boss rules. `Valid` fails at once when any changes, or when the oldest gear reading turns old. The page builds a fresh assessment on every draw, so nothing old is shown. |
| VG03-11 Standalone acceptance | `tests/spec/vanguard_board_spec.lua` | Roster only, then a partial inspect (one answers, one too far), with no peers, desktop or internet; nothing sent. |

## Tests

`tests/spec/vanguard_board_spec.lua` (10 tests): catalog sources and raid unknowns; access AND/OR, unreadable quest, loop and missing node, level gating; readiness all-unknown, range under 80%, point at 100%, monotonic, deterministic, blocked/not established/observed, bad inputs; assessment roles, size, level, boss-level risks, your own boss rule on one boss only, no percent text, no inspect; access answer as a gate; invalidation on role, group, answer and expiry; plan ranking, unknown cost, reserve, enchant waits, advice text; Nexus candidates through the real adapter and `Adapters:All`, none when off, invalid rejected; report without and with names, the copy box; the standalone scenario.

Existing Nexus suites (130 tests) still pass with the new producer.

## Data preservation

No saved dataset is changed or shrunk. New per-character Vanguard settings: `bossNeeds` (your own boss rules). Nothing about other players is saved.

## Live checks still needed

- Boss matrix on a real party before a dungeon (L01, L08): checks, boss rows, report.
- Your own prep steps in the Plan with Nexus on (L09).
- Access with a real key or attunement (L08): the data has none yet.

## Known limits

- No boss mechanics in any installed data, so boss rows differ only by boss level and your own rules.
- No verified raid makeup: raids show level and size checks and unknowns.
- Vendor prices for food, drink, ammo and reagents are unknown (shown as unknown, never free).

# VG06: Verification and release (evidence)

Date: 2026-11-26. Built after VG05 under D28 (gates batched into one final review). The commit that adds this file is the candidate.

Status: **automated audits done; live acceptance (VG06-07), real-client performance (part of VG06-03), class and locale verification (part of VG06-04) and the competitor benchmark (VG06-05) are outstanding and need Gary in game.** Nothing is released: no merge to main, no CurseForge upload (standing rule; release needs Gary's separate approval).

## VG06-01 Security and privacy audit

Automated in `tests/spec/vanguard_audit_spec.lua`:
- **Restricted APIs and events:** no `COMBAT_LOG_EVENT*`, no `CombatLogGetCurrentEventInfo`, and no cast, target, invite, uninvite, subgroup move, chat send, action, macro, raid mark, convert or promote calls in any of the 20 Vanguard files.
- **Saved data with every feature used and debug on** (scan of 10, a manual role, a prep item, a boss rule, an assessment, a named report, the what-if optimizer, a received share, a recorded run with a kill): the saved file has no GUIDs, names or name-realm keys of other players, no inspected item names or links. Your own checklist item and your run (a boss name) are saved, as intended.
- **Secrets:** a secret level or class from the game leaves the member unknown; the assessment and utility coverage still build, with unknowns.

Reviewed by reading (event registrations): Vanguard registers `GROUP_ROSTER_UPDATE`, `PLAYER_REGEN_DISABLED`, `PLAYER_ENTERING_WORLD`, `PLAYER_LOGOUT`, `OTR_COMM` (Outrider's own), `ZONE_CHANGED_NEW_AREA`, `ENCOUNTER_START`, `ENCOUNTER_END`, and `GET_ITEM_INFO_RECEIVED` only while gear is loading; the InspectBroker registers `INSPECT_READY` only while busy. Peer messages: `VPREP` over PARTY/RAID only, opt-in, validated (VG04). Exports and reports: shown in a copy box when you press the button; names only with Copy with names. Advice: Nexus candidates use the existing validator; panel intent only; nothing acts on another player. Diagnostics: counts only (D27).

## VG06-02 Data preservation audit

- The data packs are read, never changed (`vanguard_audit_spec`: every dungeon entry and the spell count are identical before and after the catalog, assessment and utility run).
- New saved data, all your own: Vanguard module settings (activity, minutes, place, access answers, your checklist items, boss rules, assignment notes, sharing choice) and `char.vanguardRuns`. Overflow moves to the Archive; damaged values go to `archiveDamaged`; a newer store is left untouched (VG05 tests). No existing dataset was changed, moved or shrunk by VG01–VG05.
- The one change to a shared file's behaviour: the tooltip inspect cache lifetime went from 15 to 5 minutes (memory only; D27).

## VG06-03 Performance and lifecycle

On the mock (desktop Lua, not the game client): a 40-member assessment p95 under 0.1 s over 20 runs (spec budget for off-game assessment: under 100 ms); 10 drilldowns and row builds under 0.5 s; 50 page redraws add at most 2 timers; a 40-player raid scan keeps at most 4 timers and one request at a time (VG01 load test); 100 canceled scans and 200 roster changes leave nothing behind (VG01). Turning Group check off leaves no handler on any event, no timer, an idle broker, no shared peers, an empty cache and no what-if model.

**Outstanding (L12):** CPU per frame, memory, taint and frame counts in the real client during a scan and with the pages open.

## VG06-04 Class, locale and accessibility

| Area | Status |
|---|---|
| All nine classes have role profiles (VG02 test); hybrids show every kind | unit-tested; live L06 outstanding |
| Utility spells limited to the Forever spellbook data | unit-tested (every counted spell exists in `Data/SpellInfo.lua`) |
| Talent API (Traits tree for inspect) | live probe 2026-11-26 (VG00); level 10+ sample outstanding |
| States shown as text and colour (met, missing, part, unknown; OK, to do, can't tell) | by construction |
| Every button has a tooltip; every page has a help entry and user guide section | `tips_spec`, `help_spec` |
| Localization: English only; strings are in the module, not yet in a locale table | not done (known limit) |
| Keyboard focus: Outrider's form pages use mouse buttons; no keyboard navigation | not done (known limit, existing UI kit) |
| 5 and 40 members: tables scroll; same layout | by construction; live L05 outstanding |

## VG06-05 Competitive scenario benchmark

**Not run: no competitor was tested in game.** Every competitor in `VG00-02_COMPETITIVE_MATRIX.md` stays "untested" (unknown, not zero). Outrider makes no superiority or "first/only" claim. The scenarios to run, when Gary can: 5-player mixed installation scan (vs GearScore Forever, NaowhForever, ForeverDB), personal prep (vs Stormwade Ready, PreppedForever), access and journal (vs DungeonMaster, DFL, Attune), subgroup optimization (vs 1MW, Forevercraft), group prep (vs ForeverDB guild tools, Ishkor's Raid Ready).

## VG06-06 Release regression and docs

- Full suite and exact-SHA CI: see the final review packet (`VG_FINAL_REVIEW_PACKET.md`).
- Docs: in-game Help entries for Group check, Prep checklist, Boss matrix, What-if and Runs; `docs/USER_GUIDE.md` rebuilt; CHANGELOG "Unreleased"; evidence files VG01–VG06; forecast plan.
- Settings, limits, data handling and fallbacks are in each evidence file and the help text.

## VG06-07 Live acceptance and rollout

**Outstanding.** L01–L14 need Gary in game (list in the final review packet). All Vanguard pages stay "preview" and off by default. Release needs Gary's separate approval; nothing was published.

# Outrider phase review packet: Phase 4 (Intelligent planning: Horizon, GearROI, Foresight)

## Implementation submission (Claude)

- **Phase / task IDs:** OI04-01 to OI04-15, gate OI04-GATE.
- **Branch:** `ai/outrider-personal-intelligence`. **Phase base:** `6bd48d5`.
- **Review arrangement (owner, 2026-11-24):** "we will let gpt review when all phases are complete. continue with no stops til the entire spec is complete." This packet is written at the gate, but is reviewed together with Phases 3 to 8 at the end.
- **Client:** WoW Forever 1.60.1. **No live evidence yet for Phase 4.**

### Acceptance evidence table

| Task | Acceptance | Files | Tests | Status |
|---|---|---|---|---|
| OI04-01 | inputs validate; solo excludes group prerequisites; saved preferences migrate; no LLM | Horizon.lua, NexusCore, Adapters, Graph, NexusPage | horizon_spec (6) | MOCK_GREEN |
| OI04-02 | shared travel and rewards once; prerequisites; time as an estimate with a buffer | Adapters, Planner, NexusPage | multiobjective_spec (5) | MOCK_GREEN |
| OI04-03 | feasible closure near the deadline; no impossible long step; nothing automatic | SessionEnd.lua, Horizon, NexusCore | sessionend_spec (6) | MOCK_GREEN |
| OI04-04 | late events, pause and resume, new goal, budget exhaustion, combat; no thrashing | NexusCore, NexusPage | liveadapt_spec (6) | MOCK_GREEN |
| OI04-05 | guaranteed vs chance; eligibility; no DPS claim | GearROI.lua | gearroi_spec | MOCK_GREEN |
| OI04-06 | zero or unknown chance, conditional, independence, group; no guaranteed drop time | GearROI.lua | gearroi_spec | MOCK_GREEN |
| OI04-07 | future items not owned; range or unknown; no circular use | GearROI.lua | gearroi_spec | MOCK_GREEN |
| OI04-08 | an expensive short-lived item below a free one; unknowns; reserve; units | GearROI.lua, Quartermaster (held gold) | gearroi_spec (13 in total) | MOCK_GREEN |
| OI04-09 | no purchase action; dismiss and pin; no price, no provider | GearROI.Cards, Nearby (Gear page) | gearroi_spec | MOCK_GREEN |
| OI04-10 | near-route savings, false positives; unknown facts not alerts; no quest acceptance | Foresight.lua | foresight_spec | MOCK_GREEN |
| OI04-11 | no double counting; no blocking; stale alts flagged | Quartermaster.lua, Inventory tooltip | quartermaster_spec (5) | MOCK_GREEN |
| OI04-12 | no enemy detection or secret maths; missing data labelled; user controls the route | Guardian.lua, NexusPage | guardian_spec (6) | MOCK_GREEN |
| OI04-13 | disconnected edges, map changes, no history, slow mode, wrong build, fallback | Pathfinder.lua (wraps Travel:TimeTo), TravelTimes | pathfinder_spec (7) | MOCK_GREEN |
| OI04-14 | no guaranteed drops or group availability; existing UI intact | DungeonDecision.lua, Dungeons page | dungeondecision_spec (3) | MOCK_GREEN |
| OI04-15 | one primary plus two; no combat interruptions; dismiss and snooze persist; no spam | Foresight.lua, NexusPage | foresight_spec (10 in total) | MOCK_GREEN |

Per-task notes: `docs/reviews/phase4/OI04-*.md`.

### Results at the gate

Full suite: Lua 1372 passed, 0 failed (1302 at the Phase 3 gate). Companion, quality (0 new) and security (0 violations) gates are clean.
The dependency gate flagged one new two-way link: GearROI and the Gear page referred to each other. It is fixed by a section registry in the Hub (`Hub:AddSection` / `Hub:Sections`), and deps is back to 0 new.

### Behaviour changes a reviewer should check

- **Step times:** a step's time now includes its activity estimate, and shared same-map travel is counted once. Time budgets are checked with a 20% margin (OI04-02).
- **Re-plan rate:** automatic re-plans are at least 20 s apart and keep the current first step unless the new one is more than 10% better. The player's own presses re-plan freely (OI04-04). Two Phase 2 tests were updated to wait for the gap.
- **Travel estimates:** `Travel:TimeTo` is now corrected by measured walking. The original is kept as `TimeToRaw`, which trips use for their own estimate (OI04-13).

### Known limits

- **Drop chances:** the gear pack has none, so drops stay "chance unknown" and are not ranked by utility.
- **Reputation:** there is no reputation data for dungeons; the ranking says so.
- **Live checks pending:**
  - the Horizon buttons and session clock
  - the closing steps near the end of a session
  - Foresight's Coming up section
  - the Gear page's "Worth getting?" section
  - the Guardian tags
  - measured route corrections after a few walking trips

## Independent review (ChatGPT fills, at the end of all phases)

| Finding ID | Severity | File/symbol and evidence | Requirement | Correction | Regression test | Status |
|---|---|---|---|---|---|---|
| | | | | | | |

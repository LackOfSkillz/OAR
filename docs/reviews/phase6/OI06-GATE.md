# Outrider phase review packet: Phase 6 (Cartographer and Fellowship)

## Implementation submission (Claude)

- **Phase / task IDs:** OI06-01 to OI06-13, gate OI06-GATE.
- **Branch:** `ai/outrider-personal-intelligence`. **Phase base:** the OI05-GATE commit.
- **Review arrangement (owner, 2026-11-24):** this packet is reviewed with Phases 3 to 8 at the end.
- **Client:** WoW Forever 1.60.1. **No live evidence yet for Phase 6.** The owner's two-client test (OI06-13) is pending.

### Acceptance evidence table

| Task | Acceptance | Files | Tests | Status |
|---|---|---|---|---|
| OI06-01 | ids, fractional coords, time, build, known map; player position never passed off as the NPC's | World.lua, Sightings (build stamp) | world_spec | MOCK_GREEN |
| OI06-02 | Classic and Forever labelled; old builds outdated; unlicensed or unclassified quarantined | World.lua | world_spec | MOCK_GREEN |
| OI06-03 | wrong layer, moved NPC, spoofed source, uncertain coords; audit kept | World.lua | world_spec | MOCK_GREEN |
| OI06-04 | no forecast under the minimum; unknown layer; build change; chance only with enough records | World.lua | world_spec | MOCK_GREEN |
| OI06-05 | unseen apart from unavailable; verified evidence only; no restricted data | World.lua | world_spec | MOCK_GREEN |
| OI06-06 | off by default; consent; schema and size; no account, chat, gold or route | Contribute.lua | world_spec | MOCK_GREEN |
| OI06-07 | malformed, oversized and hostile input rejected without running code; deterministic; rights review | Contribute.lua | world_spec | MOCK_GREEN |
| OI06-08 | offline manual workflow works; external service blocked | docs/COMMUNITY_RELEASE_GATE.md | (document) | DONE |
| OI06-09 | group channels only; sender, scope, size, rate; newer peer safe; nothing without opt-in | Fellowship.lua | fellowship_spec | MOCK_GREEN |
| OI06-10 | unshared member not ready; fairness; no inventory inferred; no invites | Fellowship.lua | fellowship_spec | MOCK_GREEN |
| OI06-11 | revoke stops sharing; roster change drops members; own plans kept | Fellowship.lua, Group plan sub-tab | fellowship_spec | MOCK_GREEN |
| OI06-12 | no code, no actions; bad ids, wrong level, old build rejected or stale | PlanShare.lua | world_spec | MOCK_GREEN |
| OI06-13 | owner multi-client evidence plus mock adversarial fixtures; no public channel | fellowship_spec | fellowship_spec | MOCK_GREEN (live pending) |

Per-task notes: `docs/reviews/phase6/OI06-01_13.md`.

### Results at the gate

- **Full suite:** 1431 passed, 2 failed. Fellowship had no activity line, and the new Sharing and Group plan sub-tabs had no tooltips. Both are fixed, and the activity and tips specs now pass. The full suite runs again at the Phase 7 gate.
- **Quality:** 0 new. **Security:** 0 violations.
- **Deps:** 1 new private read (Fellowship reading `NexusCore.current`), fixed with the public `NexusCore:StepIds`; back to 0 new. The old read pointed at a field that doesn't exist, so plan picks were never shared; that is fixed too.

### Behaviour changes a reviewer should check

- **Sightings build:** sightings now record the game build, and respawn gaps don't cross a build change.
- **Sharing page:** it now has two sub-tabs, Sharing and Group plan.

### Known limits

- **Yards conversion:** precision is compared using a single map-units-to-yards estimate.
- **Contribution export:** it has no page yet; it is reached through `ns.Contribute`.
- **Sightings history:** records from before the build stamp count as another build.

## Independent review (ChatGPT fills, at the end of all phases)

| Finding ID | Severity | File/symbol and evidence | Requirement | Correction | Regression test | Status |
|---|---|---|---|---|---|---|
| | | | | | | |

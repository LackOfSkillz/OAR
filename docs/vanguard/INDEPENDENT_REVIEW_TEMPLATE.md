# Vanguard independent review packet
- Phase / gate:
- Approved baseline SHA / candidate SHA / branch / commit list:
- Exact-SHA CI link and conclusion; local clean-checkout commands and output:
- Microtask matrix (ID, requirement, source path+line, test, result, live status, limitations):
- API capability matrix (build, context, observed result, fallback; no forbidden probes):
- Competitor comparison (version, scenario, source, actual observed result, unknowns):
- Data preservation report (original/final dataset contents, hashes, additions, versioned revisions, archived records, deleted count, unverifiable records, restore test):
- Privacy and threat model report (native vs peer vs persistent data, scope, consent/revoke, malformed/replayed messages, diagnostics):
- One-install mixed-party/raid scenario evidence:
- Readiness math and unknown/critical gate tests:
- Nexus actual-producer integration and action-boundary tests:
- Performance results (hardware/build, p50/p95/max, memory, timers/frames, cancellation):
- Historical and forecast evidence (target, cohort, counts, exclusions, split, metrics, abstention, no readiness/probability conflation; if not applicable state why):
- Outstanding live-client, policy, owner and release blockers:
- Developer recommendation (not independent approval):

Independent reviewer: verify actual diff and CI, sample critical source paths and negative tests, check data-content preservation and regressions against last accepted commit. Record REVIEW_ACCEPTED (scope explicit) or REVIEW_CHANGES with IDs, severity, reproduction and acceptance. Owner approves next phase separately. No automatic release approval.

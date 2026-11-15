# Outrider Intelligence: tasks and gates

Spec: `docs/intelligence/OUTRIDER_INTELLIGENCE_ENGINEERING_SPEC.md` (Gary's handoff, 2026-11-15).
Status marks as in TASKS.md: `[ ]` to do, `[~]` in progress, `[x]` done, `[!]` blocked.
A gate is never ticked on mock tests alone; real-client checks are listed per task.

## AI00 baseline (2026-11-15)

- HEAD `e6deb04` on `p1-foundation`, 19 commits ahead of `main` (`fc4e0e3`, the spec's
  baseline); main's 4 extra commits are pull-request merges only. Release on
  LackOfSkillz/outrider-releases: `build-20261114-1625`.
- `tools/test.ps1`: 489 Lua specs passed, 0 failed, 0 syntax errors; companion 16 tests OK.
  `python -m unittest discover -s tests` in `companion/`: 16 OK (Python 3.12.10).

### Feature matrix (what the AI layer can reuse)

| Area | State | Notes |
|---|---|---|
| WhatNow candidates (8 sources, 6 goals, scores, alternatives, skip) | present | gains `Snapshot()` with candidate ids and grounded targets in AI01-02 |
| Snapshot v1 (`/ride ask`, 50 KiB cap, OTR1 code, logout fallback) | present | v2 metadata added additively (AI01-01) |
| AdviceLoader v1 (4 safe actions, character + snapshot binding, paste) | present | v2 adds answer text, sources, limits (AI02-05) |
| Advisor tab (copy snapshot, paste advice, click rows) | present | shows the v2 answer above the cards (AI02-06) |
| Companion MCP server, store, codes, clipboard, advice writer | present | reused; new `intelligence/` package beside them |
| Journey / Travel trip times | present | used through WhatNow candidates |
| DungeonGuide (rank, next tier, ready check, party share) | present | in WhatNow; own tool later (AI01-04 next sprint) |
| GearScore / Nearby / KitShare | present | through WhatNow gear candidates |
| Professions / SkillUp / ProfTrainer / crafting profit | present | profession tool later |
| Prices (own scans, AH full scan, ages) | partial | price sample age not exposed yet |
| Model provider adapters | missing | AI02-01 (local OpenAI-compatible + fake) |
| Orchestrator, validator, privacy filter | missing | AI01-05/06, AI02-03 |
| Cloud providers, secret store | missing | AI-04 (after review) |
| Seamless in-game bridge | missing, not planned | AI-05 needs Gary's approval and policy review |

## Tasks

### AI-00 Baseline and feasibility
- [x] AI00-01 HEAD, branches, test counts, release state — 2026-11-15: see baseline above
- [x] AI00-02 Feature matrix — 2026-11-15: above
- [x] AI00-03 Run Lua + Python suites — 2026-11-15: 489 + 16 green, no pre-existing failures
- [~] AI00-04 Scrubbed fixtures (SavedVariables, OTR1, Advice) — test fixtures are generated in code (no real names, no account paths); a scrubbed real snapshot fixture still to add
- [x] AI00-05 Probe and transport review — 2026-11-15: no live file access from Lua (SavedVariables only on logout/reload); transport A (OTR1 copy/paste) is the only one used
- [x] AI00-06 Privacy defaults and budgets — 2026-11-15: docs/AI_PRIVACY_AND_TRANSPORT.md
- [x] AI00-07 Architecture, tasks, privacy docs — 2026-11-15: this file, docs/OUTRIDER_INTELLIGENCE_ARCHITECTURE.md, docs/AI_PRIVACY_AND_TRANSPORT.md
- [ ] **AI-G0** gate: baseline reproducible, modules mapped, risks logged, nothing removed (needs Gary's review)

### AI-01 Reliable grounded data
- [ ] AI01-01 ContextEnvelope v2 (Python) + additive Lua export metadata
- [ ] AI01-02 WhatNow `Snapshot()` with candidate ids, why, where, grounded targets
- [ ] AI01-03 Evidence ids, game build and time fields
- [ ] AI01-04 Read-only tool interfaces (`get_pathfinder_candidates` first)
- [ ] AI01-05 Privacy filter and field permissions, sample payload preview
- [ ] AI01-06 Answer validator (unknown ids, wrong snapshot, unsourced coordinates, unknown actions, stale)
- [ ] AI01-07 Adversarial and edge-case tests
- [ ] **AI-G1** gate

### AI-02 First model vertical slice
- [ ] AI02-01 `ModelProvider` + OpenAI-compatible local adapter + fake provider
- [ ] AI02-02 Timeouts, structured errors, bounded retries, token budget, no silent cloud fallback
- [ ] AI02-03 Orchestrator: question -> candidates -> model -> validator
- [ ] AI02-04 Command-line ask: snapshot code in, advice code out (MCP entrypoint unchanged)
- [ ] AI02-05 AdviceLoader v2: answer, plan, sources, limits beside safe actions
- [ ] AI02-06 Advisor tab shows the answer; copy/paste without reload
- [ ] AI02-07 Tests: direct answer, plan, unknown question, outage, schema mismatch, poisoned response, prompt injection, timeout, token cap, clipboard corruption
- [ ] AI02-08 Real client: hunter, warrior and mage (Gary)
- [ ] **AI-G2** gate

### Later phases (not started; need Gary's review of the slice first)
AI-03 (Adventure Plan, Compare, feedback), AI-04 (cloud providers, secure keys, more MCP tools),
AI-05 (seamless transport spike, optional, policy-gated), AI-06 (release quality and adoption).
Task lists for these phases are in the spec, section 11.

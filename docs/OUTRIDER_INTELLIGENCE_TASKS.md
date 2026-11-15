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
- [x] AI01-01 ContextEnvelope v2 (Python) + additive Lua export metadata — 2026-11-15: intelligence/context.py; snapshots carry snapshotId and gameBuild
- [x] AI01-02 WhatNow `Snapshot()` with candidate ids, why, where, grounded targets — 2026-11-15: top 12 on /ride ask only (not at logout), evidence labels per source
- [~] AI01-03 Evidence ids, game build and time fields — 2026-11-15: local:<candidateId> evidence ids, labels observed/community/inferred; price sample ages not yet exposed
- [~] AI01-04 Read-only tool interfaces — 2026-11-15: candidates come through the snapshot code; an MCP tool `get_pathfinder_candidates` is next sprint
- [~] AI01-05 Privacy filter — 2026-11-15: names, realm, guild and other players never sent; escapes stripped; bounded. Payload preview UI is next sprint
- [x] AI01-06 Answer validator — 2026-11-15: companion keeps only snapshot candidate ids and rebuilds cards; addon re-checks ids, exact waypoint targets, snapshotId binding, action whitelist
- [x] AI01-07 Adversarial and edge-case tests — 2026-11-15: 19 companion tests + 3 Lua specs (poisoned picks, escapes, oversize, unknown ids, moved waypoints, wrong snapshot, empty data, corrupt codes)
- [ ] **AI-G1** gate

### AI-02 First model vertical slice
- [~] AI02-01 Provider interface, OpenAI-compatible adapter, fake — 2026-11-15: tested against a real local HTTP server; NOT yet against Ollama/vLLM (none on this PC)
- [x] AI02-02 Timeouts, errors, retries, budget — 2026-11-15: 60 s timeout, 1 retry on connect errors, 800 output tokens, 12k-char context, loopback-only default, redirects refused, no fallback provider
- [x] AI02-03 Orchestrator — 2026-11-15: deterministic fallback (2 per kind) when the model is off, fails or picks nothing valid
- [x] AI02-04 Command-line ask — 2026-11-15: python -m outrider_companion.intelligence.ask (clipboard or files); run.py/MCP unchanged
- [x] AI02-05 AdviceLoader v2 — 2026-11-15: answer block (headline, summary, limits, sources), candidate-bound cards; schema 1 unchanged
- [~] AI02-06 Advisor tab shows the answer — 2026-11-15: answer card above the list; paste without reload in specs and tools/ask_demo.lua; free-text question box in game is next sprint
- [x] AI02-07 Tests — 2026-11-15: all listed cases covered except cancellation (the CLI call is synchronous)
- [~] AI02-08 Real client — 2026-11-15: offline route with Gary's real data for Khreos (hunter) and Fingerwiggle (mage): snapshot -> answer -> paste -> 3 grounded cards, 0 errors (tools/ask_demo.lua). Needs Gary: in game, and a local model
- [ ] **AI-G2** gate

### AI-03 Adventure Plan, Compare, and knowledge (Gary said go, 2026-11-15)
- [x] AI03-01 Deterministic plan evaluator — 2026-11-15: intelligence/planner.py (trip + typical time per kind, labelled estimates, unknown trip times flagged)
- [x] AI03-02 Time budget and goal-aware planning — 2026-11-15: budget from the Advisor's minutes box or the question; urgent first, same zone together, dungeons last; what doesn't fit moves to "later" with a note
- [x] AI03-03 Provenance and uncertainty in the UI — 2026-11-15: source chips in text and colour, evidence tooltip per card, "Not checked" line, estimates labelled
- [x] AI03-04 Compare — 2026-11-15: two steps side by side (time, label, group) from Outrider's data only, shown under the answer
- [x] AI03-05 Feedback — 2026-11-15: Useful / Wrong data / Done per card, local; Wrong data and Done hide the step for a day; the 20 newest go to the companion
- [x] AI03-06 Goal profile and plan state — 2026-11-15: goal per character; plan progress ("1 of 3 done") from Done feedback
- [x] AI03-07 Tests — 2026-11-15: budgets, ordering, later, compare (unknown ids refused), feedback, plan rows validated in the addon
- [ ] AI03-08 In-game usability review (Gary, screenshots at small and large window sizes)
- [ ] **AI-G3** gate

Also done early from AI-04: AI04-03 MCP tools `get_pathfinder_candidates`, `get_candidate_explanation`,
`plan_to_clipboard` (an MCP client like Claude Code answers as the model; Outrider validates and builds the cards).

### AI-04 Cloud provider flexibility and MCP robustness (Gary said go, 2026-11-15)
- [~] AI04-01 Native cloud adapters — 2026-11-15: Anthropic (Messages API, server-side fallback on refusals), OpenAI, Gemini; raw HTTP (the companion installs nothing); tested only against local stand-in servers, never a real provider
- [x] AI04-02 Secrets, consent, preview, spend caps — 2026-11-15: keys in Windows Credential Manager (real round trip verified), env override, never printed; cloudConsent gate; `ask --preview`; daily token cap with usage.json
- [x] AI04-03 More read-only MCP tools — 2026-11-15: pathfinder candidates, candidate explanation, gear, dungeons, gold, rare evidence; module data cleaned (escapes, person fields, bounds); old tools unchanged
- [!] AI04-04 External reference MCP (warcraftforever.com) — blocked: needs Gary's OK to contact an outside server and a license/accuracy review
- [x] AI04-05 Offline answers and tool errors — 2026-11-15: deterministic fallback on every failure kind incl. budget and consent; errors never become answer text
- [x] AI04-06 Diagnostics — 2026-11-15: `doctor` (settings, key stored yes/no, consent, tokens today; `--check` pings local servers only); tests for wrong key, wrong model, quota, overloaded, TLS, network off, server down
- [ ] AI04-07 Benchmark 25 questions across providers — needs Gary's providers and his OK to spend
- [ ] **AI-G4** gate

### AI-05 Seamless transport feasibility (optional)
- [x] AI05-01 Feasibility matrix — 2026-11-15: docs/intelligence/TRANSPORT_FEASIBILITY.md (A kept, B built, C1/C2 not recommended)
- [!] AI05-02..06 Bridge prototype and checks — blocked: needs Gary's explicit approval and a policy review; the spec prefers shipping without
- [ ] **AI-G5** gate — not attempted

### AI-06 Release quality, polish, adoption
- [x] AI06-01 Onboarding — 2026-11-15: "how it works" help in the Advisor tab, user guide (docs/intelligence/USER_GUIDE.md)
- [x] AI06-02 Card polish — 2026-11-15: source chips, tooltips, plan progress, snapshot age status; desktop Ask Outrider window (transport B)
- [~] AI06-03 Full suite + adversarial harness — 2026-11-15: 498 Lua specs, 120 golden scenarios, contract fixtures, -RequirePython; clean-VM install/upgrade/uninstall not done
- [x] AI06-04 Threat model, static checks, redaction — 2026-11-15: THREAT_MODEL.md, test_security.py; no request logging exists to redact
- [x] AI06-05 Documentation — 2026-11-15: user guide (models, privacy, FAQ, troubleshooting, limits), companion README, privacy doc
- [~] AI06-06 License review — 2026-11-15: LICENSE_REVIEW.md; Q3 is Gary's decision
- [ ] AI06-07 Family beta (Gary, with consent)
- [ ] AI06-08 Tag, package, publish (Gary's approval)
- [ ] **AI-G6** gate — see docs/intelligence/RELEASE_CHECKLIST.md

### Later phases (not started)
AI-05 (seamless transport spike, optional, policy-gated), AI-06 (release quality and adoption).
Task lists for these phases are in the spec, section 11.

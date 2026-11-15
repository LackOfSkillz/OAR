# Outrider Intelligence: release checklist and gate report (2026-11-15)

Gate status per spec section 13: **pass**, **fail** or **not verified**.
Silence is never a pass.

## Gates

| Gate | Status | Evidence / what's missing |
|---|---|---|
| AI-G0 baseline | pass (mock) | docs/OUTRIDER_INTELLIGENCE_TASKS.md baseline; no feature removed (all prior specs green) |
| AI-G1 grounded data | pass (mock) | 0 malicious/invalid outputs accepted (golden + adversarial tests); binding kept; v1 fixtures accepted |
| AI-G2 first slice | **not verified** | Route proven offline with real saved data (hunter, mage); needs a real model and the real client |
| AI-G3 plan/compare | **not verified** | Planner, compare, feedback built and tested; needs Gary's usability review at 860x520 and 1400x1000 |
| AI-G4 providers | **not verified** | Local + 3 cloud adapters tested on stand-in servers; no real provider call yet; external MCP blocked |
| AI-G5 bridge | **not attempted** | Feasibility written; needs Gary's approval and a policy review (docs/intelligence/TRANSPORT_FEASIBILITY.md) |
| AI-G6 public release | **not verified** | Needs the items below |

## Release targets (spec 12.2)

| Target | Status |
|---|---|
| 0 unsupported ids/coordinates shown as valid | pass in 120 golden scenarios + adversarial tests |
| 0 unauthorized actions, executable Lua, input automation | pass (golden, test_security) |
| 0 cross-character leaks | pass (golden family-privacy, MCP tool cleaning) |
| 0 false citations accepted | pass (golden) |
| >= 95% recommendations with evidence or explicit uncertainty | not verified: needs human review (every card carries a source chip) |
| >= 90% useful or honest abstention | not verified: needs blind human review of the scenarios |
| 100% v1 snapshot/advice compatibility | pass (Lua specs, contract fixtures) |
| 100% baseline tests with AI off | pass (498 Lua specs; AI is opt-in) |
| 0 new continuous polling loops | pass (no timers added; WhatNow logs only on change; work happens on Ask) |
| p50/p95 response times local vs cloud | not measured (no real model available) |
| Clean installer / rollback | partly: installer rollback checks pass (tools/test-installer.ps1); companion is not in the installer yet |

## Before a public release (Gary)
1. In game, one full restart, then the checklist in docs/intelligence/SPRINT1_REPORT.md
   on a hunter, warrior and mage, plus one character with sparse quest data.
2. Real-client acceptance (spec 12.3): no blocked-action popup, taint, impossible
   waypoints, empty cards or UI overflow; after /reload, logout, restart;
   with no model, model down, no internet, wrong key, stale advice.
3. One real model answer: local (Ollama/LM Studio/GX10) or a cloud key; measure times.
4. Decide Q3 (license) and whether the companion ships in the family installer.
5. Family beta with consent; fix severity 1-2 issues.
6. Then `tools/publish.ps1` (it runs the full suite with Python required).

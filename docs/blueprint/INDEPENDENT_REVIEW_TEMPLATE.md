# Outrider independent phase review packet

## Implementation submission (Claude fills)

- Phase / task IDs:
- Repository and development branch:
- Base SHA / exact candidate SHA:
- Diff link / CI run URL and head SHA:
- Client version / build / ruleset / test date:
- Scope implemented / intentionally excluded:
- Crosswalk to prior TASKS/I2/XP60 requirements:
- Policy/consent/rights decisions and references:

### Acceptance evidence table

| Task ID | Acceptance criterion | Changed files / symbols | Tests and fixtures | Command, exit code, counts | Live evidence reference | Status / limitations |
|---|---|---|---|---|---|---|
| | | | | | | |

### Required attachments / references

- Exact diff and summary of why each change was needed; migration and rollback tests; dependency and public-interface changes.
- Focused and full test command output, lint/coverage/complexity where applicable, exact CI SHA, fixture provenance. Redact credentials and private user data.
- Negative tests: wrong character, stale/unknown/secret values, malformed inputs, missing APIs, permissions, combat, disable, duplicate events, locale, data/license scope and failure paths where applicable.
- Performance baseline vs candidate on comparable conditions, raw sample counts, p50/p95/max, memory and timer counts; live evidence and unsupported measurements clearly separated.
- Owner test steps and results, build/date, self-collected permitted logs; screenshots only with separately approved D19 development UI workflow.
- Documentation changes: user, API, data contracts, events, settings, failures, privacy, source provenance and changelog.
- Known defects, risks, unresolved assumptions, blocked tasks, proposed mitigations and rollback.

## Independent review (ChatGPT fills after Gary submits branch/SHA)

Review scope: source-only / automated / live evidence reviewed. Verify exact candidate SHA; inspect actual changes and tests, CI status and policy compliance. Do not equate a claimed test run with independent execution. Check task-by-task acceptance and missing edge cases; assess test quality, architectural reuse, UX, math, performance, security and data provenance. Record what could not be reproduced. Review does not confer Blizzard approval or distribution rights.

| Finding ID | Severity (P0-P3) | File/symbol and evidence | Requirement violated | Required correction | Regression test | Status |
|---|---|---|---|---|---|---|
| | | | | | | |

Decision: `REVIEW_CHANGES` / `REVIEW_ACCEPTED` (scope stated) / `BLOCKED`.

- Accepted task IDs and evidence:
- Unaccepted / live-pending task IDs and required evidence:
- Reproduction limitations:
- Next allowed phase or required resubmission:
- Reviewer date and exact SHA:

## Product owner decision (Gary)

- Live evidence approved / outstanding:
- Explicit policy decisions or deviations (with rationale):
- Approve next phase / request revisions / defer with feature disabled:
- Merge or publication approval, if separately requested:

A new commit after review requires re-review of affected changes. Keep previous review records intact. Never advance a blocked release gate on the strength of a green mock suite alone.

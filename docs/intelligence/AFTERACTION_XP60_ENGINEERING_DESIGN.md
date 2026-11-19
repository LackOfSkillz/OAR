# Outrider Intelligence 2.0 — AfterAction XP60 Next-Session Planner

**Status:** Engineering design, NOT implemented or game-certified.
**Date:** 2026-11-18
**Target branch:** ai/intelligence-2.0
**Scope:** Maximize character experience earned within a strict 60-minute next-play-session budget.
**Policy:** D18 remains controlling: advice only, no automated gameplay, no live external-game bridge, and no writing to WTF SavedVariables.

## 1. Product contract and audience

One question drives the system: **"Given this character's actual history, current opportunities and exactly 60 minutes, what's the best achievable XP plan?"**

The output is a short, evidence-backed **plan**, not a beginner guide, ability tutorial, quest-list dump, or achievement congratulation.

- Expert-respectful: explain the **specific optimization** (route clustering, eliminated backtracking, better measured XP rate), not generic advice ("Do quests to level").
- No forced novelty: if the user's current strategy is competitive, say **"Your current route looks strong; here's how to continue it."**
- No invented numerical uplift. If data cannot justify an improvement percentage, omit the percentage and explain the unknown.
- No unsolicited class or rotation lecturing. The AI references known capability constraints only when they materially change the feasible plan.
- Show ONE recommended 60-minute plan and at most TWO distinct alternatives. No automatic gameplay, purchasing, spells or secure actions.
- Treat "Already knew", "Not interested", "Wrong", "Tried it", "Useful" and "Completed" as bounded personalization/suppression feedback, never a reason to argue.

The objective is *expected XP earned before minute 60*, with reliability, risk and source freshness constraints. Because the horizon is fixed at one hour, maximize total XP within 60 minutes is equivalent to maximize next-session XP/hour. Do not optimize an isolated quest's XP-per-minute while ignoring travel, downtime or a turn-in that occurs after minute 60.

## 2. Existing verified code to reuse (do not replace)

- **Advisor/Snapshot.lua** already writes account-wide Outrider_Snapshots, records an automatic logout snapshot, caches in-session location/gear/gold/level because logout APIs can return empty data, and caps snapshots at 50 KiB. It currently preserves the previous askedAt for ordinary logout snapshots; this is NOT an adequate binding for a new next-session plan.
- **Core/DB.lua** already stores per-character settings and history in account-wide Outrider_DB and records logout metadata. Never make the companion edit these files. Respect DB safe mode and migrations.
- **Modules/WhatNow.lua** supplies candidate ideas; its generic benefit score is NOT an XP prediction or a substitute for measured XP.
- **Modules/LevelRoutes.lua** models user-controlled steps, requirements, quest completion and source-aware route instructions.
- **Modules/Travel.lua** estimates walking, taxi and transport travel over a graph; until calibrated, these are estimates, NOT observed time.
- **Modules/Journey.lua, QuestTracker, QuestRewards, QuestInfo, NPC packs, GearScore, Talents** may provide opportunities and eligibility but must expose provenance and exact build/pack compatibility.
- **Advisor/Advice.lua + AdviceLoader.lua** already allow data-only, preloaded, action-whitelisted recommendations. Preserve the v1/v2/v3 contracts; define a separately validated next-session plan envelope, rather than trying to smuggle numeric predictions into model-authored action strings.
- **Companion intelligence/context.py, schemas_v3.py, coach_v3.py** already implement privacy-bounded, source-bound model interaction; model participation is optional.

Existing project verification: docs/PROBE_RESULTS.md records a working SavedVariables round trip on the Forever build tested 2026-11-11; docs/FOREVER_CONSTRAINTS.md C18 documents saves on /reload, logout and client exit. Re-probe after client updates.

## 3. Safe session evidence collection

Create an **opt-in** native add-on module SessionXP (default OFF for the initial development build; enable after user preview/consent), retaining numeric aggregates rather than raw event or combat logs.

### Required inputs (minimal viable)

| Evidence | Capture method | Confidence / validation |
|---|---|---|
| Session character, class, level, faction, build | Current readable character metadata at login and on level changes | observed; private identity retained only in local per-character binding |
| Session and active-play duration | login/exit times, idle/AFK and loading transitions when readable | observed wall-clock; active-time provisional if AFK/load status unavailable |
| XP before/after and each XP gain | safe XP APIs such as UnitXP/UnitXPMax, supported XP update and level-up events | observed net XP; unknown if secret/missing values or ambiguous rollover |
| Quest IDs, known objectives and turn-ins | supported quest-log and QUEST_TURNED_IN events; no combat log | observed progress, only when API confirms it |
| Last known character position and zone transitions | safe C_Map position sampled on zone change and at a bounded interval if user enabled | observed map/zone, coordinates only when available/readable |
| Candidate quests and dependencies | existing quest log, original route data and pack metadata | eligible if currently known; static pack values are labeled sourced/community |
| Player's feasible transport options | Travel's per-character known taxi points, route edges and hearth availability where verified | observed unlocks; travel seconds estimated unless timed |
| Last-session baseline XP/hour | valid observed XP divided by exact recorded denominator | observed XP; baseline rate labeled wall-clock or active |
| Combat/readiness constraints | readable level, equipment, resource readiness and player-selected role | never infer an unknown spell, talent or secret combat state |
| Session history | bounded prior XP segments and previous recommendation outcome | observed aggregate; time-sensitive; per-character |

### Important timing rules

- Use monotonic elapsed seconds **during one running session**; persist wall-time anchors for reload/relogin continuity. Mark disconnected, crash-truncated, clock-skewed or incomplete records instead of inventing missing time.
- Count **wall-clock play minutes including travel, loading, queueing, combat, downtime, and turning in quests** for the next-session horizon. Separately report optional "active XP/hour" with its distinct denominator so the display doesn't hide downtime.
- On level-up, compute XP gain as previous remaining XP plus new XP only when the previous level cap, transition and following sample are verified. Unknown intermediate caps => mark the rollover ambiguous; do not make up the missing XP.
- Absolute XP from a safe API can be measured, but the **cause** of each increment may not be known. Attribute to a quest turn-in only with a reliable event association; otherwise mark the segment "XP observed, source unclassified".
- Do not claim exact kill rate, mob XP, walking time or quest experience from just a final logout screenshot. Source-specific time estimates require observed samples or verified quest records.
- AFK, rested XP, group size, boosts, deaths, competition and ability changes are confounders. Record supported flags; reduce confidence, compare like-for-like sessions and do not claim causal certainty.
- The collector MUST NOT inspect the combat log, protected memory, screenshots, or other players. Unknown/secret values remain unknown.

### Compact, per-character data contract (illustrative, additive)

    session = {
      schema = 1,
      sessionId = "opaque-generated-id",
      characterBinding = "local-only",
      gameBuild = "observed-build-token",
      startedAt = 1795000000,
      endedAt = 1795003780,
      final = true,
      durationSeconds = 3780,
      activeSeconds = nil,
      levelStart = 20,
      levelEnd = 21,
      xpEarned = 18200,
      xpVerified = true,
      xpRateBasis = "wall",
      zones = {
        { mapID = 123, durationSeconds = 1400, xpEarned = 6500, observed = true }
      },
      questsTurnedIn = { { questID = 1234, atOffsetSeconds = 900 } },
      currentQuestIds = { 1235, 1236 },
      lastLocation = { mapID = 123, x = 0.42, y = 0.58, observed = true },
      flags = { incomplete = false, restedUnknown = true, groupUnknown = true },
      sources = { xp = "UnitXP", quest = "QUEST_TURNED_IN", route = "Travel" }
    }

Numbers and map/quest IDs in the example are **illustrative**, not actual game content. Keep addon SavedVariables bounded: target <=40 KiB per character for the compact recent-session aggregates, <=20 sessions or 30 days (whichever is smaller), and <=50 KiB for the already existing outbound snapshot. Reject excessive field lengths and nesting. If size caps are approached, aggregate older sessions rather than silently dropping the latest trusted session.

## 4. Post-session pipeline (no live bridge)

1. **During play:** Outrider keeps bounded telemetry in memory using permitted APIs and low-overhead events. No external app reads game memory or watches the screen; the addon does not transmit anything.
2. **On logout or /reload:** Save an immutable session checkpoint plus current source-validated opportunities into existing Outrider SavedVariables. On /reload, checkpoint is provisional; do not treat an in-progress character session as finished. Read last-good in-session cached location/level/gear/XP, because logout APIs can be empty or stale.
3. **Desktop file observer:** An explicitly enabled local companion watches only the configured Outrider SavedVariables path under WTF. It waits for a stable, complete file (two consistent reads + safe parse), reads it **as data without executing Lua**, enforces file size/depth/schema caps and deduplicates by sessionId + content digest. Never edit WTF.
4. **When WoW is not running:** Finalize analysis in a local planner. A change caused only by /reload may be analyzed as a draft but must not cause in-game file replacement while WoW is running. If closed-game detection is uncertain, generate a preview and hold delivery.
5. **Plan generation:** Deterministic engine derives eligible candidates, estimates routes/time/XP, compares the baseline, selects a robust plan and validates every number and source. Optional LLM produces short human-friendly reasoning or picks among *prevalidated* plan IDs.
6. **Delivery:** Write a strict **data-only** validated next-session envelope using the existing approved Advisor/Advice.lua writer and only while the game is closed. A player can alternatively copy an OTR1 plan code. The normal next game launch loads advice; no side-channel, injected runtime code, automatic /reload or control of the game.
7. **On next login:** Bind advice to the correct character, unique source session and client build. Check level, quest eligibility and location; stale/incompatible steps must be suppressed or marked "Recheck". A quiet UI entry offers **"Your next hour is planned"**. The player chooses whether to open or use it.

Important migration requirement: legacy snapshot askedAt persists between logout snapshots in current code. Add **basedOnSessionId**, **snapshotDigest**, **planCreatedAt**, **maxAgeSeconds** and **characterBinding** to a NEW versioned next-session envelope. Do not use the legacy askedAt alone as an integrity/freshness check. Do not break current Ask/copy/paste or preloaded advice flows. A preloaded plan is never allowed to create a new waypoint from unverified model coordinates.

## 5. Candidate planning contract

For each eligible step or sequence:

    {
      "candidateId": "source-bound-opaque-id",
      "kind": "quest_cluster | grind | turn_in | dungeon | travel | preparation",
      "requiredQuestIds": [1234],
      "verifiedPrerequisites": ["quest_is_active", "character_can_access_zone"],
      "sourceEvidenceIds": ["session:123", "questdb:1234", "travel:edge45"],
      "xpReward": { "value": null, "origin": "unknown" },
      "xpFromFights": { "low": null, "mid": null, "high": null },
      "timeSeconds": {
        "travel": 520, "fight": 950, "objective": 430,
        "turnIn": 140, "waiting": 0, "buffer": 120
      },
      "uncertainty": "medium",
      "manualActionOnly": true
    }

Unknown XP reward or unknown turn-in time must remain **null**, not zero masquerading as a measured fact. If a reward/step cannot be reliably evaluated, it may appear as a qualitative alternate but must not receive a numeric advantage score.

### Candidate eligibility — enforce before optimization

- Correct current class, level, faction, zone access, role constraints and **quest dependency chain**; never send a player to a quest they have already completed or cannot accept.
- Use verified known flights, mounts/teleports and route dependencies; unknown taxi links are not assumed available.
- Exclude one-time rewards already earned, quest objective overcount, mutually exclusive quest choices and dungeon/group plans with unknown availability from **guaranteed** totals.
- Dungeon queue/grouper options must include actual or confidence-labeled waiting time; never assume an instant group.
- Rested XP and temporary boosts must be factored only when the game exposed them safely and current effects are known.
- Class/role advice may affect **feasibility and expected duration** but must not invent an ability rotation or infer a talent from unknown client values.
- Safety: candidate action is strictly informational/Go-to-existing-Outrider-panel/validated waypoint; **no cast, target, buy, queue, loot or movement commands**.

## 6. Optimization objective and algorithm

**Horizon:** 60 real-world minutes (3,600 seconds), including travel, queues, downtime and rewards turned in; no undisclosed overtime.

For a feasible sequence of tasks P:

    T(P) = travel(P) + fight(P) + objectives(P)
         + accepting_and_turning_in(P) + waiting(P) + prep(P)
    XP60(P) = XP actually expected to post by second 3600 of P
    Primary objective: maximize robust_expected_XP60(P)
    Displayed XP/hour = XP60(P) / 1 hour

A quest whose reward requires a hand-in at minute 62 does **not** receive that reward in XP60; its partial progress can be shown separately as "progress toward next time", not counted as earned XP. Avoid double-counting shared mobs, quests, route segments or turn-ins.

### Deterministic implementation stages

1. **Build baseline** from comparable observed recent sessions (same level band, rest/boost flags where known, solo/group, travel mode). Show both **last-session wall-clock XP/hour** and **confidence**; never compare the next plan against a deceptively high active-only rate.
2. **Generate candidate clusters**: same-zone/nearby quest objectives, naturally linked quest chains, efficient completed-objective turn-ins, verified grind routes and dungeon options only when group/queue evidence exists. Shared kill/loot requirements must be deduplicated; no invented locations.
3. **Estimate costs** using Travel graph + observed per-zone / objective timings when available. Use range estimates [optimistic, typical, pessimistic], not a fabricated second-perfect forecast. Uncalibrated routes are marked inferred.
4. **Search ordered plans** using a bounded beam search (configurable 100–200 partial states; maximum 20 candidate clusters and 12 tasks in a route), carrying location, remaining quest requirements, XP already counted, time budget, source freshness and completion state. Beam width is a performance control, not a guarantee of global optimality.
5. **Apply uncertainty**: maximize realistic *risk-adjusted* XP, e.g. estimated typical XP minus an uncertainty penalty backed by ranges. A player's selected "reliable" setting favors higher lower-bound XP. Never assign invented probabilities.
6. **Reserve a 3–5 minute buffer** for variable travel/turn-ins when timing evidence is uncertain. Only display a plan as "fits in 60 minutes" if the estimated schedule + required buffer <=3,600 seconds; otherwise truncate to the last realistically completable reward.
7. **Compare against continuing the current route**. If another option doesn't beat the observed/prior route by a material, supported margin, recommend **continuing** rather than fabricating a superior plan.
8. **Return 1 + up to 2 alternatives**: (A) best supported expected XP; (B) reliable/low-variance XP; (C) close-to-current-location / low-travel. Label uncertainty; alternatives must be genuinely different.

### Numeric claims and usefulness suppression

- Default significance floor: at least **10% estimated improvement** over a **comparable, observed** baseline *and* a credible expected difference beyond the known uncertainty range. The percentage is never shown otherwise.
- If evidence is sparse, display a "promising route to investigate" without a made-up XP/hour or percentage.
- If the candidate includes community quest data, explain that its location or XP reward may differ on Forever; mark uncertain.
- "Already know" feedback suppresses repeat explanations and redundant discoveries. Reissue only if expected gain, quest status, level, route availability or source evidence changes materially.
- "Wrong" forces revalidation; "Not interested" mutes the class of suggestion; "Useful" improves preferences but cannot override safety, eligibility or stale facts.
- Never use a model confidence percentage. Evidence labels are observed, verified, community, inferred, unknown.

## 7. Player interface — default: concise, expert-friendly

### Login state (closed unless player requests it)

A quiet entry in Outrider Hub / Radar:

    OUTRIDER — NEXT SESSION
    Your 60-minute XP plan is ready
    Based on last session • Last analyzed 8:42 PM
    [View plan] [Keep current route] [Dismiss]

No modal takeover, autoplay, recurring toaster, combat interruption or permanent overlaid timer. If analysis was unavailable: "No new plan. Your existing route remains available." No fake recommendations.

### Opened plan (illustrative, NOT real character estimates)

    YOUR NEXT 60 MINUTES                  XP FOCUS
    Last session: 18,000 XP/hour (observed, 67 min)
    Proposed: 22k–25k XP earned in 60 min (estimated, medium confidence)
    Source: previous session + available quest objectives + travel graph

    00–08   Go to shared-objective quest area
    08–28   Complete objectives A + B together
    28–45   Finish objective C while already nearby
    45–53   Return and turn in earned quest rewards
    53–60   Finish nearby verified XP opportunity / buffer

    WHY THIS ROUTE?
    Combines objectives with shared travel and two turn-ins.
    The previous route involved more zone changes.
    [Show evidence] [Start route] [Already know] [Not interested]

    ALTERNATIVES
    Reliable route: lower predicted variance, less travel
    Stay local: lower commitment, fewer map changes

The illustration's numeric values are not grounded in a real character and must never be shipped as a default promise. In actual output, every XP estimate carries its range/provenance; omit percentages if baseline comparability or uncertainty makes them misleading.

### Behavior

- Expandable Why? shows only the **non-obvious change and supporting observation**: e.g. "This replaces two zone transitions with one" instead of "Questing grants XP".
- "Start route" opens existing Outrider LevelRoutes/Travel/waypoint UI; the user still performs all movement/combat/objectives.
- Always show **time left at decision point, source-age badge, build match and eligibility freshness**.
- If a planned quest is complete/unavailable, quietly replace/remove that step from the in-addon deterministic portion using currently available legal events; the desktop AI is *not* silently called again.
- First-run screen shows a one-time, terse explanation of which measurements are collected, why, and where they remain stored. No unsolicited tutorial on how to play.
- "Why not my current route?" compares realistic XP within 60 minutes and travel/uncertainty, not total quest count.
- If plan data is stale or for another character, show a neutral "Plan needs a new session snapshot" and keep existing normal addon features.

## 8. Component architecture

### Addon (Lua)

- **Intelligence/SessionXP.lua** — event-driven, bounded XP/session/zone measurement, no COMBAT_LOG_EVENT_UNFILTERED or frame polling. Respect Compat.IsSecret, safe-mode, versioned migrations and 50 KiB snapshot envelope.
- **Advisor/Snapshot.lua** — include a versioned additive after-action summary built *before* PLAYER_LOGOUT invalidates API values; new session-bound snapshot ID, separate from askedAt. Do not erase last good profile/position/quests on logout failure.
- **Intelligence/NextSessionPanel.lua** — quiet login state, sourced timeline, user feedback, in-addon validated Go actions. No automatic UI pop or game control.
- **Advisor/AdviceLoader.lua** — add independently validated next-session plan contract (versioned; retains v1/v2/v3 compatibility); authorize a step only from the stored trusted source record, never model coordinates.

### Desktop companion (Python)

- **intelligence/session_reader.py** — read-only, stable-file watcher; parse Lua data without executing Lua; path allowlist, size caps, dedup by sessionId/digest. Do not persist raw character identities in cloud prompts.
- **intelligence/xp_baseline.py** — XP level rollover accounting, comparable baseline XP/hour, AFK/rested confounders and source provenance.
- **intelligence/xp60_planner.py** — candidate eligibility, quest cluster dedup, travel/time ranges, 60-minute constraint, bounded beam search, confidence/risk controls, current-route baseline.
- **intelligence/next_session_delivery.py** — data-only Advice.lua generation through approved writer, *only after confirming game closed*, or explicit copy/paste export; safe schema/binding/TTL.
- **intelligence/next_session_explainer.py** — optional source-grounded one-line AI phrasing; defaults to deterministic templates. Existing local/cloud provider consent/budget rules apply.

### Data contract and trust boundary

    "nextSessionPlan": {
      "schema": 1,
      "basedOnSessionId": "opaque-session",
      "snapshotDigest": "sha256",
      "characterBinding": "local-only",
      "createdAt": "timestamp",
      "expiresAt": "timestamp",
      "goal": "xp",
      "budgetSeconds": 3600,
      "baseline": {"xpPerHour": null, "basis": "wall", "observed": false},
      "xpRange": {"low": null, "typical": null, "high": null},
      "steps": [{"candidateId": "trusted-id", "plannedStart": 0,
                 "plannedEnd": 480, "evidenceIds": ["trusted-evidence"]}],
      "risks": ["community quest data"],
      "needsRecheckAtLogin": true,
      "actions": []
    }

A model sees a sanitized view with anonymous character token and validated candidate IDs, not player/realm/guild/chat names, local paths, coordinates suitable for forging a waypoint, or raw account settings. Model output may **choose prevalidated plan IDs and explain**; only the deterministic engine computes the XP/time bounds.

## 9. Test and acceptance gates

### Automated fixtures (must be reproducible; no live-data guesswork)

1. Two XP updates, one level-up and a correct XP rollover.
2. Missing level cap during rollover -> unknown gained XP, never fabricated.
3. 60-minute plan includes travel, queue, turn-in and buffer in the same budget.
4. Quest completion at minute 61 gives **zero XP counted** inside the hour.
5. Shared quest objectives/grind kills are not counted twice.
6. Quest already completed or ineligible for class/faction is excluded.
7. Unknown taxi node/missing quest pack -> no infeasible navigation.
8. Incomplete or crashed last session -> clearly marked partial; baseline uncertainty.
9. AFK/rested/group/boost confounders do not produce unjustified uplift claims.
10. Sparse data returns "continue current route" or unquantified candidate; no fabricated XP/hour.
11. Similar observed routes compared by wall-clock denominator, not active-only denominator.
12. "Already know"/"Not interested" suppression persists, unless relevant evidence changes.
13. Bound per-character histories; forced malformed or oversized SavedVariables fail closed.
14. Stable-file watcher ignores partial writes; parsing never executes arbitrary Lua.
15. While game runs, watcher never modifies AddOns or WTF; no auto-reload.
16. Plan for wrong character, stale session ID or outdated client/pack is rejected.
17. Injected model-supplied item/spell/map/quest IDs and executable actions are rejected.
18. No model, no internet and no credentials still produce a deterministic plan if facts permit.
19. The safe model never gives advice based on unavailable or secret APIs.
20. Measured incremental addon memory, event cost and planner runtime meet performance budgets with large quest lists; no frame-bound continuous loops.

### In-game owner acceptance

- Save/log out and confirm **measured** XP/hour matches manually checked observed XP and elapsed wall time.
- Verify a plan is actually generated after logout and is visible *at the next launch*, without copying or pasting when using the preloaded file path.
- Repeat with /reload (provisional checkpoint), full client exit, and a crash/truncated session; no corrupt history or unsolicited file update.
- On at least Warrior, Druid and Hunter, compare planned 60-minute earned XP and travel duration against actual gameplay. Extend to nine classes before broad beta.
- Judge 25 example recommendations against a blinded "continue my usual route" baseline for actual player value; require source correctness, helpful specificity, minimal clicks and **no generic lectures**.
- Check D18 safety, addon taint, source privacy, saved-file compatibility, and explicit user release approval.

## 10. Implementation order and release criteria

**XP60-00 — collection contract:** schemas, safe event probes, verified XP samples, XP rollover, ring-buffer/retention and privacy/consent.

**XP60-01 — offline analysis:** SavedVariables read-only watcher, incomplete-session handling, dedup, baseline XP/hour and consistency tests.

**XP60-02 — route optimization:** source-aware quest eligibility, travel costs, shared objectives, robust 60-minute bounded planner and exhaustive negative fixtures.

**XP60-03 — next-login delivery:** new validated per-session plan contract, data-only Advice.lua integration, stale-character checks, unobtrusive Hub UI.

**XP60-04 — polish and acceptance:** player's "Already know" feedback, outcome comparison, missing-data fallback, performance, independent review and all-class real-game checks.

**Feature-complete code** means XP60-00 through XP60-03 are implemented and CI-green. **Beta-ready** additionally requires XP60-04 owner and live-client gates. D18's blocked live-transport research is NOT a dependency; do not enable any external live-game bridge.

## 11. Research/verification notes

- Blizzard community explanation of SavedVariables write-on-logout/reload behavior: https://us.forums.blizzard.com/en/wow/t/saving-local-variables-between-sessions/380081
- Historical September–October 2026 Forever beta SavedVariables loading problems were reported by addon developers; Outrider's own November 11 probe later marked its current client round trip working. Always test the actual installed build: https://us.forums.blizzard.com/en/wow/t/uiaddon-settings-wiped-on-client-restart/2353992
- Internal controlling sources: docs/DECISIONS.md D18/D22; docs/FOREVER_CONSTRAINTS.md C18; docs/PROBE_RESULTS.md; current I2 universal engineering blueprint.

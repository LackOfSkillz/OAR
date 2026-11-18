# Outrider Intelligence 2.0 — Universal AI Game Coach
## Engineering blueprint and implementation contract

**Product owner / creator:** Gary Mix  
**Status:** APPROVED PRODUCT DIRECTION / ENGINEERING SPECIFICATION — **NOT IMPLEMENTED BY THIS DOCUMENT**  
**Prepared:** 2026-11-18  
**Target:** World of Warcraft Forever (observed 1.60.1 / build 70888, newer builds must be probed)  
**Repository:** LackOfSkillz/OAR, branch `p1-foundation` (inspected at `d863045c1ecddba5186487e1833289f4c6ed03e5`)  
**Existing AI baseline:** `docs/intelligence/OUTRIDER_INTELLIGENCE_ENGINEERING_SPEC.md` and `docs/OUTRIDER_INTELLIGENCE_TASKS.md` (November 15 implementation). This document specifies the **next generation**, not a replacement that discards working components.  
**Implementation checklist:** `docs/intelligence/OUTRIDER_INTELLIGENCE_2_0_IMPLEMENTATION_BACKLOG.md`.

> **Mission.** Make Outrider a remarkably useful, unobtrusive, trustworthy game coach for **every supported player class, talent configuration, and role**. It should notice relevant opportunities using permitted local addon data, explain evidence-backed decisions using local or opt-in cloud AI, improve after feedback, and **never play the game for the user**.

---

# 0. Executive product decision

The flagship is **Opportunity Radar**: one excellent next recommendation, at most two supporting opportunities, and an optional explanation. The local addon generates and displays useful, verified hints *without any AI request*. The external AI enriches plans and explains tradeoffs using an explicitly shared, bounded snapshot. All external-model recommendations bind to factual IDs and evidence that Outrider owns.

**Universal release contract:** Warrior, Paladin, Hunter, Rogue, Priest, Shaman, Mage, Warlock and Druid must pass their class, gear, quest, economy and role-specific minimum tests before a universal release. Do **not** turn the Hunter prototype into the default class experience. Class IDs are a registry: unrecognized Forever-only class tokens fail safely into universal guidance, not a crash or incorrect Classic profile.

**Transportation reality:** the current approved path is `/ride ask` → user-authorized snapshot copy → existing companion → player pastes validated advice (or an existing reload-based data route). Outrider's Lua itself cannot open a general HTTP connection to a model. `D18` and `CLAUDE.md` expressly prohibit a live out-of-game bridge, game-window capture, memory reads, input simulation and runtime addon rewrites. A permanently connected external-model "watching" mode therefore **is not a release promise**. "Watches me play" in the safe first release means the **in-game local deterministic engine** reacts to allowed events; an external LLM sees the most recent player-shared snapshot and must disclose its age. Revisit live transport only through a separately approved, documented policy decision.

## 0.1 User-visible definition of "wow"

- The HUD shows **one priority and at most two alternatives**, with location/benefit, concise reason and a confidence/freshness indicator.
- A player never needs to open a chat window to receive native quest, gear, training, preparation and auction insights.
- The class coach changes correctly with talent distribution and chosen role; a Feral Druid does not receive Restoration item priorities.
- Auction House "NPC floor" deals show calculated **unit-vs-stack profit**, quantity, observed age and safe gold reserve; all purchasing is manual.
- A shared game-state snapshot gives local or optional cloud models enough evidence to answer "why", compare plans and explain alternatives, without inventing a game ID or coordinate.
- The system is quiet while fighting, transparent about unknowns and functional offline.
- Old Advisor, What Now?, OTR1 codes, data packs, existing UI and other addons keep working.

## 0.2 Explicit non-goals

- No automatic targeting, casting, rotation, trading, bidding, auctions, vendoring, quest accepting, equipping or movement.
- No interpreting protected or secret combat values to generate tactical decision logic, and no `COMBAT_LOG_EVENT_UNFILTERED`.
- No memory injection, process hooks, packet sniffing, nonconsensual screenshots, disk-side communication gimmicks, dynamically rewritten Lua, unattended mailbox/AH operations or botting.
- No mandatory subscription, paid addon feature, advertisements or in-game solicitation.
- No "AI knows everything" claims for missing Forever data, talents, quest packs, auction volume or boss timers.

---

# 1. Current repo audit and upgrade points

These were examined on `p1-foundation` at the inspected revision; Claude Code **must re-check HEAD and diffs** before implementing.

| Existing implementation | What is already working | Change for 2.0 |
|---|---|---|
| `addon/Outrider/Modules/WhatNow.lua` | Deterministic candidates, weights by goal, urgency, nearby grouping, feedback, `Snapshot()` | Introduce pluggable, evidence-backed opportunity producers and centralized suppression/deduplication without rewriting the ranking code prematurely |
| `addon/Outrider/Advisor/Snapshot.lua` | `OTR1` player-copy snapshots, 50 KiB cap, schema/time/build, optional module data | Add backwards-compatible v3 **task-specific evidence bundles** and source freshness; never silently drop essential class/auction inputs |
| `addon/Outrider/Advisor/AdviceLoader.lua` | Schema 1/2 advice parsing; whitelisted waypoint/quest watch/panel/item actions; grounding | Keep schema 1/2, add independently validated schema 3, exact evidence binding and explicit expiry |
| `addon/Outrider/Modules/Advisor.lua` | Advisor tab, answer and feedback, Ask/Paste keys | New compact native Coach entry and deep-explanation view; do not break existing Ask/Paste |
| `companion/outrider_companion/intelligence/context.py` | Privacy filtering, class and goal, candidate IDs and source labels | Typed evidence registry, role profiles and budgeted field selection instead of only top candidates |
| `companion/outrider_companion/intelligence/orchestrator.py` | Model ranks ≤3 candidate IDs, deterministic fallback, answer validation | Separate explain/compare/plan from deterministic arithmetic and policy decisions; tool result attestation |
| `companion/outrider_companion/intelligence/providers.py`, `cloud.py` | OpenAI-compatible model plus Anthropic/OpenAI/Gemini, fake provider, bounded requests | Keep interfaces; add provider status, profiles, circuit breaker and local GX10 configuration without hard-coded IPs or model names |
| `companion/outrider_companion/intelligence/window.py` | Separate desktop helper / clipboard workflow | Clean session panel, source age, voice only when selected and permissioned |
| `Modules/Prices.lua`, `AHBuy.lua`, `AuctionHelper.lua` | Last 14 daily-low auction observations; vendor price and manual AH workflows | Opportunity algebra, unit/stack checks, gold reserve, recorded-age, cross-check actual vendor values, outcome ledger |
| `Modules/GearScore.lua`, `GearSets.lua`, `QuestObjectives.lua`, `Journey.lua`, `DungeonJournal.lua`, `LevelRoutes.lua` | Gear/quest/travel/dungeon planning building blocks | Universal eligibility and role-specific reference adapters, with evidence IDs and per-source verification status |
| `Modules/PetStatus.lua` and `HunterFight.lua` | Hunter-specific capability | Optional HUNTER class plugin only; not a dependency of universal core |

**Existing tests:** Lua mock suite, Python companion tests, contract fixtures, security tests, Github Actions and `tools/test.ps1 -RequirePython`. Current CI was green at the inspected HEAD. Build on these tests rather than creating a separate parallel test runner.

### 1.1 Repository conventions (binding requirements)

- `CLAUDE.md`, `docs/FOREVER_CONSTRAINTS.md`, `docs/PROBE_RESULTS.md` and `docs/AI_PRIVACY_AND_TRANSPORT.md` are controlling implementation inputs.
- Lua 5.1 only, `ns:NewModule`, `ns.Compat` for unverified client APIs, `ns.Safe` and `Module:Secure` for relevant UI operations; `Outrider.toc` needs correct load order.
- Preserve existing SavedVariables; additive migrations with idempotent versioned transformations and backup instructions.
- No new global names except the explicitly approved Outrider variables/frame names; no arbitrary external text executing as Lua.
- Respect competing Questie/TomTom/Auctionator/TSM etc via `yieldsTo` and no reparenting/replacing protected frames.
- Do not silently change the owner's current `D18` advice-only rule to permit external live capture.

---

# 2. Compliance and trust policy

## 2.1 External references (review on each release)

1. Blizzard WoW UI Add-On Development Policy: https://eu.forums.blizzard.com/en/wow/t/wow-user-interface-add-on-development-policy/1642/1 — free and visible addon code, no premium services, ads or in-game donation requests, no realm/client harm.
2. Blizzard EULA: https://www.blizzard.com/en-us/legal/08b946df-660a-40e4-a072-1fbde65173b1/blizzard-end-user-license-agreement — unauthorized programs, data mining, unauthorized connections and game control restrictions.
3. Blizzard anti-cheating agreement: https://www.blizzard.com/en-us/legal/simple/cd5930c0-2784-420c-a23d-1e0d6ff8599b/anti-cheating-agreement — third-party capture/automation risks.
4. Blizzard's Midnight addon disarmament explanation: https://news.blizzard.com/en-us/article/24246290/combat-philosophy-and-addon-disarmament-in-midnight — secret combat values may be shown but not processed to solve combat decisions.
5. AH replication API (community API reference, must verify on Forever): https://warcraft.wiki.gg/wiki/API:C_AuctionHouse.ReplicateItems — account-wide cooldown around 15 minutes and performance concerns.
6. Approved policy contact: WoWUI@blizzard.com, cited by the UI policy thread.

**Policy position:** This plan is conservative engineering risk management, **not Blizzard approval or legal advice**. Any method technically employed by a competing addon may still be unauthorized. No release notes should claim "Blizzard approved" without actual written confirmation.

## 2.2 Feature-classification gates

| Category | Proposed functionality | Release classification |
|---|---|---|
| A | Deterministic informational hints computed inside the addon using readable non-secret, permitted APIs | **Allowed design baseline**, test actual APIs and taint |
| B | Player manually copies an explicit, redacted snapshot and manually pastes strictly validated advice | **Existing accepted architecture** (still subject to terms) |
| C | Desktop voice assistant answering from previously consented snapshot, with visible snapshot age | **Optional**; no direct interaction with WoW client |
| D | Local model on LAN or optional cloud endpoint; no automatic cloud fallback | **Opt-in**; account for encryption, privacy and addon-service policy |
| E | Continuous automatic external AI ingestion via screenshots, OCR, helper-file signaling, SavedVariables polling, load-on-demand slot tricks or runtime file rewrites | **BLOCKED** under D18; separate owner/policy decision, not part of this build |
| F | Protected actions, automation, input simulation, code injection, secret-value inference, combat tactical optimization | **PROHIBITED** |

**Timing policy:** In-combat coaching may display previously verified static advice and existing Blizzard-supported display values; it must not dynamically calculate an optimal action from secret combat state.

## 2.3 Addon free-use requirement

The addon and all core features are free; no premium classes, tiered coaching, payment banners, paid suggestions or advertising. An optional personal cloud API key does **not** establish permission for a paid companion service; escalate any planned commercial model or bundled metered service to a licensing/policy review. No background uploads without opt-in.

---

# 3. Target system architecture

```text
                        WORLD OF WARCRAFT FOREVER
          +---------------------------------------------+
          | Outrider Lua; normal event subscriptions     |
          | UI/API probes -> readable data adapters      |
          |             |                               |
          |    Event/Observation Registry (bounded)      |
          |             |                               |
          |    Universal Opportunity Producers           |
          |       Quest / Gear / Economy / Progression   |
          |       Professions / Dungeon / Travel         |
          |           + Class/Role Plugin Registry       |
          |             |                               |
          |    Score + Deduplicate + Safety Filters      |
          |             |                               |
          |    Opportunity Radar: ONE + TWO hints        |
          |             |                               |
          |     Optional user-click ASK / EXPLAIN        |
          +-------------|-------------------------------+
                        | OTR1 player-copy snapshot (current)
                        v
          +---------------------------------------------+
          | Desktop Companion — existing Python package |
          | Explicit snapshot decode & redaction         |
          | Evidence store + freshness validation        |
          | Goal/time/role profile and outcome feedback  |
          | Deterministic plan/deal/gear math             |
          | Model router and grounded explanation        |
          |    Local OpenAI-compatible  |  Cloud opt-in   |
          | Structured response validator                |
          +-------------|-------------------------------+
                        | OTR1 user-pasted advice (current)
                        v
          +---------------------------------------------+
          | Existing AdviceLoader + Coach panel          |
          | Validated candidate IDs, bounds, freshness   |
          | ONLY approved user-clicked UI actions         |
          +---------------------------------------------+

   OPTIONAL FUTURE: continuous external transport — NOT IMPLEMENTED.
   Requires explicit revised D18, specific Blizzard/policy clearance,
   threat model, privacy consent, tests and separate release switch.
```

## 3.1 Design rules

- **The Lua addon is the source of observed game facts**; the model is not.
- **All calculations are deterministic** for profit, required skill, eligibility, route distance, cost and risk. Models explain and compare validated results.
- **Class identification and specialization are data**, not hard-coded branches inside the planner.
- **Every recommendation is traceable** to immutable snapshot evidence and a validator-owned action.
- **No data is fresh just because a model replied recently**; source timestamps are authoritative.
- **One source of business logic** per feature: prefer adapters to existing modules rather than duplicate auction/gear/route engines.

## 3.2 Suggested file additions / refactors

```text
addon/Outrider/Intelligence/
  Observation.lua       # consent, readable data, bounded event records
  Opportunity.lua       # immutable candidate schema and eligibility
  Registry.lua          # producer registration, source invalidation
  Scoring.lua           # deterministic priorities and suppression
  Profiles.lua          # class/role registry, capabilities and safe fallback
  CoachUI.lua           # one + two HUD and details, nonprotected UI
  Economy.lua           # deterministic market candidate calculations
  Evidence.lua          # source timestamps, data origin, confidence
  Metrics.lua           # local-only anonymous feedback and timings
addon/Outrider/Data/
  ClassProfiles.lua     # light baseline descriptors for all nine classes
companion/outrider_companion/intelligence/
  evidence.py           # dedupe, provenance, TTL and snapshots
  class_profiles.py     # role and talent context, validated class tokens
  opportunities.py      # deterministic non-game adapter planner
  economy.py            # vendor floor / resale calculations
  memory.py             # feedback + result ledger, bounded storage
  coach.py              # new orchestration façade reusing providers
  schemas.py            # v3 contracts / compatibility
  voice.py              # OPTIONAL desktop-only; no game access
tests/spec/
  coach_spec.lua, profiles_spec.lua, opportunity_spec.lua, economy_coach_spec.lua
companion/tests/
  test_coach.py, test_profiles.py, test_economy.py, test_evidence.py
```

These are **target paths, not files created by this specification**. Claude may consolidate modules where that reduces complexity, but cannot leave dual owners of the same state. Keep prior AI module names and APIs stable.

---

# 4. Universal class and role intelligence (P0 requirement)

## 4.1 Class registry

Provide `ClassProfileRegistry` with one entry per supported class token. Registry lookup is by **real client class token** with an optional Forever data-pack alias (never assume English display names). Do not assume only Classic class/race combinations exist; obtain capability and talent data from documented APIs and actual Forever probes.

Required registry interface:

```text
register_profile(classToken, profileVersion, roles, sources, capabilityRules)
resolve_character(classToken, talentSnapshot, gearSnapshot, playerRoleOverride)
 -> CharacterContext { classToken, roleCandidates[], selectedRole,
      roleSource, roleConfidence, buildHash, supportedCapabilities[],
      unverifiedRequirements[] }
get_opportunity_producers(CharacterContext)
 -> universal producers + compatible role producers
```

Talent distribution may imply more than one role. Player override takes precedence, is per-character and reversible; if talents cannot be read reliably, present **"Role unknown — choose one"**, not an invented specialization.

## 4.2 Nine-class minimum profile matrix

| Class | Baseline tested roles | Example *out-of-combat* coaching facts |
|---|---|---|
| WARRIOR | melee damage, tank | Weapon compatibility, defensive gear, training and consumables |
| PALADIN | melee damage, healing, tank | Role-specific stats, blessing preparation, mana/equipment readiness |
| HUNTER | ranged damage, pet utility | Pet XP, known pet families/skills, ammo and weapon preparation |
| ROGUE | melee damage | Weapon/poison preparation, gear, trainer and crafting needs |
| PRIEST | healing, spell damage | Mana/regen, healing sets, spell/talent training and solo-leveling gear |
| SHAMAN | melee damage, spell damage, healing | Totem/training plan, role-specific stats and gear |
| MAGE | spell damage | Consumable readiness, spell-rank/training, wand/gear upgrades |
| WARLOCK | spell damage, pet utility | Demon training, shard inventory, role gear and consumables |
| DRUID | melee damage, tank, spell damage, healing | Form-aware gear, hybrid builds and training/travel planning |

The matrix names **design requirements**, not proof that each role's talents/spells are available on every Forever build. Unknown or patch-specific abilities must not be auto-added to the data pack without evidence.

**Custom/unknown class:** all universal quest/economy/profession/travel features remain active; class-specific combat/preparation rules default off and the UI explains why. A new profile can be supplied by a versioned, attributed data pack; validation must reject unknown spell/item IDs in advice actions.

## 4.3 Cross-class test model

For every class, test at least:
- new/low-level solo, mid-level solo, and high-level/dungeon contexts;
- all documented supported roles including hybrids and talent respec;
- class-appropriate gear versus off-role gear; pet/no-pet and range/melee variants;
- unrecognized talent tree and undocumented Forever race/class combination;
- unknown/protected combat values: suppressed or static-only suggestions;
- quest, profession, auction, travel and gold features available without class plugin.

**Release block:** No "universal AI" badge or documentation until all nine baseline classes and relevant roles pass the same functional gates. Hunter-only test coverage is not acceptable.

---

# 5. Data, evidence and model contracts

## 5.1 Observation record v3 (Lua-local)

```json
{
  "schema": 3,
  "eventId": "event-opaque",
  "kind": "INVENTORY_CHANGED",
  "observedAt": 1795000000,
  "gameBuild": "1.60.1",
  "characterKey": "local-only",
  "privacyClass": "player-only",
  "source": "C_Container-readonly",
  "data": { "itemID": 101, "count": 3 },
  "confidence": "observed",
  "status": "readable"
}
```

IDs and time values above are **schema examples, not actual game facts**. No chat, other-player identities, account strings or secrets in exported observation lists.

Bounded ring buffer, **suggested initial cap 256 observations**, event coalescing (bag/currency changes), and a per-source byte quota. Observations remain local until the player explicitly creates/shares a snapshot. Separate local-only from exportable fields at capture time.

## 5.2 Evidence record v3

```json
{
  "evidenceId": "src:inventory:101:snap-abc",
  "kind": "item_count",
  "origin": "wow-readonly-api",
  "observedAt": 1795000000,
  "gameBuild": "1.60.1",
  "dataPackVersion": null,
  "confidence": "observed",
  "freshness": { "ttlSeconds": 120, "invalidatedBy": ["BAG_UPDATE_DELAYED"] },
  "facts": { "itemID": 101, "count": 3 },
  "unknown": []
}
```

Evidence labels: `observed` / `verified` / `community` / `inferred` / `unknown`; no unsourced numeric "97% confidence." Expired evidence loses actionable status; archive history can still support *historical* advice when clearly labeled.

## 5.3 Opportunity v3

```json
{
  "schema": 3,
  "candidateId": "economy:vendor-floor:snap-abc:item-101:lot-2",
  "kind": "economy",
  "subtype": "vendor_floor",
  "title": "Possible vendor resale margin",
  "priority": 0.76,
  "goalFit": ["gold"],
  "roleFit": ["all"],
  "requiredFacts": ["listing_total_buyout", "stack_quantity", "vendor_unit_value"],
  "evidenceIds": ["src:ah:101:snap-abc", "src:vendor:101:snap-abc"],
  "eligibility": "valid",
  "expiresAt": 1795000120,
  "confidence": "observed",
  "riskFlags": ["recheck_current_listing"],
  "display": { "oneLine": "Potential 4s gross NPC resale margin" },
  "safeAction": { "kind": "open_panel", "panel": "auction" }
}
```

**Important:** Example fields and IDs are illustrative. The validation layer assigns the action and the authoritative item/quest IDs. The model may select by candidateId and explain, never invent IDs, coordinates, buyout prices or commands.

## 5.4 ContextEnvelope v3

Built from a player-requested existing OTR1 snapshot; additive to schema 1/2 with migration adapters.

```json
{
  "schema": 3,
  "snapshotId": "snap-opaque",
  "createdAt": 1795000000,
  "character": {
    "anonId": "character-1",
    "classToken": "DRUID",
    "level": 35,
    "role": "healer",
    "roleSource": "player_override",
    "buildHash": "opaque-hash"
  },
  "goal": "gear",
  "timeBudgetMinutes": 35,
  "opportunities": ["candidate-101", "candidate-102"],
  "evidence": ["src:gear:1", "src:quest:2"],
  "transport": "player_clipboard",
  "privacy": { "cloudConsent": false, "playerNamesIncluded": false }
}
```

Canonical IDs are opaque; do not send actual character/realm names, guild/chat/party names, paths or auth tokens to any provider. Keep the addon snapshot at its current **50 KiB maximum** by selecting an evidence pack for the specific question: quest vs economy vs gear vs class/progression. An input-size overflow is an explicit status, not a silent removal of critical evidence.

## 5.5 AI answer v3

```json
{
  "schema": 3,
  "answersSnapshotId": "snap-opaque",
  "headline": "Do the nearby training errand first",
  "summary": "It fits the available time and may help the planned dungeon.",
  "rankedCandidateIds": ["candidate-102", "candidate-101"],
  "rationaleEvidenceIds": ["src:trainer:1"],
  "assumptions": ["Dungeon group availability is unknown"],
  "limitations": ["Snapshot is no longer live"],
  "actionRequests": []
}
```

Generate model text in the companion, then rebuild final cards from trusted candidate registry. Reject unknown candidate IDs, stale or altered evidence, unsupported model fields, action types outside the existing whitelist, wrong character/build/snapshot binding or oversized text. The model does not get a direct path to a file-writing, API-spending or game-action MCP tool.

Compatibility tests must preserve OTR1 v1/v2 and existing AdviceLoader uses.

---

# 6. Opportunity generation, scoring and lifecycle

## 6.1 Producer interface

Each producer supplies `Collect(context, budget) -> candidates, evidence` with **no global side effects**. Producers are grouped:

- Universal: quest sequencing, errands/flight paths, talent/training planning, gear upgrade opportunities, dungeon readiness, professions, auction economics, consumables and inventory housekeeping.
- Role-aware: health/mana prep, tanking readiness, healing gear, DPS stats, pet-related preparation, form-specific needs.
- Contextual: player goal, time available, zone, quest objectives, vendor/auction opened, post-fight review, group-size changes.
- Optional: class plugins and verified third-party read-only datasets.

A producer's absence does not suppress the universal engine. Use `WhatNow` as the initial candidate source; instrument it before replacing its ranking logic.

## 6.2 Priority scoring (deterministic, tunable)

```text
score =
   (goal_fit * 0.28)
 + (estimated_benefit * 0.23)
 + (eligibility * 0.18)
 + (freshness * 0.13)
 + (role_relevance * 0.10)
 + (proximity * 0.08)
 - travel_penalty
 - effort_penalty
 - repetition_penalty
 - uncertainty_penalty
```

These are **proposed starter weights, not trained values**. All signals normalized to [0,1] using documented, tested procedures. Critical unreadable/secret/stale fields cause eligibility `unknown` and may remove a candidate; do not allow low confidence to become high simply by multiplying scores. Urgent out-of-combat readiness alerts (broken gear, missing ammo where relevant) get an explicitly bounded priority tier rather than arbitrary giant numbers.

## 6.3 Trigger/suppression mechanics

Suggested initial triggers: `PLAYER_ENTERING_WORLD`, `PLAYER_LEVEL_UP`, `QUEST_TURNED_IN`, `QUEST_LOG_UPDATE` (throttled), `BAG_UPDATE_DELAYED`, trainer/vendor/AH show and selection events, player-chosen role change, zone change, explicit user refresh. **No high-frequency polling loop.**

- Coalesce frequent event bursts into one recalculation (initial 2–3 seconds).
- Do not display *new* recommendation toasts during combat; queue at most one summary to show after combat, if still relevant.
- Normal HUD: maximum 1 main + 2 secondary. Notification toasts default OFF and require user opt-in.
- Deduplicate by stable candidate and evidence fingerprint. No repeated suggestion for a dismissed candidate for at least the configured cooldown (proposed 5 minutes).
- Mark cards invalid immediately when relevant source signals change (quest turned in, item sold, AH closed, role changed, item no longer owned).
- Old item prices/loot stats remain in history but cannot drive an active "buy now" recommendation.
- User controls: snooze, dismiss, useful, incorrect, completed, mute category, reset personalized learning.

## 6.4 Optional coaching modes

- **Quiet:** summary accessible on demand, no toasts (default).
- **Contextual:** one low-priority noncombat suggestion after a major milestone.
- **Planning:** explicit session goal and time budget, multiple actions shown only in planner.
- **Offline:** deterministic only, zero external requests.
- **Explain:** player asks model to justify a card or compare two verified options.

---

# 7. AI orchestration and model providers

## 7.1 Two-layer decision system

**Layer A — deterministic authority:** source adapters, class/role resolver, prerequisites, arithmetic, actions, evidence freshness, privacy, TTL. **Layer B — optional model:** compare, summarize, reason over multi-step goals, ask follow-up, explain tradeoffs, generate nonbinding alternatives.

Pipeline:

1. Player chooses a question or opens Coach; context selector assembles only required evidence.
2. Privacy preview and consent policy select provider and scope.
3. Validate the current role, snapshot, source freshness and candidates.
4. Run deterministic planning, prices and risk logic first.
5. Optionally call model with **read-only tools** and bounded evidence (hard timeout, token limits, no background uncontrolled loops).
6. Parse strict structured response. Validate candidate IDs and evidence claims.
7. Render trusted actions and separately marked explanatory prose.
8. Capture feedback and (only if approved) historical outcome for local learning.
9. On any failure, show deterministic result with a brief error state. No auto escalation to cloud.

## 7.2 Approved read-only tools

Names are API design targets; actual MCP tool naming must reconcile with `companion/outrider_companion/server.py`.

```text
get_character_profile(snapshotId)
get_quest_opportunities(snapshotId, goal, timeBudget)
get_gear_candidates(snapshotId, role)
get_dungeon_readiness(snapshotId, dungeonId)
get_profession_options(snapshotId, role)
get_market_observations(snapshotId, itemId)
get_vendor_margin_candidates(snapshotId, minimumMargin)
get_rare_observations(snapshotId, mapId)
compare_candidate_options(snapshotId, candidateIds)
get_evidence(snapshotId, evidenceIds)
```

No exposed tool performs or schedules a click, cast, purchase, trade, packet query or external game action. If the tool returns user-controlled text, quote and length-limit it; instructions embedded in quest/NPC/item names are untrusted.

## 7.3 Provider routing

- **Offline first:** no model = full native radar plus optional local rules explanation.
- **Local default:** existing `OpenAICompatibleProvider` supports Ollama/LM Studio/vLLM. Configure endpoint and model through user-owned settings; one or multiple GX10 systems can supply a LAN endpoint through a secured local network. Never ship a hardcoded private IP.
- **Cloud opt-in:** current Anthropic/OpenAI/Gemini adapters are retained, gated by preview, explicit provider/data scope consent, Windows Credential Manager, a daily token/spend cap and transport/TLS checks. No automatic fallback from local to cloud.
- Provider health checks are explicit or cached; no cloud polling on each game event.
- Limit to one concurrent answer per character; cancel UI waits safely, discard responses for superseded snapshot IDs.
- Separate model usage metrics (latency, tokens, provider cost if known) from game/user metrics. Never claim a calculated cost is an invoice.
- Provider-specific instructions live in adapters; no provider string leaks into game Lua.

## 7.4 Memory

Three tiers:
1. **Character preferences:** selected role, goals, chosen gear scale, muted coaching categories, session time.
2. **Observed outcomes:** quest times, chosen recommendations, completed errands, safe aggregate AH observations.
3. **Model narrative:** optional short human-readable summary, regenerated only from verified facts; never a hidden unbounded vector database.

Retention is bounded and local by default. Provide `Delete coaching history` and `Export data`. No embedding or cloud memory uploads without separate consent. Do not store other players' names, conversations or financial account details.

---

# 8. User interface and interaction design

## 8.1 Primary HUD (minimal, nonintrusive)

```text
+--------------------------------------------------------+
| OUTRIDER COACH        DRUID · HEALER · Local/offline    |
|--------------------------------------------------------|
| Best next move: Visit trainer before the next dungeon |
| Evidence: observed training / role profile   [Why?]   |
|                                                        |
| + Gear: compare the new staff                    [View]|
| + Gold: 2 vendor-floor listings to check         [View]|
|                                                        |
| [Plan 30 min]  [Ask]  [Snooze]  [Settings]             |
+--------------------------------------------------------+
```

- **Exactly one primary + up to two secondary cards**; hides to a small icon. Sizing, anchors and dark/light styling follow existing Outrider UI tokens.
- Show role override state: auto-detected / selected / unknown. Make role change a normal player option, not a model guess.
- Evidence chips must show `Observed`, `Verified`, `Community`, `Estimated` or `Unknown` plus age and build. Color must never be the only status signal.
- All economic and route actions link to **existing** Outrider pages or user-authorized waypoints. No auto-buy/action shortcuts.
- Hover or click `Why?` shows "Why this / evidence / tradeoff / when last seen / what I couldn't verify".
- Accessible controls: keyboard, adjustable scale, high contrast, text wrapping, no forced audio, no long visual interruption while in combat.

## 8.2 Player experiences

**A. First login / any class:** passive contextual cards use native addon data. AI toggle optional. Class is inferred from actual client token; roles detected conservatively and an explicit override offered.

**B. After turning in quests:** local engine reassesses leveling/training routes; one suggestion only when meaningfully better.

**C. At Auction House:** the player explicitly opens Deal Desk, triggers a normal client-permitted search/scan, and gets vendor-floor or resale candidates. Prices expire with market state; no background full scans.

**D. Gear pickup:** compare actual equippable item(s) with current worn items using the selected role, class permissions, known spell/talent implications and source age. A model may explain *why*, but gear math is authoritative only when all necessary stats are available.

**E. 35-minute plan:** user supplies time and goal, deterministic scheduler produces feasible candidates; optional model explains ordering and tradeoffs.

**F. Desktop voice:** user presses the desktop app's push-to-talk (or independently grants mic permission). Voice queries the **last explicitly shared** snapshot; says "I only have your data from 12 minutes ago" when stale. No speech-to-game commands, game-window capture or always-on recording by default.

---

# 9. Auction House Intelligence / Deal Desk

## 9.1 Core opportunity types

1. AH to NPC vendor resale (deterministic vendor-floor arbitrage).
2. AH to AH re-listing (probabilistic; needs market observations, listing fees and deposit rules).
3. Buy materials to craft (material bill + training/skill availability + deposit + sale probability).
4. Gather or farm versus buy (opportunity cost with actual observed time).
5. Sell now versus hold (only with sufficient historical observations, not merely daily lows).
6. Replace expensive quest materials with less costly eligible sources.

## 9.2 Vendor-floor candidate contract

Fields: `itemID`, binding/sellability verified, quality, `listingId` (or explicit unknown), `stackQuantity`, `totalBuyoutCopper`, `vendorValuePerUnitCopper`, `verifiedAt`, `source`, `inventoryFreeSlots`, `availableGold`, player gold reserve and click-eligibility status.

```text
grossVendorProceeds = vendorValuePerUnitCopper * stackQuantity
grossMarginCopper    = grossVendorProceeds - totalBuyoutCopper
marginPerUnit        = grossMarginCopper / stackQuantity
capitalRequired      = totalBuyoutCopper
safeSpendableGold    = max(0, availableGold - playerGoldReserve)
eligible             = (grossMarginCopper > 0)
                       and (capitalRequired <= safeSpendableGold)
                       and item_is_salable_to_npc
                       and listing_is_current
                       and player_review_required
```

Use **total stack buyout**, not bid price or a misleading per-item display; make quantity and required bag space visible. Re-check vendor value (may be zero on Forever), item binding, stack limits and available funds. No candidate if any essential fact is unreadable, stale, negative, secret or unknown. Model text may not override the calculation.

## 9.3 AH resale and uncertainty

```text
expectedNet = estimatedSalePrice * (1 - AHCut)
              - buyout - expectedDepositLoss
expectedProfit = probabilityOfSale * successfulProfit
                 - (1 - probabilityOfSale) * unsuccessfulLoss
```

Do **not** calculate a meaningful sale probability or market volatility from only the current 14-day **daily-low** price store. Add separate, opt-in, bounded, sourced sampling of quantities, bid/buyout distinction and timestamps from approved AH queries, respecting `C_AuctionHouse.ReplicateItems`' account-wide throttle and performance. Availability of server API ≠ permission for automated large-scale collection. Full scan is player-initiated and client-throttled; first implementation can simply use the results the player already requested.

Never store other sellers' identities or copy external AH database data without checking licenses and source access.

## 9.4 Deal Desk safety gates

- Each recommended listing has an authoritative evidence reference and timestamp; stale cards hide the "review listing" navigation until refreshed.
- No purchase attempts from the model or from a timer, macro bridge or injected input. Native AH purchase remains an explicit player act in WoW.
- Fraud guards: unit/stack mismatch, changed listing, unavailable quantity, missing vendor value, BoP/conjured/unsellable item, no bags, insufficient gold after reserve, deposit/commission misapplication.
- Score minimum return after travel/effort overhead and opt-in minimum margin; preserve user control and fees.
- Outcome ledger records **suggested / reviewed / user-confirmed purchased / user-confirmed sold**; do not infer a sale merely from a disappearing auction.

---

# 10. Privacy, security, performance, and reliability

## 10.1 Trust boundary threat model

| Boundary | Attack / error | Required mitigation |
|---|---|---|
| Game names/text → snapshot | Prompt injection, control codes, long inputs | Treat as data, strip WoW escape/control codes, strict length limits, never follow embedded instructions |
| Secret/protected client values → logic | Combat taint, covert decision inference | `C.Readable` / secret checks; unknown status; no arithmetic/branching on secret values |
| Snapshot → Python | PII leakage, oversized payload, corruption | Canonical schema, OTR1 validation, explicit manual export, allowlisted fields and 50 KiB ceiling |
| Python → LAN/cloud | Endpoint injection, redirect, SSRF, key exposure | Explicit provider configuration, TLS for non-loopback, hostname/IP restrictions, no redirects, Credential Manager |
| Model → answer | Hallucinated IDs, commands, prices, stale advice | Strict JSON schema, candidate ID lookup, source TTL, schema length caps; rebuild cards and actions from trusted data |
| Answer → addon | Wrong character, old build, altered state, forged action | Snapshot/build/binding matching; allowlist with per-action user click; no Lua code loaded from advice |
| History → memory | Mislearned profile and private info | Per-character isolation, feedback review, capped retention, export/delete, no chat/other-player identity |
| Models/tools → costs | Repeated cloud calls or expensive loops | One request per explicit click, token/cost caps, backoff, cancel, no automatic failover |
| UI → gameplay | Protected input, combat lockdown, taint | Nonprotected display only; approved UI action performed only by human click; secure changes deferred |

## 10.2 Resource budgets (initial engineering targets)

These are **acceptance targets to measure**, not measurements:
- No sustained OnUpdate polling for coaching. One event-coalesced refresh no more often than every 2 seconds during bursts.
- Most noncombat opportunity refreshes under **3 ms Lua CPU p95** on test machine; no visible frame hitch. Benchmark actual client (`debugprofilestop` where supported), not mock-only.
- New coaching module allocated memory: **target ≤ 300 KiB incremental** above measured baseline excluding optional data packs; tune with telemetry.
- In-addon evidence ring ≤ 256 entries and explicit serialized byte ceiling; no logs/snapshots that grow indefinitely.
- At most three HUD suggestions; zero unsolicited combat popups.
- Desktop local-model target p90 response time ≤ 15 seconds at reasonable prompt size; measure on user hardware and report actual latency.
- Cloud defaults OFF; no key or network required for core native coaching.

## 10.3 State and migrations

Maintain `Outrider_DB` and current OTR1 snapshot/advice. Add `intelligenceV2` settings under the appropriate character/account scope with version, role override, goal, muting, preference, event ring, feedback. Migrate on load idempotently; never rewrite source data packs or overwrite character keys. Test load v1/v2/v3 in both directions where appropriate. Old clients must ignore new fields safely, or explicitly report unsupported version.

## 10.4 Logging and diagnostics

No model prompts/responses stored by default. Diagnostic counters: producer failures, unknown source counts, dropped-secret values, stale candidates, average computation time, model outcome/fallback, token total and privacy consent status. Logs never contain player names, chat messages, raw keys, auth headers, cloud prompts, account paths or other players. Debug export requires a separate user action and redaction review.

---

# 11. Implementation phases and dependencies

Use the atomic task file for step-by-step coding. The phase descriptions below are mandatory gates.

## I2-00 Baseline and policy (P0)
Audit HEAD/CI, module data contracts, secret-value API probes and D18. Preserve owner choices; record current source pack licenses. **Exit:** policy decision document, no hidden bridge, green baseline, full nine-class test matrix defined.

## I2-01 Universal profiles and evidence (P0)
Implement class/role registry, class-independent adapters, evidence/freshness types, source TTL, data sanitization, snapshot v3 adapter. **Exit:** 9 classes + unknown class work in mock tests; correct role override; no invented talents, IDs or context; snapshots remain bounded.

## I2-02 Native Opportunity Radar (P0 flagship)
Refactor `WhatNow` as a producer, add standardized candidate registry/score, suppression and Coach UI. **Exit:** native coaching works offline across all nine classes; 1+2 display cap, no combat popups, stable cooldowns, no hidden actions.

## I2-03 Universal specialization modules (P1)
Gear, progression, quest, readiness, professions and role-specific profiles; connect to verified game data. **Exit:** role-specific minimum matrix green for every class and talent variant; no Hunter-only assumptions.

## I2-04 Economy / Deal Desk (P1)
Vendor-floor math, player-reviewed AH scans, reserve, flags, outcomes, future optional market-history enrichment. **Exit:** correct unit/stack maths, no phantom vendor flips, no unapproved purchases/scans, robust stale-listing checks.

## I2-05 Model and desktop experience (P1)
Reuse provider infrastructure and OTR1 codes; add v3 context/answer contract, grounded explanations, read-only tools, desktop freshness/status UI. **Exit:** local and optional cloud provider tests, deterministic fallback, no inventing source facts or actions, consent and budgets tested.

## I2-06 Memory, feedback and planning (P1)
Learn utility/cooldowns only from explicit feedback and trustworthy outcomes. Session planner adapts time estimates and goals, not combat tactics. **Exit:** replayable test cases improve choice quality without accumulating private third-party data.

## I2-07 Security and performance (P0 for release)
Probe relevant Forever APIs, complete taint and combat-lockdown checks, large-account saved-data migration, snapshots, data pack absence, offline/cloud failures and addon conflicts. **Exit:** clean client trace, performance targets met or documented waiver approved by Gary.

## I2-08 Universal release validation (P0 for release)
All class/role scenarios, controlled A/B test with current WhatNow, multiplayer dungeon runs only as normal gameplay, 25-question side-by-side competitor study, screenshots/UX review, user approval. **Exit:** release gate checklist below signed.

## I2-09 OPTIONAL transport investigation (BLOCKED)
Do **not** implement unless owner explicitly revises D18 and a specific interface receives favorable documented policy review. Stage as a separate spike, separate branch, compile-time disabled, no production artifact or user tracking. Lack of approval means the snapshot+clipboard companion remains the complete supported product.

---

# 12. Acceptance and verification

## 12.1 Automated coverage

1. Lua mock tests for all nine classes, each documented role, unknown class, race/class oddities, unprobed API absence, nil and secret value variants.
2. Evidence schema generation, TTL, invalidation by correct events, bounded ring, snapshot budget, source labels, source build mismatch.
3. No unknown IDs/actions, no executable model output, malicious prompt in NPC name, 10 MB prompt attack, forged OTR1, wrong character or older snapshot.
4. Auction arithmetic property tests: integer copper, stack vs unit, zero/negative, vendor unsellable, bound items, cancelled/expired listing, old price, misleading undercut, gold reserve.
5. 54 baseline scenarios (9 classes × 6 universal goals: level/gold/gear/professions/explore/mix) plus every supported role under a role-specific matrix.
6. Simulated offline local provider, LAN unreachable, cloud denied, rate-limited, malformed output, cancellation and read-only tool errors.
7. Privacy golden snapshots: zero chat, guild, other-player IDs, user paths, account names or secrets; redact cloud preview.
8. No API writes/input automation/combat log parsing, no runtime code file manipulation; existing `test_security.py` extended.
9. Backward compatibility: old OTR1 fixtures, old Adventure Plans/feedback, saved profiles and addon startup.
10. CI: `tools/test.ps1 -RequirePython` plus existing Python companion suites; no bypass for deploy.

## 12.2 In-game verification (Gary + Claude Code)

- **All nine classes:** at least one actual Forever client check per class, with documented talent/role capability validation. Owner can schedule additional characters or approved volunteers; no mock-only universal certification.
- **Role changes:** player changes talents/role and confirms visible recommendation pivots after a reload/zone change; not just label changes.
- **Quest/leveling:** zone swaps, completed quest, missing private data pack, newly started character, stale route coordinates.
- **Auction:** true vendor floor above buyout, negative margin, stacked commodity, missing vendor price, sold-out listing, client query throttle and no accidental action.
- **Group/combat:** no taint, no auto targeting/casting, no combat interruption, group ownership/visibility correct.
- **Model:** user-initiated Ask→copy→local answer→paste; cloud optional; bad data causes visible "unknown"; no response writes untrusted commands.
- **UI:** 1366×768, 1920×1080 and UI scaling; controller/keyboard where supported; no overlap with Questie/Auctionator or protected frames.
- **Persistence:** /reload, full client exit/restart, character switch and same-account alt isolation.
- **Performance:** CPU, memory and candidate counts from real client; full-frame screenshots and error log checked.

## 12.3 Ship blockers and quality targets

| Gate | Required outcome |
|---|---|
| Safety | **Zero** unauthorized game actions, data leakage, secret-value decisions, protected-frame combat taint |
| Data validity | **Zero** executable/invented action IDs or coordinates accepted by output validator |
| Privacy | 100% cloud requests explicitly consented and previewable; local-only default; deletion/export tested |
| Coverage | Nine class profiles; all documented roles and universal goal matrix pass |
| Grounding | 100% of actionable recommendation cards have evidence ID, build and freshness or are marked unavailable |
| Quiet UX | 1+2 cap, zero unsolicited combat toasts, dismiss/mute works |
| Auction | 100% tested unit/stack/reserve/fee/age arithmetic and no automated trades |
| Regression | Full Lua/Python CI green; v1/v2 legacy code flows intact |
| Game | Real Forever testing; no known critical addon conflict/taint |
| Competitive | At least 25 repeatable questions compared fairly, accuracy and friction reported (no unverified "surpasses" claims) |

**Suggested outcome metrics:** player usefulness ≥ 80% of explicitly rated radar suggestions in initial beta, wrong/stale actionable card rate < 2%, duplicate interruption ≤ 1 per hour on default settings. These are targets to evaluate and adjust, not established performance measurements.

---

# 13. Claude Code execution rules and deliverables

1. Read `CLAUDE.md`, `docs/DECISIONS.md`, `docs/FOREVER_CONSTRAINTS.md`, `docs/PROBE_RESULTS.md`, old AI spec/tasks, then this document and the I2 backlog.
2. Verify current branch, HEAD, remote changes, and full CI. Do **not** assume the inspected `d863045c` is still current. Implement on a review branch based on `p1-foundation`, not directly on `main`.
3. Build a one-class-neutral vertical slice first: readable event -> evidence -> native WhatNow producer -> one Coach card -> feedback -> tests. Verify Warrior and Druid alongside Hunter **immediately**.
4. Keep a concise implementation log per task: touched files, API provenance, tests run, real-client status, risks.
5. Write new Lua and Python unit tests with each feature. Never tick Works/Matches/Surpasses based on mocks alone.
6. Use existing module, UI, serializer, data-pack and companion structures, with additive compatibility. No duplicate provider or snapshot system.
7. Document exact APIs probed on Gary's client, including build number and whether values are secret; never guess new Forever abilities or talent IDs.
8. All core functionality functions without internet or a model. If a feature needs a prohibited live bridge, it stays blocked rather than bypassing D18.
9. Package only after passing source audit, full tests and owner in-game checks. Note that public GPLv3 and any third-party data retain their attribution and independent licensing caveats.
10. Before marking release-ready, produce: updated source, full automated test logs, nine-class role matrix, privacy/security assessment, performance measurements, annotated UX screenshots and user-facing setup guide.

**Non-negotiable scope separation:** This blueprint authorizes the **engineering design** and future implementation work; it does **not** authorize an automated game-control agent, live external data capture or unattended network sharing. Any future change requires explicit owner and policy decisions.

---

# 14. References and current source of truth

- Existing AI v1 blueprint: `docs/intelligence/OUTRIDER_INTELLIGENCE_ENGINEERING_SPEC.md`
- Current AI task list: `docs/OUTRIDER_INTELLIGENCE_TASKS.md`
- Current architecture: `docs/OUTRIDER_INTELLIGENCE_ARCHITECTURE.md`
- Privacy and transport: `docs/AI_PRIVACY_AND_TRANSPORT.md`
- Transport decision: `docs/intelligence/TRANSPORT_FEASIBILITY.md` (D18 no in-game bridge)
- Threat model: `docs/intelligence/THREAT_MODEL.md`
- Companion user guide: `docs/intelligence/USER_GUIDE.md`
- Core implementation rules: `CLAUDE.md`
- Client proof logs: `docs/PROBE_RESULTS.md`
- Owner decisions: `docs/DECISIONS.md`
- Official Blizzard addon and combat rules: URLs in `2.1`
- Data rights: `LICENSE`, `COPYRIGHT.md` and `docs/QUESTIEDB_PUBLICATION_REVIEW_2026-11-18.md`

**End of blueprint — all dates/IDs inside JSON contract examples are fictitious demonstration data.**

# OUTRIDER INTELLIGENCE
## Engineering specification and Claude Code implementation blueprint

**Edition:** 1.0 | **Prepared:** 2026-11-15 | **Target:** WoW Forever 1.60.1 and future compatible builds
**Repository:** https://github.com/LackOfSkillz/OAR (private development)
**Inspected baseline:** `main` at commit `fc4e0e3d938fa6461118c2a96e9c3476fbf2af33` (2026-11-15 12:11 UTC)
**Public distribution:** https://github.com/LackOfSkillz/outrider-releases
**Execution owner:** Claude Code on the developer workstation, with real-client verification by the owner
**Status:** Proposed engineering design, NOT a claim that these features are implemented

> Mission: Build the most useful, trusted, polished, character-aware AI companion for WoW Forever. It must help players **understand, choose, and plan**, while leaving **all gameplay actions to the human**. It should be remarkable because it knows the player's actual game state and can show its work, not because it produces longer chatbot answers.

---

# 0. CLAUDE CODE START HERE

This is an implementation specification, not permission to rewrite the existing addon. Follow the repository's `CLAUDE.md` as the controlling engineering rulebook, and read `TASKS.md`, `docs/ARCHITECTURE.md`, `docs/FOREVER_CONSTRAINTS.md`, `docs/PROBE_RESULTS.md`, and the current tests before changing any files.

1. Verify branch and HEAD before doing anything. The inspected reference is `fc4e0e3`, but newer commits take precedence. If main has moved, create a delta report and reconcile this specification with actual code.
2. Preserve existing functionality, filenames, player SavedVariables, existing commands, sharing rules, data pack compatibility, and public-release process. Keep the feature modular and OFF unless the player opts in.
3. Create a short implementation log and track each task ID and gate in `docs/OUTRIDER_INTELLIGENCE_TASKS.md`. Work in separate reviewable branches/commits. Do not mark a gate done solely because mock tests pass.
4. Build a narrow, working vertical slice before building a huge architecture. In the first slice, take `/ride ask` snapshot -> retrieve grounded context -> call a chosen local model -> render text and 1-3 safe recommendations via the already working copy/paste route.
5. Never hardcode a private local IP, local game account name, API key, model name, or Windows username into released packages. Use discovered paths and user-owned settings.
6. Never implement automation, input injection, combat decision execution, arbitrary Lua execution, runtime memory reading, network access from Lua, or automatic gameplay actions. Keep all suggested waypoints, panel openings, or trackers user-clicked and validation-gated.
7. Do not treat an existing third-party bridge pattern as inherently permitted. Investigate its API compatibility and Blizzard policy before enabling an experimental seamless transport.
8. Stop and report any unresolved client API or policy assumption rather than making up a supported API.
9. Run relevant tests continuously; run the full Lua and Python suites at phase gates. Verify in actual WoW Forever before public release.
10. Do not automatically publish, push to the public releases repo, or enable this for existing users without approval.

---

# 1. PRODUCT OUTCOME AND DIFFERENTIATION

## 1.1 Product statement

Outrider Intelligence is the optional reasoning layer over Outrider's deterministic game systems. The addon already knows a great deal about a character. The AI should answer: **What matters right now, why, what are my alternatives, and how do these activities fit together?**

Examples, all based on verified current-character data when available:

- "I have 45 minutes. What should I do as a level-15 hunter?" -> A 3-5 step plan with estimates, dependencies, source confidence, and a one-click **Set next waypoint** on eligible steps.
- "Should I run Deadmines or stay on my island?" -> Compare estimated loot benefit, availability, travel, group requirement, existing quest progress, and expected time. Admit what the addon does not know.
- "How do I reach Alchemy 125 cheapest?" -> Compare known recipes, materials in inventory/alt inventory, observed prices and their age, vendor sources, and expected skill gains. Do not invent auction prices.
- "What can my family share?" -> With opted-in family data only, identify relevant gear, known recipes, profession abilities, and who has useful materials.
- "Where should I look for a rare?" -> Show observed locations and last verified sightings; do not turn sparse sightings into a falsely precise respawn timer.
- "Why did Outrider suggest this?" -> Show the actual evidence, ranking factors and uncertainty; allow a player to mark a suggestion as irrelevant.

## 1.2 What constitutes a 'wow' experience

**A. The 60-second welcome:** Install the addon alone, open it, see useful non-AI advice; choose optional AI, configure local or cloud model, ask one question, get a grounded answer. No AI subscription or service account is required to use standard Outrider.

**B. Context matters:** The same prompt gives materially different guidance for a hunter and mage, characters at different levels, and characters with different completed quests, professions, gold, or mobility.

**C. It can show its work:** Every game-specific factual assertion that drives an action is linked to an Outrider observation, a verified game record, or an explicitly identified external reference. Inference is visibly an inference.

**D. Plans, not essays:** The model explains; deterministic code checks availability, computes estimates and selects executable *suggestions*. A plan survives being viewed again and can be manually progressed. Plans do not control the game.

**E. Useful offline:** Core Outrider works completely without the companion. A local provider can work without internet. Cloud models require network only if explicitly selected.

**F. Feels premium:** Use existing UI work (new Hub and incoming art) for an integrated Ask/Plan/Compare experience. Avoid generic text-dump chat or a second unstyled desktop application.

## 1.3 Explicit non-goals

- Autonomous quest acceptance, navigation, targeting, fighting, movement, purchasing, crafting, mailing, or selling.
- Reading the combat log, calculating on secret values, or altering protected frames in combat.
- Real-time combat rotation advice based on forbidden in-combat signals.
- Replacing Blizzard's bags, action bars, Edit Mode, or third-party UI frameworks.
- Downloading model weights as part of the addon/installer.
- Building a hosted proprietary AI backend in v1; user-supplied local/cloud providers first.
- Selling a premium in-game addon tier or inserting AI-provider advertising into the UI.
- Rebuilding a second quest/loot/price database when existing Outrider modules already have the information.

---

# 2. VERIFIED BASELINE: REUSE, DO NOT DUPLICATE

Reviewed directly in private GitHub source at the pinned baseline:

| Current component | Confirmed capability | Design consequence |
|---|---|---|
| `addon/Outrider/Modules/WhatNow.lua` | Eight candidate sources; six player goals; score = benefit x goal weight x confidence, travel penalty; 3-5 recommendations; alternatives; 24-hour skip | Extend candidate metadata and plan explanation. Do NOT replace scoring with opaque LLM ranking. |
| `addon/Outrider/Advisor/Snapshot.lua` | Snapshot of player meta, location, gear, quest log and module data; exportable code; 50 KiB limit; collect on `/ride ask` | Reuse; add v2 context selection, freshness/provenance and privacy filtering. |
| `addon/Outrider/Advisor/AdviceLoader.lua` | `schema=1`; safe actions `waypoint`, `track_quest`, `open_panel`, `show_item`; validates fields and snapshot timestamp; max 12 | Preserve v1. Add a compatible read-only narrative/plan schema; do not expand unsafe actions. |
| `addon/Outrider/Modules/Advisor.lua` | Existing Advisor UI; copy-snapshot/paste-advice; user-clicked suggestions | Upgrade view and actions, not event semantics. |
| `companion/outrider_companion/server.py` | Stdio MCP JSON-RPC server, read tools and constrained advice output | Extend read tools using this server; harden protocol compliance and error handling. |
| `companion/outrider_companion/store.py` | Read-only parser of SavedVariables; 20 MiB file cap; character/snapshot/gear/profession/rare lookups | Reuse as data adapter. Never parse SavedVariables by executing Lua. |
| `companion/outrider_companion/advice.py` | Sanitizes advice fields; writes only `Advisor/Advice.lua` via atomic replace | Keep double validation on companion and addon sides; migrate safely. |
| `companion/outrider_companion/codes.py` | Bounded OTR1 export-code codec shared with Lua | Reuse, retain backward compatibility. |
| `companion/outrider_companion/clipboard.py` | Windows clipboard exchange | Working first transport; do not remove. |
| `companion/tests/test_companion.py` | Tests parsing, safety, MCP calls, advice and copy/paste | Expand with integration and adversarial test fixtures. |
| `addon/Outrider/UI/Hub.lua` and `UI/Pages.lua` | Resizable hub, tabs, search, grouped sidebar, Form/ScrollList widgets | Integrate polished AI pages into hub. Avoid another separate competing window. |
| `tools/test.ps1` | Runs Lua suite and Python companion tests when available | Update to fail closed if Python is required but absent in AI release validation. |

**Important state distinction:** This inspection verifies source code and recent commits, NOT a successful local full-test run or passing production game-client integration. The `main` branch recently merged communications hardening and installer rollback, but AI provider adapters and seamless in-game AI transport are NOT present in reviewed code.

**Repository references:**
- https://github.com/LackOfSkillz/OAR/blob/main/addon/Outrider/Modules/WhatNow.lua
- https://github.com/LackOfSkillz/OAR/blob/main/addon/Outrider/Advisor/Snapshot.lua
- https://github.com/LackOfSkillz/OAR/blob/main/addon/Outrider/Advisor/AdviceLoader.lua
- https://github.com/LackOfSkillz/OAR/blob/main/addon/Outrider/Modules/Advisor.lua
- https://github.com/LackOfSkillz/OAR/blob/main/companion/outrider_companion/server.py
- https://github.com/LackOfSkillz/OAR/blob/main/companion/outrider_companion/store.py

## 2.1 Existing technical constraints

- WoW Lua addon has no general-purpose HTTP/network access to an LLM; companion and addon must use a verified explicit transport.
- SavedVariables are persisted on logout or reload, not instantly writable for live external read.
- New addon files/TOC additions normally require client restart; do not assume arbitrary changed files are hot-loaded.
- Classic game data may differ from new Forever content; preserve source, verification build/date and confidence.
- The addon must not send information to another player or remote server without player opt-in; all sharing defaults off.
- Avoid Lua 5.1-incompatible syntax and unsupported game APIs. Consult `docs/PROBE_RESULTS.md`, never guess.
- Preserve core idle memory/performance budgets and avoid continuous high-frequency polling.

---

# 3. COMPETITIVE RESEARCH: DESIGN TO SURPASS, NOT CLONE

**Verified online on 2026-11-15 (advertised features, not independent benchmarks):**

| Project | Capabilities to match or exceed | Outrider's differentiated answer |
|---|---|---|
| NeverQuestAlone | BYO Claude/OpenAI/Gemini/Grok/local providers, in-game chat, automatic quest routing, privacy controls, signed desktop installer | More grounded cross-module planning; evidence ledger; gear/profession/dungeon/family intelligence; local-first; no hidden action. |
| Wisp AI | In-game quest/gear/trainer help and character-grounded questions | Richer structured planning and answer provenance. |
| AI Agents Chat / wow-ai | In-game communication with desktop coding agents and character context | Domain-specific, game-knowledge-first, constrained tools rather than arbitrary agent shell access. |
| WarcraftForever.com MCP | Read-only class, item, spell, recipe and reference catalogs | Optional external reference plugin to augment native Outrider observations. This is a third-party fan site, not an official Blizzard endpoint. |
| Existing non-AI all-in-one addons | Broad maps, gear, dungeons, professions and UI | Unified explanations and cross-feature action plans; quality over feature count. |

Reference links:
- https://neverquestalone.com/build/docs/architecture
- https://github.com/tommygeoco/neverquestalone
- https://www.curseforge.com/wow/addons/wisp-ai
- https://github.com/chelinho139/wow-ai
- https://warcraftforever.com/developers/ai/

**Competitive requirement CR-01:** Create a repeatable benchmark dataset rather than claiming superiority based on feature count. Compare 25 common questions with two competitors on accuracy, freshness, completion, privacy friction and time-to-use. Attribute what was actually tested vs merely advertised. Do not copy their copyrighted art, source or UX designs wholesale.

---

# 4. PROPOSED SYSTEM ARCHITECTURE

```
[WoW Forever / Outrider Lua]
  Hub > Ask | Plan | Compare | Sources
  WhatNow / Journey / GearScore / Dungeons / Professions / Prices / Rare logs
  Snapshot v1 -> Context v2 -> AdviceLoader v1/v2 -> User-approved UI actions
          |
          | EXPLICIT, VERIFIED TRANSPORT
          | Phase 1: OTR1 copy/paste (works now)
          | Phase 4: OPTIONAL experiment (must pass policy/API gates)
          v
[Outrider Companion - Python, runs outside the game]
  Context assembly / privacy / source catalog / planner / result validator
  Provider router --------------> Local OpenAI-compatible API (Ollama/vLLM/LM Studio)
      |                              Cloud: OpenAI / Anthropic / Gemini / others
      |
      +-- Local MCP server (current server.py expanded)
      +-- Optional vetted read-only MCP reference sources
      +-- Human-readable evidence ledger and metrics (local-only default)
          |
          v
[Structured answer + ranked candidate references + evidence IDs]
          |
      Re-validate and require user click in addon
```

## 4.1 Trust boundaries (non-negotiable)

1. **Game boundary:** Lua may collect only client-permitted, non-secret data. It does not call HTTP or run external programs.
2. **Companion boundary:** Python process may read configured SavedVariables and approved reference data, and write only the validated Advisor/Advice output through existing safe interfaces. Do not give the model direct filesystem access.
3. **Model boundary:** Any model output is untrusted. Provider tool-calling requests go through an orchestrator and allowlisted read-only tool dispatcher; model text is NOT executable Lua.
4. **External MCP boundary:** Remote servers supply untrusted reference data only. Whitelist approved servers by identity and exposed tools, constrain URLs and timeouts; require explicit connection consent.
5. **User action boundary:** User clicks in-game actions; no model or companion-initiated gameplay actions.

## 4.2 Proposed Python structure (adapt to current package, do not prematurely create every file)

```
companion/outrider_companion/
    server.py               # existing MCP server, retain stdio compatibility
    store.py                # existing SavedVariables reader
    advice.py               # existing validated output writer
    codes.py                # existing OTR1 codec
    intelligence/
        models.py           # typed request/response/context schemas
        context.py          # filtered, bounded data/context assembler
        provenance.py       # sources, timestamps, evidence IDs
        provider_base.py    # provider interface, errors, retries, usage
        providers/
            openai_compatible.py  # first adapter: local vLLM/Ollama/LM Studio
            openai_api.py         # cloud adapter if actual API differs
            anthropic.py          # phase 3
            gemini.py             # phase 3
        tools.py            # allowlisted read-only domain tools
        planner.py          # deterministic plan feasibility and dependencies
        orchestrator.py     # ask -> retrieve -> model -> validate -> result
        privacy.py          # data minimization, redaction, approval
        budget.py           # usage accounting and cost controls
        sessions.py         # bounded local chat history, TTL, clear-all
        bridge.py           # interface for explicit transport strategies
```

Do not turn `companion/run.py` into a large application entrypoint; preserve its job as a stdio MCP launcher. New direct-ask CLI/desktop UX may use a separate entrypoint.

## 4.3 Proposed Lua changes

```
addon/Outrider/Advisor/
    Snapshot.lua             # additive schema v2 / explicit context selection
    AdviceLoader.lua         # backward-compatible v2 result schema
    Advice.lua               # data only; keep v1 fallback
addon/Outrider/Modules/
    Advisor.lua              # upgrade existing tab to Ask / Plan / Compare / Sources
    WhatNow.lua              # expose candidate IDs, provenance, dependencies
addon/Outrider/UI/
    Pages.lua / Hub.lua      # reuse hub and theme; don't fork the UI system
```

If a future verified bridge requires addon resource pools, it must have a self-contained threat model, kill switch, file count and memory budget; no bridge-specific code in core Lua while the experiment is unapproved.

---

# 5. DATA CONTRACTS AND PROVENANCE

**Core rule:** Numbers, item IDs, quest IDs, map IDs, location coordinates and requirements come from validated data, not LLM imagination.

## 5.1 ContextEnvelope v2 (additive to existing snapshot v1)

Illustrative contract. Field names must be finalized with compatibility tests before implementation:

```json
{
  "schema": 2,
  "requestId": "locally-generated-opaque-id",
  "snapshotId": "opaque-id",
  "takenAt": 1794740000,
  "gameBuild": "1.60.1",
  "character": {
    "anonId": "char-2",
    "class": "HUNTER",
    "level": 15,
    "faction": "HORDE",
    "realm": null,
    "name": null
  },
  "goal": "level",
  "timeBudgetMinutes": 45,
  "currentZone": {"mapID": 1, "name": "Example Zone", "verified": false},
  "candidates": [
    {
      "candidateId": "quest:12345",
      "kind": "quest",
      "entity": {"type": "quest", "id": 12345},
      "benefit": 0.7,
      "estimatedMinutes": 12,
      "requirements": ["level>=12"],
      "evidenceIds": ["local:quest-log:12345"],
      "confidence": "observed"
    }
  ],
  "sources": [
    {"evidenceId": "local:quest-log:12345", "origin": "wow-client",
     "kind": "quest-log", "observedAt": 1794740000,
     "verifiedBuild": "1.60.1"}
  ],
  "privacy": {"shareCharacterName": false, "shareGuild": false, "shareOtherPlayers": false}
}
```

Values are illustrative, NOT real Forever game IDs or coordinates. Do not copy example values into static data packs.

### Required fields

- `requestId`, `snapshotId`, `schema`, `takenAt`, `gameBuild`, `goal`.
- Per candidate: stable ID, source type, source timestamps/provenance, relevant eligibility facts, confidence state, and restrictions/unknowns.
- Structured source evidence ID never points directly to a user-controlled file path.
- `modules` remain independently optional; missing data cannot crash the answer flow.

### Size and freshness

- Preserve the current 50 KiB in-game snapshot ceiling unless measured in-game evidence supports a change. Use task-specific context selection, not complete history dumps.
- Companion sources can retrieve additional local context from allowlisted stored records, capped by token/byte budgets.
- Any location/quest/gear-dependent advice must be linked to the snapshot ID and become clearly **stale** when materially relevant state changes or a new snapshot is requested.
- Historical prices include timestamp and source; never present aged price samples as current market quotes.
- Mark classic-derived game records explicitly as **unverified for Forever** unless field-tested.

## 5.2 Evidence and confidence rules

Use categorical labels as the main UI representation:

1. `observed`: directly recorded on this game build with time and actor-independent evidence.
2. `verified`: curated source confirmed against the current game build.
3. `community`: named external source with retrieval timestamp; possibly outdated.
4. `inferred`: derived estimate from documented inputs (travel/time/profit/etc.).
5. `unknown`: missing, stale, conflicting, or unsupported.

Do not invent "92% confidence" from a model's feeling. If a numeric confidence is displayed, define and validate a calibration method separately. The UI must explain why an estimate can be wrong.

## 5.3 AnswerEnvelope v2

Illustrative contract:

```json
{
  "schema": 2,
  "requestId": "locally-generated-opaque-id",
  "answersSnapshotId": "opaque-id",
  "type": "plan",
  "headline": "A useful route for your next 45 minutes",
  "summary": "Complete two nearby errands, then visit the trainer.",
  "assumptions": ["travel time estimated from known transport routes"],
  "sources": ["local:quest-log:12345", "local:trainer:nearby"],
  "plan": [
    {"stepId": "step-1", "candidateId": "quest:12345", "why": "nearby XP",
     "estimatedMinutes": 12, "dependsOn": [], "evidenceIds": ["local:quest-log:12345"],
     "action": {"kind": "open_panel", "panel": "journey"}}
  ],
  "alternatives": [],
  "limits": ["dungeon availability not verified"],
  "generatedAt": 1794740001,
  "provider": {"label": "Local model", "model": "user-selected"}
}
```

The response is separate from the existing `Advisor/Advice.lua` v1 format. Implement a **backward-compatible v2 parser** so `v1` codes and shipped advice still work. The response parser must reject unsupported actions and unknown `candidateId`s; cross-check `requestId` and snapshot identity. Only the *validated user-facing subset* reaches Lua.

## 5.4 Source registry

Minimum schema: `sourceId`, origin (`game`, `Outrider`, `external-MCP`, `curated`), entity type/ID, game build, observed/retrieved time, verification state, reliability notes, redistribution/licensing notes. Maintain per-source TTL and conflicts. Never silently merge contradictory facts.

---

# 6. AI + MCP: HOW THE PIECES REALLY FIT

MCP is the tool interface used by AI clients. It does not automatically call arbitrary model APIs. The companion needs **both** a provider routing layer and a tool/context service.

## 6.1 Model provider interface

Implement a small stable interface (illustrative Python pseudocode):

```python
class ModelProvider:
    def validate_config(self) -> dict: ...
    def healthcheck(self, timeout_seconds: float) -> dict: ...
    def generate(self, messages, tools, *, max_output_tokens, timeout_seconds) -> dict: ...
    def estimate_cost(self, usage) -> dict: ...
```

Required behaviors: cancellation, hard timeouts, bounded retries with backoff, provider-specific error classifications, context-window budgeting, optional streaming to companion UI, token accounting, no automatic fallback to a paid provider, and a deterministic fake provider for tests. Do not rely on model provider supporting tool calls; support orchestrated retrieval + model completion as fallback.

### Adapter rollout

- **Provider P1:** OpenAI-compatible HTTP API for local vLLM, Ollama, LM Studio, and custom endpoints. URL is user-controlled in settings; no hardcoded LAN endpoint.
- **Provider P2:** Native OpenAI API if needed; native Anthropic; native Gemini. Different message/tool/stream formats hidden behind adapter interface.
- **Provider P3:** Additional OpenAI-compatible clouds or native adapters by demand. Never promise all providers share the same feature set.
- **Offline fallback:** deterministic Pathfinder and knowledge views without any model.

### Local network security

- Default connection to `http://127.0.0.1` only for local providers; any LAN or Internet URL must be explicitly configured, tested and shown to the user.
- Reject `file://`, local executable paths and unapproved schemes in provider settings. Avoid automatically following redirects to new hosts.
- No unauthenticated HTTP listener on `0.0.0.0`; companion desktop IPC must be loopback-only and protected by an unpredictable session token if used.
- Provider API keys in Windows Credential Manager / OS keychain (or platform-appropriate secure store); never in SavedVariables, exported codes, logs, or plaintext repo config.
- State clearly that a local AI on a different LAN machine is **not** private to this PC; data travels to that machine.

## 6.2 First-party MCP tool set (read-only unless explicitly described)

Retain existing tool names and signatures, then introduce versioned tools:

| Tool | Inputs | Return | Scope |
|---|---|---|---|
| `get_character_context_v2` | character, field set | Sanitized latest snapshot, provenance | Read |
| `get_pathfinder_candidates` | character, goal, max_results | Scored candidates and eligibility inputs | Read |
| `get_candidate_explanation` | candidate ID, character | Why/where/what/unknowns | Read |
| `get_quest_context` | IDs or bounded search | Relevant known quest state and chains | Read |
| `get_gear_opportunities` | character, max_results | Class-weighted upgrades, locations, prerequisites | Read |
| `get_dungeon_opportunities` | character, max_results | Availability, gear, entrances, group/quest requirements | Read |
| `get_profession_options` | character, skill target | Known recipes, bag materials, estimated cost and stale price flags | Read |
| `get_gold_options` | character, duration | Measured/estimated money methods, confidence | Read |
| `get_rare_evidence` | NPC ID | Sightings, layer and timestamp; sparse-data warning | Read |
| `get_family_resources` | character, explicit opt-in | Allowed shared gear/profession/material summaries | Read |
| `get_source_evidence` | evidence IDs | Provenance records and conflicts | Read |

**Tool rules:** strict JSON schemas, bounded collections (default <= 20 records per call), fixed character access, no unrestricted path read, no shell/command execution, no arbitrary fetch URL, no world-knowledge upload without explicit user opt-in. Sanitize player names before cloud transmission by default. Preserve original existing tools as stable aliases.

## 6.3 Optional external reference MCPs

- Create a small allowlist-based read-only connector interface. First spike: `https://warcraftforever.com/mcp` for reference catalogs, if approved after checking license, source, accuracy, limits and uptime. Treat it as independent fan-sourced reference data, not canonical Blizzard authority.
- Extract structured records, not entire HTML or uncontrolled prompts. Record retrieval time and original source identity.
- Cache bounded results locally and surface "reference unavailable" without failing the core experience.
- Never allow a reference MCP to execute tools on Outrider, install another server, read local credentials, or choose data exfiltration destinations.

## 6.4 Orchestration pipeline

`user question -> classify intent -> select narrow data -> fetch validated tools -> synthesize candidate answers -> deterministic feasibility/evidence checks -> provider explanation -> response schema validator -> safe user-facing output`.

The model can *propose* an ordering, explain trade-offs and ask for a preference. **Deterministic code** must enforce eligibility, available time, travel feasibility, data freshness, action whitelists and invalid item/quest/map IDs.

For a question that can be answered exactly from current Outrider data, prefer a direct answer without a paid model call. Example: "How many copper bars are in my bags?" should be a local structured query when available.

---

# 7. HIGH-VALUE USER EXPERIENCES

## UX-01: Ask Outrider

- In Hub, show `Ask` with text field, character summary, model badge and a clear "Send" action. Distinguish local/offline, companion unavailable, cloud-enabled, and stale data states.
- Show concise answer (2-5 sentences), sources as clickable expandable rows, then action cards if supported.
- Offer safe starter prompts: "What should I do next?", "Better gear?", "How can I earn gold?", "What dungeon should I run?".
- Support `Copy context`, `Paste answer`, `Retry`, `Refresh context`, `Show sources`, `Clear history`, `Why this advice?`.
- No dependency on a live bridge for the first release.

**Acceptance:** user can ask and receive a grounded answer from a configured local model using current copy/paste transport with no `/reload`; with AI disabled, previous WhatNow experience still works.

## UX-02: Adventure Plan (flagship)

- Player selects goal: Level / Gold / Gear / Professions / Explore / Balanced.
- Player selects a time budget: 15 / 30 / 60 / 90 minutes / Custom.
- Display 3-5 steps each with estimated time, value, prerequisites, alternate and data confidence.
- Combine nearby errands, quests, gathering and upgrades when the Travel graph knows a route. Only rank feasible segments; no fabricated travel precision. Group dungeons separately when they require a party.
- `Why this sequence?` summarizes travel savings and dependencies using validated inputs.
- `Use this plan` stores a local plan, not a macro. `Next waypoint` is an explicit player click. `Skip`, `Done`, `Recalculate` always work without an AI call.
- Plans update on requested refresh or relevant state change; avoid noisy automatic replanning. Preserve completed steps.

**Acceptance:** four character personas with different goals produce different feasible plans. A route that requires unavailable transport is excluded or labeled unreachable, not silently assumed feasible. Nothing triggers movement or protected actions.

## UX-03: Compare

- Compare two player-selected options: two dungeons, two items, quest route vs gathering route, craft vs buy, etc.
- Present a two-column `Option A | Option B` view with **quantified known inputs** and **unknowns**. Never invent item prices, travel times, drop odds or boss availability.
- Show recommendation and break-even assumptions. Allow "Choose A" or "Choose B" only to set a local goal/waypoint in permitted contexts.

**Acceptance:** same inputs generate a stable deterministic comparison table; the AI may add explanation, never overwrite measured fields.

## UX-04: Character progression strategist

- "What should I prepare for the next five levels?" uses future usable items, class trainers, known costs and available dungeons, without claiming unverified class talent behavior.
- Group results into **Now / Soon / Later**. Show prerequisites, and link to class/profession/gear modules.
- For any talent system data not yet exposed by client API, add probe cases first and report unknown.

## UX-05: Profession and economy coach

- Recommend cheap known skill-up paths and material procurement options, with clear stale-price badges.
- Show inventory material coverage across opted-in alts, recipe dependencies and vendor alternatives.
- Highlight price-source quality (self-scanned today vs old scan vs third-party guide); account for AH fees when known.
- No purchase/post/craft initiated by the companion or model. User-clicked existing UI actions only.

## UX-06: Family coordination

- Opt-in panel with exactly what is shared, a preview, and a revocation switch.
- Read family gear cards and profession summaries already permitted by Outrider, not other players' private data.
- AI can recommend that a player ask someone to craft a piece, not automatically send messages or items.

## UX-07: World knowledge and rare research

- Explain location with source/time/build and negative evidence (e.g., no recent observation; layer unknown).
- Never infer a confident respawn deadline from 1-2 sightings. Warn on cross-layer incompatibility.
- User can provide feedback `Found it`, `Wrong location`, `Not useful`, helping calibrate source reliability locally.

---

# 8. USER INTERFACE / USER EXPERIENCE DESIGN

This spec is intentionally compatible with the existing 900x640-ish Hub, grouped sidebar, theme tokens and recent incoming artwork. The goal is an **Expedition Console**, not a second giant interface.

## 8.1 Navigation

Within the existing Outrider Hub:

- Primary `What now?` remains the fast, deterministic default.
- `Intelligence` is a feature tab/section (visible only if explicitly enabled), with internal `Ask`, `Plan`, `Compare`, `Sources` views.
- `Settings > AI`: Model provider / connection / privacy / data preview / budget / experimental bridge.
- `Status`: local companion status and last successful snapshot. Do not show meaningless reconnect spinners without a live transport.

## 8.2 Key panels

```
+----------------------------------------------------------------------------+
| OUTRIDER    [Character / class / level / zone]  Search...        [Status] |
+-------------+--------------------------------------------------------------+
| Home        | INTELLIGENCE   [Ask] [Plan] [Compare] [Sources]            |
| What now?   | [Ready: Local model] [Snapshot: 2 min old]                 |
| Explore     | ---------------------------------------------------------- |
| Character   | Ask about your character, quests or plan:                  |
| Town        | [ How do I spend my next 45 minutes?                   ] |
| Social      | [Ask]  [Use current character data]  [Privacy preview]    |
| Intelligence| ---------------------------------------------------------- |
| Settings    | "Prioritize these three nearby activities..."             |
|             | [STEP 1] quest / location / evidence / Go                  |
|             | [STEP 2] trainer / known cost / evidence / Go              |
|             | [STEP 3] gather / route / estimate / Go                    |
|             | [Why?] [Alternatives] [Use as plan] [Copy]                 |
+-------------+--------------------------------------------------------------+
```

## 8.3 Visual standards

- Reuse existing Outrider dark blue-teal/gold palette and available art assets; add no Blizzard IP. Create new images only if already specified by the owner.
- Source chips: **Observed / Verified / Community / Estimated / Unknown**; color + textual label, never color only.
- UI state chips: **Ready / Waiting / Offline / Stale / Privacy mode**.
- Primary action gold and infrequent; secondary actions subdued. Avoid making every row look equally important.
- Readable at 860x520 minimum; no clipped content at current resize bounds; adapt to compact view by hiding side illustrations before hiding essential text.
- Hover tooltip explaining evidence, timestamps and missing data.
- Keyboard-driven search, escape-to-close, coherent focus and no mouse-only essential feature.
- All model requests cancellable from companion UI; no runaway calls from repeated clicks.
- No automatic opening of chat while in combat, no full-screen overlays, and no high-frequency animation.
- Do not confuse a content/source confidence badge with a model confidence score.

## 8.4 Example answer display

Question: "Should I run Deadmines now?"

**Recommendation:** "Only if you already have a group and can reach its entrance. Your available quests nearby may be a better short-session option."

**Why:** "Outrider identifies [X] potential class upgrades in dungeon data, but that loot source is currently unverified for this Forever build. Your nearest accepted quests are [Y] estimated minutes away."

**Sources:** "My gear (observed today) | Dungeon loot pack (Classic-derived, unverified) | Journey travel estimate (inferred)"

**Options:** `Plan dungeon` `See nearby quests` `Explain the uncertainty`

Use actual model-driven values at runtime only, never the bracketed example strings as hard-coded gameplay claims.

---

# 9. TRANSPORT ROADMAP (THE HARDEST PART)

The companion cannot magically inject a reply into Lua. Keep transport separate from intelligence.

## Transport A: Existing OTR1 copy/paste (RELEASE 1)

Already implemented for single snapshots and advice. Extend it to bounded narrative and plan results with matching IDs and checksums. Flow: `/ride ask` -> Ctrl+C -> companion or model invocation -> advice code -> paste into Advisor -> user clicks. No runtime game file access required, no reload.

**Gate:** End-to-end in-game user test succeeds; backward compatibility with existing code and no dropped secrets.

## Transport B: Desktop companion interface (RELEASE 2)

A tiny Windows companion with selected provider, ask field, history, data preview and `Copy response`/`Copy for Outrider` actions. This can feel seamless at the desktop level without promising automatic in-game responses. Packaging must be independently optional and support clean uninstall. Consider an OS system tray app only if maintenance overhead is justified.

**Gate:** installation, trusted packaging, version negotiation, secure key storage, and accessibility verified. This is the supported model-provider onboarding experience even when in-game bridging is disabled.

## Transport C: Optional in-game seamless bridge (EXPERIMENT ONLY)

Investigate documented and observed patterns from NeverQuestAlone and AI Agents Chat: optical UI capture, preinstalled load-on-demand resources, other compliant user-initiated mechanisms. Evaluate with a risk matrix:

| Candidate | Feasibility proof required | Main risks |
|---|---|---|
| Explicit clipboard round trip | Already works | Manual friction; clipboard privacy |
| Screen-rendered encoded request + user-consented capture | Verify Forever client output/capture, accessibility and UI footprint | Screen capture permissions, anti-cheat/policy perception, decode corruption |
| Preinstalled load-on-demand reply resources | Verify APIs, loading behavior, game file freshness, memory/resource counts and updates | Disk I/O constraints, client limits, policy uncertainty |
| Audio-/resource-based signaling | Verify client supports technique on pinned build, user consent and policy | Fragile version behavior; possible abuse or violation |

### Bridge strict release gate

- No memory reading, DLL injection, hooks into game process, input synthesis, packet inspection, unsupported game APIs, or anti-cheat evasion.
- Document exact mechanism and provenance of client API support; obtain policy/legal review when behavior is uncertain.
- Fresh data and responses must have request ID, sequence, length, checksum, time-to-live, character binding and replay protection.
- All transfers are bounded. Must fail closed without crashes, UI disruption, taint or data loss.
- Player must explicitly enable transport and be able to disable it instantly. If no verified compliant transport is found, **do not ship the feature**; use copy/paste and desktop UI.

**Never promise 'no alt-tab' until Transport C has passed real-client and compliance gates.**

---

# 10. SECURITY, PRIVACY AND POLICY

## 10.1 Threat model

Adversaries: malicious remote MCP servers, malicious game chat/quest text within data, prompt injection, tampered local provider endpoints, overshared private character data, compromised companion, and corrupted/oversized output codes.

### Mandatory controls

- Model never sees raw SavedVariables files or arbitrary paths. Provide only a sanitized, typed data subset.
- Data preview before first remote call; controls for character name, realm, guild, location, other player info, bank/inventory, session history. Default names/realm/guild/other players OFF.
- User must explicitly enable cloud access; no silent cloud fallback from a local model.
- Per-request provenance and an audit record: selected fields, sources, model label, token usage, time, validation outcome (not raw credentials or chat secrets).
- Secret management: OS credential store; no API key in addon, config committed to GitHub, clipboard snapshot, or exported log.
- Strict model output schema validation and length caps; reject unknown IDs, panel names, actions, malformed URLs, embedded WoW color codes and untrusted markup.
- Whitelisted, read-only external MCP tools with individually approved server identities, timeouts and results size limits.
- Treat reference content and MCP descriptions as untrusted. No instruction from external data can expand allowed tools/permissions.
- Rate limits, daily/monthly provider spend caps, call count limits, confirmation before a large request, and user-facing usage display. No automatic retry after a spend cap.
- HTTP endpoint redirect protections; optional network egress allowlists for packaged companion.
- No auto-update of model adapters or external scripts without signed/verified release process.
- Avoid storing raw prompts by default; configurable short retention; clear-all must actually delete the local file/cache.
- Document exactly what data remains on PC, LAN or leaves to provider; disclose API provider billing and model limitations.

## 10.2 Blizzard policy and game restrictions

- All addons distributed free; addon code visible to public; no ads or in-game donations. Review the license status for Outrider's own code and QuestieDB-derived packs before broad public release.
- Never require a paid AI provider to use basic Outrider or core addon functionality. Any third-party API costs are paid directly to that provider and clearly separated.
- No automation of actions or protected combat API manipulation.
- No aggressive game messaging, unnecessary disk loading or framerate regressions.
- Policies and client behavior may change; recheck on each relevant game update.

Primary policy: https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534
Security baseline: https://cheatsheetseries.owasp.org/cheatsheets/MCP_Security_Cheat_Sheet.html

---

# 11. IMPLEMENTATION PHASES AND MICRO-TASKS

Do **not** implement all phases in one giant PR. Each phase gets a change list, automated tests, real-client notes and a gate report.

## PHASE AI-00 - Baseline and feasibility (P0, mandatory)

- [ ] **AI00-01** Check current main HEAD; record recent commits, branches, merge differences, project test counts and current release state.
- [ ] **AI00-02** Inventory `Advisor`, `Snapshot`, `AdviceLoader`, `WhatNow`, `Journey`, `Travel`, `DungeonGuide`, `GearScore`, `Professions`, `Prices`, `KitShare`, Hub and companion. Produce a source-of-truth feature matrix (present / partial / missing / unverified).
- [ ] **AI00-03** Run `tools/test.ps1` (Lua + Python), then companion tests directly. Capture command, environment and passing/failing count. Fix *pre-existing failures* in a separate commit only with clear rationale.
- [ ] **AI00-04** Capture current SavedVariables/OTR1/Advice examples as scrubbed test fixtures. Confirm compatibility without embedding personal names or real account paths.
- [ ] **AI00-05** Review actual API probe results and avoid assumptions about real-time file access; inspect policy and competitor bridge implementations only for feasibility.
- [ ] **AI00-06** Define privacy defaults, unsupported data types, performance and size budgets. Document exclusions in test fixtures.
- [ ] **AI00-07** Draft `docs/OUTRIDER_INTELLIGENCE_ARCHITECTURE.md`, `docs/OUTRIDER_INTELLIGENCE_TASKS.md`, `docs/AI_PRIVACY_AND_TRANSPORT.md`.

**Gate AI-G0:** Baseline reproducible, current modules mapped, risks logged, no existing working functionality removed.

## PHASE AI-01 - Reliable grounded data (P0, first implementation)

- [ ] **AI01-01** Define ContextEnvelope v2 in Python and additive Lua export metadata; preserve v1 OTR1 and Advice.lua readers.
- [ ] **AI01-02** Add optional `Snapshot()` providers where existing modules do not expose enough bounded data: WhatNow candidate IDs/rank/why; dungeon next tier; gear opportunities; profession plan inputs; travel feasibility and price sample ages.
- [ ] **AI01-03** Add stable evidence/source IDs and game-build/time verification fields. Avoid new global database duplication.
- [ ] **AI01-04** Build local read-only tool interfaces and strict bounds; map them to existing module-owned data and `store.py`.
- [ ] **AI01-05** Build privacy redactor and per-source field permission matrix; show sample payload for user approval.
- [ ] **AI01-06** Build answer/plan validator that refuses unknown entity IDs, mismatched snapshot IDs, coordinates not sourced from validated records, unknown actions and stale requests.
- [ ] **AI01-07** Tests: duplicate keys, malformed strings, deep tables, huge payload, stale data, missing optional modules, wrong character, unknown item, NPC ID collisions, classic/Forever conflict, empty quest log.

**Gate AI-G1:** 100% malicious/invalid fixture outputs rejected, character and snapshot binding preserved, source labels correct, all existing v1 fixtures accepted.

## PHASE AI-02 - First model vertical slice (P0)

- [ ] **AI02-01** Implement `ModelProvider` and OpenAI-compatible local adapter; test Ollama, a local vLLM endpoint and a fake provider. Allow user-configured model and base URL.
- [ ] **AI02-02** Add robust timeouts, structured errors, cancellation, bounded retries, token context budget, spend-guard interface, no silent cloud fallback.
- [ ] **AI02-03** Implement orchestrator intent -> narrow tool query -> evidence -> model synthesis -> deterministic validator.
- [ ] **AI02-04** Add a direct CLI companion command for manual questions that uses the current copy/paste snapshot and returns validated Outrider answer codes (existing MCP stdio entrypoint stays intact).
- [ ] **AI02-05** Extend AdviceLoader v2 for textual `answer`, `plan`, `sources`, `limits`, alongside existing safe action rows. Avoid opening any protected frame automatically.
- [ ] **AI02-06** Upgrade Advisor tab with prompt, source display and fallback copy/paste flow. A user can use any selected local model on an out-of-combat snapshot.
- [ ] **AI02-07** Tests: direct answer, plan, unknown question, model outage, schema mismatch, poisoned response, prompt injection in quest title, provider timeout, token cap, cancelled request, clipboard corruption.
- [ ] **AI02-08** Real client: hunter, warrior and mage with different quests/gear; measure question-answer loop and ensure no `/reload` needed for copy/paste.

**Gate AI-G2:** At least one local model and full addon-to-companion-to-addon round trip works with no code execution, no hidden remote requests, and no protected actions. Existing no-AI behavior unchanged.

## PHASE AI-03 - Adventure Plan, Compare, and knowledge (P1, flagship)

- [ ] **AI03-01** Expose a deterministic plan evaluator: requirements, travel estimates, accessibility, candidate benefit, dependencies, duration and alternatives.
- [ ] **AI03-02** Add time budget and goal-aware planning over 3-5 candidates; test candidate combination and ordering against baseline WhatNow.
- [ ] **AI03-03** Add source provenance UI and refusal/uncertainty messages for unverified zones, dungeons, drop tables and rare timers.
- [ ] **AI03-04** Build `Compare` schema + UI for equipment, dungeon vs quest, craft vs buy, gold routes with measurable inputs.
- [ ] **AI03-05** Add user feedback (`useful`, `not useful`, `wrong data`, `completed`) keyed by candidate/evidence ID, with local storage and opt-in sharing only.
- [ ] **AI03-06** Add goal profile persistence per character and plan state (not auto-completing unless based on allowed explicit evidence and verified).
- [ ] **AI03-07** Tests: unreachable destination, party requirement, missing funds, old prices, mutually exclusive quests, incomplete chains, changing character, dungeon not yet released.
- [ ] **AI03-08** In-game usability review at 860x520/900x640/1400x1000, across classes, with screenshots and before/after benchmark.

**Gate AI-G3:** The AI plan never claims a game action or requirement it cannot validate; at least 90% of evaluation personas receive a useful or honest "insufficient data" result, and users can explain or dismiss every step.

## PHASE AI-04 - Cloud provider flexibility and MCP robustness (P1)

- [ ] **AI04-01** Integrate native OpenAI/Anthropic/Gemini provider adapters where needed, preserving local adapter as default choice. Include provider capability checks.
- [ ] **AI04-02** Configure Windows Credential Manager/OS secret storage, consent to send data, data preview and spend caps.
- [ ] **AI04-03** Extend `server.py` read-only MCP tools with versioned schemas; keep old clients supported.
- [ ] **AI04-04** Add approved external read-only MCP connector spike, no global arbitrary-server install UI. Cache and mark third-party reference quality.
- [ ] **AI04-05** Ensure offline deterministic answers and tool errors are not treated as model-generated facts.
- [ ] **AI04-06** Build transparent provider configuration/status/diagnostics view, with exact tests for wrong keys, wrong model name, TLS errors, disabled network, quota exceeded, local server down.
- [ ] **AI04-07** Benchmark 25 fixed questions across at least two local and two cloud providers when available; record measured costs/latency/answer accuracy, not marketing claims.

**Gate AI-G4:** Local, cloud and no-AI modes gracefully coexist. No credential or personal identifier leaks in tests/logs. Third-party MCPs never gain write or arbitrary host access.

## PHASE AI-05 - Seamless transport feasibility spike (P2, OPTIONAL)

- [ ] **AI05-01** Write game-client/API/policy feasibility matrix for transport A/B/C from Section 9; obtain explicit owner approval before risky experiments.
- [ ] **AI05-02** Implement one isolated bridge prototype on a feature branch if compliant evidence exists. No network/companion tool from Lua; no memory inspection.
- [ ] **AI05-03** Verify accurate frame bounds, message max size, CRC/checksum, sequence, nonce, expiry, replay protection, character binding and reset after disconnect.
- [ ] **AI05-04** Test protected-combat conditions, anti-taint, addon resource limits, FPS, reload/client restart, screen scaling, window mode, laptop/multi-monitor.
- [ ] **AI05-05** Add opt-in toggle, kill switch, clear status, and fallback to copy/paste on any bridge fault.
- [ ] **AI05-06** Recheck policy and legal acceptance for public release. If inconclusive: keep experiment out of packaged builds.

**Gate AI-G5:** May release only after reproducible multi-machine, multi-client, policy and security signoff. It is acceptable and explicitly preferred to ship without this feature rather than use a questionable workaround.

## PHASE AI-06 - Release quality, polish, and adoption (P2)

- [ ] **AI06-01** Contextual onboarding with `Why AI?`, local/cloud privacy choices, and a sample question. No confusing 'Paste your ChatGPT subscription' prompt.
- [ ] **AI06-02** Integrated UI card polish consistent with Outrider art, dark theme, compact sizes and accessibility.
- [ ] **AI06-03** Full suite plus adversarial eval harness, Windows clean install, upgrade, rollback and uninstall tests.
- [ ] **AI06-04** Threat-model review, dependency scan, static checks, provider request log redaction and provenance review.
- [ ] **AI06-05** Documentation: provider guide, supported models, permissions, API costs, privacy, FAQ, user troubleshooting, limitations, source acknowledgments.
- [ ] **AI06-06** Public code/license compliance review for addon, data packs and optional companion. Do not publish protected names or files.
- [ ] **AI06-07** Closed family beta with consent; capture friction, incorrect recommendations, crash and taint logs; fix severity 1/2 before public release.
- [ ] **AI06-08** Tag version, build reproducible packages with checksums, check empty/default setup and optional companion uninstall. Publish only with owner approval.

**Gate AI-G6:** Public-release checklist completed, measurable usability improvement, no critical bugs, privacy/policy accepted and rollback verified.

---

# 12. QUALITY MODEL AND EVALUATION HARNESS

## 12.1 Golden scenario set

Build a deterministic set of at least **100** anonymized scenarios using synthetic or scrubbed SavedVariables and registered data packs. Every scenario must specify expected answer elements, permitted unknowns, prohibited claims and validation behavior.

Suggested distribution:

- 20 quest/route/progression (including starting zones and inaccessible transit).
- 15 gear/dungeon opportunities (including unknown loot and unreleased raids).
- 15 professions/auction/gold (stale prices, limited funds, absent recipes).
- 10 hunter rare/pet scenarios (different layers, incomplete sightings).
- 10 family/alt inventory and privacy-consent scenarios.
- 10 no-data/low-confidence/conflicting-source scenarios.
- 10 injection/security/unsupported-action scenarios.
- 10 transport, timeout, stale response and wrong-character scenarios.

## 12.2 Targets: release gates, not claims of current performance

| Metric | Release acceptance target | How measured |
|---|---|---|
| Unsupported game IDs/coordinates presented as valid | **0** | Validator unit tests and 100-case eval |
| Unauthorized actions, executable Lua, input automation | **0** | Security tests and game-client review |
| Cross-character context or answer leaks | **0** | Persona/test fixture isolation |
| False citation/source ID accepted | **0** | Evidence registry validation |
| User-visible factual recommendations with evidence or explicit uncertainty | **>= 95%** | Human-reviewed golden cases |
| Scenario usefulness or honest abstention | **>= 90%** | Blind review of 100 scenarios |
| Existing v1 snapshot/advice fixture compatibility | **100%** | Cross-language codec regression suite |
| Core addon functionality with AI disabled | **100% of baseline tests** | Lua mock suite and real-client smoke test |
| Average added idle Lua polling | **0 new continuous loops** | `/ride perf` and code review |
| Response time, local vs cloud | **Measure and publish p50/p95** | Timed test harness; do not assert guarantees until measured |
| Clean Windows installer / rollback | **100% on test matrix** | Clean VM, upgrade/rollback scenarios |

## 12.3 Real-client acceptance checklist

Test level-appropriate characters including Hunter, Warrior, Mage and at least one character with sparse quest data. Run in cities, dungeons (when appropriate), and areas with uncertain Forever world data. Verify no blocked-action popup, taint errors, protected combat API changes, impossible waypoints, empty unhandled cards, or UI overflow. Test after `/reload`, logout/login, full client restart, and companion off/on. Test with no AI model, local model down, no internet, wrong key, and out-of-date advice.

## 12.4 Automated tests and CI

- Lua mock client: `tests/spec/intelligence_context_spec.lua`, `intelligence_advice_v2_spec.lua`, `intelligence_ui_spec.lua`, `whatnow` regression.
- Python: `companion/tests/test_intelligence_context.py`, `test_providers.py`, `test_orchestrator.py`, `test_security.py`, `test_mcp_v2.py`, `test_contract_golden.py`.
- Cross-language contract fixtures: v1/v2 Lua export -> Python import -> validated Python export -> Lua import.
- Provider adapters tested against deterministic fake HTTP server, without spending API credits in CI.
- Release CI must NOT silently skip required companion tests if Python missing.
- Avoid touching private customer/player data in CI. Use redacted, synthetic fixtures only.

---

# 13. DELIVERY DEFINITION OF DONE

A task is **DONE** only when the following are present:

1. Code is integrated on a branch and no existing feature was silently removed.
2. Behavior is covered by automated tests and relevant fixture cases.
3. Data-contract changes are versioned and backwards compatible or explicitly migrated.
4. Lua feature uses allowed game APIs and respects combat and secret-value constraints.
5. Privacy/security consequences documented, including log fields and data sent remotely.
6. UI tested for readability, resizable layouts, and keyboard/mouse flows.
7. Real-client test evidence exists when game interaction is involved.
8. Known limitations and release status accurately reflected in README/CHANGELOG/TASKS.
9. Changes are committed in a reviewable chunk, not an unreviewed giant diff.
10. Gate report states **pass / fail / not verified**, without treating silence as pass.

### Required Claude Code deliverables per phase

- `What changed` summary with touched file paths.
- `Tests run` command log and actual result counts.
- `Client checks needed` with concrete in-game steps.
- `Risks / trade-offs / blocked APIs` section.
- Screenshot(s) for any UI work, with no real player names or private data in shared artifacts.
- Updated `docs/OUTRIDER_INTELLIGENCE_TASKS.md` status and next gated microtask.

---

# 14. FIRST IMPLEMENTATION SPRINT: EXACT ORDER

A sprint is a logical work unit, not a time estimate.

**Sprint 1 (minimum shippable vertical slice):**

1. Complete AI-G0 audit and baseline tests.
2. Define request/response schema using existing OTR1 transport, with source IDs and safe narrative text.
3. Implement an OpenAI-compatible **local model** provider with a dummy provider for tests. The model need not have MCP support; our orchestrator provides context.
4. Build a read-only `get_pathfinder_candidates` from the actual WhatNow candidate list.
5. Ask: "I have 45 minutes. What should I do?" and get a short, grounded answer + up to 3 safe action cards.
6. Show the answer in the existing Advisor Hub tab using copy/paste **without reload**. Never control gameplay.
7. Verify on the user's hunter and a second character, including unsupported/missing data.
8. Commit with test evidence. **STOP for review before starting a seamless bridge or cloud provider integration.**

**Sprint 2:** Better Plan and Compare cards; provenance/unknowns; short-lived local history; privacy preview; additional read-only MCP tools.

**Sprint 3:** Model setup UX, cloud adapters and secure credential storage; family/alt and economy planning with explicit consent.

**Sprint 4, optional:** Validate/possibly build seamless transport. If not compliant/verified, ship without it.

---

# 15. KNOWN RISKS / OPEN DECISIONS

| Risk/decision | Default for implementation | Evidence to change default |
|---|---|---|
| Live in-game messaging | **Disabled; manual copy/paste** | Experimental bridge passed API, policy, safety and multi-PC tests |
| Player names in AI requests | **Redacted** | User explicitly opts in for chosen provider |
| Provider choice | **Local first** | User selects cloud and accepts data preview/cost |
| AI mode with no internet | **Deterministic Outrider still works** | None |
| External MCP reference server | **Off** | User consents; trust/source/license vetted |
| AI-generated item/quest/map IDs | **Never trusted** | Already present in validated data registry |
| AI-generated coordinates | **Never trusted** | Validated original source provides exact same coordinates |
| Numerical 'AI confidence' | **Not shown** | Demonstrated calibrated empirical evaluation |
| Unverified rare respawn timer | **Show uncertainty** | Sufficient measured observations, same spawn/layer conditions |
| Model can call gameplay commands | **Never** | Non-goal; would require new explicit policy and user decision |
| Paid model support | **Optional user-supplied API credentials** | License/policy review and cost disclosure |
| Current Hub artwork | **Reuse when present** | Owner supplies additional licensed art |
| Third-party bridge source | **Review design, no source copying** | Compatible license and documented owner approval |
| Native macOS companion | **Not in initial scope** | Windows flow complete and stable |

---

# 16. SOURCES AND VERIFICATION NOTES

**Direct GitHub inspection:** private `LackOfSkillz/OAR` default branch commit `fc4e0e3` on Nov 15, 2026. Reviewed README, code paths in Section 2, companion server/store/advice/codes/tests, README, TOC and existing task/test infrastructure. Did not run the current repository tests locally, did not inspect private local SavedVariables, and did not modify/push any GitHub file.

**External documentation / competitor claims (retrieved 2026-11-15):**

- NeverQuestAlone: https://neverquestalone.com/ and https://neverquestalone.com/build/docs/architecture
- NeverQuestAlone source: https://github.com/tommygeoco/neverquestalone
- Wisp AI: https://www.curseforge.com/wow/addons/wisp-ai
- AI Agents Chat: https://github.com/chelinho139/wow-ai
- Third-party Forever MCP: https://warcraftforever.com/developers/ai/
- Blizzard UI Add-On Policy: https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534
- OWASP MCP Security Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/MCP_Security_Cheat_Sheet.html
- MCP Security notes: https://github.com/modelcontextprotocol/modelcontextprotocol/blob/main/SECURITY.md

Some competitor descriptions are advertisements and repository documentation, not independently observed behavior. The third-party Forever MCP reference is not Blizzard's official service. Security and policy guidance must be rechecked at implementation time.

---

# 17. ACCEPTANCE TEST SHOWCASE: THE FIVE-MINUTE DEMO

The demo should be possible on a freshly installed, safe, opt-in build:

1. Open Outrider on a level-appropriate character. WhatNow works immediately without AI.
2. Enable Outrider Intelligence, select the local provider, verify connection and preview what character fields will be shared.
3. Ask "I have 45 minutes and want better gear without traveling too far. What should I do?"
4. See a **short, tailored plan**: current items and known sources, two alternatives, useful explanations and visible uncertainty for unverified Forever data.
5. Select one **Go** action; it only sets a legitimate waypoint or opens an existing Outrider panel after the player's click.
6. Ask "Why not the dungeon?" and receive a grounded comparison with an explicit group/time prerequisite.
7. Turn the companion off. Outrider remains fully usable, with no error, lost profile, network traffic or protected-action warning.

**Product quality bar:** The player should say "It actually understands my character" rather than "It seems to be a generic AI chat box." That is the differentiator we are engineering.

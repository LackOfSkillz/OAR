# Outrider Intelligence 2.0 — Competitive Source-Code Audit
**Date:** 2026-11-18  
**Status:** Research and design recommendations only; no I2 feature implemented by this report  
**Outrider baseline:** `LackOfSkillz/OAR` `p1-foundation` at `a808b09e2be2362891f39387c6bdee5a5139f08b`  
**Scope:** Read public competitors' source files (not just product descriptions), compare to Outrider's current Lua/Python modules, and identify independent engineering ideas. No competitor code was copied, executed, installed or deployed.

## Executive decision
**The market already has two credible WoW Forever in-game AI competitors.** Wisp AI and thott.bot chat offer live assistant experiences. Outrider cannot rely on "LLM access inside WoW" as its differentiator. The better differentiator is a *reliable proactive decision engine* that works with **no model, no subscription, no desktop process and no live bridge**: one justified recommendation, at most two alternatives, correct class/role eligibility, verified source identity, sound gold math and feedback.

**Keep D18/I2-09 blocked.** Both competitors' source trees use novel addon-state communication channels (enabled/disabled addon state and/or load-on-demand slots) to talk to desktop processes. Their claim that this is permitted is not independent Blizzard approval. Do not replicate such a channel under the current OAR policy, even if attractive UX demonstrates user demand. A separately reviewed and explicitly approved policy change would be needed to revisit transport; this audit is not that approval.

## Repositories and exact files inspected

| System | Source inspected | Engineering observation |
|---|---|---|
| thott.bot chat | [Context.lua](https://github.com/thott-bot/chat/blob/8bb6232fdbcf87831eb498e3782f5af72d836f23/thott-bot-chat/Context.lua), [Transport.lua](https://github.com/thott-bot/chat/blob/8bb6232fdbcf87831eb498e3782f5af72d836f23/thott-bot-chat/Transport.lua), [helper/slots.go](https://github.com/thott-bot/chat/blob/8bb6232fdbcf87831eb498e3782f5af72d836f23/helper/slots.go), [helper/context.go](https://github.com/thott-bot/chat/blob/8bb6232fdbcf87831eb498e3782f5af72d836f23/helper/context.go) | Granular per-section character context, optional plain/no-character mode and explicit request consent. A bit/slot addon-state transport runs at intervals; README acknowledges 256 helper addons. Not adoptable under D18. |
| Wisp AI | [Character/Capture.lua](https://github.com/fedeya/wisp-ai/blob/87fb4251b166566595540f5caee46161001c6b8a/addon/WispAI/Character/Capture.lua), [Integrations/Questie.lua](https://github.com/fedeya/wisp-ai/blob/87fb4251b166566595540f5caee46161001c6b8a/addon/WispAI/Integrations/Questie.lua), [Integrations/Auctionator.lua](https://github.com/fedeya/wisp-ai/blob/87fb4251b166566595540f5caee46161001c6b8a/addon/WispAI/Integrations/Auctionator.lua) | Source-specific collectors; feature/status reporting for optional addons; QuestieDB flavor and coordinate-frame checks; Auctionator unit-price and age with explicit unknowns. |
| Wisp AI | [Advice/Advice.lua](https://github.com/fedeya/wisp-ai/blob/87fb4251b166566595540f5caee46161001c6b8a/addon/WispAI/Advice/Advice.lua), [routine-scheduler.ts](https://github.com/fedeya/wisp-ai/blob/87fb4251b166566595540f5caee46161001c6b8a/apps/bridge/src/routine-scheduler.ts), [usage.md](https://github.com/fedeya/wisp-ai/blob/87fb4251b166566595540f5caee46161001c6b8a/docs/usage.md) | Event-triggered read-only routines, queued/deferred work, lightweight HUD tip and persistent player-defined panels; routine engine uses desktop bridge and must not be copied wholesale. |
| Wisp AI | [Transport/Transport.lua](https://github.com/fedeya/wisp-ai/blob/87fb4251b166566595540f5caee46161001c6b8a/addon/WispAI/Transport/Transport.lua), [Transport/Downlink.lua](https://github.com/fedeya/wisp-ai/blob/87fb4251b166566595540f5caee46161001c6b8a/addon/WispAI/Transport/Downlink.lua), [providers.ts](https://github.com/fedeya/wisp-ai/blob/87fb4251b166566595540f5caee46161001c6b8a/apps/agent/src/providers.ts), [druid adapter](https://github.com/fedeya/wisp-ai/blob/87fb4251b166566595540f5caee46161001c6b8a/apps/bridge/src/simulation/adapters/druid.ts) | Bidirectional addon-state W2 protocol with CRC, revisions and resynchronization; many model providers; class adapters exist, but adapters do not by themselves establish comprehensive role coverage or live-game validation. |
| Questie | [QuestEventHandler.lua](https://github.com/Questie/Questie/blob/master/Modules/EventHandler/QuestEventHandler.lua), [QuestieWaypoints.lua](https://github.com/Questie/Questie/blob/master/Modules/Map/Waypoints/QuestieWaypoints.lua) | Separate event and quest lifecycle handling; map/minimap invalidation; owner-associated waypoint paths to prevent duplicate visual ownership. Read-only integrations and provenance are preferable to copying its DB. |
| Auctionator | [CurseForge project](https://www.curseforge.com/wow/addons/auctionator), [Wisp API consumer](https://github.com/fedeya/wisp-ai/blob/87fb4251b166566595540f5caee46161001c6b8a/addon/WispAI/Integrations/Auctionator.lua) | Supports AH prices, history and user-initiated scanning. A current official Auctionator source tree was **not** verified in this review; do not claim a direct current-version code audit. |
| Hekili (historical) | [Project repository](https://github.com/Hekili/hekili) | Previous multi-specialization recommendation UI is useful as an interaction reference, but the maintainer states the retail project ended after the Midnight prepatch/API changes. Avoid secret-value tactical rotation inference. |

## Detailed findings and Outrider changes

### 1. Existing direct competitors defeat the "AI in WoW" novelty claim
- Wisp already lets players query nearby quests, compare equipment, inspect hovered references, retain goal trackers, choose local/cloud models and create triggered routines. Its public code contains class simulation adapters for nine classes, but their assumptions and completeness vary.
- thott.bot already provides player-consented context sections, in-game Codex/Claude Code conversations, structured item/spell links and an MCP knowledge service.
- **Implication:** Class-neutral coaching and support for local/cloud models are necessary features, not sufficient differentiation. Make *precision, offline usefulness, minimal friction and one excellent next step* the demonstrable product story.
- **Backlog tie:** I2-02, I2-03, I2-05, I2-08-04. Benchmark user value rather than simply checking whether each side has a chatbot.

### 2. Borrow provenance-first optional-addon integration
- Wisp's Questie adapter checks whether the expected Forever DB/flavor, field accessors, faction, maps and coordinate projections actually exist. It reports skipped/unverified frames and labels spawn locations as database locations, not sightings.
- Outrider already contains NPC pack discovery, Questie compatibility logic, Journey/Travel, and the policy to yield to another addon. **Do not replace or duplicate those features.** Introduce a generic source capabilities report, with `ready | partial | incompatible | missing`, a source-specific build/version, last observation, and reason when a candidate is suppressed.
- Add map-coordinate provenance checks and explicit "unknown, not absent" semantics to Opportunity v3 when the only input is a pack.
- **Backlog tie:** I2-00-03, I2-01-03/04/05, I2-03-07, I2-07-05.

### 3. Vendor arbitrage needs data *quality*, not just arithmetic
- Wisp's Auctionator adapter demonstrates a disciplined read-only API consumer: unit price in copper, age in days and separately marked unknown values. Its output warns that cached prices are not a live listing.
- Outrider `Modules/Prices.lua` already reads Auctionator, TSM and its own 14-day *daily-low* observations. `Modules/AuctionHelper.lua` already has vendor/crafting floor and manual AH UI. The missing piece is reliable freshness/quantity/eligibility normalization, not a new price engine.
- Make Deal Desk display **fresh live listing vs historical price** explicitly. Only a currently verified purchasable lot plus a verified sellable vendor floor can produce an *actionable* vendor arbitrage candidate. Historic daily-low data can suggest "worth checking" only.
- Record stack quantity, buyout vs unit price, gross/net fees, bind status, available gold after reserve, and a player-confirmed outcome. Reject stale/unknown fields.
- **Backlog tie:** I2-04-01 through -09. Add distinct negative tests for stale Auctionator cache and per-stack-vs-unit misinterpretation.

### 4. Borrow gentle event-triggered coaching, not autonomous model routines
- Wisp uses event subscriptions, a deferred routine scheduler, bounded update intervals, a short tip with Dismiss/Read and persistent panels. It coalesces repeated changes and delays during combat.
- Outrider's `Modules/WhatNow.lua` already scores eight producer kinds and keeps candidates cached for 30 seconds; `Advisor.lua` already accepts bounded, candidate-bound feedback.
- Implement **native**, deterministic, class-neutral refresh only for source-relevant events. Coalesce at most once per two seconds, invalidate per producer, and suppress combat toasts. Offer 1+2 cards and simple `why / later / not useful / completed` feedback. Never run an LLM automatically from game events under current D18.
- Do not adopt unsolicited recurring cloud spend, model-run routine execution, or a bridge.
- **Backlog tie:** I2-02-01 through -10; I2-06-02/04.

### 5. Borrow explicit context-selection UX
- thott.bot has context collectors for character, location, target, quests, gear, bags, talents, skills, spells, reputation and buffs. The sending view distinguishes full context from a plain text-only message.
- Wisp has structured collector sections and request-specific data capture.
- Outrider already has OTR1 player-copy snapshots and a 50 KiB cap. Improve the **copy UI**: show selected task, source categories, bytes, timestamp/age, local-only/private fields omitted, and a "What the AI will see" preview. Presets should remain default-off for sensitive sections.
- Reuse the existing v1/v2 decoder, privacy filter and candidate whitelist. Build task-specific v3 envelopes rather than giant indiscriminate dumps.
- **Backlog tie:** I2-01-07/08; I2-05-01/04/06/08.

### 6. Model/provider parity is not the immediate flagship
- Wisp's source exposes a long list of model adapters; thott.bot piggybacks the user's Codex/Claude CLI. Outrider already has a Python OpenAI-compatible path, local-model option and validation/fallback logic.
- Prioritize measured end-to-end UX (ask/copy/paste/explain), source correctness and an automatic deterministic coach before expanding cloud integrations.
- For local GX10 use, retain generic OpenAI-compatible model discovery and no hardcoded IP. For cloud models, zero calls until explicit consent, visible spend/limits and no automatic cloud fallback.
- **Backlog tie:** I2-05. Avoid delaying the I2-02 no-model vertical slice for a large provider catalog.

### 7. Avoid insecure or prohibited shortcuts
- The thott.bot and Wisp transports use addon enable/load states as an out-of-game communication medium. Both are technically interesting, but directly conflict with OAR `CLAUDE.md`/D18's explicit no-side-channel policy. **Not approved for Outrider.**
- Wisp's tool catalog includes explicit requests to create macros or adjust some settings, plus defensive guards. Outrider should retain stricter data-only recommendations and player-clicked whitelisted in-addon navigation; no model-authorized new macro/write pipeline.
- Hekili-style real-time combat action prediction is incompatible with the conservative secret-value and no-rotation rules in the blueprint.
- **Backlog tie:** I2-00-02/05; I2-07-01/02/03; I2-09 stays BLOCKED.

## Concrete priority changes to the existing backlog
This research **does not change the 77 atomic tasks or authorize I2 implementation**. Add the following acceptance details when executing the existing tasks:

1. **I2-00-03**: Record an optional-source capability report for Questie/QuestieDB/Auctionator/TSM/unknown client APIs, including missing/incompatible and version labels.
2. **I2-01-04/05**: Distinguish live observation, cached addon price, static DB spawn, community data and model inference. Each must have independent freshness and eligibility rules.
3. **I2-01-08**: Add `Preview outbound evidence`, a category consent set, exact payload byte count and snapshot-age labeling to the existing OTR1 exchange.
4. **I2-02-04/05/07**: Test event burst coalescing, post-combat queue expiry, no-model offline Coach operation and unobtrusive 1+2 UI.
5. **I2-04-03/04/09**: Negative test cached prices represented as a live executable deal; separate real listing/lot facts from a historical fair-value hypothesis.
6. **I2-08-04**: Add 25 questions scored on *actionable, correct, class-relevant, minimal-click, source-verified and not-annoying* dimensions, against current Wisp and thott.bot. A live side-by-side comparison still needs installs, consent and the owner's hands-on testing.

## Suggested short first implementation milestone
A **single event-to-card** slice, not a chatbot rewrite: `quest/gear/errand readable event -> existing WhatNow adapter -> v3 observation/evidence -> goal+role eligibility -> one native card -> Why? -> Dismiss -> persisted feedback`. Prove on Warrior, Druid and Hunter, with UNKNOWN fallback and no companion process. No extra addon install necessary.

## Evidence limitations and verification requirements
- This is a static **source review**, not code execution, security certification, market adoption study, real-client performance test or Blizzard legal approval.
- Wisp source examined at `87fb4251b166566595540f5caee46161001c6b8a`, thott.bot source at `8bb6232fdbcf87831eb498e3782f5af72d836f23`. Questie paths refer to its upstream default branch at the time inspected, not a pinned release. Verify compatibility in WoW Forever build actually installed.
- thott.bot and Wisp are GPLv3-licensed according to their repositories; that does not authorize reusing their branding or bypass third-party data/content rights. Cleanly implement patterns instead of copying code. Auctionator on CurseForge is currently listed All Rights Reserved, and this report did not verify its official current source.
- If ever revisiting live transport, independently evaluate Blizzard's official addon policy and seek explicit policy/owner signoff. No source evidence in this report can substitute for that.
- No changes to `main`, game client, production addon, CLAUDE.md, D18 or I2 task completion checkboxes were made by this audit.

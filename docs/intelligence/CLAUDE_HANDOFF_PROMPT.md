# Claude Code handoff prompt: Outrider Intelligence

Read `OUTRIDER_INTELLIGENCE_ENGINEERING_SPEC.md` in full, then read `CLAUDE.md`, `TASKS.md`, the repo architecture, and source code. The design is based on `LackOfSkillz/OAR` main at `fc4e0e3` (2026-11-15); check the actual HEAD and reconcile changes first.

Objective: add an extraordinary, **grounded, character-aware AI planning assistant** to Outrider without losing a single current feature and without automating gameplay. This is **not** a generic chatbot. It unifies WhatNow, questing, travel, gear, dungeon, professions, prices, rares and opt-in family knowledge, with evidence, confidence labels and actionable (human-clicked) plans.

Execution rules:

1. Follow repo `CLAUDE.md` hard rules. Preserve the existing Lua and Python MCP/Advisor/copy-paste systems, SavedVariables, modules and slash commands.
2. Run baseline tests and document results. Audit actual code vs spec; mark features as present, partial, absent or blocked by API.
3. Create `docs/OUTRIDER_INTELLIGENCE_TASKS.md` with the specification's task IDs AI00-01 through AI06-08 and gates AI-G0 through AI-G6.
4. Start ONLY AI-00 and AI-01, then the narrow AI-02 vertical slice. Build the local OpenAI-compatible model adapter with a deterministic fake for tests. Do not add a live in-game bridge until the separate feasibility and policy gates pass.
5. User-facing output must be grounded in IDs and facts from actual modules; no invented coordinates, prices, quest requirements or respawn times. Treat every model response and external MCP source as untrusted.
6. Store credentials securely outside the addon. Cloud data transfer and family sharing must be opt-in. Basic Outrider must work with AI disabled and offline.
7. No gameplay automation, anti-cheat workarounds, process memory reading, executable Lua generation, or protected combat manipulations. Every eligible game action requires the player's deliberate click.
8. Test each microtask and produce a reviewable commit with exact commands/results. Record real-client validation needed rather than marking it passed from mock tests.
9. When the first vertical slice works, demonstrate the full route: `/ride ask` -> context -> chosen LOCAL model -> grounded answer + up to three safe cards -> paste into the Advisor without reload. Test at least hunter and a different class.
10. STOP after that slice and provide me the implementation summary, risks, in-game validation checklist, and proposed next phase. Do not publish or merge into public releases without my approval.

Design target: a deeply polished, evidence-backed "What should I do next?" strategist worthy of Outrider's premium dark fantasy interface, with optional support for local GX10 inference and frontier API providers later. Real utility, predictable behavior, complete user control.

# Outrider Intelligence, sprint 3 (AI-04): report for Gary (2026-11-15)

Built after your "continue". Nothing published or merged; no request has been
sent to any cloud provider from this PC.

## New
- **Cloud models, optional.** Claude (Anthropic), OpenAI or Gemini can answer
  instead of a local model. Off until you: store a key, look at exactly what
  would be sent (`ask --preview`), and set `"cloudConsent": true`.
  Claude requests use server-side fallback on refusals (a declined request is
  retried on another Claude model in the same call); it can be removed.
- **Keys in Windows Credential Manager** (`keys set anthropic`, hidden input).
  Never in config files, SavedVariables, codes, logs or git. Verified with a
  real write-read-delete on this PC.
- **Daily spend cap** in tokens (default 100,000); past it, Outrider's own steps.
- **`doctor`**: what is set up, where requests go, key stored yes/no, consent,
  tokens used today. Its `--check` only ever pings a local model server.
- **More tools for Claude (MCP):** gear upgrades, dungeons that fit you,
  gold methods and crafting profit, rare evidence, all from your last
  `/ride ask`, cleaned of player names. Claude can plan with them and answer
  through `plan_to_clipboard`.
- Clear errors: wrong key, wrong model, quota, provider busy, TLS, network off.

Tests: 495 Lua specs; companion 16 + 29 + 14 (one opt-in Credential Manager test).

## Waiting on you
- A real model answer (local server or a cloud key) and your OK to spend.
- The outside reference server (warcraftforever.com MCP): needs your OK to
  contact it and a license check, so it's blocked.
- In-game checks from sprints 1-3 (one full restart, then the Advisor tab).

## Next phase if you want it
AI-06 polish: onboarding inside the Advisor tab ("Why AI?", local or cloud,
sample question), a sources view per card, plan progress, and a release
checklist. AI-05 (an in-game bridge) stays parked unless you ask: the spec
prefers shipping without it to using a questionable workaround.

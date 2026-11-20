# Outrider Intelligence: privacy and transport

Defaults for the AI layer (spec sections 6, 9, 10, 15). Everything here is off
or local until Gary changes it.

## Transport
- **Only transport: OTR1 copy and paste.** `/ride ask` shows the snapshot as a
  code; the companion reads it from the clipboard, answers, and puts an advice
  code back on the clipboard; Gary pastes it into the Advisor tab. No reload, no
  game files read while playing, no network from Lua.
- Advice.lua (the reload route) keeps working unchanged.
- No in-game bridge, ever (D18, advice only): no screen or window capture, no
  runtime addon rewrites, no input, no memory reading. The data-only Advice.lua
  (`write_advice`, seen after a /reload) stays.

## What leaves the PC
- Nothing by default. The model provider is local: the default base URL is
  `http://127.0.0.1:<port>`. A LAN or internet URL has to be typed into
  `companion/config.json` by Gary, and a LAN machine is not private to this PC.
- No automatic fallback to a paid or cloud provider. Anthropic server-side model substitution is disabled.
- Non-loopback local-model endpoints require explicit allowRemote plus HTTPS and authentication. For a development-only plaintext LAN connection, the user must additionally acknowledge the risk with allowInsecureLan; loopback stays HTTP-compatible.
- Cloud providers (Anthropic, OpenAI, Gemini; AI-04) work only when Gary
  picks one, stores its key, looks at `ask --preview` and sets
  `"cloudConsent": true`. Keys live in Windows Credential Manager, never in
  SavedVariables, codes, logs or the repo. A daily token cap
  (`dailyTokenCap`, default 100,000) stops cloud calls past the limit.
- Anthropic refusals do not trigger another model or provider. No automatic paid model substitution.

## What the model sees
- A context built from the snapshot: class, level, faction, goal, zone name and
  id, money, the WhatNow candidates (ids, titles, why, where, trip time,
  confidence label).
- Not sent: character and realm names (replaced by `char-1`), guild, other
  players' names (KitShare cards, family), chat, account paths, logs.
- Text from the game (quest titles, NPC names) is data: it is quoted, length
  limited, stripped of WoW escape codes, and the model is told it may contain
  instructions to ignore.

## What comes back
- Model output is untrusted. The validator keeps only: a headline, a summary,
  limits, up to 3 picks that name a candidate id from this snapshot. Card
  titles and every action are rebuilt from Outrider's own candidate data;
  coordinates and ids never come from the model.
- Actions stay the existing four (waypoint, track_quest, open_panel,
  show_item), each a click by Gary. The addon checks everything again on paste.
- If the model fails, times out or answers badly, the answer is Outrider's own
  top steps, labelled as such.

## Budgets
- Snapshot code: 50 KiB (unchanged). Context to the model: at most 20
  candidates, strings cut to 200 characters. Answer code: 64 KiB, headline 120,
  summary 600, 4 limits of 160, 3 picks.
- Model call: 60 s timeout, 1 retry on connection errors, max 800 output tokens.

# Outrider Intelligence: license and compliance notes (AI06-06, 2026-11-15)

Not legal advice; a checklist for Gary's decisions (docs/DECISIONS.md Q3).

| Part | Source | Status |
|---|---|---|
| Addon Lua (incl. Advisor, AdviceLoader, WhatNow) | Written for Outrider | Outrider's own; its license is still open (Q3) |
| Companion (Python, standard library only) | Written for Outrider | Same; no third-party packages, nothing vendored |
| Data packs (NPC, gear, mobs, nodes, dungeons) | Converted from QuestieDB | GPLv3 text and attribution ship in each folder; QuestieDB notes some historic contributions are unlicensed (Q3) |
| Custom art (emblem, header, step pictures) | Made by Gary with GPT image generation | Gary's; no Blizzard art or logos used |
| Fonts and icons | Shipped with the WoW client, referenced by path | Not redistributed |
| Model outputs | Gary's chosen local or cloud model | Subject to that provider's terms; not stored by Outrider beyond the pasted advice |
| Cloud APIs (Anthropic, OpenAI, Gemini) | Called only with Gary's own key | Gary's account and terms; Outrider adds no account, ads or resale |
| warcraftforever.com MCP | Not used | Blocked until Gary approves and its license is checked |

Blizzard's add-on policy (free, readable code, no automation of play): the
AI layer adds no automation, no paid tier and no in-game ads; every action is
a click. Before a public release with the AI layer, Gary decides Q3 (license)
and whether the companion ships in the family installer or separately.

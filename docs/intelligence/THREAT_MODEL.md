# Outrider Intelligence: threat model (AI06-04, 2026-11-15)

## Assets
Gary's account (no automation, no tampering), his PC (no code run from
outside text), his privacy (names, chat, other players), his API keys and
money, and the trustworthiness of the advice.

## Trust boundaries (spec 4.1) and how each is held

| Boundary | Threat | Control | Test |
|---|---|---|---|
| Game -> code | Game text (quest titles, NPC names) carries instructions or escape codes | Strings cleaned (escapes, pipes, control chars), cut short; the prompt marks them as data | test_intelligence (escapes, injection), golden "injection" scenarios |
| Code -> model | Names or other players leak | Names, realm, guild, KitShare cards never in the envelope; person fields dropped from module data | golden "family-privacy" (0 leaks), test_intelligence, MCP tool tests |
| Model -> companion | Model invents places, ids, prices; injects actions or code | Only candidate ids from the snapshot survive; titles, coordinates and actions rebuilt from Outrider data; 4 safe actions | golden harness (0 ungrounded, 0 unsafe), poisoned-reply tests |
| Companion -> addon | Forged or stale advice code | Checksummed OTR1 codes; character + snapshot time + snapshotId binding; addon re-checks ids, exact waypoint targets, action whitelist | advice_v2_spec, contract fixtures |
| Addon -> game | Advice performs protected actions | Every card is a click; only waypoint, track quest, open a page, show an item; no casting, targeting, buying | test_security (no loadstring/RunScript/CastSpellByName/SendChatMessage), hard rule 1 |
| Companion -> network | Data sent somewhere unexpected | Local loopback default; LAN needs allowRemote; cloud needs key + preview + cloudConsent; redirects refused; no fallback to cloud | test_intelligence (URL rules, redirect), test_cloud (consent, keys) |
| Keys | Leak through files or logs | Windows Credential Manager; never printed, never in errors; secrets scan of the repo | test_cloud (status never shows keys), test_security (no keys in repo) |
| Money | Runaway cloud spend | Daily token cap before every cloud call; one call per click; Stop waiting ignores late answers | test_cloud (cap), window tests |
| External MCP servers | Untrusted reference data, exfiltration | Not connected (AI04-04 blocked on Gary's OK) | n/a |

## Residual risks
- The clipboard holds the snapshot code until overwritten; other programs on
  the PC can read it. It has no names, but has class, level, zone and steps.
- A local model on another machine (allowRemote) sees the same data.
- Classic-derived quest, gear and dungeon data may be wrong on Forever; the
  answer labels it, but a person can still be misled by a confident model
  summary. The summary is model text; the cards are not.
- Cloud adapters are untested against real providers.
- The in-game advice code is shown to Gary only; nothing is shared with other
  players by this feature.

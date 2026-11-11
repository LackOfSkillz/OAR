# AI advisor (Phase 9, parked)

Not part of the first build. The groundwork ships now, dormant, so the later step is small.

## Idea

A model (local, like one run through Ollama or LM Studio, or a frontier model Gary configures) reads a snapshot of the character and suggests a short list of options in game: "Tame The Rake: it's 300 yards away and your current pet is 4 levels behind", "Train Arcane Shot rank 3 in Thunder Bluff", "This bow on the AH is a 14% upgrade". Gary picks one; picking it only does something harmless and non-protected (set a waypoint, track a quest, open a panel, show an item). The advisor never clicks, casts, targets, buys or moves anything.

## How it fits WoW's limits

WoW addons can't open sockets or files. The only bridge is SavedVariables:

```
 in game                              on Gary's PC
 /ride snap  -> Outrider_Snapshots   ---->  WTF\...\SavedVariables\Outrider.lua   (written on /reload)
                                         |
                                         v
                                companion app (MCP server)
                                         |  get_snapshot, list_characters, ...
                                         v
                                   model (local or cloud)
                                         |
                                         v
 AdviceLoader <- Outrider_Advice   <----  Interface\AddOns\Outrider\Advisor\Advice.lua  (data only)
 (after /reload)
```

Round trip: Gary types `/ride ask` (bound later to `Snapshot:AskAdvisor`, which collects and reloads), the companion notices the file change, asks the model, writes Advice.lua, Gary types `/reload` once more (or the companion waits for the next natural reload), and the advice panel shows the options.

## What already exists

- `Advisor/Snapshot.lua`: `/ride snap` collects level, class, race, faction, money, position, equipped item IDs, and anything modules return from `Module:Snapshot()`. Schema 1.
- `Advisor/AdviceLoader.lua`: validates `Outrider_Advice` (schema, character, snapshot match) and keeps only whitelisted actions (`waypoint`, `track_quest`, `open_panel`, `show_item`) with typed args. Tested in `tests/spec/advisor_spec.lua`.
- `Advisor/Advice.lua`: ships empty. `tools/deploy.ps1 -KeepAdvice` preserves the companion's file.

## Phase 9 tasks

See `phases/P9_ai_advisor.md`.

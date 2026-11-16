# Outrider Intelligence: architecture (sprint 1)

```
WoW (Lua)                                   Companion (Python, outside the game)
---------                                   ------------------------------------
WhatNow:Snapshot()  -- candidates with ids, targets
Snapshot:Collect(true) -- /ride ask, v1 + v2 meta
   | OTR1 snapshot code (clipboard)  ---->  intelligence.context.build(snapshot)
                                              privacy filter (names out, bounds)
                                            intelligence.orchestrator.ask(question)
                                              provider.generate(...)  (local model or fake)
                                              validator: picks must name candidate ids
                                              cards rebuilt from candidate data
   | OTR1 advice code, schema 2 (clipboard) <----
AdviceLoader v2: answer + cards, binding checks
Advisor tab: headline, summary, limits, click-to-act cards
```

Files (sprint 1):
- `addon/Outrider/Modules/WhatNow.lua`: `Snapshot()` returns the top candidates
  with `candidateId`, kind, title, why, where, minutes, confidence label and a
  grounded `target` (map id and coordinates from Outrider's own data) or `panel`.
- `addon/Outrider/Advisor/Snapshot.lua`: adds `snapshotId`, `gameBuild`.
- `addon/Outrider/Advisor/AdviceLoader.lua`: accepts schema 1 (unchanged) and 2
  (adds `answer` = headline, summary, limits, sources).
- `addon/Outrider/Modules/Advisor.lua`: shows the answer above the cards.
- `companion/outrider_companion/intelligence/`: `context.py` (envelope and
  privacy), `providers.py` (base, OpenAI-compatible local adapter, fake),
  `orchestrator.py` (prompt, call, validate, fallback), `ask.py` (command line).
- `companion/tests/test_intelligence.py`.

Rules: model output never becomes Lua; ids and coordinates only come from the
snapshot; no network from Lua; local provider by default; deterministic answer
when the model is off or fails.

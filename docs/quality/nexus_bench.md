# Nexus planner benchmark (OI02-15)

Mock client, Lua 5.1 through lupa on the development PC. These are **not** in-game measurements:
live p95 frame cost and memory are pending Gary's session (tracker item).

Runs per scenario: 300. Times are the Nexus pipeline only (adapters, graph, score, planner).

| Scenario | Expected | WhatNow top | Nexus top | WhatNow ok | Nexus ok | mean ms | p95 ms | max ms | work | KB allocated per run |
|---|---|---|---|---|---|---|---|---|---|---|
| gold goal | a gold step first | gold:farm | gold:farm | yes | yes | 0.11 | 1.00 | 1.00 | 12 | 30 |
| gear goal, low funds | nothing unaffordable first | gear:Axe | gear:Boots | **no** | yes | 0.09 | 1.00 | 1.00 | 4 | 23 |
| level goal, duplicate quest | one entry per quest | quest:Red Silk | dq:214 | **no** | yes | 0.09 | 1.00 | 1.00 | 4 | 22 |
| professions goal | a profession step first | profession:Cooking | profession:Cooking | yes | yes | 0.09 | 1.00 | 1.00 | 4 | 24 |
| explore goal | the rare first | rare:61 | rare:61 | yes | yes | 0.09 | 1.00 | 1.00 | 4 | 24 |
| mix goal, doubtful source | a well-evidenced step first | quest:Solid | quest:Solid | yes | yes | 0.08 | 1.00 | 1.00 | 4 | 20 |

## Where the two differ

- gear goal, low funds: WhatNow picks gear:Axe, Nexus gear:Boots. WhatNow has no gold budget, so it can put an item you can't pay for first; the Nexus treats the spendable gold as a hard limit.
- level goal, duplicate quest: WhatNow picks quest:Red Silk, Nexus dq:214. The same quest from two producers is counted once by the Nexus.

Nexus met every scenario's expected property.

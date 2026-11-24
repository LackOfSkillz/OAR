# Nexus planner benchmark (OI02-15)

Mock client, Lua 5.1 through lupa on the development PC. These are **not** in-game measurements:
live p95 frame cost and memory are pending Gary's session (tracker item).

Runs per scenario: 200. Times are the Nexus pipeline only (adapters, graph, score, planner).

| Scenario | Expected | WhatNow top | Nexus top | WhatNow ok | Nexus ok | mean ms | p95 ms | max ms | work | KB allocated per run |
|---|---|---|---|---|---|---|---|---|---|---|
| gold goal | a gold step first | gold:farm | gold:farm | yes | yes | 0.15 | 1.00 | 1.00 | 12 | 40 |
| gear goal, low funds | nothing unaffordable first | gear:Axe | gear:Boots | **no** | yes | 0.12 | 1.00 | 1.00 | 4 | 31 |
| level goal, duplicate quest | one entry per quest | quest:Red Silk | dq:214 | **no** | yes | 0.12 | 1.00 | 1.00 | 4 | 30 |
| professions goal | a profession step first | profession:Cooking | profession:Cooking | yes | yes | 0.13 | 1.00 | 1.00 | 4 | 32 |
| explore goal | the rare first | rare:61 | rare:61 | yes | yes | 0.12 | 1.00 | 1.00 | 4 | 31 |
| mix goal, doubtful source | a well-evidenced step first | quest:Solid | quest:Solid | yes | yes | 0.10 | 1.00 | 1.00 | 4 | 26 |
| conflicting goals | the top goal leads, the second still gets a step | gold:farm | gold:farm | yes | yes | 0.12 | 1.00 | 1.00 | 4 | 32 |
| insufficient resources | no purchase above the reserve, unknown prices left out | gear:Axe | quest:Q6 | **no** | yes | 0.11 | 1.00 | 1.00 | 1 | 26 |
| stale observations | a fresh node over one seen long ago | gather:old | gather:new | **no** | yes | 0.06 | 1.00 | 1.00 | 1 | 18 |
| unavailable metadata | the step with known map and time first | quest:Vague | quest:Clear | **no** | yes | 0.10 | 1.00 | 1.00 | 4 | 25 |
| overlapping objectives | one entry for one quest offered twice | quest:The Rake | quest:The Rake | **no** | yes | 0.13 | 1.00 | 1.00 | 4 | 30 |
| adverse conditions | a plan from what still works | quest:Q7 | quest:Q7 | yes | yes | 0.05 | 1.00 | 1.00 | 1 | 16 |

## The addon's own producers (mock client)

Planner on, real WhatNow producers, LevelRoutes, DealDesk and Handoffs on the mock client: 4 opportunities, 0 unavailable producers, 4 planned steps, each citing evidence that resolves, none twice.

## Where the two differ

- gear goal, low funds: WhatNow picks gear:Axe, Nexus gear:Boots. WhatNow has no gold budget, so it can put an item you can't pay for first; the Nexus treats the spendable gold as a hard limit.
- level goal, duplicate quest: WhatNow picks quest:Red Silk, Nexus dq:214. The same quest from two producers is counted once by the Nexus.
- insufficient resources: WhatNow picks gear:Axe, Nexus quest:Q6. With 5s spendable over the reserve, the 9s axe and the vendor item of unknown price can't be planned; WhatNow ranks them first.
- stale observations: WhatNow picks gather:old, Nexus gather:new. The Nexus drops a fact past its expiry; WhatNow has no observation time.
- unavailable metadata: WhatNow picks quest:Vague, Nexus quest:Clear. Unknown map and time are uncertainty to the Nexus, not free.

Nexus met every scenario's expected property.

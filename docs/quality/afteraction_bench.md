# AfterAction measurement report (OI03-14)

Fixture data from a fixed seed, not anyone's play. Same fixture, same report.

## Quest times: Journey's fixed estimate vs your personal estimate

Samples 40 (trained on 28 earlier, tested on 12 later).
Median absolute error: fixed estimate 284 s, personal estimate 88 s (same later samples for both; lower is closer).

## Walking routes: planner estimate vs actual

| Route | Trips | Median actual s | Median estimate s | Actual / estimate |
|---|---|---|---|---|
| 1>2 | 4 | 174 | 140 | 1.25 |
| 1>3 | 4 | 210 | 160 | 1.31 |
| 2>3 | 4 | 215 | 160 | 1.34 |

Unmatched routes (walked once, not compared): 1.

## Outcomes

By kind: death 8, quest_completed 8.
Attributed likely: 4; unknown: 12. Likely means it followed a Go on a plan step about the same thing; that is not proof the plan led to it.

## Sessions with and without the planner

- Level band and build 21|B: with 4 sessions, median 10151 XP/h; without 4, median 9808 XP/h.
A difference between matched groups is an observation, not proof of cause.

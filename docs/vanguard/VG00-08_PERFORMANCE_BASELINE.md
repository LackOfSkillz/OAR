# VG00-08: Performance baseline

Date: 2026-11-26. Measured by Outrider's own always-on performance watch (Core/Perf.lua, PerfWatch) in Gary's session of 2026-11-25 (logout report 21:55:55, uptime 432 s, shaman play test). This is the **pre-Vanguard** baseline. VG00 adds no timers, frames or per-frame work.

## Reference machine

| Item | Value |
|---|---|
| CPU | Intel Core i9-12950HX |
| RAM | 64 GB |
| GPU | Intel UHD Graphics (integrated) |
| Client | WoW Forever 1.60.1, build 71139, interface 16001 |
| Outrider | 0.5.0+ development build (pre-FarmLab) |

## Measured (2026-11-25 session)

| Metric | Value |
|---|---|
| Addon load | 0.5 ms |
| Login work | 23.8 ms |
| Memory, after garbage collection | 67,078 KB (budget 80 MB, D26) |
| Memory, live before collection | 70,830 KB |
| Short-lived memory made in the session | 576.8 MB (largest: path timer 267.4 MB, minimap pins timer 116.8 MB, HunterFight 70.7 MB) |
| Event registrations | 158 events / 570 handlers |
| Timers live at logout | 2 (frame driver off) |
| Named frames | 25 |
| Modules | 135 enabled of 142 |
| Combat queue | 0 waiting |
| Errors / taint | 0 / 0 |
| CPU per add-on | unavailable in that session (scriptProfile off; the Performance page uses the game's profiler when open) |
| Slowest single handlers | snapshot logout 109.6 ms (once); MinimapPins entering world 78.3 ms; HunterFight totem update 36.5 ms (6 calls); path supertrack 36.2 ms; combat end 29.3 ms |

Reproduce: play a session, log out, run `tools/read-logs.ps1 -Section all` and read the `[perf]` and `[PerfWatch]` lines. Gary's 20-30 minute performance session is still pending and will replace this short sample.

## Provisional Vanguard budgets (spec section 9, unchanged; to be confirmed against the longer session)

| Budget | Target | How it will be checked |
|---|---|---|
| Scanning in combat | none | spec tests (combat cancels), live L04 |
| Inspect broker | one timer, one request in flight, ≥2 s spacing, 8 s timeout, one retry | unit tests with the fake clock |
| CPU per slice outside combat | ≤2 ms typical, ≤4 ms worst | PerfWatch slow-run list (records any run ≥20 ms today); Vanguard work must never appear in it |
| Assessment of 40 profiles | p95 <100 ms (off-game, spec runner) | benchmark spec |
| Transient cache | ≤5 MB | memory after a 40-member scan |
| Frame growth | none per refresh | named-frame count before and after 100 refreshes |
| Cancel | within one event turn | unit test |
| Memory total | Outrider stays under 80 MB after collection (D26) | logout report |

## Notes

- The heaviest short-lived memory today comes from the path and minimap-pin timers, not from group features. Vanguard must not add per-frame or per-second work while its page is closed.
- VG00 adds handlers for `GROUP_ROSTER_UPDATE`, `ENCOUNTER_START` and `ENCOUNTER_END` in AutoCheck. Each does at most a counter check and one timer (roster) or one sample (encounter), capped per session.

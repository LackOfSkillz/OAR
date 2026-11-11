# Probe results (measured on Gary's client)

Fill this in during P0-08 from `tools/read-logs.ps1 -Section probe`, and keep it current whenever a later phase probes something new. This file is the source of truth for what exists; FOREVER_CONSTRAINTS.md is the summary.

## Client

| Field | Value | Date |
|---|---|---|
| Version (GetBuildInfo 1) | 1.60.1 (from /ride version) | 2026-11-11 |
| Build (GetBuildInfo 2) | 70888 | 2026-11-11 |
| Interface (GetBuildInfo 4) | 16001 (matches the TOC) | 2026-11-11 |
| WOW_PROJECT_ID | | |
| Client folder | `_forever_` | 2026-11-11 |
| MAX_ACCOUNT_MACROS / MAX_CHARACTER_MACROS | | |

## SavedVariables round trip (P0-07)

| Test | Result | Date |
|---|---|---|
| /reload keeps settings (loads counter rises) | Pass: loads 1 to 4 over three reloads, `sv=yes` each time, debug flag kept | 2026-11-11 |
| Full exit and restart keeps settings | Pass: client restarted 10:51:24, loads 4 to 5, `sv=yes`, debug kept, Welcome `greeted` kept | 2026-11-11 |

## Other observations

| What | Value | Date |
|---|---|---|
| Per-addon object caps (General.log) | Frame 10000, Texture 40000, FontString 5000, Font 300, Animation 5000, AnimGroup 2000, Timer 500 (C19) | 2026-11-11 |
| Torrant's race | `Skyborne` (UnitRace token), a Forever race | 2026-11-11 |
| Secure test button | One click logged OnClick twice when registered for AnyUp+AnyDown; diagnosing (down flag + ActionButtonUseKeyDown logged from build after bd98a54) | 2026-11-11 |
| Error pipeline | Deliberate error caught once with full stack through Safe/xpcall | 2026-11-11 |

## APIs

Copy the missing list here, and anything surprising in the present list. Note which phase is affected and what the fallback is.

| API | Present? | Affects | Fallback / note |
|---|---|---|---|
| | | | |

## Events

| Event | Registers? | Note |
|---|---|---|
| COMBAT_LOG_EVENT_UNFILTERED | | expected refused (C5) |

## Units (out of combat vs in combat)

| Unit | GUID readable | Name readable | Classification | Note |
|---|---|---|---|---|
| target (out of combat) | | | | |
| target (in combat) | | | | |
| nameplate1 | | | | |

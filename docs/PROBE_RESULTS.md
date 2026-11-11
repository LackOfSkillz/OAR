# Probe results (measured on Gary's client)

Fill this in during P0-08 from `tools/read-logs.ps1 -Section probe`, and keep it current whenever a later phase probes something new. This file is the source of truth for what exists; FOREVER_CONSTRAINTS.md is the summary.

## Client

| Field | Value | Date |
|---|---|---|
| Version (GetBuildInfo 1) | _pending P0-08_ | |
| Build (GetBuildInfo 2) | | |
| Interface (GetBuildInfo 4) | | |
| WOW_PROJECT_ID | | |
| Client folder | | |
| MAX_ACCOUNT_MACROS / MAX_CHARACTER_MACROS | | |

## SavedVariables round trip (P0-07)

| Test | Result | Date |
|---|---|---|
| /reload keeps settings (loads counter rises) | _pending_ | |
| Full exit and restart keeps settings | _pending_ | |

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

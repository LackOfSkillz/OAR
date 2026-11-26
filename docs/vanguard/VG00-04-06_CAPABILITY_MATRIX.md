# VG00-04 / 05 / 06: Roster, inspection and encounter capability matrix

Date: 2026-11-26. Client: WoW Forever 1.60.1, build 71139, interface 16001, enUS (last probe 2026-11-25 21:48). Status: **probe built and unit-tested; live samples pending** (Gary's next group play). Nothing below is marked verified without an in-game sample.

## How it is measured (self-collecting, hard rule: no typing mid-play)

| Task | Trigger | What is recorded | Code |
|---|---|---|---|
| VG00-04 roster | `GROUP_ROSTER_UPDATE`, 3 s later, out of combat, when group size changed; at most 6 a session | per member: unit exists; `UnitGUID` / `UnitName` / `UnitLevel` / `UnitIsConnected` / `UnitIsDeadOrGhost` readable (yes / no value / secret / missing api); class token counts; `UnitGroupRolesAssigned` counts; `CanInspect` and inspect range counts; raid `GetRaidRosterInfo` return types and subgroup counts; your own role and leader flag | `Probe:Roster` (`addon/Outrider/Core/Probe.lua`), `AutoCheck:OnRoster` |
| VG00-05 inspect | `INSPECT_READY` after a tooltip-hover inspect (PlayerInfo's existing request) or Blizzard's Inspect window on your target; out of combat; once per player; at most 6 a session | slots with a link / with an ID only / empty / secret; item levels readable; `GetInspectSpecialization`; Classic `GetNumTalentTabs(true)` and `GetTalentTabInfo(1, true)`; `Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID`, `C_Traits.GetConfigInfo(id)`, nodes read and ranked on the first tree; `C_Traits.GenerateInspectImportString` length; seconds from request to answer | `Probe:Inspect`, `PlayerInfo:ProbeInspect` (runs before `ClearInspectPlayer`) |
| VG00-06 encounter | `ENCOUNTER_START` / `ENCOUNTER_END`, at most 10 a session | event arguments (id and its type, name, difficulty, size, success shape) and `GetInstanceInfo` (name, type, difficulty, max players, instance id), group kind and size | `Probe:Encounter`, `AutoCheck:OnEncounter` |
| all | auto probe once per build | presence of 30 new group, inspect, instance and encounter APIs; 17 events checked with `C_EventUtils.IsEventValid` (never registered); `INSPECT_TRAIT_CONFIG_ID`, `MAX_RAID_MEMBERS`, `MAX_PARTY_MEMBERS` | `Probe.APIS`, `Probe.EVENTS`, `Probe.CONSTANTS` |

No names, realms, GUIDs or gear links of other players are stored (VG00-03). Samples go to `global.probeGroup` (12 newest), then to the archive. Nothing here calls `NotifyInspect` itself: VG00 only watches inspects that already happen (Gary hovers a player, or opens Inspect). No forbidden event is registered.

## Matrix (what is known today)

| Capability | API / event | Status on Forever | Evidence | Fallback if absent |
|---|---|---|---|---|
| Group size | `GetNumGroupMembers` | present | probe 2026-11-25 | solo |
| Party / raid | `IsInGroup`, `IsInRaid` | **pending** (added to probe) | — | party unit scan |
| Member GUID | `UnitGUID(partyN)` | present; readability per member **pending** | probe (presence) | canonical name + realm, never merge ambiguous names |
| Class, level | `UnitClass`, `UnitLevel` | present (used everywhere) | in use since P1 | unknown |
| Assigned role | `UnitGroupRolesAssigned` | **pending** | — | ask the player / unknown; never infer as fact |
| Raid subgroup | `GetRaidRosterInfo` | **pending** | — | unknown subgroup; optimiser works on hypotheticals |
| Inspect allowed | `CanInspect`, `CheckInteractDistance` | present (PlayerInfo uses both) | in use since 2026-11-17, no errors logged | roster-only mode (T0) |
| Inspect request | `NotifyInspect` → `INSPECT_READY` | present; wiki says *AllowedWhenUntainted* on 1.60.1 | wiki; PlayerInfo uses it with no logged error, but **no success sample logged** | manual Inspect only |
| Inspected gear | `GetInventoryItemLink(unit, slot)` | **pending for other units** | — | slot state "unreadable" (not "empty") |
| Inspected talents (Classic) | `GetNumTalentTabs(true)`, `GetTalentTabInfo` | **`GetNumTalentTabs` missing** | probe 2026-11-25 | Traits path below |
| Inspected talents (modern) | `INSPECT_TRAIT_CONFIG_ID`, `C_Traits.GetConfigInfo`, `GenerateInspectImportString` | **pending** | — | spec only, or unknown |
| Inspected spec | `GetInspectSpecialization` | **pending** | — | unknown |
| Boss pull and result | `ENCOUNTER_START` / `ENCOUNTER_END` | used by DungeonJournal and BossTimeline since P4; **no sample logged yet** | code only | instance enter / leave from Alts runs |
| Boss kill | `BOSS_KILL` | **pending** (validity only) | — | `ENCOUNTER_END` success |
| Instance identity | `GetInstanceInfo` | present (Alts) | in use | zone name |
| Difficulty | `GetDifficultyInfo` | **pending** | — | instance max players |
| Lockouts | `GetNumSavedInstances`, `GetSavedInstanceInfo` | **pending** | — | Alts lockout memory |
| Ready check | `READY_CHECK*` events | **pending** (validity only) | — | own ReadyCheck page |
| Combat log | `COMBAT_LOG_EVENT_UNFILTERED` | **forbidden**, never registered (hard rule 4; Blizzard blocks Outrider if tried, 2026-11-11) | `ns.Events.FORBIDDEN` | not used |

## Unknown-fallback tests (in `tests/spec/vanguard_probe_spec.lua`, 7 tests, green)

- Roster sample counts roles, classes, readable fields and range, and saves no names or GUIDs (every saved string is checked).
- In combat nothing is sampled; the sample is taken after combat; a secret `CanInspect` is recorded as "secret", not false.
- Hover inspect: links, ID-only slots and empty slots are told apart. A missing Classic talent API shows as missing (`nil`), not as zero talents. Each player is sampled once.
- Blizzard Inspect window via target; never in combat.
- Encounter: a missing success field stays unknown, not a wipe.
- Overflow moves to the archive (12 kept, the rest archived, none lost).
- The probe lists every new API, event and constant.

## What Gary does (live acceptance for VG00-04..06)

Plain play, no commands. Join any group (dungeon finder or party), mouse over each member for a second, kill one dungeon boss, log out. If the client allows reading other players' talents, the log line `inspect (...)` will show traits nodes or an import string. Acceptance item VG00-05 ("one non-user inspected with owner present") is met by hovering any player who doesn't run Outrider.

Not covered by this probe (left for VG01 live tests): out-of-range and offline members mid-scan, the Inspect window opened during a scan, roster churn during a scan, raid subgroups (needs a raid).

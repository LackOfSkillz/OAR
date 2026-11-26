# VG00-04 / 05 / 06: Roster, inspection and encounter capability matrix

Date: 2026-11-26. Client: WoW Forever 1.60.1, build 71139, interface 16001, enUS (last probe 2026-11-25 21:48). Status: **probe built and unit-tested; first live samples 2026-11-26** (see the end). Rows say "pending" until a sample exists.

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
| Party / raid | `IsInGroup`, `IsInRaid` | party **works** (live 2026-11-26); raid pending | roster sample | party unit scan |
| Member GUID | `UnitGUID(partyN)` | present; readability per member **pending** | probe (presence) | canonical name + realm, never merge ambiguous names |
| Class, level | `UnitClass`, `UnitLevel` | present (used everywhere) | in use since P1 | unknown |
| Assigned role | `UnitGroupRolesAssigned` | **readable** (live 2026-11-26, party) | roster sample | ask the player / unknown; never infer as fact |
| Raid subgroup | `GetRaidRosterInfo` | **pending** | — | unknown subgroup; optimiser works on hypotheticals |
| Inspect allowed | `CanInspect`, `CheckInteractDistance` | present (PlayerInfo uses both) | in use since 2026-11-17, no errors logged | roster-only mode (T0) |
| Inspect request | `NotifyInspect` → `INSPECT_READY` | **works** (live 2026-11-26, answer in 0.4 s) | inspect sample | manual Inspect only |
| Inspected gear | `GetInventoryItemLink(unit, slot)` | **works** for a non-user (8 links, 1 ID only, 9 empty; live 2026-11-26) | inspect sample | slot state "unreadable" (not "empty") |
| Inspected talents (Classic) | `GetNumTalentTabs(true)`, `GetTalentTabInfo` | **`GetNumTalentTabs` missing** | probe 2026-11-25 | Traits path below |
| Inspected talents (modern) | `INSPECT_TRAIT_CONFIG_ID`, `C_Traits.GetConfigInfo`, `GenerateInspectImportString` | **works**: config -1, 1 tree, 54 nodes, import string (live 2026-11-26); spent points not seen yet | inspect sample | spec only, or unknown |
| Inspected spec | `GetInspectSpecialization` | **works** (a spec ID, live 2026-11-26) | inspect sample | unknown |
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

## Privacy of the probes (VG00-R02)

Samples hold only allowlisted values: numbers, booleans, role/class/instance-type words, types with a size (`string(35)`), and boss and instance names. Tested with debug mode on across the whole saved file.

## What Gary does (live acceptance for VG00-04..06)

Plain play, no commands. Join any group (dungeon finder or party), mouse over each member for a second, kill one dungeon boss, log out. If the client allows reading other players' talents, the log line `inspect (...)` will show traits nodes or an import string. Acceptance item VG00-05 ("one non-user inspected with owner present") is met by hovering any player who doesn't run Outrider.

Not covered by this probe (left for VG01 live tests): out-of-range and offline members mid-scan, the Inspect window opened during a scan, roster churn during a scan, raid subgroups (needs a raid).

## Live samples (2026-11-26, build 71139, Gary's play; read from the saved log)

| Time | Sample | Result |
|---|---|---|
| 08:23:31 | **inspect**, tooltip hover, a level 7 rogue who doesn't use Outrider | answer in 0.4 s; slots: 8 with a link, 1 with an ID only, 9 empty, 0 secret; 8 item levels read; `GetInspectSpecialization` = 1488 (a spec ID); Classic `GetNumTalentTabs` = nil (missing); **`INSPECT_TRAIT_CONFIG_ID` = -1 works**: `C_Traits.GetConfigInfo(-1)` gave 1 tree, 54 nodes read, 0 ranked (expected at level 7: talents start at 10); `C_Traits.GenerateInspectImportString` gave a 35-character string |
| 08:24:02 | **roster**, party of 2 | 1 member unit; role readable (DAMAGER = 1); `CanInspect` true; in inspect range |
| 08:18 | FarmLab loot lines (not Vanguard, but confirms the chat format) | `You receive loot: |cnIQ1:|Hitem:...|h[Linen Cloth]|h|r` parses on Forever |

What this settles: **other players' gear, spec and talent tree can be read by one installation on Forever**, through the modern Traits inspect config (-1), not the Classic talent API. VG00-05's acceptance item ("one non-user inspected with owner present") is met. Still to confirm: a player with talent points spent (ranked nodes greater than 0), a raid roster with subgroups, and a boss kill (`ENCOUNTER_END`).

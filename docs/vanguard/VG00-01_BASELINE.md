# VG00-01: Baseline and inventory

Date: 2026-11-26. Branch: `ai/outrider-personal-intelligence` (the owner's current development branch; nothing merged to `main`).

## Pinned baseline

| Item | Value |
|---|---|
| Baseline commit (before any Vanguard work) | `c2ef910` (Release 0.6.0), parent `52c76f0` (FarmLab) |
| Spec's inspected baseline | `9a2fa615f368c91394b006987905afc863d7854f`. Two commits behind: FarmLab (`52c76f0`) and the 0.6.0 version bump (`c2ef910`). Neither touches the modules Vanguard reuses, apart from Alts.lua's two new `OTR_RUN_START` / `OTR_RUN_END` events (additive) |
| Addon version / interface | 0.6.0 / 16001 (client 1.60.1, build 71139 seen 2026-11-25) |
| Test suite at baseline | 1,521 Lua specs + companion Python tests, all green (`tools/test.ps1 -RequirePython`, run 2026-11-26 before the CurseForge upload) |
| Released | CurseForge file 9826271 (0.6.0) on 2026-11-26, before Vanguard started. No Vanguard code is in any release |

## Reuse targets named in the spec: verified at baseline

| Spec name | Found at | Notes |
|---|---|---|
| DungeonGuide ReadyCheck / ShareReady / PartyText | `addon/Outrider/Modules/DungeonGuide.lua:251, 297, 318` | personal supplies and durability; party message only, not raid inspection |
| DungeonDecision weights .4/.4/.2 | `addon/Outrider/Intelligence/DungeonDecision.lua:12, 18` | `W = { quests = 0.4, gear = 0.4, ready = 0.2 }`; a ranking, never a success probability |
| Fellowship Roster/Canon/Payload/Receive/Members/GroupPlan/Expire | `addon/Outrider/Intelligence/Fellowship.lua:68, 51, 158, 121, 250, 212, 89` | consent sharing, counts shared goals and ready flags |
| DungeonJournal RunCheck / RunSplit / RunEnd | `addon/Outrider/Modules/DungeonJournal.lua:279, 298, 312` | ENCOUNTER_END with success (line 337) |
| Alts run history and lockouts | `addon/Outrider/Modules/Alts.lua` (OnZone / EndRun; fires `OTR_RUN_START` / `OTR_RUN_END` since `52c76f0`) | |
| Forge Survival / Sustain / Range / Run / Compare / Calibrate | `addon/Outrider/Intelligence/Forge.lua:132, 148, 121, 156, 180, 198` | experimental; outputs are estimates |
| Native inspect (already in the addon) | `addon/Outrider/Modules/PlayerInfo.lua:139-224` | one `NotifyInspect` per tooltip hover, out of combat, in range, 3 s gap, never while `InspectFrame` is shown, 15 min session cache in memory only. **Talent read uses `GetNumTalentTabs`, which is missing on Forever (probe 2026-11-25), so the talent line never shows.** Vanguard must not add a second inspect consumer (spec section 5); InspectBroker will take this over in VG01 |
| Class roles | `addon/Outrider/Intelligence/Profiles.lua` `P.ROLES` | potential roles per class only |
| Stat weights | `addon/Outrider/Data/StatWeights.lua` | one levelling role per class, labelled "unverified" |
| Also present for reuse | GearScore, GearShop, GearROI, Talents (`C_Traits`), TalentLab, BuffRow, HealPanel, ClassFight, NexusCore, Opportunity, Planner, AfterAction, Outcomes, Archive, PlaySession, Evidence, State, Comm, Compat, Hub/UI, Events, Timer, FarmLab | |

## Data manifest (content hashes at baseline)

SHA-256 over every file in the folder, concatenated in path order (first 16 hex digits shown). Vanguard VG00 changes none of these files' data, so a recheck must match.

| Folder | Files | Size | Hash |
|---|---|---|---|
| addon/Outrider/Data | 28 | 882 KB | `ffcd5379e1a65c3c` |
| addon/Outrider_Data_Trails | 2 | 116 KB | `87998f6832a7fa18` |
| addon/Outrider_Data_Words | 3 | 862 KB | `9492c43b26ae04f7` |
| private/Outrider_Data_Crafting | 2 | 360 KB | `c559582b7940f454` |
| private/Outrider_Data_Dungeons | 2 | 129 KB | `d5d261c334ad8141` |
| private/Outrider_Data_Gear | 2 | 1545 KB | `94cccd87502d1f82` |
| private/Outrider_Data_Mobs | 2 | 268 KB | `f7780e509e317522` |
| private/Outrider_Data_Nodes | 2 | 310 KB | `ab2374897115f1ad` |
| private/Outrider_Data_NPC | 2 | 583 KB | `36e8f8691d29ba83` |
| private/Outrider_Data_Paths | 2 | 320 KB | `420ae58f3bca67fd` |
| private/Outrider_Data_Quests | 2 | 1302 KB | `29c129c14ee3f5f7` |
| private/Outrider_Data_Reagents | 2 | 315 KB | `1decf4d72ca88a23` |
| private/Outrider_Data_Travel | 2 | 33 KB | `fb7e652d2ce5a6d1` |

The whole `addon/Outrider` folder hash changes with every code commit, so it is not listed as a data hash. Gary's SavedVariables (WTF) are not hashed or read for this; the archive dataset list is `docs/quality/data_preservation_audit.json`.

## Outstanding gates and release state carried into Vanguard

- Owner data-preservation override (D-preservation memory, `docs/quality/data_preservation_audit.json`): binding.
- D18 advice only; hard rules in `CLAUDE.md` section 1 (no combat log, no automation, no protected changes in combat).
- Live checks still pending from before Vanguard: FarmLab first in-game run, shaman totem log check, the 20-30 minute performance session.
- Command Center / desktop work: separately gated, untouched.

## Dependency map (Vanguard -> existing)

```
GroupScan  -> PlayerInfo inspect (to be moved into InspectBroker) , Compat, Events, Timer, Probe
RoleScore  -> GearScore weights, StatWeights, Talents (C_Traits), Profiles.ROLES, Forge (estimates only)
Prep       -> DungeonGuide ReadyCheck, Supply, Quartermaster, GearROI, NexusCore/Opportunity
EncounterIQ-> DungeonJournal + Outrider_Data_Dungeons (bosses, levels, loot; no mechanics), DungeonQuests
History    -> Alts runs, DungeonJournal splits, FarmLab runs, Outcomes, Archive
Sharing    -> Fellowship (consent), Comm
UI         -> Hub sub-tab, Tips, HelpData
```

No new implementation of Vanguard features happens in VG00. The only code added in VG00 is capability probing (VG00-04..06), which records facts and changes no game state.

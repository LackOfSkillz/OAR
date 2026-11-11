# Probe results (measured on Gary's client)

Fill this in during P0-08 from `tools/read-logs.ps1 -Section probe`, and keep it current whenever a later phase probes something new. This file is the source of truth for what exists; FOREVER_CONSTRAINTS.md is the summary.

## Client

| Field | Value | Date |
|---|---|---|
| Version (GetBuildInfo 1) | 1.60.1 (from /ride version) | 2026-11-11 |
| Build (GetBuildInfo 2) | 70888 | 2026-11-11 |
| Interface (GetBuildInfo 4) | 16001 (matches the TOC) | 2026-11-11 |
| WOW_PROJECT_ID | 18 (build date Nov 9 2026) | 2026-11-11 |
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
| Secure test button | ActionButtonUseKeyDown = 1 on Gary's client; with AnyUp+AnyDown one click fired OnClick on down and up. Fixed: register only AnyDown when the CVar is 1, else AnyUp | 2026-11-11 |
| First Discovery capture | npcID 256092 Shadowgale Shriekling, map 2521 (0.598, 0.344) | 2026-11-11 |
| Memory | 577 KB with 5 modules (budget 1.5 MB) | 2026-11-11 |
| Error pipeline | Deliberate error caught once with full stack through Safe/xpcall | 2026-11-11 |

## APIs

Copy the missing list here, and anything surprising in the present list. Note which phase is affected and what the fallback is.

Probe 2026-11-11 11:09 (build 70888): 78 present, 21 missing. The client is a modern (Midnight-era) API surface: Classic-style globals are mostly gone.

| API | Present? | Affects | Fallback / note |
|---|---|---|---|
| GetPetHappiness, GetPetLoyalty, GetPetTrainingPoints, GetPetFoodTypes | missing | P2-09 PetStatus | Redesign needed: probe `C_StableInfo`, `C_PetInfo`, pet buffs/auras next build. Happiness may not exist on Forever |
| GetStablePetInfo, GetNumStableSlots | missing | P2-08 stable check | Probe `C_StableInfo.*` next build |
| GetPetExperience, HasPetUI | present | P2-09 | XP bar and pet presence work |
| GetSpellInfo, PickupSpell | missing | P4 | `C_Spell.GetSpellInfo` present (Compat uses it); probe `C_Spell.PickupSpell` |
| IsSpellKnown, IsPlayerSpell, PlaceAction, GetActionInfo | present | P4 | |
| GetItemInfo, GetItemStats, EquipItemByName | missing | P5, P6 | `C_Item.GetItemInfo`, `C_Item.GetItemStats` present; probe `C_Item.EquipItemByName` |
| GetContainerNumSlots | missing | P5 | `C_Container.*` present (Compat tries it first) |
| GetNumTradeSkills, GetTradeSkillInfo, GetNumCrafts, GetSkillLineInfo | missing | P5 | `C_TradeSkillUI.GetAllRecipeIDs`, `GetProfessions` present: modern profession API |
| QueryAuctionItems | missing | P5 | `C_AuctionHouse.*` present: modern AH only |
| GetQuestLogTitle | missing | P3, P6 | `C_QuestLog.GetInfo` present |
| C_AddOns.GetAddOnMemoryUsage | missing | P1-11 | global `GetAddOnMemoryUsage` present (Perf handles both) |
| InterfaceOptions_AddCategory | missing | P1 | `Settings.*` present (already used) |
| C_VignetteInfo.GetVignettes | present | P2 | Exists; whether rares show as vignettes is still a field question (C9) |
| C_NamePlate.*, UnitClassification, UnitCreatureFamily, UnitCreatureType, UnitGUID, issecretvalue | present | P2 | |
| C_Map.*, C_SuperTrack, UiMapPoint, WorldMapFrame.AddDataProvider, MapCanvas mixins, C_TaxiMap | present | P3 | Native waypoints and map pins available |
| CreateMacro, EditMacro, GetMacroIndexByName, GetNumMacros | present | P2-08, P4 | Used by /ride tamemacro |
| TooltipDataProcessor.AddTooltipPostCall, C_TooltipInfo | present | P2-10, P5 | Modern tooltip hooks |
| C_ChatInfo addon messages, guild/friends APIs | present | P8 | |
| Masque | missing | P7 | optional addon, not installed |
| C_StableInfo.GetStablePetInfo, GetNumActivePets, GetNumStablePets | present (2026-11-11 11:19) | P2-08, P2-09 | Use for stable/free-slot checks |
| C_UnitAuras.GetAuraDataByIndex, UnitPower | present | P2-09 | Pet happiness may be an aura on Forever; focus via UnitPower("pet") |
| GetPetFoodList | missing | P2-09 | Diet must come from a data pack or the pet's tooltip |
| C_PetInfo.GetPetTamersForMap | present | P2 | (battle-pet tamers; not hunter pets) |
| C_Spell.PickupSpell, C_SpellBook.PickupSpellBookItem, C_SpellBook.GetNumSpellBookSkillLines | present | P4 | Modern spellbook API |
| C_Item.EquipItemByName | present | P6 | |
| C_EventUtils.IsEventValid | present | P0 | Probe checks events without registering them |

## Events

| Event | Registers? | Note |
|---|---|---|
| COMBAT_LOG_EVENT_UNFILTERED | Registers without an error, but fires ADDON_ACTION_FORBIDDEN and Blizzard offers to disable the addon (2026-11-11) | Never touch (C5, Events.FORBIDDEN) |
| CRAFT_SHOW | unknown event | No Classic craft frame; enchanting is in the profession UI |
| NAME_PLATE_UNIT_ADDED, UPDATE_MOUSEOVER_UNIT, PLAYER_TARGET_CHANGED, VIGNETTE_MINIMAP_UPDATED, UNIT_PET, PET_STABLE_SHOW, MERCHANT_SHOW, GOSSIP_SHOW, TRAINER_SHOW, TAXIMAP_OPENED, LOOT_OPENED, QUEST_COMPLETE, TRADE_SKILL_SHOW, AUCTION_HOUSE_SHOW, BAG_UPDATE_DELAYED, CHAT_MSG_ADDON, EDIT_MODE_LAYOUTS_UPDATED, ADDON_ACTION_BLOCKED/FORBIDDEN | register | |

## Units (out of combat vs in combat)

| Unit | GUID readable | Name readable | Classification | Note |
|---|---|---|---|---|
| player (out of combat) | yes | yes | normal | 2026-11-11, map 2521 |
| target (out of combat) | yes | yes | normal, family Bear | 2026-11-11, npcID 250927 Shadowgale Ursera |
| target (in combat) | yes | yes | normal, family Bear | 2026-11-11 11:14:33: no secret values on GUID/name/classification/family |
| nameplate1 (out of and in combat) | yes | yes | normal, family Bear | 2026-11-11: nameplate reads work in combat too |

Combat timing: `PLAYER_REGEN_DISABLED` fires while `InCombatLockdown()` is still false (2026-11-11). Protected changes made inside that handler still go through; checks that need lockdown wait a moment.

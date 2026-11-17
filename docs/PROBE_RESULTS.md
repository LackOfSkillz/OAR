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
| Pet health / focus | `UnitHealth("pet")` and `UnitPower("pet")` came back secret (shown as ? before the fix); `UnitHealthMax("pet")` readable (380), `GetPetExperience` readable (694/2525). Display raw, never compute (C6) | 2026-11-11 |
| UnitPosition order | Walk test 2026-11-11: the FIRST value is north-south (falls walking south), the second east-west (rises walking west). Minimap dots now use map coords x map size, which does not depend on this | 2026-11-11 |
| Map 2521 size | 5562 x 3708 yards (measured from map corners via C_Map.GetWorldPosFromMapPos) | 2026-11-11 |
| World axes | `C_Map.GetWorldPosFromMapPos` returns its axes swapped relative to `UnitPosition` (exact match after swapping, 0.0 yards). Waypoints:Calibrate() detects it at login | 2026-11-11 |
| Pet happiness | No GetPetHappiness and no buffs on the pet (Dog, Cat 12, npcID 165189). BUT the pet window shows loyalty "(Rebellious)" for Mystmane, so loyalty (and likely happiness) exist on Forever behind other APIs; PetStatus now logs C_StableInfo.GetStablePetInfo fields to find them | 2026-11-11 |
| Hunter pet GUID | Every hunter pet has npcID 165189 in its GUID (Dog and Mystmane alike), so a tame is detected from the Tame Beast channel target instead | 2026-11-11 |
| Mystmane (tamed by Gary) | npcID 259388, found by nameplate at map 2521 59.8, 34.4 on layer 1 (rare alert fired 12:54:53). Bear, level 13, Health 424, Armor 797, Damage 18-24, Attack Power 56, Crit 5.0%, Haste 2.0%, Movement speed 114%, loyalty Rebellious (pet window screenshot) | 2026-11-11 |
| Mystmane respawn | Not on a 3 h timer from the server restart: restart 15:00 EST 2026-11-13, nothing but Shadowgale Ursera / Shriekling at her spot through the 18:00 and 21:00 windows (spawn log). Spot refills about 12-14 min after each kill; 1 other rare (Den'dralass) in about 25 spawns. Community guides also say no fixed timer (1.5-3 h typical, sometimes far longer) | 2026-11-13 |
| Mystmane spawn seen | 2026-11-13 22:39:57 EST, layer 11, map 2521 0.599,0.341: Den'dralass spawned 22:36:49 (12m42s after a bear died), died 22:37:30, Mystmane up 2m27s later, dead 1 s after Gary targeted her (killed by Gary's own pet while he was distracted). 7h40m after the 15:00 restart. Earlier Den'dralass kill (11:33) was followed by a bear, so "after Den'dralass" is 1 of 2 | 2026-11-13 |
| Pet attack speed | UnitAttackSpeed("pet") is readable. Tamed Mystmane (Torrant, level 14, Dependable, happy): 1.57 s, damage 20.3-26.4 (about 14.9 white DPS). Fox (Khreos, level 14, Best Friend, happy): 1.96 s, damage 27.6-35.9 (about 16.2). Wild readings (UnitAttackSpeed on hostile NPCs) were 2.0 for all 3 measured, so a wild speed says nothing about the tamed speed | 2026-11-14 |
| Fishing soft target | SetCVar SoftTargetInteract=3, SoftTargetInteractArc=2, SoftTargetInteractRange=30 all read back as set; with them the INTERACTTARGET binding hooks the bobber without the mouse on it (Gary: "that worked"). Minimap vignettes: none seen in 30 min of play at Zephras Isle (C9 likely holds) | 2026-11-14 |
| Profession window | C_TradeSkillUI.IsTradeSkillReady stayed false with the Alchemy window open, and GetBaseProfessionInfo once gave an empty professionName: track TRADE_SKILL_SHOW/CLOSE and take the first non-empty name. CraftRecipe from a /ride press works: 10 x Elixir of Minor Defense (orange) took Alchemy 20 -> 30, the trainer estimated +10 | 2026-11-14 |
| Weapon skills | IsPlayerSpell with the Classic weapon-skill spell ids reads Khreos (Skyborne hunter, 15) as Bows, Daggers, Swords, Two-Handed Swords: the ids hold on Forever, so the gear shop uses the learned skills. Browse queries by itemClassFilters + minLevel/maxLevel work: armor 104 items over 15 slot searches, weapons 120 in one | 2026-11-14 |
| Starting weapon skills | A new Skyborne warrior (Littlesword, level 1) knows Bows, Daggers, Maces, Swords, Thrown, Two-Handed Maces and Two-Handed Swords at level 1, so bows are fair gear suggestions for warriors. | 2026-11-15 |
| AH buying | From Gary's clicks: SendSearchQuery + GetItemSearchResultInfo + PlaceBid bought a Blackwater Cutlass (39s) and Agile Boots (16s); StartCommoditiesPurchase (sent automatically after a Buy click) + COMMODITY_PRICE_UPDATED + ConfirmCommoditiesPurchase on the confirm click bought Peacebloom x2 (80c) and Chunk of Boar Meat x10 (2s 90c) | 2026-11-14 |
| Minimap view radius | 333.3 yards at Gary's zoom (C_Minimap.GetViewRadius) | 2026-11-11 |
| Tame Beast | A channel on Forever (bar drains to zero, tame completes at zero; Gary 2026-11-11). `/stopmacro [channeling]` guards the tame macro | 2026-11-11 |
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
| C_AssistedCombat.GetNextCastSpell | present, but IsAvailable() false for a level 5 hunter (2026-11-12) | P4 | Blizzard one-button rotation API exists but is not offered on Forever (at least at low level); the Fight macro stays the answer |
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

## Events missing on Forever (2026-11-11, Gary login screenshot)

- `TABARD_FRAME_OPENED` and `PETITION_VENDOR_SHOW` cannot be registered (RegisterEvent errors). POICapture learns tabard vendors and guild masters from gossip titles instead; the warning now goes to the log only.

## Edit Mode survey (P7-03, auto probe 2026-11-11 19:00, build 1.60.1 70888)

- `C_EditMode` has GetLayouts, SetActiveLayout, SaveLayouts, GetAccountSettings, ConvertLayoutInfoToString. GetLayouts lists only Gary's own layouts ("Test 1" type 1 account, "test 2" type 2 character); activeLayout = 5, so the built-in presets (Modern, Classic) are counted before them but not returned.
- `EditModeManagerFrame` exists with 55 registered system frames: GameTooltipDefaultContainer, RaidWarningFrame, LossOfControlFrame, TalkingHeadFrame, ArcheologyDigsiteProgressBar, Main/SecondaryStatusTrackingBarContainer, PlayerCastingBarFrame, ExtraAbilityContainer, LootFrame, VehicleSeatIndicator, ChatFrame1, MicroMenuContainer, MainActionBar, MultiBarBottomLeft/BottomRight/Left/Right, MultiBar5/6/7, MainMenuBarVehicleLeaveButton, StanceBar, PossessActionBar, PetActionBar, MultiCastActionBarFrame, MinimapCluster, BuffFrame, DebuffFrame, ExternalDefensivesFrame, EncounterBar, PlayerFrame, PartyFrame, TargetFrame, FocusFrame, BossTargetFrameContainer, PetFrame, ObjectiveTrackerFrame, CompactRaidFrameContainer, Essential/Utility/BuffIcon/BuffBar CooldownViewer, **DamageMeter** (Blizzard's own), DurabilityFrame, GamepadMainActionBarFrame, BagsBar, MirrorTimerContainer, PersonalResourceDisplayFrame, QueueStatusButton, SwingTimerMainHand/OffHand/Ranged, plus two unnamed.
- Not Edit Mode systems: MicroMenu (its container is), StatusTrackingBarManager, TimerTracker, ArenaEnemyFramesContainer.
- Protected (never touch in combat): action bars, PlayerFrame, TargetFrame, FocusFrame, PetFrame, PartyFrame, BossTargetFrameContainer, MicroMenuContainer, ArenaEnemyFramesContainer.
- Consequence for P7: position and size of all of these belong to Edit Mode (Gary moves them there). Outrider's skin (P7-04/06) only changes textures, colors and fonts, out of combat, and never calls SetPoint/SetSize on them. Context layouts (P7-09) can switch layouts with C_EditMode.SetActiveLayout out of combat.

- 2026-11-11 21:10: memory measured after a full garbage collection at logout: 2677 KB live (4171 KB before collection). The earlier 6.3 MB was uncollected garbage; Outrider is under the 3 MB budget.

## C_TradeSkillUI.GetRecipeInfo fields (measured 2026-11-12, Alchemy/Herbalism window)
alwaysUsesLowestQuality, canCreateMultiple, canSkillUp, categoryID, craftable, disabled, favorite, firstCraft, hasSingleItemOutput, hyperlink, icon, isDummyRecipe, isEnchantingRecipe, isGatheringRecipe, isRecraft, isSalvageRecipe, itemLevel, learned, maxTrivialLevel, name, numSkillUps, recipeID, relativeDifficulty, skillLineAbilityID, supportsCraftingStats, supportsQualities. **No numAvailable**: Crafter asks GetCraftableCount, else counts reagents in the bags.
| Player race | UnitRace on Khreos: "High Order Skyborne", file "Skyborne", raceID 95 (Alliance). Questie's faction-wide race masks predate it, so NPCPack.RaceOK treats a mask naming all original races of your faction as faction-wide | 2026-11-13 |
| Pet feeding | Feed button = secure type "spell" Feed Pet with target-item works (drawn above the panel). Refusal text: "Your pet doesn't like that food." Fox refused Red Delicious Stormapple, ate Galestrider Jerky | 2026-11-13 |

## Official fight data (probe 2026-11-16 15:05, build 70938, 1.60.1)

All present: C_DamageMeter (IsDamageMeterAvailable, GetAvailableCombatSessions, GetCombatSessionFromType/FromID, GetCombatSessionSourceFromType/FromID), C_EncounterTimeline.GetEventList, C_CooldownViewer.GetCooldownViewerCategorySet, C_Spell.GetSpellCooldown/GetSpellCharges, C_UnitAuras.GetPlayerAuraBySpellID, UnitDamage, UnitAttackSpeed, UnitRangedDamage, UnitAttackPower, UnitRangedAttackPower, GetCritChance, GetRangedCritChance, GetHitModifier, UnitArmor, UnitStat, GetDodgeChance, UnitThreatSituation, UnitDetailedThreatSituation, UnitXP, UnitXPMax, GetXPExhaustion.
Events valid (IsEventValid, not registered): UNIT_COMBAT, UNIT_THREAT_SITUATION_UPDATE, UNIT_THREAT_LIST_UPDATE, PLAYER_XP_UPDATE, DAMAGE_METER_COMBAT_SESSION_UPDATED, DAMAGE_METER_CURRENT_SESSION_UPDATED, DAMAGE_METER_RESET, ENCOUNTER_TIMELINE_EVENT_ADDED, COOLDOWN_VIEWER_DATA_LOADED.
Return shapes of C_DamageMeter: not known yet; AutoCheck logs them after the first 3 fights of a session (Probe:DamageMeter).
Measured 2026-11-16 (Khreos, Redridge): Enum.DamageMeterType = DamageDone 0, Dps 1, HealingDone 2, Hps 3, Absorbs 4, Interrupts 5, Dispels 6, DamageTaken 7, AvoidableDamageTaken 8, Deaths 9, EnemyDamageTaken 10; Enum.DamageMeterSessionType = Overall 0, Current 1, Expired 2. GetAvailableCombatSessions() lists ~30 recent fights {sessionID, name (the mob), durationSeconds}. GetCombatSessionFromID(id, type) returns {durationSeconds, totalAmount, maxAmount, combatSources = {{name, sourceGUID, isLocalPlayer, classFilename, totalAmount, amountPerSecond, ...}}}; amounts readable out of combat, specIconID secret. The *FromType calls returned empty tables after the fight. Only the player was listed as a source (pet merged or absent: next capture checks).

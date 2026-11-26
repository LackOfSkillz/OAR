# VG00-07: Data and modelling feasibility

Date: 2026-11-26. Source inventory at baseline `c2ef910`. "Have" means the data or code exists in the repo. It does not mean the data is verified in game (hard rule 7: most packs are `verified = false`).

## Nine-class coverage matrix

| Class | Roles in `Profiles.ROLES` | Stat weights (`Data/StatWeights.lua`) | Spell facts (`Data/SpellInfo.lua`) | Self-buffs (`BuffRow`) | Fight key (`ClassFight`/`HunterFight`) | Heal panel | Talents (own, C_Traits) | Interrupt / dispel / CC / res named in SpellInfo |
|---|---|---|---|---|---|---|---|---|
| Warrior | tank, melee | 1 levelling role, unverified | yes | yes | yes | — | yes | Pummel, Shield Bash |
| Paladin | tank, melee, healer | 1 role | yes | yes | yes | yes | yes | Cleanse/Purify, Redemption |
| Hunter | ranged, pet | 1 role | yes | yes | yes (HunterFight) | yes (pet) | yes | Freezing Trap |
| Rogue | melee | 1 role | yes | yes | yes | — | yes | Kick, Sap |
| Priest | healer, caster | 1 role | yes | yes | yes | yes | yes | Dispel Magic, Shackle Undead, Resurrection |
| Shaman | healer, caster, melee | 1 role | yes | yes | yes (totems 2026-11-26) | yes | yes | Earth Shock, Purge, Ancestral Spirit |
| Mage | caster | 1 role | yes | yes | yes | — | yes | Counterspell, Polymorph, Remove Lesser Curse |
| Warlock | caster, pet | 1 role | yes | yes | yes | — | yes | Banish, Fear (no Soulstone entry) |
| Druid | tank, melee, caster, healer | 1 role | yes | yes | yes | yes | yes | Abolish/Cure Poison, Remove Curse, Hibernate, Rebirth |

25 utility spells (interrupts, dispels, crowd control, resurrection; checked by name 2026-11-26) are named in SpellInfo with level and icon. That gives **potential** capability per class and level. Whether a player has trained a spell, or will use it, cannot be read for other players. Vanguard must show these as "can have", never as "has".

## Gaps (no inferred mechanics; each stays unknown until a source is cited)

| Needed for | Have | Missing | Plan |
|---|---|---|---|
| Role-specific RoleScore | one levelling weight set per class, labelled unverified | tank, healer and dps weight sets per class; hybrid specs | VG02: role weight sets with a source label. Where none exists, show stats without a score |
| Tank survivability | `Forge.Survival(hp, armor, avoid, level)`, experimental | armor and avoidance formulas verified for Forever; other players' armor and avoidance (not readable) | own character only; other players stay unknown |
| Healer endurance | `Forge.Sustain(pool, regen, spent)` | other players' mana pool (only the max is readable via `UnitPowerMax`), regen, bonus healing | max mana when readable, the rest unknown |
| DPS potential | Forge.Range / Run, SimGear-like weights are not available | verified Forever formulas | gear-level and stat summary only; no DPS numbers for others |
| Buff stacking and subgroup rules | own buffs per class (BuffRow) | party vs raid scope, exclusive auras, Forever-specific changes (one competitor reports some raid-wide Classic buffs are personal on Forever) | VG02 CapabilityRegistry with a source and "verified" flag per rule |
| Encounter requirements | `Outrider_Data_Dungeons` (QuestieDB-derived): dungeon list, map position, boss and mob NPC IDs, levels, loot IDs; `verified = false` | encounter IDs, mechanics, interrupt/dispel/resistance needs, sizes for raids | VG03 EncounterCatalog: manual, labelled templates; requirement weights only from cited sources; unverified raids marked preview |
| Access / attunement | Leveling_DungeonQuests, Questie-derived quests | Forever attunement graph (Onyxia: Drakefire Amulet in bags per Blizzard's raid overview; Barrow and Hyjal: none named) | VG02 AccessTracker from cited sources, manual states |
| Supplies | DungeonGuide ReadyCheck (food, water, ammo, reagents, durability), Supply, Quartermaster | per-encounter consumable needs | reuse; encounter needs come from templates |
| Gear upgrades and cost | GearScore, GearShop, GearROI, Prices (Auctionator/TSM/own) | — | reuse through Nexus |
| Inspected other players | PlayerInfo (item level, quality counts, weapon) | talents on Forever (Classic API missing; Traits path pending VG00-05) | VG01 after the live probe |

## History available for GroupHistory (counts are not read here; Gary's SavedVariables stay closed while he plays)

| Dataset | Path | What it holds | Usable for Vanguard |
|---|---|---|---|
| Dungeon runs | Alts (`dungeonRuns` in the preservation audit) | instance, time in, lockouts | run identity and duration |
| Boss splits | DungeonJournal RunCheck/RunSplit/RunEnd | kill times from `ENCOUNTER_END` success | per-boss kill timing (own runs) |
| Farm runs | FarmLab (`global.farmlab.runs`, new 2026-11-26) | coin, loot, costs per dungeon run | cost and value side of prep plans |
| Outcomes / AfterAction | Intelligence/Outcomes, AfterAction | session outcomes, opt-in | completion labels, if recorded |
| Group composition at run time | **none** | — | new in VG05 (anonymous aggregates only, D27) |
| Wipes | **none**; `ENCOUNTER_END` with success 0 is the only permitted signal | — | VG05; never infer a wipe from a disconnect |

**Forecast feasibility:** no run is stored with its group composition today, so there is no training data for SuccessForecast. VG05 must start by recording, and the forecast stays **abstaining** until the spec's floors are met (at least 200 labelled runs per cohort, 50 held out). For one player, that is months of play at the earliest. Descriptive rates with Wilson intervals are feasible sooner.

## Conclusions for later phases

- T0 (roster only) and T1 (inspect) are feasible on known APIs, except other players' talents, which depend on VG00-05 live evidence.
- RoleScore can score gear for the player's own role with labelled starting weights. For other players it can show item level, quality and enchant presence, not throughput.
- EncounterIQ needs a new catalog. Existing packs have bosses and loot, not mechanics. Encounter requirements start as manual, labelled templates.
- History needs new composition capture before any learning. Forecast abstains by design until the evidence floors are met.

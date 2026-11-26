# VG02: Role modeling and preparation parity (evidence)

Date: 2026-11-26. Built straight after VG01 by Gary's instruction (D28: gates batched into one final review). Baseline: `a1e9b17` (VG01). The commit that adds this file is the candidate.

Status: **code and unit tests done; live checks pending.** Mock results are not live passes.

## What was built

| Task | Where | What it does |
|---|---|---|
| VG02-01 Role evidence registry | `Vanguard/Roles.lua` | All nine classes, with the roles each can fill and the kind of player (tank, healer, melee, ranged, caster). Hybrids (shaman and druid damage) list every kind until the build is known. Each profile lists the stats to read and what is **not modeled** (armor-to-mitigation, threat, healing per second, mana endurance, damage per second, rating-to-percent). Source: Classic class design, `verified = false`; faction limits are not assumed. |
| VG02-02 Gear stat derivation | `Vanguard/Stats.lua` | Adds up item stats from the game's item stat API (`GearScore.Stats`, `C_Item.GetItemStats`) as a range `{lo, hi}`. An empty slot adds a known zero. A pending, unreadable or unavailable slot, an item whose stats didn't come back, or an enchant (there is no verified enchant table) opens the top end: the total is "at least". Derived values are labeled derived and kept apart from observations. |
| VG02-03 Tank adequacy | `Vanguard/Adequacy.lua` | Stamina, armor, defense, dodge/parry/block rating, resistances. No armor or avoidance formula. |
| VG02-04 Healer adequacy | same | Intellect, spirit, healing and spell power, mana per 5, stamina. No healing per second, no mana endurance. |
| VG02-05 DPS adequacy | same | Melee (strength, agility, attack power, crit, hit, main weapon dps), ranged (agility, attack power, crit, hit, ranged weapon dps), caster (intellect, spell power, crit, hit, spirit). No damage per second number. Forge is not used (experimental, not validated). A target check only happens against a target (catalog or yours): met, short, unknown when the range spans it, or "no target" (reference only). |
| VG02-06 Class utility registry | `Vanguard/Utility.lua` | 22 capabilities (interrupt, five dispel kinds, purge, crowd control, stun, resurrection, battle resurrection, taunt, buffs, auras, innervate, tranquilizing shot, water breathing). A spell only counts if the Forever spellbook data (`Data/SpellInfo.lua`, `verified = false`) has it for that class, with its trainer level. States: verified (your own spellbook), potential (class and level), unlikely (below the data's level), talent (only if taken), unknown, none. |
| VG02-07 Stacking and scope | same | A buff from two providers of the same kind counts once; effects that each provider adds (interrupts, blessings) count per provider; party-scope effects record which subgroups have them; an unknown rule counts once. "Nobody" only when every member's class is known; one unreadable member makes it unknown. |
| VG02-08 Personal prep profiles | `Vanguard/Prep.lua` | Dungeon or raid, 10 to 600 minutes: food and drink per hour (drink only for mana users), ammo per hour for hunters, repair level, free bag slots, class reagents only for spells you know. Carried counts; the bank is shown apart and never counted. Amounts are Outrider's starting points, labeled as such. Nothing is used or bought. |
| VG02-09 Equipment and access | same | Empty gear slots (missing), unreadable slots (unknown), missing enchants on enchantable slots (each enchant depends on the item being there), level against the place's reference range, access as your own answer (unknown until you say), your own checklist items marked as yours. |
| VG02-10 Journal links | same | Quests to pick up or finish and upgrades for you in the chosen place, from `DungeonGuide:QuestList` and `DungeonGuide:Upgrades`. Fails soft without the packs. No copied data. |

UI: Group check gains a drilldown for the clicked member (their role's stats as ranges, notes, what isn't modeled) and a group utility line. New page Dungeons > **Prep checklist (preview)**, which works with Group check off (it reads only your own bags, gear and spellbook). `/ride prep add|done|undo|drop` for your own items.

## Tests

`tests/spec/vanguard_roles_spec.lua` (8 tests, negative cases included):
- nine classes, hybrids, not-modeled lists, unsupported role, unknown class or role;
- stat ranges: empty is zero, pending/unreadable opens the top, enchants open the top, unread item stats are not zero, a stat nobody has with everything read is a known zero;
- indicators: no target means reference only; met, short, and unknown when gear is unread; healer has no hps; hunter, rogue and mage read different indicators;
- utility: level gating, talent spells, a class with none, unknown class, every counted spell is in the Forever data, your spellbook verifies;
- coverage: two priests give one stamina buff, interrupts add up, "nobody" vs "unknown", party scope by subgroup;
- prep: amounts scale with time, carried vs bank (12 carried with 40 banked is still short), a failed bag scan is unknown, reagents only when the spell is known;
- equipment: empty is missing, unreadable is unknown and makes no enchant claim, enchant depends on the item, access unknown is not denied, your own items are labeled;
- journal: no data fails soft, finished quests left out.

`tests/spec/vanguard_spec.lua`: drawing Group check with a selected member, and the Prep page, sends no inspect.

## Data preservation

No saved dataset is changed or shrunk. New per-character settings for the Vanguard module: activity, minutes, place, access answers and your own checklist items. Nothing about other players is saved. The mock's `C_Item.GetItemCount` now honours `includeBank` (test-only change).

## Live checks still needed

- Prep checklist on Torrant before a dungeon: amounts, bank line, ammo, reagents (L09 part).
- Group check drilldown on a real party (L01) and the stat API on inspected links (item stats for other players' gear).
- Class roles and utility for all nine classes (L06).

## Known limits

- Enchant bonuses are not added (no verified enchant table): enchanted slots make totals "at least".
- Talent-granted abilities show as "only by talent"; the inspected talent tree isn't mapped to spells.
- Reagent names are Classic names, unverified on Forever; a reagent shows only when its spell is in your spellbook.

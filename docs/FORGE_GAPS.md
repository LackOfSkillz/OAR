# Forge: what it doesn't model yet (review OI-FR07)

The Forge (Intelligence/Forge.lua, shown as "Your damage estimate" on the Gear page) is **experimental**. Its card carries an Experimental tag. It never claims a full simulation. Anything it can't model goes into the report's "not modelled" list and widens the result into a range.

| Gap | Effect today | What closing it needs | Classes hit hardest |
|---|---|---|---|
| Rage generation | Rage costs are known, but the pool isn't simulated, so the report is partial | Rage from damage dealt and taken (formula from a cited source, checked on Forever) | Warrior, Druid (bear) |
| Energy regeneration | Energy costs are known, but there is no regen tick, so the report is partial | The 20-per-2-s tick, checked on Forever | Rogue, Druid (cat) |
| Combo points | Finishers are not scaled by points | A builder/finisher cycle model | Rogue, Druid (cat) |
| Procs | Not modelled (listed) | Proc chances from a cited source; spells read from tooltips | Most melee, Shaman, Paladin |
| Spell-changing talents | Not modelled (listed) | Talent effects on spells from TalentSim | All classes |
| Haste changes during a fight | Not modelled (listed) | Haste buffs with their uptime | Melee, Hunter |
| Target hit, armour and resistances | The interval is widened (MISS_WIDEN, ARMOR_WIDEN) | Target data per mob from capture | All classes |
| Buffs and debuffs from others | Not modelled (listed) | Group context | All classes |
| Talents page integration | Not built; the Gear page only | A "What if?" on Talents using TalentSim plans | All classes |

Rules that stay in place:

- No made-up precise numbers.
- Every gap appears in the report.
- No figure counts as verified until it has been checked against a training dummy in game (Forge.Calibrate).

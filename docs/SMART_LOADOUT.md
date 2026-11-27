# Smart loadout: the right imbue, buff and totem for the mob in front of you

Status: design, 2026-11-27. Nothing built yet. Asked for by Gary after a mob that
took almost no physical damage and about 3x fire damage.

## What we want

When Gary targets a mob, his fight keys should already hold the best choice for
that mob: Flametongue instead of Rockbiter, Fire Nova or Searing Totem, a
Fire Resistance Totem if it throws fire, Seal of Righteousness instead of Seal of
Command, Frostbolt instead of Fireball, and so on. This works for every class.

## What the game lets us do (hard rules)

- **A macro can't see a mob's weak spots.** Macro conditions know modifiers, stance,
  combat, and whether a target exists or is dead. They know nothing about schools
  or resistances.
- **Outrider can rewrite macros, but only out of combat.** The fight keys already
  get rewritten when a buff drops, a totem goes down or a spell is learned (ClassFight,
  HunterFight). Changing the target is one more trigger for the same rewrite.
- **In combat, nothing changes.** The one in-fight switch is a modifier key that is
  already in the macro (Shift = the other imbue today).
- **Every cast is Gary's own key press.** One press = one spell, the same as now.
  Outrider never casts anything on its own (hard rule 1).
- **No combat log.** COMBAT_LOG_EVENT_UNFILTERED is off limits (hard rule 4).

## Known from day one: databases (added 2026-11-27, Gary: "it already knows")

Outrider should already know most mobs on the first pull. Learning from fights only
fills in Forever's changes.

| Source | What it gives | Licence / rule |
|---|---|---|
| VMaNGOS and cMaNGOS `creature_template` (ForeverDB already merges both) | Per mob: resistance to each school (holy, fire, nature, frost, shadow, arcane), schools it is immune to, mechanics it is immune to (fear, stun, root, bleed, poison...), creature type | GPL. Private pack (D10) |
| VMaNGOS and cMaNGOS `creature_spells` / AI scripts | The spells each mob casts at you, which gives the totem, aura or ward to bring, and whether it fears, poisons or heals | GPL |
| Forever client tables on wago.tools (`SpellMisc`: SchoolMask) | The exact school of every spell, ours and the mobs', from Forever's own client | Blizzard game data, the same way ForeverDB already uses it |
| Wowhead Forever pages | Not scraped (their terms forbid it). When Gary looks up one mob and tells us, the row goes in with that page as its source | per row |

This becomes a load-on-demand pack, `Outrider_Data_Mobs` (it already holds every
mob's id, name and level), with an extra `res` field per mob:
`{ fire = 75, immune = { "fire" }, mech = { "fear" }, casts = { "fire", "frost" } }`.
It stays `verified = false`.

The server databases are 1.12 data. Forever's own mobs, and changes like a 3x fire
weakness, aren't in them. So the order is: **own fights > Wowhead row Gary checked >
server databases**. Learning becomes a correction layer on top of the pack instead
of the only way in.

Needs Gary's OK (hard rule 10): downloading the VMaNGOS world database dump
(GitHub, tens of MB) and `SpellMisc.csv` from wago.tools, the same place as the
CSVs already in `private/wago-source`.

## Learned in game (corrections)

Most trustworthy first. Every learned fact starts as `verified = false`.

1. **Gary's own fights** with that mob, read after combat ends:
   - **Blizzard's damage meter**, which FightMeter already reads. Each fight session
     is named after the mob. We still need to capture whether it splits damage by
     spell or by school.
   - **UNIT_COMBAT on the target.** This is the event behind the hit numbers on the
     target portrait, not the combat log. It reports the school, the amount, and
     IMMUNE, RESIST or ABSORB. It is valid on Forever. We don't know yet whether the
     amounts are readable in combat or come back secret. **Gary's call:** this is
     close to hard rule 4. See question 2.
   - **The math.** Per school, take the average hit on this mob and divide it by
     Gary's usual hit with that school on other mobs his level (a rolling
     baseline). At 1.5x or more the mob is weak to that school. At 0.5x or less it
     resists it. Any IMMUNE flag means immune. It takes at least 8 hits per school
     before anything is believed.
2. **What the mob does to you:**
   - Its cast bar (`UnitCastingInfo`) gives the spell name, and so the school.
   - The debuffs it puts on you give a type (poison, disease, curse, magic) and fear.
   - These choose the resistance totems and auras, Poison or Disease Cleansing
     Totem, Tremor Totem, Fire Ward, Shadow Protection, and so on.
3. **What the client shows about the mob:** creature type (Elemental, Undead,
   Demon), family, and any tooltip line that names a school ("Vulnerable to Fire",
   "Immune to Nature"). We capture tooltip lines first so we can see whether
   Forever has such lines.
4. **Cited starter data:** a small pack with a source for each row, for example
   "fire elementals are immune to fire". Our own fight results always override it.
   Later, guild members can share mob profiles over GUILD (KitShare already does
   this kind of thing), and only if Gary switches it on.

## Mob profile (account-wide)

`ns.db.global.mobSchools[npcID]`:

```lua
{ name = "…", seen = 12,
  schools = { physical = { mult = 0.2, n = 40 }, fire = { mult = 3.1, n = 11 } },
  immune  = { nature = true },
  casts   = { fire = 6 },          -- spells it cast at you, by school
  debuffs = { poison = 3, fear = 1 },
  source  = "fights", verified = false }
```

If a mob has no profile of its own, a profile from the same creature family is a
weak hint. It is shown as "probably" and is never used to swap an imbue.

## The chooser

Each class gets a short list of slots. Each slot holds options, and each option
names its school, or what it counters. Each option's score is its school's
multiplier on this mob, plus counters for what the mob does. The highest score
wins. If nothing is known, the current choice stays (today's behaviour).

| Class | Slot | Options | Picked by |
|---|---|---|---|
| Shaman | weapon imbue | Rockbiter (physical), Flametongue (fire), Frostbrand (frost), Windfury (physical) | mob's school multipliers |
| Shaman | fire totem | Searing, Magma, Flametongue Totem; Frost Resistance Totem | fire multiplier; Frost Resistance if the mob casts frost |
| Shaman | earth totem | Strength of Earth, Stoneskin, Tremor | Tremor if it fears |
| Shaman | water totem | Mana Spring, Fire Resistance, Poison Cleansing, Disease Cleansing | what the mob casts or puts on you |
| Shaman | air totem | Grace of Air, Nature Resistance, Grounding | Nature Resistance or Grounding against casters |
| Shaman | shock | Earth / Flame / Frost Shock | school multiplier |
| Mage | main nuke | Frostbolt / Fireball / Arcane Missiles | school multiplier |
| Mage | ward | Fire Ward / Frost Ward | what the mob casts |
| Warlock | main nuke | Shadow Bolt / Searing Pain, Immolate | shadow vs fire |
| Warlock | curse | Agony (Bane) / Elements / Shadow / Tongues | Tongues against casters |
| Priest | nuke | Smite, Holy Fire / Mind Blast, Mind Flay | holy vs shadow; undead |
| Priest | buff | Shadow Protection | the mob casts shadow |
| Paladin | seal | Righteousness (holy) / Command, Crusader (physical) | holy vs physical |
| Paladin | aura | Devotion / Fire, Frost, Shadow Resistance Aura | what the mob casts |
| Paladin | extra | Exorcism, Holy Wrath | undead and demons |
| Druid | form | caster (Wrath, Moonfire) / Cat, Bear (physical) | nature/arcane vs physical |
| Hunter | shots | Arcane Shot, Serpent Sting (arcane, nature) vs Auto Shot weight | school multiplier |
| Hunter | aspect | Hawk / Wild (Nature resist) | the mob casts nature |
| Rogue | poison | Instant (nature) / Crippling, Mind-numbing against casters | nature multiplier, casters |
| Warrior | — | physical only | warns "this one shrugs off physical: bring a caster or a wand" |

Spell schools come from a cited table (`Data/SpellSchools.lua`) and stay
unverified until they're checked against Gary's own hits.

## How it reaches Gary's keys

1. **Out of combat, when he targets a mob,** the fight macros are rewritten with
   the best options: the same one-press-one-spell lines, in the same buffs-first
   order. A wrong imbue counts as "missing", so the next press re-imbues. It only
   switches when the gain is real: 1.5x or more, from a believed profile, and the
   mob isn't grey. That way re-imbuing doesn't burn mana and global cooldowns on
   trash.
2. **In combat,** the macros stay as they are. Each slot's second-best option
   stays on Shift. A small icon on the buff row shows the hint, for example a fire
   icon with "x3 · Shift". There's no chat line and no sound.
3. **The first fight with a new mob** teaches Outrider. From the second pull on,
   the keys are right before he presses them.
4. The fight page's "why" line names the reason: "Flametongue: this mob took 3.1x
   fire over 11 hits."

## Build order

| Id | What | Who |
|---|---|---|
| SL-00 | Mob resistance pack from VMaNGOS/cMaNGOS plus Forever spell schools from SpellMisc (needs the download OK) | Claude |
| SL-01 | Capture only: UNIT_COMBAT on the target (readable or secret, in and out of combat), whether the damage meter splits by spell or school, the target's casts and the debuffs it puts on you, tooltip lines, and the enchant id on the weapon (which imbue is on). Everything goes to the log. | Both |
| SL-02 | Mob profiles plus the multiplier math, with specs for baselines, minimum hits and immune flags | Claude |
| SL-03 | The shaman chooser: imbue, the four totem elements, shock. Rewrite on target change. | Both |
| SL-04 | The hint icon on the buff row, plus the "why" line | Both |
| SL-05 | The other eight classes, one at a time, each with its own in-game check | Both |
| SL-06 | The cited starter pack, plus guild sharing of profiles (opt-in) | Claude |

## Questions for Gary

1. How did you see the 3x fire: hit numbers, a tooltip line, or something else? And
   what was the mob called? This tells us where to look first.
2. UNIT_COMBAT, the target's own hit numbers, isn't the combat log. Is it OK to
   learn from it? Without it we only have the post-fight damage meter, which is
   slower and may not split damage by school.

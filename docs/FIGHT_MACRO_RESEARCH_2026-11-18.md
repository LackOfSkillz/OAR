# Fight macros for every class, spec, race and level: research and proposal (2026-11-18)

For Gary. This is a proposal to review, not shipped code. Nothing in the addon changed. Companion data file: `docs/fight_macro_catalog_draft.lua` (a draft, not in the TOC).

Everything below is **verified = false**. Spell names, learn levels and racials come from WoW Forever community guides (cited inline). Where a guide didn't cover something, I used the Classic Era value and marked it **CL**. Each item needs an in-game check before it ships.

---

## 1. Summary

- **Why "it only works for a couple of classes".** Today's builder (`Modules/HunterFight.lua` plus `Modules/ClassFight.lua`) has one fixed order per class. It ignores talents, race and PvP, and several orders don't match what Forever changed (section 3). The fix is a catalogue built from **layers**: class and spec, then level (what the spellbook knows), then race, then faction. Utility keys hold the actions that shouldn't sit in a spam key.
- **Ranged and melee keys for every class** (your addition). Every class, spec and mode gets a **ranged** key and a **melee** key. Classes that need more also get **heal**, **pet**, **react** (warrior) or **utility** (rogue). For some classes one of the two is really a pull, reach or escape key, and the tables say so (section 5).
- **It grows with level by itself.** Each slot lists the spells it may use, and the first one the character knows wins (the same rule the addon uses now). The catalogue writes a new **bracket** at every level where a key's text changes. Your hunter's ranged key, for example, changes at 1, 4, 6, 10, 18, 20, 25 and 44, and the melee key at 1, 4, 10, 12 and 16. Traps come in at 16 (Immolation) and 20 (Freezing).
- **Freezing Trap and Immolation Trap.** Immolation stays on the melee key (Strike). Freezing Trap gets its own **Trap** key: a plain press drops Freezing Trap, Shift drops Frost Trap, Ctrl drops Explosive Trap. Forever lets you set traps in combat, so you no longer need Feign Death first.
- **"Wrong macro for your build" detection** is designed in section 8. It reads talent points per tree, race, faction, level and known spells, picks the best catalogue entry, scores what's on your bar, and gives at most one quiet line per session.
- **Size of the draft:** 803 macro texts, all 255 characters or fewer (longest exactly 255). The generator counts every one and lists what it dropped to fit.

### What's covered and what isn't confirmed

| Area | Covered | Confidence / what needs checking |
|---|---|---|
| Hunter BM (your main) | every bracket 1-60, ranged + melee + pet, PvE + PvP, Trap/Stings/Feign/Intim/Burst/Break | spell levels from Warcraft Tavern Forever (Hunter's Mark level is CL); in-combat traps confirmed by 3 Forever guides; shared cooldowns (Aimed/Multi, Arcane/Summon Hawk) from wow.gg + Endgame Tools |
| Priest Undead (Shadow, Disc, Holy) | every bracket, ranged + melee + heal, PvE + PvP, Undead racial layer | Mind Flay, Vampiric Embrace, Silence and Shadowform conflict (trainer spell in one guide, talent in Data/Talents.lua). Undead racial **levels** are inferred |
| Mage, Warlock, Warrior, Rogue, Druid, Paladin, Shaman | 3 specs + levelling, ranged + melee (+ extra keys), PvE at 10/20/30/40/60, PvP at 30/60 | trainer levels from Warcraft Tavern Forever levelling guides; most deep talent spells (Mortal Strike, Bloodthirst, Shield Slam, Seal of Command, Holy Shock, Holy Shield, Insect Swarm) are CL |
| Race layer (10 races incl. both Skyborne) | every racial, where it goes (Burst / Break / Recover / none) | Forever racial list from Warcraft Tavern + Method + the pre-launch change notes; cooldowns not published |
| Faction layer | paladin (Alliance + Undead Horde), shaman (Horde + Dwarf + Windshaper Skyborne), Skyborne mage (Alliance only) | Warcraft Tavern combo table |
| PvP rotations | slot lists and macros for every spec | **weakest area**: no Forever PvP rotation guide was readable (Mobalytics/Icy Veins returned 403), so these follow Classic PvP practice adapted to Forever spells |
| Level 41-60 Forever talents | where Talents.lua or a guide names them | Forever beta capped at 30, and several guides still say "60 builds at launch" |

---

## 2. The biggest Forever differences found

1. **Torrant is Skyborne, not Orc, Troll or Undead.** `docs/PROBE_RESULTS.md` logs `UnitRace = Skyborne` for Torrant (Horde, so the **Windshaper Skyborne**). Windshaper racials are Walk on Air, Skysight, Wind Blessed (+2% haste) and Elemental Insight. None of them is a damage cooldown, so his Burst key is class-only (Bestial Wrath, Rapid Fire, trinkets). His Break key is just Shift: Feign Death. ([Warcraft Tavern racials](https://www.warcrafttavern.com/forever/guides/racial-abilities/), [pre-launch changes](https://www.warcrafttavern.com/forever/news/changes-to-racial-abilities-in-wow-forever-ahead-of-name-reservations/))
2. **Every race has 2 active and 2 passive racials, and many changed.** Examples: Orc Shatter Curse, Command (back) and Hardiness; Undead Touch of the Grave; Human Will to Survive (a free PvP trinket); Gnome Eureka!; Night Elf Elune's Light (+10% crit); Troll Rapid Regeneration; Dwarf Artisan's Precision. ([Method](https://www.method.gg/wow-forever/all-new-racial-abilities-in-world-of-warcraft-forever))
3. **Priest racial spells changed.** Fear Ward and Devouring Plague are trainer spells now, not racials. Undead priests get **Dark Sacrifice** (health into mana) and Touch of Weakness. Dwarves get Chastise and Desperate Prayer. Gnomes get Confounding Flash and Contingency Plan. Humans get Divine Grace and Feedback. Night Elf (Starshards, Elune's Grace) and Troll (Hex of Weakness, Shadowguard) are unchanged. ([Warcraft Tavern priest racials](https://www.warcrafttavern.com/forever/news/priest-racials-in-world-of-warcraft-forever-fear-ward-is-baseline/))
4. **New race and class pairs.** Undead **paladins** (the only Horde paladin), Dwarf **shamans** (the only Alliance shaman), Orc mage, Troll warlock, Gnome priest, Human hunter, and Skyborne druid, hunter, rogue and warrior (plus mage for Alliance, shaman for Horde). Skyborne cannot be a priest, paladin or warlock. ([Warcraft Tavern combos](https://www.warcrafttavern.com/forever/news/undead-paladins-other-race-class-combos-in-world-of-warcraft-forever/))
5. **Hunter:** Aimed Shot is a **trainer** spell at 20, and Summon Hawk is a BM talent at 25 that shares Arcane Shot's cooldown. Aimed Shot and Multi-Shot share a cooldown. Traps work in combat. Disengage is a threat drop, not a jump. Intimidation now does damage. ([wow.gg BM](https://wow.gg/guides/wow-forever-beast-mastery-hunter), [Warcraft Tavern hunter levelling](https://www.warcrafttavern.com/forever/guides/hunter-leveling/), [wowtbc.gg BM](https://wowtbc.gg/warcraftforever/class-guides/beast-mastery-hunter/))
6. **Priest:** Penance (30) for Discipline, Shadow Word: Death (32), Binding Heal (25), Prayer of Mending, and Shadowform reworked (crit and cost). DoTs update their damage while they tick. ([Warcraft Tavern priest levelling](https://www.warcrafttavern.com/forever/guides/priest-leveling/), [priest overview](https://www.warcrafttavern.com/forever/guides/priest/))
7. **Paladin: Judgement no longer uses up the Seal** (already in `FOREVER_CONSTRAINTS.md`). The current paladin macro re-casts the Seal after every Judgement, which wastes a global cooldown and mana each time. The catalogue casts the Seal once per fight and Judgement on cooldown. Seal of Fury (10) is the tank seal. Holy Strike comes at 6. ([Warcraft Tavern paladin levelling](https://www.warcrafttavern.com/forever/guides/paladin-leveling/))
8. **Warlock:** curses are split into **Banes** (damage over time) and Curses (utility), so one of each can sit on a target. Incinerate is the Destruction filler from 40, and Wrack is Affliction's at 47. ([Warcraft Tavern warlock levelling](https://www.warcrafttavern.com/forever/guides/warlock-leveling/))
9. **Mage:** Arcane Blast and Ice Lance (8 s cooldown) at 20, Arcane Wrath at 25, Fingers of Frost, Heating Up, and Frostfire Bolt at 40. ([Warcraft Tavern mage levelling](https://www.warcrafttavern.com/forever/guides/mage-leveling/))
10. **Druid: Primal Bite is a Feral talent at 40**, not a trainer spell. Nature's Grasp comes at 10, Revive at 12, Lacerate is new for Bear, Shifting Power comes at 40 (Cat energy), and Roots work indoors. The Warcraft Tavern table doesn't list **Tiger's Fury**, which the current druid macro uses (unconfirmed). ([Warcraft Tavern druid levelling](https://www.warcrafttavern.com/forever/guides/druid-leveling/))
11. **Shaman:** Call of the Elements (20) drops your saved set of four totems in one cast, so one "once per fight" line replaces the separate totem lines. Totem twisting is gone. Lava Burst is an Elemental talent at 30, Water Shield a Resto talent at 20, and Fire Nova a spell at 12. ([Warcraft Tavern shaman levelling](https://www.warcrafttavern.com/forever/guides/shaman-leveling/))
12. **Rogue:** Shank at 24 (an energy builder for every spec), Mutilate for Assassination at 40, and Ghostly Strike lets Subtlety use Ambush and Garrote in combat. Cheap Shot comes at 26 on Forever (Classic: 26). ([Warcraft Tavern rogue levelling](https://www.warcrafttavern.com/forever/guides/rogue-leveling/))
13. **Warrior:** Victory Rush at 20, Thunder Clap on a 6 s cooldown, rage normalised to weapon speed, and Whirlwind Weapon from a class quest at 30. ([Warcraft Tavern warrior levelling](https://www.warcrafttavern.com/forever/guides/warrior-leveling/))

### Problems found in the current builder (worth fixing even before the catalogue)
- **Channels get cut.** The warlock key ends in `/cast Drain Life`, so spamming it during the channel likely restarts it. The same would hit Mind Flay, Arcane Missiles and Evocation. The fix is already measured on Forever: `/stopmacro [channeling]` works (the tame macro uses it, `PROBE_RESULTS.md`). The catalogue puts it at the top of every key that can channel.
- **Paladin re-seals after every Judgement** (Forever change 7 above).
- **Druid** uses Primal Bite as if it were trained (it's a level 40 talent) and Tiger's Fury (not in the Forever table). Fail-soft holds because the builder only writes known spells, but the explain text is wrong.
- **Priest** has no Mind Flay, no Devouring Plague, no Penance, and no channel guard.

---

## 3. How the catalogue works (rules every macro follows)

These come from what was measured on your client (`FOREVER_CONSTRAINTS.md` C16b) and the hard rules:

- One spell attempt per press. A line that casts, or is refused for a real reason, ends the press. Only "Spell is not ready yet" (cooldown or global cooldown) moves on to the next line. A line whose `[conditions]` don't match is skipped and costs nothing.
- So every key follows the same order: targeting, channel guard, modifier lines (Shift/Ctrl/Alt), before-the-pull buffs (only while missing), opener (`[nocombat]`), **once per pull** (`/castsequence reset=combat/target X,null`), **once per fight** (`reset=combat`), **cooldowns**, then the always-usable **filler** last.
- **Reactive** spells (Overpower, Revenge, Execute, Riposte, Counterattack, Mongoose Bite, Victory Rush, Hammer of Wrath) are refused when not lit. That refusal ends the press, so they go on a second key or last in the line.
- A macro can't see buffs, range, mana or procs. Outrider rewrites it out of combat when a buff goes on or off (as today). Range is handled by the separate ranged and melee keys. Procs (Missile Barrage, Heating Up, Fingers of Frost) go on a modifier or the second key, where you press them when they light up.
- If a key goes over 255 characters, the highest `keep` number is dropped first (the same rule as `HunterFight M:Body`). The draft lists every dropped line.
- Each press is an ordinary macro press. Nothing fires on a timer or an event, and Outrider only writes the text (hard rule 1).

**Layer shape** (`docs/fight_macro_catalog_draft.lua`):

```
catalog[CLASS].learn[spell]  = { level, source, spec }   -- spec = talent tree tag
catalog[CLASS].trees         = { tree1, tree2, tree3 }   -- talent tab order (for detection)
catalog[CLASS].keys          = { ranged = "Fight", melee = "Strike", heal = ..., pet = ... }
catalog[CLASS].specs[spec][mode] = {
  brackets = { [key] = { { from = level, slots = { { line, spells, kind, keep, why } } } } },
  macros   = { [key] = { [level] = { text, chars, dropped? } } } }
catalog.races[race]          = { faction, classes, abilities = { {name, type, slot, why} }, priest = {...} }
catalog.utility[CLASS]       = { { id, name, text, chars, why, race? } }
```
`spec` is `levelling` (no talents yet) or a tree tag, and `mode` is `pve` or `pvp`. The printed macros show the in-fight state, so buff lines are left out because the buff is up. With a buff missing, the live builder adds its line and drops the highest `keep` to fit.

---

## 4. Hunter, Beast Mastery (Torrant): in full

**How BM fights (PvE).** The pet tanks and you shoot. Keep Hunter's Mark and Serpent Sting up, keep Auto Shot running, use Aimed Shot on cooldown from 20, keep two hawks out with Summon Hawk from 25 (it shares Arcane Shot's cooldown, so Arcane Shot is the spare-mana filler), and use Bestial Wrath when the pet can attack for the full 18 s. Save Rapid Fire for strong enemies. Shift swaps Multi-Shot in for packs, since it shares Aimed Shot's cooldown. Sources: [wow.gg BM](https://wow.gg/guides/wow-forever-beast-mastery-hunter), [wowtbc.gg BM](https://wowtbc.gg/warcraftforever/class-guides/beast-mastery-hunter/), [Warcraft Tavern hunter levelling](https://www.warcrafttavern.com/forever/guides/hunter-leveling/).

**How BM fights (PvP)** (Classic practice, Forever spells, unconfirmed). Same core, plus Concussive Shot on cooldown to keep them slowed. Intimidation stuns and now deals damage on Forever. Viper Sting goes on casters, Scorpid Sting on melee. Freezing Trap controls a second player, and Scatter Shot (Marksmanship) sets it up ([Mobalytics MM PvP, via search](https://mobalytics.gg/wow-forever/profile/feor/classes/marksmanship-hunter-pvp-guide)). Feign Death drops combat. On Forever it isn't needed to set traps, because traps can be set in combat.

**Level timeline (BM, from the catalogue).** 1 Auto Shot, Raptor Strike; 4 Serpent Sting, Monkey; 6 Arcane Shot, Hunter's Mark (CL); 8 Concussive (left out in PvE, as today); 10 pet + Hawk; 12 Wing Clip, Mend Pet; 16 **Immolation Trap**, Mongoose Bite; 18 Multi-Shot; 20 **Aimed Shot, Freezing Trap**; 22 Scorpid Sting (CL); 25 **Summon Hawk** (talent); 26 Rapid Fire; 28 Frost Trap; 30 Feign Death; 34 Explosive Trap; 35 Intimidation (talent); 36 Viper Sting (CL); 44 **Bestial Wrath** (talent).

### Ranged key "Fight" (PvE), growing with level
Level 10 (193 characters):
```
#showtooltip
/targetenemy [noharm][dead]
/petattack [pet,harm]
/castsequence reset=combat/target Hunter's Mark,!Auto Shot,Serpent Sting,null
/cast Arcane Shot
/cast [combat] !Aspect of the Hawk
```
Level 25 (252 characters):
```
#showtooltip
/targetenemy [noharm][dead]
/petattack [pet,harm]
/castsequence reset=combat/target Hunter's Mark,!Auto Shot,Serpent Sting,null
/cast [mod:shift] Multi-Shot; Aimed Shot
/cast Summon Hawk
/cast Arcane Shot
/cast [combat] !Aspect of the Hawk
```
Level 44 to 60 (237 characters; the "back to Hawk" line is dropped to make room for Bestial Wrath):
```
#showtooltip
/targetenemy [noharm][dead]
/petattack [pet,harm]
/castsequence reset=combat/target Hunter's Mark,!Auto Shot,Serpent Sting,null
/cast Bestial Wrath
/cast [mod:shift] Multi-Shot; Aimed Shot
/cast Summon Hawk
/cast Arcane Shot
```
What each line does:
- `/targetenemy [noharm][dead]`: picks the nearest enemy when you have none or yours died.
- `/petattack [pet,harm]`: sends the pet at your target every press, so it grabs aggro.
- `/castsequence ... Hunter's Mark,!Auto Shot,Serpent Sting,null`: one press each for Mark, start Auto Shot and Serpent Sting. Then the line goes quiet until combat ends or you change target. This is the measured fix for Auto Shot restarting and Mark being skipped.
- `/cast Bestial Wrath`: pet burst. It falls through while it cools down.
- `/cast [mod:shift] Multi-Shot; Aimed Shot`: Aimed Shot on cooldown; hold Shift on a pack for Multi-Shot (they share the cooldown).
- `/cast Summon Hawk`: keeps the hawks out. It falls through while it, and therefore Arcane Shot, cools down.
- `/cast Arcane Shot`: only reached when Summon Hawk can't be cast for another reason (no talent yet, or you already have two out). Before 25 it's the main instant.
- `/cast [combat] !Aspect of the Hawk`: after the melee key switched you to Monkey, the first press with nothing else ready puts Hawk back.
- Before the pull, while Hawk is off, Outrider adds `/cast [nocombat] !Aspect of the Hawk` (as today).

### Melee key "Strike" (PvE): level 16 onwards (240 characters)
```
#showtooltip
/targetenemy [noharm][dead]
/startattack
/petattack [pet,harm]
/castsequence reset=combat !Aspect of the Monkey,null
/castsequence reset=combat/target Wing Clip,null
/cast Raptor Strike
/cast Immolation Trap
/cast Mongoose Bite
```
- Monkey once per fight, Wing Clip once per target (so you can step back and shoot).
- Raptor Strike on cooldown (off the global cooldown on Forever, per the pack note).
- **Immolation Trap** at your feet while the mob is on you, every time it's ready. Traps work in combat on Forever. This is your Immolation Trap.
- Mongoose Bite last, because it only works after a dodge and a refusal ends the press.

### Pet key "Pet"
`/cast [@pet,dead] Revive Pet; [nopet] Call Pet; Mend Pet` (69 characters). On Forever the Call spell takes the pet's name, so the live builder uses `M.CallPetName()`.

### Trap key "Trap" (new; this is where Freezing Trap lives)
```
#showtooltip
/cast [mod:shift] Frost Trap; [mod:ctrl] Explosive Trap; Freezing Trap
```
83 characters. A plain press drops **Freezing Trap** at your feet. Use it when a second mob (an add) joins: it runs at you, steps in and freezes, and you finish the first mob, then the frozen one. Don't hit the frozen mob with Multi-Shot, and don't let Immolation Trap or the pet touch it, because damage breaks the freeze. Shift drops Frost Trap (a slow, for kiting or when the pet loses aggro, as the Warcraft Tavern guide says). Ctrl drops Explosive Trap on packs (34). **Needs an in-game check:** on Classic, fire traps (Immolation, Explosive) share one cooldown and frost traps (Freezing, Frost) share another. If Forever keeps that, the Immolation Trap on Strike never blocks the Freezing Trap on Trap.
PvP version: `/cast [mod:shift] Frost Trap; [mod:ctrl] Scatter Shot; Freezing Trap`. Scatter Shot (Marksmanship) sets up the trap; it shares diminishing returns with Freezing Trap, per Mobalytics.

### Other hunter utility keys
- **Stings** (PvP): `/cast [mod:shift] Viper Sting; [mod:ctrl] Scorpid Sting; Serpent Sting`. This keeps the sting choice off the Fight key, which was over 255 characters with it in.
- **Feign** (30): `/petfollow` then `/cast Feign Death`. Drops aggro, with the pet coming back.
- **Intim** (BM 35): `/cast [@pet,nodead] Intimidation` plus `/petattack`.
- **Burst**: `/cast Bestial Wrath`, `/cast Rapid Fire`, `/cast <racial>`, `/use 13`, `/use 14`. One press per cooldown, and each line falls through while it cools down. Racial by race: Orc Blood Fury, Troll Berserking, Night Elf Elune's Light. Windshaper Skyborne (Torrant), Human, Dwarf and Tauren have no damage racial.
- **Break**: racial escape (Orc Shatter Curse, Human Will to Survive, Dwarf Stoneform, Tauren War Stomp), plus Shift: Feign Death. For Torrant it's just Shift: Feign Death.

### BM PvP ranged key (level 44+, 241 characters)
```
#showtooltip
/targetenemy [noharm][dead]
/petattack [pet,harm]
/castsequence reset=combat/target Hunter's Mark,!Auto Shot,Serpent Sting,null
/cast Concussive Shot
/cast Bestial Wrath
/cast [mod:shift] Multi-Shot; Aimed Shot
/cast Summon Hawk
```
Intimidation moves to the Intim key, and Arcane Shot is dropped to fit (Summon Hawk shares its cooldown anyway).

**Marksmanship and Survival** follow the same frame. Marksmanship adds Sniper Shot (a Forever talent somewhere in levels 20-29; its priority is unconfirmed), Trueshot Aura before the pull, and the option of Lone Wolf with no pet. Survival plays melee-first on Forever: Strike gets Strider Kick (talent at 30), and Counterattack comes last (it's dropped when the key is full).

---

## 5. Priest, Undead (Shadow, Discipline and Holy levelling): in full

**How each spec fights (PvE).**
- *Levelling (1-20, every spec):* Smite until 4, then Shadow Word: Pain once and Smite. From 5, the wand once you carry one. From 10, Mind Blast opens and is used on cooldown. Spirit Tap mana, Lesser Heal when low. ([Warcraft Tavern priest levelling](https://www.warcrafttavern.com/forever/guides/priest-leveling/))
- *Shadow (20+):* Mind Blast to pull, then Vampiric Embrace (25) and Shadow Word: Pain once per target, Devouring Plague on cooldown (a trainer spell at 20 on Forever), Mind Blast on cooldown, and Mind Flay as the filler. Shadowform before the pull from 40. Shadow "comes online about 28".
- *Discipline (30+):* Power Word: Shield yourself, Smite or Mind Blast to pull, Shadow Word: Pain, **Penance** on cooldown, then the wand.
- *Holy:* the same without Penance. Holy Fire pulls. The guides don't recommend levelling as Holy (slow kills).

**PvP** (Classic practice, unconfirmed): Shadow keeps DoTs and Vampiric Embrace up, uses Mind Blast and Shadow Word: Death on cooldown, Psychic Scream on Shift and Silence on Ctrl. Disc and Holy shield themselves and heal from the Heal key. Undead Will of the Forsaken (the Break key) clears fear, charm and sleep.

**Undead race layer.** Touch of Weakness is a before-the-pull buff on the Fight key (only while missing; level 10 by the Classic analogue). Dark Sacrifice and Cannibalize go on a **Mana** key: `/cast [nocombat] Cannibalize` then `/cast Dark Sacrifice`. Cannibalize is out of combat on a humanoid or undead corpse; in a fight, Dark Sacrifice turns health into mana. Will of the Forsaken goes on **Break**. Touch of the Grave is passive (a 30% proc for casters). The level 10/20 timing of the Undead priest racials follows the guide's "level 10 racial spells / level 20 racial spells" note and is **inferred**.

### Ranged key "Fight", Shadow, growing with level
Level 10 (155 characters):
```
#showtooltip
/targetenemy [noharm][dead]
/cast [nocombat] Mind Blast
/castsequence reset=combat/target Shadow Word: Pain,null
/cast Mind Blast
/cast !Shoot
```
Level 25 to 60 (247 characters):
```
#showtooltip
/targetenemy [noharm][dead]
/stopmacro [channeling]
/cast [mod:shift] !Shoot
/cast [nocombat] Mind Blast
/castsequence reset=combat/target Vampiric Embrace,Shadow Word: Pain,null
/cast Devouring Plague
/cast Mind Blast
/cast Mind Flay
```
- `/stopmacro [channeling]`: a press during Mind Flay does nothing instead of cutting the channel. This is measured on Forever (the tame macro).
- `/cast [mod:shift] !Shoot`: Shift uses the wand to save mana (Spirit Tap levelling). The `!` keeps it from toggling off.
- `/cast [nocombat] Mind Blast`: the pull. Mind Blast before the DoTs, from full range.
- The castsequence puts Vampiric Embrace, then Shadow Word: Pain, once per target.
- Devouring Plague, then Mind Blast, on cooldown. Mind Flay is the filler (before 20, the wand, or Smite with no wand).
- Before the pull, while missing, Outrider adds Power Word: Fortitude, Inner Fire, **Touch of Weakness (Undead)** and Shadowform (40+).

### Ranged key, Discipline (30+, 253 characters)
```
#showtooltip
/targetenemy [noharm][dead]
/castsequence [@player] reset=combat Power Word: Shield,null
/cast [nocombat] Mind Blast
/castsequence reset=combat/target Shadow Word: Pain,null
/cast Penance
/cast Devouring Plague
/cast Mind Blast
/cast !Shoot
```
### Ranged key, Holy (20+, 193 characters)
```
#showtooltip
/targetenemy [noharm][dead]
/cast [nocombat] Holy Fire
/castsequence reset=combat/target Shadow Word: Pain,null
/cast Devouring Plague
/cast Mind Blast
/cast Holy Fire
/cast !Shoot
```
### Melee key "Strike": a mob is on you (really a defensive key)
Level 32+ Shadow (213 characters):
```
#showtooltip
/targetenemy [noharm][dead]
/stopmacro [channeling]
/castsequence [@player] reset=combat Power Word: Shield,null
/cast [mod:shift] Psychic Scream
/cast Shadow Word: Death
/cast Mind Blast
/cast !Shoot
```
Shield first so hits don't push back your casts. Fear goes on Shift in PvE (feared mobs run into more mobs) and on plain press in PvP. The wand fires at melee range. Discipline puts Penance in place of Shadow Word: Death.

### Heal key "Heal"
```
#showtooltip
/cast [mod:shift,@mouseover,help,nodead][mod:shift,@player] Power Word: Shield; [mod:ctrl,@mouseover,help,nodead][mod:ctrl,@player] Renew; [@mouseover,help,nodead][@target,help,nodead][@player] Flash Heal
```
217 characters. It heals who you point at, your friendly target, or you. Shift shields and Ctrl casts Renew. The plain heal grows Lesser Heal (1), then Heal (16), then Flash Heal (20). Holy uses Greater Heal (40) or Heal instead of Flash Heal. **Check:** on Classic, Holy spells can't be cast in Shadowform. If Forever's reworked form still blocks them, the Heal key should cancel the form first (`/cancelform`), or the Heal explain text should say so.

### Priest utility
**Burst** (Undead): Power Infusion (Disc 40), Inner Focus (20), `/use 13`, `/use 14`. **Break**: `/cast [nomod] Will of the Forsaken` and `/cast [mod:shift] Fade`. **Recover**: `/cast [nocombat] Cannibalize`. **Mana**: as above.

### The Mind Flay conflict
Warcraft Tavern lists Mind Flay (20), Vampiric Embrace (25), Silence (30) and Shadowform (40) at those levels. `Data/Talents.lua` (wowhandbook) has them as talents (24, 27, 32, 42). The catalogue tags them Shadow-only. In game it doesn't matter: the builder writes only what the spellbook has. If they turn out to be trainer spells, Holy and Disc pick up Mind Flay too, and the detection in section 8 tells them apart through Penance and the talent points instead.

---

## 6. The other seven classes

For each spec: how it fights, what changes with level, and the level-60 PvE ranged and melee keys. Every bracket, the PvP keys and the levels 10/20/30/40 are in the draft file. Targeting (`/targetenemy [noharm][dead]`) heads every key and is left out of the one-line versions below. ` | ` separates the lines.

### Mage
Trainer: Fireball 1, Frostbolt 4, Fire Blast 6, Arcane Missiles 8, Frost Nova 10, Arcane Explosion 14, Evocation 20, Scorch 22, Counterspell 24, Ice Armor 30, Mage Armor 34, Frostfire Bolt 40. Talents: Arcane Blast and Ice Lance at 20, Pyroblast 20, Arcane Wrath 25, Blast Wave 30. ([Warcraft Tavern](https://www.warcrafttavern.com/forever/guides/mage-leveling/))
- **Arcane:** Frostbolt rank 1 to fish for Missile Barrage until 20, then Arcane Blast stacks and Arcane Wrath at 3-4 stacks. Arcane Missiles is for when Missile Barrage lights up, so it goes on Shift on the melee key. Ranged: `/stopmacro [channeling] | /cast Arcane Wrath | /cast Arcane Blast`. Melee: `/cast [mod:shift] Arcane Missiles | Frost Nova | Cone of Cold | Fire Blast | Arcane Explosion`.
- **Fire:** Fireball filler, Fire Blast on cooldown, Scorch stacks for long fights, Pyroblast at 3 Heating Up stacks (Shift on the melee key). Ranged: `Fire Blast | Fireball`. Melee: `[mod:shift] Pyroblast | Frost Nova | Blast Wave | Cone of Cold | Fire Blast | Arcane Explosion`.
- **Frost:** Frostbolt main, Ice Lance on frozen targets or Fingers of Frost, Frost Nova, Cone of Cold. Ranged: `Frostbolt`. Melee: `Frost Nova | Ice Lance | Cone of Cold | Fire Blast | Arcane Explosion`.
- **PvP:** `/cast [mod:shift] Polymorph; [mod:ctrl] Counterspell` on the ranged key. The melee key is the "it reached me" key (Nova, then blink away yourself).
- The melee key is a close-range and escape key for every spec.

### Warrior (ranged "Pull", melee "Fight", react "Strike")
Trainer: Battle Shout/Heroic Strike 1, Rend/Charge 4, Thunder Clap 6, Hamstring 8, Overpower 12, Revenge 14, Victory Rush/Cleave/Slam 20, Intimidating Shout 22, Execute 24, Intercept/Berserker Stance 30, Whirlwind 36, Pummel 38. Mortal Strike, Bloodthirst and Shield Slam are CL (41st point, level 40). ([Warcraft Tavern](https://www.warcrafttavern.com/forever/guides/warrior-leveling/))
- **Arms:** Battle Shout, Charge, Overpower when lit, Rend, Mortal Strike, Heroic Strike or Slam. Melee: `/startattack | [nocombat] Charge | castsequence(combat) Battle Shout | castsequence Rend | Mortal Strike | Heroic Strike` (206 characters).
- **Fury:** the same with Bloodthirst and Whirlwind (Berserker Stance). **Prot:** Demoralizing Shout and Rend once, Shield Slam, Thunder Clap on cooldown, Heroic Strike. Revenge goes on react.
- **Ranged (pull):** `[nocombat] Charge | [combat] Intercept | Shoot Bow` (the live builder picks Shoot Bow, Gun or Crossbow or Throw from the ranged slot; Skyborne warriors start with Bows and Thrown, per PROBE_RESULTS). This is a pull key, not a rotation.
- **React:** `Victory Rush | Overpower | Revenge | Execute | Thunder Clap | Cleave`. PvP adds `[mod:shift] Intimidating Shout; [mod:ctrl] Pummel/Shield Bash`. PvP melee adds Hamstring once per target.
- **Limitation:** a macro can't stance-dance without spending a press. Each spec's keys assume its main stance, and the `why` text names the stance a spell needs.

### Rogue (ranged "Pull", melee "Fight", utility "Strike")
Trainer: Sinister Strike/Eviscerate/Stealth 1, Backstab 4, Gouge 6, Evasion 8, Slice and Dice 10, Kick 12, Garrote 14, Ambush 18, Rupture 20, Vanish 22, **Shank 24**, Cheap Shot 26, Kidney Shot 30, Blind 34. Talents: Riposte 20, Cold Blood and Ghostly Strike 25, Blade Flurry and Hemorrhage 30, Mutilate and Adrenaline Rush 40. ([Warcraft Tavern](https://www.warcrafttavern.com/forever/guides/rogue-leveling/))
- **Assassination:** Ambush from Stealth, Mutilate builders, Slice and Dice, Shank, Eviscerate. Melee: `[stealth] Ambush | /startattack [nostealth] | [nostealth] Shank | castsequence Mutilate,Mutilate,Slice and Dice,Mutilate,Mutilate,Eviscerate`.
- **Combat:** Cheap Shot, Sinister Strike, Slice and Dice, Eviscerate. Blade Flurry and Adrenaline Rush go on the **Burst** key.
- **Subtlety:** Ambush, then Hemorrhage, Ghostly Strike on cooldown.
- **PvP:** Cheap Shot opener, a shorter loop (3 builders, then Eviscerate). The utility key gets `[mod:shift] Gouge; [mod:ctrl] Blind; [mod:alt] Kidney Shot`, then Kick and Evasion.
- **Ranged** is a pull key only (`/cast [nostealth] Shoot Bow` or Throw). **Utility:** Stealth out of combat, Kick, Riposte, Evasion.

### Warlock (ranged "Fight", melee "Strike" = escape key)
Trainer: Shadow Bolt/Immolate 1, Corruption 4, Life Tap 6, Fear and **Bane of Agony** 8, Drain Life 14, Searing Pain 18, Demon Armor/Curse of the Elements 20, Curse of Tongues 26, Howl of Terror 40, Death Coil 42. Talents: Shadowburn 20, Conflagrate 25, Siphon Life 30 (37 in the build), Incinerate 40, Wrack 47. ([Warcraft Tavern](https://www.warcrafttavern.com/forever/guides/warlock-leveling/))
- **Affliction:** Bane, Corruption, Immolate, Siphon Life once each, then the wand until 30, Drain Life after. Ranged at 60: `/stopmacro [channeling] | /petattack [pet,harm] | castsequence Bane of Agony,Corruption,Immolate,Siphon Life,null | Wrack | Drain Life`.
- **Demonology:** the demon in, Searing Pain to brand, then the DoTs and Drain Life. **Destruction:** Immolate once, Conflagrate, Shadow Bolt filler (Incinerate from 40). Shadowburn goes on the melee key.
- **Melee (escape):** `[mod:shift] Fear | [mod:ctrl] Life Tap | Death Coil | Howl of Terror | Shadowburn | !Shoot`. **PvP:** Curse of Tongues joins the sequence, plus `[mod:shift] Howl of Terror; [mod:ctrl] Death Coil`.

### Druid (ranged "Fight" = caster, melee "Strike" = forms, heal "Heal")
Trainer: Wrath/Healing Touch 1, Moonfire/Rejuvenation 4, Thorns 6, Roots 8, Bear Form/Maul/Regrowth/Nature's Grasp 10, Revive 12, Bash 14, Swipe 16, Faerie Fire 18, Cat Form/Claw/Rip/Shred/Starfire 20, Rake/Ferocious Bite 24, Shifting Power 40. Talents: Primal Bite 40 (Feral), Swiftmend (Resto, 25+), Insect Swarm (CL). ([Warcraft Tavern](https://www.warcrafttavern.com/forever/guides/druid-leveling/))
- **Balance:** Wrath pull, Moonfire, Insect Swarm, Wrath. From 30, two Starfire then one Wrath. Ranged: `castsequence [noform] Moonfire,Insect Swarm,null | castsequence [noform] Starfire,Starfire,Wrath | [noform] Wrath`.
- **Feral:** Bear from 10 (Faerie Fire, Demoralizing Roar, Lacerate, Primal Bite, Maul or Swipe), Cat from 20 (Rake, Claws, Rip or Bite at 4-5 points). Melee: `/startattack [form:1/3] | [noform] Cat Form | [form:1] Primal Bite | [form:1] Maul | castsequence [form:3] Rake,Claw,Claw,Claw,Rip`. Before Bear Form at 10 the melee key is empty.
- **Resto:** Wrath and Moonfire damage until 25, then heals. Heal: `[form:1] Swipe; [noform,mod:shift,...] Rejuvenation; [noform,...] Regrowth` and Ctrl: Swiftmend.
- Form numbers: the printed macros use 1 = Bear and 3 = Cat. The live builder reads them with `GetShapeshiftFormInfo` (as today). Moonkin Form isn't in the macros yet, because the `[noform]` caster lines would need `[noform][form:N]`.

### Paladin (ranged "Reach", melee "Fight", heal "Heal")
Trainer: Seal of Righteousness/Holy Light 1, Judgement/Blessing of Might 4, **Holy Strike 6**, Hammer of Justice 8, **Seal of Fury 10**, Retribution Aura/Righteous Fury 16, Consecration/Flash of Light/Exorcism 20, Divine Shield 32, Hammer of Wrath 44. Talents: Seal of Command, Holy Shock and Holy Shield (CL levels). The guide doesn't mention Crusader Strike. ([Warcraft Tavern](https://www.warcrafttavern.com/forever/guides/paladin-leveling/))
- **Retribution:** Seal of Command with a two-hander from 20 (Righteousness below that), Judgement and Holy Strike on cooldown. Melee: `/startattack | castsequence(combat) Seal of Command,null | Judgement | Holy Strike | Consecration`.
- **Protection:** Seal of Fury, Righteous Fury, Judgement, Consecration, Holy Shield, Holy Strike. **Holy (Shockadin):** Holy Shock opens, then the same.
- **Ranged (reach):** Seal once, Holy Shock, Judgement, Hammer of Wrath last. This is a reach key, not a rotation.
- **PvP:** `[mod:shift] Hammer of Justice`. **Faction:** every Alliance paladin race, and on the Horde only Undead (with its own start zone).

### Shaman (ranged "Fight" = caster, melee "Strike", heal "Heal")
Trainer: Lightning Bolt/Rockbiter 1, Earth Shock 4, Lightning Shield 8, Flame Shock/Searing Totem/Flametongue 10, Fire Nova/Purge 12, Frost Shock/**Call of the Elements**/Lesser Healing Wave 20, Windfury Weapon 30, Chain Lightning 32. Talents: Water Shield 20 (Resto), Stormstrike 25 (Enhancement), Lava Burst 30 (Elemental). ([Warcraft Tavern](https://www.warcrafttavern.com/forever/guides/shaman-leveling/))
- **Elemental:** Lava Burst pull, Flame Shock, Lava Burst on cooldown, Lightning Bolt. Ranged: `castsequence Flame Shock,null | Lava Burst | [mod:alt] Chain Lightning | Earth Shock | Lightning Bolt`.
- **Enhancement:** imbue (Windfury from 30) and Lightning Shield, Searing Totem or Call of the Elements once, Flame Shock, Stormstrike, Earth Shock. Melee: `/startattack | [nocombat] Lightning Bolt | castsequence(combat) Call of the Elements,null | castsequence Flame Shock,null | Stormstrike | Earth Shock`.
- **Resto:** Water Shield, then the Heal key (`Healing Wave`, Shift: Lesser Healing Wave).
- **PvP:** `[mod:shift] Earth Shock; [mod:ctrl] Purge`, with Frost Shock in place of Earth Shock. **Faction:** Horde Orc, Troll, Tauren and Windshaper Skyborne; Alliance Dwarf only (trainers in Coldridge, Kharanos and Ironforge).

---

## 7. Race and faction layers

| Race (faction) | Active racials | Where they go | Passives |
|---|---|---|---|
| Human (A) | Will to Survive (removes stuns), Perception | Break; utility | Ruthless +1% crit, Human Spirit +10% Spirit |
| Dwarf (A) | Stoneform, Find Treasure | Break | Artisan's Precision +1% hit, Big Game Hunter |
| Night Elf (A) | Elune's Light (+10% crit 15 s), Shadowmeld | **Burst**; utility | Quickness, Wisp Spirit |
| Gnome (A) | Escape Artist, Eureka! (8 s, -10% cost, +10% hit) | Break; **Burst** | Expansive Mind, Engineering Specialization |
| High Order Skyborne (A) | Walk on Air, Read Ley Line | none (movement); **Recover** | Wind Blessed +2% haste, Elemental Insight |
| Orc (H) | Blood Fury (+10% attack and spell power 15 s), Shatter Curse | **Burst**; Break | Command +5% pet damage, Hardiness |
| Troll (H) | Berserking (+10% speed 15 s), Rapid Regeneration | **Burst**; **Recover** | Beast Slaying, Regeneration |
| Undead (H) | Will of the Forsaken, Cannibalize | Break; **Recover** / Mana | Underwater Breathing, Touch of the Grave |
| Tauren (H) | War Stomp (2 s stun, 5 targets), Cultivation | Break (plain press) | Plainsrunning, Endurance +5% health |
| Windshaper Skyborne (H) | Walk on Air, Skysight (+15% run 15 s) | none (movement) | Wind Blessed, Elemental Insight |

Sources: [Warcraft Tavern racials](https://www.warcrafttavern.com/forever/guides/racial-abilities/), [Method](https://www.method.gg/wow-forever/all-new-racial-abilities-in-world-of-warcraft-forever), [pre-launch changes](https://www.warcrafttavern.com/forever/news/changes-to-racial-abilities-in-wow-forever-ahead-of-name-reservations/). No source gives cooldowns or global cooldown behaviour, so those need checking.

**Why racials stay out of the spam keys.** Burst racials are 15 s windows that you want lined up with Bestial Wrath, Rapid Fire or trinkets. In a spam key they would fire on the first press of every trash pull. Break racials answer a specific crowd-control effect, so they're reactive. They go on the **Burst** key (with the class cooldowns and trinkets; one press each), the **Break** key (racial first, Shift for the class panic button), and the **Recover** key (out of combat only). The one exception is the priest racial buffs and DoTs (Touch of Weakness, Shadowguard, Starshards), which sit in the Fight key like any other buff or once-per-target DoT.

**Priest racial spells** (Forever): Undead Touch of Weakness and Dark Sacrifice; Troll Hex of Weakness and Shadowguard; Night Elf Starshards and Elune's Grace; Human Feedback and Divine Grace; Dwarf Desperate Prayer and Chastise; Gnome Confounding Flash and Contingency Plan. Levels for the new ones aren't published.

**Faction layer.** It only matters for which classes exist (paladin, shaman and Skyborne mage, above) and the race list. No faction-only spell changes the rotations. Read Ley Line (Alliance Skyborne) and Skysight (Horde Skyborne) are the only racials that differ by faction for one race.

---

## 8. "You're using a macro that's not the best fit for your build": design

### Working out the character's best entry
1. **Class**: `ns.PlayerClass()`. **Race**: `UnitRace("player")` (third return = race file, e.g. `Skyborne`, `Scourge` for Undead). **Faction**: `UnitFactionGroup("player")`. Skyborne plus the faction picks High Order or Windshaper. **Level**: `UnitLevel`.
2. **Spec**: `ns.Talents:Read()` already returns `tabs[i].spent`. Pick the tree with the most points. With no points spent (or under 10), use `levelling`. If two trees are within 5 points of each other, say "hybrid" and score against both, picking the better fit. On the Traits API the tabs are named "tree <id>", so map them by **tab index** to `catalog[CLASS].trees`. A spec-marker check confirms it (Summon Hawk or Bestial Wrath known means BM; Penance means Disc; Shadowform or Mind Flay means Shadow, and so on). Dual Talent Specialization at 40 is just "the active config", which `C_ClassTalents.GetActiveConfigID` already gives.
3. **Mode**: PvE by default. PvP while in a battleground, arena or war mode (`C_PvP.IsWarModeDesired`, `IsInInstance` type pvp/arena, both via `ns.Compat`, and probe them first), or when the player picked PvP in settings. The suggestion never switches modes on its own; it just says which mode it compared against.
4. **Entry** = `catalog[class].specs[spec][mode]`, the bracket for this level with the spells resolved against the spellbook. That is exactly the text Outrider would write.

### Comparing with what the player is using
- **Outrider-written macros** carry an id in `MacroLibrary:Settings().installed[name].id`. Today that's `hunter-fight`. The proposal is `<class>-<spec>-<mode>-<key>`, e.g. `hunter-bm-pve-ranged`. If the installed id's spec or mode doesn't match the detected one (say you respecced to Marksmanship and your Fight macro is still the BM one), that's a mismatch. With `auto = true` (the current default), Outrider just rewrites it out of combat. With auto off, it suggests.
- **Hand-written macros on the bar**: `GetActionInfo(slot)` (present, `PROBE_RESULTS`) shows which action slots hold macros, and `GetMacroInfo(index)` gives the body. A macro counts as a "fight macro" when at least 2 of its `/cast` and `/castsequence` spell names are damage spells of this class in the catalogue. To score it:
  - Each catalogue slot is weighted by kind: once/opener 3, cooldown 3, filler 2, reactive 1 (when it's on this key), utility and buff 0.
  - The score is (weight of the catalogue slots whose spell, or an alternative, appears in the player's macro) divided by (total weight), over **known** spells only.
  - Also flag **known anti-patterns**: `/cast` of a channel with no `/stopmacro [channeling]`; a filler line above a cooldown line (the cooldown is never reached); `/cast !Auto Shot` sent every press (measured restart); a re-cast Seal after Judgement on a paladin; a spell from another tree that this build doesn't have (it gets refused every press); `reset=N` timers alone (measured not to re-arm).
  - Suggest only when the score is under 0.6, **and** the missing slots include a high-priority one (a cooldown or once-per-pull spell the character knows), **or** an anti-pattern is present.
- Never read secret values and never use the combat log. This is a text comparison of macro bodies and the spellbook, out of combat only (hard rule 4).

### When and how it speaks (hard rule 6)
- It checks out of combat, at most once per login session per macro, and never during or within 10 s of a fight. It's triggered by `PLAYER_LOGIN`, `PLAYER_TALENT_UPDATE` / `TRAIT_CONFIG_UPDATED` (a respec), `LEARNED_SPELL_IN_TAB`, and `UPDATE_MACROS`.
- **One chat line per session** at most, then silence. Every finding also goes to the Macros tab (a yellow "better fit available" badge on the macro) and the log (so Claude can read it).
- Wording (chat, one line, with Outrider's prefix):
  > Outrider: your "Fight" macro looks set up for a different build. For Beast Mastery at level 34 it's missing Aimed Shot and Summon Hawk. Open /ride macros to compare, or ignore this.
- An anti-pattern variant:
  > Outrider: your "Shadow" macro can cut Mind Flay short when you press it again. /ride macros has a version that waits for the channel.
- The Macros tab shows the two texts side by side, the missing spells, and the anti-patterns found. There are three buttons: **Use Outrider's** (writes it, out of combat, on Gary's click), **Keep mine** (mutes this macro until it changes), and **Not now**.
- Settings: `suggest = true`; a "mute for this character" option; debug mode lifts the once-per-session cap so it can be tested.

### Specs for when this is built
`tests/spec/fightcatalog_spec.lua`: every catalogue macro is 255 characters or fewer, and every spell name in a slot exists in `learn`. The spec choice comes from point totals (BM 21/5/0 gives bm; 0/0/0 gives levelling). A copy of the catalogue BM macro scores 1.0 and the levelling macro scores under 0.6 at 30. A Drain Life macro without the guard flags the channel anti-pattern. The line is said once per session (a second trigger stays quiet).

---

## 9. In-game checks needed (batch these when the catalogue is built)

Self-collecting, as Gary's rule asks: the fight log the addon already writes (UNIT_SPELLCAST_*, UI_ERROR_MESSAGE) answers most of these without anything to type.
1. Hunter: Freezing Trap and Immolation Trap don't share a cooldown (fight log: Immolation cast, then Freezing within 15 s). Freezing Trap works in combat. Summon Hawk and Arcane Shot share a cooldown. Aimed Shot cast from the spam key doesn't clip Auto Shot badly.
2. Priest: `/stopmacro [channeling]` stops a Mind Flay re-press (fight log: one Mind Flay channel, not restarts). Whether Mind Flay, Vampiric Embrace and Shadowform show up in the trainer list or the talent tree. Undead Touch of Weakness and Dark Sacrifice levels. Whether Heal can be cast in Shadowform.
3. Druid form indexes with Cat, Bear and Aquatic learned. Whether Tiger's Fury exists.
4. Racial cooldowns and whether they're on the global cooldown (Blood Fury, Berserking, Elune's Light, Eureka!), from a fight log on an alt.
5. Off-GCD spells (Bestial Wrath, Raptor Strike): does a cast end the press, or does the press carry on? If it carries on, Burst could be one press.

---

## 10. Sources

- Warcraft Tavern (Forever): [racial abilities](https://www.warcrafttavern.com/forever/guides/racial-abilities/), [pre-launch racial changes](https://www.warcrafttavern.com/forever/news/changes-to-racial-abilities-in-wow-forever-ahead-of-name-reservations/), [priest racials](https://www.warcrafttavern.com/forever/news/priest-racials-in-world-of-warcraft-forever-fear-ward-is-baseline/), [race/class combos](https://www.warcrafttavern.com/forever/news/undead-paladins-other-race-class-combos-in-world-of-warcraft-forever/), levelling guides for [hunter](https://www.warcrafttavern.com/forever/guides/hunter-leveling/), [priest](https://www.warcrafttavern.com/forever/guides/priest-leveling/), [mage](https://www.warcrafttavern.com/forever/guides/mage-leveling/), [warrior](https://www.warcrafttavern.com/forever/guides/warrior-leveling/), [rogue](https://www.warcrafttavern.com/forever/guides/rogue-leveling/), [warlock](https://www.warcrafttavern.com/forever/guides/warlock-leveling/), [druid](https://www.warcrafttavern.com/forever/guides/druid-leveling/), [paladin](https://www.warcrafttavern.com/forever/guides/paladin-leveling/), [shaman](https://www.warcrafttavern.com/forever/guides/shaman-leveling/); class overviews for [hunter](https://warcrafttavern.com/forever/guides/hunter/) and [priest](https://www.warcrafttavern.com/forever/guides/priest/).
- Method: [all new racial abilities](https://www.method.gg/wow-forever/all-new-racial-abilities-in-world-of-warcraft-forever).
- wow.gg: [Beast Mastery hunter (Forever)](https://wow.gg/guides/wow-forever-beast-mastery-hunter).
- wowtbc.gg: [BM hunter PvE (Forever)](https://wowtbc.gg/warcraftforever/class-guides/beast-mastery-hunter/).
- Mobalytics: Forever hunter PvP guides (search snippets only; the pages returned 403): [MM PvP](https://mobalytics.gg/wow-forever/profile/feor/classes/marksmanship-hunter-pvp-guide), [BM PvP](https://mobalytics.gg/wow-forever/profile/feor/classes/beast-mastery-hunter-pvp-guide).
- In the repo: `Data/Talents.lua` (wowhandbook builds), `Data/Macros_Hunter.lua` (Endgame Tools, Kami Labs, Wowcalc, wowf.io notes), `docs/FOREVER_CONSTRAINTS.md` (C16b measured macro rules, Rankedboost class changes), `docs/PROBE_RESULTS.md` (Torrant = Skyborne, APIs present).
- Not reachable this session: Icy Veins Forever pages (403), Method's Forever shaman guide (404).

**How the draft was made:** a scratch generator (not in the repo) holds the layer data: the learn table, ordered slots per spec, mode and key, and the race table. It resolves every level from 1 to 60, writes a bracket wherever the text changes, prints the macros, and counts each one against 255 using the same shrink rule as `HunterFight M:Body`. Result: 803 macros, longest 255, none over. 47 low-priority lines were dropped to fit, each listed in its macro's `dropped` field (mostly the "back to Hawk" line, pet attack on Marksmanship and Survival, Counterattack, and PvP extras).

## Update 2026-11-18 (evening): sources Gary supplied

Gary pasted three pages. Still `verified = false` until seen in game.

**Mobalytics, Forever Beast Mastery Hunter PvP and Marksmanship Hunter PvP (Feor, Nov 7 / Oct 21 2026).** Changes to the hunter `bm` and `mm` PvP Fight keys:
- No Serpent Sting in the PvP opener: a target with a sting on it can't be trapped.
- Multi-Shot is the default while kiting or chasing; Shift gives Aimed Shot when you can stand still or the target is trapped (they share a cooldown).
- Concussive Shot goes before the big shots, so a melee can't close the gap.
- BM: Intimidation moves to Ctrl, used to stun or interrupt a caster. Bestial Wrath is off the Fight key and lives on Burst only; the guide says to save it for after Ice Block or Divine Shield.
- MM: Sniper Shot moves to Ctrl (a 4-second cast, only on a trapped, rooted or unaware target). Viper Sting goes on Alt from 36 (15 s cooldown on Forever).
- Burst = Rapid Fire plus the damage racial, which matches the guide's macro.
- PvP Trap key starts with `/stopattack`, so your own shots don't break Scatter Shot or the trap.
- Every hunter Break key starts with `/stopcasting`, from the guide's Feign Death macro.

**Racials:**
- Night Elf Shadowmeld works in combat on Forever and acts like Feign Death against spells being cast at you, so it is now on the Night Elf Break key (plain press; Shift = Feign Death).
- Troll Rapid Regeneration is used mid-fight while the target is trapped, so the `[nocombat]` guard came off every class's Troll Recover key.
- Tauren War Stomp has a 90 s cooldown (Mobalytics).

**Warcraft Tavern, Forever Racial Abilities Guide (Val Hull)** confirms the race table: two active and two passive racials per race.
- Windshaper (Horde) Skyborne: Walk on Air and Skysight.
- High Order (Alliance) Skyborne: Walk on Air and Read Ley Line.
- The priest racials match the draft.
- The page gives **no cooldowns or levels**, so those stay open, along with the PvP rotations for the other classes.

## Update 2026-11-19: rogue Stealth on the Fight key

Gary, on his level 2 rogue: Stealth was never used. It sat only on the separate Strike key. Below level 14, the Fight key also had no opener, and every line in it had `[nostealth]`, so pressing Fight while sneaking did nothing.

The fix: every rogue Fight bracket, all builds, PvE and PvP, levels 1 to 60, now starts with:

    /cast [nocombat,nostealth] Stealth;[stealth] <opener>

- **The opener by level:**
  - Sinister Strike up to 13.
  - Then the plan's own openers: Garrote at 14, Ambush at 18 for Assassination and Subtlety, Cheap Shot at 26.
- **How it plays:** the first press out of combat puts you in Stealth; the next press opens.
- **Why one line:** a separate Stealth line pushed the level 10 key past 255 characters.
- **Positional openers are not verified on Forever.** In Classic, Garrote and Ambush need you behind the target. If you're in front, the opener fails and you stay in Stealth until you move behind.
- **Test:** `tests/spec/fightplan_spec.lua`, "rogue Stealth on the Fight key". It checks every build at levels 1, 10, 14, 18, 26, 30, 40 and 60, in PvE and PvP.

**Level 4 (same day):** Gary learned Backstab and Pick Pocket at level 4, but nothing changed, because the rogue plan had no level 4 step. Pick Pocket wasn't in the catalogue at all (now `{ 4, "GA" }`, seen in game).
- **Fight key opener from level 4 to 13:** `Stealth;[stealth,equipped:Daggers] Backstab;[stealth] Sinister Strike`. Backstab is used with a dagger; Classic needs you behind the target, which is unverified on Forever. Otherwise it opens with Sinister Strike.
- **Strike key:** `Stealth;[stealth] Pick Pocket`. The flow is Strike to sneak, Strike again to pick a humanoid's pocket, then Fight to open.
- **`FightPlan:Lines`** now drops a `/cast` clause for a spell not learned yet, using `KnownLine`. `KnownLine` keeps the line's own `;` separator.
- **HunterFight** prints one line per session when it rewrites a fight key for new spells.

**Pull key (same day):** the rogue and warrior Pull keys were hard-coded to Shoot Bow. They now pick the shot from what's equipped:

    /cast [nostealth,equipped:Thrown] Throw; [nostealth,equipped:Bows] Shoot Bow; [nostealth,equipped:Crossbows] Shoot Crossbow; [nostealth,equipped:Guns] Shoot Gun

The warrior version has no `[nostealth]`.
- **Rogues can use bows:** Jekar's spellbook on Forever has both Shoot Bow (2480) and Throw (2764). Classic rogues use bows, crossbows, guns and thrown weapons.
- **Not seen on Forever yet:** the Shoot Crossbow and Shoot Gun spell names. They're harmless, because a clause for a shot you haven't learned drops out.

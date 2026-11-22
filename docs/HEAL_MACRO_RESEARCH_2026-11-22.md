# Heal and Fight keys for every class, levels 1-60 (research, 2026-11-22)

Research only. Nothing in the repo was changed. Every line is **verified = false** until a fight log shows it working on Gary's client.

## 0. How to read this

- **Macro cells.** Lines are separated by `<br>`. Every macro also starts with `#showtooltip`, which is left out of the table. The `ch` figure in the Why column is the full length, `#showtooltip` and newlines included, counted by a script (`count_macros.py`, next to this file). All macros are 255 characters or fewer.
- **Short forms used in the text only (not in the macros):**
  - **TGT** is the line `/targetenemy [noharm][dead]`.
  - **H** is the heal unit `[@mouseover,help,nodead][]`. The empty `[]` means "my target, or me if I have no friendly target". That needs the client's Auto Self Cast option, which is on by default (unconfirmed on Forever).
- **Source tags:**
  - **FC** = [foreverchanges.pro spellbooks](https://foreverchanges.pro/spellbook/druid) and talent pages (class pages `/spellbook/<class>` and `/talents/<class>`; built from the live client; the repo's `Data/SpellInfo.lua` comes from the same site).
  - **FCP** = [foreverchanges.pro patch notes](https://foreverchanges.pro/patch-notes).
  - **WHF** = Wowhead Forever spell pages (`wowhead.com/forever/spell=<id>`). These show rank-1 numbers unless a max-rank ID is named.
  - **WT** = Warcraft Tavern Forever guides.
  - **CL** = a Classic Era value, unconfirmed on Forever.
- **Modifier clauses on the Heal keys** (`[mod:shift]`, `[mod:ctrl]`) have no `@mouseover`, to fit 255. They heal your friendly target, or you. Only the plain press heals the mouseover. If Gary heals groups by mouseover, the builder can add `@mouseover` to one modifier per key.
- **Rules every macro follows** (the measured facts in the brief):
  - The order is: channel guard, modifier lines, cooldown lines (they fall through while cooling down), a castsequence of real spells sized to the DoT or HoT duration, then nothing after an always-castable line, because a line below it is never reached.
  - There is no `,null` anywhere.
  - Spells that can be refused for a reason other than cooldown go on a modifier or on the second key: out of range (Fire Blast), wrong target (Exorcism), a proc (Overpower, Victory Rush), or a health gate (Hammer of Wrath, Execute).

### Castsequence behaviour these designs rely on (needs a fight-log check)
1. A step that is on cooldown "parks". The press falls through, and the sequence stays on that step. This is measured for paladin Judgement.
2. A step refused for another reason (no mana, out of range, no HoT on the target) does **not** advance and ends the press. That is Classic behaviour, assumed on Forever.
3. `reset=target` follows **your target**, not your mouseover. With mouseover healing, the heal sequence carries on across players. So no heal sequence contains a step that needs a precondition on that player (Swiftmend, Riptide-boosted Chain Heal). The one exception is the solo sequence, which is self or target.
4. Unknown: whether an interrupted cast (you moved) still advances the sequence. Classic says it advances when the cast starts.

---

## 1. Facts found for Forever (with numbers) that change the macros

| Fact | Value on Forever | Classic | Source |
|---|---|---|---|
| **Lava Burst removed** from the game (Nov 3 launch notes); Call of Thunder (+5% LB/CL crit) takes its slot | gone | n/a | [FC shaman talents](https://foreverchanges.pro/talents/shaman) |
| The repo still writes `/cast Lava Burst` in `Data/FightPlans.lua` (lines ~5715-5892) | stale | | repo |
| Riptide: heal over time only, 805 over 15 s (rank 3), cooldown **12 s** (was 6), -40% mana | 12 s cd | n/a | FC shaman talents + spellbook |
| Stormstrike: 150% normalised weapon damage, cooldown **6 s** (was 8); trainable at 40 (Wowhead Drakanthos build in `Data/Talents.lua`) | 6 s | 10 s CL | FC |
| Maelstrom Weapon procs twice as often; can't benefit two casts (Nov 16) | | | FCP |
| Swiftmend **does not consume** Rejuvenation/Regrowth; 15 s cd, 20% base mana | 15 s | consumes | WT resto druid, FC, [WHF 18562](https://www.wowhead.com/forever/spell=18562/swiftmend) |
| Wild Growth: 3 s cast, **6 s cooldown** shared by all ranks, can't cast while moving; Nature's Swiftness makes it instant (Nov 10) | 6 s cd | n/a | FCP, FC druid talents |
| Rejuvenation 12 s (rank 11 heals 776), Regrowth 2 s cast, 21 s HoT, max rank **525 mana** (Classic 880), heals 965-1077 + 994 | | | FC, WHF 774/8936 |
| Healing Touch max rank: 3.5 s cast, 840 mana, 2139-2525 (rank 1: 1.5 s, 25 mana). Kami Labs saw ~840 mana "regardless of rank" in beta (downranking may not save mana) | | | [WHF 25297](https://www.wowhead.com/forever/spell=25297), [Kami Labs druid](https://kami-labs.fr/en/wow-forever/druide-wow-forever-sorts-et-talents-modifies/) |
| Innervate: trainer 40, 6 min cd, 20 s, +400% regen | 6 min | 6 min | WHF 29166, FC |
| Nature's Swiftness (druid and shaman): 3 min cd, starts when the buff is used | 3 min | 3 min | WHF 17116 / 16188 |
| Gift of the Earthmother: GCD of Rejuv/Swiftmend/HT/WG down 0.5 s (to 1 s) | | n/a | Kami Labs |
| Priest: PW:S 4 s cd, 30 s, can't re-shield the target for 15 s; Renew 15 s; Mind Blast 1.5 s, 8 s cd | | same | WHF 17/139/8092, FC |
| **Devouring Plague: 24 s cooldown, 24 s duration**, trainer 20, any race but Undead/Gnome lists | 24 s | 3 min, Undead only | [WHF 2944](https://www.wowhead.com/forever/spell=2944), FC |
| Shadow Word: Death (32): if the target survives you take **30% of your max health** | | not in Classic | FC priest |
| Shadowform: you **can't cast healing spells** in it (Classic: Holy spells) | | | FC priest |
| Penance: talent 30, 2 s channel (3 bolts); cooldown not published | ? | n/a | FC |
| Greater Heal max 3 s, 710 mana; Flash Heal 1.5 s; Inner Focus 3 min | | | WHF 25314/2061/14751 |
| Binding Heal: **not in the Forever spellbook or tree**; the Holy talent is Holy Binding (Flash Heal also heals you 50%). The repo's priest `learn` table lists Binding Heal 25 | | | FC priest talents |
| Holy Light max: 2.5 s cast, 660 mana, 1495-1665; Flash of Light 1.5 s, 292-325 at max rank | | | WHF 25292/19750, FC |
| Holy Shock: talent 30, **10 s cd** (was 30), 225 mana at rank 1, up to 40 yd per Kami Labs | 10 s | 30 s | WHF 20473, Blazingboost |
| Divine Favor: 2 min cd; also works on Holy Shock | 2 min | 2 min | WHF 20216 |
| Lay on Hands: **20 min** cd, heals to full + 550 mana | 20 min | 60 min | WHF 633, FC |
| Light's Vigil (holy 40): 1.5 s cast, 30 s; next Holy Shock on that target has no cd and heals their party | | n/a | FC, Blazingboost |
| Judgement: 10 s cd, does **not** consume the Seal; Seals last 30 s; **Judgement of Wisdom/Light last 40 s** (Classic 10 s) | | | WHF 20271, FC paladin |
| Crusader Strike: **not on Forever** (no spellbook or talent entry). `Modules/ClassFight.lua` line 264 still lists it (harmless, it drops out) | | | FC paladin |
| Healing Wave max: 3 s cast, 620 mana; Lesser Healing Wave 1.5 s; Chain Heal 2.5 s | | | WHF 25357/8004/1064 |
| Healing Stream and Mana Spring totems last **5 min**, 30 yd (Classic 1 min, 20 yd) | 5 min | 1 min | FC shaman |
| Water Shield (resto talent): 3 globes, 2% max mana each when hit or on a spell crit, 10 min | | n/a | FC |
| Lightning Bolt max rank: **2.5 s** cast, 220 mana | 2.5 s | 3 s | FC shaman |
| Flame Shock, Earth Shock: 6 s cd (shared shock cd is CL); Flame Shock 12 s DoT | | | WHF 8050/8042, FC |
| Evocation: 8 s channel, **8 min** cd | 8 min | 8 min | [WHF 12051](https://www.wowhead.com/forever/spell=12051/evocation) |
| Mana gems: Agate 28, Jade 38, Citrine 48, Ruby 58 (item names are CL) | | | FC mage |
| Arcane Blast (talent): +100% mana per stack, 4 stacks, 18 s. Arcane Wrath adds 5% of max mana as damage | | | FC mage talents |
| Mage Armor: 50% regen while casting (Classic 30%) | | | FC mage |
| Life Tap max rank: **848 health into 848 mana** (Classic 424); scales with Spirit | | | FC warlock, WT |
| Bane of Agony 24 s, instant; Corruption 18 s (rank 1: 12 s, 2 s cast; Improved Corruption -0.4 s per rank); Immolate 15 s, 2 s; Siphon Life 30 s, instant; Drain Life 5 s channel; Conflagrate 10 s cd, consumes Immolate | | | WHF 980/172/348/18265/17962, FC |
| Wrack (Affliction talent): 6 s channel; your DoTs tick 100% faster while it channels | | n/a | FC warlock talents |
| Dark Pact: removed | | | FC |
| Battle Shout **3 min** (Classic 2 min); Thunder Clap 6 s cd; Rend 21 s at max rank (9 s rank 1); Victory Rush usable 20 s after a kill, heals 10% | | | FC warrior |
| Shank (24): off-hand strike that **generates 25 Energy**, can't miss; off-hand needed (CL inference from "off-hand") | | n/a | FC rogue |
| Slice and Dice 9 s + 3 s per combo point (21 s at 5) | | same | FC rogue |
| Immolation/Explosive Trap cd 30 s (Classic 15 s), usable in combat | | | FC hunter |
| **Tiger's Fury**: Kami Labs says "+15% damage for 6 s, level 24"; the FC spellbook (live client) has **no** Tiger's Fury | conflict | | Kami Labs vs FC |
| DoT and HoT values update while they tick (no snapshot) | | snapshot | WT priest levelling |

---

## 2. Mana: what a macro can and can't do, and the best legal patterns

A macro can't see mana. A spell refused for "Not enough mana" ends the press, and the press does not fall through to the wand. These are the legal patterns, best first:

1. **"Conserve mode" rewritten between fights (recommended addition).** Out of combat, Outrider reads the player's mana. Player mana *may* be a secret value in combat: pet `UnitPower` was secret in combat (`PROBE_RESULTS.md`), so probe the player's out of combat. After a fight, if mana is under about 40%, Outrider rewrites Fight for the next pull in a cheaper order:
   - priest: DoT + wand instead of the Smite or Mind Flay loop;
   - paladin: Seal of Wisdom in the sequence;
   - warlock: Life Tap first, then Drain Life instead of Shadow Bolt;
   - mage: wand finish.
   - When mana is back up, Outrider writes the normal order again.

   This is the same legal mechanism as "leave a buff line out while the buff is up". It is the only way to make the order depend on mana.
2. **Alt = mana on the Heal key and the Fight key** (your plan). Each class's mana cooldown comes first, because it falls through while it cools down. The best potion comes last.
   - druid: `Innervate @player`;
   - mage: mana gem, then Evocation;
   - priest: Inner Focus (free next spell);
   - Undead: Dark Sacrifice;
   - warlock: Life Tap;
   - then `/use [mod:alt,combat] <best mana potion>` (Outrider writes the item name out of combat).
   - **Test needed:** does `/use` of a potion on its cooldown fall through like a spell on cooldown? If not, put the potion first.
3. **Shift = wand** on caster Fight keys (`/cast [mod:shift] !Shoot`). It's the low-mana filler you choose to use. A second key with just `/cast !Shoot` is better if `!Shoot` turns out to restart the wand swing when pressed again, as `!Auto Shot` did (`FOREVER_CONSTRAINTS` C16b).
4. **On-screen cue.** If player mana is readable in combat, show a cue: "hold Alt" on low mana, "hold Shift: wand" when out of mana. If it's secret, the modern client's secret-safe display tools may still work. Those are a StatusBar fed the raw value, and possibly the Midnight `UnitPowerPercent` with a colour curve. Both are unconfirmed on Forever: probe before building. Rule 4 still holds: display it, never compare it.
5. **Drink line out of combat:** `/use [nocombat,mod:alt] <best water>` on the same Alt branch. Outrider writes the item, and one Alt press between pulls drinks.

---

## 3. Druid

**Heal key.** Max-HPS vs mana:
- Regrowth is the efficient direct heal on Forever: about 3.8 health per mana at max rank (965-1077 + 994 for 525 mana).
- Healing Touch is the burst heal: about 2.8 per mana, and about 670 HPS against Regrowth's ~510 direct.
- Rejuvenation is the HoT that also lets Swiftmend work.
- Swiftmend doesn't eat the HoT on Forever, so it's pure extra healing every 15 s.

So:
- **plain** = HoTs + Regrowth, and Healing Touch when the loop gets to it;
- **Shift** = Nature's Swiftness + Healing Touch;
- **Ctrl** = Healing Touch (25+: Wild Growth for resto at 40);
- **Alt** = Innervate.

`/cancelform` comes first, because healing fails in every form (Kami Labs) and Moonkin "prevents healing spells" (FC). It is assumed not to use up the press (Classic powershift behaviour): **check**.

| Level band | Macro lines in order | Why | Source |
|---|---|---|---|
| 1-3 | `/cancelform`<br>`/cast [@mouseover,help,nodead][] Healing Touch` | Only heal (rank 1: 1.5 s, 25 mana). (71 ch) | WHF 5185, WT druid levelling |
| 4-11 | `/cancelform`<br>`/castsequence [@mouseover,help,nodead][] reset=target Rejuvenation,Healing Touch,Healing Touch,Healing Touch,Healing Touch` | Rejuv (12 s) once, then Healing Touch. The loop is about 1.5 + 4 x 2 s = 9.5 s, so Rejuv comes round as it runs out. Stop pressing when full. (147 ch) | WHF 774, FC |
| 12-24 | `/cancelform`<br>`/cast [mod:ctrl] Healing Touch`<br>`/castsequence [@mouseover,help,nodead][] reset=target Rejuvenation,Regrowth,Regrowth,Healing Touch` | Regrowth (12) is the efficient heal. Loop 1.5 + 2 + 2 + 3 s = about 9-11 s against Rejuv's 12. The second Regrowth refreshes the direct heal; its HoT is 21 s, so this is a deliberate HPS trade. Ctrl = big single heal. (154 ch) | FC (Regrowth 525 mana), WT |
| 25-39 (Resto: Swiftmend, NS) | `/cancelform`<br>`/cast [mod:shift] Nature's Swiftness`<br>`/cast [mod] Healing Touch`<br>`/castsequence [@mouseover,help,nodead][] reset=target Rejuvenation,Regrowth,Swiftmend,Healing Touch` | Shift: NS falls through on its 3 min cd; if NS ends the press, the next Shift press is an instant HT either way (Rankedboost's Forever macro does it in one press). Swiftmend sits **after** two HoTs, so it is never refused for "no HoT" on a self/target loop; on its 15 s cd it parks. Loop about 1.5 + 2 + 1.5 + 3.5 = 8.5-12 s. Non-resto: drop the Swiftmend step and NS. (187 ch) | WT resto (Swiftmend doesn't consume), WHF 18562, [Rankedboost resto macros](https://rankedboost.com/world-of-warcraft/forever/macros/druid/restoration/) |
| 40-60 (Resto) | `/cancelform`<br>`/cast [mod:alt,@player] Innervate`<br>`/cast [mod:shift] Nature's Swiftness`<br>`/cast [mod:shift] Healing Touch;[mod:ctrl] Wild Growth`<br>`/castsequence [@mouseover,help,nodead][] reset=target Rejuvenation,Regrowth,Swiftmend,Healing Touch` | Alt: Innervate on yourself (6 min). Ctrl: Wild Growth (3 s cast, 6 s cd, party heal). The Nov 10 hotfix lets NS make WG instant, so Shift+Ctrl is not needed. Loop is 12 s with Gift of the Earthmother's 1 s GCD. **Conflict:** WHF says Innervate can't be cast shapeshifted; FOREVER_CONSTRAINTS (Rankedboost) says it works in Moonkin. The cancelform line covers both. (250 ch) | FCP (WG cd), WHF 29166, Kami Labs (GotE) |

**Fight key** (caster until Cat at 20; Balance from 25). The DoT is 12 s from Moonfire rank 2 (rank 1 is 9 s), and Insect Swarm is 12 s. Wrath is 2 s at max rank. Starfire is 3.5 s (CL), with Eclipse cutting 0.17 s per rank.

| Level band | Macro lines in order | Why | Source |
|---|---|---|---|
| 1-3 | `/targetenemy [noharm][dead]`<br>`/cast Wrath` | Only damage spell. (52 ch) | WT druid levelling |
| 4-9 | `/targetenemy [noharm][dead]`<br>`/castsequence reset=target Wrath,Moonfire,Wrath,Wrath,Wrath` | Wrath pull (guide), Moonfire 9 s, then Wraths. The loop is about 1.5 x 4 + 1.5 = 7.5-9 s. Matches the repo's measured-safe shape (real spells, no null). (100 ch) | WHF 8921 (rank 1 9 s), WT |
| 10-19 caster | `/targetenemy [noharm][dead]`<br>`/castsequence [noform] reset=target Wrath,Moonfire,Wrath,Wrath,Wrath,Wrath`<br>`/cast [form:1] Maul` | Moonfire 12 s now: 1.5 + 5 x 2 = 11.5 s. In Bear (form 1, read from the stance bar) Maul instead. (135 ch) | WHF, FC |
| 20-39 Cat (levelling choice per WT) | `/targetenemy [noharm][dead]`<br>`/startattack`<br>`/cast [noform] Cat Form`<br>`/cast [mod:shift,form:3] Ferocious Bite;[mod:ctrl,form:3] Shifting Power`<br>`/castsequence [form:3] reset=target Rake,Claw,Claw,Claw,Claw,Rip` | Rake (1 CP, 9 s bleed), 4 Claw = 5 CP, then Rip (12 s). Energy shortfall ends the press without advancing, so spamming just waits. Shift: Ferocious Bite (WT: 4-5 CP and 70+ energy). Ctrl: Shifting Power (feral talent, about 40; "below 50 energy"). Shred (behind) is not used, since a spam key can't know you're behind. Tiger's Fury is left out (conflict, section 1). Form numbers are as the repo reads them (3 = Cat), unconfirmed. (215 ch) | WT druid levelling, FC (Rake/Rip/Shifting Power) |
| 25-60 Balance caster | `/targetenemy [noharm][dead]`<br>`/cast [mod:alt,@player] Innervate`<br>`/castsequence [noform][form:5] reset=target Moonfire,Insect Swarm,Starfire,Starfire,Wrath` | WT: from 30, "2 Starfire + 1 Wrath". Loop 1.5 + 1.5 + 3.5 + 3.5 + 2 = 12 s, the same as Moonfire and Insect Swarm's 12 s. Between 25 and 29, use Wrath,Wrath in place of Starfire,Starfire. `form:5` is a guess at Moonkin's slot: Outrider must read it from the stance bar. (164 ch) | WT, FC (IS 12 s, Eclipse) |

---

## 4. Priest

**Heal key.**
- Greater Heal (40, 3 s) is the most mana-efficient big heal.
- Flash Heal (20, 1.5 s) is the fast, expensive one.
- Renew (15 s) goes once per loop.
- PW:S is on Shift only. Weakened Soul (15 s) makes a re-shield fail for a non-cooldown reason, which would stall a sequence.
- Holy's **Litany of Light** returns 5% base cost when you alternate heals, which favours a mixed loop.

Shadowform blocks every heal on Forever, so the Heal key starts with `/cancelform`. That Shadowform counts as a form for `/cancelform` is CL: **check**.

| Level band | Macro lines in order | Why | Source |
|---|---|---|---|
| 1-5 | `/cast [@mouseover,help,nodead][] Lesser Heal` | Only heal. (57 ch) | WT priest levelling |
| 6-7 | `/cast [mod:shift] Power Word: Shield;[@mouseover,help,nodead][] Lesser Heal` | Shift: shield (4 s cd, 15 s Weakened Soul). (88 ch) | WHF 17 |
| 8-15 | `/cast [mod:shift] Power Word: Shield`<br>`/castsequence [@mouseover,help,nodead][] reset=target Renew,Lesser Heal,Lesser Heal,Lesser Heal,Lesser Heal` | Renew 15 s; Lesser Heal ranks 1.5-2.5 s (CL), so the loop is about 9-11.5 s. (157 ch) | WHF 139, FC |
| 16-39 | `/cancelform`<br>`/cast [mod:shift] Power Word: Shield;[mod:ctrl] Flash Heal`<br>`/castsequence [@mouseover,help,nodead][] reset=target Renew,Heal,Heal,Heal,Heal` | Heal (16) is about 3 s (CL): 1.5 + 12 = 13.5 s against Renew's 15. Ctrl (20+): Flash Heal when it must land now. (163 ch) | FC (Heal max rank 34), WT holy |
| 30-60 Disc | `/stopmacro [channeling]`<br>`/cast [mod:shift] Power Word: Shield;[mod:ctrl] Flash Heal`<br>`/cast [@mouseover,help,nodead][] Penance`<br>`/castsequence [@mouseover,help,nodead][] reset=target Renew,Greater Heal,Greater Heal,Greater Heal,Greater Heal` | Penance (2 s channel) on cooldown, with a channel guard so re-pressing doesn't clip it. Its Forever cooldown isn't published. Greater Heal from 40 (Heal before). WT Disc: "Renew, Shield, Penance, Flash Heal, Greater Heal for big damage". (248 ch) | WT disc, FC (Penance) |
| 40-60 Holy | `/cancelform`<br>`/cast [mod:alt] Inner Focus`<br>`/cast [mod:shift] Power Word: Shield;[mod:ctrl] Flash Heal`<br>`/castsequence [@mouseover,help,nodead][] reset=target Renew,Greater Heal,Flash Heal,Greater Heal,Greater Heal` | Mixed loop for Litany of Light: 1.5 + 3 + 1.5 + 3 + 3 = 12 s against Renew's 15. Holy Binding makes every Flash Heal also heal you 50%. Alt: Inner Focus (3 min), so the next heal is free with +25% crit (WT: "pair with Greater Heal"). Prayer of Mending (holy talent 40) belongs on its own key or Ctrl+Shift; there's no room. (221 ch) | WT holy, FC (Litany, Holy Binding, Inner Focus) |

**Fight key.**
- Smite at max rank is 2.5 s (CL).
- SW:P is 18 s.
- Mind Blast: 8 s cd.
- Devouring Plague: cd = duration = 24 s, so a plain cooldown line keeps it up exactly.
- Mind Flay: 3 s channel.
- Wand on Shift.

| Level band | Macro lines in order | Why | Source |
|---|---|---|---|
| 1-3 | `/targetenemy [noharm][dead]`<br>`/cast Smite` | (52 ch) | WT |
| 4-9 | `/targetenemy [noharm][dead]`<br>`/cast [mod:shift] !Shoot`<br>`/castsequence reset=target Smite,Shadow Word: Pain,Smite,Smite,Smite,Smite,Smite` | Smite pull (WT), SW:P 18 s, then Smites: about 1.5 + 6 x 1.5-2.5 s. Shift = wand (from 5). (146 ch) | WHF 589, WT |
| 10-19 | `/targetenemy [noharm][dead]`<br>`/cast [mod:shift] !Shoot`<br>`/cast Mind Blast`<br>`/castsequence reset=target Shadow Word: Pain,Smite,Smite,Smite,Smite` | Mind Blast on cooldown, **above** the sequence (a filler sequence never parks, so anything below it is unreachable). Per 18 s: 2 Mind Blasts + SW:P + 4 Smites = 3 + 1.5 + 10 = 14.5-17 s. (151 ch) | WHF 8092 |
| 20-29 Shadow | `/targetenemy [noharm][dead]`<br>`/stopmacro [channeling]`<br>`/cast [mod:shift] !Shoot`<br>`/cast Devouring Plague`<br>`/cast Mind Blast`<br>`/castsequence reset=target Shadow Word: Pain,Mind Flay,Mind Flay,Mind Flay` | DP keeps itself up (24/24). Per 18 s: SW:P + 3 Flays (10.5 s) + 2 MB + DP (about 4.5 s) = 15-18 s. WT: Shadow "shines" from about 28. Before Mind Flay (talent 24 in the wowhandbook build) use Smite. DP costs a lot (215 at rank 1): drop the line in conserve mode. (204 ch) | WHF 2944, WT, FC |
| 27-60 Shadow | `/targetenemy [noharm][dead]`<br>`/stopmacro [channeling]`<br>`/cast [mod:shift] !Shoot`<br>`/cast Devouring Plague`<br>`/cast Mind Blast`<br>`/castsequence reset=target Vampiric Embrace,Shadow Word: Pain,Mind Flay,Mind Flay,Mind Flay,Shadow Word: Pain,Mind Flay` | VE is 30 s, so it comes once per two SW:P cycles (about 30-34 s). SW:Death (32) goes on the Strike key as an execute only, because you take 30% of your max health if it doesn't kill (no room here). Shadowform goes on as a buff line while missing (Outrider rewrite). (249 ch) | FC (VE 30 s, SW:D backlash) |
| 30-60 Disc | `/targetenemy [noharm][dead]`<br>`/stopmacro [channeling]`<br>`/cast [mod:shift] !Shoot`<br>`/cast Penance`<br>`/cast Mind Blast`<br>`/castsequence reset=target Shadow Word: Pain,Smite,Smite,Smite,Smite` | WT Disc levelling: Smite, SW:P, Penance when available, finish with the wand. Holy is the same without Penance (Holy Fire 20 may replace one Smite). (189 ch) | WT priest levelling |

---

## 5. Paladin

**Heal key.**
- Holy Light (2.5 s, 660 mana, about 1580) is both the higher-HPS heal (about 630 HPS) and the more efficient one per mana on Forever's numbers.
- Flash of Light heals only about 308 at max rank (Classic 368). It's for topping up, and the guides' "efficient filler" when little health is missing.
- Holy Shock is instant but expensive (225 at rank 1): an emergency button.

| Level band | Macro lines in order | Why | Source |
|---|---|---|---|
| 1-19 | `/cast [@mouseover,help,nodead][] Holy Light` | Only heal. (56 ch) | WT paladin levelling |
| 20-29 | `/cast [mod:ctrl] Flash of Light;[@mouseover,help,nodead][] Holy Light` | Plain: Holy Light, the most healing per second and per mana. Ctrl: Flash of Light when little is missing (less overheal). (82 ch) | WHF 25292/19750, FC, [Icy Veins via search](https://www.icy-veins.com/wow-forever/holy-paladin-healer-pve-rotation-cooldowns-abilities) |
| 30-39 Holy | `/cast [mod:shift] Divine Favor`<br>`/cast [mod:shift] Holy Shock;[mod:ctrl] Flash of Light;[@mouseover,help,nodead][] Holy Light` | Shift = emergency: Divine Favor (2 min) falls through on cooldown, then Holy Shock (10 s), a guaranteed crit and an Illumination refund. Infusion of Light (FoL/Shock crit, then Holy Light -0.5 s) fits the plain press. (136 ch) | WHF 20216/20473, FC talents, WT holy |
| 40-60 Holy | `/castsequence [mod:alt] reset=combat Light's Vigil,Holy Shock,Holy Shock`<br>`/cast [mod:shift] Divine Favor`<br>`/cast [mod:shift] Holy Shock;[mod:ctrl] Flash of Light;[@mouseover,help,nodead][] Holy Light` | Alt is the group heal here. Light's Vigil (1.5 s cast, 30 s), and the next Holy Shock has no cooldown and heals the party (wowtbc: "Vigil, then Holy Shock twice"). The mana potion then goes on a separate key for the paladin, because there's no room. Lay on Hands (20 min) belongs on a Recover/Break key. (209 ch) | FC, [wowtbc.gg holy paladin](https://wowtbc.gg/warcraftforever/class-guides/holy-paladin/) |

**Fight key (Retribution levelling).**
- Seals last 30 s, and Judgement has a 10 s cd and doesn't consume the Seal. So `Seal,Judgement,Judgement,Judgement` re-seals exactly as the Seal expires. This is measured on Gul.
- Holy Strike's cooldown is not published (it falls through either way).

| Level band | Macro lines in order | Why | Source |
|---|---|---|---|
| 1-3 | `/targetenemy [noharm][dead]`<br>`/startattack` | Seal of Righteousness as a buff line while missing (Outrider rewrite). No Judgement yet, so a castsequence would only re-seal every press. (53 ch) | WT |
| 4-5 | `/targetenemy [noharm][dead]`<br>`/startattack`<br>`/castsequence reset=combat Seal of Righteousness,Judgement,Judgement,Judgement` | Seal, then Judgement on cd, and re-seal about every 30 s. (132 ch) | measured (FOREVER_CONSTRAINTS), FC |
| 6-19 | `/targetenemy [noharm][dead]`<br>`/startattack`<br>`/castsequence reset=combat Seal of Righteousness,Judgement,Judgement,Judgement`<br>`/cast Holy Strike` | The sequence parks on Judgement's cd, and the press falls through to Holy Strike (6). WT: "Judgement and Holy Strike loop". (150 ch) | WT, FC (Holy Strike 6) |
| 20-43 Ret | `/targetenemy [noharm][dead]`<br>`/startattack`<br>`/cast [mod:shift] Consecration;[mod:ctrl] Exorcism`<br>`/castsequence reset=combat Seal of Command,Judgement,Judgement,Judgement`<br>`/cast Holy Strike` | Seal of Command with a two-hander (WT; Righteousness with a one-hander). Shift: Consecration for packs. Ctrl: Exorcism, which is Undead/Demon only (refused otherwise), so it can't be on plain. (195 ch) | WT, FC |
| 38-60 conserve mode (Outrider writes it out of combat when mana is low) | `/targetenemy [noharm][dead]`<br>`/startattack`<br>`/castsequence reset=combat Seal of Wisdom,Judgement,Seal of Command,Judgement,Judgement`<br>`/cast Holy Strike` | Judgement of Wisdom lasts 40 s on Forever and refunds mana on every hit on the judged target. Then Command for damage. **Unconfirmed:** whether a later Judgement of Command replaces your Wisdom debuff (WT: "one Judgement debuff per paladin"; JoC is damage, not a debuff). (159 ch) | FC (40 s JoW), WT |
| 44-60 | (same as 20-43) plus `/cast [mod:alt] Hammer of Wrath` in place of the Ctrl clause when Exorcism isn't wanted | Hammer of Wrath only works under 20% health (refused otherwise), so it goes on a modifier. | FC |

---

## 6. Shaman

**Heal key.**
- Healing Wave (3 s, 620 mana, about 1615) is the efficient heal.
- Lesser Healing Wave (1.5 s, about 820) gives the same HPS for more mana, with no waiting.
- Riptide (resto 40): 12 s cd, 15 s HoT, +25% to Chain Heal on that target.

| Level band | Macro lines in order | Why | Source |
|---|---|---|---|
| 1-19 | `/cast [@mouseover,help,nodead][] Healing Wave` | (58 ch) | WT shaman levelling |
| 20-39 | `/cast [mod:shift] Nature's Swiftness`<br>`/cast [mod:shift] Healing Wave;[mod:ctrl] Lesser Healing Wave;[@mouseover,help,nodead][] Healing Wave` | Plain: Healing Wave. Ctrl: LHW when it must land fast. Shift: NS (resto talent tier 5) + instant Healing Wave (WT: "macro it with Healing Wave or Chain Heal"). Without NS, the first line drops out. (151 ch) | WT resto, WHF 16188 |
| 40-60 Resto | `/cast [mod:shift] Nature's Swiftness`<br>`/cast [mod:shift] Healing Wave;[mod:ctrl] Chain Heal`<br>`/castsequence [@mouseover,help,nodead][] reset=target Riptide,Healing Wave,Healing Wave,Healing Wave,Lesser Healing Wave` | Loop 1.5 + 9 + 1.5 = 12 s, the same as Riptide's 12 s cd (HoT 15 s). Ctrl: Chain Heal (2.5 s), best right after Riptide on the same target (WT: "Riptide first"). Healing Stream and Mana Spring last 5 min on Forever, so they go on Call of the Elements, not here. Water Shield is a buff line while missing. (223 ch) | FC (Riptide 12 s), WT resto |

**Fight key.**
- Shocks: 6 s cd (sharing is CL).
- Flame Shock: 12 s.
- Lightning Bolt: 2.5 s at max rank.
- **No Lava Burst** (removed).
- Enhancement Stormstrike from 40, 6 s.

| Level band | Macro lines in order | Why | Source |
|---|---|---|---|
| 1-3 | `/targetenemy [noharm][dead]`<br>`/startattack`<br>`/cast [nocombat] Lightning Bolt` | WT: Lightning Bolt pull, then melee. Rockbiter and Lightning Shield (8) as buff lines while missing. (85 ch) | WT |
| 4-9 | `/targetenemy [noharm][dead]`<br>`/startattack`<br>`/cast [nocombat] Lightning Bolt`<br>`/cast Earth Shock` | WT: "Earth Shock right after it". Earth Shock costs 30 at rank 1; on cd the press falls through to nothing (melee runs). (103 ch) | WT, WHF 8042 |
| 10-19 | `/targetenemy [noharm][dead]`<br>`/startattack`<br>`/cast [nocombat] Lightning Bolt`<br>`/castsequence reset=target Flame Shock,Earth Shock` | Shared 6 s shock cd: Flame Shock at 0 s, Earth Shock at 6 s, Flame Shock at 12 s, the same as its 12 s DoT. Searing Totem (55 s) on Ctrl or its own key. (136 ch) | WHF 8050, FC |
| 20-39 Enh | `/targetenemy [noharm][dead]`<br>`/startattack`<br>`/cast [nocombat] Lightning Bolt`<br>`/castsequence reset=combat Call of the Elements,Flame Shock,Earth Shock,Flame Shock,Earth Shock,Flame Shock,Earth Shock,Flame Shock,Earth Shock` | Totems once per about 48 s (Searing Totem lasts 55 s), and the shocks alternate between. Maelstrom Weapon (talent about 35): 5-stack Lightning Bolt on Shift (`/cast [mod:shift] Lightning Bolt`). (229 ch) | FC (CotE, Searing 55 s), WT |
| 40-60 Enh | `/targetenemy [noharm][dead]`<br>`/startattack`<br>`/cast [mod:shift] Lightning Bolt`<br>`/cast Stormstrike`<br>`/castsequence reset=combat Call of the Elements,Flame Shock,Earth Shock,Flame Shock,Earth Shock,Flame Shock,Earth Shock` | Stormstrike (6 s, buffs the next Earth Shock or LB 20%) above the shock loop. The `[nocombat]` LB pull moves to Shift, which also spends Maelstrom stacks. (224 ch) | FC (Stormstrike 6 s, 1.60.1 notes), WH Drakanthos build |
| 10-60 Elemental | `/targetenemy [noharm][dead]`<br>`/cast [mod:shift] Chain Lightning;[mod:ctrl] Lightning Mastery`<br>`/castsequence reset=target Flame Shock,Lightning Bolt,Lightning Bolt,Lightning Bolt,Lightning Bolt` | 1.5 + 4 x 2.5 = 11.5 s against Flame Shock's 12. Shift: Chain Lightning (32) for packs. Ctrl: Lightning Mastery (talent, replaces Elemental Mastery: -0.5 s Lightning Bolt for 15 s). The Lava Burst lines in `Data/FightPlans.lua` must go. (202 ch) | FC, WT |

---

## 7. Mage

**Fight key.**
- Frostbolt is the main spell while levelling (WT).
- Fire Blast only reaches 20 yd (CL), so out of range would end the press. It goes on Ctrl, with the close-range spells kept on the Strike key.
- Arcane Missiles (channel) is only worth it on a Missile Barrage proc, which a macro can't see: Shift on the Arcane key.
- Alt = mana: gem, then Evocation (8 min).

| Level band | Macro lines in order | Why | Source |
|---|---|---|---|
| 1-3 | `/targetenemy [noharm][dead]`<br>`/cast Fireball` | (55 ch) | WT mage levelling |
| 4-19 | `/targetenemy [noharm][dead]`<br>`/cast [mod:shift] !Shoot;[mod:ctrl] Fire Blast`<br>`/cast Frostbolt` | WT: Frostbolt main from 4, Fire Blast (6) at the end of a Frostbolt (Ctrl, range), wand to finish (Shift, low mana). (103 ch) | WT |
| 20-39 Arcane (wowhandbook build) | `/targetenemy [noharm][dead]`<br>`/stopmacro [channeling]`<br>`/use [mod:alt] Mana Agate`<br>`/cast [mod:alt] Evocation;[mod:shift] Arcane Missiles;[mod:ctrl] Fire Blast`<br>`/castsequence reset=target Arcane Blast,Arcane Blast,Arcane Blast,Arcane Wrath,Frostbolt` | WT Arcane: 3-4 Blast stacks, then Arcane Wrath, then a non-Arcane spell while stacks drop (Frostbolt also fishes Missile Barrage). Blast stacks double the mana cost each time (FC), so WT warns "three early Arcane Blasts can empty you". Conserve mode: Outrider drops the Blasts to two. Arcane Wrath is in the sequence, so if it has a cooldown (unpublished) it parks. The gem name changes at 38/48/58 (Jade, Citrine, Ruby: CL names). (255 ch) | WT, FC mage talents |
| 40-60 Frost (guide respec) | `/targetenemy [noharm][dead]`<br>`/stopmacro [channeling]`<br>`/use [mod:alt] Mana Citrine`<br>`/cast [mod:alt] Evocation;[mod:shift] Ice Lance;[mod:ctrl] Fire Blast`<br>`/cast Frostbolt` | Frostbolt main. Shift: Ice Lance (8 s cd, x3 on frozen) when Fingers of Frost lights up or after your own Frost Nova (Strike key). Frostfire Bolt (40) hits less than Frostbolt at max rank (270-314 + 57 vs 457-493), so it isn't the filler. (178 ch) | FC (Frostfire vs Frostbolt), WT |
| 20-60 Fire (alternative) | `/targetenemy [noharm][dead]`<br>`/cast [mod:shift] Pyroblast;[mod:ctrl] Fire Blast`<br>`/castsequence reset=target Fireball,Fireball,Scorch` | WT Fire: Fireball filler, Scorch stacks (Improved Scorch 30 s), Pyroblast at 3 Heating Up stacks (Shift; invisible to the macro). (142 ch) | WT, FC |

---

## 8. Warlock

**Fight key.**
- Life Tap is about 1:1 health to mana at max rank, twice Classic's rate, so warlock mana comes from health. Life Tap goes on Ctrl, and Drain Life (from 30) gives the health back.
- Wand: Shift.
- `/stopmacro [channeling]` protects Drain Life and Wrack.

| Level band | Macro lines in order | Why | Source |
|---|---|---|---|
| 1-3 | `/targetenemy [noharm][dead]`<br>`/petattack [pet,harm]`<br>`/cast [mod:shift] !Shoot`<br>`/castsequence reset=target Immolate,Shadow Bolt,Shadow Bolt,Shadow Bolt,Shadow Bolt` | Immolate 15 s; Shadow Bolt 1.7-2.2 s at low ranks (CL), so the loop is about 9-11 s. (171 ch) | WT warlock levelling |
| 4-9 | `/targetenemy [noharm][dead]`<br>`/petattack [pet,harm]`<br>`/cast [mod:shift] !Shoot;[mod:ctrl] Life Tap`<br>`/castsequence reset=target Corruption,Immolate,Shadow Bolt,Shadow Bolt,Shadow Bolt` | Corruption rank 1 is 12 s (2 s cast). From 8, Bane of Agony leads the sequence (see the next row). Life Tap from 6 on Ctrl. (190 ch) | WHF 172, WT |
| 10-29 Affliction | `/targetenemy [noharm][dead]`<br>`/petattack [pet,harm]`<br>`/cast [mod:shift] !Shoot;[mod:ctrl] Life Tap`<br>`/castsequence reset=target Bane of Agony,Corruption,Immolate,Shadow Bolt,Shadow Bolt,Shadow Bolt,Shadow Bolt` | WT: "Bane to pull, Corruption, Immolate on mobs that live, then wand". Loop 1.5 + 2 + 2 + 4 x 2.8-3 s = about 17 s, against Corruption's 18 s and Bane's 24 s. Conserve mode: the sequence stops after Immolate (`Bane,Corruption,Immolate,Shadow Bolt`) and you wand on Shift. (216 ch) | WT, FC durations |
| 30-46 Affliction | `/targetenemy [noharm][dead]`<br>`/stopmacro [channeling]`<br>`/petattack [pet,harm]`<br>`/cast [mod:shift] !Shoot;[mod:ctrl] Life Tap`<br>`/castsequence reset=target Bane of Agony,Corruption,Siphon Life,Drain Life,Drain Life,Drain Life,Drain Life` | WT: Drain Life is the filler from 30, Siphon Life from 37 (leave that step out before then). Loop 4.5 + 4 x 5 = 24.5 s, the same as Bane's 24 s; Corruption (18 s) runs out for about 6 s. WT: "Life Tap when health > mana, Drain Life when mana > health". (239 ch) | WT, FC (Drain 5 s, Siphon 30 s) |
| 47-60 Affliction (Wrack) | `/targetenemy [noharm][dead]`<br>`/stopmacro [channeling]`<br>`/petattack [pet,harm]`<br>`/cast [mod:shift] Drain Life;[mod:ctrl] Life Tap`<br>`/castsequence reset=target Bane of Agony,Corruption,Siphon Life,Wrack,Drain Life,Drain Life` | Wrack (6 s) makes the DoTs tick twice as fast, so they end about 6 s sooner: loop 4.5 + 6 + 10 = 20.5 s against an effective 18 s. WT: Wrack when health **and** mana are high, otherwise Drain Life (Shift). (227 ch) | FC (Wrack), WT |
| 25-60 Destruction | `/targetenemy [noharm][dead]`<br>`/petattack [pet,harm]`<br>`/cast [mod:shift] Shadowburn;[mod:ctrl] Life Tap`<br>`/castsequence reset=target Immolate,Bane of Agony,Shadow Bolt,Shadow Bolt,Shadow Bolt,Conflagrate` | WT Destruction: Immolate, Bane, Conflagrate "right before Immolate runs out", Shadow Bolt (Incinerate, +25% on Immolate, from 40). Loop 2 + 1.5 + 9 = 12.5 s, then Conflagrate (10 s cd) inside the 15 s Immolate. Shift: Shadowburn as the killing blow. (209 ch) | WT, WHF 17962, FC |

---

## 9. Warrior

**Fight key.**
- Battle Shout lasts 3 min on Forever, so it's a buff line while missing, not a castsequence.
- Reactive spells (Overpower, Revenge, Victory Rush, Execute) go on the React key, unchanged from the repo design.
- Heroic Strike is on-next-swing and doesn't use a GCD (CL).

| Level band | Macro lines in order | Why | Source |
|---|---|---|---|
| 1-3 | `/targetenemy [noharm][dead]`<br>`/startattack`<br>`/cast Heroic Strike` | Rage dump. (73 ch) | WT warrior levelling |
| 4-9 | `/targetenemy [noharm][dead]`<br>`/startattack`<br>`/cast [nocombat] Charge`<br>`/castsequence reset=target Rend,Heroic Strike,Heroic Strike,Heroic Strike,Heroic Strike` | Rend rank 1 is 9 s (rank 7: 21 s); about four swings later Rend comes round. Out of rage, the press ends and waits. (165 ch) | WHF 772, FC |
| 10-29 | `/targetenemy [noharm][dead]`<br>`/startattack`<br>`/cast [nocombat] Charge`<br>`/cast [mod:shift] Thunder Clap;[mod:ctrl] Cleave`<br>`/castsequence reset=target Rend,Heroic Strike,Heroic Strike,Heroic Strike,Heroic Strike,Heroic Strike` | Thunder Clap (6 s cd) for packs on Shift; Cleave (20) on Ctrl. Bloodrage (10, off-GCD) belongs on React or Burst. (228 ch) | FC (TC 6 s), WT |
| 30-39 Fury (Drakanthos build) | `/targetenemy [noharm][dead]`<br>`/startattack`<br>`/cast [nocombat] Charge;[combat] Intercept`<br>`/cast Whirlwind`<br>`/cast [mod:shift] Cleave;Heroic Strike` | Whirlwind (36, uses both weapons on Forever) on cd. Charge needs Battle Stance and Intercept Berserker: each refusal ends the press, so set the stance before the pull. **Issue:** Heroic Strike every press can starve Whirlwind of rage; Classic levelling accepts this. (151 ch) | FC (Whirlwind), Data/Talents.lua Fury build |
| 40-60 Arms/Fury | `/targetenemy [noharm][dead]`<br>`/startattack`<br>`/cast [nocombat] Charge`<br>`/cast Mortal Strike`<br>`/cast Whirlwind`<br>`/castsequence reset=target Rend,Heroic Strike,Heroic Strike,Heroic Strike,Heroic Strike,Heroic Strike,Heroic Strike` | Mortal Strike (Arms) or Bloodthirst (Fury, and leave Rend out) on cd above the filler. Cooldowns not published (CL: 6 s). (229 ch) | FC (MS/BT 40) |

---

## 10. Rogue

**Fight key.**
- The Stealth/opener line is kept from the repo (the 2026-11-19 fix).
- Combo points are invisible to the macro, so the builder/finisher order is a fixed count.
- Out of energy, the press ends and the sequence doesn't advance (it waits).

| Level band | Macro lines in order | Why | Source |
|---|---|---|---|
| 1-9 | `/targetenemy [noharm][dead]`<br>`/cast [nocombat,nostealth] Stealth;[stealth] Sinister Strike`<br>`/startattack [nostealth]`<br>`/castsequence reset=target Sinister Strike,Sinister Strike,Sinister Strike,Eviscerate` | 3 CP then Eviscerate (35 energy). From 4, Backstab with a dagger in the Stealth clause (repo). (212 ch) | repo 2026-11-19, FC |
| 10-23 | `/targetenemy [noharm][dead]`<br>`/cast [nocombat,nostealth] Stealth;[stealth] Sinister Strike`<br>`/castsequence reset=target Sinister Strike,Sinister Strike,Slice and Dice,Sinister Strike,Sinister Strike,Sinister Strike,Eviscerate` | Slice and Dice at 2 CP (15 s), then 3 CP Eviscerate. 14+: Garrote, 18+: Ambush in the Stealth clause (behind the target, unverified on Forever). (234 ch) | FC (SnD 9 + 3/CP) |
| 24-39 | `/targetenemy [noharm][dead]`<br>`/cast [nocombat,nostealth] Stealth;[stealth] Cheap Shot`<br>`/cast Shank`<br>`/castsequence reset=target Sinister Strike,Sinister Strike,Slice and Dice,Sinister Strike,Sinister Strike,Sinister Strike,Eviscerate` | Shank **gives** 25 energy and can't miss. On cd it falls through, so it goes above the sequence. It needs an off-hand weapon, which is an assumption from "off-hand strike": without one, it's refused and ends the press, so leave the line out. Cheap Shot 26 opener. (241 ch) | FC (Shank), WT rogue |
| 40-60 Assassination | `/targetenemy [noharm][dead]`<br>`/cast [nocombat,nostealth] Stealth;[stealth] Cheap Shot`<br>`/cast Shank`<br>`/castsequence reset=target Mutilate,Slice and Dice,Mutilate,Mutilate,Eviscerate` | Mutilate gives 2 CP (CL; FC doesn't say), so 1 Mutilate means about 2 CP Slice and Dice, and 2 more mean 4 CP Eviscerate. Combat and Subtlety keep the 24-39 line, with Hemorrhage in place of Sinister Strike for Subtlety. (188 ch) | FC, WT |

---

## 11. Hunter

The hunter Fight key is measured on Torrant (`FOREVER_CONSTRAINTS` C16b, `HunterFight.lua`). Its once-per-pull `Hunter's Mark,!Auto Shot,Serpent Sting,null` line is one of the **open** `,null` lines that probably wrap. A null-free shape that keeps Auto Shot to one press per loop:

| Level band | Macro lines in order | Why | Source |
|---|---|---|---|
| 6-19 | `/targetenemy [noharm][dead]`<br>`/petattack [pet,harm]`<br>`/castsequence reset=target Hunter's Mark,!Auto Shot,Serpent Sting,Arcane Shot,Arcane Shot,Serpent Sting,Arcane Shot,Arcane Shot` | Serpent Sting 15 s; Arcane Shot's cd (6 s CL) parks the sequence, so the loop is about 30 s and Mark and Auto Shot come round about every 30 s. Most mobs die first. Below 6, `!Auto Shot,Serpent Sting,Raptor Strike` on Strike. (190 ch) | WHF 1978, FC |
| 20-60 BM | `/targetenemy [noharm][dead]`<br>`/petattack [pet,harm]`<br>`/cast [mod:shift] Multi-Shot;Aimed Shot`<br>`/castsequence reset=target Hunter's Mark,!Auto Shot,Serpent Sting,Summon Hawk,Arcane Shot,Serpent Sting,Summon Hawk` | Aimed and Multi-Shot share a cooldown; Summon Hawk (25) shares Arcane Shot's. **Unknown:** whether Aimed Shot (a cast) above the sequence clips Auto Shot (open check 1 in the research doc). (218 ch) | FC (shared cds), repo |

---

## 12. Healing for the other classes (out of scope, for completeness)
- **Hunter:** Mend Pet (pet key).
- **Warlock:** Drain Life, Death Coil (heals 100% of its damage on Forever), Health Funnel (pet).
- **Warrior:** Victory Rush, 10% health after a kill (React key).
- **Rogue and mage:** none (bandages; Ice Barrier and Mana Shield absorb damage).
- **Racial heals:** Troll Rapid Regeneration, Dwarf priest Desperate Prayer, Undead Cannibalize (repo Recover keys).

## 13. Not confirmed for Forever (check in fight logs before shipping)
1. Does `/cancelform` leave the press free, so the heal on the next line still casts? This matters for druid forms and priest Shadowform.
2. Does an off-GCD cast (Nature's Swiftness, Inner Focus, Divine Favor, Bloodrage) end the press? Each design here works either way. If it doesn't end the press, the combo takes one press instead of two.
3. Does `/use` of a potion or mana gem on cooldown fall through like a spell on cooldown?
4. Does `!Shoot` sent again restart the wand swing, as `!Auto Shot` did?
5. Cooldowns not published on Forever: Penance, Prayer of Mending, Arcane Wrath, Holy Strike, Shank, Mortal Strike, Bloodthirst, Whirlwind.
6. Cast times not published on Forever: Heal, Lesser Heal and Smite ranks, Starfire, Shadow Bolt and Frostbolt ranks (CL used).
7. Do the shocks share a cooldown?
8. Form slot numbers for Moonkin, Cat and Bear with every form learned (Outrider reads them from the stance bar).
9. Tiger's Fury: exists or not (Kami Labs says yes; the live spellbook data says no).
10. Does a castsequence advance when a cast is interrupted?
11. Item names for mana gems and potions on Forever.
12. Does Judgement of Command overwrite your own Judgement of Wisdom debuff?
13. Repo items to fix, found during this research:
    - Lava Burst lines in `Data/FightPlans.lua`;
    - Binding Heal in the priest `learn` table;
    - Crusader Strike in `Modules/ClassFight.lua` (harmless);
    - every remaining `,null` line in `ClassFight.lua` (warrior Battle Shout and Rend, shaman Searing Totem and Flame Shock, paladin seal fallback at line 262, the hunter castsequence).

## 14. Sources
- foreverchanges.pro: [druid](https://foreverchanges.pro/spellbook/druid), [priest](https://foreverchanges.pro/spellbook/priest), [paladin](https://foreverchanges.pro/spellbook/paladin), [shaman](https://foreverchanges.pro/spellbook/shaman), [mage](https://foreverchanges.pro/spellbook/mage), [warlock](https://foreverchanges.pro/spellbook/warlock), [warrior](https://foreverchanges.pro/spellbook/warrior), [rogue](https://foreverchanges.pro/spellbook/rogue), [hunter](https://foreverchanges.pro/spellbook/hunter) spellbooks; talents for [shaman](https://foreverchanges.pro/talents/shaman), [priest](https://foreverchanges.pro/talents/priest), [druid](https://foreverchanges.pro/talents/druid), [paladin](https://foreverchanges.pro/talents/paladin), [mage](https://foreverchanges.pro/talents/mage), [warlock](https://foreverchanges.pro/talents/warlock), [hunter](https://foreverchanges.pro/talents/hunter); [patch notes](https://foreverchanges.pro/patch-notes).
- Wowhead Forever spell pages: [Swiftmend 18562](https://www.wowhead.com/forever/spell=18562/swiftmend), [Rejuvenation 774](https://www.wowhead.com/forever/spell=774/rejuvenation), [Regrowth 8936](https://www.wowhead.com/forever/spell=8936/regrowth), [Healing Touch 5185](https://www.wowhead.com/forever/spell=5185/healing-touch) and [25297](https://www.wowhead.com/forever/spell=25297), [Innervate 29166](https://www.wowhead.com/forever/spell=29166/innervate), [Nature's Swiftness 17116](https://www.wowhead.com/forever/spell=17116/natures-swiftness) and [16188](https://www.wowhead.com/forever/spell=16188), [SW:P 589](https://www.wowhead.com/forever/spell=589/shadow-word-pain), [Renew 139](https://www.wowhead.com/forever/spell=139/renew), [PW:S 17](https://www.wowhead.com/forever/spell=17/power-word-shield), [Mind Blast 8092](https://www.wowhead.com/forever/spell=8092/mind-blast), [Devouring Plague 2944](https://www.wowhead.com/forever/spell=2944), [Inner Focus 14751](https://www.wowhead.com/forever/spell=14751), [Greater Heal 25314](https://www.wowhead.com/forever/spell=25314), [Flash Heal 2061](https://www.wowhead.com/forever/spell=2061), [Holy Shock 20473](https://www.wowhead.com/forever/spell=20473/holy-shock), [Judgement 20271](https://www.wowhead.com/forever/spell=20271/judgement), [Lay on Hands 633](https://www.wowhead.com/forever/spell=633/lay-on-hands), [Divine Favor 20216](https://www.wowhead.com/forever/spell=20216), [Holy Light 25292](https://www.wowhead.com/forever/spell=25292), [Flash of Light 19750](https://www.wowhead.com/forever/spell=19750), [Healing Wave 331](https://www.wowhead.com/forever/spell=331) and [25357](https://www.wowhead.com/forever/spell=25357), [Lesser Healing Wave 8004](https://www.wowhead.com/forever/spell=8004), [Chain Heal 1064](https://www.wowhead.com/forever/spell=1064), [Flame Shock 8050](https://www.wowhead.com/forever/spell=8050/flame-shock), [Earth Shock 8042](https://www.wowhead.com/forever/spell=8042), [Evocation 12051](https://www.wowhead.com/forever/spell=12051/evocation), [Corruption 172](https://www.wowhead.com/forever/spell=172/corruption), [Bane of Agony 980](https://www.wowhead.com/forever/spell=980), [Immolate 348](https://www.wowhead.com/forever/spell=348/immolate), [Siphon Life 18265](https://www.wowhead.com/forever/spell=18265), [Conflagrate 17962](https://www.wowhead.com/forever/spell=17962), [Moonfire 8921](https://www.wowhead.com/forever/spell=8921/moonfire), [Serpent Sting 1978](https://www.wowhead.com/forever/spell=1978/serpent-sting), [Rend 772](https://www.wowhead.com/forever/spell=772/rend), [Life Tap 1454](https://www.wowhead.com/forever/spell=1454/life-tap). New Forever spells (Penance, Riptide, Wild Growth and others) use new IDs, and the Classic and Wrath IDs return 404.
- Warcraft Tavern Forever: [restoration druid](https://www.warcrafttavern.com/forever/guides/restoration-druid/), [holy paladin](https://www.warcrafttavern.com/forever/guides/holy-paladin/), [restoration shaman](https://www.warcrafttavern.com/forever/guides/restoration-shaman/), [holy priest](https://www.warcrafttavern.com/forever/guides/holy-priest/), [discipline priest](https://www.warcrafttavern.com/forever/guides/discipline-priest/), levelling guides for [mage](https://www.warcrafttavern.com/forever/guides/mage-leveling/), [warlock](https://www.warcrafttavern.com/forever/guides/warlock-leveling/), [priest](https://www.warcrafttavern.com/forever/guides/priest-leveling/), [paladin](https://www.warcrafttavern.com/forever/guides/paladin-leveling/), [shaman](https://www.warcrafttavern.com/forever/guides/shaman-leveling/), [druid](https://www.warcrafttavern.com/forever/guides/druid-leveling/).
- Others:
  - [wowtbc.gg resto druid](https://wowtbc.gg/warcraftforever/class-guides/restoration-druid/) and [holy paladin](https://wowtbc.gg/warcraftforever/class-guides/holy-paladin/);
  - [Blazingboost holy paladin](https://blazingboost.com/wow-forever-classic/wow-forever-holy-paladin-guide);
  - Kami Labs: [druid changes](https://kami-labs.fr/en/wow-forever/druide-wow-forever-sorts-et-talents-modifies/), [paladin changes](https://kami-labs.fr/en/wow-forever/paladin-wow-forever-sorts-et-talents-modifies/), [resto druid](https://kami-labs.fr/en/wow-forever/build-druide-restauration-wow-forever/) and [resto shaman](https://kami-labs.fr/en/wow-forever/build-chaman-restauration-wow-forever/) builds;
  - [Rankedboost resto druid macros](https://rankedboost.com/world-of-warcraft/forever/macros/druid/restoration/).
- Not reachable:
  - Icy Veins Forever pages (403; search snippets only);
  - Wowhead Forever guide bodies (loaded by script);
  - forever.warcraftdb.com spell pages (no URL pattern found).

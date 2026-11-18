# Outrider deep gap analysis (2026-11-18, Claude)

Gary asked for a comprehensive gap analysis and brainstorm to make Outrider "the one addon to rule them all". GPT wrote one in parallel: `docs/COMPETITIVE_PARITY_ROADMAP_2026-11-18.md`. This file:
- adds the details GPT missed;
- corrects a few claims;
- merges both into one ranked build list.

**How this was done.** Yesterday's analysis (`docs/ADDON_GAP_ANALYSIS.md`) compared headlines, and Questie later showed that a "✅" can hide four or five missing sub-features. So this round went **option by option**:
- 40 addons, in four parallel research passes.
- Each feature was checked against Outrider's real code (grep and reading the module), not against the docs.
- Feature lists come from the CurseForge pages, GitHub and wikis, plus the Forever-only addons on the CurseForge front page (Polestar, Forever Route, ThreatTint, Deathskip, TurnInXP, Rucksack, DaylightUI, Social Diary, MouseOverTooltip).

**Key:**
- **HAS**: Outrider has it.
- **PART**: Outrider has some of it; the row says what's missing.
- **MISS**: missing.
- **CAN'T**: breaks hard rule 1 (it would act for the player) or rule 4 (it needs the combat log).
- **PROBE**: may be blocked by Midnight's secret values, so it needs an in-game probe first.

---

## 1. The short version

1. **Outrider's coverage is wide but often shallow.** It beats the specialist addons in a few places:
   - "picked recently" node state (better than GatherMate2);
   - rare telemetry across layers;
   - tame macros;
   - party quest progress counts.

   In most areas it has the first 60% of a feature and is missing the parts players use every day.
2. **Five big gaps** (each is a whole product somewhere else):
   1. **Levelling route.** Polestar, Forever Route and RestedXP guide you step by step from 1 to 60. Outrider suggests 3 to 5 things.
   2. **Bag window.** Bagnon, Baganator, Rucksack and DaylightUI all have one window with categories. Outrider decorates Blizzard's bags.
   3. **Dungeon journal.** DungeonJournal and AtlasLoot show dungeon quests, full loot tables and bosses. Outrider shows only *your* upgrades.
   4. **Combat-adjacent tools that are still allowed.** Auto Shot timer, threat colours (ThreatTint already ships on Forever), and the post-fight damage meter (`C_DamageMeter`).
   5. **The graveyard map.** On Forever the subzone decides where you respawn, and Outrider's "nearest spirit healer" is wrong about 1 time in 5 (Deathskip measured it on 5,671 deaths).
3. **About 25 cheap gaps**, each a day or less, usually on data Outrider already stores. Examples:
   - XP per hour and time to level;
   - "ready now" quest XP;
   - layer on the info bar;
   - corpse arrow;
   - sell lists beyond greys;
   - a restock button;
   - waypoint queue;
   - cursor coordinates;
   - hide tooltips in combat;
   - whisper history.

   This is where "one addon to rule them all" is won fastest.
4. **Outrider's real edge is that it knows everything at once.** No other addon can say "the rare you need is up on your layer, it drops an upgrade, the route takes 4 minutes, and your pet can tank it". The brainstorm (section 6) leans on that.

---

## 2. Notes on GPT's roadmap

GPT's roadmap is good on process: verification gates, evidence, "parity per module, not a made-up percent". Keep its IDs (Q01, D01, …) as the task keys. Where the two analyses differ:

| GPT says | Reality (checked in code) |
|---|---|
| X04: no static gate for syntax, TOC, combat-log registration | **Mostly exists.** `tools/test.ps1` checks syntax, globals, the TOC and Blizzard overwrites, and `tests/spec/core_spec.lua` fails on COMBAT_LOG registration. Missing: running it on GitHub at each push (no `.github/`). |
| R03/R01 frame rares as unproven | Detection works: nameplate, target, mouseover, vignette and macro scan are all live (Gary's Mystmane sessions). The real gaps are loot, models and routes. |
| H05: pet happiness "no unsupported loyalty promises" | Right, and sharper: `GetPetHappiness` **doesn't exist on Forever** (PROBE_RESULTS). PetStatus logs auras to find another source. Until then this stays a probe task. |
| C03/C06: combat meter drilldowns, cooldown viewer | Possible only out of combat, with `C_DamageMeter` sessions. Don't promise live numbers. |
| D03/D04/D09: boss mechanics and timelines | Low value for a levelling hunter and the riskiest data job. Last tier. |
| Q03: tracker has a 45-row cap | Confirmed (`QuestTracker.lua:24`). Easy fix: scroll. |
| HE01: heal panel 10 bars | Confirmed (`HealPanel.lua:34`). |
| A02: no median price | Confirmed: Prices keeps the lowest price per day only. |

**What GPT missed** (found in this pass):
- Auto Shot timer, aspect warning, Growl-in-group warning (hunter).
- Threat colours on nameplates, with your pet's threat.
- Graveyard by subzone and the corpse arrow.
- XP per hour, time to level, and "ready now" quest XP.
- Restock button, sell lists, keep-free-slots.
- Waypoint queue and `/way <zone>`.
- Layer always on screen, visited layers, the world-refresh countdown.
- Whisper history, class-coloured chat names, longer chat history.
- Tooltip hidden in combat, quest "X left" on mob tooltips.
- Darkmoon Faire dates, fishing skill per zone, list of undiscovered areas.
- Settings search box.

**One correction to my own researchers:** one report said map pins show "one pin per rare". That was fixed on 2026-11-17 (every pack spawn spot now shows).

---

## 3. The merged build list

Ranked by daily payoff for Gary (Horde hunter, levelling) per hour of work. GPT IDs are in brackets where they match; **NEW** means GPT doesn't have it.

### Tier 1: cheap, daily, data already there (a day or less each)
| # | Feature | Borrowed from | Notes |
|---|---|---|---|
| 1 | **XP pace**: XP/hour, time to level, session XP; "ready now" quest XP vs whole log, with the level you'd land at and a per-quest list | TurnInXP, Titan, RestedXP | NEW. QuestExtras already sums log XP |
| 2 | **Layer on the info bar**, visited layers with "seen 12 min ago" | NWB, Layer-Swap | NEW. Layers.lua has it; just show it |
| 3 | **Corpse arrow** after release (GetCorpseMapPosition) | TomTom | NEW. Today it points at a spirit healer |
| 4 | **Sell lists**: "always sell" and "sell once", learned from what you sell; the Merchant button sells them. Never-sell protection for quest items | Rucksack, Scrap | NEW. One click, your click |
| 5 | **Restock button** at the vendor: buy ammo, food and water up to set amounts, with a gold reserve | Rucksack, TSM | NEW. One click per purchase batch, Gary presses it |
| 6 | **Waypoint queue**: several waypoints, auto-advance on arrival, kept across sessions, `/ride way <zone> x y` | TomTom | NEW. Rare routes need this |
| 7 | **Cursor coordinates** on the world map | Leatrix Maps, TomTom | NEW |
| 8 | **Tooltip**: hide in combat (Shift shows it); quest "4 left" on mob tooltips | MouseOverTooltip | NEW |
| 9 | **Hunter: aspect warning** (no aspect, or Cheetah/Pack in combat) and **Growl left on in a group** | ZHunterMod, Quiver | NEW |
| 10 | **Tracker scroll** past 45 rows; "focus this quest" dims other pins | Questie | [Q03] |
| 11 | **Chat**: whisper history per person, longer history after reload (50 → 500+), class-coloured names | WIM, Prat, Chattynator | [UI03] |
| 12 | **Lockout fixes**: timer starts on leaving, instance ID, delete a wrong entry, lockouts on minimap button hover | Nova Instance Tracker | [D07] |
| 13 | **Map extras**: list and count of undiscovered areas; fishing skill per zone; Darkmoon Faire location and next dates | Leatrix Maps, NWB | NEW |
| 14 | **Mailbox**: open filters (AH sold/won/expired only), keep N slots free, Shift-click take | Postal | [B05] |
| 15 | **Settings search box** | Leatrix Plus | [UI01] |

### Tier 2: real features, a few days each
| # | Feature | Borrowed from | Notes |
|---|---|---|---|
| 16 | **Auto Shot timer**: "stop moving" mark and dead-zone/range marker on Blizzard's own ranged swing bar (Forever has it, PROBE_RESULTS:113) | Quiver, Improved Auto Shot Timer, DaylightUI | NEW. PROBE `UnitRangedDamage` and `C_Spell.IsSpellInRange` in combat |
| 17 | **Threat colours on nameplates** with pet threat (blue), plus a small threat list | ThreatTint, ThreatClassic2 | NEW. PROBE `UnitDetailedThreatSituation` on nameplates in combat. ThreatTint working on Forever is a good sign |
| 18 | **Graveyard map**: "you'd respawn at X" box, map hover, and death logging (predicted vs actual) so it learns. Subzone from the game's own data | Deathskip | NEW. High value on Forever |
| 19 | **Dungeon quests**: per dungeon, givers, chains, rewards, map spot; live progress inside | DungeonJournal, Polestar, Forever Route | [D01 part]. QuestieDB already has the data |
| 20 | **Level-up training card** without a trainer visit: spells and cost per level | What's Training, Polestar | [P01 part]. Needs a cited spell/rank/cost pack (rule 7) |
| 21 | **Rare route**: through all, or only watched, rares on the map, as a waypoint queue | RareScanner | [R02]. Needs #6 |
| 22 | **Where to? zones**: XP left per zone, the level you'd reach, chains about to go grey, abandon list (quests that never pay off) | Forever Route, Polestar | [Q02 part] |
| 23 | **Gear wishlist**: Alt+click to save, owned marker, tooltip tag; full loot table of any boss | AtlasLoot | [D02, G04] |
| 24 | **Map notes you write** (click to add, edit, minimap) | HandyNotes | [M02] |
| 25 | **Post-fight meter** from `C_DamageMeter` (out of combat, Blizzard's numbers) | Details | [D05, C03]. PROBE the session shape |
| 26 | **Food rules**: use-first and never lists, Well Fed reminder, delete-old-food button | Rucksack | NEW |
| 27 | **Stat weight editor**, spec scales, Pawn string import | Pawn | [G03]. Storage already exists |
| 28 | **Auction selling**: bag list on the selling side, one-click cancel per undercut, sales/expired ledger | Auctionator, Journalator | [A01, A03, A06] |
| 29 | **Recipe sources**: unlearned recipes with trainer/vendor/drop/quest and colour thresholds | What's Training, SkillUp | [P01, P05]. Needs a cited data pack |
| 30 | **Alt detail**: reputations per alt, "known by alt" on recipe tooltips, browse alt bags | Altoholic | [AL01] |
| 31 | **Equipment set window** with icons and a missing-item report | ItemRack | [G02] |
| 32 | **Rare toast**: 3D model (PlayerModel, fails soft to an icon); loot list once a cited drop source exists | RareScanner | [R01, R04] |

### Tier 3: big builds (a week or more)
| # | Feature | Borrowed from | Notes |
|---|---|---|---|
| 33 | **Levelling route engine**: our own step format; steps tick off from quest, kill, loot and place events; skip with undo; starts at any level. First pack: Horde 1–20 in our zones | Polestar, Forever Route, Guidelime | [Q04, Q05]. Write our own routes; don't copy paid guides |
| 34 | **Bag window** with categories, bank, alts, a search that lights up slots, and BoE marks. Yields to Bagnon/Baganator | Baganator, Bagnon, Rucksack | [B01, B02] |
| 35 | **Dungeon journal**: bosses, loot, quests, map, readiness | DungeonJournal, AtlasLoot | [D01, D02] |
| 36 | **Heal panel for 40**, click-binding editor, Ctrl/Alt modifiers | VuhDo, HealBot | [HE01, HE02]. For Gary's priest |
| 37 | **Auction engine**: median and volatility, shopping lists, groups | TSM, Auctionator | [A02, A04] |
| 38 | **Boss notes and timelines** (C_EncounterTimeline) | DBM, BigWigs | [D03, D04]. Probe first; last |

---

## 4. Gaps by area (details behind the list)

### Questing and levelling
- **Polestar / Forever Route / RestedXP:**
  - **The route:**
    - MISS: step route; auto-ticking steps; skip/undo; step browser; class quest side trips.
    - MISS: "loads at any level and skips done quests".
  - **Questing aids:**
    - MISS: dungeon quests button; quest-item glow; timed-quest countdown; targeting key for the step's NPC.
    - PART: level-up card (only after a trainer visit).
  - **Travel and pace:**
    - PART: arrow (straight line, Travel plans legs); boat waits.
    - MISS: XP per hour.
  - **CAN'T:** auto-accept, auto-train, auto-fly.
- **TurnInXP:**
  - HAS: whole-log XP.
  - MISS: "ready now" XP, projected level, per-quest hover list.
- **Questie leftovers:**
  - Tracker past 45 rows; focus quest; quests-by-zone browser [Q02].

### Bags, vendor, mail
- **Bagnon / Baganator / Rucksack:**
  - **The window:** MISS: combined window, categories, bank in the window, BoE and new-item marks, sorting, transfer-matching-items-to-bank/mail buttons.
  - **Search:** MISS: search keywords (type, slot, BoE, &|!) and highlighting matching slots.
  - **Bag management:**
    - MISS: keep-N-free, special-bag colours, quest marks on quest items, "delete cheapest junk" button.
    - PART: alt bags (data, no view).
- **Vendor:**
  - MISS: sell lists, restock button, "why wasn't it sold".
  - **CAN'T:** sell or buy on opening the vendor (a button is fine).
- **Postal:**
  - MISS: open filters, keep free slots, select-and-return, Shift/Ctrl-click, QuickAttach, autocomplete, forward.
  - **CAN'T:** unattended open-all (we do one click per mail).

### Maps, travel, waypoints, graveyards
- **TomTom:**
  - MISS: waypoint queue, `/way <zone>`, persistence, arrival sound, corpse arrow, cursor coordinates, ETA.
  - HAS: /way, clear on arrival, TomTom hand-off.
- **Leatrix Maps:**
  - MISS: undiscovered list, fishing skill per zone, zone jump menus, centre on player, remember zoom, bigger player arrow, dungeon interior maps.
  - HAS: reveal, entrances, levels.
- **Deathskip:**
  - PART: graveyard (nearest by distance, often wrong).
  - MISS: respawn box, map hover, borders, death logging.
- **HandyNotes:** MISS: notes of your own.
- **GatherMate2:**
  - MISS: filter by node type (only Copper), delete a node, icon size, minimap edge icons, chests and treasures.
  - HAS, better than GM2: picked-recently state.

### Rares and layers
- **RareScanner:**
  - MISS: 3D model, loot list and filters, item → rare explorer, rare route, treasures and containers, per-rare hide, stacked list when several rares are up, nameplate range hint.
  - PART: sound picker.
- **NWB / Layer-Swap:**
  - MISS: layer always on screen, visited layers with ages, world-refresh countdown, ask guild for a layer, world buff timers (low until 60), DMF dates.
  - **CAN'T:** CVar flipping to read layers, auto-invite and auto-leave.

### Combat-adjacent and hunter (only what Midnight allows)
- **ThreatTint / ThreatClassic2:**
  - MISS: threat colours, pet threat, threat %, threat list, warning at status 2–3.
  - PROBE: whether the threat values are secret.
- **Quiver / Auto Shot timers:** MISS: Auto Shot "stop moving" mark, dead-zone/range marker.
- **Other hunter tools:**
  - MISS: aspect warning, Growl-in-group warning, Feign Death + trap macro, Tranq Shot announce (opt-in, level 60).
  - PROBE: pet happiness has no API; aura hunt in progress.
- **Plater:**
  - HAS: quest and rare marks.
  - MISS: colour or icon per NPC ID (dangerous mobs), target highlight.
  - PROBE: health % text (`UnitHealthPercent`).
  - **CAN'T:** execute colour (compares secret health), scripting engine.
- **OmniCC / Bartender:**
  - PROBE: out-of-range tint (`C_Spell.IsSpellInRange`).
  - **CAN'T:** cooldown colours by time left (secret).
- **Details / DBM:**
  - **CAN'T:** live meters and timers.
  - PROBE: post-fight `C_DamageMeter`, `C_EncounterTimeline`.

### Tooltips, chat, social
- **MouseOverTooltip / TipTac:** MISS: hide in combat, quest "X left", "targeted by" party, mount, item/spell/NPC IDs, guild rank, reaction colour.
- **Prat / WIM / Chattynator:**
  - MISS: class colours, short channel names, alt-click invite in chat, chat search, whisper windows and history, new-whisper alert, editbox history.
  - PART: history (50 lines).
- **Social Diary:**
  - HAS: last seen, duels, trail.
  - MISS: a page per player (grouped, dungeons, trades), your notes per player, a "friend/foe in view" toast.
  - **CAN'T:** "who killed you" (combat log).

### Economy, gear, professions, alts
- **Auctionator:**
  - MISS: custom shopping lists, search filters and history, bag list for selling, one-click cancel, price history view, sales/expired ledger.
  - **CAN'T:** auto-scan on open.
- **TSM:**
  - MISS: groups and operations, cost-to-make in tooltips, mail ops, gold graph, accounting, destroying list.
  - PART: vendor restock.
- **Pawn:**
  - MISS: spec scales, weight editor UI, scale strings, side-by-side compare, several scales at once.
- **AtlasLoot:** MISS: full loot tables, wishlist, reputation rewards, sets, crafting tables.
- **What's Training / SkillUp:**
  - MISS: class spells without a visit, spellbook view, recipe sources, colour thresholds, unlearned recipes in the route.
- **Altoholic:**
  - MISS: reputations per alt, known-by-alt recipe tags, quest log per alt, talents per alt, alt groups.
  - PART: alt bags and gear (stored, no view).

### Interface (Leatrix Plus, Titan, DaylightUI)
- **Leatrix Plus:**
  - Cheap game-setting switches, all MISS:
    - faster auto loot;
    - mute chosen sounds;
    - larger quest/mail/book text;
    - wider quest log;
    - bigger trainer window with a Train-all button (one click);
    - durability on the character frame;
    - screen glow off;
    - skip movies;
    - easy item destroy;
    - hide event toasts and the boss banner.
  - One-click "decline" toast for duels and invites from strangers. A safe version of Leatrix's auto-block.
- **Titan Panel:**
  - MISS: XP/hour, zone + coordinates on the bar, repair cost, a second bar, DataBroker (LDB) feeds so other addons can show on our bar.
- **DaylightUI:**
  - MISS: cast bars, buffs grouped by dispel type, soft AFK screen.
  - PART: unit frames (look only, on purpose).

---

## 5. What stays out (and the one-click version we offer instead)

| They do | Why we don't | Ours instead |
|---|---|---|
| Auto accept/turn in quests, auto pick reward (Questie, Leatrix, Polestar) | Rule 1 | Best-reward hint (have it) |
| Sell/repair/buy when the vendor opens (Leatrix, Rucksack) | Rule 1 | Sell, repair and Restock buttons |
| Unattended open-all mail (Postal) | Rule 1 | One click per mail with totals (have it) |
| Auto-confirm loot, auto-open clams, auto-delete junk (Leatrix, Rucksack) | Rule 1 | "Open next", "delete cheapest junk" buttons |
| Auto-train, auto-fly (Polestar, RestedXP) | Rule 1 | Train-all button on the trainer, a flight hint |
| CVar flipping to read layers, auto-invite/leave (Layer-Swap) | Rule 1 | Passive layer reading (have it), an Invite button |
| Live meters, boss timers, "who killed you", Spy (Details, DBM, Social Diary) | Rule 4, secrets | Post-fight `C_DamageMeter`, if the probe passes |
| Cooldown colours, execute range, threat-pull prediction maths | Secret values | Display only |

---

## 6. Brainstorm: things no single addon can do

Outrider knows rares, quests, gear, prices, professions, alts, layers, the party and your pet all at once. Single-purpose addons can't combine them. Ideas, roughly by how much they'd wow Gary:

1. **"Switch to Outrider" importer.** On first run, read the SavedVariables that Questie, TomTom, GatherMate2, Auctionator and RareScanner left behind (read-only, on Gary's PC; it can't read other addons' saved data in game unless they're loaded, so do it in the desktop tools). Bring over waypoints, nodes, price history and rare sightings.
   - Then show a **"you can turn these off" report**: which installed addons Outrider now covers, and how much memory they use.
   - This is the most direct way to *become* the one addon.
2. **"This trip" planner.** "I have 40 minutes." Outrider picks:
   - quests to turn in;
   - a rare that's due on your layer;
   - nodes on the way;
   - the vendor to restock at;
   - the flight home.

   It's one waypoint queue with a reason on every step. This is GPT's X01, made concrete with the parts above.
3. **Rare + pet + gear in one card.** When a watched rare is due:
   - spawn odds on your layer;
   - route time;
   - drop value for you (upgrade, or auction price);
   - fight odds with your current pet;
   - whether it's tameable and which skill it teaches.
4. **Group brain.** Party members running Outrider share:
   - quests (have it);
   - who still needs which objective, so kills get split;
   - who can craft what;
   - who's on which layer;
   - a "spawn camp rota" like Gary's Mystmane group used.
5. **Session recap at logout.** One card when you log out:
   - XP, gold, rares, loot, deaths, best moment;
   - "next time: hand in 3 quests in Thunder Bluff".

   Written to the snapshot, so the Advisor can comment on the week.
6. **Death coach (no combat log).** Out of combat after a death, read `C_DamageMeter` for the fight, plus level, mob, health and pet state, and say why you died: "pulled 3 at level -2, pet was dead".
7. **Price watch with a route.** "Linen sells for 2× vendor now. The nearest humanoids that drop it are 3 minutes away."
8. **Forever change log.** Every time Outrider sees something that differs from the Classic data (a moved NPC, a new quest, a redrawn zone), it collects it. With Gary's OK, the family/guild shares it. Outrider's data gets better than Questie's on Forever.
9. **Accessibility and comfort presets** (GPT X10): "solo leveller", "hunter", "healer", "trader", "gatherer". One click turns on the right modules and bars.
10. **Performance budget page.** Memory and CPU per module, with a "turn off what you don't use" button. Proves "one addon" is lighter than twenty.

---

## 7. Suggested order

1. **Tier 1 items 1–9** as one batch: two or three sessions, one combined in-game check.
2. **Probe batch** for #16, #17, #25 and pet happiness: one deploy, then Gary fights a few mobs normally. Results decide Tier 2's combat items.
3. **Graveyard map (#18)** and **waypoint queue → rare route (#6, #21)**.
4. **Dungeon quests (#19)** and **XP "where to?" (#22)**: both from QuestieDB, which we already import.
5. **Then one Tier 3 build at a time.** The levelling route first, because it's the biggest thing players install another addon for.

Sources: the CurseForge project pages for every addon named above (Polestar, Forever Route, RestedXP, TurnInXP, ThreatTint, Deathskip, Rucksack Forever, DaylightUI, Social Diary, MouseOverTooltip, Chattynator, Quiver, Improved Auto Shot Timer, Questie, RareScanner, Auctionator, Pawn, AtlasLoot Classic, Altoholic, DungeonJournal, What's Training, SkillUp Forever, Leatrix Plus, Leatrix Maps, Bagnon, Baganator, Postal, Titan Panel, Nova World Buffs, Nova Instance Tracker, Layer-Swap), plus GitHub READMEs where the pages were thin. Outrider statuses were checked against `addon/Outrider/Modules/*.lua` on 2026-11-18 at commit a13314b.

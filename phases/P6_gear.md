# Phase 6: Gear advisor

**Goal:** each character gets told, quietly, when an upgrade is close: in bags, in quest rewards, on a nearby vendor, from a rare in this zone, in a dungeon at their level, on the AH, or sitting on an alt. Scoring is per character, per spec, solo or group.

**Gate G6:** on Torrant and on the priest, the tooltip verdict agrees with Gary's own judgment on 10 test items each; quest reward highlight picks the item Gary would pick (or the best vendor value when nothing is usable); the Nearby list shows at least five sensible upgrades in the current zone with where to get them; no toast in combat or instances.

Build order follows the blueprint: "what's in front of you" first (works on day one with no database), then sources that ride on data other modules already collect. If GearQuest Forever exposes its data to other addons, read it; if not, grow our own sources.

Modules: `GearScore`, `GearTooltip`, `QuestRewards`, `UpgradeFinder`, `AltHandoff`, `GearSets`.

---

### P6-01 · Stat weights · Claude · deps: none
1. `Data/StatWeights.lua`: per class and spec, solo and group, weights for primary stats, attack power, spell power/healing, hit, crit, armor, weapon DPS and speed (hunter ranged), from cited sources; marked as starting points.
2. Spec detection from talent points (Classic talent API per probe); Gary can override and edit weights in the hub.
3. Specs: weights load for every class; detection picks the tree with most points.

**Done when:** `/oar weights` prints Torrant's detected spec and weights.

### P6-02 · Item scoring · Claude · deps: P6-01
1. `Score(itemLink, char)`: stats from `C_Item.GetItemStats`/`GetItemStats`, plus tooltip parsing (via `C_TooltipInfo` if present) for stats the API misses ("Equip: Increases attack power by 24").
2. Compare with what is equipped in that slot: 2H vs 1H+off-hand, two rings and two trinkets (compare against the weaker), ranged slot for hunters (weapon DPS weighs heavily), wands, relics/idols/totems if present.
3. Usable checks: armor type and weapon skills the class can use, required level ("usable in 2 levels" tag), class restrictions, faction.
4. Specs with fixture items covering each slot rule.

**Done when:** specs pass; `/oar score` on a linked item prints the verdict and the stat diff.

### P6-03 · Tooltip verdict · Claude · deps: P6-02
1. One line on item tooltips: "+12% upgrade for Torrant (Marksmanship, solo)" in green, "downgrade" in muted, "usable at 26" in amber. Shift shows the stat diff.
2. Also show the verdict for your other characters on account-bound or BoE items ("Lumen: +8%").

**Done when:** screenshot of three tooltips (upgrade, downgrade, future).

### P6-04 · Bags and quest rewards · Claude · deps: P6-02
1. Bag scan on `BAG_UPDATE_DELAYED`: upgrades in bags get a small corner arrow (on Blizzard bag buttons; skip if a bag addon is loaded and say so) and a hub notice.
2. On `QUEST_COMPLETE` / `QUEST_DETAIL` with reward choices: highlight the best choice for this character; if none is usable or an upgrade, highlight the highest vendor value. Choosing stays Gary's click.

**Done when:** Gary turns in a quest with choices and the highlight matches his choice.

### P6-05 · Upgrade sources pack · Claude · deps: P3-06
1. Separate load-on-demand addon `addon/OAR_Data_Gear/` (TOC with `## LoadOnDemand: 1`, `## Dependencies: OAR`) with `gear` entries: quest rewards, vendor items, rare drops, dungeon drops for levels 1 to 60, from cited sources, faction-tagged, `verified = false`.
2. Fill vendor entries from merchant lists Gary actually opened (P5-09 records them).
3. Tests: the data addon validates; deploy.ps1 and package.ps1 handle a second addon folder (extend them).

**Done when:** pack loads on demand the first time the Nearby panel opens; memory before/after logged.

### P6-06 · Nearby upgrades · Claude · deps: P6-02, P6-05, P2-07, P3-01
1. Rank upgrade candidates for the current character by score gain, then by effort: same zone and level-appropriate quest rewards (with Questie bridge if present), vendors in the current town, rares in the zone (with their respawn window), dungeons at the character's level (entrance distance), AH listings within a budget (from P5 price data), crafters (own alts' recipes), alts' BoE items.
2. Hub tab **Gear**: list with gain, source, where, and buttons **Waypoint**, **Track** (pins it on the map), **Search AH** (opens the AH search for the item when at the AH).
3. Quiet alerts: one toast when a new candidate clears Gary's threshold, never in combat or instances, never twice for the same item.

**Done when:** Nearby shows at least five sensible entries in Gary's current zone; one toast fired and not repeated.

### P6-07 · GearQuest bridge · Claude · deps: P6-06
1. If GearQuest Forever is installed, read Gary's addons folder to see whether it exposes a public API or global data table. If it does, module `GearQuestBridge` reads its picks as an extra source (pcall, read-only). If it doesn't, record that in DECISIONS and skip.

**Done when:** decision recorded; bridge works or is documented as not possible.

### P6-08 · Alt handoffs · Claude · deps: P5-01, P6-02
1. At login, check BoE items in other characters' bags/bank (from Inventory) that this character could use as an upgrade: "Lumen holds a BoE cloak Torrant could wear (+6%)". Once per item.
2. At a mailbox on the holding character, offer to address a mail to the other character (Gary clicks Send).

**Done when:** test with a BoE item on the priest; the hunter gets the notice.

### P6-09 · Gear sets · Claude · deps: P6-02
1. Save and equip named sets (fishing, solo, group) on a click out of combat, using `C_EquipmentSet` if the probe found it, otherwise `EquipItemByName` per slot.

**Done when:** Gary swaps between two sets with one click each.

### P6-10 · Gate G6 · Both · deps: all P6
Run the gate checks; tick G6.

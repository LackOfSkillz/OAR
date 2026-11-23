# Talent builds page: research and design (2026-11-23)

Gary asked for a talent page like Blizzard's window with recommended builds
(max DPS, max HPS, PvP, raid, PvE), tuning, his current build read in, stats
at level ranges, a damage / healing / tank test like Forever Class Lab, and
Outrider analysing builds to recommend the best. This file holds what exists
and the plan. Sources were read 2026-11-23; many pages were second-hand
(JavaScript-only or refusing fetches), so details marked (?) are unconfirmed.

## Facts
- 51 points at 60, one per level from 10; 7 rows per tree, a row every 5
  points; one-point milestones at 11, 16, 21, 31 (Blizzard deep dive,
  worldofwarcraft.blizzard.com/news/24301515). 9 classes, 27 trees, ~467
  talents (gamingcy). Hotfixes have moved talents (Pathfinding, Oct 30).
- Dual spec at 40 (50g); respec at a city trainer, 1g rising to 50g.
- Gary's client: talents come from C_ClassTalents / C_Traits (probe: present);
  GetTalentInfo / GetNumTalentTabs absent. Learning is purchase-then-commit
  with a short cast. Talents.lua now logs the raw API shape once per session.
- Forever Class Lab (manginelli.github.io/forever-class-lab): talent calc +
  hands-on dummy (damage, tank, healing tests), Classic 1.12 combat model,
  data from ForeverChanges (client 1.60.1.70790) and wago.tools spell tables.
  Deliberately shows no DPS/HPS numbers. Source repo not public: ideas only.

## Existing tools (what to borrow)
| Tool | Borrow | Licence |
|---|---|---|
| Talented Forever | read trees live from C_Traits; store talent IDs, not positions | ? |
| Azeroth Forever | "build at level X" slider; share codes with catalog version + checksum, refuse mismatches | ARR (ideas only) |
| TalentPath Forever | tab in Blizzard's window; next talent glows; says why a point isn't allowed; totals (crit, hit...) parsed from talent text with source line | ARR (ideas only) |
| zTalentPlanner | Sync Build from current talents; Compare tab with level slider; talent search; imports Wowhead / Icy Veins / fan-site links | ? |
| Talent Scanner Forever | Core / Recommended / Situational tiers; stat-change panel | ARR |
| Gamingcy / Method / Wowhead guides | build cards (role, split, key talents, why); level-band order; New / Changed / Moved markers | web |
| Spellwise | DPS/HPS and per-mana numbers read from the client's own tooltips | ARR |
| Pawn Forever | stat weights per spec, levelling vs 60 | MIT |
| Hekili Forever | priority lists (rotation) | GPLv3 |
| WoWSims (classic) | sim engine design, per-spec configs | MIT (link back) |
| SimulationCraft / ClassicSim | action lists; "what is a talent worth" | GPL-3 / LGPL |

## Gaps nobody fills (Outrider's edge)
1. Stats for a chosen build at levels 10-60 with the player's real gear.
2. Recommendations scoped to class, race, level and gear (everyone ships static builds).
3. "You are 4 points off Raid BM": the diff from your build, in order.
4. Primary and Secondary planned together, with the respec cost.
5. Healer HPS and mana-efficiency compared between builds.
6. Freshness per build: source, date, verified on Forever.
7. Hunter pet talents in the same planner.
8. One place for build, macros (fight plans), gear advice and stat weights.
9. A plain "why" for each pick, in game.

## Plan (phases)
1. **Builds page** (in game): the three trees drawn from C_Traits like
   Blizzard's window; your current build read in; build cards (Levelling, Max
   DPS, Max HPS for healers, Raid, PvP) with source and date; try points in a
   sandbox with a level slider; diff to your build; next point glows in
   Blizzard's window (Talents.lua does the rings already); share codes with a
   catalog checksum; paste a Wowhead link. Advice only: Blizzard's window and
   Gary's click spend the points.
2. **Build totals and stats by level:** totals parsed from talent text
   (+crit, +hit, +% spell damage...), applied to the character's stats now,
   and projected to 10/20/.../60 from base-stat tables (source to be agreed).
3. **Numbers per build:** a deterministic Lua sim (damage, healing, threat per
   second against a dummy) using Outrider's fight plans as the rotation and the
   client's own tooltip numbers plus cited coefficients; ranks builds and
   recommends the best for the goal picked.
4. **Real dummy test:** fight a training dummy in a capital with the build you
   have; Outrider reads Blizzard's damage meter after the fight and compares
   it with the sim (calibrates phase 3). An interactive practice dummy inside
   the addon like Class Lab's is possible but large; the real dummy is the
   honest version.

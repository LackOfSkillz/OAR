# Decisions

## Made (with reasons)

| # | Decision | Why | Date |
|---|---|---|---|
| D1 | One addon with switchable modules, not a bundle of separate addons | One settings model, one UI, no addon conflicts; modules still off by default where another addon does it better | 2026-11 |
| D2 | Hook Questie, TomTom, Auctionator/TSM, GearQuest instead of copying them | They hold large maintained datasets; copying means maintaining it forever | 2026-11 |
| D3 | Skin Blizzard frames (Phase 7) instead of replacing them; step aside for ElvUI/EllesmereUI | Replacing unit frames and bars is where taint and breakage live | 2026-11 |
| D4 | Account-wide SavedVariables with per-character sections | Cross-character copy, inventory totals, single file for the companion app | 2026-11 |
| D5 | Self-building data (discovery mode) plus small verified packs | Forever redrew zones; old Classic coordinates can't be trusted | 2026-11 |
| D6 | No automation; advice never acts | Blizzard ToS; Gary's account | 2026-11 |
| D7 | AI advisor parked until Phase 9; snapshot and advice loader shipped dormant | Don't hold up the core; make the later step cheap | 2026-11 |
| D8 | Working name OAR, global prefix `OAR_` | Placeholder until Gary picks a name (Q1) | 2026-11 |

## Open questions for Gary

| # | Question | Options | Recommendation | Needed by |
|---|---|---|---|---|
| Q1 | Real addon name | anything; must not collide with an existing CurseForge/Wago addon | Pick before P1 gate; rename is a search/replace of `OAR` (P0-10) | P1 gate |
| Q2 | Personal use or public release | personal / friends via zip / public on CurseForge and Wago | Personal first, decide at the end of P3 | P3 gate |
| Q3 | License | GPLv3 / MIT / all rights reserved | GPLv3 if we ever study or reuse GPL addon code; MIT if everything is original | Before any public release |
| Q4 | Visual direction for Phase 7 | Clean dark (default theme) / Classic gold trimmed / Minimal | Claude makes mockups in P7-01 | P7 |
| Q5 | Guild sharing on by default for guildmates who install it | yes / opt-in | Opt-in per character | P8 |

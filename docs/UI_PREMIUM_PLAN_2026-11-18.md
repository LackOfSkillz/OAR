# Outrider premium UI plan (2026-11-18)

Gary ran `/ride tour` (D19): 35 screenshots, one per page plus the world map and its Pins menu, on Khreos (level 20 hunter, Redridge). Four reviewers went page by page, with Theme.lua, Widgets.lua and Premium.lua open for the tokens and helpers that already exist. Gary's goal: **every page should look high-end and premium.**

The short version: Outrider has a premium *frame* (the hero banners and the dark theme look good) but plain *pages*. Text lists, half-empty panes and raw developer strings sit under a polished header. Most of the fix is shared: six system changes make every page better at once. After that, each page gets its own layout.

---

## 1. Bugs found (fix first)

| # | Sev | Where | Bug | Cause / fix |
|---|---|---|---|---|
| B1 | High | Every page | Sidebar highlight stays on "What now?" whatever page is open | `Hub:ShowTab` (UI/Hub.lua) shows the panel but never updates the sidebar's selected row. The tour, the "All steps" button and any code that opens a page hit it. Update the highlight inside ShowTab |
| B2 | High | Every page | Cards, tiles and text stop at ~560 px; the right ~40% of every page is empty and text wraps early | `UI:CardList` / `UI:StatusTiles` hard-code `SetSize(560, …)` (UI/Premium.lua), and many FontStrings have `SetWidth(560)`. Anchor to both edges of the page instead |
| B3 | High | Tools page error log | `RareProfile.lua:71` indexes a table with a **secret key** in combat (x83, UNIT_SPELLCAST_*) | Breaks hard rule 4. Guard with `issecretvalue` / `C.Readable` before using the unit/GUID as a key |
| B4 | High | Tools page error log | `ADDON_ACTION_BLOCKED` on `Outrider_FishingHUD` Hide/SetHeight/SetWidth (x35) | The HUD is resized or hidden in combat. Route through `Module:Secure` / `ns.Combat:Run` (hard rule 5) |
| B5 | High | HUD | Outrider's quest tracker draws over the game's own objective tracker (doubled, ghosted text); the hub also clips the tracker | Rule 8, one owner per frame. Hide Blizzard's tracker while ours shows (setting exists, default off) or dock ours elsewhere; keep the hub clear of the tracker |
| B6 | High | Dungeons, Gear, Money | Buttons drawn over card titles and tags ("Go to the entrance" over "Next tier", "Set waypoint" over slot tags, "Find Duskwood" over titles) | Fixed-x buttons. Shared row template: the text's right edge anchors to the button's left |
| B7 | High | All commands | List stops at "errands"; no scrollbar; most commands unreachable | Needs a real scroll list |
| B8 | High | Home, Journey | "Best quests for you" lists *A Sealed Crate [60]* three times for a level 20; every Journey result reads "1 min" | Journey's quest/XP ranking: level filter, de-duplicate, real travel distance |
| B9 | High | Crafting | "0c per point", "Route to 53 (about 0c)"; non-recipes in the list (Basic Campfire, Fish Bowl) | Unknown prices shown as zero; filter by real recipes |
| B10 | Med | Rares | "seen 2459 min ago" | One time formatter: "1d 17h ago" |
| B11 | Med | Money, Fishing | Tanaris (225 fishing) and STV suggested to a level 20 with no travel cost; two methods share the same "26s 92c" | Gate by level/skill (or dim with "needs 225 fishing"); flag fallback numbers |
| B12 | Med | Gear, Macros | Raw tokens leak: `profession ?`, `boss_drop`, `PET_FOOD`, `MOUNT`; "+285%" upgrades | One label formatter; unknown = muted "—" with a tooltip; upgrades as stat deltas (+5 Agi), not percentages |
| B13 | Med | Feed | "No hunter aspect active" x3, "Ammo running low" x2; wrong icon on an upgrade | Collapse repeats into one row with "×3" |
| B14 | Med | Modules | "Rares and class tools" group appears twice; names truncated mid-word | Fix grouping; full names in tooltips |
| B15 | Med | Chat, Hunter | Inputs prefilled with real-looking values ("Skyborne", the pet's own name) | Placeholders in muted italic, empty by default |
| B16 | Med | Fishing | "Next point: measured after two skill-ups" while capped at 150/150 | Show the next-rank callout instead |
| B17 | Med | Census vs Players | 1055 players vs "200 players counted"; an Undead Paladin listed although only your faction shows in /who | Label the cap; check the faction filter |
| B18 | Med | Chat frame | 3–4 multi-line "Outrider WARN" paragraphs at login | Hard rule 6: one line, or move to the Feed/Status page |
| B19 | Low | Info bar | "Layer ?", latency 1866 ms in neutral white, "+6% ready" unlabeled, money without coin icons | Muted "Layer —", warn/bad colours, "+6% ready to hand in", coin textures |
| B20 | Low | Map | Hundreds of hollow beige squares, dense trail scribble, pins on zone labels | Distinct glyph per kind, clustering, thinner trail, hide the meaningless squares |

---

## 2. The premium system (six shared changes)

These fix most pages at once. Build them first, in `UI/Theme.lua`, `UI/Widgets.lua` and `UI/Premium.lua`.

### S1. Full-width layout grid
- Every page block anchors LEFT and RIGHT to the page (no fixed 560).
- A 2-column card grid above 900 px of page width, one column below.
- Spacing scale: 4 / 8 / 12 / 16 / 24. Cards get 16 px padding and 12 px gaps.

### S2. Type scale (one hierarchy everywhere)
| Role | Font | Size | Colour token |
|---|---|---|---|
| Page title (hero) | Morpheus | 24 | goldText |
| Card title | Friz Quadrata | 15 | goldText |
| Row title | Friz Quadrata | 13 | text |
| Body | Friz Quadrata | 12 | body |
| Meta, captions | Friz Quadrata | 11 | muted |
| Big numbers (tiles) | Friz Quadrata | 20, tabular | text, or good/warn/bad |

Morpheus only in the page hero. Its lowercase reads poorly at card size.

### S3. Components (most already exist and are unused)
- **Hero strip:** title, one subtitle line, and 3–4 **stat tiles** (`UI:StatusTiles`: icon, big number, caption, optional progress bar).
- **Row template:** icon (28–32 px, quality-colour border), flexible text block, fixed right column for value and action. Text can never run under a button.
- **Table:** sortable headers, 24 px rows, alternating raised/bg stripes, hover highlight, right-aligned numbers.
- **Pill/tag:** status in good/warn/bad/muted; quality and difficulty colours.
- **Toggle switch:** 28×14 track. On = gold fill, knob right. Off = strong outline, muted knob left. Every switch gets a one-line description.
- **Chips with ×** for word lists, watch lists and filters (replaces the paired Add/Remove inputs).
- **Progress bar:** skill, XP, respawn window, sightings.
- **Empty state:** page art, one line, one button. No more empty bordered boxes.
- **Scroll list:** thin gold scrollbar and a bottom fade gradient whenever content is longer than the pane.

### S4. Button rules
- **One gold primary button per card**, the main action. Everything else is a ghost (outlined) button or an icon button.
- Destructive actions (Clear recorded data, Copy settings, Delete) get a bad-coloured outline and a confirm dialog.
- Selected state: hover fill and a 3 px gold left bar (sidebar, lists).

### S5. Formatters (no raw data on screen)
- `FormatAgo` ("1d 17h ago", "1 day" not "1 days").
- `FormatDistance` (yards, or zone and travel time).
- `FormatMoney` with coin textures.
- `Label(token)`: `boss_drop` becomes "Boss drop"; unknown values become "—" with a tooltip.
- Layer names ("Layer 2", not L002).
- Developer detail (build ids, file paths, dates, pipe syntax) moves to tooltips and the Tools page only.

### S6. Window manners
- The hub opens in the space between the pet panel and the quest tracker, never over the action bars. Default height is ~680.
- While the hub is open, the tracker and pet panel dim (or hide) so nothing shows through.
- Login chat: at most one Outrider line (rule 6). The rest goes to the Feed/Status page.

---

## 3. Page by page

Each page's redesign uses the system above. Bug numbers refer to section 1.

**Explore**
- **What now? (Home)**
  - Keep the hero.
  - Next-step card with one gold "Go", plus the XP figure as a big number tile.
  - Nearest services as an icon tile grid.
  - Merge Errands into one list (no duplicates).
  - Session tiles: XP, gold, time.
  - Fixes B8.
- **Help**
  - Search in the hero.
  - A 3-column grid of topic cards: icon, short one-line title, "12 topics" pill, one line of text.
  - The tree only appears inside a topic.
- **Journey**
  - Filter chips with icon and count.
  - Results table: type icon, name coloured by kind, zone, distance in yards.
  - An active-guide bar pinned at the bottom.
  - Fixes B8.
- **Map**
  - Pins grouped into 4 cards (Services, Travel, Gathering, Quests), each with its legend colour and a master switch.
  - Recording stats as tiles.
  - Clear-data button gets a confirm.
- **Waypoints**
  - Hero tile with the current destination and its distance, or "No waypoint".
  - A 5×2 icon tile grid for the nearest services.
  - "Set arrow" is the only gold button.
- **Rares**
  - Card rows: portrait, name, level pill, ALIVE/DEAD/UNKNOWN pill, "seen 1d ago · Layer 2", respawn progress bar, star to watch.
  - A warn banner when the layer is unknown.
  - Fixes B10.
- **Rare alerts**
  - Watch list as chips with ×.
  - Timers as plain status lines.
  - How you're alerted as switches with a "Test alert" button.
- **Dungeons**
  - Ready check as 5 compact status chips.
  - Full-width dungeon cards: art, name, level range, a bar marking your level on the range, up to 3 upgrade icons, and "Go" vertically centred on the right.
  - Fixes B6.
- **Quests**
  - Hero: "16 quests · 5 ready · nearest 120 yd".
  - Table grouped by zone: quest icon, title, level pill coloured by difficulty, objective progress bar, distance, ghost "Go".

**Character**
- **Hunter**
  - Two columns.
  - Fight macros as action-button-style tiles with installed/needs tags.
  - Pet hero card: portrait, level, happiness, XP bar.
  - Taming as 3 numbered steps instead of prose.
- **Gear**
  - Paper-doll column (16 slots with icons, quality borders, click to filter).
  - Upgrade rows on the right: item icon, quality-colour name, stat-delta chips, source icon, zone and distance, level required.
  - Fixes B6 and B12.
- **Gear sets**
  - Set cards with a strip of slot icons, Equip as primary, a trash icon.
  - "Save current gear" inline at the top.
  - Empty state.
- **Professions**
  - Tile per profession: icon, skill bar, next trainer milestone, "+9 from bags".
  - "Make now" icon buttons.
  - Settings as switches.
- **Fishing**
  - Hero: skill bar and the next-rank callout.
  - Zone table: skill-range bar with your skill marked, distance, top catch icon.
  - Fixes B11 and B16.
- **Crafting**
  - Three panes: recipe list (icon, colour by skill-up, filter chips, search), queue with quantity steppers, shopping list (reagent icon, have/need, cost).
  - Fixes B9.
- **Macros**
  - List rows with icon and status tag.
  - Detail pane: header, "unverified" warn tag, the macro in a code panel, numbered line-by-line explanation, Install right under the code.
  - Fixes B12.
- **My characters**
  - Account hero: characters and total gold.
  - One wide row per character: class icon, name in class colour, level, gold, rested bar, durability, bags, profession mini-bars, last seen.
  - Lockouts as two ring tiles (x/5 an hour, x/30 a day).

**Town**
- **Money**
  - Hero tiles: your gold/hr, best method, this session.
  - Ranked rows with a kind icon, one line of text with "More", the rate in a fixed right column, and "Find" never over text.
  - Fixes B6 and B11.
- **Errands**
  - Town checklist rows with icons and done ticks.
  - Each due errand's button says exactly what it does.
  - Empty state.
- **Forecasts**
  - Gold tiles plus a 15-session trend bar list.
  - Rare cards with a "1 / 3 sightings" progress bar and when the forecast unlocks.
- **Feed**
  - Compact rows grouped Today / Earlier, repeats collapsed with ×N, a coloured left strip by kind.
  - Filter chips and a Clear button.
  - Fixes B13.

**Social**
- **Chat**
  - "Chat filters" card with the switches in a grid.
  - Highlight and spell-check words as chips with ×.
  - Recent alerts move to Feed.
  - Fixes B15.
- **Sharing**
  - Privacy banner with a lock: "Nothing is shared until you turn it on."
  - Switches grouped by channel.
  - Family as chips.
  - Tiles: alts known, family, Outrider users.
- **Census**
  - Hero tiles: players, average level, top class, highest level.
  - Level and class bar charts at the top.
  - /who counting as one progress bar and one button.
  - Fixes B17.
- **Players & guilds**
  - Sortable tables (Name, Lvl, Class, Guild, Zone, Seen) with Whisper/Invite on hover.
  - A minimum member count filter for guilds.

**Outrider**
- **Settings**
  - A sub-nav (Look, Info bar, Map, Alerts, Chat).
  - Info bar: live preview strip and a 4×2 chip grid.
  - One "needs reload" warn banner with the Reload button.
  - Gold slider thumb.
- **Modules**
  - Two-column card grid, one card per group with an "n of m on" chip.
  - 36 px rows: icon, name, plain-English status, switch.
  - "Needs attention" rows on top.
  - Fixes B14.
- **Characters**
  - Current-character hero.
  - Character cards with class art and an XP bar.
  - Starter alts collapsed.
  - "Copy settings from…" behind a confirm that lists what changes.
- **Advisor**
  - Three-step stepper: Ask, then Copy snapshot, then Paste advice.
  - Stale snapshot as a warn banner with Refresh.
  - Advice as numbered suggestion cards.
  - Feedback buttons hidden until there's advice.
- **Status**
  - A 3×2 tile grid: settings OK, errors (click to Tools), API coverage bar, modules, layer, build.
  - Health line in plain words.
- **Tools**
  - Cards: Your data, Diagnostics, Interface.
  - Error table: count badge, module, short message, expand for the stack, Copy report.
- **All commands**
  - Two panes: searchable grouped list with a scrollbar, and a detail card with labelled inputs and Run, with the result shown inline.
  - Fixes B7.

**Map overlays**
- **World map pins**
  - Distinct glyph and colour ring per kind (12–14 px).
  - "+5" clusters, fading under zone labels, a sparse trail, hover scale-up.
  - Fixes B20.
- **Pins menu**
  - Gold header with a master switch.
  - Each row: the pin's real glyph, label, count chip, switch.
  - Footer: pin size, trail length.

---

## 4. Suggested order

1. **Bugs B1–B4.** Sidebar highlight, full width, and the two rule-breaking errors. Small, and they unblock everything.
2. **The system S1–S6** in Theme/Widgets/Premium, with specs for each component.
3. **Pages by daily use:** What now?, Quests, Rares, Hunter, Gear, Dungeons, then Town, Social, Outrider.
4. **Map pins and the Pins menu.**
5. **Re-run `/ride tour`** after each batch and compare before and after.

**Timing:** GPT is still editing modules and `UI/Pages.lua`. Per Gary's rule, the page work waits until GPT has finished. Bugs B3/B4 and the system layer (S1–S6) touch files GPT hasn't changed recently, but check `git log` before starting.

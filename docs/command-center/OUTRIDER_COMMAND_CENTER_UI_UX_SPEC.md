# Outrider Command Center: UI and UX specification

**Status: PLANNING ONLY.** No screens are built. Visual direction: the owner's concept art for the install companion, a dark and gold dashboard. It is mood reference only, not a specification to copy. Colours come from the addon's own theme tokens, so the two products look like one family.

## 1. Product principles

1. **One product, not a toolbox.** One window, one navigation, one design system and one voice (FR-14).
2. **Plain pages (owner rule).** Every page opens with:
   - a one-sentence purpose line;
   - a short "1-2-3" of what to do;
   - picture cards rather than walls of numbers.

   An 8th grader should get it.
3. **Your character first (owner rule).** Content is scoped to the selected character's class, build, race and level. Other builds come last and are labelled as such (FR-10).
4. **Show the evidence.** Any number can be tapped to show where it came from: an evidence chip linking to the vault row and its provenance. Estimates show their confidence and sample count.
5. **Honest gaps.** Missing data reads "Not enough data yet: play two more sessions with this character". It is never a made-up value or an empty chart.
6. **Advice, not control.** Buttons copy a code or write the advice file when the game is closed. Nothing claims to act in the game.

## 2. Window, navigation and host

**Host (D01):**
- **Recommended (D01 a):** a WebView2 window, minimum 1100×700, that remembers its size and position.
- **Fallback:** the default browser at the tokenised loopback URL, with a banner explaining why.

**Layout:**
- Left sidebar navigation.
- A top bar with:
  - the character switcher (portrait icon by class, then `Name - Realm`, then level), with "All characters" at the end;
  - the ingest status ("Updated 5 minutes ago" or "Game is running: will update after you log out");
  - Help.

**Sidebar order:**

| # | Screen | Group |
|---|---|---|
| 1 | Home | |
| 2 | Characters | |
| 3 | Sessions | |
| 4 | Progression | Analytics |
| 5 | Economy | Analytics |
| 6 | World | Analytics |
| 7 | Planner | |
| 8 | Coach | |
| 9 | Vault | |
| 10 | Settings | System |
| 11 | Diagnostics | System |
| 12 | Character detail | Reached from Characters and from the switcher |

**Keyboard:**
- Ctrl+1 to Ctrl+9 jump to screens.
- Ctrl+K opens search (Vault).
- Tab order follows the visual order.
- Esc closes dialogs.

## 3. Design system

**Tokens** (`ui/static/tokens.css`, generated from the addon's `UI/Theme.lua` where a matching token exists):

| Token | Use |
|---|---|
| `--bg`, `--bg-raised`, `--bg-sunken` | Dark surfaces |
| `--fg`, `--fg-muted` | Text. Contrast at least 4.5:1 on every background. |
| `--accent` (gold), `--accent-fg` | Primary actions, selection, headings |
| `--good`, `--warn`, `--bad`, `--info` | Status. Always paired with a text label or icon, never colour alone. |
| `--class-<class>` | Class colours for portraits and chart series, each with a contrast-safe text variant |
| Spacing | 4-px scale: 4, 8, 12, 16, 24, 32 |
| Radius | 6 for cards, 4 for controls |
| Type | System UI font. Sizes 13/15/18/24/32. Line height 1.4. |

**Components:**

| Component | What it is |
|---|---|
| Purpose line | One sentence at the top of every page |
| Step list | A numbered 1-2-3 |
| Card | Title, body and an optional action |
| Stat tile | Big number, label, change from the comparison period, and an evidence chip |
| Chart frame | Inline SVG chart, text summary, and a "show table" toggle |
| Table | Sortable, with sticky header and keyboard row focus |
| Evidence chip | `●` plus a short source (for example "12 sessions"); opens the row in Vault |
| Confidence pill | Low, medium or high, with sample count |
| Status pill | |
| Empty state | Picture, one sentence, next step |
| Banner | Info, warning or error |
| Dialog | Confirmations, the AI preview |
| Code box | Copy button and the paste instructions for the game |

**Charts:** line (rates over time), stacked bar (time use), bar (comparisons), sparkline (tiles). They are rendered locally as SVG, with no CDN. Every chart has a text summary sentence and a table view (QR-06).

## 4. Screens

Every screen has a purpose line, steps, its main content, an empty state and an error state.

| Screen | Purpose line | Steps | Main content |
|---|---|---|---|
| **Home** | "Your last adventure, and what to do next." | 1 Read how it went. 2 Look at what we learned. 3 Plan tonight. | Welcome-back card for the last session: duration, XP, gold, quests. "What we learned": up to 3 trend sentences with evidence. "Your next adventure": the top plan steps and a Plan button. With an empty vault, the first-run steps to find the game folder. |
| **Characters** | "All your characters in one place." | 1 Pick a character. 2 See where they stand. 3 Pick one for tonight. | Portrait cards: class, level, realm, last played, rested state, top goal. A "Which one tonight?" button (the choice ranking, OCC-04-05). |
| **Character detail** | "Everything about \<Name\>." | 1 Check progress. 2 Review gear and professions. 3 Set a goal. | Profile (class, spec or "unknown", race, level), progression summary, gear snapshot, professions, goals. Own-class content first; "Other builds" last. |
| **Sessions** | "Every time you played, start to finish." | 1 Pick a session. 2 See the timeline. 3 Compare it with your usual. | Session list with filters, and a timeline (activity bands, XP, deaths, sales). Inferred sessions are marked. |
| **Progression** | "How fast you're levelling, and why." | 1 See your XP per hour. 2 See where your time goes. 3 Read the tips. | XP/hour over time, level curve, time-use stacked bar, trend explanations |
| **Economy** | "Where your gold comes from and goes." | 1 See your net gold. 2 Check your best sellers. 3 Watch prices. | Net gold per week, ledger, best sellers, price trends for watched items |
| **World** | "What you've found out there." | 1 Check your rares. 2 See your paths. 3 Look at fishing and nodes. | Rare sightings with observed respawn ranges and sample counts, a trails map image (from the recorded points), fishing stats. Unverified pack data is labelled. |
| **Planner** | "Plan tonight before you log in." | 1 Say how long you can play. 2 Pick the character and goals. 3 Send the plan to the game. | Time input, character choice with reasons, ordered steps with time, confidence and evidence. Copy code (shows the paste instructions). Write to the game (enabled only when the game is closed). |
| **Coach** | "Ask anything about your characters." | 1 Type a question. 2 Check what will be sent. 3 Read the answer and its sources. | Question box, suggested questions, answer with evidence chips and a confidence pill, the cloud preview dialog. In AI-off mode: deterministic answers, plus "Add an AI helper (optional)". |
| **Vault** | "Everything Outrider has ever recorded, kept safe." | 1 Search. 2 Open a record. 3 See where it came from. | Search (text, dataset, character, date, id), row view with provenance, lineage and revisions. Backup and restore controls. Off-load confirmation status. There is no delete. |
| **Settings** | "Choose how Command Center works for you." | 1 Check the game folder. 2 Choose when to update. 3 Set up AI (optional). | Game folder and accounts, ingest trigger (D04), backup schedule, AI providers and budgets, keys (write-only), privacy toggles, theme scale |
| **Diagnostics** | "Check that everything is healthy." | 1 Look at the checks. 2 Open the log if something is red. 3 Copy a report for help. | Version, paths, vault size and integrity, last ingest result, errors, a "Copy report" button (local file, redacted) |

## 5. Class and build awareness

- The character switcher drives every screen. "All characters" is explicit and is labelled as such on every page.
- Ordering rule: the selected character's class and spec first, then the same class with other specs (labelled "Other builds"), then other classes only where relevant.
- An unknown spec is shown as "Spec unknown: log in once with Outrider to update". It is never guessed.

## 6. States, wording and accessibility

**States:**

| State | Wording |
|---|---|
| Empty (first run) | Find the game folder, then the 1-2-3 to log in and out once |
| Not enough data | "Play N more sessions with this character to see this." |
| Game running | "The game is open. Command Center will update after you log out." The write button is disabled, with the reason shown. |
| AI off | Every screen works. The Coach screen explains that answers come from your data, with an optional AI helper. |
| Error | What happened, in one sentence; the next step; a Diagnostics link. No stack traces in the UI. |

**Wording:**
- Short sentences, everyday words, the second person.
- No jargon on main screens. "Provenance" is shown as "Where this came from".

**Accessibility (QR-06):**
- Keyboard navigable, with visible focus.
- Contrast at least 4.5:1.
- Status is never shown by colour alone.
- Charts have text summaries and tables.
- Works at 125% and 150% Windows scaling.
- Respects the system's reduced-motion setting.
- Images have alt text.

## 7. Review artefacts

G6 packets include screenshots of every screen at 100% and 150%, in the empty and populated states (dev only, D19), plus the owner's notes from an evening of real use.

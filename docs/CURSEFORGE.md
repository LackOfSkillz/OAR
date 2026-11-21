# Publishing Outrider on CurseForge

How Outrider gets onto CurseForge and from there into players' AddOns folders. Researched 2026-11-21; sources at the end. Decision D23 in [DECISIONS.md](DECISIONS.md).

## How players will install it (easiest first)

| Way | What the player does | Notes |
|---|---|---|
| **CurseForge app** | Install the app, add their WoW folder, search "Outrider", click Install. Updates with one click. | Most players already use it. CurseForge's site lists Forever as its own game version (Forever addons are live there). The app's help pages name Retail, Classic and Classic Era but not Forever: if the app doesn't find `_forever_` by itself, they add the `World of Warcraft` folder by hand (Settings, +, Manually add a game). Check this once ourselves after the first upload. |
| **WowUp** | Install WowUp (CurseForge edition), Options, Clients, Re-Scan, then search "Outrider". | WowUp's docs list **World of Warcraft: Forever** as a supported client (confirmed). |
| **Install-Outrider.cmd** | Download from the [releases page](https://github.com/LackOfSkillz/outrider-releases/releases/latest), close WoW, double-click. | Finds WoW Forever (registry and the usual folders, or asks), backs up an older copy, installs, adds an "Update Outrider" desktop shortcut. Windows may warn (More info, Run anyway). Not for CurseForge: it is a script, and addon zips must hold addon files only. |
| **By hand** | Unzip into `World of Warcraft\_forever_\Interface\AddOns`. | The zip's top level is the addon folders themselves (`Outrider`, `Outrider_Data_*`), so unzipping straight into AddOns is right. Common mistake: an extra folder level (`AddOns\Outrider-0.3.0\Outrider`); the game then lists nothing. |

## One-time setup (Gary, on the website: about 15 minutes)

The CurseForge API can upload files and read game versions; it has no documented way to create a project or set its logo, description, categories or licence. So these steps are on the website, once.

1. **Author account.** Sign in at https://authors.curseforge.com (accepting the Mod Author Terms is part of signing up).
2. **Create the project:** https://authors.curseforge.com/#/projects/create/choose-game, game **World of Warcraft**. Fill in from "Listing text" below:
   - Name, Summary, Main category plus up to 4 more, Allow comments on, **Experimental off**, editor Markdown, Description, Licence **GNU General Public License version 3 (GPLv3)**.
   - Logo: upload [curseforge/logo.png](curseforge/logo.png) (400x400, made by `python tools/logo.py` from the in-game emblem).
3. **Submit.** CurseForge's moderators review new projects and every file (8 AM to 3 PM CET, 7 days a week, first in first out). Notifications: https://www.curseforge.com/my-notifications
4. **Project ID.** On the project page under "About This Project". Tell Claude the number: it goes into `Outrider.toc` as `## X-Curse-Project-ID: <number>`.
5. **First file.** Either upload `dist\curseforge\Outrider-<version>.zip` on the project's Files tab (game version **1.60.1**, the Forever one; release type Release), or let the script do it (next section).
6. **Screenshots** (Images tab, after the project exists): Home, Map with the way-there dots and rare pins, Quests with Chains, Dungeons quests and keys, Macros, the auction house window. `/ride tour` takes them one click at a time.

## Every release after that (one command)

1. **API token, once:** https://authors.curseforge.com/#/settings/api-tokens, make a token, then on this PC in PowerShell (keep the token out of chat and out of the repo):

   ```powershell
   [Environment]::SetEnvironmentVariable('CF_API_KEY', '<your token>', 'User')
   ```

   Open a new terminal afterwards.
2. **Release:** bump `## Version:` in `Outrider.toc`, write the CHANGELOG section, then

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File tools/curseforge.ps1 -Upload
   ```

   It runs every test, builds the zip, finds CurseForge's id for game version 1.60.1 (from `## Interface: 16001`), and uploads with the newest CHANGELOG section as the changelog. `-ReleaseType beta` or `alpha` for test builds; `-Changelog "text"` to write your own. Without `-Upload` it only builds the zip.

What's in the zip: `Outrider`, `Outrider_Data_Words` and the six QuestieDB-derived data addons (NPC, Gear, Mobs, Nodes, Dungeons, Quests), each with `LICENSE-DATA.txt` and the GPLv3 text. Never in it: the installer, the updater, Gary's shared world knowledge, SavedVariables or logs. The script refuses to package any program or script file.

Why not CurseForge's own automatic packager or the BigWigs packager: both build from a public git repository on a tag push, and the source repo `LackOfSkillz/OAR` is private, with the addon in `addon/` and the data addons in `private/`. Our own script builds the same zip the tests check. If the source goes public later, the BigWigs packager in GitHub Actions (`CF_API_KEY` secret, `## X-Curse-Project-ID` in the TOC) is the standard way.

## Listing text (paste into the project form)

**Name:** Outrider. Fallback if taken: Outrider (WoW Forever).

**Summary:** One addon for WoW Forever: rare alerts, quest and dungeon guidance, the way to any place, hunter pet tools, macros, professions, auction shopping and gear advice, all for the character you're on.

**Main category:** Quests & Leveling. **More categories:** Map & Minimap, Professions, Auction & Economy, Hunter.

**Description:**

```markdown
# Outrider: one addon for WoW Forever

Outrider replaces a stack of addons with one that knows which character you're on: class, race, level, talents, professions and gold. Every page shows what fits that character, in plain words, with one button to go there.

**Open it with /ride** (or the minimap button).

## What it does
- **Home:** your next step, where to go and why, XP and rested XP, nearby trainers and services, quests, upgrades and rares at a glance.
- **The way there:** pick any place, quest or trainer and a gold arrow plus a line of dots on the map and minimap show the way, with flight masters, zeppelins, boats and skyboats planned for you.
- **Quests:** objectives and turn-ins on the map, quest chains in order, a quest diary.
- **Dungeons:** which dungeons fit your level, their quests and keys, upgrades inside, and a ready check.
- **Rares:** alerts with sound and a screen flash, big map pins, spawn timers, a watch list.
- **Hunters:** tame macro, pet happiness and diet, feed button, ammo warnings.
- **Macros:** written from your own spellbook and talents for all nine classes, with combined keys (interrupt, defensive, burst, recover).
- **Professions and gold:** skill-up planner, crafting queue, fishing helper, an auction house shopping window that finds the cheapest listing, money guide by level.
- **Gear:** upgrade verdicts weighted for your class and build, quest reward picks, gear for your alts.

## Safe and private
- Advice only: every cast, target, buy and craft is your own click or key press.
- No combat log parsing. Nothing leaves your PC; sharing with guild or party is off until you switch it on.
- Works on its own: no other addon needed.

## Data
Quest, NPC, creature, node, gear and dungeon data is converted from QuestieDB and shared under GPLv3 (licence and source notes inside each data folder). Outrider is not made by or affiliated with the Questie team. New Forever data is marked unverified until it has been seen in game.

Created by Gary Mix. GPLv3. Source of the data packs: https://github.com/LackOfSkillz/outrider-releases
```

## Sources (read 2026-11-21)
- Project Submission Guide: https://support.curseforge.com/en/support/solutions/articles/9000199552-project-submission-guide-and-tips
- Addons FAQ (moderation hours): https://support.curseforge.com/support/solutions/articles/9000198422-addons-faq
- Upload API (game versions, upload-file, X-Api-Token): https://support.curseforge.com/en/support/solutions/articles/9000197321-curseforge-upload-api
- Automatic packaging: https://support.curseforge.com/support/solutions/articles/9000197281
- BigWigs packager: https://github.com/BigWigsMods/packager and https://warcraft.wiki.gg/wiki/Using_the_BigWigs_Packager_with_GitHub_Actions
- Forever files on CurseForge, game version 1.60.1: https://www.curseforge.com/wow/addons/foreverplus
- CurseForge app, getting started: https://support.curseforge.com/en/support/solutions/articles/9000193488-getting-started
- WowUp supported clients (Forever listed): https://wowup.io/guide/options/wow-clients
- Mod Authors Terms: https://legal.overwolf.com/docs/curseforge/mod-authors-terms

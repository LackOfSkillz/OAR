# HANDOFF: from the claude.ai chat to Claude Code on Gary's PC

Written 2026-11-11 at the end of the planning chat. Read this once, then work from CLAUDE.md and TASKS.md. Delete this file (or move it to `docs/`) after the first Claude Code session has done "Start here".

---

## Start here (first Claude Code session)

1. **Get the rename commit.** `git pull` in the repo. You should be on v0.2.0: folder `addon/Outrider`, `Outrider.toc`, this file present.
2. **Rename the GitHub repo** (Gary is signed in to `gh` on this PC):
   ```
   gh repo rename Outrider --yes
   git remote set-url origin https://github.com/LackOfSkillz/Outrider.git
   git fetch origin && git status
   ```
   GitHub redirects the old URL, so nothing breaks if this waits, but do it now.
3. **Local folder (optional, Gary's call).** The project lives in `C:\Users\Administrator\Dev\OAR`. To match the name, Gary closes Claude Code and any terminal in that folder, renames it to `Outrider` in Explorer, and reopens Claude Code there. Nothing in the tools depends on the folder name.
4. **Tests.** `powershell -NoProfile -ExecutionPolicy Bypass -File tools/test.ps1`: expect 71 passed. `tools/local.json` already exists from setup (WoW paths); it's git-ignored and doesn't depend on the addon name.
5. **Continue TASKS.md at P0-05** (first deploy and login). P0-01 to P0-04 and P0-10 are done.
6. **Say hi to Gary briefly**: confirm the pull and rename, then give him the P0-05 in-game list (start game, enable Outrider on the AddOns screen, tick "Load out of date AddOns" if shown, log in on Torrant, `/ride version`, `/reload`).

Nothing was ever deployed under the old name, so there is no `Interface\AddOns\OAR` folder to clean up and no SavedVariables to migrate.

---

## The project in one paragraph

**Outrider** is one character-aware addon for **WoW Forever** (Blizzard's Classic+ servers on the modern Midnight-era client, launched November 2026) that replaces a stack of separate addons. Planned: rare alerts with one-click target/tame, hunter pet tools, map pins that appear as you approach, waypoints, a macro library, professions/auction/fishing helpers, a gear advisor, a cleaner interface skin, guild sharing, and last an AI advisor (local or cloud model via an MCP companion app; groundwork already in the code, dormant). Gary plays and tests; Claude Code writes, tests, deploys and reads results. Claude never sends input to the game.

## Where everything is

| What | Where |
|---|---|
| Repo on the PC | `C:\Users\Administrator\Dev\OAR` (maybe renamed to `Dev\Outrider`, step 3) |
| GitHub | `LackOfSkillz/OAR`, private, becoming `LackOfSkillz/Outrider` (step 2) |
| WoW install | `C:\Program Files (x86)\World of Warcraft`, client folder `_forever_` |
| Deploy target | `...\_forever_\Interface\AddOns\Outrider` (tools/deploy.ps1) |
| SavedVariables | `...\_forever_\WTF\Account\82030498#1\SavedVariables\Outrider.lua` (appears after the first login + /reload) |
| Screenshots | `...\_forever_\Screenshots` (tools/screenshot-latest.ps1) |
| Blueprint doc (feature brainstorm, macro research, professions, gear, interface, AI advisor) | https://claude.ai/artifact/7ThmPPt2DH5tJghYFXTdsb |
| PC | `it-lt-01`, Windows, user `Administrator`; Git 2.56, gh 2.103 (signed in as LackOfSkillz), Python 3.12.10 + lupa, Claude Code 2.1.322 |

## State at handoff (v0.2.0)

Built and tested headless (71 specs, Lua 5.1 via lupa):
- Core: namespace, compat layer, ring-buffer log (`Outrider_Log`), error catcher (BugGrabber-friendly), event dispatcher with owners, combat queue (capped, cancellable), serializer + `OTR1:` export strings, account-wide DB with per-character sections, safe migrations (run on a copy; newer/failed/missing schema → safe mode, file untouched), profiles (export/import/copy), module system (class, required addons, yieldsTo, player choice), conflict detection, API probe (keeps last 6 unit-readability runs).
- UI: theme tokens, widget kit, hub window, minimap button (LibDBIcon if present), Options page.
- Advisor groundwork (dormant): `/ride snap`, advice loader with whitelist (integer IDs, finite 0..1 coords, panel whitelist, map existence, escape-code stripping, confidence tags).
- Data: registry with schema + provenance checks; hunter macro pack (19 hunter + 2 general macros from the blueprint's research, all `verified = false` except the tame macro, which Gary confirmed on The Rake).
- Tools: find-wow, deploy (build stamp, restart detection), read-logs (+ `-Mark`, `-Bugs`), backup/restore, screenshots, package, setup-dev (one-time), build_tasks.

**Verified in game: nothing yet.** Interface number 16001, the `_forever_` folder (confirmed on this PC), and every API assumption in `docs/FOREVER_CONSTRAINTS.md` still need Phase 0. P0-07 (SavedVariables round trip) is the gate for everything else.

## How we got here (short)

1. Hunter pet questions → Gary tamed **The Rake** with a macro built in the chat (pet attack speed 1.20 base, 1.17 with haste; advice given: train abilities, never reset training).
2. Brainstorm of "one addon to rule them all" → the blueprint doc above.
3. Build package: CLAUDE.md, docs, 10 phase files, 113 micro-tasks, scaffold, tests, tools.
4. **GPT reviewed the package.** Its valid code findings were fixed in v0.1.1 (migration safety, newer-schema safe mode, reset rebinding, combat queue re-reading state, stricter advice validation, provenance fields; 11 new specs). Its product suggestions are listed under "Open with Gary" below.
5. Setup on this PC via `Setup.cmd`; first push to GitHub.
6. Gary picked the name **Outrider** (DECISIONS D8); renamed in v0.2.0 before any deploy.

## Decisions already made

See `docs/DECISIONS.md` (D1 to D8). The ones that matter most day to day:
- Skin Blizzard frames, never replace them; step aside for ElvUI/EllesmereUI.
- Hook Questie, TomTom, Auctionator/TSM, GearQuest; don't copy their data.
- Self-building data (discovery mode) plus small verified packs; never invent IDs or coordinates.
- No automation; advice never acts.
- AI advisor last, groundwork shipped dormant.

## Open with Gary (ask when the time comes, not before)

| Question | When | Context |
|---|---|---|
| Roadmap order after Phase 3: current plan or "companion-first" | Before starting Phase 4 | GPT's review argued for: hunter companion → discovery atlas → a deterministic in-game "goals" screen (better pet, upgrade gear, town errands, session recap) → macros → gear → AI companion → professions → sharing → UI last and optional. Phases 0 to 3 are the same either way. Recommended to Gary: companion-first, with interface redesign last and optional. He hasn't decided. |
| Add a **pet comparison engine** and **pet journal** to Phase 2 | At the P1 gate, before Phase 2 | Best idea from the review: "is The Rake actually better than my pet, and is it worth the trip". Fits either order. Needs pet data with provenance. Propose as P2 tasks; Gary approves. |
| Add player-value checks to gates | With the item above | e.g. "can Gary find and tame a pet using only Outrider", not only "no errors". |
| Public release and license | End of Phase 3 | DECISIONS Q2, Q3. |
| Visual direction | Phase 7 | DECISIONS Q4. |
| Guild sharing default | Phase 8 | DECISIONS Q5 (recommend opt-in). |

## Known quirks and lessons

- **GitHub sign-in:** GitHub Mobile push approvals were flaky for Gary. If `gh` ever needs re-auth, have him open `github.com/login/device` in the Chrome window where he's already signed in and paste the code, rather than relying on the browser `gh` opens (his default browser may differ) or the phone push.
- **Windows PowerShell 5.1** turns a native command's stderr into a red `NativeCommandError` when it's merged with `2>&1`. The setup script's `git push` line shows one even on success. Cosmetic; if touched, drop `2>&1` there and use `git -c core.safecrlf=false add -A` to silence the LF→CRLF warnings.
- **Line endings:** files were created with LF; `.gitattributes` sets `eol=crlf` for `.ps1`/`.cmd`, `text=auto` for the rest. Expect CRLF warnings on the first touch; harmless for WoW, Lua and PowerShell.
- **`.claude/settings.json`** could not be written remotely. `tools/claude-settings.example.json` pre-approves the project's commands; copy it to `.claude/settings.json` if Gary wants fewer prompts.
- **Test Lua:** `tools/lua.py` runs tests on lupa's Lua 5.1, which has no `io.popen`; it injects `OTR_HOST_LIST_LUA` for file listing. A real Lua 5.1/LuaJIT on PATH also works. Don't move to 5.2+ (tests use `setfenv`).
- **Commit identity:** repo-local `Gary Mix <218629871+LackOfSkillz@users.noreply.github.com>`. Keep using the no-reply address; never put Gary's personal email in commits.
- **Commit trailers** used so far: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_0184WK5DzcAEndyqESt4z1eR`. Use whatever attribution your own session instructions give you.

## Gary

- Network engineer (OT/SCADA background); thinks in reliability and escalation thresholds. Comfortable in a terminal.
- Casual and concise, dry humor. **No em dashes** in anything you write for him. **Flag judgment calls explicitly** when rule sets conflict (e.g. his original "merge everything" goal vs the review's "companion first").
- Plays **Torrant Mcluvin**, Horde hunter, main; also a priest and a mage (test character awareness on those).
- Hunting next: **Mystmane** and **Ghost Howl** (G2 field test targets alongside The Rake, already tamed).
- His Mystmane macro (copied from the Rake one) has `#showtooltip Mystmane`; it should be `#showtooltip Tame Beast`, and the macro is still named "The Rake". He was told; the Phase 4 library's rare-aware tame macro replaces per-rare copies.
- Wants BugGrabber + BugSack installed and enemy nameplates on before Phase 0's in-game steps (told, not confirmed).

## Hard rules (full list in CLAUDE.md §1)

Never send input to the game. Only write to `Interface\AddOns\Outrider` via deploy.ps1; WTF is read-only. Fail soft on every API. No combat-log features; secret values are unknown. Protected frames only out of combat. Quiet by default. Never invent game data. Hook, don't replace. Tests green before deploy. Nothing leaves the PC.

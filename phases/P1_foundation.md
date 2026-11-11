# Phase 1: Foundation

**Goal:** the core every module stands on is proven in the real client: modules switch per character, settings survive restarts, export/import works, errors are caught and readable, the hub and minimap button work, and the shared services Phase 2 needs (secure button pool, toasts, throttling) exist.

Most of the core is already written (see `addon/OAR/Core`, `UI`). Phase 1 tasks verify it in game and add the missing shared services.

**Gate G1:** settings survive a full game restart; two characters (hunter + priest or mage) have independent settings and the hub shows only what applies to each; a 30-minute normal play session produces zero OAR errors and zero taint reports; the name question (Q1) is settled.

---

### P1-01 · Module loader in game · Both · deps: P0-07
1. Gary: `/oar modules`, `/oar module Welcome off`, `/reload`, `/oar modules`, `/oar module Welcome on`, `/reload`.
2. Claude: `tools/read-logs.ps1 -Section chars`.

**Done when:** Welcome shows `switched off` for Torrant after the first reload and nothing after the second; no errors.

### P1-02 · Character awareness · Both · deps: P1-01
1. Gary logs in on his priest (or mage), `/oar status`, opens the hub (`/oar`), Print Screen, `/reload`.
2. Claude: `tools/read-logs.ps1 -Section chars` and the screenshot.

**Done when:** two character sections with correct class/race/level; the priest got the greeting once; hub shows the priest's name and class.

### P1-03 · Export, import, copy in game · Both · deps: P1-02
1. On Torrant: hub → Export, Ctrl+C. Log the priest in: hub → Import, paste, Accept, `/reload`.
2. Hub → Copy from... → Torrant. `/reload`.
3. Try importing a broken string (delete a few characters): expect a red message, nothing applied.

**Done when:** log shows `applied profile from Torrant-<realm>` twice; broken import refused with "checksum mismatch"; priest's class metadata unchanged.

### P1-04 · Throttle and timer helpers · Claude · deps: none
Shared by every scanner in later phases.
1. Add to `Core/Compat.lua` or a new `Core/Timer.lua`: `ns.Timer.After(sec, fn)`, `ns.Timer.Ticker(sec, fn)` returning a handle with `:Cancel()`, both wrapped in `ns.Safe`, falling back to an OnUpdate frame if `C_Timer` is missing.
2. `ns.Throttle(key, interval, fn)`: run at most once per interval per key; trailing call guaranteed (so the last event in a burst is processed).
3. Add mock support for `C_Timer.NewTicker` in wowmock (advance time with `game:advance(sec)`).
4. Specs: burst of 20 calls in 0.1 s → 1 immediate + 1 trailing run; cancel stops a ticker.

**Files:** `Core/Timer.lua` (add to TOC after Combat), `tests/spec/timer_spec.lua`.
**Done when:** specs pass; no OnUpdate runs when no timers are pending.

### P1-05 · Secure button pool · Claude · deps: P1-04
Rare alerts (P2), tame helper (P2), macro buttons (P4) all need clickable secure buttons that are safe around combat.
1. `UI/SecureButtons.lua`: `ns.SecureButtons:Acquire(owner, opts)` returns a `SecureActionButtonTemplate` button from a pool created out of combat (pre-create 4 at login). `:SetMacro(btn, text)` sets `type=macro`, `macrotext` via `ns.Combat:Run` keyed per button. `:Release(btn)`.
2. Buttons register `RegisterForClicks("AnyUp", "AnyDown")` as the client requires (check the probe; modern clients fire secure clicks on down when `ActionButtonUseKeyDown` is set).
3. Never call protected functions from Lua. The button's click does the work.
4. Specs: acquiring in combat returns a pre-created button; SetMacro in combat is queued and applied after combat; release resets attributes.

**Files:** `UI/SecureButtons.lua`, mock `SetAttribute/GetAttribute`, `tests/spec/secure_spec.lua`.
**Done when:** specs pass; in game, Gary can click a test button (add `/oar selftest button`: a small secure button whose macro is `/wave`) and it works out of combat, and after combat if the macro was changed during combat.

### P1-06 · Toasts · Claude · deps: P1-04
1. `UI/Toast.lua`: `ns.Toast:Show({ title, text, icon, color, sound, duration, button = { label, macro } })`. Stack up to 3, top-center by default, movable anchor saved per character, fade out. Sound via `PlaySound(soundKitID)` guarded; sound choice per module setting.
2. Optional secure button on the toast via the pool (P1-05).
3. `/oar selftest toast` shows a sample.

**Done when:** Gary sees the sample toast with sound, can drag its anchor, and the position survives /reload; screenshot reviewed.

### P1-07 · UI kit additions · Claude · deps: P1-06
1. Widgets: `ScrollList` (virtualized rows for long lists: macros, upgrades, recipes), `Tabs`, `Dropdown` (simple, our own, no UIDropDownMenu taint), `Slider`, `SearchBox`.
2. Keep everything token-driven (Theme). Add `Theme:UseClassAccent()` setting in the hub.
3. Gary reviews a screenshot of a test window showing each widget.

**Done when:** widgets render without errors; Gary approves the look or lists changes.

### P1-08 · Hub with tabs · Claude · deps: P1-07
1. Turn the hub into tabs: **Overview** (character, status line, alerts summary later), **Modules** (current list with reasons), **Characters** (list from `DB:Characters()`, copy-from buttons), **Tools** (export, import, errors, probe summary, debug toggle, reload).
2. `ns.Hub:AddTab(id, title, build)` for modules (Phase 2 adds "Rares", "Pet").
3. Hub remembers the last tab per character.

**Done when:** screenshot of each tab; no errors; Esc closes; position saved.

### P1-09 · Minimap button and settings page · Both · deps: P1-08
1. Gary: drag the minimap button around, `/reload` (position kept). Right click (settings page opens at OAR). Left click (hub). `/oar minimap off`, `/reload`, `/oar minimap on`.
2. If Gary uses a minimap button collector, check OAR's button is collected (LibDBIcon path).

**Done when:** all of the above work; Esc > Options > AddOns shows OAR with the "Open OAR hub" button.

### P1-10 · Snapshot stays dormant but works · Both · deps: P0-07
1. Gary: `/oar snap`, `/reload`.
2. Claude: `tools/read-logs.ps1 -Section snapshots`.

**Done when:** a snapshot for Torrant with level, class, mapID and gear IDs is in the file; no reload happened by itself.

### P1-11 · Performance check · Claude · deps: P1-08
1. Add `/oar perf`: `UpdateAddOnMemoryUsage()` then `GetAddOnMemoryUsage("OAR")` (or `C_AddOns` variant per probe), event handler counts per event, pending timers, modules on.
2. Optional: wrap the dispatcher with `debugprofilestop()` timing when debug is on, keep the slowest 10 handlers.
3. Gary runs `/oar perf` in a city after 10 minutes of play, `/reload`.

**Done when:** numbers logged and within the budget in ARCHITECTURE.md; anything over budget gets a task.

### P1-12 · Installed addons check · Claude · deps: P0-02
1. List `Interface\AddOns` folder names (read-only) and compare with `Core/Conflicts.lua` KNOWN.
2. Fix folder names that differ (some addons ship as several folders, e.g. `Questie` vs `Questie-Classic`).
3. Add any addon Gary uses that overlaps a planned module, with the right relation.

**Done when:** hub Overview lists Gary's relevant addons correctly; DECISIONS gets a line for any overlap that changes plans.

### P1-13 · Gate G1 run · Both · deps: all P1
1. Gary: play normally for 30 minutes on Torrant (quests, a city visit, combat), then switch to the priest for 5 minutes, then exit the game fully, start again, log in on Torrant.
2. Claude: `tools/read-logs.ps1 -Section all -Bugs`.

**Done when:** zero OAR errors and taint entries; settings intact after restart; tick G1 in TASKS.md.

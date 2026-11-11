# Phase 7: Interface modernization

**Goal:** the screen looks current and behaves around what Gary is doing: flat dark panels with the class color as accent, readable fonts, clean tooltips, and context layouts (questing, combat, dungeon, fishing, crafting, auction) built on Edit Mode and Blizzard's own frames. Skin, don't replace.

**Gate G7:** Gary signs off on before/after screenshots for the main screens; a one-hour session including combat, a dungeon or group, a city and fishing produces zero taint reports and zero OAR errors; with ElvUI or EllesmereUI installed, the skin steps aside and only OAR's own panels remain.

What Forever gives us (from the blueprint research): Edit Mode, a Cooldown Manager, a built-in damage meter, a swing timer and a one-bag view ship with the client; players pick a Classic or Enhanced preset at first login. Protected frames can't be moved or rebuilt in combat. Values can be shown in combat but not computed. Fonts we ship need a redistributable license (SIL Open Font License).

Modules: `Skin` (yieldsTo ElvUI, EllesmereUI), `TooltipPlus`, `Bars` (look only), `ChatPlus`, `Nameplates` (look + rare highlight), `Layouts`, `CommandBar`, `Notifications`, `Setup`.

---

### P7-01 · Visual direction · Both · deps: P1-07
1. Claude makes a mockup (an image or an HTML page) of three directions: Clean dark (current theme tokens), Classic+ (gold trim and parchment, sharper), Minimal. Show the same screen: unit frames, bars, tooltip, OAR hub, a toast.
2. Gary picks one (Q4 in DECISIONS). Theme tokens updated to match.

**Done when:** decision recorded; Theme.lua updated.

### P7-02 · Fonts and textures · Claude · deps: P7-01
1. Pick an open-license font family (check the license file allows redistribution; include it in `addon/OAR/Media/Fonts/` with its license). Register sizes in Theme.
2. Status bar and border textures (our own, simple). LibSharedMedia registration if LSM is present.

**Done when:** fonts render in the hub and toasts; license files included; DECISIONS notes the fonts and licenses.

### P7-03 · Edit Mode survey · Both · deps: P0-08
1. Probe what Edit Mode controls on Forever (`EditModeManagerFrame`, `C_EditMode.GetLayouts`) and what the Classic vs Enhanced presets change. Screenshots of both.
2. Write findings into PROBE_RESULTS.md: which frames are Edit Mode systems (movable without us), which are not.

**Done when:** the frame list is documented; every later P7 task names whether it relies on Edit Mode or our hooks.

### P7-04 · Skin Blizzard frames · Claude · deps: P7-02, P7-03
1. Module `Skin`: restyle (textures, borders, fonts, colors) on non-protected or cosmetic regions only, via `hooksecurefunc` and region changes out of combat: character frame, spellbook, quest log, gossip, merchant, mail, bags (one-bag view if on), loot window, popups, game menu.
2. Never reparent, move or resize protected frames; never call `SetPoint` on secure frames in combat.
3. Step aside when ElvUI or EllesmereUI is loaded (`yieldsTo`). One owner per frame.

**Done when:** before/after screenshots for each frame; `/oar errors` empty after opening each frame in and out of combat.

### P7-05 · Tooltips · Claude · deps: P7-04
1. Flat tooltip style, class-colored border for players, a thin health bar, target-of-target line, and a single ordered block for OAR lines (upgrade verdict, AH value, beast info, "needed by quest/recipe"). Each module adds lines through one `ns.TooltipLines:Add(kind, provider)` so they appear in a fixed order and never duplicate.
2. Optional ID display (npcID, itemID, spellID) for Claude-Gary debugging, off by default.

**Done when:** screenshots of player, NPC, beast and item tooltips.

### P7-06 · Unit frames and bars, look only · Claude · deps: P7-04
1. Player, target, pet, party frames: textures, fonts, class-colored health, cleaner numbers. Positions stay in Edit Mode.
2. Action bars: hide gryphons/art (setting), button skin (Masque support if present), cleaner hotkey text, out-of-range coloring. Fade out of combat via secure state drivers (`RegisterStateDriver` with `[combat] show; hide` style visibility), which work mid-fight.
3. Cooldown Manager: clean up duplicate rows for each spell rank (the known Forever quirk) if the API allows.

**Done when:** screenshots; one combat session without taint.

### P7-07 · Nameplates · Claude · deps: P2-03
1. Style friendly and enemy nameplates (bars, fonts) where the client allows addon styling; rare highlight (border/icon) driven by RareScan.

**Done when:** a rare's nameplate is visibly marked; screenshot.

### P7-08 · Chat · Claude · deps: P1-07
1. Short channel names, timestamps, copy chat window, clickable URLs to copy (no browser opening), class-colored names.
2. Keyword highlight (rare names, items on the shopping list, Gary's name) feeding P8 chat triage.

**Done when:** screenshot; copy works.

### P7-09 · Context layouts · Both · deps: P7-06
1. Contexts: questing, combat, dungeon/raid, battleground, fishing, crafting, auction, city. Detection from events (`PLAYER_REGEN_DISABLED`, instance type, fishing mode, profession or AH frame open).
2. Each context selects an Edit Mode layout (if `C_EditMode` allows switching layouts by API, out of combat) and which OAR panels show. Combat context uses only secure visibility drivers.
3. Per-character presets; export/import with profiles.

**Done when:** Gary walks from questing into a city into the AH and the layout follows; no taint.

### P7-10 · Command bar · Claude · deps: P3-07, P6-06
1. One keybind opens a search box: "rake" → rare card + waypoint, "spirit" → nearest spirit healer, "bow" → gear upgrades filtered, "crates" → Favor planner, "macro pull" → library entry. Opens panels and finds things; never casts.

**Done when:** ten sample queries open the right panels.

### P7-11 · Notification center · Claude · deps: P1-06
1. Toasts also land in a feed with history (rares, upgrades, rank-ready, AH sales, errors), so nothing scrolls away in chat. Bell on the minimap button tooltip with unread count.

**Done when:** feed shows the last 50 notifications across a session.

### P7-12 · First-run setup and accessibility · Claude · deps: P7-09
1. Short per-character wizard: pick a layout by class and role with a preview, sound on/off, which modules to start with.
2. Accessibility: per-element scale, font size, colorblind-safe palette (tokens), high-contrast mode, reduced motion (no fades).

**Done when:** new character sees the wizard once; settings apply.

### P7-13 · Gate G7 · Both · deps: all P7
Run the gate checks (including a session with ElvUI or EllesmereUI enabled if Gary is willing); tick G7.

# Phase 4: Macro library

**Goal:** an in-game library that installs ready macros in one click, fills in names from the spellbook and bags, only offers what this character can use, fixes the rank trap after training, and keeps rare-aware macros (tame, scan) current. Hunter first (the pack already exists in `Data/Macros_Hunter.lua`), then every class.

**Gate G4:** on Torrant, five library macros installed and each works when Gary presses it; on the priest, five priest macros; the rank-check finds an outdated button after a trainer visit and fixes it with one click out of combat; no macro over 255 characters; macro slot counts correct.

Modules: `MacroLibrary`, `RankCheck`. Data: `Data/Macros_<Class>.lua`.

Facts this phase relies on (from the blueprint's macro research): Forever uses Classic macro syntax (`/cast`, `/castsequence`, `[@mouseover]`, `[mod:shift]`, `[@focus]`); a `/cast` without a rank uses the highest rank; spell names must match the client language; 255 characters per macro; the General tab is account-wide and the second tab is per character. Confirm slot limits from the P0-08 probe (`MAX_ACCOUNT_MACROS`, `MAX_CHARACTER_MACROS`).

---

### P4-01 · Macro engine (pure logic) · Claude · deps: none
1. `Modules/Macros/Engine.lua` (pure functions, no game calls): `Fill(body, values)` replaces `{PLACEHOLDERS}`; `Validate(body)` returns problems: over 255 chars, unknown slash command, unbalanced `[` `]`, Auto Shot or an aspect without `!`, empty conditional blocks, missing `#showtooltip` on a multi-spell cast (warning only); `Explain(body)` returns one plain-English line per macro line ("If Shift is held, cast Multi-Shot; otherwise Aimed Shot").
2. Specs: every macro in every pack validates; tricky cases (`[@pet,dead][mod:shift]`, `/castsequence reset=6`, `[nomod,@mouseover,harm,nodead][nomod]`) explain correctly.

**Done when:** specs pass; `Explain` output for the 20 hunter macros reads correctly (Claude reviews the printed list).

### P4-02 · Spellbook resolver · Claude · deps: P0-08
1. Scan the spellbook (Classic `GetNumSpellTabs`/`GetSpellBookItemName` or modern `C_SpellBook` per probe) into `{ [lowercase name] = { spellID, rank, levelLearned? } }` for this character; refresh on `SPELLS_CHANGED`, `LEARNED_SPELL_IN_TAB`.
2. `Known(name)` and `Localized(name)`: macros store English names; the resolver maps them to the client's names via spell IDs captured once from an English client (store `spellIDs` in packs as they get verified).
3. Specs with a mock spellbook.

**Done when:** `/ride spells` lists known spells with IDs; matches the spellbook.

### P4-03 · Library window · Claude · deps: P4-01, P4-02, P1-08
1. Hub tab **Macros**: list (ScrollList) filtered by class (current character by default), tags, search; each row shows name, icon, short explanation, level needed, and state: available / needs spell (greyed with "learn Feign Death at 30") / installed / installed but different.
2. Detail pane: full body with placeholders filled, line-by-line explanation, warnings, **Install** / **Update** / **Remove** buttons, placeholder pickers (food from bags, mount, target rare).
3. Free slot counter for General and Character tabs.

**Done when:** screenshot of the tab on Torrant shows the hunter list with correct greyed entries for his level.

### P4-04 · Installer · Both · deps: P4-03
1. `Install(entry, values)`: out of combat only (`ns.Combat:Run`), `CreateMacro(name, icon, body, perCharacter)` or `EditMacro` if a macro with that name exists and was installed by Outrider (track installed names per character in settings; never overwrite a macro Outrider didn't create without asking in the UI).
2. Icon: `#showtooltip` macros use the question-mark icon (the client shows the spell); others use the pack icon.
3. After install, offer "Pick up" (`PickupMacro(index)`) so Gary can drop it on a bar himself (placing on bars is his click).
4. Specs: name collision handling, slot full refusal, combat queueing.

**Done when:** Gary installs Pull, AutoShot, Aimed, PetCare and Feed on Torrant from the library and each works when pressed. Mark those five `verified = true` in the pack.

### P4-05 · Live placeholders · Claude · deps: P4-04
1. `{PET_FOOD}`: best food in bags the pet eats (P2-09 diet logic). `{FOOD}`/`{DRINK}`: highest-level usable food/drink in bags (item level + required level from `ItemInfo`; conjured first). `{MOUNT}`: chosen once.
2. On `BAG_UPDATE_DELAYED` out of combat, if an installed macro's filled value would change (ran out of that food), update it with `EditMacro` (throttled, at most once per 10 s, never in combat). Setting: auto-update on/off per macro.

**Done when:** Gary eats his last stack of one food; the EatDrink macro switches to the next food within seconds out of combat.

### P4-06 · Rank-check · Both · deps: P4-02
1. Module `RankCheck` (all classes): after `LEARNED_SPELL_IN_TAB` / trainer close, scan action bars (`GetActionInfo(slot)` for `spell` actions) for spells whose rank is lower than the highest known.
2. Toast: "3 buttons use old ranks" with a **Fix** button (out of combat): for each, `PickupSpell(highest)` + `PlaceAction(slot)` + `ClearCursor()`, which is allowed out of combat on a click. Or offer the matching rank-free library macro instead.
3. Report what changed in the log with slot numbers.

**Done when:** after Gary trains a new rank (e.g. Serpent Sting), the toast appears and Fix updates the button. Update FOREVER_CONSTRAINTS C13.

### P4-07 · Rare-aware macros · Claude · deps: P4-04, P2-05
1. "Outrider Tame": the target name follows the newest watched tameable rare seen, or Gary's pick in the Rares tab; updated out of combat only.
2. "Outrider Scan": `/targetexact` lines for watched rares in the current zone, rebuilt on zone change (`ZONE_CHANGED_NEW_AREA`) out of combat, as many as fit in 255 characters (rares Gary watches first, then pack rares by distance).

**Done when:** entering Mulgore rebuilds the scan macro with the Mulgore rares; log shows the lines.

### P4-08 · Class packs · Claude · deps: P4-01
1. Research (web) and write packs for Priest, Mage, Warrior, Rogue, Warlock, Druid, Shaman, Paladin: 8 to 12 macros each, following the hunter pack's format, with sources and levels. Respect Forever spell changes found in research (cite them).
2. Every entry `verified = false` until pressed in game. Gary verifies the priest and mage ones he uses.

**Done when:** packs validate (spec); priest and mage lists show in the library on those characters.

### P4-09 · Export, import and context sets · Claude · deps: P4-04
1. Export installed Outrider macros of a character as an `OTR1:` string (reuses `ns.Serialize`), import onto another character (same validation as profiles).
2. Context sets (later tie-in with P7 context layouts): a named set of macro variants (questing / dungeon / pvp) swapped on a button click out of combat.

**Done when:** Gary exports Torrant's macros and imports them on an alt hunter (or the spec test proves the round trip if he has none).

### P4-10 · Gate G4 · Both · deps: all P4
Run the gate checks above; tick G4.

# Phase 2: Hunter tools and rares

**Goal:** Outrider notices rares the moment they are visible, alerts with a one-click target (and for hunters, tame) button, remembers where and when each was seen and on which layer, and gives hunters a pet status panel, beast tooltips and ammo warnings. Data comes from what Gary actually encounters on WoW Forever.

**Gate G2:** in the field, alerts fire for The Rake, Mystmane and Ghost Howl (or whichever of the three Gary can reach, plus two other rares); the target/tame button works with one click; sightings show the right zone, position and layer in the Rares tab; no errors or taint in a 1-hour hunting session.

Modules this phase: `Discovery` (all classes), `RareScan`, `RareAlerts`, `Layers`, `Sightings`, `TameHelper` (HUNTER), `PetStatus` (HUNTER), `BeastInfo`, `Ammo` (HUNTER).

---

### P2-01 · Discovery: record what Gary meets · Claude · deps: P1-04
Builds our own Forever-native NPC database.
1. Module `Discovery` (all classes, default on). Sources: `PLAYER_TARGET_CHANGED`, `UPDATE_MOUSEOVER_UNIT`, `NAME_PLATE_UNIT_ADDED`, and interaction events `MERCHANT_SHOW`, `GOSSIP_SHOW`, `TRAINER_SHOW`, `TAXIMAP_OPENED`, `BANKFRAME_OPENED`, `MAIL_SHOW` (role tags), `PET_STABLE_SHOW`.
2. From the unit: npcID and zoneUID (`Compat.UnitNpcID`), name, level, classification, creature family and type. Skip players, pets, critters (optional setting), secret values.
3. Position = the player's position at that moment, with a quality tag: `interact` (merchant/gossip, within a few yards), `target`, `nameplate` (up to ~40 yards off). Keep the best-quality position seen; average repeated `interact` positions.
4. Store in `ns.db.global.discovered.npcs[npcID]` per DATA_SCHEMAS.md. Throttle nameplate captures (P1-04).
5. `/ride discovered [n]` prints the last n captures.
6. Specs with mock units: capture, quality upgrade, skipping secrets and players, throttling.

**Done when:** Gary targets five NPCs and talks to one vendor; log shows six captures with mapIDs and the vendor tagged `vendor` with quality `interact`.

### P2-02 · Rare data pack seed · Both · deps: P2-01
1. Create `Data/Rares_Kalimdor.lua` (and `_EasternKingdoms` later) registering kind `rare`.
2. Seed with the rares Gary hunts first (The Rake, Mystmane, Ghost Howl) and other rares in his leveling zones. npcIDs: from Discovery captures when Gary has seen them, otherwise from a cited source (note `source`), `verified = false`.
3. Coordinates: only from discovery or sources known to be valid for Forever's maps. For redrawn zones (Mulgore), leave `spawns` empty until captured.
4. Beast details (family, tameable, attack speed, abilities) for tameable rares: cited source, `verified = false`.
5. `tools/` helper (optional): `tools/discovered-to-pack.lua` turns `discovered` entries with classification rare/rareelite into pack entries Claude can review and paste.

**Done when:** pack loads without validation errors (spec), each entry has `source`, and verified entries are only those Gary has seen.

### P2-03 · RareScan · Claude · deps: P2-01
1. Module `RareScan`. Watches nameplates, target, mouseover. A unit counts as a rare if its classification is `rare` or `rareelite`, or its npcID is in the rare pack, or it is on Gary's watchlist (P2-05).
2. Fires `OTR_RARE_SEEN` with `{ npcID, name, unit, how, mapID, x, y, layer, dead, level, family, classification, tameable }`. `dead` from `UnitIsDead(unit)`.
3. De-duplicate: same npcID within 60 s (setting) does not re-fire unless it changed from alive to dead or the layer changed.
4. Nameplate scans throttled (P1-04); never scan with OnUpdate.
5. Note: nameplates must be enabled for enemies (and possibly friendly/neutral for neutral beasts). Detect and tell Gary once if they are off (CVar `nameplateShowEnemies`).
6. Specs: classification rare fires; normal mob ignored unless in pack/watchlist; dedupe; dead transition re-fires.

**Done when:** in game, mousing over a rare logs `rare seen npcID=... how=mouseover layer=...`.

### P2-04 · RareAlerts · Claude · deps: P2-03, P1-05, P1-06
1. Module `RareAlerts` (`yieldsTo = { "RareScanner" }`). On `OTR_RARE_SEEN` for an alive rare: toast with name, level, distance hint ("nearby" for nameplate), sound (setting), and a **Target** secure button whose macro is `/targetexact <name>`.
2. Per-NPC cooldown (default 5 min) and per-character options: alert for all rares / pack rares / watchlist only; sound on/off and which sound; toast on/off; screen flash on/off.
3. Combat: if the button macro must change during combat, show the toast without the button and a note; the queued attribute change applies after combat (P1-05).
4. Specs: cooldown, filter modes, dead rares don't alert.

**Done when:** Gary gets a toast and sound for a real rare, clicks Target, and the rare is targeted. Screenshot of the toast.

### P2-05 · Watchlist and Rares tab · Claude · deps: P2-04, P1-08
1. Hub tab **Rares**: known rares for the current zone (pack + discovered), each with last seen time, layer, state (alive/dead/tamed), watch toggle.
2. Watchlist stored per character (a hunter's taming list differs from a mage's).
3. `/ride watch <name or npcID>` and `/ride unwatch ...`.

**Done when:** Gary adds The Rake to the watchlist on Torrant only; the priest's list is empty.

### P2-06 · Layer detection · Both · deps: P2-01
1. Service `ns.Layers` (module `Layers`): collect zoneUIDs from creature GUIDs seen in the open world (not instances); current layer = most frequent zoneUID among the last N creatures in the current zone, with a confidence value.
2. Fire `OTR_LAYER_CHANGED` when the dominant zoneUID changes with good confidence (e.g. after joining a group on another layer).
3. Show the layer in the minimap tooltip and the Rares tab. Layer numbers are server-internal ids; label them `L<last 3 digits>` for display.
4. Field check: Gary notes when he changes layer (joins a group); the log should show `layer changed`.

**Done when:** the layer stays stable while Gary walks around one zone and changes once after a known layer change. Update FOREVER_CONSTRAINTS C12.

### P2-07 · Sightings and respawn windows · Claude · deps: P2-03, P2-06
1. Module `Sightings`: append each `OTR_RARE_SEEN` to `ns.db.global.sightings[npcID]` (schema in DATA_SCHEMAS.md), cap 50 per NPC.
2. Respawn window per NPC and layer: after a `dead` or `tamed` sighting, if the pack has `respawn.min/max`, window opens at `t + min`, closes at `t + max`. Without pack data, show only "last seen ... ago, dead/alive".
3. Learning: when Gary sees the same rare dead and later alive on the same layer, record the gap as an observed respawn (never shown as fact until there are 3+ observations; then show the observed range).
4. Rares tab shows "window opens in 34 min" / "window open now" per layer.
5. Specs: window math, layers kept separate, learning needs 3 observations.

**Done when:** specs pass; after Gary kills or tames a rare, the Rares tab shows the window (or "no respawn data yet").

### P2-08 · TameHelper · Both · deps: P2-04, P1-05
HUNTER only.
1. When the alert is for a tameable beast (pack or `UnitCreatureFamily` + classification), add a **Tame** button to the toast. Macro: the one Gary already uses, built from the name:
   ```
   #showtooltip Tame Beast
   /stopmacro [channeling]
   /cleartarget
   /targetexact <Name>
   /stopmacro [noexists][noharm][dead]
   /cast Tame Beast
   ```
2. Before offering: beast level ≤ player level; Gary has a free pet slot (`HasPetUI`, stable info per probe); show "stable full" instead of the button otherwise.
3. Toast line with the beast's notes from the pack (family, attack speed, abilities), marked "unverified" when `verified = false`.
4. `/ride tamemacro <Name>`: creates or updates a per-character macro named "Outrider Tame" (out of combat, typed command = key press). Uses the P4 installer if it exists; otherwise `CreateMacro`/`EditMacro` directly, checking free slots.

**Done when:** Gary clicks Tame on a real beast's toast and the tame starts (one click). Screenshot.

### P2-09 · PetStatus · Claude · deps: P1-07
HUNTER only.
1. Small movable frame: pet name, level, XP bar (`GetPetExperience`), happiness (`GetPetHappiness`: icon + text), loyalty (`GetPetLoyalty` if present), training points (`GetPetTrainingPoints` if present), focus.
2. Unhappy warning: toast once when happiness drops to unhappy (setting).
3. **Feed** secure button: macro `/cast Feed Pet` + `/use <bag> <slot>` of a food item the pet eats. Diet: `GetPetFoodTypes()`; item diet from a small data pack `Data/PetFood.lua` (itemID → diet, cited source, unverified until tested). Unknown items are never suggested.
4. Hide when no pet; update on `UNIT_PET`, `UNIT_HAPPINESS` (if it exists per probe), `PET_UI_UPDATE`, `UNIT_PET_EXPERIENCE`.
5. Specs with mocked pet API: unhappy transition warns once, food selection respects diet.

**Done when:** Gary sees his pet's status, feeds it with one click, and the unhappy warning fires once when it drops. Screenshot.

### P2-10 · BeastInfo tooltips · Claude · deps: P2-02
1. On beast tooltips (mouseover): family, "tameable" (hunter only), level vs yours, attack speed and abilities if known from the pack (labelled unverified when so), last seen info for rares.
2. Hook via `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, ...)` if present, else `GameTooltip:HookScript("OnTooltipSetUnit")`. Probe decides.
3. Two lines max by default; more with Shift held.

**Done when:** screenshot of a beast tooltip with the extra lines; non-beasts unchanged.

### P2-11 · Ammo · Claude · deps: P1-06
HUNTER only.
1. Ammo count in the ammo slot (`GetInventoryItemCount("player", 0)` or the slot per probe) and in bags; quiver/ammo pouch capacity.
2. Warn once per session under a threshold (default 200), again under 50. Add "buy ammo" to the town errand list later (P8-06).

**Done when:** warning fires once when Gary drops below the threshold (he can test with a stack split).

### P2-12 · Gate G2 field test · Both · deps: all P2
1. Gary hunts for an hour in zones with the target rares, `/ride mark G2` at the start, `/reload` at the end.
2. Claude: `tools/read-logs.ps1 -Mark G2 -Last 300 -Bugs`, screenshots of toast, Rares tab, pet frame.
3. Promote pack entries Gary saw to `verified = true` with capture coordinates.

**Done when:** gate criteria above are met; TASKS.md G2 ticked.

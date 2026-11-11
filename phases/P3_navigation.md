# Phase 3: Navigation and map

**Goal:** points of interest appear on the world map and minimap automatically as Gary approaches (like quest markers), clicking a pin shows a card about its subject with a "Waypoint" button, and Gary can ask for the nearest spirit healer, flight master, trainer or vendor and get a waypoint.

**Gate G3:** for five known NPCs, pins land where the game shows them (screenshot check: within a small distance on the map); `/ride near spirit` sets a waypoint to the nearest known spirit healer; pin cards open and show correct info; minimap pins appear and disappear with distance; no errors.

Modules: `Waypoints`, `MapPins`, `MinimapPins`, `PinCards`, `Nearest`, `POICapture`, `QuestieBridge` (requires Questie), `Coords`.

---

### P3-01 · Waypoint service · Claude · deps: P0-08
1. `ns.Waypoints:Set(mapID, x, y, title, opts)` / `:Clear()`. Backends in order: Blizzard user waypoint (`C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(...))` + `C_SuperTrack.SetSuperTrackedUserWaypoint(true)`) if the probe found them; TomTom if loaded (`TomTom:AddWaypoint`); our own arrow (P3-02) otherwise.
2. Fire `OTR_WAYPOINT_SET` / `OTR_WAYPOINT_CLEARED`. Auto-clear on arrival (within 10 yards, setting).
3. `/ride way <x> <y> [title]` for the current map.

**Done when:** `/ride way 50 50 test` shows a waypoint with whichever backend exists; log names the backend.

### P3-02 · Fallback arrow · Claude · deps: P3-01
Only if no Blizzard waypoint and no TomTom.
1. Small arrow frame: direction from player facing (`GetPlayerFacing`, may be nil in instances: hide then) and world positions (`C_Map.GetWorldPosFromMapPos`), distance in yards.
2. Runs an OnUpdate only while a waypoint is active, throttled to 20 fps.

**Done when:** arrow points correctly while Gary turns and walks to a waypoint; screenshot.

### P3-03 · World map pins · Claude · deps: P0-08
1. If `WorldMapFrame:AddDataProvider` and `MapCanvasPinMixin` exist: a data provider that adds pins for POIs and rares on the shown map, with pin templates created via `CreateFromMixins`. Otherwise use HereBeDragons-Pins (check its license before embedding; record in DECISIONS).
2. Pin kinds and icons per POI kind; rares show alive/dead/window state color.
3. Filters in the hub (per character): which kinds to show.
4. "Auto as you approach": pins for a POI become visible on the world map once Gary has been within N yards of it (setting: show all known / only discovered by me / only near me).

**Done when:** opening the map in a zone with known POIs shows pins; toggling a kind hides them; screenshot.

### P3-04 · Minimap pins · Claude · deps: P3-03
1. Pins on the minimap for POIs within the minimap radius; edge arrows optional for watched rares outside it.
2. Math: convert map coords to world yards, compare with player position, scale by minimap zoom (`Minimap:GetZoom()`, indoor/outdoor), rotate if `rotateMinimap` CVar is on.
3. Update throttled (5 per second) only while moving.
4. Specs for the coordinate math (pure functions).

**Done when:** pins appear when Gary approaches a known vendor and vanish as he leaves; correct with rotating minimap on and off.

### P3-05 · Pin cards · Claude · deps: P3-03
1. Clicking a pin opens a card: name, kind, level, notes, last seen and respawn window for rares, beast details for tameables, vendor role tags, and buttons: **Waypoint**, **Watch** (rares), **Copy coords**.
2. Portrait via `SetPortraitTextureFromCreatureDisplayID` only if a displayID is known; otherwise a kind icon.
3. Card is a normal frame (no secure actions), so it works in combat.

**Done when:** Gary clicks The Rake's pin and sees its card; Waypoint works.

### P3-06 · POI capture · Claude · deps: P2-01
1. Extend Discovery (or module `POICapture`) to turn interaction captures into POIs: flight masters (`TAXIMAP_OPENED`), innkeepers, trainers (by class/profession from the trainer frame title), vendors (food/ammo/reagent detection from the merchant item list), repair (`CanMerchantRepair`), bank, auctioneer, stable master, mailbox (`MAIL_SHOW`, object position = player position).
2. Spirit healers: captured on `CONFIRM_XP_LOSS`/gossip with the healer, or when Gary is a ghost and the spirit healer is targeted.
3. Each POI keeps capture quality and count; repeated captures refine the average position.

**Done when:** after a city visit the Nearest command finds the vendors and trainers Gary talked to.

### P3-07 · Nearest · Claude · deps: P3-01, P3-06
1. `/ride near <kind>` (spirit, flight, inn, repair, ammo, food, trainer, mailbox, bank, ah, stable): nearest known POI of that kind on the current continent (distance in world yards), faction-filtered, sets a waypoint and prints name and distance.
2. Hub Overview gets quick buttons for the common ones.
3. When Gary dies (`PLAYER_DEAD`), optionally show "Nearest spirit healer" with a waypoint button (setting).

**Done when:** after dying near The Rake's area, the nearest spirit healer waypoint is set correctly (Gary confirms in game).

### P3-08 · Questie bridge · Claude · deps: P3-03
1. Module `QuestieBridge`, `requires = { "Questie" }`. Read Questie's public API inside pcall (find the current entry points by reading Questie's source in Gary's AddOns folder; do not copy code).
2. Show "on the way" quests: objectives near the current waypoint route in the Rares tab or a small list.
3. If the API is missing or changed, log one warning and switch off.

**Done when:** with Questie installed, the bridge lists nearby objectives; without it the module shows "needs Questie".

### P3-09 · Discovery privacy and controls · Claude · deps: P3-06
1. Hub: discovery on/off, what is captured, "forget this NPC", clear all discovered data (with confirm).
2. Data never leaves the PC unless Phase 8 sharing is switched on.

**Done when:** toggles work and are per account (discovery data is account-wide).

### P3-10 · Coordinates · Claude · deps: P3-01
1. Player coordinates under the minimap (setting) and cursor coordinates on the world map.
2. `/ride coords` prints current mapID and x, y with two decimals (for Gary to report locations to Claude).

**Done when:** coords show and match `/dump C_Map.GetPlayerMapPosition(...)`.

### P3-11 · Redrawn zone check · Both · deps: P3-06
1. Gary visits three known NPCs in Mulgore and three in a zone believed unchanged (e.g. Durotar).
2. Claude compares captured positions with Classic-era coordinates from a cited source.

**Done when:** FOREVER_CONSTRAINTS C14 updated with the measured difference per zone; pack rules updated (which zones may use Classic coordinates).

### P3-12 · Gate G3 · Both · deps: all P3
Screenshot check of five pins against the in-game NPC positions, nearest spirit healer test, pin card test, minimap approach test.

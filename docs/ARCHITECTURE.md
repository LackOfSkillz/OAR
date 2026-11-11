# Architecture

## Layers

```
 ┌──────────────────────────────────────────────────────────────────────┐
 │ Feature modules  (Modules/*)  one per feature, switchable per char   │
 │  P2 PetStatus TameHelper BeastInfo Discovery RareScan RareAlerts ... │
 │  P3 Waypoints MapPins MinimapPins Nearest QuestieBridge ...          │
 │  P4 MacroLibrary RankCheck   P5 Inventory Professions Prices Fishing │
 │  P6 GearScore UpgradeFinder  P7 Skin TooltipPlus   P8 RareShare ...  │
 ├──────────────────────────────────────────────────────────────────────┤
 │ Shared services                                                      │
 │  UI kit (Theme, Widgets, Hub)   Data registry + packs   Comm (P8)    │
 │  Snapshot/Advice (P9, dormant)  Bridges to other addons (hook only)  │
 ├──────────────────────────────────────────────────────────────────────┤
 │ Core  Init · Compat · Log · Errors · Events · Combat · Serialize ·   │
 │       DB · Profiles · Modules · Conflicts · Probe · Slash · Boot     │
 └──────────────────────────────────────────────────────────────────────┘
          WoW Forever client API (guarded by Compat; facts in PROBE_RESULTS.md)
```

A module may use Core and shared services. Modules never call each other's internals directly; they talk through internal messages (`ns.Events:Fire("OAR_RARE_SEEN", info)`) or a small public table the providing module documents in its header (e.g. `ns.Waypoints:Set(mapID, x, y, title)`). That keeps any module removable.

## Lifecycle

| Moment | What happens (Core/Boot.lua) |
|---|---|
| File load (TOC order) | Each file adds itself to `ns`. Modules call `ns:NewModule`, which registers settings defaults. No game state yet. |
| `ADDON_LOADED` (ours) | SavedVariables are available: `Log:Attach`, `DB:Init` (migrations, defaults, character section), `Errors:Attach`, session start, `OnInitialize` for every module. |
| `PLAYER_LOGIN` | BugGrabber hook, conflict detection, settings page, minimap button, then `OnEnable` for each module that should run for this character (class, required addons, yields, player choice). |
| `PLAYER_LOGOUT` (also on /reload) | `lastSave` stamp, errors saved. WoW writes `OAR.lua`. |

## Saved data

One account-wide file: `WTF\Account\<ACCOUNT>\SavedVariables\OAR.lua`.

```lua
OAR_DB = {
  schema = 1,
  global = {                 -- account-wide
    debug, minimap = { hide, angle }, loads, sessions = { ... }, lastSave = { ... },
    probe = { ... },         -- P0-08
    discovered = { ... },    -- P2-02 NPC/POI captures, keyed by npcID
    sightings = { ... },     -- P2-07 rare sightings by npcID and layer
    prices = { ... },        -- P5 if no auction addon is installed
    inventory = { ["Char-Realm"] = { bags, bank } },  -- P5-02
  },
  chars = {
    ["Torrant-Realm"] = {
      meta = { class, race, level, faction, logins, lastLogin, created },
      modules = { [ModuleName] = { enabled = nil|true|false, settings = { ... } } },
      hub = { point, x, y, shown },
    },
  },
}
OAR_Log = { lines = { {t, s, l, m, x}, ... up to 600 }, errors = { ... up to 50 } }
OAR_Snapshots = { ["Torrant-Realm"] = { ... } }   -- P9 groundwork, written only by /oar snap
```

"Character aware" means: `ns.db.char` is always the logged-in character's section; module defaults can depend on class (`spec.classes`); the hub shows only what applies; export/import/copy move a setup between characters.

Schema changes: bump `ns.SCHEMA` in `Core/Init.lua`, add `DB.migrations[old] = function(db) ... end`, add a spec that loads an old-schema file and checks the result. Back up SavedVariables before deploying a migration.

## Module system

`ns:NewModule(name, spec)` with spec fields: `title`, `phase`, `order`, `classes`, `requires`, `yieldsTo`, `defaultEnabled`, `defaults`. Lifecycle hooks: `OnInitialize`, `OnEnable`, `OnDisable`, optional `Snapshot`. Helpers: `self:On(event, fn)`, `self:Off(event)`, `self:Settings()`, `self:Secure(label, fn)`, `self:Info/Debug/Warn/Error`. A module whose `OnInitialize` or `OnEnable` throws is marked broken and switched off; the rest keep running.

Decision order for whether a module runs: class allowed → required addons loaded → not broken → player's explicit choice → yields to an installed addon → `defaultEnabled`.

## Events

One hidden frame in `Core/Events.lua`. Handlers are keyed by owner so `OffAll(module)` removes everything. Each handler runs in `ns.Safe`. Internal messages share the dispatcher and must start with `OAR_`. Conventions for message names are in CONVENTIONS.md.

## Combat safety

`ns.Combat:Run(label, fn, key)` runs now out of combat, or queues until `PLAYER_REGEN_ENABLED`. Keyed requests collapse (only the latest runs). Secure buttons (target/tame/cast) are pre-created out of combat in a pool and only have their attributes changed out of combat.

## Data packs

Plain tables registered with `ns.Data:Register(kind, packName, entries)`, validated against `Data.SCHEMAS`. Small packs live in `addon/OAR/Data/`. Big ones (gear sources, recipes) become separate load-on-demand addons in `addon/OAR_Data_<Name>/` with `## LoadOnDemand: 1` and `## Dependencies: OAR`, loaded with `ns.Compat.LoadAddOn` when a module first needs them. Formats: DATA_SCHEMAS.md.

Self-building data: Discovery (P2-02) records NPCs, vendors, trainers, flight masters and gathering nodes Gary actually meets, with Forever-native coordinates. Shipped packs start small and verified; discovery fills the rest.

## Bridges to other addons

A bridge is a module with `requires = { "OtherAddon" }` that reads the other addon's public API inside `pcall` and translates it into our internal messages or data. If the other addon changes, the bridge logs a warning and switches itself off. Bridges never write into the other addon's SavedVariables.

## UI

`UI/Theme.lua` holds all colors, fonts and spacing. `UI/Widgets.lua` builds windows, buttons, checkboxes and text dialogs from those tokens. `UI/Hub.lua` is the one main window; modules add sections with `ns.Hub:AddSection(title, builder)` (extend Hub into tabs in P1-08). Phase 7 skins Blizzard frames with hooks and textures only, and steps aside if ElvUI or EllesmereUI is loaded.

## Performance budget

Measured with `/oar perf` (P1-12): core idle under 1.5 MB memory, under 0.1 ms per frame average; no `OnUpdate` scripts running when nothing is visible; nameplate scans throttled to 4 per second; data packs loaded on demand.

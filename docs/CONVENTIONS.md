# Conventions

## Lua

- WoW runs Lua 5.1. No `goto`, `//`, bit operators, `utf8` library, `table.unpack` (use `unpack`), `#` on tables with holes, or `%d` formatting of numbers that can exceed 2^31 (use `%.0f`).
- `xpcall(f, handler)` takes no extra arguments in stock 5.1 (our tests); wrap arguments in a closure, or just use `ns.Safe(where, fn, ...)`.
- Two-space indent, `local` everything, early returns over nesting. Lines under 120 characters where practical.
- File header comment: what the file does and anything non-obvious about the client it relies on.
- Comments explain why, not what.
- No `os`, `io`, `require`, `loadfile`, `dofile` in addon code (WoW does not have them). `loadstring` is banned for data we did not write (imports use `ns.Serialize`).

## Names

| Thing | Pattern | Example |
|---|---|---|
| Module | PascalCase identifier | `RareAlerts`, `PetStatus` |
| Module file | `Modules/<Name>.lua`, or `Modules/<Name>/` for multi-file | `Modules/Hunter/PetStatus.lua` |
| Named frame | `Outrider_<Module><Thing>` | `Outrider_RareAlertsToast` |
| Internal message | `OTR_<NOUN>_<VERB>` | `OTR_RARE_SEEN`, `OTR_WAYPOINT_SET`, `OTR_PROFILE_CHANGED` |
| Settings keys | lowerCamel | `soundOn`, `alertCooldown` |
| Data pack file | `Data/<Kind>_<Region>.lua` | `Data/Rares_Kalimdor.lua` |
| Slash subcommand | lower, one word | `/ride rares`, `/ride near spirit` |
| Task IDs in commits | `Px-nn: summary` | `P2-04: rare detector reads nameplates` |

## Module template

```lua
-- Modules/RareAlerts.lua
-- Toast + sound when a known rare or any rare-classified mob is seen.
-- Listens to OTR_RARE_SEEN from RareScan. Secure "Target" button is pooled.

local ADDON, ns = ...
local M = ns:NewModule("RareAlerts", {
  title = "Rare alerts",
  phase = "P2",
  order = 30,
  yieldsTo = { "RareScanner" },        -- step aside by default if installed
  defaults = { sound = true, cooldown = 300, toast = true },
})

function M:OnInitialize()
  -- once, SavedVariables available, no UI yet
end

function M:OnEnable()
  self:On("OTR_RARE_SEEN", self.OnRareSeen)
  self:Secure("build toast", function() self:BuildToast() end)
end

function M:OnDisable()
  if self.toast then self.toast:Hide() end
end

function M:OnRareSeen(_, info)
  local s = self:Settings()
  -- ...
  self:Info("alert %s (%d) layer %s", info.name, info.npcID, tostring(info.layer))
end

function M:Snapshot()          -- optional, plain data for the future advisor
  return { lastAlert = self.lastAlert }
end
```

Rules:
- Register events only with `self:On` (auto-cleanup on disable).
- Never keep references to another module's private fields. Use its documented public table or messages.
- Settings defaults belong in the spec, not scattered `or` fallbacks.
- Account-wide data: `ns.db.global.<moduleLowerName>` created in `OnInitialize`.

## Events and throttling

- Prefer specific events over `OnUpdate`. If you need a ticker, use `C_Timer.NewTicker` via Compat, stop it in `OnDisable`, and only run while needed.
- Scans driven by frequent events (nameplates, bags) are throttled: collect, then process at most every 0.25 s.
- `BAG_UPDATE_DELAYED` instead of `BAG_UPDATE`.

## Secure buttons

- Template `SecureActionButtonTemplate`, attributes `type = "macro"` and `macrotext`, created out of combat via `self:Secure`.
- Attribute changes only out of combat. If a rare appears in combat, show the toast but leave the button with its previous macro and note "out of combat to retarget" (or queue the update).
- Never call protected functions (`CastSpellByName`, `TargetUnit`, `UseContainerItem` in combat) from Lua. Clicking a secure button does it.

## Logging

- `self:Info` for things Claude needs to verify a task (one line per meaningful action, not per frame).
- `self:Debug` for detail; only stored with `/ride debug on`.
- `self:Warn` for degraded features ("Questie API changed, bridge off").
- Errors come from `ns.Safe` automatically; don't log the same error twice.
- Include IDs in log lines (`npcID`, `mapID`, `itemID`) so logs can be checked against data.

## UI

- All colors, fonts and spacing from `ns.Theme`. No hard-coded RGB in modules.
- Windows via `ns.UI:Window`, buttons via `ns.UI:Button`, text via `ns.UI.Text`.
- Every window: movable, position saved per character, Esc closes it, clamped to screen.
- No frame is shown at login unless the player left it open.
- Strings shown to the player live in one table per module (`local L = { ... }`) at the top of the file so localization is a later mechanical change.

## Data

- IDs, not names, as keys. Names are display only (they can differ by locale).
- Coordinates are map fractions 0..1 with the `mapID` they belong to.
- Every entry has `verified` (boolean) and, where it came from outside the game, `source`.
- Packs contain no functions.

## Tests

- One spec file per area: `tests/spec/<area>_spec.lua`, receives `T, mock`.
- Use `mock.new(opts)` for a fresh client, `game:loadAddon()`, `game:login()`, `game:fire(event, ...)`, `game:slash("...")`, `game:logout()` (returns SavedVariables text for the next `mock.new({ savedVariables = text })`).
- When a module needs a new API, add a minimal fake to `tests/lib/wowmock.lua` that returns the same shape as the real one, and note in PROBE_RESULTS.md whether the real one exists.
- Test behavior that can be wrong (decisions, parsing, scoring, validation, persistence), not that a frame has a size.

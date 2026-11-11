# Changelog

## 0.1.1 (review fixes, 2026-11-11)

- DB: migrations run on a copy; a missing step, a failing step, or a file from a newer OAR now puts the session in safe mode (saved file left untouched, temporary settings in memory) instead of silently continuing.
- Resets rebind the live settings immediately; reset all writes nothing back.
- Combat queue: capped at 100 jobs, `Combat:Cancel(key)`, and a module toggle queued in combat re-reads the wanted state when it finally runs.
- Advice loader: IDs must be positive integers, coordinates finite 0..1, panels from a whitelist, waypoint maps must exist on this client, WoW escape codes stripped from text, every item carries a confidence (verified / community / inferred / unknown).
- Data packs: optional `confidence` and `verifiedOn` provenance fields, validated.
- 11 new specs (71 total).

## 0.1.0 (build package, 2026-11-11)

- Core: namespace, compat layer, ring-buffer log, error catcher (BugGrabber-friendly), event dispatcher with owners, combat queue, serializer with export strings, account-wide DB with per-character sections and migrations, profiles (export, import, copy from character), module system (class, required addons, step-aside, player choice), conflict detection, API probe.
- UI: theme tokens, widget kit, hub window, minimap button (LibDBIcon when available), Options > AddOns page.
- Advisor groundwork (dormant): `/oar snap` snapshot, advice loader with action whitelist, empty Advice.lua.
- Data: registry with schema checks; hunter macro pack (19 hunter + 2 general macros, unverified except the tame macro).
- Modules: Welcome (reference module).
- Tests: WoW client mock, 60 specs. Tools: find-wow, deploy (build stamp, restart detection), read-logs, backup/restore, screenshots, package, lua.py.

# Phase 9: AI advisor (parked; start only when Gary says so)

**Goal:** a model on Gary's PC (local, or a frontier model he configures) reads a snapshot of the character and offers a short list of options in game; choosing one only does harmless, non-protected things (waypoint, track quest, open a panel, show an item). Design: `docs/AI_ADVISOR_LATER.md`.

**Gate G9:** Gary types `/oar ask`, reloads, and within a minute sees 3 to 8 relevant options for Torrant; malformed or stale advice files are ignored safely; nothing leaves the PC unless Gary configured a cloud model; no option can cast, target, buy or move anything.

Already in the code: `Advisor/Snapshot.lua`, `Advisor/AdviceLoader.lua` (whitelist and validation, tested), empty `Advisor/Advice.lua`, `tools/deploy.ps1 -KeepAdvice`.

---

### P9-01 · Richer snapshots · Claude · deps: P2–P6 modules
1. Each module adds `Snapshot()` with plain data the advisor would need: Rares (watchlist, last sightings), PetStatus (pet family, level, happiness), Professions (skills, queue), Gear (top candidates), Inventory (money, notable items), quests (log titles and IDs).
2. Keep the snapshot under ~50 KB; spec checks size and that it is plain data (no functions, no frames).

**Done when:** `/oar snap` + `/reload` gives a complete snapshot; `tools/read-logs.ps1 -Section snapshots` shows it.

### P9-02 · `/oar ask` · Claude · deps: P9-01
1. Bind `Snapshot:AskAdvisor()` to `/oar ask` (out of combat; collects and reloads; typing the command is Gary's key press).
2. Advice panel (hub tab **Advisor**): list of `ns.Advice:Load()` items with title, why, and a button that performs the whitelisted action. Shows "no advice yet" / "advice is stale" reasons from the loader.

**Done when:** with a hand-written test Advice.lua, the panel shows the items and each button does its harmless action.

### P9-03 · Companion app · Claude · deps: P9-02
1. `companion/` (Python or Node, Gary's choice): watches `WTF\...\SavedVariables\OAR.lua`, parses it safely (a Lua table parser, never executing it), exposes an MCP server with read-only tools: `list_characters`, `get_snapshot(char)`, `get_rare_log(char)`, `get_gear(char)`, `get_professions(char)`, plus one write tool `write_advice(char, items)` that validates against the same whitelist and writes `Interface\AddOns\OAR\Advisor\Advice.lua` as plain data.
2. Never writes anything else; never runs while unconfigured.

**Done when:** an MCP client (Claude Desktop or Claude Code) can call the tools and get Torrant's snapshot.

### P9-04 · Model wiring · Both · deps: P9-03
1. Config file for the model: local (Ollama / LM Studio endpoint) or cloud (Gary's own API key, stored only on his PC). A prompt that asks for 3 to 8 options using only the whitelisted actions and real IDs from the snapshot.
2. Watch mode: on snapshot change, ask the model, write advice; Gary reloads to see it.

**Done when:** a full round trip works with a local model and with a cloud model if Gary wants one.

### P9-05 · Safety tests · Claude · deps: P9-04
1. Specs and companion tests: unknown actions dropped, wrong character ignored, stale snapshot ignored, oversized files rejected, Lua injection in strings (e.g. `]]` and `--`) cannot break out of the data file (the writer escapes with `%q`).

**Done when:** all safety tests pass.

### P9-06 · Gate G9 · Both · deps: all P9
Run the gate checks; tick G9.

---

# Release (any time after G3, Gary's call)

### R-01 · Packaging · Claude
`tools/package.ps1` builds `dist\OAR-<version>.zip`. Use PowerShell 7 for release zips (Windows PowerShell 5.1's Compress-Archive writes backslash paths some sites reject) or 7-Zip. Include the data addons.

### R-02 · Changelog and version · Claude
`CHANGELOG.md` per release; semantic version in the TOC; `/oar version` shows it.

### R-03 · Public release decision · Gary
Q2 and Q3 in DECISIONS (public or not, license). If public: CurseForge and Wago project pages, screenshots, a short description that only claims what has been verified on Forever.

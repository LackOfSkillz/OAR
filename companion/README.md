# Outrider companion app

A small program on Gary's PC that lets an AI model read what Outrider saved and
leave suggestions in the game's Advisor tab. Python, standard library only:
nothing to install, no network.

## What it does

- Reads `WTF\Account\<account>\SavedVariables\Outrider.lua` as plain data.
  It never runs that file: anything that is not data (code, function calls)
  is refused.
- Offers these tools to an MCP client (Claude Desktop, Claude Code):
  - `list_characters`: characters Outrider knows, and when each was last snapshotted.
  - `get_snapshot(character)`: level, zone, money, gear, quest log, module data from `/ride ask`.
  - `get_rare_log(character)`: rare sightings and the watchlist.
  - `get_gear(character)`: worn items, stat weights, best nearby upgrades.
  - `get_professions(character)`: skills, recipe names, craft queue.
  - `write_advice(character, items)`: the only write. It accepts 4 actions
    (waypoint, track_quest, open_panel, show_item), drops anything else, and
    writes only `Interface\AddOns\Outrider\Advisor\Advice.lua`.
- Stays off until `companion/config.json` says `"enabled": true`.

## Set up (once)

1. Copy `companion/config.example.json` to `companion/config.json` and set
   `"enabled": true`. Leave the two paths empty to use the ones in
   `tools/local.json`.
2. Add it to the MCP client. For Claude Code, from the repo root:

   ```
   claude mcp add outrider -- py -I companion/run.py
   ```

   For Claude Desktop, add to its `claude_desktop_config.json`:

   ```json
   { "mcpServers": { "outrider": { "command": "py",
       "args": ["-I", "C:\\Users\\Administrator\\Dev\\OAR\\companion\\run.py"] } } }
   ```

## Use

1. In game, out of combat: `/ride ask` (takes a snapshot and reloads).
2. Ask the model for advice; it reads the snapshot and calls `write_advice`.
3. In game: `/reload`, then open the hub's **Advisor** tab. Click a suggestion
   to do it. Nothing happens on its own.

Advice answers one snapshot: after the next `/ride ask` the old advice shows as
stale until the model writes new advice.

Note: `tools/deploy.ps1` replaces the Outrider folder, which removes
`Advice.lua`; deploy with `-KeepAdvice` to keep it.

## Tests

`py -I companion/tests/test_companion.py` (also run by `tools/test.ps1`).

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
  - `read_clipboard_snapshot` / `advice_to_clipboard(character, answersSnapshot, items)`: the no-reload route (Windows clipboard, local only).
  - `write_advice(character, items)`: the only file write. It accepts 4 actions
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

## Use (no reload)

1. In game, out of combat: `/ride ask` (or the Ask button in the Advisor tab)
   shows a snapshot code, already selected. Press Ctrl+C.
2. Tell Claude "advise" (or `/advise`). It reads the code from the clipboard
   (`read_clipboard_snapshot`) and puts an advice code on the clipboard
   (`advice_to_clipboard`).
3. In the Advisor tab: **Paste advice** (or your Paste key), Ctrl+V. The suggestions show
   at once. Click one to do it. Nothing happens on its own.

Older route (needs a reload): `/ride ask reload`, then `write_advice`, then
`/reload` in game.

Advice answers one snapshot: after the next `/ride ask` the old advice shows as
stale until the model writes new advice.

Note: `tools/deploy.ps1` replaces the Outrider folder, which removes
`Advice.lua`; deploy with `-KeepAdvice` to keep it.

## Tests

`py -I companion/tests/test_companion.py` (also run by `tools/test.ps1`).

## Ask Outrider (local model, sprint 1 of Outrider Intelligence)

A grounded answer to "what should I do?" from a model running on your own PC.
The model only explains and orders Outrider's own What now? steps; every
place, id and action is rebuilt from Outrider's data and checked again in game.

1. Run a local model server that speaks the OpenAI chat API (Ollama, LM Studio,
   vLLM, llama.cpp). In `companion/config.json` add:
   `"intelligence": {"enabled": true, "provider": "openai-compatible",
   "baseUrl": "http://127.0.0.1:11434", "model": "<your model>", "allowRemote": false}`.
   A server on another machine (a GX10 on the LAN) needs `"allowRemote": true`;
   your data then travels to that machine.
2. In game: Advisor tab > Ask (copy snapshot), Ctrl+C.
3. `python -m outrider_companion.intelligence.ask "I have 45 minutes, what should I do?"`
   (run in `companion/`). The advice code goes to the clipboard.
4. In game: Advisor tab > Paste advice. No reload.

Without a model (or with `--no-model`) you get Outrider's own top steps.
Privacy and limits: `docs/AI_PRIVACY_AND_TRANSPORT.md`.

## Cloud models (optional, off by default)

Anthropic, OpenAI or Gemini instead of a local model:
1. `python -m outrider_companion.intelligence.keys set anthropic` (the key is
   asked for hidden and stored in Windows Credential Manager).
2. In `companion/config.json`: `"intelligence": {"enabled": true, "provider": "anthropic",
   "model": "claude-opus-5-5", "dailyTokenCap": 100000}`.
3. `python -m outrider_companion.intelligence.ask --preview`: everything that
   would be sent. If you're happy with it, add `"cloudConsent": true`.
4. `python -m outrider_companion.intelligence.doctor` shows what is set up.

Character names are never sent. Each answer costs tokens on your account;
the cap stops calls for the day once reached.

## The Ask Outrider window (no command line)

`pythonw -m outrider_companion.intelligence.window` (run in `companion/`).
In game: your Ask key (or Advisor > Ask), Ctrl+C. With "Answer by itself"
on (the default) the window notices the new snapshot code on its clipboard and
asks; otherwise Read snapshot, Ask (Enter). The answer is copied; in game:
your Paste key (or Paste advice), Ctrl+V; it applies without an Accept click.
Each code you copy is one model call (the daily cap still applies). Preview shows exactly
what a model would receive; Status shows the setup; Stop waiting lets go of
a slow model. It never touches the game.


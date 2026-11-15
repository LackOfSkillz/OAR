# Ask Outrider: user guide

Outrider's What now? page works on its own with no AI. "Ask Outrider" adds a
helper that explains and orders those steps for your question, with a plan
that fits your time. It never plays for you: every card is a click.

## Why use it
- "I have 45 minutes, what should I do?" -> 3 steps in order with minutes.
- "Should I run Deadmines or keep questing?" -> both side by side and a verdict.
- It only points at steps Outrider found in your own game data, and says
  what it couldn't check.

## Three ways to get answers
1. **Claude (MCP), no setup beyond Claude Code/Desktop:** copy the snapshot,
   tell Claude "plan my clipboard"; it uses Outrider's tools and puts the
   answer on your clipboard.
2. **A local model on this PC (private, free):** install Ollama or LM Studio,
   pull an instruction model (8B or larger follows the format well), set the
   `intelligence` section in `companion/config.json`.
3. **A cloud model (costs per answer):** store a key with the keys command,
   preview the payload, set `cloudConsent`. A daily token cap protects you.

## Once: two keys
Esc > Options > Key Bindings > AddOns > Outrider: bind **Ask** and **Paste
advice** (for example Ctrl+F1 and Ctrl+F2).

## Every time (the fast way)
1. In game: press your **Ask** key, then Ctrl+C. (Or the Advisor tab's Ask,
   with a question and minutes typed first.)
2. The Ask Outrider window, left open with "Answer by itself" on, sees the
   new code, asks and copies the answer (its title says "answer ready").
3. In game: press your **Paste** key, then Ctrl+V. It applies at once and opens
   the Advisor tab. Click a card to set a waypoint or open a page. Mark cards
   Useful, Wrong data or Done.

Every step is a key you press; nothing in the game happens on its own (D18).
Without the window: the ask command or Claude, then step 3.

## Supported models
Any server that speaks the OpenAI chat API (Ollama, LM Studio, vLLM,
llama.cpp server); Anthropic (Claude, default `claude-opus-5-5`); OpenAI;
Gemini. Small models sometimes ignore the answer format: you then get
Outrider's own picks, labelled.

## Privacy
Your character's name, realm, guild and other players are never sent. See
`docs/AI_PRIVACY_AND_TRANSPORT.md` and `ask --preview` for exactly what is.

## Troubleshooting
| You see | Do |
|---|---|
| "No model answer this time (no model is set up)" | Normal without a model; set one up or use Claude |
| "can't reach ... (is it running?)" | Start the local model server; `doctor --check` |
| "only this PC (127.0.0.1) is allowed" | The model is on another machine: add `"allowRemote": true` if you accept that |
| "HTTP 401 ... check the API key" | `keys set <provider>` again |
| "HTTP 404 ... check the model name" | Fix `model` in the config; `doctor --check` lists local models |
| "cloud models are off until..." | Run `ask --preview`, then add `"cloudConsent": true` |
| "today's cloud token cap is reached" | Wait for tomorrow or raise `dailyTokenCap` |
| In game: "The advice answers an older snapshot" | Click Ask again, then ask again |
| In game: cards missing | They didn't match this snapshot's steps (by design); ask again |

## Limits
Quest, gear and dungeon places partly come from Classic data and may have
moved on Forever. Times are estimates. Rare respawn windows are guesses from
few sightings. The model's summary is its own words; the cards are Outrider's.

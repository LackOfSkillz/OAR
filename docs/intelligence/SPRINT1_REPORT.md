# Outrider Intelligence, sprint 1: report for Gary (2026-11-15)

Stopped here as the handoff asks: AI-00, AI-01 and the narrow AI-02 slice are
built. Nothing is published, merged to main or switched on for anyone.
Commits on `p1-foundation`: 726ce60, ac62c9b, 8bcfeed, 1b03788.

## What works now
- `/ride ask` (Advisor > Ask) puts What now?'s top 12 steps into the snapshot
  code: id, title, why, where, minutes, an evidence label (observed / community /
  inferred) and the exact place Outrider recorded (map and coordinates) or a
  panel to open. Only when you ask; never at logout.
- The companion turns that into a private context (no character, realm, guild
  or other players' names), asks a local model for up to 3 steps that fit your
  question, and builds the advice code. The model can only choose step ids;
  every card's title, waypoint and action comes from Outrider's own data.
- If no model is set up, or it's down, slow or answers badly, you get
  Outrider's own top 3 steps, saying so.
- Pasting the code into the Advisor shows a headline, a summary, what wasn't
  checked, and the cards. The addon checks everything again: the right
  character and snapshot, step ids from that snapshot, waypoints exactly where
  Outrider recorded them, the 4 safe actions only. No reload.
- Proven offline with your real saved data for Khreos (hunter) and
  Fingerwiggle (mage): 3 grounded cards each, 0 errors (`tools/ask_demo.lua`).

Tests: 493 Lua specs, 16 companion tests and 19 intelligence tests (poisoned
answers, injected text, unknown ids, moved waypoints, wrong snapshot,
timeouts, server down, redirects, corrupt codes, a real local HTTP round trip).

## Not done or not verified
- No real model has answered yet: there is no Ollama/LM Studio on this PC.
  Your GX10 would work over the LAN with `"allowRemote": true` (your data then
  goes to that box).
- Nothing has run in the real game yet (the new Advisor answer card, the
  snapshot with steps).
- No question box in game yet: you type the question when you run the ask
  command. No MCP tool for the steps yet (the snapshot code carries them).
- Price ages, cancellation and a payload preview are next sprint.

## Risks
- Small local models may ignore the JSON format; they then fall back to
  Outrider's picks (safe, but less helpful). Pick a model that follows
  instructions well (8B+ instruct).
- Quest, gear and dungeon places still come from Classic data; answers say so.
- The copy/paste loop has three steps; it stays the only transport until a
  safer one passes the spec's gates.

## In-game check (about 5 minutes)
1. Exit WoW fully and start it again (several new files today).
2. On Khreos: open the hub, Advisor tab, click **Ask (copy snapshot)**, press Ctrl+C.
3. Tell Claude "ask is copied" (or run the ask command): the advice code goes to the clipboard.
4. Advisor tab: **Paste advice**. Check the answer card and the 3 cards; click one.
5. Do the same on the mage (Fingerwiggle) and the warrior (Littlesword).

To try a real model: install Ollama (or LM Studio) here or point at the GX10,
set the `intelligence` section in `companion/config.json` (see companion/README.md).

## Proposed next phase (needs your go-ahead)
AI-03: a question box and time budget in the Advisor tab, Plan and Compare
cards (dungeon vs quests, craft vs buy), "useful / wrong data / done" feedback
per card, and the read-only MCP tools (`get_pathfinder_candidates` and
friends) so Claude Desktop or Claude Code can ask directly. Cloud providers
(AI-04) and any in-game bridge (AI-05) only after that, and only with your OK.

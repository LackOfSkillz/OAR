# Outrider Intelligence, sprint 2 (AI-03): report for Gary (2026-11-15)

Built after your go-ahead. Nothing published or merged to main.
Commits on `p1-foundation`: 7b44e71, 0b2b1d5, 2eb028a.

## New
- **Ask from the game.** The Advisor tab has a question box, a minutes box and
  a gold Ask button. Your question and minutes go into the snapshot, so the
  companion answers what you asked; you no longer type it on the command line.
- **Plans that fit your time.** The answer comes with an order and minutes:
  urgent things first (repairs), steps in the same zone together, dungeons
  last. Times are the trip plus a typical time for that kind of step, and say
  so. What doesn't fit moves to "Won't fit in 45 minutes: ...".
- **Compare.** Ask "Should I run Deadmines or keep questing?" and the answer
  shows both side by side (time, how sure the data is, needs a group), facts
  from Outrider only; the model gives the verdict.
- **Feedback.** After clicking a card: Useful, Wrong data or Done. Wrong data
  and Done hide that step from What now? for a day; recent feedback goes to
  the companion so it avoids steps you flagged. Stays on your PC.
- **Claude as the planner (MCP).** New read-only tools let Claude Code or
  Claude Desktop see the steps (`get_pathfinder_candidates`,
  `get_candidate_explanation`) and answer with `plan_to_clipboard`; Outrider
  validates that answer exactly like a local model's. This works without
  installing any model: copy the snapshot, ask Claude, paste the advice.

Tests: 495 Lua specs, 16 companion and 28 intelligence tests, all green.

## Not verified
- Nothing in the real game yet (question box, plan line, feedback buttons).
- No real local model has answered yet (none on this PC).
- The MCP tools need the companion server restarted to show up in Claude.

## Try it (after a full game restart)
1. Advisor tab: type "I have 45 minutes, what should I do?", 45 in minutes, click Ask, Ctrl+C.
2. Tell Claude "plan my clipboard" (Claude uses the new tools) or run the ask command.
3. Paste advice: check the plan line, the cards, and click one; try Useful / Done.
4. Ask a compare question: "Should I run Deadmines or keep questing?"

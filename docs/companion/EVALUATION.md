# Competitive usefulness evaluation (OI08-11)

## Outrider's own baseline (measured)

**How it was run.** `companion/tests/test_eval25.py` sends 25 representative questions through the companion with **no model**: Outrider's deterministic picks on the shared test snapshot. To reproduce, run `py -I companion/tests/test_eval25.py --report`.

**How each answer is scored:**
- **useful:** at least one card, and every card comes from the snapshot's own candidates.
- **incorrect:** a card that isn't a candidate.
- **unanswered:** no card, or a compare question with no side-by-side rows.

**Results (2026-11-24):**

| Useful | Unanswered | Incorrect | Slowest |
|---|---|---|---|
| 22 | 3 | 0 | 0.35 ms |

**Unanswered** (side-by-side comparisons only come from a model answer):
- "Should I do the quest or train Alchemy?"
- "Which is better: repair or quest?"
- "Compare the quest and the profession"

**Limits:**
- One snapshot, one character, a mock client. Real questions on a real client are part of the live beta (OI08-12).
- Blind scoring wasn't possible: the scoring rule is mechanical, not judged.

## Competitors: not evaluated

Scoring other addons or assistants needs their **current public documentation** and a real client. That research wasn't done in this phase, so no comparison is made. Outrider makes **no "only addon" or "better than" claim**.

**Suggested set for a later run**, the specialist tools named in the gap analysis:
- Questie (quests)
- TomTom (waypoints)
- Auctionator and TSM (auctions)
- a leveling guide addon
- a general chat assistant given the same snapshot text

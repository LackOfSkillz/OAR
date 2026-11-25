"""OI08-11: 25 representative questions against Outrider's own baseline (no model).

Each question goes through orchestrator.ask with no provider, on the shared
test snapshot. Scored per question:
  useful      at least one card, every card from Outrider's own candidates
  incorrect   a card that isn't one of the snapshot's candidates (must be 0)
  unanswered  no card, or a compare question with no side-by-side rows
Latency is measured per question. Competitors aren't scored here: that needs
their current public documentation, which isn't in this repo (see
docs/companion/EVALUATION.md). Run: py -I companion/tests/test_eval25.py
"""
import json
import os
import sys
import time
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from outrider_companion.intelligence import orchestrator  # noqa: E402
import test_intelligence as TI  # noqa: E402

QUESTIONS = [
    "What should I do next?", "I have 15 minutes", "I have 45 minutes", "I have 2 hours", "What's the fastest XP right now?",
    "How do I make gold at my level?", "Is my gear okay?", "Should I repair first?", "What quest should I pick up?",
    "Where should I go after this zone?", "Should I train my profession now?", "Is there a rare nearby worth it?",
    "What do I need before a dungeon?", "Should I do the quest or train Alchemy?", "Which is better: repair or quest?",
    "I only want quests", "I want gold, not XP", "What can I do in 5 minutes?", "Plan my session",
    "What did I miss last time?", "What's urgent?", "Give me three steps", "What's close to me?",
    "Compare the quest and the profession", "Anything I'm forgetting?",
]


def run_all():
    rows = []
    for q in QUESTIONS:
        env, binding = TI.env_of()
        ids = {c["candidateId"] for c in env["candidates"]}
        t0 = time.perf_counter()
        advice, report = orchestrator.ask(q, env, binding, None)
        ms = (time.perf_counter() - t0) * 1000
        items = advice["items"]
        bad = [i for i in items if i.get("candidateId") not in ids]
        compare = orchestrator.is_compare(q)
        if bad:
            verdict = "incorrect"
        elif not items or (compare and not advice["answer"].get("compare")):
            verdict = "unanswered"
        else:
            verdict = "useful"
        rows.append({"question": q, "verdict": verdict, "cards": len(items), "ms": round(ms, 2), "mode": report["mode"]})
    return rows


class Eval25(unittest.TestCase):
    def test_baseline(self):
        rows = run_all()
        self.assertEqual(len(rows), 25)
        self.assertEqual([r for r in rows if r["verdict"] == "incorrect"], [], "nothing invented")
        useful = sum(1 for r in rows if r["verdict"] == "useful")
        self.assertGreaterEqual(useful, 20, json.dumps(rows, indent=1))
        self.assertLess(max(r["ms"] for r in rows), 1000)


if __name__ == "__main__":
    if "--report" in sys.argv:
        out = run_all()
        print(json.dumps({"useful": sum(r["verdict"] == "useful" for r in out),
                          "unanswered": sum(r["verdict"] == "unanswered" for r in out),
                          "incorrect": sum(r["verdict"] == "incorrect" for r in out),
                          "maxMs": max(r["ms"] for r in out), "rows": out}, indent=1))
    else:
        unittest.main()

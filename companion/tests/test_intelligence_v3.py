"""Intelligence 2.0 v3 contract tests; independent from live game/provider."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from outrider_companion import codes
from outrider_companion.intelligence import schemas_v3 as v3


def copied(**over):
    cands = [
        {"candidateId": "quest:Coming of Age", "kind": "quest", "title": "Next quest",
         "label": "community", "target": {"mapID": 2521, "x": 0.3, "y": 0.6}},
        {"candidateId": "gold:loot", "kind": "gold", "title": "Earn coins",
         "label": "observed", "panel": "hub"},
        {"candidateId": "gear:Upgrade", "kind": "gear", "title": "Upgrade bow",
         "label": "inferred", "itemID": 2504},
    ]
    snap = {"schema": 1, "askedAt": 1794740000, "takenAt": 1794740000,
            "snapshotId": "anonymous-snapshot-1", "gameBuild": "1.60.1",
            "class": "HUNTER", "level": 20, "where": {"mapID": 2521, "zone": "Here"},
            "modules": {"WhatNow": {"goal": "mix", "candidates": cands}}}
    snap.update(over)
    # This is the same legacy OTR1 API used by existing v1/v2 callers.
    return codes.import_code(codes.export({
        "kind": "snapshot", "character": "Private-Realm", "snapshot": snap,
    }))


class Envelope(unittest.TestCase):
    def test_legacy_snapshot_context_with_redaction(self):
        envelope, binding = v3.envelope_v3(copied(), "quest")
        self.assertEqual(envelope["schema"], 3)
        self.assertEqual(len(envelope["opportunities"]), 1)
        self.assertEqual(envelope["character"]["selectedRole"], "UNKNOWN")
        self.assertNotIn("Private", str(envelope))
        self.assertNotIn("Realm", str(envelope))
        self.assertNotIn("2504", str(envelope))
        self.assertNotIn("2521", str(envelope))
        self.assertEqual(binding["forCharacter"], "Private-Realm")

    def test_overflow_is_explicit_no_silent_truncation(self):
        with self.assertRaisesRegex(v3.ContractError, "too large"):
            v3.envelope_v3(copied(), "general", byte_limit=256)

    def test_unknown_task_refused(self):
        with self.assertRaises(v3.ContractError):
            v3.envelope_v3(copied(), "run_lua")


class Reply(unittest.TestCase):
    def test_keeps_only_trusted_source_rows(self):
        env, binding = v3.envelope_v3(copied(), "general")
        candidate = env["opportunities"][0]
        reply = {"schema": 3, "answersSnapshotId": env["snapshotId"],
                 "headline": "Quest!", "rankedCandidateIds": [candidate["candidateId"]],
                 "rationaleEvidenceIds": candidate["evidenceIds"],
                 "actionRequests": [], "limitations": ["Source may be old"]}
        out, cards = v3.validate_answer_v3(reply, env, binding)
        self.assertEqual(cards, [candidate])
        self.assertEqual(out["rankedCandidateIds"], [candidate["candidateId"]])
        self.assertEqual(out["actionRequests"], [])

    def test_hallucinated_ids_snapshot_mismatch_and_actions_rejected(self):
        env, binding = v3.envelope_v3(copied(), "general")
        reply = {"schema": 3, "answersSnapshotId": env["snapshotId"],
                 "rankedCandidateIds": [env["opportunities"][0]["candidateId"]],
                 "actionRequests": []}
        for patch in (
            {"rankedCandidateIds": ["invented:item:999"]},
            {"answersSnapshotId": "another"},
            {"actionRequests": [{"kind": "click"}]},
            {"execute": "cast"},
            {"rationaleEvidenceIds": ["fake:evidence"]},
        ):
            attempt = dict(reply, **patch)
            with self.assertRaises(v3.ContractError):
                v3.validate_answer_v3(attempt, env, binding)


if __name__ == "__main__":
    unittest.main()

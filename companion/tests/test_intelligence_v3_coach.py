"""End-to-end v3 OTR1 tests: no model, valid model, poisoned model."""
import json
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from outrider_companion import codes
from outrider_companion.intelligence import coach_v3


def snapshot():
    return codes.export({
        "kind": "snapshot", "character": "Private-Realm",
        "snapshot": {
            "schema": 1, "askedAt": 1794740000, "takenAt": 1794740000,
            "snapshotId": "source-snapshot-id", "class": "DRUID", "level": 32,
            "modules": {"WhatNow": {"goal": "level", "candidates": [
                {"candidateId": "quest:Some quest", "kind": "quest",
                 "title": "Consider the quest", "label": "community",
                 "target": {"mapID": 1, "x": 0.4, "y": 0.5}},
                {"candidateId": "gear:Some gear", "kind": "gear",
                 "title": "Review equipment", "label": "observed",
                 "itemID": 2504},
            ]}},
        },
    })


class Provider:
    def __init__(self, message):
        self.message = message
        self.calls = []

    def generate(self, messages):
        self.calls.append(messages)
        return self.message


class V3EndToEnd(unittest.TestCase):
    def test_offline_runs_without_provider_and_roundtrips(self):
        raw, advice, report = coach_v3.run(snapshot(), task="quest")
        self.assertEqual(report["mode"], "deterministic")
        self.assertEqual(advice["rankedCandidateIds"], ["quest:Some quest"])
        decoded = codes.import_code(raw)
        # OTR1 has one Lua table type: an empty Python list decodes as {}.
        self.assertEqual(decoded["kind"], "advice")
        self.assertEqual(decoded["rankedCandidateIds"], advice["rankedCandidateIds"])
        self.assertEqual(decoded["answersSnapshotId"], advice["answersSnapshotId"])
        self.assertEqual(decoded["forCharacter"], advice["forCharacter"])
        self.assertEqual(decoded["actionRequests"], {})
        self.assertEqual(advice["actionRequests"], [])
        self.assertNotIn("mapID", json.dumps(advice))
        self.assertEqual(advice["forCharacter"], "Private-Realm")

    def test_model_can_rank_but_cannot_author_action_or_coords(self):
        provider = Provider(json.dumps({
            "schema": 3, "answersSnapshotId": "source-snapshot-id",
            "headline": "Review your gear", "summary": "Valid",
            "rankedCandidateIds": ["gear:Some gear"],
            "rationaleEvidenceIds": ["local:gear:Some gear"],
            "actionRequests": [],
        }))
        raw, result, report = coach_v3.run(snapshot(), "which next?", provider=provider)
        self.assertEqual(report["mode"], "model")
        self.assertEqual(result["rankedCandidateIds"], ["gear:Some gear"])
        self.assertNotIn("itemID", json.dumps(result))
        self.assertNotIn("Private-Realm", str(provider.calls))

    def test_poisoned_reply_safely_falls_back_to_trusted_candidates(self):
        provider = Provider(json.dumps({
            "schema": 3, "answersSnapshotId": "source-snapshot-id",
            "rankedCandidateIds": ["secret:made-up"],
            "actionRequests": [{"kind": "cast", "spell": 9}],
        }))
        _, result, report = coach_v3.run(snapshot(), provider=provider)
        self.assertEqual(report["mode"], "fallback")
        self.assertEqual(result["rankedCandidateIds"][0], "quest:Some quest")
        self.assertEqual(result["actionRequests"], [])

    def test_empty_candidates_fail_explicitly(self):
        data = codes.import_code(snapshot())
        data["snapshot"]["modules"]["WhatNow"]["candidates"] = []
        with self.assertRaisesRegex(ValueError, "no evidence"):
            coach_v3.run(codes.export(data), task="general")


if __name__ == "__main__":
    unittest.main()

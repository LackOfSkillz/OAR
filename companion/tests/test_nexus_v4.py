"""Nexus v4 contracts: the Python validator gives the recorded verdict on every shared fixture."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from outrider_companion.intelligence import schemas_v4  # noqa: E402


class NexusV4(unittest.TestCase):
    def test_fixtures_match_recorded_verdicts(self):
        fx = schemas_v4.fixtures()
        self.assertGreaterEqual(len(fx), 18)
        for case in fx:
            ok, field = schemas_v4.validate(case["record"], case["data"])
            self.assertEqual(ok, case["ok"], case)
            if not case["ok"]:
                self.assertEqual(field, case["error"], case)

    def test_spec_version_and_records(self):
        s = schemas_v4.spec()
        self.assertEqual(s["version"], 4)
        self.assertEqual(sorted(s["records"]), ["CharacterState", "Evidence", "Goal", "Opportunity", "Outcome", "OutcomeEvent", "Plan"])

    def test_extra_fields_and_bad_values_are_rejected(self):
        ok, field = schemas_v4.validate("Plan", {"planId": "p", "snapshotRevision": 1, "steps": [], "reasonCodes": [],
                                                 "createdAt": 1, "version": 1, "truncated": False, "exec": "x"})
        self.assertEqual((ok, field), (False, "unknownField"))
        ok, field = schemas_v4.validate("Goal", {"goalId": "g", "scope": "char", "objective": "gold", "priority": True,
                                                 "status": "active", "createdAt": 1})
        self.assertEqual((ok, field), (False, "priority"))


if __name__ == "__main__":
    unittest.main()

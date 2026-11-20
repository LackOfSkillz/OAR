import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from outrider_companion import luadata
from outrider_companion.intelligence import next_session_delivery as D
from outrider_companion.intelligence import session_reader


def recording():
    return {
        "schema": 1, "sessionId": "session-2026", "final": True,
        "durationSeconds": 3600, "xpEarned": 10000,
        "xpVerified": True, "levelStart": 20, "levelEnd": 20,
        "startedAt": 10000, "endedAt": 13600,
        "build": "1.60.1", "flags": {}
    }


class Delivery(unittest.TestCase):
    def test_session_bound_default_plan_never_invents_xp(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "Outrider.lua"
            p.write_text(luadata.dumps("Outrider_DB", {
                "chars": {"Test-Realm": {"xp60": {
                    "schema": 1, "history": [recording()]}}}}) +
                luadata.dumps("Outrider_Snapshots", {
                    "Test-Realm": {"modules": {"WhatNow": {"seenAt": 13580, "candidates": [
                        {"candidateId": "quest:possible", "kind": "quest", "label": "community"}]}}}}),
                encoding="utf-8")
            result = session_reader.read_sessions(p)
            plan = D.create_plan(result, "Test-Realm", now=1795000000)
            self.assertEqual(plan["schema"], 4)
            self.assertEqual(plan["basedOnSessionId"], "session-2026")
            self.assertEqual(plan["baselineXPPerHour"], 10000)
            self.assertIsNone(plan["estimatedEarnedXP"])
            self.assertEqual(plan["steps"], [])
            self.assertEqual(plan["qualitativeCandidateIds"], ["quest:possible"])
            self.assertEqual(D.validate_payload(plan), plan)

    def test_stale_whatnow_candidates_are_not_suggested(self):
        result = {
            "sessions": [("Test-Realm", recording())],
            "sourceDigest": "a" * 64,
            "snapshots": {"Test-Realm": {
                "modules": {"WhatNow": {
                    "seenAt": 1000,
                    "candidates": [{"candidateId": "quest:old", "kind": "quest",
                                    "label": "observed"}]}}}},
        }
        p = D.create_plan(result, "Test-Realm", now=1795000000)
        self.assertEqual(p["qualitativeCandidateIds"], [])

    def test_player_known_candidate_is_not_repeated_next_session(self):
        s = recording()
        result = {
            "sessions": [("Test-Realm", s)],
            "sourceDigest": "a" * 64,
            "snapshots": {"Test-Realm": {"modules": {"WhatNow": {
                "seenAt": 13580,
                "candidates": [{"candidateId": "quest:known", "kind": "quest",
                                "label": "community"}]}}}},
            "preferences": {"Test-Realm": {"quest:known": {
                "verdict": "already_know", "at": 1794999990, "level": 20}}},
        }
        p = D.create_plan(result, "Test-Realm", now=1795000000)
        self.assertEqual(p["qualitativeCandidateIds"], [])

    def test_never_writes_without_confirmed_game_exit(self):
        with tempfile.TemporaryDirectory() as d:
            addon = Path(d) / "Interface" / "AddOns" / "Outrider"
            (addon / "Advisor").mkdir(parents=True)
            advice_file = addon / "Advisor" / "Advice.lua"
            advice_file.write_text("Outrider_Advice = nil\n", encoding="utf-8")
            plan = {"schema": 4, "kind": "nextSessionPlan",
                    "forCharacter": "Test-Realm", "basedOnSessionId": "session-1",
                    "sourceDigest": "a" * 64, "createdAt": 1000,
                    "expiresAt": 2000, "goal": "xp", "budgetSeconds": 3600,
                    "status": "insufficient_evidence", "headline": "Continue", "summary": "",
                    "gameBuild": "test", "levelAtPlan": 20, "baselineXPPerHour": None,
                    "estimatedEarnedXP": None, "steps": [], "limitations": [],
                    "actions": []}
            with self.assertRaises(D.DeliveryError):
                D.write_after_exit(plan, addon, checker=lambda: False)
            self.assertEqual(advice_file.read_text(), "Outrider_Advice = nil\n")
            D.write_after_exit(plan, addon, checker=lambda: True)
            data = luadata.parse(advice_file.read_text())
            self.assertEqual(data["Outrider_Advice"]["basedOnSessionId"], "session-1")
            self.assertEqual(data["Outrider_Advice"]["actions"], {})

    def test_rejects_extra_fields_and_overlong_schedule(self):
        plan = {"schema": 4, "kind": "nextSessionPlan", "forCharacter": "Test-Realm",
                "basedOnSessionId": "s", "sourceDigest": "a"*64,
                "createdAt": 1, "expiresAt": 2, "goal": "xp", "budgetSeconds": 3600,
                "actions": [], "steps": []}
        self.assertIs(D.validate_payload(plan), plan)
        with self.assertRaises(D.DeliveryError):
            D.validate_payload(dict(plan, execute="click"))
        with self.assertRaises(D.DeliveryError):
            D.validate_payload(dict(plan, actions=[{"spell": 1}]))
        with self.assertRaises(D.DeliveryError):
            D.validate_payload(dict(plan, budgetSeconds=3700))


if __name__ == "__main__":
    unittest.main()

import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from outrider_companion import luadata
from outrider_companion.intelligence import session_reader, xp_baseline, xp60_planner


def session(**over):
    row = {"schema": 1, "sessionId": "opaque-1", "final": True,
           "durationSeconds": 1800, "xpEarned": 9000,
           "xpVerified": True, "levelStart": 20,
           "levelEnd": 20, "startedAt": 1000, "endedAt": 2800,
           "build": "test", "flags": {}}
    row.update(over)
    return row


def option(cid, *, seconds=1200, xp=6000, **over):
    row = {"candidateId": cid, "title": cid, "eligible": True,
           "completed": False, "origin": "verified",
           "evidenceIds": ["quest-record:" + cid], "requires": [],
           "timeSeconds": {"travel": 200, "activity": seconds - 300,
                           "turnIn": 100, "wait": 0},
           "xpReward": {"value": xp, "origin": "verified"}}
    row.update(over)
    return row


class Reader(unittest.TestCase):
    def test_reads_only_stable_plain_lua_and_deduplicates(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "Outrider_DB.lua"
            p.write_text(luadata.dumps("Outrider_DB", {"chars": {
                "A-Realm": {"xp60": {"schema": 1, "history": [
                    session(), session()]}}}}), encoding="utf-8")
            got = session_reader.read_sessions(p)
            self.assertEqual(len(got["sessions"]), 1)
            self.assertEqual(session_reader.newest_completed(got)[1]["sessionId"], "opaque-1")
            self.assertEqual(len(got["sourceDigest"]), 64)
            p.write_text("Outrider_DB = function() return 1 end", encoding="utf-8")
            with self.assertRaises(session_reader.SessionReadError):
                session_reader.read_sessions(p)

    def test_rejects_non_outider_paths_and_incomplete(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(session_reader.SessionReadError):
                session_reader.stable_bytes(Path(d) / "SavedVariables.lua")
            p = Path(d) / "Outrider_DB.lua"
            p.write_text("Outrider_DB = {", encoding="utf-8")
            with self.assertRaises(session_reader.SessionReadError):
                session_reader.read_sessions(p)


class Baseline(unittest.TestCase):
    def test_wall_clock_not_active_time(self):
        b = xp_baseline.baseline([session(), session(sessionId="opaque-2",
                          durationSeconds=1800, xpEarned=6000)])
        self.assertEqual(b["xpPerHour"], 15000)
        self.assertEqual(b["sampleCount"], 2)
        self.assertEqual(b["basis"], "wall")

    def test_unknown_rollover_or_partial_session_not_eligible(self):
        b = xp_baseline.baseline([
            session(xpVerified=False), session(sessionId="other", flags={"rolloverUnknown": True}),
            session(sessionId="third", final=False)])
        self.assertIsNone(b["xpPerHour"])


class Planner(unittest.TestCase):
    def test_horizon_counts_travel_and_turn_in_and_buffer(self):
        plan = xp60_planner.optimize([option("quest1", seconds=1500, xp=8000),
                                      option("quest2", seconds=1700, xp=9000)],
                                     baseline=xp_baseline.baseline([session()]))
        self.assertEqual(len(plan["steps"]), 2)
        self.assertEqual(plan["estimatedEarnedXP"], 17000)
        self.assertLessEqual(plan["steps"][-1]["endsAt"] + 240, 3600)
        self.assertIsNone(plan["estimatedImprovementPercent"])

    def test_turnin_at_minute_61_is_not_counted(self):
        p = xp60_planner.optimize([option("late", seconds=3660, xp=100000)])
        self.assertIsNone(p["estimatedEarnedXP"])
        self.assertEqual(p["status"], "insufficient_evidence")

    def test_dependencies_never_count_unfinished_rewards(self):
        p = xp60_planner.optimize([option("end", seconds=900, xp=8000,
                                      requires=["first"]), option("first", seconds=900, xp=1000)])
        self.assertEqual([s["candidateId"] for s in p["steps"]], ["first", "end"])

    def test_unverified_or_group_unavailable_stays_qualitative(self):
        p = xp60_planner.optimize([option("unknown", xp=90000, xpReward={"value": None, "origin": "unknown"}),
                                   option("group", xp=60000, requiresGroup=True, groupAvailable=False)])
        self.assertIsNone(p["estimatedEarnedXP"])
        self.assertIsNone(p["estimatedImprovementPercent"])
        self.assertEqual(len(p["unknownCandidateIds"]), 2)

    def test_duplicate_candidate_cannot_gain_xp_twice(self):
        p = xp60_planner.optimize([option("one"), option("one")])
        self.assertEqual(p["estimatedEarnedXP"], 6000)
        self.assertEqual(len(p["steps"]), 1)


if __name__ == "__main__":
    unittest.main()

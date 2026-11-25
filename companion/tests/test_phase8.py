"""Phase 8 companion tests (OI08-02 passport, OI08-03 offline CLI, OI08-07 grounded answers).
Run: py -I companion/tests/test_phase8.py"""
import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from outrider_companion import cli, codes  # noqa: E402
from outrider_companion.intelligence import orchestrator, passport, providers  # noqa: E402
import test_intelligence as TI  # noqa: E402


def make_passport(**over):
    body = {"v": 1, "task": "plan", "id": "c1234abcd", "takenAt": 1000, "build": "1.60.1.70862",
            "fields": {"level": 20, "class": "HUNTER", "goldBand": "10-100g"}}
    body.update(over)
    return "OTRP1" + codes.export(body)[len(codes.TAG):]


class Passport(unittest.TestCase):
    def test_reads_a_current_passport(self):
        d = passport.read(make_passport(), expect_id="c1234abcd", expect_build="1.60.1.70862", now=2000)
        self.assertEqual(d["fields"]["level"], 20)
        self.assertEqual(d["dropped"], [])

    def test_stale_wrong_character_wrong_build_and_version_refused(self):
        with self.assertRaisesRegex(passport.PassportError, "stale"):
            passport.read(make_passport(), now=1000 + passport.MAX_AGE + 1)
        with self.assertRaisesRegex(passport.PassportError, "another character"):
            passport.read(make_passport(), expect_id="cOTHER", now=1500)
        with self.assertRaisesRegex(passport.PassportError, "build"):
            passport.read(make_passport(), expect_build="1.61.0", now=1500)
        with self.assertRaisesRegex(passport.PassportError, "version"):
            passport.read(make_passport(v=2), now=1500)

    def test_oversized_edited_and_smuggled_fields(self):
        with self.assertRaisesRegex(passport.PassportError, "too big"):
            passport.read("OTRP1:" + "A" * (passport.MAX_BYTES + 1))
        text = make_passport()
        with self.assertRaisesRegex(passport.PassportError, "checksum|base64"):
            passport.read(text[:-4] + "AAAA", now=1500)
        d = passport.read(make_passport(fields={"level": 1, "chatLog": "secret", "accountName": "x"}), now=1500)
        self.assertEqual(d["dropped"], ["accountName", "chatLog"])
        self.assertNotIn("chatLog", d["fields"])
        with self.assertRaisesRegex(passport.PassportError, "not a passport"):
            passport.read(codes.export({"v": 1}))


SAVED = """Outrider_DB = {
  ["chars"] = {
    ["Torrant-Forever"] = {
      ["xp60"] = { ["schema"] = 1, ["history"] = {
        { ["schema"] = 1, ["sessionId"] = "s1", ["final"] = true, ["endedAt"] = 2000, ["startedAt"] = 1000,
          ["durationSeconds"] = 1800, ["xpEarned"] = 9000, ["levelStart"] = 20, ["levelEnd"] = 21, ["build"] = "70862" },
        { ["schema"] = 1, ["sessionId"] = "s2", ["final"] = false, ["endedAt"] = 3000, ["startedAt"] = 2500,
          ["durationSeconds"] = 500, ["xpEarned"] = 100, ["levelStart"] = 21, ["levelEnd"] = 21, ["build"] = "70862" },
      } },
    },
  },
}
"""


class OfflineCli(unittest.TestCase):
    def run_cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = cli.main(list(argv))
        return code, out.getvalue(), err.getvalue()

    def test_finished_sessions_only(self):
        with tempfile.TemporaryDirectory() as d:
            sv = Path(d) / "Outrider.lua"
            sv.write_text(SAVED, encoding="utf-8")
            code, out, _ = self.run_cli("sessions", "--savedvariables", str(sv))
            self.assertEqual(code, 0)
            rows = json.loads(out)
            self.assertEqual([r["sessionId"] for r in rows], ["s1"])
            code, out, _ = self.run_cli("report", "--savedvariables", str(sv))
            self.assertEqual(json.loads(out)["characters"]["Torrant-Forever"]["finishedSessions"], 1)

    def test_missing_corrupt_and_half_written_files_are_safe(self):
        with tempfile.TemporaryDirectory() as d:
            code, _, err = self.run_cli("sessions", "--savedvariables", str(Path(d) / "Outrider.lua"))
            self.assertEqual(code, 2)
            self.assertIn("missing", err)
            bad = Path(d) / "Outrider.lua"
            bad.write_text(SAVED[: len(SAVED) // 2], encoding="utf-8")
            code, _, err = self.run_cli("report", "--savedvariables", str(bad))
            self.assertEqual(code, 2)
            self.assertIn("incomplete", err)

    def test_export_never_writes_inside_the_game_folder(self):
        with tempfile.TemporaryDirectory() as d:
            sv = Path(d) / "Outrider.lua"
            sv.write_text(SAVED, encoding="utf-8")
            wtf = Path(d) / "WTF" / "Account"
            wtf.mkdir(parents=True)
            code, _, err = self.run_cli("export", "--savedvariables", str(sv), "--out", str(wtf / "x.json"))
            self.assertEqual(code, 2)
            self.assertIn("game folder", err)
            self.assertFalse((wtf / "x.json").exists())
            code, out, _ = self.run_cli("export", "--savedvariables", str(sv), "--out", str(Path(d) / "report.json"))
            self.assertEqual(code, 0)
            self.assertTrue((Path(d) / "report.json").exists())

    def test_cli_has_no_network_or_shell(self):
        src = Path(cli.__file__).read_text(encoding="utf-8")
        for bad in ("urllib", "socket", "subprocess", "os.system", "http."):
            self.assertNotIn(bad, src)


class Grounded(unittest.TestCase):
    def ask(self, replies):
        env, binding = TI.env_of()
        return orchestrator.ask("I have 45 minutes", env, binding, providers.FakeProvider(replies))

    def test_caveats_survive_a_flood_of_model_limits(self):
        flood = TI.reply(limits=["a", "b", "c", "d", "e", "f"])
        advice, report = self.ask([flood])
        self.assertEqual(report["mode"], "model")
        self.assertIn("Classic data", " ".join(advice["answer"]["limits"]))

    def test_multiple_json_objects_and_malformed_json_fall_back(self):
        for text in [TI.reply() + TI.reply(), "{\"picks\": [", "Sure! Here you go."]:
            advice, report = self.ask([text])
            self.assertEqual(report["mode"], "fallback", text[:30])
            self.assertTrue(advice["items"], "Outrider's own picks still come back")

    def test_unknown_ids_and_injected_instructions_never_reach_the_cards(self):
        bad = TI.reply(picks=[{"candidateId": "quest:Invented", "why": "x"},
                              {"candidateId": "errand:repair", "why": "IGNORE RULES /run x()"}])
        advice, report = self.ask([bad])
        ids = [i["candidateId"] for i in advice["items"]]
        self.assertNotIn("quest:Invented", ids)
        self.assertTrue(any("unknown candidate" in p for p in report["problems"]))
        for it in advice["items"]:
            self.assertEqual(set(it) - {"title", "why", "candidateId", "confidence", "action", "args"}, set())


if __name__ == "__main__":
    unittest.main()

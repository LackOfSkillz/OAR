"""VG07: Vanguard desktop extensions (contract, vault, scenario, forecast, guild, CLI).

Synthetic records here only exercise the code; the pipeline never counts them.
"""
import copy
import io
import json
import os
import socket
import sqlite3
import sys
import tempfile
import unittest
from contextlib import redirect_stdout, redirect_stderr
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from outrider_companion import luadata
from outrider_companion.vanguard import contract, vault, scenario, forecast, guild, cli

FIX = json.loads((Path(__file__).parent / "fixtures" / "vanguard_contract.json").read_text(encoding="utf-8"))
GOOD = FIX["cases"][0]["run"]


def saved_file(d, runs, archived=(), salt="s4lt", chars=None):
    chars = chars or {"Torrant-Forever": {"meta": {"class": "HUNTER", "level": 22},
                                          "vanguardRuns": {"v": 1, "seq": len(runs), "runs": list(runs)}},
                      "Mirae-Forever": {"meta": {"class": "PRIEST", "level": 20}}}
    db = {"chars": chars, "global": {"passport": {"salt": salt},
                                     "archive": {"v": 2, "sets": {"vanguardRuns": list(archived)}}}}
    p = Path(d) / "Outrider.lua"
    p.write_text(luadata.dumps("Outrider_DB", db), encoding="utf-8")
    return p


def run(i, outcome="completed", t0=1764000000, **feat):
    r = copy.deepcopy(GOOD)
    r["runId"] = "The Deadmines:%d:%d" % (t0 + i * 3600, i)
    r["startedAt"], r["endedAt"], r["outcome"] = t0 + i * 3600, t0 + i * 3600 + 1800, outcome
    r["features"].update(feat)
    return r


def envelope(runs, exporter="c0000abcd", guild_ok=True, synthetic=False):
    env = {"format": contract.FORMAT, "v": 1, "createdAt": 1764100000, "exporter": exporter,
           "source": {"sha256": "0" * 64}, "consent": {"runs": True, "profile": False, "guild": guild_ok},
           "runs": runs, "counts": {"runs": len(runs)}}
    if synthetic:
        env["synthetic"] = True
    return env


def write_env(d, env, name="x.json"):
    p = Path(d) / name
    p.write_bytes(contract.canonical(env))
    return p


class ContractTest(unittest.TestCase):
    def test_shared_fixture_cases(self):
        self.assertEqual(FIX["fields"], contract.contract_fields(), "fixture matches the Python contract")
        for case in FIX["cases"]:
            dropped = {}
            try:
                out = contract.clean_run(case["run"], dropped=dropped)
                got = "dropped" if dropped else "kept"
                self.assertNotIn("partyNames", out)
            except contract.ContractError:
                got = "refused"
            self.assertEqual(got, case["export"], case["name"] + " (export)")
            try:
                contract.clean_run(case["run"], strict=True)
                got = "ok"
            except contract.ContractError:
                got = "refused"
            self.assertEqual(got, case["import"], case["name"] + " (import)")

    def test_export_is_anonymous_and_preview_by_default(self):
        with tempfile.TemporaryDirectory() as d:
            named = run(2)
            named["attempts"][0]["name"] = "Mirae's ghost"  # a character name from this file: refused
            sv = saved_file(d, [run(0), dict(run(1), secret="x"), named],
                            archived=[{"id": "a:1", "char": "Torrant-Forever", "row": run(3)},
                                      {"id": "a:2", "char": "Mirae-Forever", "row": run(4)}])
            db, sha = contract.read_saved(sv)
            env, dropped = contract.build_export(db, sha, "Torrant-Forever")
            self.assertEqual(env["counts"]["runs"], 3, "own active + own archived")
            self.assertEqual(env["counts"]["refused"], 1)
            self.assertEqual(dropped, {"run.secret": 1})
            text = json.dumps(env)
            for bad in ("Torrant", "Mirae", "Forever-"):
                self.assertNotIn(bad, text.replace("The Deadmines", ""))
            self.assertRegex(env["exporter"], r"^c[0-9a-f]{8}$")
            self.assertNotIn("profile", env)
            env2, _ = contract.build_export(db, sha, "Torrant-Forever", profile=True, guild=True)
            self.assertEqual(env2["profile"], {"class": "HUNTER", "level": 22})
            # CLI: preview only, then refuses with the game open, then writes
            out = Path(d) / "export.json"
            buf = io.StringIO()
            with redirect_stdout(buf):
                self.assertEqual(cli.main(["export", "--savedvariables", str(sv), "--character", "Torrant-Forever"]), 0)
            self.assertIn("Nothing written", buf.getvalue())
            self.assertFalse(out.exists())
            with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                self.assertEqual(cli.main(["export", "--savedvariables", str(sv), "--character", "Torrant-Forever",
                                           "--out", str(out)], check_game=lambda: False), 2)
            self.assertFalse(out.exists(), "game open: nothing written")
            with redirect_stdout(io.StringIO()):
                self.assertEqual(cli.main(["export", "--savedvariables", str(sv), "--character", "Torrant-Forever",
                                           "--out", str(out)], check_game=lambda: True), 0)
            back, _ = contract.read_import(out)
            self.assertEqual(len(back["runs"]), 3)

    def test_export_refuses_game_folder_and_missing_salt(self):
        with tempfile.TemporaryDirectory() as d:
            sv = saved_file(d, [run(0)], salt="")
            db, sha = contract.read_saved(sv)
            with self.assertRaises(contract.ContractError):
                contract.build_export(db, sha, "Torrant-Forever")
            with self.assertRaises(contract.ContractError):
                contract.write_export({}, str(Path(d) / "WTF" / "x.json"))

    def test_import_is_strict(self):
        with tempfile.TemporaryDirectory() as d:
            ok = envelope([run(0)])
            contract.read_import(write_env(d, ok))
            bad = [dict(ok, v=2), dict(ok, extra=1), dict(ok, exporter="Torrant-Forever"),
                   dict(ok, consent={"runs": True}), dict(ok, runs=[dict(run(0), names="x")]),
                   dict(ok, profile={"class": "HUNTER"}),  # profile without consent
                   dict(ok, consent={"runs": True, "profile": True, "guild": False}, profile={"name": "x"}),
                   dict(ok, format="other")]
            for i, env in enumerate(bad):
                with self.assertRaises(contract.ContractError, msg="case %d" % i):
                    contract.read_import(write_env(d, env, "b%d.json" % i))
            p = Path(d) / "junk.json"
            p.write_text("{not json", encoding="utf-8")
            with self.assertRaises(contract.ContractError):
                contract.read_import(p)
            p.write_bytes(b"")
            with self.assertRaises(contract.ContractError):
                contract.read_import(p)
            with self.assertRaisesRegex(contract.ContractError, "newer"):
                contract.validate(dict(ok, v=2))


class VaultTest(unittest.TestCase):
    def test_idempotent_revisions_scoped_never_deletes(self):
        with tempfile.TemporaryDirectory() as d:
            v = vault.Vault(Path(d) / "v.sqlite")
            f1 = write_env(d, envelope([run(0), run(1)]))
            self.assertEqual(v.import_file(f1)["new"], 2)
            self.assertEqual(v.import_file(f1)["status"], "skipped", "same file again changes nothing")
            changed = run(1, outcome="incomplete")
            f2 = write_env(d, envelope([run(0), changed, run(2)]), "f2.json")
            c = v.import_file(f2)
            self.assertEqual((c["new"], c["revised"], c["unchanged"]), (1, 1, 1))
            self.assertEqual(v.revisions("c0000abcd", changed["runId"]), [1, 2], "old revision kept")
            latest = {r["runId"]: r["outcome"] for r in v.runs(exporter="c0000abcd")}
            self.assertEqual(latest[changed["runId"]], "incomplete")
            v.import_file(write_env(d, envelope([run(5)], exporter="c1111beef"), "f3.json"))
            self.assertEqual(len(v.runs(exporter="c0000abcd")), 3, "scoped to one exporter")
            self.assertEqual(len(v.runs(everyone=True)), 4)
            with self.assertRaises(vault.VaultError):
                v.runs()
            st = v.status()
            self.assertEqual((st["runRows"], st["sources"], st["failedImports"]), (5, 3, 0))
            n_prov = v.db.execute("SELECT COUNT(*) FROM provenance").fetchone()[0]
            self.assertEqual(n_prov, 5, "every row has provenance")
            v.close()

    def test_failed_import_rolls_back(self):
        with tempfile.TemporaryDirectory() as d:
            v = vault.Vault(Path(d) / "v.sqlite")
            env = envelope([run(0), run(1)])
            env["runs"][1]["instance"] = None  # breaks NOT NULL mid-transaction
            with self.assertRaises(vault.VaultError):
                v.import_envelope(env, "a" * 64, "x")
            st = v.status()
            self.assertEqual((st["runRows"], st["sources"], st["failedImports"]), (0, 0, 1))
            v.close()

    def test_backup_restore_and_damage(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "v.sqlite"
            v = vault.Vault(path)
            v.import_file(write_env(d, envelope([run(0)])))
            b = v.backup(stamp="t1")
            with self.assertRaises(vault.VaultError):
                v.backup(stamp="t1")
            v.import_file(write_env(d, envelope([run(1)]), "f2.json"))
            v.close()
            res = vault.restore(path, b, stamp="r1")
            self.assertTrue(Path(res["kept"]).exists(), "the replaced file is kept")
            v2 = vault.Vault(path)
            self.assertEqual(v2.status()["runRows"], 1)
            v2.close()
            # damage the file: opens read-only and refuses imports
            data = bytearray(path.read_bytes())
            for i in range(100, len(data), 97):
                data[i] = 0xFF
            path.write_bytes(bytes(data))
            try:
                v3 = vault.Vault(path)
            except sqlite3.DatabaseError:
                v3 = None
            if v3 is not None:
                self.assertTrue(v3.read_only)
                with self.assertRaises(vault.VaultError):
                    v3.import_envelope(envelope([run(9)]), "b" * 64, "x")
                v3.close()
            self.assertTrue(Path(res["kept"]).exists())

    def test_refuses_game_folder(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(vault.VaultError):
                vault.Vault(Path(d) / "Interface" / "v.sqlite")


class ScenarioTest(unittest.TestCase):
    GROUP = [{"class": "WARRIOR", "role": "TANK", "level": 20}, {"class": "PRIEST", "role": "HEALER", "level": 20},
             {"class": "HUNTER", "role": "DAMAGER", "level": 21}, {"class": "MAGE", "role": "DAMAGER", "level": 19},
             {"class": "WARLOCK", "role": "DAMAGER", "level": 20}]

    def test_capabilities_and_boss_needs(self):
        r = scenario.analyse(self.GROUP, "The Deadmines")
        self.assertEqual(r["shape"]["tank"], 1)
        self.assertIn("WARRIOR", r["capabilities"]["interrupt"]["canBring"])
        self.assertEqual(r["capabilities"]["dispel_poison"]["canBring"], [], "nobody here cures poison")
        green = [b for b in r["bosses"] if b["name"] == "Captain Greenskin"][0]
        self.assertFalse(green["verified"])
        self.assertTrue(any(n["need"] == "dispel_poison" and not n["covered"] for n in green["needs"]))
        self.assertIn("Classic", green["source"])
        t = scenario.text(r)
        self.assertNotRegex(t.lower().replace("nothing here is a success probability", ""), r"probabilit|chance of|will succeed|guarantee")
        self.assertIn("Nothing here is a success probability", t)

    def test_bad_groups_refused(self):
        for g in ([], [{"class": "MONK"}], [{"class": "MAGE", "role": "TANK"}], [{"class": "MAGE", "level": 0}],
                  [{"class": "MAGE"}] * 41):
            with self.assertRaises(scenario.ScenarioError):
                scenario.analyse(g)

    def test_past_runs_abstain_then_describe(self):
        shape = dict(members=5, tank=1, healer=1, levelMin=19, levelMax=21)
        few = [run(i, **shape) for i in range(4)]
        self.assertIsNone(scenario.analyse(self.GROUP, "The Deadmines", few)["past"]["fullClear"])
        many = few + [run(10 + i, outcome="incomplete", **shape) for i in range(3)] + [run(20, outcome="unknown", **shape)]
        p = scenario.analyse(self.GROUP, "The Deadmines", many)["past"]
        self.assertEqual((p["known"], p["unknownOutcome"]), (7, 1))
        self.assertEqual((p["fullClear"]["k"], p["fullClear"]["n"]), (4, 7))
        self.assertLess(p["fullClear"]["low"], 4 / 7)

    def test_raid_size_and_status(self):
        r = scenario.analyse(self.GROUP * 3, "Barrow Deeps")
        self.assertTrue(any("more members" in n for n in r["notes"]))


def synth_runs(n, t0=1764000000, build="b1"):
    """Synthetic, deterministic: more healers -> more full clears. Exercises the math only."""
    import random
    rng = random.Random(3)
    out = []
    for i in range(n):
        healer = 1 + (i % 2)
        lvl = 18 + (i % 5)
        p = 0.2 + 0.5 * (healer - 1) + 0.04 * (lvl - 18)
        outcome = "completed" if rng.random() < p else "incomplete"
        r = run(i, outcome=outcome, t0=t0, members=5, tank=1, healer=healer, damage=4 - healer,
                levelMin=lvl, levelMax=lvl + 1)
        r["build"] = build
        r["_exporter"] = "c0000abcd"
        r["attempts"] = [{"id": 1, "encounterId": "1", "name": "Rhahk'Zor", "start": 1, "end": 2,
                          "result": "kill" if outcome == "completed" or rng.random() < 0.5 else "wipe"},
                         {"id": 2, "encounterId": "2", "name": "Sneed", "start": 3, "end": 4, "result": "unknown"}]
        out.append(r)
    return out


class ForecastTest(unittest.TestCase):
    def test_no_plan_approval_fits_nothing(self):
        card = forecast.run(synth_runs(300), "full_clear")
        self.assertFalse(card["eligible"])
        self.assertNotIn("models", card)
        self.assertTrue(any("not approved" in r for r in card["reasons"]))
        self.assertEqual(len(card["datasetSha256"]), 64)

    def test_labels_exclude_unknown_and_censored(self):
        runs = synth_runs(10)
        runs[0]["outcome"] = "unknown"
        rows, ex = forecast.labelled(runs, "full_clear")
        self.assertEqual((len(rows), ex["censored_run"]), (9, 1))
        rows, ex = forecast.labelled(runs, "first_attempt_kill")
        self.assertEqual(ex["unknown_attempt"], 9, "Sneed's unknown attempt is never a wipe")
        self.assertTrue(all(r[2] == "The Deadmines/Rhahk'Zor" for r in rows))

    def test_pipeline_math_on_synthetic_is_never_eligible(self):
        runs = synth_runs(320)
        appr = {"by": "test", "at": "2026-11-26"}
        card = forecast.run(runs, "full_clear", "The Deadmines", approval=appr)
        self.assertEqual(card["trainRows"] + card["holdoutRows"], 320)
        self.assertGreaterEqual(card["holdoutRows"], 50)
        names = [m["model"] for m in card["models"]]
        self.assertEqual(names, ["prevalence", "role_level_logistic", "regularized_logistic"])
        rl = card["models"][1]
        self.assertLess(rl["brier"], rl["baselineBrier"], "the healer signal is learnable")
        self.assertTrue(rl["auc"] > 0.6)
        self.assertTrue(rl["reliability"] and all(b["n"] > 0 for b in rl["reliability"]))
        self.assertIn("slope", rl["calibration"])
        self.assertFalse(card["approved"], "never approved by the pipeline")
        again = forecast.run(runs, "full_clear", "The Deadmines", approval=appr)
        self.assertEqual(again["models"], card["models"], "deterministic")
        # the same records marked synthetic: left out and never eligible
        for r in runs:
            r["_synthetic"] = True
        s = forecast.run(runs, "full_clear", approval=appr)
        self.assertFalse(s["eligible"])
        self.assertEqual(s["excluded"]["synthetic"], 320)

    def test_floors_skew_and_build_mix_abstain(self):
        appr = {"by": "test", "at": "x"}
        small = forecast.run(synth_runs(60), "full_clear", approval=appr)
        self.assertTrue(any("training runs" in r for r in small["reasons"]))
        self.assertFalse(small["eligible"])
        mixed = synth_runs(150) + synth_runs(150, t0=1765000000, build="b2")
        card = forecast.run(mixed, "full_clear", approval=appr)
        self.assertTrue(any("more than one game build" in r for r in card["reasons"]))
        self.assertFalse(card["eligible"])
        skew = [run(i, outcome="completed") for i in range(300)]
        card = forecast.run(skew, "full_clear", approval=appr)
        self.assertFalse(card["eligible"])

    def test_plan_approval_reader(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "policy.json"
            self.assertIsNone(forecast.plan_approval(p))
            p.write_text('{"vanguardForecast": {"planApprovedBy": " "}}', encoding="utf-8")
            self.assertIsNone(forecast.plan_approval(p))
            p.write_text('{"vanguardForecast": {"planApprovedBy": "reviewer", "planApprovedAt": "2026-12-01"}}',
                         encoding="utf-8")
            self.assertEqual(forecast.plan_approval(p)["by"], "reviewer")
        self.assertIsNone(forecast.plan_approval(), "not approved in this repository")
        with self.assertRaises(forecast.ForecastError):
            forecast.write_card({}, os.path.join("x", "Interface", "card.json"))


class GuildTest(unittest.TestCase):
    def test_aggregate_consent_only_no_rankings(self):
        with tempfile.TemporaryDirectory() as d:
            v = vault.Vault(Path(d) / "v.sqlite")
            v.import_file(write_env(d, envelope([run(i) for i in range(4)] + [run(9, outcome="abandoned")]), "a.json"))
            v.import_file(write_env(d, envelope([run(20 + i) for i in range(3)], exporter="c2222cafe",
                                                guild_ok=False), "b.json"))
            v.import_file(write_env(d, envelope([run(40)], exporter="c3333dead", synthetic=True), "c.json"))
            obj = Path(d) / "obj.json"
            obj.write_text(json.dumps({"objectives": [{"instance": "The Deadmines", "goal": "full_clear", "count": 3},
                                                      {"instance": "The Deadmines", "goal": "boss_kill",
                                                       "boss": "Rhahk'Zor", "count": 10}]}), encoding="utf-8")
            rep = guild.report(v.runs(everyone=True, guild_only=True), guild.read_objectives(obj))
            self.assertEqual((rep["runs"], rep["contributors"]), (5, 1), "no consent, no synthetic")
            dm = rep["places"]["The Deadmines"]
            self.assertEqual((dm["completed"], dm["abandoned"]), (4, 1))
            self.assertEqual(dm["fullClear"]["n"], 5)
            self.assertTrue(rep["objectives"][0]["met"])
            self.assertEqual(rep["objectives"][1]["done"], 5)
            md = guild.markdown(rep)
            self.assertNotIn("c0000abcd", md, "no per-player rows")
            self.assertNotRegex(md.lower().replace("no rankings", ""), r"rank|leaderboard|top player")
            out = Path(d) / "report.md"
            guild.write(rep, out)
            self.assertTrue(out.read_text(encoding="utf-8").startswith("# Guild"))
            with self.assertRaises(guild.GuildError):
                guild.write(rep, Path(d) / "WTF" / "r.md")
            obj.write_text('{"objectives": [{"instance": "X", "goal": "rank_players"}]}', encoding="utf-8")
            with self.assertRaises(guild.GuildError):
                guild.read_objectives(obj)
            v.close()


class IntegrationTest(unittest.TestCase):
    """VG07-07: clean install, round trip, malformed files, offline, independence."""

    def test_clean_install_round_trip_offline(self):
        real = socket.socket

        def no_net(*a, **k):
            raise AssertionError("network used")
        socket.socket = no_net
        try:
            with tempfile.TemporaryDirectory() as d:
                sv = saved_file(d, [run(0), run(1, outcome="incomplete")])
                out = Path(d) / "exp.json"
                vp = Path(d) / "fresh" / "vanguard.sqlite"
                with redirect_stdout(io.StringIO()):
                    self.assertEqual(cli.main(["export", "--savedvariables", str(sv), "--character", "Torrant-Forever",
                                               "--guild", "--out", str(out)], check_game=lambda: True), 0)
                    self.assertEqual(cli.main(["import", "--file", str(out), "--vault", str(vp)]), 0)
                    self.assertEqual(cli.main(["import", "--file", str(out), "--vault", str(vp)]), 0)
                    self.assertEqual(cli.main(["vault", "--vault", str(vp)]), 0)
                    self.assertEqual(cli.main(["backup", "--vault", str(vp)]), 0)
                    g = Path(d) / "group.json"
                    g.write_text(json.dumps(ScenarioTest.GROUP), encoding="utf-8")
                    self.assertEqual(cli.main(["scenario", "--group", str(g), "--instance", "The Deadmines",
                                               "--everyone", "--vault", str(vp)]), 0)
                    self.assertEqual(cli.main(["forecast", "--target", "full_clear", "--everyone",
                                               "--vault", str(vp)]), 0)
                    self.assertEqual(cli.main(["guild", "--vault", str(vp), "--out", str(Path(d) / "g.md")]), 0)
                v = vault.Vault(vp)
                self.assertEqual(v.status()["runRows"], 2)
                v.close()
                self.assertEqual(sv.read_text(encoding="utf-8"), saved_file(d, [run(0), run(1, outcome="incomplete")])
                                 .read_text(encoding="utf-8"), "the saved file is never changed")
        finally:
            socket.socket = real

    def test_malformed_inputs_exit_cleanly(self):
        with tempfile.TemporaryDirectory() as d:
            bad_sv = Path(d) / "Outrider.lua"
            bad_sv.write_text("Outrider_DB = { os.execute('x') }", encoding="utf-8")
            junk = Path(d) / "junk.json"
            junk.write_text("[1,2", encoding="utf-8")
            vp = str(Path(d) / "v.sqlite")
            with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                self.assertEqual(cli.main(["export", "--savedvariables", str(bad_sv), "--character", "X-Y"]), 2)
                self.assertEqual(cli.main(["import", "--file", str(junk), "--vault", vp]), 2)
                self.assertEqual(cli.main(["import", "--file", str(Path(d) / "missing.json"), "--vault", vp]), 2)
                self.assertEqual(cli.main(["scenario", "--group", str(junk), "--vault", vp]), 2)
                self.assertEqual(cli.main(["restore", "--backup", str(Path(d) / "none.sqlite"), "--vault", vp]), 2)

    def test_tables_file_is_present_and_unverified(self):
        t = scenario.tables()
        self.assertIs(t["verified"], False)
        self.assertGreaterEqual(len(t["bosses"]), 29)
        self.assertEqual(sorted(t["roles"]), sorted(contract.CLASSES))


if __name__ == "__main__":
    unittest.main()

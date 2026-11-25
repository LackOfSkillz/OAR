"""OI-FR01 regression: the walked-path export merges, never replaces.

Runs tools/export_trails.lua (through tools/lua.py) on a temporary folder: the
points already shipped stay first and in order, archived and live points are
added, nothing is dropped. Also runs tools/preservation_check.py's self-check
on the repository.
"""
import os
import re
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LUA = os.path.join(ROOT, "tools", "lua.py")
EXPORT = os.path.join(ROOT, "tools", "export_trails.lua")


def have_lupa():
    import importlib.util
    found = importlib.util.find_spec("lupa") is not None
    # under tools/test.ps1 -RequirePython (CI) these tests must run, not skip
    if not found and os.environ.get("OTR_REQUIRE_LUPA") == "1":
        raise RuntimeError("lupa is required here (OTR_REQUIRE_LUPA=1): pip install lupa")
    return found


def points(text, mapid):
    m = re.search(r"\[%d\]=\{([^}]*)\}" % mapid, text)
    if not m:
        return []
    nums = [x for x in m.group(1).split(",") if x]
    return [(nums[i], nums[i + 1]) for i in range(0, len(nums) - 1, 2)]


@unittest.skipUnless(have_lupa(), "lupa not installed")
class ExportMerges(unittest.TestCase):
    def run_export(self, out, sv, *bases):
        r = subprocess.run([sys.executable, LUA, EXPORT, sv, out, "test", *bases], cwd=ROOT,
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        with open(os.path.join(out, "Data.lua"), encoding="utf-8") as f:
            return f.read()

    def test_shipped_points_survive_a_smaller_live_list(self):
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, "Data.lua"), "w", encoding="utf-8") as f:
                f.write('Outrider_DataTrails = { maps = { [1420]={0.100,0.100,0.200,0.200,0.300,0.300}, [1411]={0.500,0.500} } }\n')
            sv = os.path.join(d, "sv.lua")
            with open(sv, "w", encoding="utf-8") as f:
                f.write("Outrider_DB = { global = {\n"
                        "  trails = { [1420] = { {x=0.3,y=0.3}, {x=0.4,y=0.4} } },\n"
                        "  archive = { v = 2, sets = {\n"
                        "    trail = { { keys = { mapID = 1420 }, row = { x = 0.25, y = 0.25 } } },\n"
                        "    trailCleared = { { keys = { mapID = 1438 }, row = { {x=0.6,y=0.6} } } } } } } }\n")
            text = self.run_export(d, sv)
            self.assertEqual(points(text, 1420), [("0.100", "0.100"), ("0.200", "0.200"), ("0.300", "0.300"),
                                                  ("0.250", "0.250"), ("0.400", "0.400")])
            self.assertEqual(points(text, 1411), [("0.500", "0.500")], "a map missing from the live list is kept")
            self.assertEqual(points(text, 1438), [("0.600", "0.600")], "a cleared (archived) trail is exported")

    def test_extra_base_file_is_merged(self):
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, "Data.lua"), "w", encoding="utf-8") as f:
                f.write('Outrider_DataTrails = { maps = { [1420]={0.100,0.100} } }\n')
            old = os.path.join(d, "old.lua")
            with open(old, "w", encoding="utf-8") as f:
                f.write('Outrider_DataTrails = { maps = { [1420]={0.900,0.900,0.100,0.100} } }\n')
            text = self.run_export(d, "-", old)
            self.assertEqual(points(text, 1420), [("0.100", "0.100"), ("0.900", "0.900")])


class PreservationGate(unittest.TestCase):
    def test_repository_keeps_the_base_data(self):
        r = subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tools", "preservation_check.py")],
                           cwd=ROOT, capture_output=True, text=True)
        if r.returncode == 2:
            self.skipTest(r.stdout.strip())
        self.assertEqual(r.returncode, 0, r.stdout)



sys.path.insert(0, os.path.join(ROOT, "tools"))
import preservation_check as PC  # noqa: E402

BASE = '''local _, ns = ...
local SRC = "warcraft db, read 2026-11-15"
ns.Data:Register("rare", "test", {
  { id = 12345, name = "The Rake", strength = 15, agility = 20, dropRate = 0.12, source = SRC },
  { id = 777, name = "Twin", x = 0.1 },
  { id = 777, name = "Twin", x = 0.2 },
})
'''


@unittest.skipUnless(have_lupa(), "lupa not installed")
class ContentLevel(unittest.TestCase):
    """review OI-FR14: keeping an id while losing what it holds fails the gate"""

    def check(self, cur, revisions=None):
        problems, unverified = [], []
        PC.compare_file("addon/Outrider/Data/Test.lua", BASE, cur, "addon/Outrider/Data/Test.lua", PC.flattener(),
                        revisions or {}, problems, unverified)
        return problems, unverified

    def test_unchanged_and_added_pass(self):
        self.assertEqual(self.check(BASE), ([], []))
        added = BASE.replace('  { id = 777, name = "Twin", x = 0.1 },', '  { id = 1, name = "New" },\n  { id = 777, name = "Twin", x = 0.1 },')
        self.assertEqual(self.check(added)[0], [], "inserting a record doesn't shift the others")

    def test_id_kept_contents_destroyed_fails(self):
        emptied = BASE.replace('name = "The Rake", strength = 15, agility = 20, dropRate = 0.12, source = SRC', '')
        problems, _ = self.check(emptied)
        self.assertTrue(problems and "value(s) changed or missing" in problems[0], problems)
        self.assertEqual(PC.ids(BASE) - PC.ids(emptied), set(), "the old id-only check would have passed it")

    def test_changed_value_lost_attribution_and_lost_duplicate_fail(self):
        for cur in (BASE.replace("dropRate = 0.12", "dropRate = 0.5"),
                    BASE.replace('local SRC = "warcraft db, read 2026-11-15"', 'local SRC = nil'),
                    BASE.replace('  { id = 777, name = "Twin", x = 0.2 },\n', '')):
            self.assertTrue(self.check(cur)[0], cur)

    def test_a_recorded_revision_keeps_the_old_value_and_passes(self):
        cur = BASE.replace("dropRate = 0.12", "dropRate = 0.5")
        allowed = {"addon/Outrider/Data/Test.lua": {'ns.Data.packs.rare.test[id=12345#1].dropRate' + chr(9) + "0.12"}}
        self.assertEqual(self.check(cur, allowed)[0], [])

    def test_a_file_the_sandbox_cant_run_is_reported_not_passed(self):
        odd = "local _, ns = ...\nns.Compat.Call('x')\n" + BASE
        problems, unverified = self.check(odd)
        self.assertTrue(any("can't run in the sandbox" in u for u in unverified), unverified)
        self.assertEqual(problems, [], "falls back to the id check, which this passes")


if __name__ == "__main__":
    unittest.main()

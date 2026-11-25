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
    try:
        import lupa  # noqa: F401
        return True
    except Exception:
        return False


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


if __name__ == "__main__":
    unittest.main()

"""OI02-14: Nexus v4 records over the OTR1 transport, Lua -> Python and Python -> Lua.

tests/fixtures/contract/nexus_v4_otr1.txt is written by the addon (tools/nexus_fixtures.lua);
nexus_v4_otr1_py.txt by this companion's encoder. Both must decode to the shared
fixture records, validate, and keep ids and numbers. Fuzzed records never carry an action.
"""
import os
import random
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from outrider_companion import codes  # noqa: E402
from outrider_companion.intelligence import schemas_v4  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _lines(name):
    out = []
    with open(os.path.join(ROOT, "tests", "fixtures", "contract", name), encoding="utf-8") as fh:
        for line in fh:
            line = line.rstrip("\r\n")
            if "\t" in line:
                out.append(line.split("\t", 1))
    return out


def _norm(v):
    if isinstance(v, dict) and not v:
        return []
    if isinstance(v, dict):
        return {k: _norm(x) for k, x in v.items()}
    if isinstance(v, list):
        return [_norm(x) for x in v]
    return v


class NexusTransport(unittest.TestCase):
    def setUp(self):
        self.valid = [c for c in schemas_v4.fixtures() if c["ok"]]

    def test_lua_codes_decode_to_the_shared_records(self):
        got = _lines("nexus_v4_otr1.txt")
        self.assertEqual(len(got), len(self.valid))
        for (rec, code), case in zip(got, self.valid):
            data = codes.import_code(code)
            self.assertEqual(rec, case["record"])
            self.assertEqual(_norm(data), _norm(case["data"]), rec)
            self.assertEqual(schemas_v4.validate(rec, data), (True, None))

    def test_python_codes_are_current(self):
        got = _lines("nexus_v4_otr1_py.txt")
        for (rec, code), case in zip(got, self.valid):
            self.assertEqual(code, codes.export(case["data"]), "regenerate nexus_v4_otr1_py.txt if the contract changed")

    def test_fuzz_never_lets_an_action_through(self):
        rng = random.Random(4242)
        junk = ["x|cffff0000", 1e300, -1, 0.5, True, "/cast Fireball", [1, 2], "a" * 400, ""]
        extras = ["action", "macro", "run", "script", "cast"]
        rejected = kept = 0
        for case in self.valid:
            fields = sorted(case["data"])
            for _ in range(150):
                d = dict(case["data"])
                how = rng.randint(1, 3)
                if how == 1:
                    d[rng.choice(fields)] = rng.choice(junk)
                elif how == 2:
                    d[rng.choice(extras)] = rng.choice(junk)
                else:
                    d.pop(rng.choice(fields), None)
                ok, _ = schemas_v4.validate(case["record"], d)
                if ok:
                    kept += 1
                    self.assertFalse(set(d) & set(extras))
                    if "intent" in d:
                        self.assertIn(d["intent"], ("waypoint", "panel", "none"))
                else:
                    rejected += 1
        self.assertGreater(rejected, 500)
        self.assertGreater(kept, 0)


if __name__ == "__main__":
    unittest.main()

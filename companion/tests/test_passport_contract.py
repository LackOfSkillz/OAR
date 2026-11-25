"""OI-FR12: the Python reader against the shared Passport contract fixtures.

tests/spec/passport_spec.lua runs the same fixtures through the Lua reader.
"""
import json
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

from outrider_companion import codes  # noqa: E402
from outrider_companion.intelligence import passport  # noqa: E402

with open(os.path.join(HERE, "fixtures", "passport_contract.json"), encoding="utf-8") as f:
    CONTRACT = json.load(f)


def body_for(case):
    body = json.loads(json.dumps(CONTRACT["base"]))
    body.update(case.get("body", {}))
    return body


def text_for(body):
    return "OTRP1" + codes.export(body)[len(codes.TAG):]


class Contract(unittest.TestCase):
    def test_cases(self):
        for case in CONTRACT["cases"]:
            with self.subTest(case["name"]):
                o = case.get("opts", {})
                want = case["expect"]
                try:
                    d = passport.read(text_for(body_for(case)), expect_id=o.get("id"), expect_build=o.get("build"),
                                      now=o.get("now"))
                except passport.PassportError as exc:
                    self.assertFalse(want["ok"], f"refused: {exc}")
                    self.assertEqual(str(exc), want["why"])
                    continue
                self.assertTrue(want["ok"], f"accepted, wanted {want.get('why')}")
                self.assertEqual(sorted(d["fields"]), want["fields"])
                self.assertEqual(d["dropped"], want["dropped"])

    def test_texts(self):
        for t in CONTRACT["texts"]:
            with self.subTest(t["name"]):
                text = t.get("text") or t["repeat"] * t["count"]
                with self.assertRaises(passport.PassportError) as ctx:
                    passport.read(text, now=2000)
                self.assertEqual(str(ctx.exception), t["why"])


if __name__ == "__main__":
    unittest.main()

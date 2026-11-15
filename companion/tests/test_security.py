"""Static security checks (spec AI06-04). Run: py -I companion/tests/test_security.py

Fails if code that could run model text, reach a shell, or write outside its
lanes appears in the companion or the addon. Allowed exceptions are listed
by file with the reason.
"""
import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
COMPANION = os.path.join(ROOT, "companion", "outrider_companion")
ADDON = os.path.join(ROOT, "addon", "Outrider")

PY_BANNED = [r"\beval\(", r"\bexec\(", r"\bos\.system\(", r"shell\s*=\s*True", r"\bpickle\b", r"\bmarshal\b",
             r"__import__\(\s*[\"']subprocess", r"(?<!re\.)\bcompile\("]
# clipboard.py runs a fixed PowerShell command (Get-Clipboard / Set-Clipboard),
# no shell, no user text in the command line
PY_SUBPROCESS_OK = {"clipboard.py"}
LUA_BANNED = [r"\bloadstring\s*\(", r"\bRunScript\s*\(", r"\bRunMacroText\s*\(", r"\bCastSpellByName\s*\(",
              r"\bSendChatMessage\s*\("]
# files that may mention these in comments only are fine: comments are stripped first


def files(base, ext):
    for d, _, fs in os.walk(base):
        if "__pycache__" in d:
            continue
        for f in fs:
            if f.endswith(ext):
                yield os.path.join(d, f)


def strip_py_comments(t):
    return "\n".join(line.split("#", 1)[0] for line in t.splitlines())


def strip_lua_comments(t):
    t = re.sub(r"--\[\[.*?\]\]", "", t, flags=re.S)
    return "\n".join(line.split("--", 1)[0] for line in t.splitlines())


class Static(unittest.TestCase):
    def test_companion_never_runs_text_or_a_shell(self):
        bad = []
        for path in files(COMPANION, ".py"):
            text = strip_py_comments(open(path, encoding="utf-8").read())
            for pat in PY_BANNED:
                if re.search(pat, text):
                    bad.append("%s: %s" % (os.path.basename(path), pat))
            if re.search(r"\bsubprocess\b", text) and os.path.basename(path) not in PY_SUBPROCESS_OK:
                bad.append("%s: subprocess" % os.path.basename(path))
        self.assertEqual(bad, [])

    def test_companion_writes_only_where_allowed(self):
        # open(..., "w") only in: advice.py (Advice.lua), ask.py (--out file), budget.py (usage.json)
        allowed = {"advice.py", "ask.py", "budget.py"}
        bad = []
        for path in files(COMPANION, ".py"):
            text = strip_py_comments(open(path, encoding="utf-8").read())
            if re.search(r"open\([^)]*[\"'][wa]b?[\"']", text) and os.path.basename(path) not in allowed:
                bad.append(os.path.basename(path))
        self.assertEqual(bad, [])

    def test_addon_never_runs_strings_or_acts_alone(self):
        bad = []
        for path in files(ADDON, ".lua"):
            text = strip_lua_comments(open(path, encoding="utf-8").read())
            for pat in LUA_BANNED:
                if re.search(pat, text):
                    bad.append("%s: %s" % (os.path.relpath(path, ADDON), pat))
        self.assertEqual(bad, [])

    def test_no_secrets_in_the_repo_tree(self):
        pat = re.compile(r"sk-(ant-)?[A-Za-z0-9]{20,}|AIza[0-9A-Za-z_\-]{30,}")
        hits = []
        for base in (COMPANION, ADDON, os.path.join(ROOT, "docs"), os.path.join(ROOT, "tools")):
            for path in list(files(base, ".py")) + list(files(base, ".lua")) + list(files(base, ".md")) + list(files(base, ".json")):
                if pat.search(open(path, encoding="utf-8", errors="replace").read()):
                    hits.append(os.path.relpath(path, ROOT))
        self.assertEqual(hits, [])


if __name__ == "__main__":
    unittest.main()

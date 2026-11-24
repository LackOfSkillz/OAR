"""tools/security_check.py - static security gate (OI01-13). Standard library only.

    python -I tools/security_check.py            check the repo, exit 1 on a violation
    python -I tools/security_check.py --selftest negative fixtures must all be caught

Adds token- and AST-level checks on top of the regex checks in companion/tests/test_security.py:

Lua (addon/, tokens from tools/comment_only.py, so comments never count and STRINGS DO count:
     looking a banned function up by name, e.g. rawget(_G, "SendChatMessage"), is caught too)
  * code execution from text: loadstring, RunScript, RunMacroText, load (as a call)
  * protected or automating actions: CastSpellByName, CastSpellByID, TargetUnit, UseAction,
    SendChatMessage, AcceptQuest, CompleteQuest, PlaceAuctionBid, PostAuction, PickupMerchantItem...
  * combat log: CombatLogGetCurrentEventInfo, COMBAT_LOG_EVENT_UNFILTERED
  Each allowed use is listed in ALLOW with the file and the reason (a player click, a refusal list).
Python (companion/, tools/), by AST:
  * eval/exec/compile calls, os.system, pickle/marshal imports, subprocess with shell=True
  * network: http(s) URL literals must be in HOSTS (the three model providers the owner configures,
    localhost); urllib/http.client imports only in ALLOW_NET files
Whole repo (tracked text files): strings shaped like real secrets (sk-..., AKIA..., ghp_...,
  "api_key": "<long>"), excluding obvious placeholders.

Limits: static only. It cannot see a name built at runtime from pieces ("Send".."Chat"); the
review checklist covers that. It is a floor, not a proof.
"""
import ast
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from comment_only import tokens  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LUA_BANNED = {
    "loadstring", "RunScript", "RunMacroText", "CastSpellByName", "CastSpellByID", "TargetUnit", "AssistUnit",
    "UseAction", "SendChatMessage", "AcceptQuest", "CompleteQuest", "GetQuestReward", "PlaceAuctionBid",
    "PostAuction", "PickupMerchantItem", "BuyMerchantItem", "CombatLogGetCurrentEventInfo",
    "COMBAT_LOG_EVENT_UNFILTERED", "COMBAT_LOG_EVENT", "SpellStopCasting", "JumpOrAscendStart", "MoveForwardStart",
}
# (file, name): reason. File paths relative to the repo, forward slashes.
ALLOW = {
    ("addon/Outrider/Core/Events.lua", "COMBAT_LOG_EVENT_UNFILTERED"): "the refusal list Events.FORBIDDEN",
    ("addon/Outrider/Core/Events.lua", "COMBAT_LOG_EVENT"): "the refusal list Events.FORBIDDEN",
    ("addon/Outrider/Modules/PartyQuests.lua", "SendChatMessage"):
        "quest progress lines in PARTY chat (like Questie's announce), setting 'announce', rate-limited queue; reviewed OI01-13",
    ("addon/Outrider/Modules/Merchant.lua", "BuyMerchantItem"):
        "vendor restock, called only from the visible Restock button with the vendor open, out of combat; reviewed OI01-13",
}
ALLOW_PREFIX = ("addon/Outrider/Core/Probe.lua",)  # API names listed for /ride probe existence checks only

HOSTS = {"api.anthropic.com", "api.openai.com", "generativelanguage.googleapis.com", "127.0.0.1", "localhost",
         "wago.tools", "github.com", "raw.githubusercontent.com", "api.github.com", "curseforge.com",
         "www.curseforge.com", "wow.curseforge.com", "legacy.curseforge.com"}
ALLOW_NET = {"companion/outrider_companion/intelligence/cloud.py", "companion/outrider_companion/intelligence/providers.py",
             "companion/outrider_companion/intelligence/doctor.py", "companion/outrider_companion/server.py",
             "tools/import_map_overlays.py", "tools/import_crafting.py", "tools/foreverdb.py", "tools/publish_public_packs.py"}
SECRET = re.compile(r"\b(sk-[A-Za-z0-9_-]{24,}|sk-ant-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{30,}|"
                    r"xox[bp]-[A-Za-z0-9-]{20,})\b|[\"'](?:api_?key|token|secret)[\"']\s*[:=]\s*[\"'][A-Za-z0-9_\-]{24,}[\"']",
                    re.I)


def rel(p):
    try:
        return os.path.relpath(p, ROOT).replace("\\", "/")
    except ValueError:  # another drive (CI checks out on D:, temp files live on C:)
        return p.replace("\\", "/")


def lua_violations(paths):
    out = []
    for p in paths:
        r = rel(p) if os.path.isabs(p) else p
        if r.startswith(ALLOW_PREFIX):
            continue
        with open(p, encoding="utf-8", errors="replace") as fh:
            src = fh.read()
        for t in tokens(src):
            name = t[1:-1] if t[:1] in "\"'" else t
            if name in LUA_BANNED and (r, name) not in ALLOW:
                out.append("%s: %s%s" % (r, name, " (as a string)" if t[:1] in "\"'" else ""))
            elif name == "load" and t == "load":
                out.append("%s: load" % r)
    return sorted(set(out))


def py_violations(paths):
    out = []
    for p in paths:
        r = rel(p) if os.path.isabs(p) else p
        with open(p, encoding="utf-8", errors="replace") as fh:
            src = fh.read()
        try:
            tree = ast.parse(src)
        except SyntaxError:
            out.append("%s: syntax error" % r)
            continue
        for n in ast.walk(tree):
            if isinstance(n, ast.Call):
                f = n.func
                name = f.id if isinstance(f, ast.Name) else (f.attr if isinstance(f, ast.Attribute) else None)
                if name in ("eval", "exec") or (name == "compile" and isinstance(f, ast.Name)):
                    out.append("%s:%d: %s()" % (r, n.lineno, name))
                if name == "system" and isinstance(f, ast.Attribute) and getattr(f.value, "id", "") == "os":
                    out.append("%s:%d: os.system()" % (r, n.lineno))
                for kw in n.keywords:
                    if kw.arg == "shell" and isinstance(kw.value, ast.Constant) and kw.value.value is True:
                        out.append("%s:%d: shell=True" % (r, n.lineno))
            elif isinstance(n, (ast.Import, ast.ImportFrom)):
                mods = [a.name for a in n.names] if isinstance(n, ast.Import) else [n.module or ""]
                for m in mods:
                    if m.split(".")[0] in ("pickle", "marshal"):
                        out.append("%s:%d: import %s" % (r, n.lineno, m))
                    if m.split(".")[0] in ("urllib", "http") and r not in ALLOW_NET and not r.startswith("companion/tests/"):
                        if m not in ("urllib.parse",):
                            out.append("%s:%d: network import %s outside ALLOW_NET" % (r, n.lineno, m))
            elif isinstance(n, ast.Constant) and isinstance(n.value, str):
                for host in re.findall(r"https?://([A-Za-z0-9.-]+)", n.value):
                    if host.lower() not in HOSTS and not r.startswith(("companion/tests/", "tools/")):
                        out.append("%s:%d: URL host %s not allowlisted" % (r, n.lineno, host))
    return sorted(set(out))


def secret_violations(paths):
    out = []
    for p in paths:
        try:
            with open(p, encoding="utf-8") as fh:
                for i, line in enumerate(fh, 1):
                    m = SECRET.search(line)
                    if m and not re.search(r"example|placeholder|your[-_ ]?key|xxxx|dummy|test", line, re.I):
                        out.append("%s:%d: looks like a secret" % (rel(p) if os.path.isabs(p) else p, i))
        except (UnicodeDecodeError, OSError):
            continue
    return out


def tracked():
    res = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True, text=True, encoding="utf-8")
    return [os.path.join(ROOT, f) for f in res.stdout.split("\n") if f]


def check():
    files = tracked()
    lua = [f for f in files if f.endswith(".lua") and rel(f).startswith("addon/")]
    py = [f for f in files if f.endswith(".py") and rel(f).startswith(("companion/", "tools/"))]
    text = [f for f in files if os.path.splitext(f)[1] in (".lua", ".py", ".ps1", ".json", ".md", ".toc", ".txt", ".yml")]
    bad = lua_violations(lua) + py_violations(py) + secret_violations(text)
    for b in bad:
        print("SECURITY " + b)
    print("security: %d Lua, %d Python, %d text files checked, %d violations" % (len(lua), len(py), len(text), len(bad)))
    return 1 if bad else 0


def selftest():
    import tempfile
    d = tempfile.mkdtemp()

    def w(name, body):
        p = os.path.join(d, name)
        with open(p, "w", encoding="utf-8") as fh:
            fh.write(body)
        return p
    lua = w("bad.lua", "local f = rawget(_G, 'SendChatMessage')\nloadstring('x')()\n-- CastSpellByName in a comment is fine\n"
                       "local g = _G[\"RunMacroText\"]\nload(s)\n")
    got = lua_violations([lua])
    names = sorted(x.split(": ", 1)[1].split(" ")[0] for x in got)
    assert names == ["RunMacroText", "SendChatMessage", "load", "loadstring"], got
    py = w("bad.py", "import pickle\nimport subprocess\nsubprocess.run('x', shell=True)\neval('1')\nimport os\nos.system('x')\n"
                     "URL = 'https://evil.example.net/x'\nimport urllib.request\n")
    got = py_violations([py])
    kinds = sorted({re.sub(r"^[^:]+:\d+: ", "", x).split(" ")[0] for x in got})
    assert kinds == ["URL", "eval()", "import", "network", "os.system()", "shell=True"], kinds
    fake = "sk" + "-ant-" + "abcdefghijklmnopqrstuvwxyz012345"  # built at runtime so no secret-shaped text sits in the repo
    sec = w("s.txt", 'key = "' + fake + '"' + chr(10) + "placeholder " + fake + chr(10))
    assert len(secret_violations([sec])) == 1
    print("security selftest: ok")
    return 0


if __name__ == "__main__":
    sys.exit(selftest() if "--selftest" in sys.argv else check())

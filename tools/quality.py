"""tools/quality.py - code health report and gate (OI01-06).

Standard library only, no downloads. Python 3.9+.

    python -I tools/quality.py            report (writes docs/quality/report.md)
    python -I tools/quality.py --check    exit 1 on any finding not in docs/quality/baseline.json
    python -I tools/quality.py --update   rewrite the baseline from the current tree (owner-reviewed)
    python -I tools/quality.py --coverage dist/lua_coverage.txt   add Lua line coverage to the report

Checks
  Lua (addon/): files over LUA_FILE_LINES lines; functions over LUA_FUNC_LINES lines, found by a small
    tokenizer that skips strings and comments and matches function/if/for/while/do/repeat with end/until.
  Python (companion/, tools/): syntax; unused imports; bare `except:`; mutable default arguments;
    eval/exec calls (the companion must never run text it reads).
  Coverage: tests/run_tests.lua writes executed "file<TAB>line" pairs when OTR_COVERAGE is set; this
    script divides them by executable lines (non-blank, non-comment, not just `end`/`else`/brackets).
    The number is measured, never estimated.

Limits: the Lua tokenizer understands Lua 5.1 syntax but is not a full parser; a finding names
file:line so a person can confirm it. Luacheck and Ruff (pinned) are the planned upgrade once the
owner approves fetching them.
"""
import ast
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASELINE = os.path.join(ROOT, "docs", "quality", "baseline.json")
REPORT = os.path.join(ROOT, "docs", "quality", "report.md")
LUA_FILE_LINES = 1500
LUA_FUNC_LINES = 150
LUA_DIRS = ["addon"]
PY_DIRS = ["companion", "tools"]
SKIP_LUA_SIZE = ("addon/Outrider/Data/", "addon/Outrider_Data_")  # generated data tables


def rel(p):
    return os.path.relpath(p, ROOT).replace("\\", "/")


def walk(dirs, ext):
    for d in dirs:
        for base, subdirs, files in os.walk(os.path.join(ROOT, d)):
            subdirs[:] = [s for s in subdirs if s not in ("__pycache__", ".git", "private", "dist")]
            for f in sorted(files):
                if f.endswith(ext):
                    yield os.path.join(base, f)


# ------------------------------------------------------------------ Lua
OPENERS = {"function", "if", "for", "while", "repeat"}
TOKEN = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def lua_tokens(src):
    """Yield (word, line) for identifiers/keywords, skipping strings and comments."""
    i, n, line = 0, len(src), 1
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            i += 1
        elif src.startswith("--", i):
            m = re.match(r"--\[(=*)\[", src[i:])
            if m:
                close = "]" + m.group(1) + "]"
                j = src.find(close, i)
                j = n if j < 0 else j + len(close)
            else:
                j = src.find("\n", i)
                j = n if j < 0 else j
            line += src.count("\n", i, j)
            i = j
        elif c == "[" and re.match(r"\[(=*)\[", src[i:]):
            m = re.match(r"\[(=*)\[", src[i:])
            close = "]" + m.group(1) + "]"
            j = src.find(close, i)
            j = n if j < 0 else j + len(close)
            line += src.count("\n", i, j)
            i = j
        elif c in "\"'":
            j = i + 1
            while j < n and src[j] != c:
                if src[j] == "\\":
                    j += 1
                elif src[j] == "\n":
                    break
                j += 1
            line += src.count("\n", i, j)
            i = j + 1
        elif c.isalpha() or c == "_":
            m = TOKEN.match(src, i)
            yield m.group(0), line
            i = m.end()
        else:
            i += 1


def lua_functions(src):
    """[(start_line, end_line)] of every function body, by block matching."""
    stack, out = [], []
    pending_do = 0  # `for`/`while` own their `do`
    for word, line in lua_tokens(src):
        if word in OPENERS:
            stack.append((word, line))
            if word in ("for", "while"):
                pending_do += 1
        elif word == "do":
            if pending_do:
                pending_do -= 1
            else:
                stack.append(("do", line))
        elif word in ("end", "until"):
            if stack:
                kind, start = stack.pop()
                if kind == "function":
                    out.append((start, line))
    return out


def lua_findings():
    found = []
    for path in walk(LUA_DIRS, ".lua"):
        r = rel(path)
        with open(path, encoding="utf-8", errors="replace") as fh:
            src = fh.read()
        lines = src.count("\n") + 1
        if not r.startswith(SKIP_LUA_SIZE) and lines > LUA_FILE_LINES:
            found.append({"id": "lua-file-size:" + r, "where": r, "what": "%d lines (> %d)" % (lines, LUA_FILE_LINES)})
        if r.startswith(SKIP_LUA_SIZE):
            continue
        for start, end in lua_functions(src):
            if end - start + 1 > LUA_FUNC_LINES:
                found.append({"id": "lua-func-size:%s:%d" % (r, start), "where": "%s:%d" % (r, start),
                              "what": "function of %d lines (> %d)" % (end - start + 1, LUA_FUNC_LINES)})
    return found


# ------------------------------------------------------------------ Python
def py_findings():
    found = []
    for path in walk(PY_DIRS, ".py"):
        r = rel(path)
        with open(path, encoding="utf-8", errors="replace") as fh:
            src = fh.read()
        try:
            tree = ast.parse(src, filename=r)
        except SyntaxError as e:
            found.append({"id": "py-syntax:" + r, "where": "%s:%s" % (r, e.lineno), "what": "syntax error"})
            continue
        imported, used = {}, set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                for a in node.names:
                    imported[(a.asname or a.name).split(".")[0]] = node.lineno
            elif isinstance(node, ast.ImportFrom) and node.module != "__future__":
                for a in node.names:
                    if a.name != "*":
                        imported[a.asname or a.name] = node.lineno
            elif isinstance(node, ast.Name):
                used.add(node.id)
            elif isinstance(node, ast.Attribute):
                base = node
                while isinstance(base, ast.Attribute):
                    base = base.value
                if isinstance(base, ast.Name):
                    used.add(base.id)
            elif isinstance(node, ast.ExceptHandler) and node.type is None:
                found.append({"id": "py-bare-except:%s:%d" % (r, node.lineno), "where": "%s:%d" % (r, node.lineno),
                              "what": "bare except"})
            elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                for d in node.args.defaults + node.args.kw_defaults:
                    if isinstance(d, (ast.List, ast.Dict, ast.Set)):
                        found.append({"id": "py-mutable-default:%s:%s" % (r, node.name), "where": "%s:%d" % (r, node.lineno),
                                      "what": "mutable default argument in %s" % node.name})
            elif isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id in ("eval", "exec"):
                found.append({"id": "py-eval:%s:%d" % (r, node.lineno), "where": "%s:%d" % (r, node.lineno),
                              "what": "%s() call" % node.func.id})
        all_names = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Assign):
                for t in node.targets:
                    if isinstance(t, ast.Name) and t.id == "__all__" and isinstance(node.value, (ast.List, ast.Tuple)):
                        all_names |= {e.value for e in node.value.elts if isinstance(e, ast.Constant)}
        if not r.endswith("__init__.py"):
            for name, line in sorted(imported.items()):
                if name not in used and name not in all_names and name != "__future__":
                    found.append({"id": "py-unused-import:%s:%s" % (r, name), "where": "%s:%d" % (r, line),
                                  "what": "unused import %s" % name})
    return found


# ------------------------------------------------------------------ coverage
EXEC_SKIP = re.compile(r"^\s*(--.*)?$|^\s*(end|else|\}|\)|\]|end\)|end,|\},|\}\)|\)\s*,?)\s*(--.*)?$")


def coverage(path):
    hit = {}
    with open(path, encoding="utf-8", errors="replace") as fh:
        for row in fh:
            parts = row.rstrip("\n").split("\t")
            if len(parts) == 2 and parts[1].isdigit():
                f = parts[0].lstrip("@").replace("\\", "/")
                i = f.find("addon/")
                if i >= 0:
                    hit.setdefault(f[i:], set()).add(int(parts[1]))
    rows, tot_e, tot_h = [], 0, 0
    for p in walk(["addon/Outrider"], ".lua"):
        r = rel(p)
        if r.startswith(SKIP_LUA_SIZE):
            continue
        with open(p, encoding="utf-8", errors="replace") as fh:
            lines = fh.read().split("\n")
        execl = {i + 1 for i, l in enumerate(lines) if not EXEC_SKIP.match(l)}
        h = len(execl & hit.get(r, set()))
        rows.append((r, len(execl), h))
        tot_e += len(execl)
        tot_h += h
    return rows, tot_e, tot_h


# ------------------------------------------------------------------ self test
def selftest():
    """The checks must catch planted problems (negative fixtures), or the gate means nothing."""
    nl = chr(10)
    body = nl.join("  x = x + %d" % i for i in range(LUA_FUNC_LINES + 5))
    lua = "local s = 'function if for' -- function" + nl + "local function big()" + nl + body + nl + "end" + nl + "for i = 1, 2 do end" + nl
    spans = lua_functions(lua)
    assert len(spans) == 1 and spans[0][1] - spans[0][0] + 1 > LUA_FUNC_LINES, spans
    assert lua_functions("local t = [[function]] while true do end") == []
    import tempfile
    d = tempfile.mkdtemp()
    f = os.path.join(d, "bad.py")
    with open(f, "w", encoding="utf-8") as fh:
        fh.write(nl.join(["import os", "def f(a=[]):", "    try:", "        eval('1')", "    except:", "        pass", ""]))
    old = list(PY_DIRS)
    try:
        PY_DIRS[:] = [d]
        kinds = sorted({x["id"].split(":")[0] for x in py_findings()})
    finally:
        PY_DIRS[:] = old
    assert kinds == ["py-bare-except", "py-eval", "py-mutable-default", "py-unused-import"], kinds
    print("quality selftest: ok")
    return 0


# ------------------------------------------------------------------ main
def main(argv):
    if "--selftest" in argv:
        return selftest()
    findings = lua_findings() + py_findings()
    ids = sorted({f["id"] for f in findings})
    base = []
    if os.path.exists(BASELINE):
        with open(BASELINE, encoding="utf-8") as fh:
            base = json.load(fh).get("accepted", [])
    if "--update" in argv:
        os.makedirs(os.path.dirname(BASELINE), exist_ok=True)
        with open(BASELINE, "w", encoding="utf-8") as fh:
            json.dump({"note": "Existing findings accepted as the OI01-06 baseline; new code must not add any.",
                       "accepted": ids}, fh, indent=1)
            fh.write("\n")
        print("baseline: %d findings recorded" % len(ids))
        return 0
    new = [f for f in findings if f["id"] not in set(base)]
    fixed = sorted(set(base) - set(ids))
    out = ["# Code health report", "",
           "Generated by `python -I tools/quality.py`. Findings: %d (baseline %d, new %d, fixed since baseline %d)."
           % (len(findings), len(base), len(new), len(fixed)), "",
           "| Where | Finding | In baseline |", "|---|---|---|"]
    for f in sorted(findings, key=lambda x: x["where"]):
        out.append("| %s | %s | %s |" % (f["where"], f["what"], "yes" if f["id"] in base else "**NEW**"))
    if "--coverage" in argv:
        k = argv.index("--coverage")
        rows, e, h = coverage(argv[k + 1])
        out += ["", "## Lua line coverage (measured)", "",
                "Total: %d of %d executable lines run by the specs (%.1f%%)." % (h, e, 100.0 * h / max(e, 1)), "",
                "| File | Executable | Run | % |", "|---|---|---|---|"]
        for r, ex, hh in sorted(rows, key=lambda x: (x[2] / max(x[1], 1), x[0])):
            out.append("| %s | %d | %d | %.0f%% |" % (r, ex, hh, 100.0 * hh / max(ex, 1)))
    if "--check" in argv and "--coverage" not in argv:
        out = None  # the gate run doesn't rewrite the committed report
    if out is not None:
      os.makedirs(os.path.dirname(REPORT), exist_ok=True)
      with open(REPORT, "w", encoding="utf-8") as fh:
        fh.write("\n".join(out) + "\n")
    for f in new:
        print("NEW %s: %s" % (f["where"], f["what"]))
    print("quality: %d findings, %d new, %d fixed since baseline" % (len(findings), len(new), len(fixed)))
    if "--check" in argv and new:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

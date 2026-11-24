"""tools/deps.py - module dependency and coupling audit (OI01-12). Standard library only.

    python -I tools/deps.py            write docs/quality/deps.md
    python -I tools/deps.py --check    exit 1 on a new cycle or new private access not in docs/quality/deps_baseline.json
    python -I tools/deps.py --update   re-record the baseline (owner-reviewed)

What it reads (addon/Outrider, comments and strings removed):
  * owners: a file that assigns `ns.Name =` (or `ns.Name = M`) owns that namespace handle
  * uses: `ns.Name` read in another file -> dependency edge file -> owner file
  * private access: `ns.Name.lowercase` field read from another file (fields starting with a
    lowercase letter are module state by convention; Capitalized ones are the public API)
  * events: `Events:Fire("OTR_X")` producers and `On("OTR_X")` listeners
Cycles are strongly connected groups of files in the dependency graph. Mutual calls at runtime are
normal in an addon, so existing cycles are the baseline; the gate stops new ones from growing.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = os.path.join(ROOT, "addon", "Outrider")
OUT = os.path.join(ROOT, "docs", "quality", "deps.md")
BASE = os.path.join(ROOT, "docs", "quality", "deps_baseline.json")
CORE_SHARED = {"Compat", "UI", "Theme", "Events", "Log", "Timer", "Combat", "Modules", "DB", "Errors", "db",
               "Hub", "Data", "Safe", "Print", "AddCommand", "TitleCase", "CopyTable", "Slash", "SecureButtons",
               "Toast", "TooltipLines", "PlayerClass", "Throttle", "ThrottleCancel", "Perf", "Probe", "Art",
               "session", "build", "version", "key", "ADDON", "PREFIX", "SCHEMA", "Comm"}


def strip(src):
    """Remove comments and string contents (keep quotes) so names inside text don't count."""
    out, i, n = [], 0, len(src)
    while i < n:
        if src.startswith("--", i):
            m = re.match(r"--\[(=*)\[", src[i:])
            if m:
                j = src.find("]" + m.group(1) + "]", i)
                j = n if j < 0 else j + 2 + len(m.group(1))
            else:
                j = src.find("\n", i)
                j = n if j < 0 else j
            out.append("\n" * src.count("\n", i, j))
            i = j
        elif src[i] in "\"'":
            q, j = src[i], i + 1
            while j < n and src[j] != q and src[j] != "\n":
                j += 2 if src[j] == "\\" else 1
            out.append(src[i:j + 1] if re.fullmatch(r"[\"']OTR_\w+[\"']", src[i:j + 1] or "") else q + q)
            i = j + 1
        else:
            out.append(src[i])
            i += 1
    return "".join(out)


def scan():
    files = {}
    for base, _, names in os.walk(ADDON):
        for f in sorted(names):
            if f.endswith(".lua"):
                p = os.path.join(base, f)
                r = os.path.relpath(p, ADDON).replace("\\", "/")
                with open(p, encoding="utf-8", errors="replace") as fh:
                    files[r] = strip(fh.read())
    owner = {}
    for r, s in files.items():
        for m in re.finditer(r"(?m)^\s*ns\.([A-Z]\w*)\s*=", s):
            owner.setdefault(m.group(1), r)
    edges, private, fires, listens = {}, set(), {}, {}
    for r, s in files.items():
        for m in re.finditer(r"\bns\.([A-Z]\w*)(?:\.([a-z]\w*))?", s):
            name, field = m.group(1), m.group(2)
            o = owner.get(name)
            if not o or o == r or name in CORE_SHARED:
                continue
            edges.setdefault(r, set()).add(o)
            if field and field != "enabled" and not re.match(r"\s*\(", s[m.end():m.end() + 2]):
                private.add("%s -> ns.%s.%s" % (r, name, field))
        for m in re.finditer(r"Fire\(\s*\"(OTR_\w+)\"", s):
            fires.setdefault(m.group(1), set()).add(r)
        for m in re.finditer(r"On\(\s*\"(OTR_\w+)\"", s):
            listens.setdefault(m.group(1), set()).add(r)
    return files, owner, edges, private, fires, listens


def duplicates(files):
    """Identical one-line local helpers defined in 3+ files (candidates for a shared helper)."""
    seen = {}
    for r, s in files.items():
        for m in re.finditer(r"(?m)^local function (\w+)\(([^)]*)\)(.*\bend)\s*$", s):
            key = re.sub(r"\s+", " ", "(%s)%s" % (m.group(2), m.group(3))).strip()
            seen.setdefault(key, set()).add("%s:%s" % (r, m.group(1)))
    return sorted(((k, sorted(v)) for k, v in seen.items() if len(v) >= 3), key=lambda x: -len(x[1]))


def sccs(nodes, edges):
    index, low, stack, on, out, k = {}, {}, [], set(), [], [0]
    sys.setrecursionlimit(10000)

    def visit(v):
        index[v] = low[v] = k[0]
        k[0] += 1
        stack.append(v)
        on.add(v)
        for w in sorted(edges.get(v, ())):
            if w not in index:
                visit(w)
                low[v] = min(low[v], low[w])
            elif w in on:
                low[v] = min(low[v], index[w])
        if low[v] == index[v]:
            comp = []
            while True:
                w = stack.pop()
                on.discard(w)
                comp.append(w)
                if w == v:
                    break
            if len(comp) > 1:
                out.append(sorted(comp))
    for v in sorted(nodes):
        if v not in index:
            visit(v)
    return out


def main(argv):
    files, owner, edges, private, fires, listens = scan()
    cyc = sccs(files.keys(), edges)
    cyc_ids = sorted("cycle:" + "|".join(c) for c in cyc)
    pairs = sorted("pair:%s<->%s" % (a, b) for a in edges for b in edges[a] if a < b and a in edges.get(b, ()))
    found = sorted(set(pairs) | {"private:" + p for p in private})
    if "--update" in argv:
        with open(BASE, "w", encoding="utf-8") as fh:
            json.dump({"note": "OI01-12 baseline: existing mutual references and private field reads.", "accepted": found}, fh, indent=1)
            fh.write("\n")
        print("deps baseline: %d entries" % len(found))
        return 0
    base = set()
    if os.path.exists(BASE):
        with open(BASE, encoding="utf-8") as fh:
            base = set(json.load(fh).get("accepted", []))
    new = [f for f in found if f not in base]
    if "--check" not in argv:
        lines = ["# Module dependency and coupling report", "",
                 "Generated by `python -I tools/deps.py` (OI01-12). Files: %d. Namespace owners: %d. Dependency edges: %d." %
                 (len(files), len(owner), sum(len(v) for v in edges.values())), "",
                 "## Mutual references (file pairs that use each other): %d" % len(pairs), ""]
        lines += ["- " + p[5:] for p in pairs]
        lines += ["", "## Strongly connected groups: %d" % len(cyc), ""]
        lines += ["- %d files: %s" % (len(c), ", ".join(c)) for c in sorted(cyc, key=len, reverse=True)]
        lines += ["", "## Reads of another module's lowercase (state) fields: %d" % len(private), ""]
        lines += ["- " + p for p in sorted(private)]
        dups = duplicates(files)
        lines += ["", "## Same one-line helper in 3+ files: %d" % len(dups), ""]
        lines += ["- `%s` in %d files: %s" % (k[:80], len(v), ", ".join(v)) for k, v in dups]
        lines += ["", "## Internal OTR_ events", "", "| Event | Fired by | Listened in |", "|---|---|---|"]
        for ev in sorted(set(fires) | set(listens)):
            lines.append("| %s | %s | %s |" % (ev, ", ".join(sorted(fires.get(ev, []))) or "**nobody**",
                                              ", ".join(sorted(listens.get(ev, []))) or "**nobody**"))
        with open(OUT, "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines) + "\n")
    for f in new:
        print("NEW " + f)
    print("deps: %d mutual pairs, %d cycles, %d private reads, %d new" % (len(pairs), len(cyc), len(private), len(new)))
    return 1 if ("--check" in argv and new) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

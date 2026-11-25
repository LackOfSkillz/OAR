"""tools/preservation_check.py (OI-FR01)

A larger count does not prove nothing was lost. This gate compares the data
files against a base commit (docs/quality/preservation_base.txt) and fails when
anything present at the base is missing now:

* walked paths (addon/Outrider_Data_Trails/Data.lua): every point of every map
  at the base must still be in the current file;
* every other data file (addon/Outrider/Data/*.lua, addon/Outrider_Data_*/*.lua):
  CONTENT, not just ids (review OI-FR14). Both versions are run in a sandbox
  (tools/preservation_flatten.lua, through lupa) and every value at the base
  (each field of each record, sources included, duplicates counted) must
  still be there with the same value. A deliberate correction is allowed
  only when docs/quality/preservation_revisions.json records it with the old
  value, so the original stays recoverable. A file the sandbox can't run is
  reported as UNVERIFIED and falls back to the record-id check; parts it
  can't read (functions) are counted and reported, never silently passed.

--require-content is strict and fails closed (review OI-FR17): a missing
lupa, a file either version of which can't run in the sandbox, or any part
of the base or the candidate that couldn't be compared makes the gate fail.
The record-id fallback is never accepted as content verification there.

A data file that was removed on purpose must be moved, not deleted: list its new
path in docs/quality/preservation_moves.json ({"old": "new"}).

    python tools/preservation_check.py [--base SHA] [--require-content]
Exit 0 when nothing is missing, 1 when something is (or, with
--require-content, when anything couldn't be verified), 2 when the base
can't be read.
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRAILS = "addon/Outrider_Data_Trails/Data.lua"
ID_RE = re.compile(r"\[(\d+)\]\s*=|\b(?:id|npcId|npcID|itemId|itemID|questId|questID|spellId|spellID|mapID|mapId)\s*=\s*(\d+)")
MAP_RE = re.compile(r"\[(\d+)\]=\{([^}]*)\}")


def git(*args):
    r = subprocess.run(["git", *args], cwd=ROOT, capture_output=True)
    if r.returncode != 0:
        return None
    return r.stdout.decode("utf-8", "replace")


def trail_points(text):
    out = {}
    for k, v in MAP_RE.findall(text or ""):
        nums = [x.strip() for x in v.split(",") if x.strip()]
        out[int(k)] = {(nums[i], nums[i + 1]) for i in range(0, len(nums) - 1, 2)}
    return out


def ids(text):
    found = set()
    for a, b in ID_RE.findall(text or ""):
        found.add(a or b)
    return found


_FLATTEN = None


def flattener():
    """the Lua flattener, or None when lupa isn't installed"""
    global _FLATTEN
    if _FLATTEN is None:
        try:
            from lupa import lua51
        except ImportError:
            _FLATTEN = False
            return None
        lua = lua51.LuaRuntime(unpack_returned_tuples=True)
        with open(os.path.join(ROOT, "tools", "preservation_flatten.lua"), encoding="utf-8") as f:
            lua.execute(f.read())
        fn = lua.globals().Flatten

        def run(text, name):
            res = fn(text, name)
            lines, extra = (res if isinstance(res, tuple) else (res, None))
            if lines is None:
                return None, str(extra)
            return set(lines.values()), sorted(extra.values()) if extra is not None else []
        _FLATTEN = run
    return _FLATTEN or None


def load_revisions():
    path = os.path.join(ROOT, "docs", "quality", "preservation_revisions.json")
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as f:
        rows = json.load(f).get("revisions", [])
    allowed = {}
    for r in rows:
        allowed.setdefault(r["file"], set()).add(r["path"] + chr(9) + r["old"])
    return allowed


def data_files(listing):
    for path in listing:
        if not path.endswith(".lua"):
            continue
        if path.startswith("addon/Outrider/Data/") or re.match(r"addon/Outrider_Data_[^/]+/", path):
            yield path


def compare_file(path, old, cur, cur_path, flat, revisions, problems, unverified):
    """compare one data file's base text with its current text; appends to
    problems (data lost) and unverified (what couldn't be compared)"""
    if path == TRAILS:
        a, b = trail_points(old), trail_points(cur)
        for m, pts in sorted(a.items()):
            miss = pts - b.get(m, set())
            if miss:
                problems.append(f"{path}: map {m} lost {len(miss)} of {len(pts)} points")
    else:
        content = None
        if flat:
            a, why_a = flat(old, path)
            b, why_b = flat(cur, cur_path)
            if a is None or b is None:
                unverified.append(f"{path}: can't run in the sandbox ({why_a if a is None else why_b}); record ids only")
            else:
                content = True
                lost = sorted(line for line in a - b if line not in revisions.get(path, set()))
                if lost:
                    sample = "; ".join(x.replace(chr(9), " = ")[:120] for x in lost[:5])
                    problems.append(f"{path}: {len(lost)} value(s) changed or missing ({sample})")
                if why_a:
                    unverified.append(f"{path}: {len(why_a)} base part(s) not comparable: {', '.join(why_a[:3])}")
                if why_b:
                    unverified.append(f"{path}: {len(why_b)} current part(s) not comparable: {', '.join(why_b[:3])}")
        if not content:
            miss = ids(old) - ids(cur)
            if miss:
                sample = ", ".join(sorted(miss, key=int)[:8])
                problems.append(f"{path}: {len(miss)} record ids missing ({sample})")


def main(argv):
    base = None
    if "--base" in argv:
        base = argv[argv.index("--base") + 1]
    if not base:
        with open(os.path.join(ROOT, "docs", "quality", "preservation_base.txt"), encoding="utf-8") as f:
            base = f.read().strip().split()[0]
    moves = {}
    mp = os.path.join(ROOT, "docs", "quality", "preservation_moves.json")
    if os.path.exists(mp):
        with open(mp, encoding="utf-8") as f:
            moves = json.load(f)
    listing = git("ls-tree", "-r", "--name-only", base)
    if listing is None:
        print(f"preservation: cannot read base commit {base} (a shallow checkout needs fetch-depth: 0)")
        return 2
    problems = []
    checked = 0
    unverified = []
    flat = flattener()
    revisions = load_revisions()
    if not flat:
        if "--require-content" in argv:
            print("preservation: lupa is not installed, so content can't be compared (--require-content)")
            return 1
        unverified.append("lupa not installed: content not compared, record ids only")
    for path in data_files(listing.splitlines()):
        old = git("show", f"{base}:{path}")
        cur_path = moves.get(path, path)
        full = os.path.join(ROOT, cur_path)
        if not os.path.exists(full):
            problems.append(f"{path}: file is gone (move it and list it in preservation_moves.json)")
            continue
        with open(full, encoding="utf-8", errors="replace") as f:
            cur = f.read()
        checked += 1
        compare_file(path, old, cur, cur_path, flat, revisions, problems, unverified)
    for u in unverified:
        print("  UNVERIFIED " + u)
    strict = "--require-content" in argv
    if strict and unverified:
        problems.append(f"{len(unverified)} file(s) or part(s) unverified; --require-content accepts only content-level checks")
    if problems:
        print(f"preservation: {len(problems)} problem(s) against {base[:7]}")
        for p in problems:
            print("  " + p)
        return 1
    print(f"preservation: {checked} data files keep everything from {base[:7]}"
          f" ({len(unverified)} unverified note(s) above)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

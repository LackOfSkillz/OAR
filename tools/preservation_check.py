"""tools/preservation_check.py (OI-FR01)

A larger count does not prove nothing was lost. This gate compares the data
files against a base commit (docs/quality/preservation_base.txt) and fails when
anything present at the base is missing now:

* walked paths (addon/Outrider_Data_Trails/Data.lua): every point of every map
  at the base must still be in the current file;
* every other data file (addon/Outrider/Data/*.lua, addon/Outrider_Data_*/*.lua):
  every record id at the base (``[123]=`` keys and ``id = 123`` style fields)
  must still appear in the current file.

A data file that was removed on purpose must be moved, not deleted: list its new
path in docs/quality/preservation_moves.json ({"old": "new"}).

    py -I tools/preservation_check.py [--base SHA]
Exit 0 when nothing is missing, 1 when something is, 2 when the base can't be read.
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


def data_files(listing):
    for path in listing:
        if not path.endswith(".lua"):
            continue
        if path.startswith("addon/Outrider/Data/") or re.match(r"addon/Outrider_Data_[^/]+/", path):
            yield path


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
        if path == TRAILS:
            a, b = trail_points(old), trail_points(cur)
            for m, pts in sorted(a.items()):
                miss = pts - b.get(m, set())
                if miss:
                    problems.append(f"{path}: map {m} lost {len(miss)} of {len(pts)} points")
        else:
            miss = ids(old) - ids(cur)
            if miss:
                sample = ", ".join(sorted(miss, key=int)[:8])
                problems.append(f"{path}: {len(miss)} record ids missing ({sample})")
    if problems:
        print(f"preservation: {len(problems)} problem(s) against {base[:7]}")
        for p in problems:
            print("  " + p)
        return 1
    print(f"preservation: {checked} data files keep everything from {base[:7]}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

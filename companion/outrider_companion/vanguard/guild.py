"""VG07-06: guild preparation report, aggregate only, manual export.

  * Only runs whose export said guild = true are used (each player opted in
    when exporting). Synthetic records are left out.
  * Aggregate per place: runs, full clears, incomplete, abandoned, unknown, and
    a full-clear interval once 5 runs have a known outcome.
  * Shared objectives come from a small JSON file the officer writes:
      {"objectives": [{"instance": "Scholomance", "goal": "full_clear", "count": 3}]}
    goal is full_clear or boss_kill (with "boss"); progress is a group total.
  * No per-player breakdown and no rankings: only how many players contributed.
  * Written to a file on your PC when you ask. Nothing is uploaded or posted.
"""
import json
from pathlib import Path

from . import contract
from .scenario import wilson, MIN_RUNS

GOALS = ("full_clear", "boss_kill")


class GuildError(ValueError):
    pass


def read_objectives(path):
    p = Path(path)
    if not p.is_file() or p.stat().st_size > 64 * 1024:
        raise GuildError("objectives file is missing or too large")
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
    except ValueError as exc:
        raise GuildError("objectives file is not JSON") from exc
    if not isinstance(data, dict) or set(data) - {"objectives"} or not isinstance(data.get("objectives"), list):
        raise GuildError('objectives file must be {"objectives": [...]}')
    out = []
    for o in data["objectives"][:50]:
        if not isinstance(o, dict) or set(o) - {"instance", "goal", "count", "boss"}:
            raise GuildError("an objective has unknown fields")
        if not isinstance(o.get("instance"), str) or o.get("goal") not in GOALS:
            raise GuildError("an objective needs instance and goal (full_clear or boss_kill)")
        n = o.get("count", 1)
        if isinstance(n, bool) or not isinstance(n, int) or not 1 <= n <= 1000:
            raise GuildError("count must be 1 to 1000")
        if o["goal"] == "boss_kill" and not isinstance(o.get("boss"), str):
            raise GuildError("a boss_kill objective names the boss")
        out.append({"instance": o["instance"][:60], "goal": o["goal"], "count": n, "boss": o.get("boss")})
    return out


def report(runs, objectives=()):
    runs = [r for r in runs if not r.get("_synthetic")]
    places = {}
    for r in runs:
        p = places.setdefault(r["instance"], {"runs": 0, "completed": 0, "incomplete": 0, "abandoned": 0, "unknown": 0})
        p["runs"] += 1
        p[r["outcome"]] += 1
    for p in places.values():
        known = p["completed"] + p["incomplete"] + p["abandoned"]
        p["fullClear"] = wilson(p["completed"], known) if known >= MIN_RUNS else None
    progress = []
    for o in objectives:
        if o["goal"] == "full_clear":
            done = sum(1 for r in runs if r["instance"] == o["instance"] and r["outcome"] == "completed")
        else:
            want = o["boss"].lower()
            done = sum(1 for r in runs if r["instance"] == o["instance"] and any(
                a.get("result") == "kill" and (a.get("name") or "").lower() == want for a in r.get("attempts") or []))
        progress.append(dict(o, done=min(done, o["count"]), met=done >= o["count"]))
    return {"contributors": len({r.get("_exporter") for r in runs}), "runs": len(runs), "places": places,
            "objectives": progress,
            "note": "Group totals from runs players chose to share; no per-player results, no rankings."}


def markdown(rep):
    lines = ["# Guild preparation report", "",
             "%d runs from %d players who chose to share. %s" % (rep["runs"], rep["contributors"], rep["note"]), ""]
    if rep["objectives"]:
        lines += ["## Objectives", ""]
        for o in rep["objectives"]:
            what = "full clears" if o["goal"] == "full_clear" else "%s kills" % o["boss"]
            lines.append("- %s: %s %d of %d%s" % (o["instance"], what, o["done"], o["count"], " (met)" if o["met"] else ""))
        lines.append("")
    lines += ["## Places", "", "| Place | Runs | Full clears | Incomplete | Abandoned | Unknown | Full-clear range |",
              "|---|---|---|---|---|---|---|"]
    for name in sorted(rep["places"]):
        p = rep["places"][name]
        rng = ("%.0f%% to %.0f%%" % (p["fullClear"]["low"] * 100, p["fullClear"]["high"] * 100)) if p["fullClear"] \
            else "fewer than %d known" % MIN_RUNS
        lines.append("| %s | %d | %d | %d | %d | %d | %s |" % (name, p["runs"], p["completed"], p["incomplete"],
                                                             p["abandoned"], p["unknown"], rng))
    return "\n".join(lines) + "\n"


def write(rep, out):
    if contract._inside_game(out):
        raise GuildError("refusing to write inside the game folder")
    text = markdown(rep) if str(out).lower().endswith(".md") else json.dumps(rep, indent=2, sort_keys=True)
    Path(out).write_text(text, encoding="utf-8")
    return out

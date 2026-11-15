"""Deterministic plan evaluator (spec AI03-01/02).

The model suggests which steps; this code decides what fits and in which
order, using only Outrider's data. Times are estimates (labelled "inferred"):
the trip Outrider worked out plus a typical time for that kind of step.

Order rules: urgent steps first (gear about to break, out of ammo), group
content (dungeons) last, steps in the same zone kept together, otherwise the
suggested order. Steps that don't fit the time budget move to "later".
"""

import re

# typical minutes to do a step once there (an estimate, shown as one)
ACTIVITY = {"errand": 3, "quest": 10, "gear": 5, "dungeon": 50, "profession": 6, "rare": 10, "gold": 30, "gather": 3}
MIN_BUDGET, MAX_BUDGET = 5, 600


def budget_from(question, snapshot_budget=None):
    """Minutes from the snapshot's time box, else from the question ("45 minutes", "an hour", "2h")."""
    if isinstance(snapshot_budget, (int, float)) and not isinstance(snapshot_budget, bool):
        return int(max(MIN_BUDGET, min(MAX_BUDGET, snapshot_budget)))
    q = (question or "").lower()
    m = re.search(r"(\d+(?:\.\d+)?)\s*(h|hr|hrs|hour|hours)\b", q)
    if m:
        return int(max(MIN_BUDGET, min(MAX_BUDGET, float(m.group(1)) * 60)))
    m = re.search(r"(\d+)\s*(m|min|mins|minute|minutes)\b", q)
    if m:
        return int(max(MIN_BUDGET, min(MAX_BUDGET, int(m.group(1)))))
    if re.search(r"\b(an|one) hour\b", q):
        return 60
    if re.search(r"\bhalf an hour\b", q):
        return 30
    return None


def _zone(c):
    t = c.get("target")
    return t["mapID"] if t else None


def order(picked):
    """Urgent first, dungeons last, same zone kept together (stable otherwise)."""
    urgent = [c for c in picked if c.get("urgent")]
    group = [c for c in picked if not c.get("urgent") and c["kind"] == "dungeon"]
    rest = [c for c in picked if not c.get("urgent") and c["kind"] != "dungeon"]
    grouped, seen = [], set()
    for c in rest:
        if id(c) in seen:
            continue
        z = _zone(c)
        same = [d for d in rest if id(d) not in seen and z is not None and _zone(d) == z] or [c]
        for d in same:
            seen.add(id(d))
            grouped.append(d)
    return urgent + grouped + group


def plan(picked, budget=None):
    """{steps, later, total, budget, unknownTime} from candidates in suggested order."""
    steps, later, total, unknown = [], [], 0, []
    for c in order(picked):
        trip = c.get("minutes")
        do = ACTIVITY.get(c["kind"], 10)
        mins = (trip if isinstance(trip, (int, float)) else 0) + do
        if trip is None:
            unknown.append(c["candidateId"])
        if budget is not None and total + mins > budget and not c.get("urgent"):
            later.append({"candidateId": c["candidateId"], "minutes": int(mins)})
            continue
        steps.append({"stepId": "step-%d" % (len(steps) + 1), "candidateId": c["candidateId"],
                      "minutes": int(mins), "startsAt": int(total), "estimate": "inferred"})
        total += mins
    return {"steps": steps, "later": later, "total": int(total), "budget": budget, "unknownTime": unknown}


def limits_for(p, titles):
    out = ["Times are estimates: the trip plus a typical time for that kind of step."]
    if p["later"]:
        names = ", ".join(titles.get(x["candidateId"], x["candidateId"]) for x in p["later"][:2])
        out.append("Won't fit in %d minutes: %s." % (p["budget"], names))
    if p["unknownTime"]:
        out.append("Trip time unknown for %d step%s." % (len(p["unknownTime"]), "" if len(p["unknownTime"]) == 1 else "s"))
    return out

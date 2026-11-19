"""Deterministic XP60 planner; no arbitrary model-authored actions or numbers."""
import math

SECONDS = 3600
BUFFER = 240
MAX_STEPS = 12
MAX_CANDIDATES = 20
BEAM = 120


class PlanningError(ValueError):
    pass


def _num(x):
    return isinstance(x, (float, int)) and not isinstance(x, bool) and math.isfinite(x)


def _bounded(x, maximum=1e9):
    return _num(x) and 0 <= x <= maximum


def normalize(source):
    """Require source-backed, feasible XP/time; unmeasured ideas remain qualitative."""
    if not isinstance(source, dict):
        return None
    cid = source.get("candidateId")
    if not isinstance(cid, str) or not 1 <= len(cid) <= 100:
        return None
    if source.get("eligible") is not True or source.get("completed") is True:
        return None
    if source.get("requiresGroup") and source.get("groupAvailable") is not True:
        return None
    if source.get("travelKnown") is False:
        return None
    if source.get("origin") not in ("observed", "verified", "community"):
        return None
    timecost = source.get("timeSeconds")
    xp = source.get("xpReward")
    if not isinstance(timecost, dict) or not isinstance(xp, dict):
        return None
    for k in ("travel", "activity", "turnIn", "wait"):
        if not _bounded(timecost.get(k), SECONDS):
            return None
    if xp.get("origin") not in ("observed", "verified"):
        return None
    if not _bounded(xp.get("value"), 1e7):
        return None
    total = sum(timecost[k] for k in ("travel", "activity", "turnIn", "wait"))
    if total <= 0 or total > SECONDS:
        return None
    # All numeric inputs must be sourced; never invent a percentage improvement.
    evidence = source.get("evidenceIds")
    if not isinstance(evidence, list) or not 1 <= len(evidence) <= 8 or any(
            not isinstance(e, str) or not e or len(e) > 100 for e in evidence):
        return None
    requires = source.get("requires", [])
    if not isinstance(requires, list) or len(requires) > 8 or any(
            not isinstance(q, str) for q in requires):
        return None
    return {"candidateId": cid, "title": str(source.get("title") or cid)[:120],
            "seconds": int(math.ceil(total)), "xp": int(xp["value"]),
            "evidenceIds": evidence, "requires": requires, "kind": source.get("kind", "quest"),
            "mapID": source.get("mapID"), "source": source.get("origin"),
            "riskSeconds": int(min(600, source.get("riskSeconds", 0)))
               if _bounded(source.get("riskSeconds", 0), 600) else 600}


def _score(state):
    return (state["xp"], -state["seconds"], tuple(state["ids"]))


def optimize(candidates, *, baseline=None, budget=SECONDS):
    if budget != SECONDS:
        raise PlanningError("XP60 is fixed at a 3600-second horizon")
    eligible, unknown = [], []
    for source in (candidates or [])[:MAX_CANDIDATES]:
        normalized = normalize(source)
        if normalized is None:
            if isinstance(source, dict):
                unknown.append(str(source.get("candidateId", "unknown"))[:100])
        else:
            eligible.append(normalized)
    eligible.sort(key=lambda x: x["candidateId"])
    beam = [{"ids": [], "seconds": 0, "xp": 0, "steps": [], "done": set()}]
    best = beam[0]
    for _ in range(min(MAX_STEPS, len(eligible))):
        expanded = []
        for state in beam:
            expanded.append(state)
            for c in eligible:
                if c["candidateId"] in state["done"] or any(dep not in state["done"] for dep in c["requires"]):
                    continue
                # This assumes each candidate's travel cost is independently
                # grounded in the stated itinerary. Do not combine duplicate
                # objectives as independent XP rewards.
                end = state["seconds"] + c["seconds"]
                if end + BUFFER + c["riskSeconds"] > budget:
                    continue
                ids = state["ids"] + [c["candidateId"]]
                step = {"candidateId": c["candidateId"], "startsAt": state["seconds"],
                        "endsAt": end, "xp": c["xp"], "evidenceIds": c["evidenceIds"],
                        "title": c["title"]}
                expanded.append({"ids": ids, "seconds": end,
                                 "xp": state["xp"] + c["xp"],
                                 "steps": state["steps"] + [step],
                                 "done": state["done"] | {c["candidateId"]}})
        if not expanded:
            break
        unique = {}
        for s in expanded:
            key = tuple(s["ids"])
            if key not in unique or _score(s) > _score(unique[key]):
                unique[key] = s
        beam = sorted(unique.values(), key=lambda s: (-s["xp"], s["seconds"], s["ids"]))[:BEAM]
        if _score(beam[0]) > _score(best):
            best = beam[0]
    measured = baseline if isinstance(baseline, dict) else {}
    previous = measured.get("xpPerHour") if measured.get("observed") else None
    # A finite historical XP/hour isn't a controlled experiment. An uplift
    # requires a comparable route and sufficiently narrow uncertainty.
    improvement = None
    if _bounded(previous) and previous > 0 and best["xp"] > previous * 1.1:
        improvement = None  # explicitly withheld until ranges/comparability exist
    return {
        "schema": 1, "goal": "xp", "budgetSeconds": SECONDS,
        "estimatedEarnedXP": best["xp"] if best["steps"] else None,
        "xpRange": {"low": None, "typical": best["xp"] if best["steps"] else None,
                    "high": None},
        "estimatedImprovementPercent": improvement,
        "steps": best["steps"], "baseline": measured,
        "status": "evidence_backed" if best["steps"] else "insufficient_evidence",
        "message": ("Proposed XP route from verified rewards and time evidence."
                    if best["steps"] else
                    "No defensible XP/hour improvement established; continue your current route."),
        "unknownCandidateIds": unknown[:20],
        "alternatives": [],
        "remainingSeconds": SECONDS - best["seconds"],
        "bufferSeconds": BUFFER,
        "actions": [],
    }

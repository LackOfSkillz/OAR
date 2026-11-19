"""Conservative XP/hour calculations from completed, comparable sessions."""
import math


def _number(v):
    return isinstance(v, (float, int)) and not isinstance(v, bool) and math.isfinite(v)


def valid_session(s):
    if not isinstance(s, dict) or s.get("final") is not True or s.get("xpVerified") is not True:
        return False
    flags = s.get("flags") or {}
    if not isinstance(flags, dict) or any(flags.get(k) for k in (
        "incomplete", "xpUnknown", "xpReset", "rolloverUnknown", "clockUnknown"
    )):
        return False
    return (_number(s.get("durationSeconds")) and 60 <= s["durationSeconds"] <= 86400
            and _number(s.get("xpEarned")) and 0 <= s["xpEarned"] <= 1e9
            and _number(s.get("levelStart")) and 1 <= s["levelStart"] <= 200)


def baseline(sessions, *, target_level=None, game_build=None):
    """Rate uses *wall clock* hours, not only time spent earning XP.

    Unknown rested, boost or grouping state is reported, not assumed equal.
    """
    eligible = []
    for s in sessions[-20:]:
        if not valid_session(s):
            continue
        if target_level is not None and abs(s["levelStart"] - target_level) > 3:
            continue
        if game_build and s.get("build") != game_build:
            continue
        eligible.append(s)
    seconds = sum(s["durationSeconds"] for s in eligible)
    xp = sum(s["xpEarned"] for s in eligible)
    if not seconds:
        return {"observed": False, "xpPerHour": None, "sampleCount": 0,
                "basis": "wall", "uncertainty": "insufficient comparable sessions"}
    rates = sorted(s["xpEarned"] * 3600 / s["durationSeconds"] for s in eligible)
    return {"observed": True, "xpPerHour": round(xp * 3600 / seconds),
            "sampleCount": len(eligible), "durationSeconds": round(seconds),
            "basis": "wall", "lowObservedRate": round(rates[0]),
            "highObservedRate": round(rates[-1]),
            "uncertainty": "observed variation; rested, grouping and bonuses may differ"}

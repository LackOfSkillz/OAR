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


def merge_segments(sessions):
    """Join /reload segments into play sessions (OI03-01, addon PlaySession.Merge).

    Records sharing a playSessionId are one play session: duration and XP are
    summed, levelStart comes from the first segment, levelEnd/final/endedAt
    from the last, xpVerified only if every segment was, flags are the union.
    Records without a playSessionId (older data) stay as they are. The input
    records are not changed.
    """
    out, by_id = [], {}
    for r in sessions or []:
        if not isinstance(r, dict):
            continue
        sid = r.get("playSessionId")
        cur = by_id.get(sid) if sid else None
        if cur is None:
            cur = dict(r)
            cur["flags"] = dict(r.get("flags") or {}) if isinstance(r.get("flags"), dict) else r.get("flags")
            cur["segments"] = 1
            out.append(cur)
            if sid:
                by_id[sid] = cur
            continue
        cur["segments"] += 1
        for f in ("durationSeconds", "xpEarned"):
            if _number(r.get(f)) and _number(cur.get(f)):
                cur[f] = cur[f] + r[f]
        for f in ("levelEnd", "endedAt", "final", "endReason"):
            if f in r:
                cur[f] = r[f]
        if r.get("xpVerified") is not True:
            cur["xpVerified"] = False
        if isinstance(r.get("flags"), dict) and isinstance(cur.get("flags"), dict):
            for k, v in r["flags"].items():
                if v:
                    cur["flags"][k] = v
    return out


def baseline(sessions, *, target_level=None, game_build=None):
    """Rate uses *wall clock* hours, not only time spent earning XP.

    Unknown rested, boost or grouping state is reported, not assumed equal.
    """
    eligible = []
    for s in merge_segments(sessions)[-20:]:
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

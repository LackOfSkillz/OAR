"""Prepare XP60 plan data for a later, closed-game launch.

Never edit SavedVariables; never run a command in the game. File installation
fails closed if running-game detection cannot be completed.
"""
import os
import ctypes
from ctypes import wintypes
import sys
import time
from pathlib import Path

from .. import advice
from . import session_reader, xp_baseline, xp60_planner

GAME_NAMES = {"wow.exe", "wow-64.exe", "wowclassic.exe", "wowclassicera.exe",
              "wowforever.exe", "warcraft forever.exe", "forever.exe"}


class DeliveryError(ValueError):
    pass


class _PROCESSENTRY32W(ctypes.Structure):
    _fields_ = [
        ("dwSize", wintypes.DWORD), ("cntUsage", wintypes.DWORD),
        ("th32ProcessID", wintypes.DWORD), ("th32DefaultHeapID", ctypes.c_void_p),
        ("th32ModuleID", wintypes.DWORD), ("cntThreads", wintypes.DWORD),
        ("th32ParentProcessID", wintypes.DWORD), ("pcPriClassBase", wintypes.LONG),
        ("dwFlags", wintypes.DWORD), ("szExeFile", wintypes.WCHAR * 260),
    ]


def game_closed():
    """Read-only Windows process enumeration, without shell execution.

    Fail closed if the platform or process enumeration is unavailable.
    Uses documented Toolhelp32Snapshot to inspect process names ONLY;
    no process is opened, injected into, read from, or controlled.
    """
    if sys.platform != "win32":
        raise DeliveryError("automatic installation requires Windows process verification")
    kernel = ctypes.windll.kernel32
    create = kernel.CreateToolhelp32Snapshot
    create.argtypes = [wintypes.DWORD, wintypes.DWORD]
    create.restype = ctypes.c_void_p
    first = kernel.Process32FirstW
    first.argtypes = [ctypes.c_void_p, ctypes.POINTER(_PROCESSENTRY32W)]
    first.restype = wintypes.BOOL
    advance = kernel.Process32NextW
    advance.argtypes = first.argtypes
    advance.restype = wintypes.BOOL
    close = kernel.CloseHandle
    close.argtypes = [ctypes.c_void_p]
    close.restype = wintypes.BOOL
    handle = create(0x00000002, 0)
    if not handle or handle == ctypes.c_void_p(-1).value:
        raise DeliveryError("cannot enumerate running processes")
    try:
        entry = _PROCESSENTRY32W()
        entry.dwSize = ctypes.sizeof(entry)
        if not first(handle, ctypes.byref(entry)):
            raise DeliveryError("process enumeration failed")
        while True:
            name = entry.szExeFile.strip().lower()
            if name in GAME_NAMES or "warcraft" in name or "wow" in name:
                return False
            if not advance(handle, ctypes.byref(entry)):
                # Error 18 is normal end of enumeration; others are unsafe.
                if kernel.GetLastError() != 18:
                    raise DeliveryError("process enumeration ended abnormally")
                break
        return True
    finally:
        close(handle)


def create_plan(read_result, character, *, now=None):
    now = int(time.time() if now is None else now)
    selected = session_reader.newest_completed(read_result, character=character)
    if not selected or selected[0] != character:
        raise DeliveryError("no finished XP session for this character")
    _, last = selected
    history = [s for key, s in read_result["sessions"] if key == character]
    b = xp_baseline.baseline(history, target_level=last.get("levelEnd"),
                             game_build=last.get("build"))
    snapshot = read_result.get("snapshots")
    snapshot = snapshot.get(character) if isinstance(snapshot, dict) else None
    # This is deliberately conservative: existing WhatNow candidate 'benefit'
    # and Journey's community XP estimates are not verified player earnings.
    # A source can become quantitative only after we have real, separately
    # provenance-checked reward + duration inputs.
    whatnow = ((snapshot.get("modules") or {}).get("WhatNow") or {}) if isinstance(snapshot, dict) else {}
    raw = whatnow.get("candidates")
    # An old Ask snapshot may survive multiple logouts. It cannot establish
    # a fresh next-session quest opportunity without its observation time.
    seen_at = whatnow.get("seenAt")
    latest_end = last.get("endedAt")
    if (not isinstance(seen_at, int) or not isinstance(latest_end, int)
            or seen_at > latest_end + 300 or latest_end - seen_at > 900):
        raw = []

    # Previously turned-in, non-repeatability-unknown IDs are excluded from
    # certain next-session picks; never award the same one-time XP twice.
    turned_in = {
        q.get("questID")
        for entry in history
        for q in (entry.get("questsTurnedIn") or [])
        if isinstance(q, dict) and isinstance(q.get("questID"), int)
    }
    suppressed = (read_result.get("preferences") or {}).get(character, {})
    suppressed = suppressed if isinstance(suppressed, dict) else {}
    def recently_suppressed(candidate_id):
        row = suppressed.get(candidate_id)
        if not isinstance(row, dict):
            return False
        at = row.get("at")
        if not isinstance(at, int) or at > now + 300:
            return False
        verdict = row.get("verdict")
        max_age = 30 * 86400 if verdict == "not_interested" else 14 * 86400
        if verdict == "wrong":
            max_age = 7 * 86400
        if now - at > max_age:
            return False
        level = row.get("level")
        if verdict == "already_know" and isinstance(level, int) and isinstance(last.get("levelEnd"), int):
            if abs(last["levelEnd"] - level) >= 3:
                return False
        return verdict in ("already_know", "not_interested", "wrong")
    opportunities = []
    for c in raw if isinstance(raw, list) else []:
        if (not isinstance(c, dict) or not isinstance(c.get("candidateId"), str)
                or recently_suppressed(c["candidateId"])):
            continue
        community = (
            c.get("questID") not in turned_in
            and c.get("kind") == "quest" and c.get("label") == "community"
            and c.get("estimateBasis") == "journey_community"
            and isinstance(c.get("estimatedQuestXP"), (int, float))
            and isinstance(c.get("estimatedTripSeconds"), (int, float))
            and isinstance(c.get("estimatedActivitySeconds"), (int, float))
            and isinstance(c.get("target"), dict)
        )
        if community:
            # Costs are source-provided heuristics, with a conservative
            # estimated turn-in allowance and uncertainty reserve. They are
            # never reported as verified XP or a proven better route.
            opportunities.append({
                "candidateId": c["candidateId"], "title": c.get("title"),
                "questID": c.get("questID"),
                "kind": "quest", "eligible": True, "completed": False,
                "origin": "community", "estimateBasis": "journey_community",
                "travelKnown": True, "mapID": c["target"].get("mapID"),
                "evidenceIds": ["whatnow:" + c["candidateId"]],
                "timeSeconds": {"travel": c["estimatedTripSeconds"],
                                "activity": c["estimatedActivitySeconds"],
                                "turnIn": 180, "wait": 0},
                "riskSeconds": 360,
                "xpReward": {"value": c["estimatedQuestXP"], "origin": "community"},
            })
        else:
            opportunities.append({"candidateId": c["candidateId"],
                                  "eligible": False, "origin": c.get("label") or "unknown"})
    computed = xp60_planner.optimize(opportunities, baseline=b)
    # Unknown XP/time is not a reason to hide valid, player-eligible next
    # steps. Show source-bound candidate IDs qualitatively, with no fake rate.
    qualitative = []
    for c in raw if isinstance(raw, list) else []:
        if (not isinstance(c, dict) or c.get("kind") != "quest"
                or c.get("questID") in turned_in
                or recently_suppressed(c.get("candidateId"))):

            continue
        cid = c.get("candidateId")
        if (isinstance(cid, str) and 1 <= len(cid) <= 100
                and cid not in {step["candidateId"] for step in computed["steps"]}
                and cid not in qualitative and c.get("label") in
                ("observed", "verified", "community")):
            qualitative.append(cid)
        if len(qualitative) >= 3:
            break
    if len(str(last.get("sessionId", ""))) > 80:
        raise DeliveryError("invalid session identifier")
    payload = {
        "schema": 4, "kind": "nextSessionPlan",
        "forCharacter": character, "basedOnSessionId": last["sessionId"],
        "sourceDigest": read_result["sourceDigest"],
        "createdAt": now, "expiresAt": now + 86400,
        "gameBuild": str(last.get("build") or "unknown")[:40],
        "levelAtPlan": last.get("levelEnd"),
        "goal": "xp", "budgetSeconds": xp60_planner.SECONDS,
        "status": computed["status"],
        "headline": "Your next 60 minutes" if computed["steps"]
                    else "Quest opportunities to review" if qualitative
                    else "Your current route remains the best supported choice",
        "summary": computed["message"],
        "baselineXPPerHour": b["xpPerHour"],
        "estimatedEarnedXP": computed["estimatedEarnedXP"],
        "steps": computed["steps"], "qualitativeCandidateIds": qualitative,
        "limitations": [
            "XP/hour is measured from wall-clock time, not active time.",
            "No quantified improvement without verified reward, timing and comparable baseline.",
        ],
        "actions": [],
    }
    return payload


def validate_payload(plan):
    if not isinstance(plan, dict) or set(plan) - {
        "schema", "kind", "forCharacter", "basedOnSessionId", "sourceDigest",
        "createdAt", "expiresAt", "gameBuild", "levelAtPlan", "goal",
        "budgetSeconds", "status", "headline", "summary", "baselineXPPerHour",
        "estimatedEarnedXP", "steps", "qualitativeCandidateIds", "limitations", "actions"
    }:
        raise DeliveryError("unexpected plan fields")
    if plan.get("schema") != 4 or plan.get("kind") != "nextSessionPlan" or plan.get("goal") != "xp":
        raise DeliveryError("incorrect XP60 schema")
    if not isinstance(plan.get("forCharacter"), str) or "-" not in plan["forCharacter"]:
        raise DeliveryError("missing character binding")
    if not isinstance(plan.get("basedOnSessionId"), str) or not plan["basedOnSessionId"]:
        raise DeliveryError("missing source session")
    if not isinstance(plan.get("sourceDigest"), str) or len(plan["sourceDigest"]) != 64:
        raise DeliveryError("missing snapshot digest")
    if type(plan.get("budgetSeconds")) is not int or plan["budgetSeconds"] != 3600:
        raise DeliveryError("budget not fixed to 3600 seconds")
    if type(plan.get("createdAt")) is not int or type(plan.get("expiresAt")) is not int or not (
        0 < plan["expiresAt"] - plan["createdAt"] <= 86400):
        raise DeliveryError("invalid plan expiry")
    if plan.get("actions") != []:
        raise DeliveryError("model or planner actions are not permitted")
    suggestions = plan.get("qualitativeCandidateIds", [])
    if not isinstance(suggestions, list) or len(suggestions) > 3 or any(
            not isinstance(x, str) or not 1 <= len(x) <= 100 for x in suggestions
    ) or len(set(suggestions)) != len(suggestions):
        raise DeliveryError("invalid source suggestion IDs")
    rows = plan.get("steps")
    if not isinstance(rows, list) or len(rows) > 12:
        raise DeliveryError("too many steps")
    cursor, ids = 0, set()
    for s in rows:
        if not isinstance(s, dict) or set(s) != {
                "candidateId", "startsAt", "endsAt", "xp", "evidenceIds", "title"}:
            raise DeliveryError("unrecognized step fields")
        if not isinstance(s["candidateId"], str) or s["candidateId"] in ids:
            raise DeliveryError("invalid or duplicate candidate ID")
        ids.add(s["candidateId"])
        if not all(type(s[n]) is int and s[n] >= 0 for n in ("startsAt", "endsAt", "xp")):
            raise DeliveryError("invalid XP/time data")
        if s["startsAt"] < cursor or s["endsAt"] <= s["startsAt"] or s["endsAt"] > 3600:
            raise DeliveryError("step exceeds time budget")
        cursor = s["endsAt"]
    return plan


def write_after_exit(plan, addon_dir, *, checker=None):
    validate_payload(plan)
    is_closed = checker or game_closed
    if is_closed() is not True:
        raise DeliveryError("game is still running or process status is unknown")
    path = Path(addon_dir).resolve() / "Advisor" / "Advice.lua"
    if not path.is_file():
        raise DeliveryError("existing Outrider Advisor/Advice.lua not found")
    # Recheck immediately before mutating the existing data-only advice file.
    if is_closed() is not True:
        raise DeliveryError("game restarted before advice delivery")
    return advice.write(str(path), plan)

"""Validate advice and write Advisor/Advice.lua (P9-03).

Mirrors addon/Outrider/Advisor/AdviceLoader.lua: only these actions, these
argument kinds, at most 12 items, plain text titles. The game checks again
when it loads the file; this side refuses bad advice before writing.
"""

import math
import os
import tempfile

from . import luadata

SCHEMA = 1
MAX_ITEMS = 12
MAX_BYTES = 64 * 1024
ALLOWED = {
    "waypoint": {"mapID": "id", "x": "frac", "y": "frac"},
    "track_quest": {"questID": "id"},
    "open_panel": {"panel": "panel"},
    "show_item": {"itemID": "id"},
}
PANELS = {"hub", "rares", "pet", "macros", "gear", "professions", "map"}
CONFIDENCE = {"verified", "community", "inferred", "unknown", "observed"}
ADVICE_SUFFIX = os.path.join("Interface", "AddOns", "Outrider", "Advisor", "Advice.lua")


def _is_id(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v) \
        and v == int(v) and 1 <= v < 2 ** 31


def _is_frac(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v) and 0 <= v <= 1


CHECK = {"id": _is_id, "frac": _is_frac, "panel": lambda v: isinstance(v, str) and v in PANELS}


def _plain(s, limit):
    if not isinstance(s, str):
        return None
    s = s.replace("|", "")
    s = "".join(" " if ord(c) < 32 else c for c in s).strip()
    return s[:limit] or None


def clean_item(item):
    """A cleaned item, or (None, reason)."""
    if not isinstance(item, dict):
        return None, "not an object"
    spec = ALLOWED.get(item.get("action"))
    if not spec:
        return None, "action %r is not allowed" % item.get("action")
    title = _plain(item.get("title"), 120)
    if not title:
        return None, "missing title"
    src = item.get("args") if isinstance(item.get("args"), dict) else {}
    args = {}
    for key, kind in spec.items():
        v = src.get(key)
        if not CHECK[kind](v):
            return None, "bad %s for %s" % (key, item.get("action"))
        args[key] = int(v) if kind == "id" else v
    conf = item.get("confidence") if item.get("confidence") in CONFIDENCE else "unknown"
    return {"title": title, "why": _plain(item.get("why"), 400) or "", "action": item["action"],
            "args": args, "confidence": conf}, None


def build(character, snapshot_taken_at, items):
    """The Outrider_Advice table and the list of rejected items with reasons."""
    if not isinstance(character, str) or "-" not in character:
        raise ValueError("character must look like Name-Realm")
    if not isinstance(snapshot_taken_at, (int, float)):
        raise ValueError("no snapshot for this character: type /ride ask in game first")
    if not isinstance(items, list):
        raise ValueError("items must be a list")
    kept, rejected = [], []
    for i, item in enumerate(items):
        c, why = clean_item(item)
        if c and len(kept) < MAX_ITEMS:
            kept.append(c)
        elif c:
            rejected.append({"index": i, "reason": "more than %d items" % MAX_ITEMS})
        else:
            rejected.append({"index": i, "reason": why})
    return {"schema": SCHEMA, "forCharacter": character, "answersSnapshot": int(snapshot_taken_at),
            "items": kept}, rejected


def write(path, advice):
    """Atomically write Advice.lua; refuses any other path."""
    norm = os.path.normcase(os.path.normpath(path))
    if not norm.endswith(os.path.normcase(ADVICE_SUFFIX)):
        raise ValueError("refusing to write anywhere but %s" % ADVICE_SUFFIX)
    folder = os.path.dirname(path)
    if not os.path.isdir(folder):
        raise ValueError("Outrider is not installed at %s" % folder)
    text = ("-- Advisor/Advice.lua (written by the Outrider companion app; DATA ONLY)\n"
            + luadata.dumps("Outrider_Advice", advice))
    if len(text.encode("utf-8")) > MAX_BYTES:
        raise ValueError("advice is larger than %d KB; refusing to write it" % (MAX_BYTES // 1024))
    fd, tmp = tempfile.mkstemp(dir=folder, prefix=".advice-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)
    return len(text)

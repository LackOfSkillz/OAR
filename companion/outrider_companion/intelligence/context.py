"""ContextEnvelope v2: what the model may see (spec section 5.1, AI01-01/05).

Built from a /ride ask snapshot (the decoded OTR1 code). Privacy by default:
no character, realm, guild or other player names; strings stripped of WoW
escape codes and control characters and cut short; at most MAX_CANDIDATES
WhatNow candidates. The candidate list is also what answers are checked
against: the model may only point at these ids.
"""

import re

SCHEMA = 2
MAX_CANDIDATES = 20
MAX_TEXT = 200
LABELS = {"observed", "verified", "community", "inferred", "unknown"}
PANELS = {"hub", "rares", "pet", "macros", "gear", "professions", "map"}

_ESCAPE = re.compile(r"\|c[0-9a-fA-F]{8}|\|r|\|H[^|]*\|h|\|h|\|T[^|]*\|t|\|n")


class ContextError(ValueError):
    pass


def clean_text(s, limit=MAX_TEXT):
    """Plain text: no WoW escapes, no pipes, no control characters, bounded."""
    if not isinstance(s, str):
        return None
    s = _ESCAPE.sub("", s).replace("|", "")
    s = "".join(" " if ord(c) < 32 else c for c in s)
    s = " ".join(s.split())
    return s[:limit] or None


def _frac(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool) and 0 <= v <= 1


def _id(v):
    return isinstance(v, int) and not isinstance(v, bool) and 1 <= v < 2 ** 31


def _target(t):
    if isinstance(t, dict) and _id(t.get("mapID")) and _frac(t.get("x")) and _frac(t.get("y")):
        return {"mapID": t["mapID"], "x": t["x"], "y": t["y"]}
    return None


def candidates_of(snapshot):
    mods = snapshot.get("modules") if isinstance(snapshot.get("modules"), dict) else {}
    w = mods.get("WhatNow") if isinstance(mods.get("WhatNow"), dict) else {}
    raw = w.get("candidates") if isinstance(w.get("candidates"), list) else []
    out, seen = [], set()
    for c in raw:
        if not isinstance(c, dict):
            continue
        cid = clean_text(c.get("candidateId"), 120)
        if not cid or cid in seen:
            continue
        seen.add(cid)
        item = {
            "candidateId": cid,
            "kind": clean_text(c.get("kind"), 20) or "unknown",
            "title": clean_text(c.get("title")) or cid,
            "why": clean_text(c.get("why")),
            "where": clean_text(c.get("where")),
            "caveat": clean_text(c.get("caveat")),
            "minutes": c.get("minutes") if isinstance(c.get("minutes"), (int, float)) and not isinstance(c.get("minutes"), bool) else None,
            "label": c.get("label") if c.get("label") in LABELS else "unknown",
            "urgent": c.get("urgent") is True,
            "target": _target(c.get("target")),
            "panel": c.get("panel") if c.get("panel") in PANELS else None,
            "itemID": c.get("itemID") if _id(c.get("itemID")) else None,
        }
        out.append(item)
        if len(out) >= MAX_CANDIDATES:
            break
    return out, (clean_text(w.get("goal"), 20) or "mix")


def build(code_data):
    """Envelope from a decoded snapshot code ({kind, character, snapshot})."""
    if not isinstance(code_data, dict) or code_data.get("kind") != "snapshot":
        raise ContextError("that is not an Outrider snapshot code: type /ride ask in game and copy it")
    snap = code_data.get("snapshot")
    if not isinstance(snap, dict):
        raise ContextError("the snapshot code has no snapshot")
    character = code_data.get("character")
    if not isinstance(character, str) or "-" not in character:
        raise ContextError("the snapshot names no character")
    asked = snap.get("askedAt") or snap.get("takenAt")
    if not isinstance(asked, int):
        raise ContextError("the snapshot has no time")
    cands, goal = candidates_of(snap)
    where = snap.get("where") if isinstance(snap.get("where"), dict) else {}
    env = {
        "schema": SCHEMA,
        "snapshotId": clean_text(snap.get("snapshotId"), 60),
        "takenAt": asked,
        "gameBuild": clean_text(snap.get("gameBuild"), 20),
        "character": {   # names are never included (privacy default)
            "anonId": "char-1",
            "class": clean_text(snap.get("class"), 20),
            "race": clean_text(snap.get("race"), 30),
            "level": snap.get("level") if isinstance(snap.get("level"), int) else None,
            "faction": clean_text(snap.get("faction"), 20),
            "money": snap.get("money") if isinstance(snap.get("money"), int) else None,
        },
        "goal": goal,
        "currentZone": {"mapID": where.get("mapID") if _id(where.get("mapID")) else None,
                        "name": clean_text(where.get("zone"), 60)},
        "candidates": cands,
        "sources": [{"evidenceId": "local:" + c["candidateId"], "origin": "outrider", "label": c["label"]} for c in cands],
        "privacy": {"shareCharacterName": False, "shareGuild": False, "shareOtherPlayers": False},
    }
    # kept beside the envelope, never sent to the model
    binding = {"forCharacter": character, "answersSnapshot": asked, "answersSnapshotId": snap.get("snapshotId")}
    return env, binding


def model_view(env):
    """The part of the envelope that goes into the prompt (no binding data)."""
    keep = ("candidateId", "kind", "title", "why", "where", "caveat", "minutes", "label", "urgent")
    return {
        "character": {k: env["character"][k] for k in ("class", "race", "level", "faction")},
        "goal": env["goal"],
        "zone": env["currentZone"]["name"],
        "candidates": [{k: c[k] for k in keep if c.get(k) not in (None, False)} for c in env["candidates"]],
    }

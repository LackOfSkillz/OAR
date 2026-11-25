"""Passport snapshots (OI08-02): read and check one, the same rules as the addon.

A passport is "OTRP1:<adler32>:<base64>" made by Intelligence/Passport.lua:
a few chosen fields for one task, the character as an opaque id. It is
refused as current when it is too big, another version, older than MAX_AGE,
made on another build or for another character id. Sensitive fields the
player didn't tick are never there; read() also drops any field not on the
allow list, so an edited passport can't smuggle more in.
"""
import time

from .. import codes

TAG = "OTRP1"
VERSION = 1
MAX_BYTES = 16 * 1024
MAX_AGE = 6 * 3600
ALLOWED = {"level", "class", "role", "zone", "goals", "plan", "gearSlots", "professions",
           "goldBand", "gold", "realm", "guild"}
TASKS = {"plan", "gear", "gold", "explain", "lesson"}


class PassportError(ValueError):
    pass


def read(text, expect_id=None, expect_build=None, max_age=MAX_AGE, now=None):
    if not isinstance(text, str) or len(text) > MAX_BYTES:
        raise PassportError("missing or too big")
    text = text.strip()
    if not text.startswith(TAG + ":"):
        raise PassportError("not a passport")
    try:
        data = codes.import_code(codes.TAG + text[len(TAG):])
    except codes.CodeError as exc:
        raise PassportError(str(exc))
    if not isinstance(data, dict) or data.get("v") != VERSION:
        raise PassportError("another passport version")
    if data.get("task") not in TASKS:
        raise PassportError("unknown task")
    if expect_id is not None and data.get("id") != expect_id:
        raise PassportError("another character's passport")
    taken = data.get("takenAt")
    now = time.time() if now is None else now
    if not isinstance(taken, (int, float)) or now - taken > max_age:
        raise PassportError("stale: take a new one in game")
    if expect_build is not None and data.get("build") != expect_build:
        raise PassportError("made on another game build")
    fields = data.get("fields") if isinstance(data.get("fields"), dict) else {}
    data["fields"] = {k: v for k, v in fields.items() if k in ALLOWED}
    data["dropped"] = sorted(k for k in fields if k not in ALLOWED)
    return data

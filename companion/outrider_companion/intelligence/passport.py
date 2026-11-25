"""Passport snapshots (OI08-02): read and check one, the same rules as the addon.

A passport is "OTRP1:<adler32>:<base64>" made by Intelligence/Passport.lua:
a few chosen fields for one task, the character as an opaque id. It is
refused as current when it is too big, another version, an unknown task, a
malformed character id or build, taken in the future (beyond FUTURE_SKEW),
older than MAX_AGE, made on another build or for another character id.

Review OI-FR12: one contract for both languages. Fields not on the allow
list, or of the wrong type or size, are dropped (and listed in "dropped"), so
an edited passport can't smuggle more in. companion/tests/fixtures/
passport_contract.json holds the shared cases; the Lua reader
(Passport.Read) must give the same answers.
"""
import re
import time

from .. import codes

TAG = "OTRP1"
VERSION = 1
MAX_BYTES = 16 * 1024
MAX_AGE = 6 * 3600
FUTURE_SKEW = 300
TASKS = {"plan", "gear", "gold", "explain", "lesson"}
ID_RE = re.compile(r"^c[0-9a-f]{8}$")


class PassportError(ValueError):
    pass


def _num(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def _int_in(lo, hi):
    return lambda v: _num(v) and v == int(v) and lo <= v <= hi


def _text(n):
    return lambda v: isinstance(v, str) and 0 < len(v) <= n


def _ids(n):
    # an empty Lua table may decode as {}: that is an empty list too
    return lambda v: (isinstance(v, dict) and not v) or (
        isinstance(v, list) and len(v) <= n and all(isinstance(x, str) and 0 < len(x) <= 40 for x in v))


def _slots(v):
    if isinstance(v, list):
        items = list(enumerate(v, 1))
    elif isinstance(v, dict):
        items = list(v.items())
    else:
        return False
    return len(items) <= 19 and all(_int_in(1, 19)(k) and _num(x) and x > 0 and x == int(x) for k, x in items)


def _small_table(v):
    return isinstance(v, (list, dict)) and len(v) <= 20


# the allow list, with each field's check (same as FIELD_CHECKS in Passport.lua)
CHECKS = {
    "level": _int_in(1, 60),
    "class": _text(16),
    "role": _text(16),
    "zone": _int_in(1, 100000),
    "goals": _ids(5),
    "plan": _ids(10),
    "gearSlots": _slots,
    "professions": _small_table,
    "goldBand": _text(16),
    "gold": lambda v: _num(v) and v >= 0,
    "realm": _text(64),
    "guild": _text(64),
}
ALLOWED = set(CHECKS)


def read(text, expect_id=None, expect_build=None, max_age=MAX_AGE, now=None):
    if not isinstance(text, str):
        raise PassportError("missing or too big")
    text = text.strip()
    if len(text) > MAX_BYTES:
        raise PassportError("missing or too big")
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
    cid = data.get("id")
    if not isinstance(cid, str) or not ID_RE.match(cid):
        raise PassportError("bad character id")
    if expect_id is not None and cid != expect_id:
        raise PassportError("another character's passport")
    taken = data.get("takenAt")
    now = time.time() if now is None else now
    if not _num(taken):
        raise PassportError("stale: take a new one")
    if taken > now + FUTURE_SKEW:
        raise PassportError("taken in the future")
    if now - taken > max_age:
        raise PassportError("stale: take a new one")
    build = data.get("build")
    if build is not None and not (isinstance(build, str) and 0 < len(build) <= 32):
        raise PassportError("bad build")
    if expect_build is not None and build != expect_build:
        raise PassportError("made on another game build")
    fields = data.get("fields") if isinstance(data.get("fields"), dict) else {}
    kept, dropped = {}, []
    for k, v in fields.items():
        check = CHECKS.get(k)
        if check and check(v):
            kept[k] = v
        else:
            dropped.append(str(k))
    data["fields"] = kept
    data["dropped"] = sorted(dropped)
    return data

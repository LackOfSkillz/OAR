"""Nexus v4 record contracts (OI02-01). Additive to schemas_v3; v1-v3 unchanged.

The spec is read from docs/contracts/nexus_v4.lua, the same file the addon's
Intelligence/Contracts.lua copies (a Lua test keeps the copy identical). The
validator here must give the same verdict as the Lua one on
docs/contracts/nexus_v4_fixtures.lua. Standard library only; no network.
"""
import math
import os
import re

from .. import luadata

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
SPEC_PATH = os.path.join(ROOT, "docs", "contracts", "nexus_v4.lua")
FIXTURES_PATH = os.path.join(ROOT, "docs", "contracts", "nexus_v4_fixtures.lua")
ID_RE = re.compile(r"^[A-Za-z0-9_:.@-]+$")
CONTROL_RE = re.compile(r"[\x00-\x1f\x7f|]")
LIST_RE = re.compile(r"^list:([A-Za-z0-9]+):(\d+)$")

_spec = None


def spec():
    global _spec
    if _spec is None:
        with open(SPEC_PATH, encoding="utf-8") as fh:
            _spec = luadata.parse(fh.read())["NexusSpec"]
    return _spec


def fixtures():
    with open(FIXTURES_PATH, encoding="utf-8") as fh:
        return luadata.parse(fh.read())["NexusFixtures"]


def _as_list(v):
    if isinstance(v, list):
        return v
    if isinstance(v, dict) and not v:
        return []
    return None


def check_type(tname, v):
    s = spec()
    if tname.startswith("enum:"):
        return isinstance(v, str) and v in s["enums"].get(tname[5:], [])
    m = LIST_RE.match(tname)
    if m:
        items = _as_list(v)
        if items is None or len(items) > int(m.group(2)):
            return False
        return all(check_type(m.group(1), x) for x in items)
    t = s["types"].get(tname)
    if not t:
        return False
    kind = t["kind"]
    if kind == "id":
        return isinstance(v, str) and 1 <= len(v) <= t["max"] and bool(ID_RE.match(v))
    if kind == "string":
        return isinstance(v, str) and len(v.encode("utf-8")) <= t["max"] and not CONTROL_RE.search(v)
    if isinstance(v, bool):
        return kind == "boolean"
    if kind in ("integer", "number"):
        if not isinstance(v, (int, float)) or (isinstance(v, float) and not math.isfinite(v)):
            return False
        if kind == "integer" and v != int(v):
            return False
        return t["min"] <= v <= t["max"]
    return False


def validate(record, data):
    """(ok, field): the first failing field, "unknownField" for extras."""
    fields = spec()["records"].get(record)
    if fields is None:
        return False, "record"
    if not isinstance(data, dict):
        return False, "table"
    known = set()
    for f in fields:
        name, tname, required = f[0], f[1], f[2]
        known.add(name)
        if name not in data:
            if required:
                return False, name
        elif not check_type(tname, data[name]):
            return False, name
    for k in data:
        if k not in known:
            return False, "unknownField"
    if record == "Evidence" and data["expiresAt"] < data["observedAt"]:
        return False, "expiresAt"
    if record == "Outcome" and "endAt" in data and data["endAt"] < data["startAt"]:
        return False, "endAt"
    return True, None

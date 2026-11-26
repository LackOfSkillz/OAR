"""VG07-02: privacy-filtered export and import of Vanguard run history.

Export (from Outrider.lua SavedVariables, after the game is closed):
  * only the anonymous RunRecord v1 fields listed in
    companion/tests/fixtures/vanguard_contract.json (the Lua spec checks the
    addon writes nothing outside them); anything else is dropped and counted;
  * no names or GUIDs: a string that looks like a player GUID or a character
    key from this file refuses the run;
  * the exporter is the opaque character id (c + adler32(salt|Name-Realm)),
    the only character identifier allowed across a boundary;
  * an optional profile (class and level only) and a guild flag, each only
    when the player asks for it;
  * preview by default; a file is written only on request, never inside the
    game folder.
Import (a file someone gives you, or your own): strict. Wrong format, a newer
version, an unknown field anywhere, a bad type or a size over the caps
refuses the whole file. Nothing is ever sent anywhere.
"""
import hashlib
import json
import re
import time
import zlib
from pathlib import Path

from .. import luadata
from ..intelligence import session_reader

FORMAT = "OTR-VG-EXPORT"
VERSION = 1
MAX_IMPORT_BYTES = 5 * 1024 * 1024
MAX_RUNS = 5000
MAX_ATTEMPTS = 60
FIXTURE = Path(__file__).resolve().parents[2] / "tests" / "fixtures" / "vanguard_contract.json"

CLASSES = ("WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID")
OUTCOMES = ("completed", "incomplete", "abandoned", "unknown")
RESULTS = ("kill", "wipe", "unknown")
GUID = re.compile(r"(Player|Creature|Pet|Vehicle)-\d+-[0-9A-Fa-f]+")
OPAQUE = re.compile(r"^c[0-9a-f]{8}$")


class ContractError(ValueError):
    pass


def _str(n):
    def f(v):
        if not isinstance(v, str) or len(v) > n:
            raise ContractError("text too long or not text")
        return v
    return f


def _num(lo, hi):
    def f(v):
        if isinstance(v, bool) or not isinstance(v, (int, float)) or v != v or not lo <= v <= hi:
            raise ContractError("number out of range")
        return int(v) if float(v).is_integer() else float(v)
    return f


def _enum(values):
    def f(v):
        if v not in values:
            raise ContractError("value not allowed: %r" % (v,))
        return v
    return f


def _bool(v):
    if not isinstance(v, bool):
        raise ContractError("not true/false")
    return v


def _label(v):
    """A short version label: text or a number."""
    if isinstance(v, str):
        return _str(40)(v)
    return _num(0, 2 ** 31)(v)


TIME = _num(0, 2 ** 33)
COUNT = _num(0, 40)

FEATURES = {"members": COUNT, "tank": COUNT, "healer": COUNT, "damage": COUNT, "unknownRole": COUNT,
            "levelMin": _num(1, 100), "levelMax": _num(1, 100)}
ASSESSMENT = {"low": _num(0, 100), "high": _num(0, 100), "coverage": _num(0, 1),
              "point": _num(0, 100), "gate": _str(40), "catalog": _label}
ATTEMPT = {"id": _num(1, 10 ** 6), "encounterId": _str(20), "name": _str(60), "start": TIME, "end": TIME,
           "result": _enum(RESULTS)}
RUN = {"v": _enum((1,)), "runId": _str(80), "instance": _str(60), "difficulty": _str(20), "size": COUNT,
       "build": _str(40), "startedAt": TIME, "endedAt": TIME, "outcome": _enum(OUTCOMES),
       "censorReason": _str(60), "rosterChanges": _num(0, 10 ** 4), "kills": _num(0, 10 ** 4),
       "distinctKills": _num(0, 100), "bosses": _num(0, 100), "revision": _num(1, 10 ** 6)}
NESTED = ("features", "assessment", "attempts")


def contract_fields():
    """The allowed field names, for the shared fixture test."""
    return {"run": sorted(list(RUN) + list(NESTED)), "features": sorted(list(FEATURES) + ["classes"]),
            "assessment": sorted(ASSESSMENT), "attempt": sorted(ATTEMPT)}


def _clean_table(src, spec, strict, dropped, where):
    out = {}
    for k, v in src.items():
        if k in spec:
            out[k] = spec[k](v)
        elif strict:
            raise ContractError("unknown field %s.%s" % (where, k))
        else:
            dropped[where + "." + str(k)] = dropped.get(where + "." + str(k), 0) + 1
    return out


def clean_run(run, *, strict=False, dropped=None, forbidden=()):
    """One run record -> a clean copy with only contract fields (or ContractError)."""
    dropped = {} if dropped is None else dropped
    if not isinstance(run, dict):
        raise ContractError("run is not a table")
    flat = {k: v for k, v in run.items() if k not in NESTED}
    out = _clean_table(flat, RUN, strict, dropped, "run")
    for need in ("v", "runId", "instance", "startedAt", "outcome"):
        if need not in out:
            raise ContractError("run is missing %s" % need)
    if out["outcome"] != "unknown" and "endedAt" not in out:
        raise ContractError("finished run without endedAt")
    f = run.get("features")
    if f is not None:
        if not isinstance(f, dict):
            raise ContractError("features is not a table")
        rest = {k: v for k, v in f.items() if k != "classes"}
        feats = _clean_table(rest, FEATURES, strict, dropped, "features")
        classes = f.get("classes")
        if classes is not None:
            if not isinstance(classes, dict):
                raise ContractError("classes is not a table")
            feats["classes"] = {}
            for c, n in classes.items():
                if c not in CLASSES:
                    raise ContractError("unknown class %r" % (c,))
                feats["classes"][c] = COUNT(n)
        out["features"] = feats
    a = run.get("assessment")
    if a is not None:
        if not isinstance(a, dict):
            raise ContractError("assessment is not a table")
        out["assessment"] = _clean_table(a, ASSESSMENT, strict, dropped, "assessment")
    atts = run.get("attempts")
    if atts is not None:
        if isinstance(atts, dict) and not atts:
            atts = []  # an empty Lua table reads back as {}
        if not isinstance(atts, list) or len(atts) > MAX_ATTEMPTS:
            raise ContractError("attempts is not a short list")
        out["attempts"] = []
        for x in atts:
            if not isinstance(x, dict):
                raise ContractError("attempt is not a table")
            out["attempts"].append(_clean_table(x, ATTEMPT, strict, dropped, "attempt"))
    text = json.dumps(out, sort_keys=True)
    if GUID.search(text):
        raise ContractError("a GUID-shaped value is in the run")
    for name in forbidden:
        if name and name.lower() in text.lower():
            raise ContractError("a character name is in the run")
    return out


def canonical(obj):
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def sha256(obj):
    return hashlib.sha256(canonical(obj)).hexdigest()


def opaque_id(salt, char_key):
    return "c%08x" % (zlib.adler32(("%s|%s" % (salt, char_key)).encode("utf-8")) & 0xffffffff)


def _inside_game(path):
    parts = {p.lower() for p in Path(path).resolve().parts}
    return "wtf" in parts or "interface" in parts


def _list(v):
    if isinstance(v, list):
        return v
    if isinstance(v, dict) and not v:
        return []
    return None


def read_saved(path):
    """Stable, read-only parse of Outrider.lua (the session reader's rules)."""
    data = session_reader.stable_bytes(path, cap=64 * 1024 * 1024)
    try:
        root = luadata.parse(data.decode("utf-8-sig"))
    except (UnicodeDecodeError, luadata.LuaDataError, IndexError) as exc:
        raise ContractError("SavedVariables is incomplete or not plain Lua data") from exc
    db = root.get("Outrider_DB")
    if not isinstance(db, dict) or not isinstance(db.get("chars"), dict):
        raise ContractError("Outrider character database is missing")
    return db, hashlib.sha256(data).hexdigest()


def runs_for(db, char_key):
    """Active runs plus archived ones for this character, deduplicated by runId
    (the latest revision wins), oldest first."""
    char = db["chars"].get(char_key)
    if not isinstance(char, dict):
        raise ContractError("unknown character %s" % char_key)
    rows = []
    store = char.get("vanguardRuns")
    if isinstance(store, dict):
        rows.extend(_list(store.get("runs")) or [])
    sets = (((db.get("global") or {}).get("archive") or {}).get("sets") or {})
    for e in _list(sets.get("vanguardRuns") if isinstance(sets, dict) else None) or []:
        if isinstance(e, dict) and e.get("char") == char_key and isinstance(e.get("row"), dict):
            rows.append(e["row"])
    best = {}
    for r in rows:
        if isinstance(r, dict) and isinstance(r.get("runId"), str):
            old = best.get(r["runId"])
            if old is None or (r.get("revision") or 0) >= (old.get("revision") or 0):
                best[r["runId"]] = r
    return sorted(best.values(), key=lambda r: (r.get("startedAt") or 0, r["runId"]))


def build_export(db, source_sha, char_key, *, profile=False, guild=False, now=None):
    salt = ((db.get("global") or {}).get("passport") or {}).get("salt")
    if not isinstance(salt, str) or not salt:
        raise ContractError("no passport salt in saved data yet: log in once with this Outrider build")
    forbidden = [k.split("-")[0] for k in db["chars"] if isinstance(k, str)]
    dropped, runs, refused = {}, [], 0
    for r in runs_for(db, char_key)[-MAX_RUNS:]:
        try:
            runs.append(clean_run(r, dropped=dropped, forbidden=forbidden))
        except ContractError:
            refused += 1
    env = {"format": FORMAT, "v": VERSION, "createdAt": int(time.time() if now is None else now),
           "exporter": opaque_id(salt, char_key), "source": {"sha256": source_sha},
           "consent": {"runs": True, "profile": bool(profile), "guild": bool(guild)},
           "runs": runs, "counts": {"runs": len(runs), "refused": refused, "droppedFields": sum(dropped.values())}}
    if profile:
        meta = (db["chars"][char_key] or {}).get("meta") or {}
        p = {}
        if meta.get("class") in CLASSES:
            p["class"] = meta["class"]
        if isinstance(meta.get("level"), (int, float)) and 1 <= meta["level"] <= 100:
            p["level"] = int(meta["level"])
        env["profile"] = p
    return env, dropped


def preview(env):
    """What would leave this PC, in words (the default action)."""
    lines = ["Vanguard export preview (nothing written yet)",
             "  who: %s (an anonymous id; no names)" % env["exporter"],
             "  runs: %d (refused %d, fields dropped %d)" % (env["counts"]["runs"], env["counts"]["refused"],
                                                              env["counts"]["droppedFields"]),
             "  profile: %s" % (json.dumps(env.get("profile")) if env["consent"]["profile"] else "not included"),
             "  guild report: %s" % ("may include these runs" if env["consent"]["guild"] else "not allowed"),
             "  fields per run: " + ", ".join(sorted({k for r in env["runs"] for k in r}))]
    return "\n".join(lines)


def write_export(env, out):
    if _inside_game(out):
        raise ContractError("refusing to write inside the game folder (WTF or Interface)")
    Path(out).write_bytes(canonical(env))
    return out


TOP = {"format", "v", "createdAt", "exporter", "source", "consent", "runs", "counts", "profile", "synthetic"}


def read_import(path):
    """Strict reader for an export file. Returns the validated envelope."""
    p = Path(path)
    if not p.is_file() or p.is_symlink():
        raise ContractError("file is missing or is a link")
    size = p.stat().st_size
    if size <= 0 or size > MAX_IMPORT_BYTES:
        raise ContractError("file is empty or too large")
    raw = p.read_bytes()
    try:
        env = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, ValueError) as exc:
        raise ContractError("not a Vanguard export (not JSON)") from exc
    return validate(env), hashlib.sha256(raw).hexdigest()


def validate(env):
    if not isinstance(env, dict) or env.get("format") != FORMAT:
        raise ContractError("not a Vanguard export")
    v = env.get("v")
    if isinstance(v, int) and not isinstance(v, bool) and v > VERSION:
        raise ContractError("made by a newer Outrider (v%d); update first" % v)
    if v != VERSION:
        raise ContractError("bad version")
    extra = set(env) - TOP
    if extra:
        raise ContractError("unknown field %s" % sorted(extra)[0])
    if not isinstance(env.get("exporter"), str) or not OPAQUE.match(env["exporter"]):
        raise ContractError("exporter is not an anonymous id")
    TIME(env.get("createdAt"))
    consent = env.get("consent")
    if not isinstance(consent, dict) or set(consent) != {"runs", "profile", "guild"}:
        raise ContractError("consent must say runs, profile and guild")
    for k in consent:
        _bool(consent[k])
    if consent["runs"] is not True:
        raise ContractError("runs were not consented")
    src = env.get("source")
    if not isinstance(src, dict) or set(src) - {"sha256"} or not re.match(r"^[0-9a-f]{64}$", str(src.get("sha256"))):
        raise ContractError("bad source")
    runs = env.get("runs")
    if not isinstance(runs, list) or len(runs) > MAX_RUNS:
        raise ContractError("runs is not a list within the cap")
    env["runs"] = [clean_run(r, strict=True) for r in runs]
    if "profile" in env:
        if not consent["profile"]:
            raise ContractError("a profile without consent")
        pr = env["profile"]
        if not isinstance(pr, dict) or set(pr) - {"class", "level"}:
            raise ContractError("profile has fields outside class and level")
        if "class" in pr:
            _enum(CLASSES)(pr["class"])
        if "level" in pr:
            _num(1, 100)(pr["level"])
    if "synthetic" in env:
        _bool(env["synthetic"])
    if "counts" in env and not isinstance(env["counts"], dict):
        raise ContractError("bad counts")
    return env

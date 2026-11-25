"""Offline companion (OI08-03): finished-session history, reports and exports.

  python -m outrider_companion.cli sessions --savedvariables PATH [--character Name-Realm]
  python -m outrider_companion.cli report   --savedvariables PATH [--character Name-Realm]
  python -m outrider_companion.cli passport --text "OTRP1:..." [--max-age-hours 6]
  python -m outrider_companion.cli export   --savedvariables PATH --out FILE.json

Reads SavedVariables only (the same stable reader XP60 uses): a missing,
damaged or half-written file gives a plain message and exit code 2, never a
traceback. Only finished sessions are used. Nothing is written inside the
WoW folder (export refuses any path under a WTF or Interface folder), there
is no network, and the addon works the same with or without this program.
"""
import argparse
import json
import sys
from pathlib import Path

from .intelligence import session_reader, xp_baseline, passport


class CliError(ValueError):
    pass


def _finished(result, character=None):
    out = []
    for key, s in result["sessions"]:
        if character and key != character:
            continue
        if s.get("final") is True and not (s.get("flags") or {}).get("incomplete"):
            out.append((key, s))
    return out


def sessions(path, character=None):
    rows = []
    for key, s in _finished(session_reader.read_sessions(path, character=character), character):
        rows.append({"character": key, "sessionId": s.get("sessionId"), "endedAt": s.get("endedAt"),
                     "durationSeconds": s.get("durationSeconds"), "xpEarned": s.get("xpEarned"),
                     "levelStart": s.get("levelStart"), "build": s.get("build")})
    return rows


def report(path, character=None):
    result = session_reader.read_sessions(path, character=character)
    by = {}
    for key, s in _finished(result, character):
        by.setdefault(key, []).append(s)
    out = {}
    for key, list_ in by.items():
        out[key] = {"finishedSessions": len(list_), "xp": xp_baseline.baseline(list_)}
    return {"characters": out, "note": "from finished sessions only; estimates, not promises"}


def _inside_game(path):
    parts = {p.lower() for p in Path(path).resolve().parts}
    return "wtf" in parts or "interface" in parts


def export(path, out, character=None):
    if _inside_game(out):
        raise CliError("refusing to write inside the game folder (WTF or Interface)")
    data = report(path, character)
    Path(out).write_text(json.dumps(data, indent=2, sort_keys=True), encoding="utf-8")
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(prog="outrider-companion", description="Outrider offline companion (read-only)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("sessions", "report", "export"):
        p = sub.add_parser(name)
        p.add_argument("--savedvariables", required=True)
        p.add_argument("--character")
        if name == "export":
            p.add_argument("--out", required=True)
    pp = sub.add_parser("passport")
    pp.add_argument("--text", required=True)
    pp.add_argument("--max-age-hours", type=float, default=passport.MAX_AGE / 3600)
    args = ap.parse_args(argv)
    try:
        if args.cmd == "sessions":
            print(json.dumps(sessions(args.savedvariables, args.character), indent=2))
        elif args.cmd == "report":
            print(json.dumps(report(args.savedvariables, args.character), indent=2))
        elif args.cmd == "export":
            print("wrote %s" % export(args.savedvariables, args.out, args.character))
        elif args.cmd == "passport":
            data = passport.read(args.text, max_age=args.max_age_hours * 3600)
            print(json.dumps({"task": data["task"], "fields": sorted(data["fields"]), "dropped": data["dropped"],
                              "build": data.get("build")}, indent=2))
    except (session_reader.SessionReadError, passport.PassportError, CliError, OSError) as exc:
        print("Outrider companion: %s" % exc, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
